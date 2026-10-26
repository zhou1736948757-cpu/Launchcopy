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
import LauncherLocalization

/// 文件夹打开层（open layer）：全表面遮罩 + 居中文件夹面板。
public final class FolderOverlayView: NSView, @unchecked Sendable {

    /// The material is decoration only; panel content retains event and accessibility ownership.
    private final class PanelMaterialView: NSVisualEffectView {
        var isRenderingAllowed = true {
            didSet { reconcileRenderingState() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reconcileRenderingState()
        }

        private func reconcileRenderingState() {
            // A still-mounted exit keeps glass; a detached reusable view is parked.
            state = isRenderingAllowed && window != nil ? .active : .inactive
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func accessibilityChildren() -> [Any]? { [] }
    }

    /// Transient 预览的事件隔离宿主：代理只负责绘制，不参与 AppKit hit-test。
    private final class MoveOutProxyHostView: NSView {
        // Ignoring the host alone would still export its named image cells.
        override func accessibilityChildren() -> [Any]? { [] }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// 开/关与内部分页动画参数（纯值；测试断言 Reduce Motion 路径）。
    ///
    /// 来源类别：`PRODUCT_DECISION`（标准开/关/翻页动画）/ `ACCESSIBILITY_REQUIREMENT`
    /// （Reduce Motion 下减少大位移/缩放）。注册于 `Workflow/results/T-1E-C.md`。
    public struct MotionParams: Equatable, Sendable {
        public let duration: TimeInterval
        public let exitDuration: TimeInterval
        public let scale: CGFloat
        public let displacement: CGFloat

        public init(duration: TimeInterval, scale: CGFloat, displacement: CGFloat,
                    exitDuration: TimeInterval? = nil) {
            self.duration = duration
            self.exitDuration = exitDuration ?? duration
            self.scale = scale
            self.displacement = displacement
        }

        /// 标准动画：短时 + 轻微缩放 + 轻微位移（非 RM）。
        // Fixed scale/displacement stay neutral; the source glyph determines actual travel.
        public static let standard = MotionParams(duration: 0.24, scale: 1, displacement: 0, exitDuration: 0.20)
        /// Reduce Motion：短时透明度淡入/淡出；调用方保持 identity transform。
        public static let reduceMotion = MotionParams(duration: 0.18, scale: 1.0, displacement: 0.0)

        /// 按 Reduce Motion 标志选择动画参数。
        public static func forReduceMotion(_ reduce: Bool) -> MotionParams {
            reduce ? .reduceMotion : .standard
        }
    }

    // MARK: - 回调（装配层接线；测试观察）

    /// 成员激活（→ 装配层复用 AppLaunchController 启动成员 app）。
    public var onActivateMember: ((AppID) -> Void)?
    /// Application-owned menu factory; changing it leaves member bindings and icons intact.
    /// Capture application owners weakly. Exit visuals and drawing-only proxies are inert.
    public var appContextMenuProvider: ((AppGridCellView) -> NSMenu?)? {
        didSet {
            for cell in memberCells { connectContextMenu(to: cell) }
            moveOutRemainingAppProxy?.appContextMenuProvider = nil
        }
    }
    /// 请求关闭文件夹（点击面板外 / 关闭按钮；只关闭文件夹，不退出 app）。
    public var onRequestClose: (() -> Void)?
    /// Signals the application owner to begin editing; this view performs no persistence or focus change.
    public var onRequestTitleEdit: (() -> Void)? {
        didSet { updateTitleEditPresentation() }
    }
    public var titleEditingEnabled = true {
        didSet { if titleEditingEnabled != oldValue { updateTitleEditPresentation() } }
    }
    /// Cancels an application-owned session before lifecycle cleanup removes its mounted editor.
    /// The owner must cancel before its own lifecycle/responder changes as well. Drawing-only exit
    /// visuals never call this callback. Explicit unmount after commit/cancel does not call it.
    public var onWillInvalidateTitleEditor: (() -> Void)?
    /// 成员拖拽越过 panel 边界并已满足 move-out 阈值：请求装配层折叠 Folder 视觉，
    /// 但保持 overlay 在视图树中继续接收本次 mouseDragged/mouseUp。
    public var onMemberDragExitPanel: (() -> Void)?
    /// 内部分页变更（→ 装配层写回 FolderOpenState.setInnerPage）。
    public var onInnerPageChange: ((Int) -> Void)?
    /// Application-owned input admission; rejected folder scrolls are still consumed.
    public var canBeginTrackpadPaging: (() -> Bool)?
    public var onTrackpadPagingActivity: ((Bool) -> Void)?
    public var isTrackpadPagingActive: Bool { innerPager?.isActive == true }
    internal var trackpadVisualPageCount: Int { swipePageHosts.count }
    internal func trackpadVisualFrame(for page: Int) -> NSRect? { swipePageHosts[page]?.frame }
    private var innerPager: FolderPagingController?
    private var swipeViewport: MoveOutProxyHostView?
    private var swipePageHosts: [Int: NSView] = [:]
    private var swipeVisualGeneration: UInt64 = 0
    private var swipePageWidth: CGFloat = 0
    private var swipeLayoutBounds: NSRect = .zero
    private var swipeCellFrames: [NSRect] = []
    private var swipeMemberNames: [AppID: String] = [:]
    private var swipeEntry: FolderEntry?

    /// Exposed for deterministic input/frame tests; production uses the demand-driven clock.
    public var trackpadPager: FolderPagingController {
        if let innerPager { return innerPager }
        let pager = FolderPagingController()
        pager.onOffsetChange = { [weak self] offset in self?.renderTrackpadOffset(offset) }
        pager.onCommit = { [weak self] page in
            guard let self, !self.isTornDown, !self.isVisualOnly else { return }
            self.finishTrackpadPresentation()
            self.onInnerPageChange?(page)
        }
        pager.onActivityChange = { [weak self] active in
            guard let self else { return }
            if !active { self.finishTrackpadPresentation() }
            self.updateTitleEditPresentation()
            self.onTrackpadPagingActivity?(active)
        }
        innerPager = pager
        return pager
    }

    /// 成员图标异步 apply 结果观察（测试 + telemetry 合成；无字节/哈希/路径/身份原文）。
    public var onIconApplyResult: ((ItemBindingToken, AppGridIconApplyResult) -> Void)?

    /// Optional local observer, never an input owner. Production leaves this nil.
    public enum DropDiagnosticEvent: Sendable {
        case willRelease(eventTimestamp: TimeInterval, observedAt: TimeInterval)
        case didRelease(observedAt: TimeInterval, readyIcons: Int, visibleMembers: Int)
        case willDraw(observedAt: TimeInterval)
    }
    public var onDropDiagnosticEvent: ((DropDiagnosticEvent) -> Void)?

    /// Callback bundle retained while the view is used as a drawing-only exit visual.
    /// Keeping the callbacks out of the live view makes the visual state inert even if a
    /// stale event reaches the retained view before AppKit has removed it from the hierarchy.
    private struct InteractionCallbacks {
        let onActivateMember: ((AppID) -> Void)?
        let onRequestClose: (() -> Void)?
        let onRequestTitleEdit: (() -> Void)?
        let onWillInvalidateTitleEditor: (() -> Void)?
        let onMemberDragExitPanel: (() -> Void)?
        let onInnerPageChange: ((Int) -> Void)?
        let onIconApplyResult: ((ItemBindingToken, AppGridIconApplyResult) -> Void)?
    }

    /// Phase 1F（T-1F-D1）：拖拽协调器（装配层注入；nil = 无 drag 仲裁 → 既有点击路径不变）。
    public weak var dragCoordinator: DragUISessionCoordinator?

    /// Member and proxy display policy; headings, paging and bindings remain intact.
    public var itemAppearance: GridItemAppearance = .default {
        didSet {
            guard !isTornDown, !isVisualOnly else { itemAppearance = oldValue; return }
            guard itemAppearance.isValid else {
                itemAppearance = oldValue
                return
            }
            guard itemAppearance != oldValue else { return }
            for cell in memberCells { cell.itemAppearance = itemAppearance }
            moveOutRemainingAppProxy?.itemAppearance = itemAppearance
        }
    }

    /// Member and move-out captions follow this policy; the folder title remains visible.
    public var showsAppLabels: Bool = true {
        didSet {
            guard !isTornDown, !isVisualOnly else { showsAppLabels = oldValue; return }
            guard showsAppLabels != oldValue else { return }
            for cell in memberCells { cell.showsAppLabels = showsAppLabels }
            moveOutRemainingAppProxy?.showsAppLabels = showsAppLabels
        }
    }

    // MARK: - 状态（测试/诊断）

    /// 视图生命周期代（每次 configure/clearContent/teardown bump；成员图标门控）。
    public private(set) var surfaceGeneration: UInt64 = 0
    /// 是否已 teardown（此后零 UI 写回）。
    public private(set) var isTornDown = false
    /// 是否处于仅绘制模式（退出动画期间不参与命中、输入、无障碍或异步 UI 写回）。
    public private(set) var isVisualOnly = false
    /// 已投递但被门控拒绝的成员图标 apply 计数（stale result rejected）。
    public private(set) var staleIconApplyCount = 0
    /// 当前呈现的文件夹条目（nil = 未配置/已清空）。
    public private(set) var currentEntry: FolderEntry?
    /// 当前内部页（0-based）。
    public private(set) var currentInnerPage = 0
    private var currentCatalogRevision: UInt64 = 0
    /// 当前 Reduce Motion 标志。
    public private(set) var reduceMotion = false
    private var reduceTransparency = false
    private var increaseContrast = false
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
        if let displayedStrings { proxy.relabel(strings: displayedStrings) }
        proxy.itemAppearance = itemAppearance
        proxy.showsAppLabels = showsAppLabels
        proxy.isAppContextMenuEnabled = false
        proxy.appContextMenuProvider = nil
    }
    /// 每页成员数（装配层与 FolderOpenState 对齐）。
    public var membersPerPage: Int = FolderOpenState.defaultMembersPerPage

    /// One application-owned snapshot drives drawing, paging and keyboard geometry.
    /// Nil retains the legacy standalone view contract for existing clients.
    public private(set) var appliedFolderLayout: FolderLayoutSnapshot?
    public private(set) var isMemberPresentationAvailable = true
    private var configuredMembersPerPage = 0
    private var deferredEditorLayout: FolderLayoutSnapshot?

    public func applyFolderLayout(_ snapshot: FolderLayoutSnapshot) {
        guard !isTornDown, !isVisualOnly else { return }
        let changed = appliedFolderLayout != snapshot
        if changed { cancelTrackpadPaging() }
        appliedFolderLayout = snapshot
        deferredEditorLayout = nil
        membersPerPage = snapshot.capacity
        setMemberPresentationAvailable(snapshot.canPresentMembers)
        if changed { needsLayout = true }
    }

    /// A pending unsafe reflow must not leave invisible members actionable.
    public func setMemberPresentationAvailable(_ available: Bool) {
        guard !isTornDown, !isVisualOnly else { return }
        if !available { cancelTrackpadPaging() }
        isMemberPresentationAvailable = available
        for cell in memberCells {
            cell.isHidden = !available || swipeViewport != nil
            cell.isAppContextMenuEnabled = available
            if !available { cell.setFocused(false) }
        }
        insufficientSpaceLabel.isHidden = available || titleEditorView != nil
        closeButton.isHidden = available
        updatePageIndicator()
    }

    /// Resize the chrome around the same mounted editor without reconfiguring content.
    /// Native field-editor selection/composition and the frozen member indices survive.
    public func constrainMountedTitleEditor(using snapshot: FolderLayoutSnapshot?) {
        guard titleEditorView != nil, !isVisualOnly, !isTornDown else { return }
        deferredEditorLayout = snapshot
        needsLayout = true
    }

    /// 成员 cell 数（测试/诊断）。
    public var memberCellCount: Int { memberCells.count }

    /// 当前拖出成员仍在打开层中的 cell；用于复用现有 name/icon 作为折叠代理。
    public var moveOutRemainingMemberCell: AppGridCellView? {
        guard let remaining = moveOutRemainingAppID else { return nil }
        return memberCells.first { $0.bindingToken?.appID as? AppID == remaining }
    }

    /// 面板 frame（overlay 坐标系；测试/诊断）。
    public var panelFrame: NSRect { panel.frame }
    /// Stable visual surface for owner-controlled transitions. Modal coverage remains untransformed.
    public var motionPresentationView: NSView { panel }
    public private(set) var isPanelTransitionActive = false

    /// Suppress settled-coordinate pointer targets while the panel is moving.
    /// Outside close and application-owned keyboard cancellation remain available.
    public func setPanelTransitionActive(_ active: Bool) {
        guard !isTornDown, !isVisualOnly, active != isPanelTransitionActive else { return }
        isPanelTransitionActive = active
        if active { cancelTrackpadPaging() }
        updateTitleEditPresentation()
        prevButton.isEnabled = !active
        nextButton.isEnabled = !active
    }


    /// The real panel, with the title frame expressed in this host's coordinates.
    public var titleEditorHostView: NSView { panel }
    public var titleEditorFrame: NSRect {
        let slot = titleLabel.frame
        guard let field = titleEditorView as? NSTextField, slot.width > 0, slot.height > 0 else { return slot }
        let font = field.font ?? titleLabel.font ?? .systemFont(ofSize: 22, weight: .semibold)
        let draft = field.currentEditor()?.string ?? field.stringValue
        let measured = (draft as NSString).size(withAttributes: [.font: font])
        let width = min(slot.width, max(44, ceil(measured.width) + 24))
        let height = min(slot.height, ceil(font.ascender - font.descender + font.leading) + 10)
        return NSRect(x: slot.midX - width / 2, y: slot.midY - height / 2, width: width, height: height)
    }
    public private(set) var titleEditorView: NSView?
    /// A real target/action control over the existing title drawing, preserving its typography.
    public let titleEditButton = NSButton()

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
        guard isMemberPresentationAvailable, !isVisualOnly, !isTornDown else { return [] }
        return memberCells.compactMap { cell in
            guard let token = cell.bindingToken else { return nil }
            let frameInHost = cell.convert(cell.bounds, to: host)
            let rect = DragRect(x: Double(frameInHost.minX), y: Double(frameInHost.minY),
                                width: Double(frameInHost.width), height: Double(frameInHost.height))
            guard let appID = token.appID as? AppID,
                  let record = catalog?.records.first(where: { $0.id == appID }) else { return nil }
            return DragItemFrame(identity: .app(PersistentAppReference.from(record: record)), frame: rect)
        }
    }

