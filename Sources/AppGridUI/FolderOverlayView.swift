// AppGridUI — FolderOverlayView（Phase 1E §3.1C 文件夹打开层；ADR-008 §3 Q5/Q9/Q13）
// 实现：T-1E-C（Worker C）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 打开层（open layer）：全表面遮罩 + 居中文件夹面板（标题 + 成员网格 + 内部分页）。
// - 内部分页完全独立于外层 PagingCore 状态：本视图只维护自己的 innerPage 呈现，
//   绝不驱动/污染外层（外层由 PagingSurface/PagingCore 状态机独占）。
// - 点击面板外（遮罩区）→ onRequestClose（只关闭文件夹，不退出 app；"下一次真实背景
//   单击退出"由 T-1E-E 在窗口层接线）。
// - 成员图标经 IconPipeline 异步请求，surfaceGeneration 门控写回（stale defense）：
//   打开 A 后打开 B，A 的旧成员图标回调被 generation 拒绝；teardown 后零 UI 写回。
// - Reduce Motion：开/关与内部分页动画减少大位移/缩放，状态保持正确。动画参数来自
//   PRODUCT_DECISION / ACCESSIBILITY_REQUIREMENT，注册于 Workflow/results/T-1E-C.md
//   （PARAMETER_RATIONALE.md 由 Main 登记，超出本 Worker 写范围）。
// - 无障碍：面板标题 + 成员层级可理解；成员 cell 复用 AppGridCellView 的完整名称标签。
//
// 线程模型：视图主线程（MainActor）受限；onApply 由 IconPipeline 保证在 MainActor 投递，
// 故 @unchecked Sendable 仅为满足 @Sendable 闭包捕获（与 AppGridPageView 同一约定）。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI

/// 文件夹打开层（open layer）：全表面遮罩 + 居中文件夹面板。
public final class FolderOverlayView: NSView, @unchecked Sendable {

    /// Transient 预览的事件隔离宿主：代理只负责绘制，不参与 AppKit hit-test。
    private final class MoveOutProxyHostView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// 开/关与内部分页动画参数（纯值；测试断言 Reduce Motion 路径）。
    ///
    /// 来源类别：`PRODUCT_DECISION`（标准开/关/翻页动画）/ `ACCESSIBILITY_REQUIREMENT`
    /// （Reduce Motion 下减少大位移/缩放）。注册于 `Workflow/results/T-1E-C.md`。
    public struct MotionParams: Equatable, Sendable {
        public let duration: TimeInterval
        public let scale: CGFloat
        public let displacement: CGFloat

        public init(duration: TimeInterval, scale: CGFloat, displacement: CGFloat) {
            self.duration = duration
            self.scale = scale
            self.displacement = displacement
        }

        /// 标准动画：短时 + 轻微缩放 + 轻微位移（非 RM）。
        public static let standard = MotionParams(duration: 0.18, scale: 0.96, displacement: 8)
        /// Reduce Motion：零时长 + 无缩放 + 无位移（状态仍正确）。
        public static let reduceMotion = MotionParams(duration: 0.0, scale: 1.0, displacement: 0.0)

        /// 按 Reduce Motion 标志选择动画参数。
        public static func forReduceMotion(_ reduce: Bool) -> MotionParams {
            reduce ? .reduceMotion : .standard
        }
    }

    // MARK: - 回调（装配层接线；测试观察）

    /// 成员激活（→ 装配层复用 AppLaunchController 启动成员 app）。
    public var onActivateMember: ((AppID) -> Void)?
    /// 请求关闭文件夹（点击面板外 / 关闭按钮；只关闭文件夹，不退出 app）。
    public var onRequestClose: (() -> Void)?
    /// 成员拖拽越过 panel 边界并已满足 move-out 阈值：请求装配层折叠 Folder 视觉，
    /// 但保持 overlay 在视图树中继续接收本次 mouseDragged/mouseUp。
    public var onMemberDragExitPanel: (() -> Void)?
    /// 内部分页变更（→ 装配层写回 FolderOpenState.setInnerPage）。
    public var onInnerPageChange: ((Int) -> Void)?
    /// 成员图标异步 apply 结果观察（测试 + telemetry 合成；无字节/哈希/路径/身份原文）。
    public var onIconApplyResult: ((ItemBindingToken, AppGridIconApplyResult) -> Void)?

