// AppGridUI — AppGridPageView（§E PagingPageRendering 真实内容页渲染）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 真实网格渲染：
// - app 名：NSTextField 同步文本（render 内直接写，绝不显示旧名）；
// - 运行时图标：IconPipeline 异步请求，七字段 ItemBindingToken 门控写回（§6.4）；
// - 复用：clearForReuse/render 先清空全部 cell（名/图标/token）→ 新内容 → 图标到达；
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

    private static let columns = 5
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

    /// 观察钩子（测试 + telemetry 合成 icon_async_state 用）。
    /// 注意：设置方须弱捕获本视图（本视图不持有钩子；teardown 后回调仍可达，用于观测）。
    public var onIconApplyResult: ((ItemBindingToken, AppGridIconApplyResult) -> Void)?

    /// 文件夹快照提供者（装配层注入；用于 folder cell 的成员计数）。
    /// nil = 无快照 → folder cell 显示中性符号 + 标题（成员计数 0，仍可区分）。
    public var folderSnapshotProvider: (() -> FolderSnapshot?)?

    /// 文件夹点击回调透传（T-1E-folder-open-repair-wiring；装配层注入）。
    /// 仅 folder cell 触发（AppGridCellView.onFolderClick）；nil = 无回调 → folder cell 点击 no-op。
    public var onFolderClick: ((FolderID) -> Void)?

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
            return DragItemFrame(identity: .app(PersistentAppReference.from(record: record)), frame: rect)
        }
    }

    private let pipeline: IconPipeline
    private let iconPointSize: Double
    private let displayScale: Double
    private var cells: [AppGridCellView] = []
    private let pageLabel = NSTextField(labelWithString: "")

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
        guard !isTornDown else { return }
        surfaceGeneration &+= 1
        self.pageIndex = pageIndex
        self.presentationID = content.presentationID
        self.reuseGeneration = reuseGeneration
        pageLabel.stringValue = "Page \(pageIndex + 1) of \(pageCount)"
        pageLabelText = pageLabel.stringValue
        setAccessibilityLabel("Page \(pageIndex + 1) of \(pageCount)")

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
            if let folderID = identity as? FolderID {
                // folder cell：中性符号 + 标题 + 成员计数；绝不请求 app 图标（iconKey 为 nil）。
                let memberCount = folderSnapshotProvider?()?.entry(for: folderID)?.members.count ?? 0
                cells[index].bindFolder(title: item.title, memberCount: memberCount, token: token)
            } else {
                cells[index].bind(name: item.title, token: token)
                if let key = token.iconKey {
                    requestIcon(key: key, token: token, cellIndex: index)
                }
            }
        }
        needsLayout = true
    }

    /// 进入复用池前清理：generation bump 作废全部在途异步绑定；清空全部 cell（名/图标/token）。
    public func clearForReuse() {
        guard !isTornDown else { return }
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
        surfaceGeneration &+= 1
        pageIndex = -1
        presentationID = nil
        reuseGeneration = 0
        for cell in cells { cell.removeFromSuperview() }
        cells.removeAll()
        pageLabel.stringValue = ""
        pageLabelText = ""
        setAccessibilityLabel("")
    }

    // MARK: - 内部

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
            for cell in cells { cell.removeFromSuperview() }
            cells = (0..<count).map { _ in
                let cell = AppGridCellView()
                cell.onFolderClick = onFolderClick
                addSubview(cell)
                return cell
            }
        } else {
            for cell in cells {
                cell.clearContent()
                cell.onFolderClick = onFolderClick
            }
        }
    }

    private func clearCells() {
        for cell in cells { cell.clearContent() }
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

        let inset: CGFloat = 24
        let topInset: CGFloat = 96
        let columns = Self.columns
        let spacing = Self.spacing
        let cellHeight: CGFloat = 88
        let area = CGRect(
            x: inset, y: inset,
            width: max(width - inset * 2, 0), height: max(height - topInset - inset, 0)
        )
        guard area.width > 0, area.height > 0, !cells.isEmpty else { return }
        let tileWidth = (area.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let total = cells.count
        for (index, cell) in cells.enumerated() {
            let column = index % columns
            let row = index / columns
            // T-1D：行内水平居中 —— 搜索结果/部分页末行不足 columns 时，整行在网格区域内居中
            // （单结果/少量结果不再被挤到左侧）。满行（= columns）行宽恰等于 area.width，
            // 行起始偏移为 0，几何与全页布局完全一致（零回归）。
            let colsInThisRow = min(columns, total - row * columns)
            let rowContentWidth = CGFloat(colsInThisRow) * tileWidth + CGFloat(colsInThisRow - 1) * spacing
            let rowStartX = area.minX + (area.width - rowContentWidth) / 2
            let x = rowStartX + CGFloat(column) * (tileWidth + spacing)
            let y = area.maxY - CGFloat(row + 1) * (cellHeight + spacing)
            cell.frame = CGRect(x: x, y: y, width: tileWidth, height: cellHeight)
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