    private var displayedStrings: LocalizedStrings?

    /// Frozen exits keep their sampled text. Live members/proxies retain bindings and icons.
    public func relabel(strings: LocalizedStrings) {
        guard !isTornDown, !isVisualOnly else { return }
        displayedStrings = strings
        for cell in memberCells { cell.relabel(strings: strings) }
        moveOutRemainingAppProxy?.relabel(strings: strings)
        prevButton.setAccessibilityLabel(strings.gridText(.previousPage))
        nextButton.setAccessibilityLabel(strings.gridText(.nextPage))
        insufficientSpaceLabel.stringValue = strings.gridText(.folderInsufficientSpace)
        closeButton.title = strings.gridText(.closeFolder)
        updateTitleEditPresentation()
        updatePageIndicator()
    }

    private func gridText(_ key: GridTextKey) -> String {
        displayedStrings?.gridText(key) ?? key.englishFallback
    }

    private let pipeline: IconPipeline
    private let iconPointSize: Double
    private let displayScale: Double
    private var memberCells: [AppGridCellView] = []
    private let panel = NSView()
    private let panelMaterial = PanelMaterialView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let pageIndicator = NSTextField(labelWithString: "")
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let insufficientSpaceLabel = NSTextField(wrappingLabelWithString: "")
    private let closeButton = NSButton()
    private var memberName: (AppID) -> String? = { _ in nil }
    private var isTrackingMemberDrag = false
    private var didRequestMemberDragExit = false
    private var trackedMemberAppID: AppID?
    private var moveOutProxyHost: MoveOutProxyHostView?
    private var suspendedInteractionCallbacks: InteractionCallbacks?
    private var isInvalidatingTitleEditor = false

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
        layer?.backgroundColor = NSColor.clear.cgColor

