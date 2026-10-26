// AppGridUI — AppGridPageView（§E PagingPageRendering 真实内容页渲染）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 真实网格渲染：
// - app 名：NSTextField 同步文本（render 内直接写，绝不显示旧名）；
// - 运行时图标：IconPipeline 异步请求，七字段 ItemBindingToken 门控写回（§6.4）；
// - Reuse clears every cell; an admitted main-page reorder restores ready icons only after rebinding.
//   在途异步绑定被 surfaceGeneration bump 作废（stale apply 不落任何 cell）；
// - 失败结果 → 中性 placeholder 保持；teardown 后零 UI 写回；
// - 无障碍：页标签 + cell 完整名称（§9）。
//
// 线程模型：视图主线程（MainActor）受限；onApply 由 IconPipeline 保证在 MainActor 投递，
// 故 @unchecked Sendable 仅为满足 @Sendable 闭包捕获（与 AppIconPipeline 既有约定一致）。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
import LauncherLocalization

/// 图标异步 apply 结果（观察/telemetry 用；无字节/哈希/路径/身份原文）。
public enum AppGridIconApplyResult: Equatable, Sendable {
    case applied                 // 七字段匹配，已写回 cell
    case rejectedStale           // 已投递但门控拒绝（stale result rejected，§7）
    case failed                  // 加载失败 → 中性 placeholder 保持
    case cancelled               // 底层取消 → 零写回
    case ignoredAfterTeardown    // 视图已 teardown → 零写回
}

/// 单个页面的真实内容渲染器（PagingPageRendering；由装配层注入 PagingSurface）。
public final class AppGridPageView: NSView, PagingPageRendering, @unchecked Sendable {

    private static let spacing: CGFloat = 16
    private static let pageLabelHeight: CGFloat = 28

    /// 当前页索引（未 render = -1）。
    public private(set) var pageIndex = -1
    /// 当前呈现身份（revision + page index；一页所有 item 同 revision，§6.1）。
    public private(set) var presentationID: PagePresentationID?
    /// 当前复用代（PagingSurface 每次 clear bump，render 携带）。
    public private(set) var reuseGeneration: UInt64 = 0
    /// 页面视图生命周期代（本视图每次 clearForReuse/render bump；token 第七字段）。
    public private(set) var surfaceGeneration: UInt64 = 0
    /// 已投递但被门控拒绝的 apply 计数（stale result rejected；测试断言/telemetry）。
    public private(set) var staleIconApplyCount = 0
    /// 是否已 teardown（此后零 UI 写回）。
    public private(set) var isTornDown = false
    public var layoutMode: AppGridLayoutMode = .ordinary
    /// Main-grid metrics only. Rebinding and admission belong to the app owner;
    /// the independent folder overlay never reads this configuration.
    public var gridCapacity: MainGridCapacity = .default {
        didSet {
            guard gridCapacity != oldValue else { return }
            needsLayout = true
        }
    }
    /// Updates live and retained cells without rendering or requesting icons.
    public var itemAppearance: GridItemAppearance = .default {
        didSet {
            guard itemAppearance.isValid else {
                itemAppearance = oldValue
                return
            }
            guard itemAppearance != oldValue else { return }
            for cell in cells { cell.itemAppearance = itemAppearance }
            needsLayout = true
        }
    }
    /// Applies caption visibility without rendering, rebinding or invalidating icon results.
    public var showsAppLabels: Bool = true {
        didSet {
            guard showsAppLabels != oldValue else { return }
            for cell in cells { cell.showsAppLabels = showsAppLabels }
        }
    }

    /// 观察钩子（测试 + telemetry 合成 icon_async_state 用）。
    /// 注意：设置方须弱捕获本视图（本视图不持有钩子；teardown 后回调仍可达，用于观测）。
    public var onIconApplyResult: ((ItemBindingToken, AppGridIconApplyResult) -> Void)?