    /// Phase 1F（T-1F-D1）：拖拽协调器（装配层注入；nil = 无 drag 仲裁 → 既有点击路径不变）。
    public weak var dragCoordinator: DragUISessionCoordinator?

    // MARK: - 状态（测试/诊断）

    /// 视图生命周期代（每次 configure/clearContent/teardown bump；成员图标门控）。
    public private(set) var surfaceGeneration: UInt64 = 0
    /// 是否已 teardown（此后零 UI 写回）。
    public private(set) var isTornDown = false
    /// 已投递但被门控拒绝的成员图标 apply 计数（stale result rejected）。
    public private(set) var staleIconApplyCount = 0
    /// 当前呈现的文件夹条目（nil = 未配置/已清空）。
    public private(set) var currentEntry: FolderEntry?
    /// 当前内部页（0-based）。
    public private(set) var currentInnerPage = 0
    /// 当前 Reduce Motion 标志。
    public private(set) var reduceMotion = false
    /// move-out 手势期间仅视觉折叠；逻辑 Folder 状态要等 commit 后才真正关闭。
    public private(set) var isMoveOutPresentationCollapsed = false
    /// move-out 折叠预览期间，Folder 中唯一未被拖出的成员。
    /// 仅当当前 Folder 恰好有两个成员且已识别拖拽源时有值。
    public private(set) var moveOutRemainingAppID: AppID?
    /// 顶层 Folder cell 上的 transient remaining-app 代理（不参与真实布局/绑定）。
    public private(set) var moveOutRemainingAppProxy: AppGridCellView?
    /// 折叠前缓存剩余成员图标（panel.isHidden 后源 cell 图标可能被卸掉）。
    private var cachedMoveOutRemainingIcon: NSImage?
    private var cachedMoveOutRemainingName: String = ""
    /// 代理在宿主坐标系中的 frame（测试/诊断）。
    public var moveOutRemainingAppProxyFrame: NSRect? { moveOutProxyHost?.frame }
    /// 代理事件隔离宿主（仅供 commit 事务同步复挂；不参与真实布局）。
    public var moveOutRemainingAppProxyHost: NSView? { moveOutProxyHost }

    /// 将 commit 事务中暂存并重新挂回 host 的代理恢复为本视图所拥有，
    /// 以便正式 presentation refresh 后由统一 clear 路径移除，不留下 orphan view。
    public func reattachMoveOutRemainingAppProxyHost(_ host: NSView, frame: NSRect) {
        guard let typedHost = host as? MoveOutProxyHostView,
              let proxy = typedHost.subviews.compactMap({ $0 as? AppGridCellView }).first else {
            return
        }
        typedHost.frame = frame
        moveOutProxyHost = typedHost
        moveOutRemainingAppProxy = proxy
    }
    /// 每页成员数（装配层与 FolderOpenState 对齐）。
    public var membersPerPage: Int = FolderOpenState.defaultMembersPerPage

    /// 成员 cell 数（测试/诊断）。
    public var memberCellCount: Int { memberCells.count }

    /// 当前拖出成员仍在打开层中的 cell；用于复用现有 name/icon 作为折叠代理。
    public var moveOutRemainingMemberCell: AppGridCellView? {
        guard let remaining = moveOutRemainingAppID else { return nil }
        return memberCells.first { $0.bindingToken?.appID as? AppID == remaining }
    }

    /// 面板 frame（overlay 坐标系；测试/诊断）。
    public var panelFrame: NSRect { panel.frame }

    /// 取成员 cell（测试/诊断；越界返回 nil）。
    public func memberCell(at index: Int) -> AppGridCellView? {
        guard index >= 0, index < memberCells.count else { return nil }
        return memberCells[index]
    }

    /// 面板内指定点的成员 AppID（测试/诊断；非成员区返回 nil）。
    public func memberAppID(at index: Int) -> AppID? {
        guard let entry = currentEntry else { return nil }
        let members = members(onPage: currentInnerPage, in: entry)
        guard index >= 0, index < members.count else { return nil }
        return members[index]
    }