        panel.wantsLayer = true
        panel.layer?.cornerRadius = 12
        panel.layer?.backgroundColor = NSColor.clear.cgColor
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(panel)

        // Keep the editor/content host stable. One native backdrop samples only this window;
        // foreground cells and text are siblings above it, not blurred descendants.
        panelMaterial.material = .popover
        panelMaterial.blendingMode = .withinWindow
        panelMaterial.state = .inactive
        panelMaterial.wantsLayer = true
        panelMaterial.layer?.cornerRadius = 12
        panelMaterial.layer?.masksToBounds = true
        panelMaterial.autoresizingMask = [.width, .height]
        panelMaterial.setAccessibilityElement(false)
        panel.addSubview(panelMaterial, positioned: .below, relativeTo: nil)

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        panel.addSubview(titleLabel)

        titleEditButton.isBordered = false
        titleEditButton.isTransparent = true
        titleEditButton.font = titleLabel.font
        titleEditButton.target = self
        titleEditButton.action = #selector(requestTitleEdit(_:))
        titleEditButton.setAccessibilityIdentifier("folder-title-edit")
        titleEditButton.setAccessibilityRole(.button)
        panel.addSubview(titleEditButton)
        updateTitleEditPresentation()

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
        prevButton.setAccessibilityLabel(gridText(.previousPage))
        nextButton.setAccessibilityLabel(gridText(.nextPage))
        panel.addSubview(prevButton)
        panel.addSubview(nextButton)

        insufficientSpaceLabel.stringValue = gridText(.folderInsufficientSpace)
        insufficientSpaceLabel.alignment = .center
        insufficientSpaceLabel.isHidden = true
        panel.addSubview(insufficientSpaceLabel)
        closeButton.title = gridText(.closeFolder)
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeForInsufficientSpace)
        closeButton.isHidden = true
        panel.addSubview(closeButton)

        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Applies independent accessibility material flags without rebinding content or icons.
    /// Retained exit visuals and torn-down views ignore updates, including stored policy changes.
    public func applyMaterialPolicy(reduceTransparency: Bool, increaseContrast: Bool) {
        guard !isTornDown, !isVisualOnly else { return }
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        layer?.backgroundColor = isMoveOutPresentationCollapsed
            ? NSColor.clear.cgColor : materialBackdropColor
        let needsOpaquePanel = reduceTransparency || increaseContrast
        panelMaterial.isHidden = needsOpaquePanel
        updatePanelMaterialRendering()
        panel.layer?.backgroundColor = needsOpaquePanel
            ? NSColor.windowBackgroundColor.withAlphaComponent(1).cgColor
            : NSColor.clear.cgColor
        panel.layer?.borderColor = increaseContrast
            ? NSColor.labelColor.cgColor : NSColor.separatorColor.cgColor
        panel.layer?.borderWidth = increaseContrast ? 2 : 1
        pageIndicator.textColor = increaseContrast ? .labelColor : .secondaryLabelColor
    }

    private func updatePanelMaterialRendering() {
        panelMaterial.isRenderingAllowed = !isTornDown && !isMoveOutPresentationCollapsed
            && !reduceTransparency && !increaseContrast
    }

    private var materialBackdropColor: CGColor {
        // Only the panel is animated/material-treated. A full-window dim would
        // reintroduce the user-rejected dark pulse, including under Reduce Transparency.
        NSColor.clear.cgColor
    }

