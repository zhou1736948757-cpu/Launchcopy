//
//  AppCatalogAssembly.swift
//  PagingPrototypeApp
//
//  Phase 1B Wave 3（t10）—— 真实内容装配层（composition root）。
//  实现：worker-integration（deepseek-v4-flash:0731, max）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
//  职责（单一 integration worker 收口，§12 Wave 3）：
//  - CatalogRepository（revision 单调唯一拥有者）→ AppGridDataSource 适配（含匿名时长）；
//  - AppGridUIPageContentProvider → PagingSurface.contentProvider（§E seam）；
//  - IconPipeline + SystemIconLoader(resolver:)（identity→URL 仅运行时读取，无磁盘缓存）；
//  - AppGridRenderer：把单个 AppGridPageView 渲染器按 pageIndex 拆分为每页实例
//    （seam 的 `surface.renderer` 是单实例；PageHostView 的视图承载移动语义只支持
//    单 host 显示 —— 见 T-worker-b-integration.md 集成发现与证据）；
//  - AppGridRefreshController 状态机接线（presentation 提交回调转发）；
//  - 装配决策：--neutral-content → 不装配（Phase 1A 回归模式，AppRuntimeFactory）。
//
//  隐私硬边界：本层不把 app 名/bundle ID/路径/图标数据/启动 URL 写入 telemetry；
//  identity→URL 映射仅进程内存（启动 smoke 重新确认用），绝不进日志。

import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import Foundation
import MacAppCatalog
import PagingUI

// MARK: - identity → URL 运行时解析盒（NSLock 保护；仅内存，无磁盘缓存）

/// 快照记录 → 可解析 URL 的运行时映射（图标 resolver 与启动 smoke 共用同一权威来源）。
/// 每次快照提交时整体重建（latest-wins；旧 identity 立即失效 —— stale 拒绝的第二道防线）。
public final class IconURLResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var identityToURL: [IconIdentity: URL] = [:]
    private var appIDToURL: [AppID: URL] = [:]

    public init() {}

    /// 以已提交快照重建映射（调用方 = 提交路径，MainActor）。
    public func update(from snapshot: CatalogSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        identityToURL.removeAll()
        appIDToURL.removeAll()
        for record in snapshot.records {
            identityToURL[record.iconIdentity] = record.canonicalURL
            appIDToURL[record.id] = record.canonicalURL
        }
    }

    /// 图标管道 resolver 用（任意线程；未命中 → nil → 系统通用图标）。
    public func url(for identity: IconIdentity) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return identityToURL[identity]
    }

    /// 启动 smoke 重新确认用（任意线程；nil = 不在当前 catalog）。
    public func url(for appID: AppID) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return appIDToURL[appID]
    }
}

// MARK: - CatalogRepository → AppGridDataSource 适配（含匿名时长）

/// AppGridDataSource 适配器：包住 CatalogRepository actor 的 refresh，
/// 缓存已提交快照（协议要求同步 currentSnapshot），并暴露匿名扫描/刷新时长
/// （telemetry catalog_scan_duration_ms / refresh_duration_ms 来源）。
/// 非 actor 类 + NSLock（协议要求非隔离同步 currentSnapshot；refresh 可被任意上下文
/// 调用，读取侧（MainActor UI）与写入侧（refresh Task）经锁互斥 —— 与 IconURLResolver 同模式）。
public final class CatalogRepositoryDataSource: AppGridDataSource, @unchecked Sendable {

    private let lock = NSLock()
    private let repository: CatalogRepository
    private let configuration: ScanConfiguration
    private var cachedSnapshot: CatalogSnapshot?

    /// 最近一次扫描的匿名时长（毫秒；report.scanDuration；无路径/名称原文）。
    public private(set) var lastScanDurationMS: Double?
    /// 最近一次 refresh（扫描 + snapshot apply）总时长（毫秒）。
    public private(set) var lastRefreshDurationMS: Double?

    public init(repository: CatalogRepository, configuration: ScanConfiguration) {
        self.repository = repository
        self.configuration = configuration
    }

    public var currentSnapshot: CatalogSnapshot? {
        readSnapshot()
    }