    /// Phase 1F：成员拖拽几何（成员 cell frame → DragItemFrame；host 坐标系）。
    /// catalog 用于 AppID → PersistentAppReference 解析（nil = 无快照 → 成员条目跳过）。
    public func memberDragItemFrames(convertedTo host: NSView, catalog: CatalogSnapshot?) -> [DragItemFrame] {
        memberCells.compactMap { cell in
            guard let token = cell.bindingToken else { return nil }
            let frameInHost = cell.convert(cell.bounds, to: host)
            let rect = DragRect(x: Double(frameInHost.minX), y: Double(frameInHost.minY),
                                width: Double(frameInHost.width), height: Double(frameInHost.height))
            guard let appID = token.appID as? AppID,
                  let record = catalog?.records.first(where: { $0.id == appID }) else { return nil }
            return DragItemFrame(identity: .app(PersistentAppReference.from(record: record)), frame: rect)
        }
    }

    private let pipeline: IconPipeline
    private let iconPointSize: Double
    private let displayScale: Double
    private var memberCells: [AppGridCellView] = []
    private let panel = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let pageIndicator = NSTextField(labelWithString: "")
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private var memberName: (AppID) -> String? = { _ in nil }
    private var isTrackingMemberDrag = false
    private var didRequestMemberDragExit = false
    private var trackedMemberAppID: AppID?
    private var moveOutProxyHost: MoveOutProxyHostView?

    private static let columns = 5
    private static let spacing: CGFloat = 16
    private static let cellHeight: CGFloat = 88
    private static let panelInset: CGFloat = 24
    private static let titleHeight: CGFloat = 40
    private static let footerHeight: CGFloat = 44

    public init(iconPipeline: IconPipeline, iconPointSize: Double = 48, displayScale: Double = 2) {
        self.pipeline = iconPipeline
        self.iconPointSize = max(iconPointSize, 8)
        self.displayScale = max(displayScale, 1)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor

        panel.wantsLayer = true
        panel.layer?.cornerRadius = 12
        panel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(panel)

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        panel.addSubview(titleLabel)

        pageIndicator.font = .systemFont(ofSize: 12)
        pageIndicator.textColor = .secondaryLabelColor
        pageIndicator.alignment = .center
        panel.addSubview(pageIndicator)

        prevButton.title = "‹"
        nextButton.title = "›"
        prevButton.bezelStyle = .rounded
        nextButton.bezelStyle = .rounded
        prevButton.target = self
        nextButton.target = self
        prevButton.action = #selector(prevPage)
        nextButton.action = #selector(nextPage)
        prevButton.setAccessibilityLabel("Previous page")
        nextButton.setAccessibilityLabel("Next page")
        panel.addSubview(prevButton)
        panel.addSubview(nextButton)

        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - 配置 / 清空 / teardown

    /// 配置打开层：渲染标题 + 当前内部页成员网格 + 分页指示。
    /// 幂等：同 entry + 同 innerPage + 同 reduceMotion → 无操作（不重复请求图标）。
    /// 成员图标异步请求，surfaceGeneration 门控写回。
    public func configure(entry: FolderEntry, innerPage: Int, reduceMotion: Bool,
                          memberName: @escaping (AppID) -> String?) {
        guard !isTornDown else { return }
        // 活跃 move-out 期间普通 refresh 不得把已折叠视觉重新展开或清掉代理。
        if isMoveOutPresentationCollapsed && isTrackingMemberDrag { return }
        setMoveOutPresentationCollapsed(false)
        moveOutRemainingAppID = nil
        trackedMemberAppID = nil
        if entry == currentEntry, innerPage == currentInnerPage, reduceMotion == self.reduceMotion {
            return  // 幂等：状态未变，不重复渲染/请求
        }
        surfaceGeneration &+= 1
        self.currentEntry = entry
        self.currentInnerPage = innerPage
        self.reduceMotion = reduceMotion
        self.memberName = memberName
        titleLabel.stringValue = entry.title
        setAccessibilityLabel(entry.title)

        let members = members(onPage: innerPage, in: entry)
        prepareMemberCells(count: members.count)
        for (index, member) in members.enumerated() {
            let token = memberToken(member: member, index: index)
            memberCells[index].bind(name: memberName(member), token: token)
            if let key = token.iconKey {
                requestMemberIcon(key: key, token: token, cellIndex: index)
            }
        }
        updatePageIndicator()
        needsLayout = true
    }

    /// 清空打开层（复用/关闭路径）：generation bump 作废在途成员图标；清空标题/成员。
    public func clearContent() {
        guard !isTornDown else { return }
        setMoveOutPresentationCollapsed(false)
        clearMoveOutRemainingAppProxy()
        moveOutRemainingAppID = nil
        trackedMemberAppID = nil
        isTrackingMemberDrag = false
        didRequestMemberDragExit = false
        surfaceGeneration &+= 1
        currentEntry = nil
        currentInnerPage = 0
        titleLabel.stringValue = ""
        setAccessibilityLabel("")
        for cell in memberCells { cell.clearContent() }
        updatePageIndicator()
        needsLayout = true
    }

    /// teardown：此后零 UI 写回（成员图标回调 → .ignoredAfterTeardown）；释放全部成员 cell。
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        isMoveOutPresentationCollapsed = false
        clearMoveOutRemainingAppProxy()
        moveOutRemainingAppID = nil
        trackedMemberAppID = nil
        isTrackingMemberDrag = false
        didRequestMemberDragExit = false
        surfaceGeneration &+= 1
        currentEntry = nil
        currentInnerPage = 0
        for cell in memberCells { cell.removeFromSuperview() }
        memberCells.removeAll()
        titleLabel.stringValue = ""
        setAccessibilityLabel("")
    }