    /// 文件夹快照提供者（装配层注入；用于 folder cell 的成员计数）。
    /// nil = 无快照 → folder cell 显示中性符号 + 标题（成员计数 0，仍可区分）。
    public var folderSnapshotProvider: (() -> FolderSnapshot?)?

    /// 文件夹点击回调透传（T-1E-folder-open-repair-wiring；装配层注入）。
    /// 仅 folder cell 触发（AppGridCellView.onFolderClick）；nil = 无回调 → folder cell 点击 no-op。
    public var onFolderClick: ((FolderID) -> Void)?

    /// Updates menu consumers without rebinding, requesting icons or changing generations.
    /// Application owners should use weak captures when installing their factory.
    public var appContextMenuProvider: ((AppGridCellView) -> NSMenu?)? {
        didSet {
            for cell in cells { connectContextMenu(to: cell) }
        }
    }

    /// 当前 cell 数（测试/诊断）。
    public var cellCount: Int { cells.count }
    /// 页标签文本（"Page N of M"；测试/诊断）。
    public private(set) var pageLabelText: String = ""

    /// 取 cell（测试/诊断；越界返回 nil）。
    public func cell(at index: Int) -> AppGridCellView? {
        guard index >= 0, index < cells.count else { return nil }
        return cells[index]
    }

    // MARK: - Phase 1F：拖拽几何 + drop 目标 hit-test（T-1F-D1）

    /// drop 目标 hit-test：页坐标系内包含该点的 cell（无 = nil）。
    public func cell(at point: NSPoint) -> AppGridCellView? {
        cells.first { $0.frame.contains(point) }
    }

    /// 拖拽几何：cell frame → DragItemFrame（host 坐标系）。
    /// catalog 用于 AppID → PersistentAppReference 解析（nil = 无快照 → app 条目跳过；
    /// folder 条目恒解析，不依赖 catalog）。
    public func dragItemFrames(convertedTo host: NSView, catalog: CatalogSnapshot?) -> [DragItemFrame] {
        cells.compactMap { cell in
            guard let token = cell.bindingToken else { return nil }
            let frameInHost = cell.convert(cell.bounds, to: host)
            let rect = DragRect(x: Double(frameInHost.minX), y: Double(frameInHost.minY),
                                width: Double(frameInHost.width), height: Double(frameInHost.height))
            if let folderID = token.appID as? FolderID {
                return DragItemFrame(identity: .folder(folderID), frame: rect)
            }
            guard let appID = token.appID as? AppID,
                  let record = catalog?.records.first(where: { $0.id == appID }) else { return nil }
            // Ordering still uses the entire cell. Grouping follows the visible icon,
            // which may be offset from the cell center by captions and responsive sizing.
            let icon = cell.iconView.convert(cell.iconView.bounds, to: host)
            let grouping = DragRect(x: Double(icon.minX), y: Double(icon.minY),
                                    width: Double(icon.width), height: Double(icon.height))
            return DragItemFrame(identity: .app(PersistentAppReference.from(record: record)),
                                 frame: rect, appGroupingFrame: grouping)
        }
    }

    private let pipeline: IconPipeline
    private let iconPointSize: Double
    private let displayScale: Double
    private var cells: [AppGridCellView] = []
    // Expected outgoing bindings, not an image cache. Only render may author this ledger.
    private var renderedBindings: [ItemBindingToken] = []
    private var renderedLayoutMode: AppGridLayoutMode?
    private var renderedGridCapacity: MainGridCapacity?
    private let pageLabel = NSTextField(labelWithString: "")
    private var displayedStrings: LocalizedStrings?
    private var textPageCount = 0
    private var textUpdateGeneration: UInt64 = 0
    private var textUpdateScheduled = false
    internal private(set) var languageFormattingCount = 0

    /// Updates retained cells and page chrome without render, binding or icon requests.
    public func relabel(strings: LocalizedStrings) {
        guard !isTornDown else { return }
        displayedStrings = strings
        for cell in cells { cell.relabel(strings: strings) }
        queuePageText()
    }