    private func readSnapshot() -> CatalogSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSnapshot
    }

    public func refresh() async -> AppGridRefreshOutcome {
        let start = Date()
        let result = await repository.refresh(configuration: configuration)
        let refreshMS = Date().timeIntervalSince(start) * 1000
        let scanMS = result.report.scanDuration * 1000
        let snapshot = result.snapshot
        store(outcome: (refreshMS, scanMS, snapshot))
        return AppGridRefreshOutcome(
            succeeded: snapshot != nil && !result.cancelled,
            appCount: snapshot?.records.count ?? 0,
            failureCount: result.report.failureCounts.values.reduce(0, +),
            cancelled: result.cancelled || result.coalesced
        )
    }

    private func store(outcome: (refreshMS: Double, scanMS: Double, snapshot: CatalogSnapshot?)) {
        // 同步辅助（async 上下文经它拿锁：NSLock 在 async 函数内直调为 Swift 6 弃用）。
        lock.lock()
        defer { lock.unlock() }
        lastRefreshDurationMS = outcome.refreshMS
        lastScanDurationMS = outcome.scanMS
        if let snapshot = outcome.snapshot {
            cachedSnapshot = snapshot
        }
    }
}

// MARK: - 每页实例渲染器包装（seam 单实例 → 每 host 一个 AppGridPageView）

/// 把单个 `AppGridPageView` 渲染器按 pageIndex 拆分为每页实例，使多个 live host
/// 各自承载自己的真实内容网格。
///
/// 为什么需要（集成发现，证据见 T-worker-b-integration.md）：
/// `PagingSurface.renderer` 是单实例注入点；`PageHostView.render` 会把自定义渲染器
/// **视图**挂入（并移动进）正在渲染的 host —— 多 host 并存时渲染器视图只存在于
/// 最后渲染的 host，其余 live host 空白（真实缺陷复现证据见集成冒烟）。
/// 本包装器：每个 host 渲染时创建/复用**属于该页**的 AppGridPageView 实例并直接挂入
/// host 层级；`clearForReuse()` 无 host 上下文（协议签名），真实清理改由两个时点完成：
/// ① PageHostView 离开 live 范围/入池调用的 clearForReuse()；② 下一次 render() ——
/// 均按「记录的 host 是否已离开 surface（superview == nil）」判定，离开者的页实例
/// 清空回池（§10.6 item view 上界 = live + pool，与 PagingSurface 同界）。
///
/// 线程模型：视图主线程（MainActor）受限；@unchecked Sendable 与 AppGridPageView 同约定。
public final class AppGridRenderer: PagingPageRendering, PagingPageRenderingTargetBinding, @unchecked Sendable {

    /// 当前承载目标（PageHostView.render 前由 PagingUI 绑定）。
    public weak var renderTarget: NSView?

    /// 图标异步 apply 观察钩子透传（telemetry 合成 icon_async_state 用）。
    public var onIconApplyResult: ((ItemBindingToken, AppGridIconApplyResult) -> Void)? {
        didSet {
            for (_, page) in pages {
                page.onIconApplyResult = onIconApplyResult
            }
        }
    }

    /// folder 快照提供者透传（T-1E-folderlab-membercount-repair）：装配层注入，
    /// 每页实例据此渲染 folder cell 的真实成员计数。nil = 无快照 → folder cell
    /// 显示中性符号 + 标题（成员计数 0，仍可区分）。
    public var folderSnapshotProvider: (() -> FolderSnapshot?)? {
        didSet {
            for (_, page) in pages {
                page.folderSnapshotProvider = folderSnapshotProvider
            }
        }
    }

    /// folder cell 点击回调透传（T-1E-folder-open-repair-wiring）：装配层注入，
    /// 每页实例据此把 folder cell 点击接到 AppDelegate（键盘焦点 + 打开 folder）。
    /// nil = 无回调 → folder cell 点击 no-op。
    public var onFolderClick: ((FolderID) -> Void)? {
        didSet {
            for (_, page) in pages {
                page.onFolderClick = onFolderClick
            }
        }
    }

    /// 已创建的页实例总数（证据/测试）。
    public private(set) var totalInstancesCreated = 0
    /// 当前存活页实例数（live 页；测试/诊断）。
    public var livePageInstanceCount: Int { pages.count }
    /// 池大小（测试/诊断；与 PagingSurface pool 同界）。
    public var pooledInstanceCount: Int { pool.count }

    private let pipeline: IconPipeline
    private let iconPointSize: Double
    private let displayScale: Double
    private var pages: [Int: AppGridPageView] = [:]
    private var pageHosts: [Int: WeakHost] = [:]
    private var pool: [AppGridPageView] = []