    // MARK: - 点击处理（面板外 → 关闭；成员 → 激活）

    /// 处理一次点击（测试直接调用；mouseDown 委托）。
    /// - 面板外（遮罩区）→ onRequestClose（只关闭文件夹）。
    /// - 面板内成员 cell → onActivateMember。
    /// - 面板内非成员区（标题/页脚）→ 忽略。
    public func handleClick(at point: NSPoint) {
        if panel.frame.contains(point) {
            // 成员 cell 是 panel 的子视图，frame 在 panel 坐标系；先把点转换到 panel 坐标系。
            let panelPoint = panel.convert(point, from: self)
            for (index, cell) in memberCells.enumerated() where cell.frame.contains(panelPoint) {
                if let member = memberAppID(at: index) {
                    onActivateMember?(member)
                }
                return
            }
            return
        }
        onRequestClose?()
    }

    /// Phase 1F（T-1F-D1）：pointer-down 路由到仲裁层。
    /// - 面板内成员 cell → coordinator（成员源；mouse-up 未过阈值 → 成员激活）。
    /// - 面板内非成员区（标题/页脚）→ 忽略（与既有 handleClick 语义一致）。
    /// - 面板外（遮罩区）→ coordinator 空白按下（mouse-up 未过阈值 → onOverlayBlankClick 关闭）。
    /// coordinator 为 nil 时回退既有路径（handleClick 在 mouse-down 派发）。
    public override func mouseDown(with event: NSEvent) {
        let coordinator = dragCoordinator ?? DragUISessionCoordinator.shared
        guard let coordinator else {
            handleClick(at: convert(event.locationInWindow, from: nil))
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if panel.frame.contains(point) {
            let panelPoint = panel.convert(point, from: self)
            for (index, cell) in memberCells.enumerated() where cell.frame.contains(panelPoint) {
                isTrackingMemberDrag = true
                didRequestMemberDragExit = false
                trackedMemberAppID = memberAppID(at: index)
                moveOutRemainingAppID = remainingAppID(for: trackedMemberAppID)
                coordinator.pointerDown(locationInWindow: event.locationInWindow,
                                        sourceCell: cell, memberFolderID: currentEntry?.id)
                return
            }
            isTrackingMemberDrag = false
            // T-1F-B10-wave-a forensics census（s15）：面板内非成员区 mouseDown 静默 return
            // （标题/页脚/面板边距；仅计数，零行为变更）。与 s14 联动判别：
            // 「事件进了 overlay 被吞」= s15 增；「根本没进 overlay」= s14/s15 均不增。
            ClickCensus.hit(ClickCensus.Sink.overlayMouseDownSilentReturn)
            return
        }
        isTrackingMemberDrag = false
        coordinator.pointerDown(locationInWindow: event.locationInWindow, sourceCell: nil, memberFolderID: nil)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let coordinator = dragCoordinator ?? DragUISessionCoordinator.shared else { return }
        coordinator.pointerDragged(locationInWindow: event.locationInWindow)

        // 系统 Launchpad 同款两阶段 move-out：离开 panel 时先视觉折叠，让用户看见
        // 顶层网格并继续拖；真正的 FolderOpenState.close 留到成功 commit。overlay 本体
        // 仍留在层级中承接既有 mouse capture，故本次 mouseUp 不会丢。
        let point = convert(event.locationInWindow, from: nil)
        let isActiveDrag = coordinator.controller.state == .dragging
            || coordinator.controller.state == .edgeTurnPending
        if isTrackingMemberDrag,
           !didRequestMemberDragExit,
           isActiveDrag,
           coordinator.controller.moveOutArmed,
           !panel.frame.contains(point) {
            didRequestMemberDragExit = true
            onMemberDragExitPanel?()
        }
    }

    public override func mouseUp(with event: NSEvent) {
        (dragCoordinator ?? DragUISessionCoordinator.shared)?
            .pointerUp(locationInWindow: event.locationInWindow)
        isTrackingMemberDrag = false
        didRequestMemberDragExit = false
        trackedMemberAppID = nil
    }

    /// 折叠前调用：把剩余成员的图标/名称拷到缓存（必须在 panel.isHidden 之前）。
    public func prepareMoveOutIconCache() {
        guard let remaining = moveOutRemainingAppID,
              let cell = moveOutRemainingMemberCell else {
            cachedMoveOutRemainingIcon = nil
            cachedMoveOutRemainingName = ""
            return
        }
        cachedMoveOutRemainingIcon = cell.iconView.image?.copy() as? NSImage ?? cell.iconView.image
        cachedMoveOutRemainingName = cell.boundName.isEmpty
            ? (memberName(remaining) ?? "")
            : cell.boundName
    }

    /// 只折叠/恢复 Folder 的可见外观，不移除 overlay，也不结束 drag 会话。
    /// 折叠后透明 overlay 继续接收当前 mouse capture；视觉宿主由装配层切到 surface。
    public func setMoveOutPresentationCollapsed(_ collapsed: Bool) {
        guard !isTornDown, collapsed != isMoveOutPresentationCollapsed else { return }
        if !collapsed {
            clearMoveOutRemainingAppProxy()
            moveOutRemainingAppID = nil
            cachedMoveOutRemainingIcon = nil
            cachedMoveOutRemainingName = ""
        }
        isMoveOutPresentationCollapsed = collapsed
        panel.isHidden = collapsed
        layer?.backgroundColor = collapsed
            ? NSColor.clear.cgColor
            : NSColor.black.withAlphaComponent(0.35).cgColor
    }

    /// 在真实顶层 Folder cell frame 上显示唯一剩余成员的 transient 代理。
    /// 代理只用于折叠期间的视觉反馈，不改变真实 cell 的 binding 或 drop geometry。
    /// `frame` 必须已经转换到 `host` 坐标系。
    public func showMoveOutRemainingAppProxy(in host: NSView, frame: NSRect) {
        guard !isTornDown, isMoveOutPresentationCollapsed,
              let remaining = moveOutRemainingAppID else { return }

        clearMoveOutRemainingAppProxy()
        let source = moveOutRemainingMemberCell
        let proxy = AppGridCellView(frame: frame)
        let token = ItemBindingToken(
            catalogRevision: 0,
            pageIdentity: PagePresentationID(revision: 0, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(remaining),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0
        )
        let name = cachedMoveOutRemainingName.isEmpty
            ? (source?.boundName.isEmpty == false ? (source?.boundName ?? "") : (memberName(remaining) ?? ""))
            : cachedMoveOutRemainingName
        proxy.bind(name: name, token: token)
        // 优先用折叠前缓存；hidden cell 的 image 可能已空。
        proxy.iconView.image = cachedMoveOutRemainingIcon ?? source?.iconView.image
        let proxyHost = MoveOutProxyHostView(frame: frame)
        proxyHost.addSubview(proxy)
        proxy.frame = proxyHost.bounds
        host.addSubview(proxyHost, positioned: .above, relativeTo: nil)
        proxy.needsLayout = true
        proxy.layoutSubtreeIfNeeded()
        moveOutProxyHost = proxyHost
        moveOutRemainingAppProxy = proxy
        if proxy.iconView.image == nil {
            let key = IconKey(identity: IconIdentity.from(appID: remaining),
                              pointSize: iconPointSize, displayScale: displayScale)
            pipeline.request(key: key, generation: surfaceGeneration) { [weak self, weak proxy] _, _, result in
                guard let self, let proxy,
                      self.moveOutRemainingAppProxy === proxy,
                      self.isMoveOutPresentationCollapsed else { return }
                if case .success(let image) = result {
                    proxy.iconView.image = image
                }
            }
        }
    }

    /// 清除折叠预览代理；幂等。
    public func clearMoveOutRemainingAppProxy() {
        moveOutProxyHost?.removeFromSuperview()
        moveOutRemainingAppProxy?.removeFromSuperview()
        moveOutProxyHost = nil
        moveOutRemainingAppProxy = nil
    }

    /// 命中测试：按钮自行处理点击；其余（成员 cell / 面板 / 遮罩）路由到本视图的 mouseDown。
    public override func hitTest(_ point: NSPoint) -> NSView? {
        // T-1F-B10-wave-a forensics census（s14）：overlay 参与 hitTest 入口计数 +
        // superview==nil 布尔位（仅计数，零行为变更）。判别「残留命中」直接证据：
        // 关闭后 overlay 已移出视图树，若 _sv1 仍递增 = 移除未生效/被重挂/孤儿仍被命中。
        ClickCensus.hit(ClickCensus.Sink.overlayHitTest(superviewIsNil: superview == nil))
        let hit = super.hitTest(point)
        if hit === prevButton || hit === nextButton {
            return hit
        }
        return self
    }

    // MARK: - 内部分页

    /// Phase 1F（T-1F-D1）：folder scope 边缘翻页入口（AppDelegate 跨模块调用 → public）。
    @objc public func prevPage() {
        onInnerPageChange?(currentInnerPage - 1)
    }

    @objc public func nextPage() {
        onInnerPageChange?(currentInnerPage + 1)
    }

    private var innerPageCount: Int {
        guard let entry = currentEntry, !entry.members.isEmpty else { return 0 }
        return (entry.members.count + membersPerPage - 1) / membersPerPage
    }

    private func members(onPage page: Int, in entry: FolderEntry) -> [AppID] {
        let start = page * membersPerPage
        guard start >= 0, start < entry.members.count else { return [] }
        let end = min(start + membersPerPage, entry.members.count)
        return Array(entry.members[start..<end])
    }

    private func remainingAppID(for dragged: AppID?) -> AppID? {
        guard let entry = currentEntry, entry.members.count == 2,
              let dragged else { return nil }
        return entry.members.first { $0 != dragged }
    }

    private func updatePageIndicator() {
        let count = innerPageCount
        if count <= 1 {
            pageIndicator.stringValue = ""
            prevButton.isHidden = true
            nextButton.isHidden = true
        } else {
            pageIndicator.stringValue = "\(currentInnerPage + 1) of \(count)"
            prevButton.isHidden = currentInnerPage == 0
            nextButton.isHidden = currentInnerPage >= count - 1
        }
    }

    // MARK: - 成员 cell 复用 + 图标异步（generation 门控）

    private func prepareMemberCells(count: Int) {
        if memberCells.count != count {
            for cell in memberCells { cell.removeFromSuperview() }
            memberCells = (0..<count).map { _ in
                let cell = AppGridCellView()
                panel.addSubview(cell)
                return cell
            }
        } else {
            for cell in memberCells { cell.clearContent() }
        }
    }

    private func memberToken(member: AppID, index: Int) -> ItemBindingToken {
        ItemBindingToken(
            catalogRevision: 0,
            pageIdentity: PagePresentationID(revision: 0, pageIndex: currentInnerPage),
            itemSlot: index,
            appID: AnyHashable(member),
            reuseGeneration: 0,
            iconKey: IconKey(identity: IconIdentity.from(appID: member),
                             pointSize: iconPointSize, displayScale: displayScale),
            surfaceGeneration: surfaceGeneration
        )
    }

    private func requestMemberIcon(key: IconKey, token: ItemBindingToken, cellIndex: Int) {
        let generation = surfaceGeneration
        pipeline.request(key: key, generation: generation) { [weak self] _, deliveredGeneration, result in
            guard let self else { return }
            guard !self.isTornDown else {
                self.observe(token, .ignoredAfterTeardown)
                return
            }
            // 快路径：视图代不匹配（已 clear/re-configure）→ 直接拒绝。
            guard deliveredGeneration == self.surfaceGeneration else {
                self.registerStale(token)
                return
            }
            switch result {
            case .success(let image):
                guard cellIndex < self.memberCells.count,
                      self.memberCells[cellIndex].applyIconIfValid(image, token: token) else {
                    self.registerStale(token)
                    return
                }
                if let proxyID = self.moveOutRemainingAppProxy?.bindingToken?.appID as? AppID,
                   let tokenID = token.appID as? AppID,
                   proxyID == tokenID {
                    self.moveOutRemainingAppProxy?.iconView.image = image
                }
                self.observe(token, .applied)
            case .failed(.cancelled):
                self.observe(token, .cancelled)
            case .failed(.loadFailed), .failed(.pipelineShutdown):
                self.observe(token, .failed)
            }
        }
    }

    private func registerStale(_ token: ItemBindingToken) {
        staleIconApplyCount += 1
        observe(token, .rejectedStale)
    }

    private func observe(_ token: ItemBindingToken, _ result: AppGridIconApplyResult) {
        onIconApplyResult?(token, result)
    }

    // MARK: - 布局（面板居中；成员网格 5 列）

    public override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        let panelW = min(max(w * 0.7, 200), 900)
        let panelH = min(max(h * 0.8, 200), 700)
        panel.frame = CGRect(x: (w - panelW) / 2, y: (h - panelH) / 2,
                             width: panelW, height: panelH)
        layoutPanel()
    }

    private func layoutPanel() {
        let pw = panel.bounds.width
        let ph = panel.bounds.height
        let inset = Self.panelInset
        let titleH = Self.titleHeight
        let footerH = Self.footerHeight

        titleLabel.frame = CGRect(x: inset, y: ph - titleH - 12, width: pw - inset * 2, height: titleH)

        let gridTop = ph - titleH - 12 - 12
        let gridBottom = footerH + 12
        let area = CGRect(x: inset, y: gridBottom, width: pw - inset * 2, height: gridTop - gridBottom)
        let columns = Self.columns
        let spacing = Self.spacing
        // 动态 pitch：让当前页全部成员行都落在网格区内（修复 T-1E 大文件夹末行被裁到面板外）。
        // 小文件夹（≤ 5 行）保持固定 88pt cellHeight（pitch 104），无视觉变化。
        let rows = (memberCells.count + columns - 1) / columns
        let pitch = min(Self.cellHeight + spacing, area.height / CGFloat(max(rows, 1)))
        let cellHeight = max(pitch - spacing, 56)
        let tileWidth = (area.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        for (index, cell) in memberCells.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = area.minX + CGFloat(column) * (tileWidth + spacing)
            let y = area.maxY - CGFloat(row + 1) * (cellHeight + spacing)
            cell.frame = CGRect(x: x, y: y, width: tileWidth, height: cellHeight)
        }

        pageIndicator.frame = CGRect(x: 0, y: 8, width: pw, height: 20)
        prevButton.frame = CGRect(x: inset, y: 8, width: 40, height: 24)
        nextButton.frame = CGRect(x: pw - inset - 40, y: 8, width: 40, height: 24)
    }
}

// MARK: - T-1F-B10-wave-a forensics census sinks（FolderOverlayView 层布点；仅命名空间声明，
// 计数机制与 env 门控沿用 `ClickCensus`，零机制改动、零行为变更）

extension ClickCensus.Sink {
    /// s14 基名：overlay 参与 hitTest 入口（`FolderOverlayView.hitTest` 首行）。
    /// 实际 sink 为基名 + `_sv1`/`_sv0` 布尔位变体（`superview == nil`），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份：无窗口标题/
    /// 无坐标/无应用名，隐私 A/B/C）。
    public static let overlayHitTestBase = "s14_overlay_hittest"

    /// s14 状态位 sink 名（superview.nil → _sv1；superview 非 nil → _sv0）。
    public static func overlayHitTest(superviewIsNil: Bool) -> String {
        "\(overlayHitTestBase)_sv\(superviewIsNil ? 1 : 0)"
    }

    /// s15：overlay.mouseDown 面板内非成员区静默 return（`FolderOverlayView.mouseDown`
    /// 面板分支成员遍历后无命中；点击被 overlay 吞掉且不留派发痕迹的位置）。
    public static let overlayMouseDownSilentReturn = "s15_overlay_mousedown_silent_return"
}