    private func invalidatePendingText() {
        textUpdateGeneration &+= 1
        textUpdateScheduled = false
    }

    private func queuePageText() {
        guard !textUpdateScheduled else { return }
        textUpdateScheduled = true
        let generation = textUpdateGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isTornDown, generation == self.textUpdateGeneration else { return }
            self.textUpdateScheduled = false
            self.updatePageText()
        }
    }

    private func updatePageText() {
        guard pageIndex >= 0, !isTornDown else { return }
        languageFormattingCount += 1
        let text = displayedStrings?.page(pageIndex + 1, total: textPageCount)
            ?? "Page \(pageIndex + 1) of \(textPageCount)"
        pageLabel.stringValue = text
        pageLabelText = text
        setAccessibilityLabel(text)
    }

    public init(iconPipeline: IconPipeline, iconPointSize: Double = 48, displayScale: Double = 2) {
        self.pipeline = iconPipeline
        self.iconPointSize = max(iconPointSize, 8)
        self.displayScale = max(displayScale, 1)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.cornerRadius = 0
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        pageLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        pageLabel.textColor = .white.withAlphaComponent(0.9)
        pageLabel.alignment = .center
        pageLabel.lineBreakMode = .byTruncatingTail
        // Keep page diagnostics/accessibility without decorative text over search.
        pageLabel.isHidden = true
        addSubview(pageLabel)
        setAccessibilityRole(.group)
    }

    /// Phase 1I：透出壁纸；SDK 上 `isOpaque` 为 get-only，必须 override。
    public override var isOpaque: Bool { false }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - PagingPageRendering

    /// 渲染一页内容：render 前必须已清空（复用路径由 clearForReuse 保证）。
    /// 同步写 app 名；异步请求图标（generation 门控写回）。
    public func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        render(pageIndex: pageIndex, content: content, pageCount: pageCount,
               reuseGeneration: reuseGeneration, retainingReadyIconsForReorder: false)
    }

    /// The main renderer may admit continuity only for its existing attached page/host pair.
    /// Images live in this synchronous transaction; all cells still clear, rebind and request.
    public func render(pageIndex: Int, content: PagingPageContent, pageCount: Int,
                       reuseGeneration: UInt64, retainingReadyIconsForReorder: Bool) {
        guard !isTornDown else { return }
        let retained = retainingReadyIconsForReorder
            ? readyIconsForReorder(pageIndex: pageIndex, content: content, reuseGeneration: reuseGeneration)
            : [:]
        renderedBindings.removeAll(keepingCapacity: true)
        renderedLayoutMode = layoutMode
        renderedGridCapacity = gridCapacity
        surfaceGeneration &+= 1
        self.pageIndex = pageIndex
        self.presentationID = content.presentationID
        self.reuseGeneration = reuseGeneration
        textPageCount = pageCount
        queuePageText()

        guard !content.isPlaceholder else {
            clearCells()
            needsLayout = true
            return
        }

        prepareCells(count: content.items.count)
        for (index, item) in content.items.enumerated() {
            let identity = item.identity
            let token = ItemBindingToken(
                catalogRevision: content.presentationID.revision,
                pageIdentity: content.presentationID,
                itemSlot: item.slot,
                appID: identity,
                reuseGeneration: reuseGeneration,
                iconKey: iconKey(for: identity),
                surfaceGeneration: surfaceGeneration
            )
            renderedBindings.append(token)
            if let folderID = identity as? FolderID {
                // folder cell：中性符号 + 标题 + 成员计数；绝不请求 app 图标（iconKey 为 nil）。
                let memberCount = folderSnapshotProvider?()?.entry(for: folderID)?.members.count ?? 0
                cells[index].bindFolder(title: item.title, memberCount: memberCount, token: token)
            } else {
                cells[index].bind(name: item.title, token: token)
                if let key = token.iconKey {
                    if let appID = identity as? AppID, let ready = retained[appID], ready.key == key {
                        cells[index].applyIconIfValid(ready.image, token: token)
                    }
                    requestIcon(key: key, token: token, cellIndex: index)
                }
            }
        }
        needsLayout = true
    }

    /// 进入复用池前清理：generation bump 作废全部在途异步绑定；清空全部 cell（名/图标/token）。
    public func clearForReuse() {
        guard !isTornDown else { return }
        renderedBindings.removeAll()
        renderedLayoutMode = nil
        renderedGridCapacity = nil
        invalidatePendingText()
        surfaceGeneration &+= 1
        pageIndex = -1
        presentationID = nil
        reuseGeneration = 0
        clearCells()
        pageLabel.stringValue = ""
        pageLabelText = ""
        setAccessibilityLabel("")
        needsLayout = true
    }

    /// teardown：此后零 UI 写回（pipeline shutdown 之外的视图级防线）；释放全部 cell。
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        renderedBindings.removeAll()
        renderedLayoutMode = nil
        renderedGridCapacity = nil
        invalidatePendingText()
        surfaceGeneration &+= 1
        pageIndex = -1
        presentationID = nil
        reuseGeneration = 0
        for cell in cells {
            cell.invalidatePendingText()
            cell.removeFromSuperview()
        }
        cells.removeAll()
        pageLabel.stringValue = ""
        pageLabelText = ""
        setAccessibilityLabel("")
    }

    // MARK: - 内部

    private struct ReadyReorderIcon {
        let key: IconKey
        let image: NSImage
    }

    private func readyIconsForReorder(pageIndex: Int, content: PagingPageContent,
                                      reuseGeneration: UInt64) -> [AppID: ReadyReorderIcon] {
        guard superview != nil, !content.isPlaceholder,
              self.pageIndex == pageIndex, content.presentationID.pageIndex == pageIndex,
              presentationID == content.presentationID, self.reuseGeneration == reuseGeneration,
              renderedLayoutMode == .ordinary, layoutMode == .ordinary,
              renderedGridCapacity == gridCapacity, renderedBindings.count == cells.count else { return [:] }
        let previousIDs = renderedBindings.compactMap(\.appID)
        let nextIDs = content.items.compactMap(\.identity)
        // Pure same-page permutations (including a repeated refresh) only. New members,
        // cross-page moves, duplicates and nil identities take the ordinary request path.
        guard previousIDs.count == renderedBindings.count, nextIDs.count == content.items.count,
              Set(previousIDs).count == previousIDs.count, Set(nextIDs).count == nextIDs.count,
              Set(previousIDs) == Set(nextIDs) else { return [:] }
        var ready: [AppID: ReadyReorderIcon] = [:]
        for (index, expected) in renderedBindings.enumerated() {
            let cell = cells[index]
            guard cell.superview === self, !cell.isFolderCell,
                  cell.bindingToken == expected,
                  expected.catalogRevision == presentationID?.revision,
                  expected.pageIdentity == presentationID,
                  expected.reuseGeneration == self.reuseGeneration,
                  expected.surfaceGeneration == surfaceGeneration,
                  let appID = expected.appID as? AppID, let key = expected.iconKey,
                  key == iconKey(for: expected.appID), let image = cell.iconView.image else { continue }
            ready[appID] = ReadyReorderIcon(key: key, image: image)
        }
        return ready
    }

    /// 身份 → IconKey（IconIdentity 不透明；不含 bundle ID 原文/路径/哈希）。
    private func iconKey(for identity: AnyHashable?) -> IconKey? {
        guard let appID = identity as? AppID else { return nil }
        return IconKey(identity: IconIdentity.from(appID: appID),
                       pointSize: iconPointSize, displayScale: displayScale)
    }

    /// 数量变化才重建 cell 数组；否则复用既有 cell 并同步清空（防旧名/旧图标残留）。
    /// 每次重建/复用都重设 onFolderClick（T-1E-folder-open-repair-wiring：回调可能已变，
    /// 含池化复用页 —— 与 folderSnapshotProvider 同源透传）。
    private func prepareCells(count: Int) {
        if cells.count != count {
            for cell in cells {
                cell.invalidatePendingText()
                cell.removeFromSuperview()
            }
            cells = (0..<count).map { _ in
                let cell = AppGridCellView()
                cell.contentLayoutContext = .mainGrid
                if let displayedStrings { cell.relabel(strings: displayedStrings) }
                cell.itemAppearance = itemAppearance
                cell.showsAppLabels = showsAppLabels
                cell.onFolderClick = onFolderClick
                connectContextMenu(to: cell)
                addSubview(cell)
                return cell
            }
        } else {
            for cell in cells {
                cell.clearContent()
                cell.contentLayoutContext = .mainGrid
                cell.itemAppearance = itemAppearance
                cell.showsAppLabels = showsAppLabels
                cell.onFolderClick = onFolderClick
                connectContextMenu(to: cell)
            }
        }
    }

    private func clearCells() {
        for cell in cells { cell.clearContent() }
    }

    private func connectContextMenu(to cell: AppGridCellView) {
        cell.appContextMenuProvider = { [weak self] cell in
            guard let self, !self.isTornDown else { return nil }
            return self.appContextMenuProvider?(cell)
        }
    }

    private func requestIcon(key: IconKey, token: ItemBindingToken, cellIndex: Int) {
        let generation = surfaceGeneration
        pipeline.request(key: key, generation: generation) { [weak self] _, deliveredGeneration, result in
            guard let self else { return }
            guard !self.isTornDown else {
                self.observe(token, .ignoredAfterTeardown)
                return
            }
            // 快路径：视图代不匹配（已 clear/re-render）→ 直接拒绝，不再逐 cell 校验。
            guard deliveredGeneration == self.surfaceGeneration else {
                self.registerStale(token)
                return
            }
            switch result {
            case .success(let image):
                guard cellIndex < self.cells.count,
                      self.cells[cellIndex].applyIconIfValid(image, token: token) else {
                    self.registerStale(token)
                    return
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

    // MARK: - 布局（网格；图标 frame 固定 → 图标到达无布局跳动）

    public override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height
        pageLabel.frame = CGRect(x: 0, y: max(height - Self.pageLabelHeight - 24, 0),
                                 width: width, height: Self.pageLabelHeight)

        let geometry = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: cells.count,
            mode: layoutMode, capacity: gridCapacity, appearance: itemAppearance,
            preferredSpacing: Self.spacing)
        guard !cells.isEmpty else { return }
        let total = cells.count
        for (index, cell) in cells.enumerated() {
            if let frame = geometry.frame(for: index, itemCount: total) { cell.frame = frame }
        }
    }

    // MARK: - T-1F-B10-regression-fix §2.1 取证（E6a'）：中间层投递观测（纯转发 census，零行为变更）

    /// mouseDown 纯转发 census（sE6_page_down，中性计数，隐私合规；转发 super 原样，
    /// 响应链与普通 NSView 完全一致）。判别（任务包 §2.1 步骤 3）：>0 → 投递目标 =
    /// AppGridPageView → f 族定罪（AppKit 缓存/跟踪会话指向中间层视图）。
    public override func mouseDown(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.pageViewMouseDown)
        super.mouseDown(with: event)
    }

    /// mouseUp 纯转发 census（sE6_page_up；事件对完整性——mouseUp 目标同步记录）。
    public override func mouseUp(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.pageViewMouseUp)
        super.mouseUp(with: event)
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 取证 census sinks（E6a'：中间层投递观测）

extension ClickCensus.Sink {
    /// E6a'：AppGridPageView.mouseDown 到达（投递目标=中间层页视图；f 族定罪证据）。
    public static let pageViewMouseDown = "sE6_page_down"
    /// E6a'：AppGridPageView.mouseUp 到达（事件对完整性）。
    public static let pageViewMouseUp = "sE6_page_up"
}