    /// 弱引用 host（防 customRenderer(host) ↔ host 引用环）。
    private final class WeakHost {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }

    public init(iconPipeline: IconPipeline, iconPointSize: Double = 48, displayScale: Double = 2) {
        self.pipeline = iconPipeline
        self.iconPointSize = max(iconPointSize, 8)
        self.displayScale = max(displayScale, 1)
    }

    // MARK: - PagingPageRendering

    public func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        guard let target = renderTarget else { return }
        // 占位内容（中性模式/越界页）：无 cell 可展示 → 不创建/不挂载实例
        // （placeholder host 无需页面实例；避免空转实例 + 减少生命周期噪音）。
        guard !content.isPlaceholder else { return }

        // 1) host 复用换页：本 target 曾渲染别的页 → 旧实例清空回池（复用 host 内容不得残留）。
        let reusedHostPage = pages.first { $0.value.superview === target && $0.key != pageIndex }?.key
        if let reusedHostPage {
            retire(pageIndex: reusedHostPage)
        }

        // 2) 离开范围的 host（superview 已 nil，含刚被 PagingSurface 移除者）→ 清理。
        sweepRetiredHosts()

        // 3) 取实例：同页同 host 原地复用 → 池 → 新建。
        let page: AppGridPageView
        if let existing = pages[pageIndex], existing.superview === target {
            page = existing
        } else if let pooled = pool.popLast() {
            page = pooled
        } else {
            page = AppGridPageView(iconPipeline: pipeline, iconPointSize: iconPointSize, displayScale: displayScale)
            page.onIconApplyResult = onIconApplyResult
            totalInstancesCreated += 1
        }
        if page.superview !== target {
            target.addSubview(page)
        }
        // T-1E-folderlab-membercount-repair：每页实例透传 folder 快照提供者
        // （含池化复用页 —— 旧 provider 可能已变，须每次 render 重设）。
        page.folderSnapshotProvider = folderSnapshotProvider
        // T-1E-folder-open-repair-wiring：每页实例透传 folder cell 点击回调（同源 seam）。
        page.onFolderClick = onFolderClick
        // 首次挂入时 host frame 可能尚未就位（relayout 顺序：render → 设 frame）：
        // autoresizing 让页实例随 host 尺寸变化自动跟随（含 resize，§10.5）。
        page.autoresizingMask = [.width, .height]
        page.frame = target.bounds
        page.render(pageIndex: pageIndex, content: content, pageCount: pageCount, reuseGeneration: reuseGeneration)
        pages[pageIndex] = page
        pageHosts[pageIndex] = WeakHost(target)
    }

    /// 协议要求：PageHostView 离开 live 范围/进入复用池时调用（无 pageIndex 上下文）。
    /// 真实清理在这里完成：凡记录的 host 已离开 surface 层级（superview == nil）→
    /// 其页实例清空回池（离开范围的 host 内容不可见，不构成「旧内容残留」；
    /// 空 catalog 等不再有 render 的场景也由本路径收敛，不泄漏实例计数）。
    public func clearForReuse() {
        sweepRetiredHosts()
    }

    // MARK: - 测试/诊断

    /// 取某页的渲染实例（测试断言；不存在返回 nil）。
    public func pageView(forPage index: Int) -> AppGridPageView? {
        pages[index]
    }

    /// teardown：全部实例 teardown（此后零 UI 写回）+ 清池。
    public func teardown() {
        for (_, page) in pages { page.teardown() }
        pages.removeAll()
        pageHosts.removeAll()
        for page in pool { page.teardown() }
        pool.removeAll()
    }

    // MARK: - 内部

    /// 清理记录的 host 已离开 surface 层级（superview == nil）的页实例。
    private func sweepRetiredHosts() {
        let stalePages = pages.compactMap { index, page -> Int? in
            guard let host = pageHosts[index]?.view, host.superview == nil else { return nil }
            return index
        }
        for index in stalePages {
            retire(pageIndex: index)
        }
    }

    private func retire(pageIndex: Int) {
        guard let page = pages.removeValue(forKey: pageIndex) else { return }
        pageHosts.removeValue(forKey: pageIndex)
        page.clearForReuse()
        pool.append(page)
    }
}

// MARK: - 装配决策（可单测）