    /// Switches the live overlay between interactive and drawing-only presentation.
    ///
    /// Pointer close retains this exact view so its already-rendered subviews remain faithful to
    /// the sampled presentation transform. While visual-only, callbacks and late icon results are
    /// suppressed; interactive resume rebinds the current members to invalidate any result that
    /// arrived while the view was frozen.
    public func setVisualOnly(_ visualOnly: Bool) {
        guard !isTornDown, visualOnly != isVisualOnly else { return }

        if visualOnly {
            cancelTrackpadPaging()
            invalidateTitleEditor()
            suspendedInteractionCallbacks = InteractionCallbacks(
                onActivateMember: onActivateMember,
                onRequestClose: onRequestClose,
                onRequestTitleEdit: onRequestTitleEdit,
                onWillInvalidateTitleEditor: onWillInvalidateTitleEditor,
                onMemberDragExitPanel: onMemberDragExitPanel,
                onInnerPageChange: onInnerPageChange,
                onIconApplyResult: onIconApplyResult)
            onActivateMember = nil
            onRequestClose = nil
            onRequestTitleEdit = nil
            onWillInvalidateTitleEditor = nil
            onMemberDragExitPanel = nil
            onInnerPageChange = nil
            onIconApplyResult = nil
        } else {
            let callbacks = suspendedInteractionCallbacks
            onActivateMember = callbacks?.onActivateMember
            onRequestClose = callbacks?.onRequestClose
            onRequestTitleEdit = callbacks?.onRequestTitleEdit
            onWillInvalidateTitleEditor = callbacks?.onWillInvalidateTitleEditor
            onMemberDragExitPanel = callbacks?.onMemberDragExitPanel
            onInnerPageChange = callbacks?.onInnerPageChange
            onIconApplyResult = callbacks?.onIconApplyResult
            suspendedInteractionCallbacks = nil
        }

        isVisualOnly = visualOnly
        setAccessibilityElement(!visualOnly)
        if visualOnly {
            setAccessibilityFocused(false)
        }
        titleLabel.setAccessibilityElement(!visualOnly)
        updateTitleEditPresentation()
        pageIndicator.setAccessibilityElement(!visualOnly)
        prevButton.setAccessibilityElement(!visualOnly)
        nextButton.setAccessibilityElement(!visualOnly)
        for cell in memberCells {
            // The parent excludes the frozen subtree. Preserve native member
            // exposure rather than adding a second named wrapper on resume.
            cell.isAppContextMenuEnabled = !visualOnly
            if visualOnly { cell.setAccessibilityFocused(false) }
        }

        if !visualOnly {
            rebindCurrentMembersAfterVisualResume()
        }
    }

    /// Keep the retained drawing-only subtree out without replacing AppKit's
    /// automatic children permanently when the same overlay becomes live again.
    public override func accessibilityChildren() -> [Any]? {
        if isVisualOnly { return [] }
        if !isMemberPresentationAvailable {
            return [titleEditorView ?? titleLabel, insufficientSpaceLabel, closeButton].filter { !$0.isHidden }
        }
        return super.accessibilityChildren()
    }

    // MARK: - 配置 / 清空 / teardown

    /// 配置打开层：渲染标题 + 当前内部页成员网格 + 分页指示。
    /// 幂等：同 entry + 同 innerPage + 同 reduceMotion → 无操作（不重复请求图标）。
    /// 成员图标异步请求，surfaceGeneration 门控写回。
    /// A non-idempotent refresh invalidates the mounted editor before changing its presentation.
    public func configure(entry: FolderEntry, innerPage: Int, reduceMotion: Bool,
                          catalogRevision: UInt64 = 0,
                          memberName: @escaping (AppID) -> String?) {
        guard !isTornDown, !isVisualOnly else { return }
        // 活跃 move-out 期间普通 refresh 不得把已折叠视觉重新展开或清掉代理。
        if isMoveOutPresentationCollapsed && isTrackingMemberDrag { return }
        let retainedIcons = retainedIconsForReorder(to: entry, innerPage: innerPage,
            catalogRevision: catalogRevision, reduceMotion: reduceMotion)
        setMoveOutPresentationCollapsed(false)
        moveOutRemainingAppID = nil
        trackedMemberAppID = nil
        if entry == currentEntry, innerPage == currentInnerPage, reduceMotion == self.reduceMotion,
           catalogRevision == currentCatalogRevision, configuredMembersPerPage == membersPerPage {
            return  // 幂等：状态未变，不重复渲染/请求
        }
        cancelTrackpadPaging()
        invalidateTitleEditor()
        surfaceGeneration &+= 1
        self.currentEntry = entry
        self.currentInnerPage = innerPage
        self.currentCatalogRevision = catalogRevision
        self.reduceMotion = reduceMotion
        self.memberName = memberName
        configuredMembersPerPage = membersPerPage
        titleLabel.stringValue = entry.title
        updateTitleEditPresentation()
        setAccessibilityLabel(entry.title)

        let members = members(onPage: innerPage, in: entry)
        prepareMemberCells(count: members.count)
        for (index, member) in members.enumerated() {
            let token = memberToken(member: member, index: index)
            memberCells[index].bind(name: memberName(member), token: token)
            if let retained = retainedIcons[member], retained.key == token.iconKey {
                // Commit pixels with the new identity/order, without waiting for even a cached
                // asynchronous delivery. Fresh results still pass the normal complete token gate.
                memberCells[index].applyIconIfValid(retained.image, token: token)
            }
            if let key = token.iconKey {
                requestMemberIcon(key: key, token: token, cellIndex: index)
            }
        }
        updatePageIndicator()
        setMemberPresentationAvailable(isMemberPresentationAvailable)
        needsLayout = true
    }

    /// 清空打开层（复用/关闭路径）：generation bump 作废在途成员图标；清空标题/成员。
    public func clearContent() {
        guard !isTornDown else { return }
        cancelTrackpadPaging()
        isPanelTransitionActive = false
        prevButton.isEnabled = true
        nextButton.isEnabled = true
        invalidateTitleEditor()
        // Cleanup also runs after a retained exit visual has been removed. In that state
        // setMoveOutPresentationCollapsed(false) is intentionally unavailable, so restore the
        // presentation state directly instead of leaving the panel hidden for the next reuse.
        restoreMoveOutPresentation()
        surfaceGeneration &+= 1
        currentEntry = nil
        currentInnerPage = 0
        titleLabel.stringValue = ""
        updateTitleEditPresentation()
        setAccessibilityLabel("")
        for cell in memberCells { cell.clearContent() }
        updatePageIndicator()
        needsLayout = true
    }