/// App 层装配决策：--neutral-content → 不装配（Phase 1A 回归模式）。
public enum AppRuntimeFactory {
    /// 返回 nil = 中性回归模式（contentProvider/renderer 保持 nil → NeutralContentProvider 缺省）。
    @MainActor
    public static func makeAssembly(options: AppArguments.Options) -> AppCatalogAssembly? {
        guard !options.neutralContent else { return nil }
        let assembly = AppCatalogAssembly(roots: options.catalogRoots)
        // Phase 1E：--folder-lab 会话内 folder lab/demo 入口（默认关闭；产品启动不重排用户应用）。
        // 生成器从已提交 catalog 派生 folder 组合（ADR-008 §2.5：稳定顺序前 N 个一组，中性标题）。
        if options.folderLab {
            assembly.folderLabEnabled = true
            assembly.folderSnapshotGenerator = { catalog in
                FolderLabFixture.makeGroups(from: catalog, configuration: .init(enabled: true))
            }
        }
        return assembly
    }
}

// MARK: - 装配根

/// 真实内容装配根（composition root）：一次构建全部 Phase 1B 组件并接线。
/// 扫描根：`--catalog-root` 覆盖（可多次）；缺省 CatalogRoots.defaults（4 受限根，§5.2 上界）。
/// 测试注入：`scanning` / `loader` 可注入 fake（测试资源隔离 §10.3/§10.4；绝不触碰真实 /Applications）。
@MainActor
public final class AppCatalogAssembly {

    /// 数据源适配器（含匿名时长）。
    public let dataSource: CatalogRepositoryDataSource
    /// 内容提供者（PagingSurface.contentProvider 注入）。
    public let provider: AppGridUIPageContentProvider
    /// 刷新状态机。
    public let refreshController: AppGridRefreshController
    /// 图标管道（有界内存缓存；teardown 由本装配负责）。
    public let iconPipeline: IconPipeline
    /// 每页实例渲染器（PagingSurface.renderer 注入）。
    public let renderer: AppGridRenderer
    /// identity→URL 运行时解析盒（图标 resolver + 启动 smoke 共用）。
    public let urlResolver: IconURLResolver
    /// 搜索呈现编排器（T-1D-E 搜索接线：presentation → provider；AppDelegate 接 search controller）。
    public let searchPresentation: AppGridSearchPresentationController

    /// Phase 1E：folder lab 是否开启（--folder-lab；默认关闭，产品启动不重排用户应用）。
    public var folderLabEnabled = false
    /// Phase 1E：folder 组合生成器（从已提交 catalog 派生 FolderSnapshot；nil = 无 folder 组合）。
    /// 由 AppRuntimeFactory 在 --folder-lab 时接线到 FolderLabFixture.makeGroups。
    public var folderSnapshotGenerator: ((CatalogSnapshot) -> FolderSnapshot?)?

    /// 呈现提交回调（装配层接线：surface.setPageCount + refreshPresentation + telemetry）。
    public var onPresentationUpdate: ((AppGridPresentationUpdate) -> Void)?

    private let roots: [URL]
    private var hasBegun = false
    private var isTornDown = false
    /// 已为其生成 folder 组合的 catalog revision（避免同 revision 重复重建；folder 层绝不 mint/forge CatalogRevision）。
    private var lastFolderCatalogRevision: UInt64?

    public init(roots: [URL],
                policy: CatalogPolicy = .init(),
                scanning: (any CatalogScanning)? = nil,
                loader: (any IconLoading)? = nil,
                iconLimits: IconCacheLimits = .init(),
                displayScale: Double = 2) {
        let effectiveRoots = roots.isEmpty ? CatalogRoots.defaults : roots
        self.roots = effectiveRoots

        let scanner = scanning ?? CatalogScanner()
        let repository = CatalogRepository(policy: policy, scanning: scanner)
        let configuration = ScanConfiguration(roots: effectiveRoots)
        let dataSource = CatalogRepositoryDataSource(repository: repository, configuration: configuration)
        let provider = AppGridUIPageContentProvider()
        let urlResolver = IconURLResolver()
        // 仅运行时读取：identity→URL 经公开 NSWorkspace.icon(forFile:)（SystemIconLoader）；
        // 无磁盘缓存、不复制进资源/fixture/发布包（§5.3）。
        let iconLoader = loader ?? SystemIconLoader(resolver: { urlResolver.url(for: $0) })
        let pipeline = IconPipeline(loader: iconLoader, limits: iconLimits)
        let renderer = AppGridRenderer(iconPipeline: pipeline, displayScale: displayScale)
        let controller = AppGridRefreshController(dataSource: dataSource, provider: provider)
        let searchPresentation = AppGridSearchPresentationController(provider: provider)

        self.dataSource = dataSource
        self.provider = provider
        self.refreshController = controller
        self.iconPipeline = pipeline
        self.renderer = renderer
        self.urlResolver = urlResolver
        self.searchPresentation = searchPresentation

        controller.onPresentationUpdate = { [weak self] update in
            guard let self else { return }
            // 提交路径同步重建 identity→URL 映射（latest-wins；旧 identity 立即失效）。
            if let snapshot = self.dataSource.currentSnapshot {
                self.urlResolver.update(from: snapshot)
            }
            self.onPresentationUpdate?(update)
        }
    }