    /// teardown：此后零 UI 写回（成员图标回调 → .ignoredAfterTeardown）；释放全部成员 cell。
    public func teardown() {
        guard !isTornDown else { return }
        cancelTrackpadPaging()
        innerPager?.tearDown()
        onTrackpadPagingActivity = nil
        canBeginTrackpadPaging = nil
        invalidateTitleEditor()
        // Preserve the icon observer so an already-in-flight request can report
        // .ignoredAfterTeardown. If the view is currently visual-only, interaction callbacks stay
        // suppressed; only the observer is restored for the terminal diagnostic result.
        if isVisualOnly {
            onIconApplyResult = suspendedInteractionCallbacks?.onIconApplyResult
            suspendedInteractionCallbacks = nil
        }
        isTornDown = true
        onDropDiagnosticEvent = nil
        isPanelTransitionActive = false
        panelMaterial.isHidden = true
        updatePanelMaterialRendering()
        onRequestTitleEdit = nil
        onWillInvalidateTitleEditor = nil
        restoreMoveOutPresentation()
        moveOutRemainingAppID = nil
        trackedMemberAppID = nil
        isTrackingMemberDrag = false
        didRequestMemberDragExit = false
        surfaceGeneration &+= 1
        currentEntry = nil
        currentInnerPage = 0
        for cell in memberCells {
            cell.invalidatePendingText()
            cell.removeFromSuperview()
        }
        memberCells.removeAll()
        titleLabel.stringValue = ""
        updateTitleEditPresentation()
        setAccessibilityLabel("")
    }

    // MARK: - Application-owned title editor host

    private var canRequestTitleEdit: Bool {
        !isTornDown && !isVisualOnly && !isMoveOutPresentationCollapsed
            && !isPanelTransitionActive && !isTrackpadPagingActive && !isInvalidatingTitleEditor && titleEditingEnabled && currentEntry != nil && titleEditorView == nil
    }

    @objc public func requestTitleEdit(_ sender: Any?) {
        guard canRequestTitleEdit else { return }
        onRequestTitleEdit?()
    }

    /// Mount before making the editor first responder. This method never changes the responder.
    /// Rejects inactive hosts, replacement of a live editor and views owned by another host/window.
    @discardableResult
    public func mountTitleEditor(_ view: NSView) -> Bool {
        guard !isTornDown, !isVisualOnly, !isMoveOutPresentationCollapsed,
              !isInvalidatingTitleEditor, titleEditingEnabled, currentEntry != nil else { return false }
        if let mounted = titleEditorView { return mounted === view }
        guard view !== self, view !== panel, !isDescendant(of: view),
              view.superview == nil else { return false }
        cancelTrackpadPaging()
        layoutSubtreeIfNeeded()
        titleEditorView = view
        panel.addSubview(view)
        view.frame = titleEditorFrame
        updateTitleEditPresentation()
        return true
    }

    /// Owner calls this after finishing/cancelling its session; no application callback or focus change.
    public func unmountTitleEditor() {
        let editor = titleEditorView
        titleEditorView = nil
        deferredEditorLayout = nil
        editor?.removeFromSuperview()
        updateTitleEditPresentation()
        insufficientSpaceLabel.isHidden = isMemberPresentationAvailable
    }

    private func invalidateTitleEditor() {
        guard titleEditorView != nil, !isInvalidatingTitleEditor else { return }
        isInvalidatingTitleEditor = true
        // Cancellation must precede removal, which can otherwise trigger focus-loss commit.
        if !isVisualOnly && !isTornDown { onWillInvalidateTitleEditor?() }
        unmountTitleEditor()
        isInvalidatingTitleEditor = false
        updateTitleEditPresentation()
    }

    private func updateTitleEditPresentation() {
        titleLabel.isHidden = titleEditorView != nil
        titleLabel.setAccessibilityElement(!isTornDown && !isVisualOnly && titleEditorView == nil)
        titleEditButton.title = currentEntry?.title ?? ""
        titleEditButton.toolTip = currentEntry == nil ? nil : gridText(.renameFolder)
        titleEditButton.setAccessibilityLabel(currentEntry.map { gridText(.renameFolderPrefix) + $0.title } ?? gridText(.renameFolder))
        titleEditButton.isHidden = currentEntry == nil || titleEditorView != nil
        titleEditButton.isEnabled = canRequestTitleEdit && onRequestTitleEdit != nil
        titleEditButton.setAccessibilityElement(canRequestTitleEdit)
    }

    // MARK: - 点击处理（面板外 → 关闭；成员 → 激活）

    /// Left clicks remain routed through this overlay; context lookup delegates only the
    /// existing icon hit region to the current member cell, without activating it.
    public override func menu(for event: NSEvent) -> NSMenu? {
        cancelTrackpadPaging()
        guard isMemberPresentationAvailable, !isTornDown, !isVisualOnly, !isPanelTransitionActive, !isMoveOutPresentationCollapsed,
              currentEntry != nil else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        guard panel.frame.contains(point) else { return nil }
        let panelPoint = panel.convert(point, from: self)
        guard let cell = memberCells.first(where: { $0.frame.contains(panelPoint) }) else { return nil }
        return cell.menu(for: event)
    }