    /// 首次加载：已有快照 → 立即呈现；否则 .loading + 首扫（AppDelegate 在 surface 接线后调用）。
    public func begin() {
        guard !hasBegun, !isTornDown else { return }
        hasBegun = true
        refreshController.begin()
        // Phase 1E：首扫/已有快照提交后重建 folder 组合（若已提交 catalog 且 lab 开启）。
        rebuildFolderCompositionIfNeeded()
    }

    /// Phase 1E：在已提交 catalog 上重建 folder 组合（若 lab 开启且 catalog revision 变化）。
    ///
    /// 优先级基线（ADR-008 §3 Q6）：新 catalog snapshot 提交后，在**新 base** 上重建 folder
    /// 组合（folder 层绝不 mint/forge CatalogRevision；folder generation 为独立单调 token）。
    /// 生成结果经 `provider.receiveFolderSnapshot` 暂存为 pending，由下一次 idle 边界
    /// `applyPending` 原子提交（catalog + folder 同界）。同 revision 幂等（不重复重建）。
    @MainActor
    public func rebuildFolderCompositionIfNeeded() {
        guard let generator = folderSnapshotGenerator,
              let base = provider.servedSnapshot,
              base.revision.value != lastFolderCatalogRevision else { return }
        lastFolderCatalogRevision = base.revision.value
        if let folderSnapshot = generator(base) {
            provider.receiveFolderSnapshot(folderSnapshot)
        }
    }

    /// 手动刷新（透传；UI 刷新按钮/Rescan 路径）。
    public func refreshNow() {
        guard !isTornDown else { return }
        refreshController.refreshNow()
    }

    /// 可取消的 debounced rescan（透传）。
    public func scheduleRescan() {
        guard !isTornDown else { return }
        refreshController.scheduleRescan()
    }

    /// 当前 catalog 中仍存在的 app 的 bundle URL（启动 smoke 重新确认；nil = 不在 catalog）。
    public func bundleURL(for appID: AppID) -> URL? {
        urlResolver.url(for: appID)
    }

    /// 当前扫描根（诊断/测试断言）。
    public var scanRoots: [URL] { roots }

    /// Phase 1E：构造 folder 成员启动 cell（复用 `AppLaunchController.handleCell` 管线）。
    ///
    /// folder 成员激活解析出成员 `AppID` 后，构造一个绑定正确 catalog revision 的合成 cell，
    /// 交给既有 `AppLaunchController` 管线（stale revision → identity 在 catalog → 磁盘存在 →
    /// `NSWorkspace`）。**无并行启动路径**；folder 身份（`FolderID`）绝不进入此 cell 的 appID 槽位。
    /// 成员 cell 的 `catalogRevision` 必须等于当前 served revision，否则 `handleCell` 会以
    /// `.rejectedStaleRevision` 拒绝（与顶层 cell 同一校验）。
    @MainActor
    public static func makeMemberLaunchCell(appID: AppID, servedRevision: UInt64) -> AppGridCellView {
        let cell = AppGridCellView()
        let token = ItemBindingToken(
            catalogRevision: servedRevision,
            pageIdentity: PagePresentationID(revision: servedRevision, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(appID),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0
        )
        cell.bind(name: nil, token: token)
        return cell
    }

    /// teardown：取消待决 rescan + 页实例 teardown + 图标管道 shutdown（幂等）。
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        refreshController.cancelScheduledRescan()
        renderer.teardown()
        iconPipeline.shutdown()
    }
}