    /// 处理一次点击（测试直接调用；mouseDown 委托）。
    /// - 面板外（遮罩区）→ onRequestClose（只关闭文件夹）。
    /// - 面板内成员 cell → onActivateMember。
    /// - 面板内非成员区（标题/页脚）→ 忽略。
    public func handleClick(at point: NSPoint) {
        cancelTrackpadPaging()
        guard !isVisualOnly, !isTornDown else { return }
        if panel.frame.contains(point) {
            guard isMemberPresentationAvailable, !isPanelTransitionActive else { return }
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
        PointerInputDiagnostics.record(.overlayDown)
        guard !isVisualOnly else { return }
        cancelTrackpadPaging()
        let coordinator = dragCoordinator ?? DragUISessionCoordinator.shared
        guard let coordinator else {
            handleClick(at: convert(event.locationInWindow, from: nil))
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if panel.frame.contains(point) {
            guard isMemberPresentationAvailable else { PointerInputDiagnostics.record(.overlayUnavailableDenied); return }
            guard !isPanelTransitionActive else { PointerInputDiagnostics.record(.overlayTransitionDenied); return }
            let panelPoint = panel.convert(point, from: self)
            for (index, cell) in memberCells.enumerated() where cell.frame.contains(panelPoint) {
                PointerInputDiagnostics.record(.overlayMember)
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
            PointerInputDiagnostics.record(.overlayNonMember)
            ClickCensus.hit(ClickCensus.Sink.overlayMouseDownSilentReturn)
            return
        }
        isTrackingMemberDrag = false
        PointerInputDiagnostics.record(.overlayBlank)
        coordinator.pointerDown(locationInWindow: event.locationInWindow, sourceCell: nil, memberFolderID: nil)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard !isVisualOnly else { return }
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
            if isMoveOutPresentationCollapsed {
                // Reclassify the same native event against the now-visible main grid.
                // Waiting for a second move leaves an invisible-member marker on release.
                coordinator.pointerDragged(locationInWindow: event.locationInWindow)
            }
        }
    }

    public override func mouseUp(with event: NSEvent) {
        guard !isVisualOnly, !isTornDown else { return }
        let diagnostics = onDropDiagnosticEvent
        if let diagnostics {
            diagnostics(.willRelease(eventTimestamp: event.timestamp,
                                     observedAt: ProcessInfo.processInfo.systemUptime))
        }
        (dragCoordinator ?? DragUISessionCoordinator.shared)?
            .pointerUp(locationInWindow: event.locationInWindow)
        isTrackingMemberDrag = false
        didRequestMemberDragExit = false
        trackedMemberAppID = nil
        if let diagnostics {
            diagnostics(.didRelease(observedAt: ProcessInfo.processInfo.systemUptime,
                readyIcons: memberCells.filter { $0.iconView.image != nil }.count,
                visibleMembers: memberCells.count))
        }
    }

    public override func viewWillDraw() {
        super.viewWillDraw()
        if !isVisualOnly, !isTornDown, let diagnostics = onDropDiagnosticEvent {
            // Pre-draw notification only: this is not a compositor/scanout acknowledgement.
            diagnostics(.willDraw(observedAt: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// 折叠前调用：把剩余成员的图标/名称拷到缓存（必须在 panel.isHidden 之前）。
    public func prepareMoveOutIconCache() {
        guard !isVisualOnly else { return }
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
        guard !isTornDown, !isVisualOnly, collapsed != isMoveOutPresentationCollapsed else { return }
        if !collapsed {
            restoreMoveOutPresentation()
            return
        }
        cancelTrackpadPaging()
        isMoveOutPresentationCollapsed = collapsed
        invalidateTitleEditor()
        updateTitleEditPresentation()
        panel.isHidden = collapsed
        updatePanelMaterialRendering()
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// Restores the live move-out presentation state without consulting `isVisualOnly`.
    /// Retained exit visuals use the same view instance and must be fully reset before reuse or
    /// teardown, even though their public interaction mutators are disabled while frozen.
    private func restoreMoveOutPresentation() {
        clearMoveOutRemainingAppProxy()
        moveOutRemainingAppID = nil
        cachedMoveOutRemainingIcon = nil
        cachedMoveOutRemainingName = ""
        trackedMemberAppID = nil
        isTrackingMemberDrag = false
        didRequestMemberDragExit = false
        isMoveOutPresentationCollapsed = false
        updateTitleEditPresentation()
        panel.isHidden = false
        updatePanelMaterialRendering()
        layer?.backgroundColor = materialBackdropColor
    }

    /// 在真实顶层 Folder cell frame 上显示唯一剩余成员的 transient 代理。
    /// 代理只用于折叠期间的视觉反馈，不改变真实 cell 的 binding 或 drop geometry。
    /// `frame` 必须已经转换到 `host` 坐标系。
    public func showMoveOutRemainingAppProxy(in host: NSView, frame: NSRect) {
        guard !isTornDown, !isVisualOnly, isMoveOutPresentationCollapsed,
              let remaining = moveOutRemainingAppID else { return }

        clearMoveOutRemainingAppProxy()
        let source = moveOutRemainingMemberCell
        let proxy = AppGridCellView(frame: frame)
        if let displayedStrings { proxy.relabel(strings: displayedStrings) }
        proxy.itemAppearance = itemAppearance
        proxy.showsAppLabels = showsAppLabels
        proxy.isAppContextMenuEnabled = false
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
            let requestGeneration = surfaceGeneration
            let requestBinding = proxy.bindingToken
            pipeline.request(key: key, generation: requestGeneration) { [weak self, weak proxy] deliveredKey, generation, result in
                guard let self, let proxy, !self.isTornDown, !self.isVisualOnly,
                      generation == requestGeneration, self.surfaceGeneration == requestGeneration,
                      deliveredKey == key, proxy.bindingToken == requestBinding,
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
        guard !isTornDown, !isVisualOnly else { return nil }
        // T-1F-B10-wave-a forensics census（s14）：overlay 参与 hitTest 入口计数 +
        // superview==nil 布尔位（仅计数，零行为变更）。判别「残留命中」直接证据：
        // 关闭后 overlay 已移出视图树，若 _sv1 仍递增 = 移除未生效/被重挂/孤儿仍被命中。
        ClickCensus.hit(ClickCensus.Sink.overlayHitTest(superviewIsNil: superview == nil))
        if isPanelTransitionActive { return self }
        let hit = super.hitTest(point)
        if let editor = titleEditorView, !isMoveOutPresentationCollapsed,
           let hit, hit === editor || hit.isDescendant(of: editor) {
            return hit
        }
        if hit === titleEditButton, canRequestTitleEdit { return hit }
        if hit === closeButton { return hit }
        if hit === prevButton || hit === nextButton {
            return hit
        }
        return self
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { cancelTrackpadPaging() }
        super.viewWillMove(toWindow: newWindow)
    }

    // MARK: - Folder-local direct manipulation

    /// Never call super: even ignored/blocked input belongs to the open modal folder.
    public override func scrollWheel(with event: NSEvent) {
        handleTrackpadScroll(phase: event.phase, momentumPhase: event.momentumPhase,
                             deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                             isDirectionInverted: event.isDirectionInvertedFromDevice,
                             timestamp: event.timestamp)
    }

    public func handleTrackpadScroll(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                                    deltaX: CGFloat, deltaY: CGFloat,
                                    isDirectionInverted: Bool, timestamp: TimeInterval) {
        guard !isTornDown, !isVisualOnly, !isPanelTransitionActive, !isMoveOutPresentationCollapsed,
              currentEntry != nil, isMemberPresentationAvailable, titleEditorView == nil,
              !isTrackingMemberDrag,
              (dragCoordinator ?? DragUISessionCoordinator.shared)?.isSessionActive != true,
              canBeginTrackpadPaging?() != false else {
            cancelTrackpadPaging()
            return
        }
        guard innerPageCount > 1 else { return }
        layoutSubtreeIfNeeded()
        let area = trackpadGridFrame
        guard area.width > 0, area.height > 0 else { return }
        let pager = trackpadPager
        if !pager.isActive {
            pager.configure(pageCount: innerPageCount, pageWidth: Double(area.width),
                            currentPage: currentInnerPage, reduceMotion: reduceMotion)
        }
        pager.handleScroll(phase: phase, momentumPhase: momentumPhase,
                           deltaX: deltaX, deltaY: deltaY,
                           isDirectionInverted: isDirectionInverted, timestamp: timestamp)
    }

    public func cancelTrackpadPaging() {
        innerPager?.cancel()
        finishTrackpadPresentation()
    }

    private var trackpadGridFrame: NSRect {
        if let snapshot = appliedFolderLayout { return snapshot.gridFrame }
        let top = panel.bounds.height - Self.titleHeight - 24
        return NSRect(x: Self.panelInset, y: Self.footerHeight + 12,
                      width: max(panel.bounds.width - Self.panelInset * 2, 0),
                      height: max(top - Self.footerHeight - 12, 0))
    }

    private func beginTrackpadPresentation() {
        guard swipeViewport == nil, let entry = currentEntry else { return }
        let area = trackpadGridFrame
        guard area.width > 0, area.height > 0 else { return }
        swipeVisualGeneration &+= 1
        let viewport = MoveOutProxyHostView(frame: area)
        viewport.wantsLayer = true
        viewport.layer?.masksToBounds = true
        panel.addSubview(viewport)
        swipeViewport = viewport
        swipeLayoutBounds = bounds
        swipePageWidth = area.width
        // Freeze geometry and text once at the input boundary, never resolve them per frame.
        swipeCellFrames = appliedFolderLayout?.cellFrames ?? memberCells.map(\.frame)
        swipeMemberNames = entry.members.reduce(into: [:]) { names, member in
            names[member] = memberName(member) ?? ""
        }
        swipeEntry = entry
        updateTrackpadPageWindow(offset: Double(currentInnerPage))
        for cell in memberCells { cell.isHidden = true }
    }

    /// Follow the visual position, not just the committed page. Fast/long tracking may
    /// traverse more than one page; keep only three hosts around the visible interval.
    private func updateTrackpadPageWindow(offset: Double) {
        guard let viewport = swipeViewport, let entry = swipeEntry, innerPageCount > 0 else { return }
        let boundedOffset = min(max(offset, 0), Double(innerPageCount - 1))
        let center = Int(floor(boundedOffset))
        let wanted = Set(max(center - 1, 0)...min(center + 1, innerPageCount - 1))
        for page in Array(swipePageHosts.keys) where !wanted.contains(page) {
            swipePageHosts.removeValue(forKey: page)?.removeFromSuperview()
        }
        let generation = swipeVisualGeneration
        let area = trackpadGridFrame
        for page in wanted.sorted() where swipePageHosts[page] == nil {
            let host = MoveOutProxyHostView(frame: viewport.bounds)
            host.wantsLayer = true
            viewport.addSubview(host)
            swipePageHosts[page] = host
            for (slot, member) in members(onPage: page, in: entry).enumerated() {
                guard swipeCellFrames.indices.contains(slot) else { continue }
                let cell = AppGridCellView(frame: swipeCellFrames[slot].offsetBy(dx: -area.minX, dy: -area.minY))
                cell.contentLayoutContext = .folderGrid
                if let displayedStrings { cell.relabel(strings: displayedStrings) }
                cell.itemAppearance = itemAppearance
                cell.showsAppLabels = showsAppLabels
                cell.isAppContextMenuEnabled = false
                cell.setClickRecognitionEnabled(false)
                let key = IconKey(identity: IconIdentity.from(appID: member),
                                  pointSize: iconPointSize, displayScale: displayScale)
                let token = ItemBindingToken(catalogRevision: currentCatalogRevision,
                    pageIdentity: PagePresentationID(revision: currentCatalogRevision, pageIndex: page),
                    itemSlot: slot, appID: AnyHashable(member), reuseGeneration: 0,
                    iconKey: key, surfaceGeneration: surfaceGeneration)
                cell.bind(name: swipeMemberNames[member] ?? "", token: token)
                cell.iconView.image = memberCells.first { $0.bindingToken?.appID as? AppID == member }?.iconView.image
                host.addSubview(cell)
                cell.layoutSubtreeIfNeeded()
                pipeline.request(key: key, generation: generation) { [weak self, weak cell, weak viewport] deliveredKey, delivered, result in
                    guard let self, let cell, !self.isTornDown, !self.isVisualOnly,
                          self.swipeViewport === viewport, self.swipeVisualGeneration == generation,
                          delivered == generation, deliveredKey == key, cell.bindingToken == token else { return }
                    if case .success(let image) = result { _ = cell.applyIconIfValid(image, token: token) }
                }
            }
        }
    }

    private func renderTrackpadOffset(_ offset: Double) {
        guard !isTornDown, !isVisualOnly, !reduceMotion, currentEntry != nil else { return }
        if swipeViewport == nil, abs(offset - Double(currentInnerPage)) > 0.000001 {
            beginTrackpadPresentation()
        }
        guard swipeViewport != nil else { return }
        updateTrackpadPageWindow(offset: offset)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (page, host) in swipePageHosts {
            host.frame.origin.x = (CGFloat(page) - CGFloat(offset)) * swipePageWidth
        }
        CATransaction.commit()
    }

    private func finishTrackpadPresentation() {
        guard swipeViewport != nil else { return }
        swipeVisualGeneration &+= 1
        swipeViewport?.removeFromSuperview()
        swipeViewport = nil
        swipePageHosts.removeAll()
        swipePageWidth = 0
        swipeCellFrames.removeAll()
        swipeMemberNames.removeAll()
        swipeEntry = nil
        for cell in memberCells { cell.isHidden = !isMemberPresentationAvailable }
    }

    // MARK: - 内部分页

    /// Phase 1F（T-1F-D1）：folder scope 边缘翻页入口（AppDelegate 跨模块调用 → public）。
    @objc public func prevPage() {
        cancelTrackpadPaging()
        guard !isVisualOnly, !isTornDown, !isPanelTransitionActive, isMemberPresentationAvailable else { return }
        onInnerPageChange?(currentInnerPage - 1)
    }

    @objc public func nextPage() {
        cancelTrackpadPaging()
        guard !isVisualOnly, !isTornDown, !isPanelTransitionActive, isMemberPresentationAvailable else { return }
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
        pageIndicator.isHidden = count <= 1 || !isMemberPresentationAvailable
        if count <= 1 || !isMemberPresentationAvailable {
            pageIndicator.stringValue = ""
            prevButton.isHidden = true
            nextButton.isHidden = true
        } else {
            pageIndicator.stringValue = displayedStrings?.page(currentInnerPage + 1, total: count)
                ?? "Page \(currentInnerPage + 1) of \(count)"
            prevButton.isHidden = currentInnerPage == 0
            nextButton.isHidden = currentInnerPage >= count - 1
        }
    }

    // MARK: - 成员 cell 复用 + 图标异步（generation 门控）

    private struct RetainedMemberIcon {
        let key: IconKey
        let image: NSImage
    }

    /// Transaction-local continuity only for a pure reorder under the same served catalog.
    /// Catalog changes revoke source mappings; a different page/folder/lifecycle loads normally.
    private func retainedIconsForReorder(to entry: FolderEntry, innerPage: Int,
                                         catalogRevision: UInt64, reduceMotion: Bool)
        -> [AppID: RetainedMemberIcon] {
        guard let previous = currentEntry,
              previous.id == entry.id, previous.title == entry.title,
              previous.members != entry.members, previous.members.count == entry.members.count,
              currentCatalogRevision == catalogRevision, currentInnerPage == innerPage,
              self.reduceMotion == reduceMotion, configuredMembersPerPage == membersPerPage,
              !isPanelTransitionActive, !isMoveOutPresentationCollapsed,
              !isTrackpadPagingActive, swipeViewport == nil else { return [:] }
        let identities = Set(previous.members)
        guard identities.count == previous.members.count, identities == Set(entry.members) else { return [:] }
        var retained: [AppID: RetainedMemberIcon] = [:]
        for (index, member) in members(onPage: currentInnerPage, in: previous).enumerated() {
            guard memberCells.indices.contains(index) else { continue }
            let expected = memberToken(member: member, index: index)
            let cell = memberCells[index]
            guard cell.bindingToken == expected, let key = expected.iconKey,
                  let image = cell.iconView.image else { continue }
            retained[member] = RetainedMemberIcon(key: key, image: image)
        }
        return retained
    }

    private func prepareMemberCells(count: Int) {
        if memberCells.count != count {
            for cell in memberCells {
                cell.invalidatePendingText()
                cell.removeFromSuperview()
            }
            memberCells = (0..<count).map { _ in
                let cell = AppGridCellView()
                cell.contentLayoutContext = .folderGrid
                if let displayedStrings { cell.relabel(strings: displayedStrings) }
                cell.itemAppearance = itemAppearance
                cell.showsAppLabels = showsAppLabels
                connectContextMenu(to: cell)
                panel.addSubview(cell)
                return cell
            }
        } else {
            for cell in memberCells {
                cell.clearContent()
                cell.contentLayoutContext = .folderGrid
                cell.itemAppearance = itemAppearance
                cell.showsAppLabels = showsAppLabels
                connectContextMenu(to: cell)
            }
        }
    }

    private func connectContextMenu(to cell: AppGridCellView) {
        cell.isAppContextMenuEnabled = !isVisualOnly
        cell.appContextMenuProvider = { [weak self] cell in
            guard let self, !self.isTornDown, !self.isVisualOnly, !self.isPanelTransitionActive,
                  !self.isMoveOutPresentationCollapsed else { return nil }
            return self.appContextMenuProvider?(cell)
        }
    }

    private func memberToken(member: AppID, index: Int) -> ItemBindingToken {
        ItemBindingToken(
            catalogRevision: currentCatalogRevision,
            pageIdentity: PagePresentationID(revision: currentCatalogRevision, pageIndex: currentInnerPage),
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
            // A retained exit visual must remain pixel-stable. The next interactive configure
            // rebinds current members and advances the generation so this one-shot result cannot
            // be applied after the visual resumes.
            guard !self.isVisualOnly else { return }
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

    /// Re-issues the current member requests after a visual-only interval. Icon callbacks are
    /// one-shot, so results suppressed while frozen must not leave an interactive reopen blank.
    private func rebindCurrentMembersAfterVisualResume() {
        guard let entry = currentEntry, !entry.members.isEmpty else { return }
        surfaceGeneration &+= 1
        let members = members(onPage: currentInnerPage, in: entry)
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
        if swipeViewport != nil, bounds != swipeLayoutBounds { cancelTrackpadPaging() }
        if let snapshot = deferredEditorLayout ?? appliedFolderLayout {
            layoutAdaptivePanel(snapshot)
            return
        }
        let w = bounds.width
        let h = bounds.height
        let panelW = min(max(w * 0.7, 200), 900)
        let panelH = min(max(h * 0.8, 200), 700)
        panel.frame = CGRect(x: (w - panelW) / 2, y: (h - panelH) / 2,
                             width: panelW, height: panelH)
        panelMaterial.frame = panel.bounds
        layoutPanel()
    }

    @objc private func closeForInsufficientSpace() {
        guard !isTornDown, !isVisualOnly else { return }
        onRequestClose?()
    }

    private func layoutAdaptivePanel(_ snapshot: FolderLayoutSnapshot) {
        panel.frame = snapshot.panelFrame
        panelMaterial.frame = panel.bounds
        let titleFrame = snapshot.titleFrame.isEmpty && titleEditorView != nil
            ? snapshot.insufficientSpaceMessageFrame : snapshot.titleFrame
        titleLabel.frame = titleFrame
        titleLabel.isHidden = titleEditorView != nil || titleFrame.isEmpty
        titleEditButton.frame = titleFrame
        titleEditButton.isHidden = titleEditorView != nil || currentEntry == nil || titleFrame.isEmpty
        titleEditorView?.frame = titleEditorFrame
        pageIndicator.frame = snapshot.pageIndicatorFrame
        prevButton.frame = snapshot.previousButtonFrame
        nextButton.frame = snapshot.nextButtonFrame
        for (index, cell) in memberCells.enumerated() {
            guard snapshot.cellFrames.indices.contains(index) else {
                cell.isHidden = true
                continue
            }
            cell.frame = snapshot.cellFrames[index]
            cell.isHidden = !isMemberPresentationAvailable || swipeViewport != nil
        }
        insufficientSpaceLabel.frame = snapshot.insufficientSpaceMessageFrame
        insufficientSpaceLabel.isHidden = isMemberPresentationAvailable || titleEditorView != nil
            || snapshot.insufficientSpaceMessageFrame.height < 16
        closeButton.frame = snapshot.closeButtonFrame
    }

    private func layoutPanel() {
        let pw = panel.bounds.width
        let ph = panel.bounds.height
        let inset = Self.panelInset
        let titleH = Self.titleHeight
        let footerH = Self.footerHeight

        titleLabel.frame = CGRect(x: inset, y: ph - titleH - 12, width: pw - inset * 2, height: titleH)
        titleEditButton.frame = titleLabel.frame
        titleEditorView?.frame = titleEditorFrame

        let gridTop = ph - titleH - 12 - 12
        let gridBottom = footerH + 12
        let area = CGRect(x: inset, y: gridBottom, width: pw - inset * 2, height: gridTop - gridBottom)
        let columns = Self.columns
        let spacing = Self.spacing
        // Preserve fitting layouts, but never impose a minimum height that makes
        // the current page exceed its reserved grid area. Very short rows also
        // compress their vertical gap; horizontal column spacing is unchanged.
        let rows = (memberCells.count + columns - 1) / columns
        let pitch = min(Self.cellHeight + spacing, max(area.height, 0) / CGFloat(max(rows, 1)))
        let rowSpacing = min(spacing, pitch / 2)
        let cellHeight = max(pitch - rowSpacing, 0)
        let tileWidth = (area.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        for (index, cell) in memberCells.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = area.minX + CGFloat(column) * (tileWidth + spacing)
            let y = area.maxY - CGFloat(row + 1) * (cellHeight + rowSpacing)
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
