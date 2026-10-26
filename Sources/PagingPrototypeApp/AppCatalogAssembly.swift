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
import LauncherLocalization
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
    @discardableResult
    public func update(from snapshot: CatalogSnapshot) -> Set<IconIdentity> {
        lock.lock()
        defer { lock.unlock() }
        var nextIcons: [IconIdentity: URL] = [:]
        var nextApps: [AppID: URL] = [:]
        for record in snapshot.records {
            nextIcons[record.iconIdentity] = record.canonicalURL
            nextApps[record.id] = record.canonicalURL
        }
        let identities = Set(identityToURL.keys).union(nextIcons.keys)
        let changed = Set(identities.filter { identityToURL[$0] != nextIcons[$0] })
        identityToURL = nextIcons
        appIDToURL = nextApps
        return changed
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

/// Timings from the latest accepted refresh, captured together under the data source lock.
/// These values are not attributed to a particular historical presentation revision.
public struct CatalogRefreshTimings: Sendable, Equatable {
    public let scanDurationMS: Double?
    public let refreshDurationMS: Double?

    public init(scanDurationMS: Double? = nil, refreshDurationMS: Double? = nil) {
        self.scanDurationMS = scanDurationMS
        self.refreshDurationMS = refreshDurationMS
    }
}

/// AppGridDataSource 适配器：包住 CatalogRepository actor 的 refresh，
/// 缓存已提交快照（协议要求同步 currentSnapshot），并暴露匿名扫描/刷新时长
/// （telemetry catalog_scan_duration_ms / refresh_duration_ms 来源）。
/// 非 actor 类 + NSLock（协议要求非隔离同步 currentSnapshot；refresh 可被任意上下文
/// 调用，读取侧（MainActor UI）与写入侧（refresh Task）经锁互斥 —— 与 IconURLResolver 同模式）。
public final class CatalogRepositoryDataSource: AppGridDataSource, @unchecked Sendable {

    private let lock = NSLock()
    private let repository: CatalogRepository
    private var configuration: ScanConfiguration
    private var configurationGeneration: UInt64 = 0
    private var isClosed = false
    private struct RootAdmission: Sendable {
        let fixedRoots: [URL]
        let context: AppSourceRootAdmissionContext
        let admitter: any AppSourceRootAdmitting
    }
    private var rootAdmission: RootAdmission?
    private var cachedSnapshot: CatalogSnapshot?
    private var cachedSnapshotGeneration: UInt64 = 0

    private var latestRefreshTimings = CatalogRefreshTimings()

    /// A coherent pair from the latest accepted refresh; invalidation/close retain history.
    public var refreshTimings: CatalogRefreshTimings {
        lock.lock()
        defer { lock.unlock() }
        return latestRefreshTimings
    }

    /// Latest accepted scan duration in milliseconds; separate scalar reads are not a pair.
    public var lastScanDurationMS: Double? { refreshTimings.scanDurationMS }
    /// Latest accepted refresh duration in milliseconds (scan plus snapshot apply).
    public var lastRefreshDurationMS: Double? { refreshTimings.refreshDurationMS }

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
        return !isClosed && cachedSnapshotGeneration == configurationGeneration ? cachedSnapshot : nil
    }

    public func refresh() async -> AppGridRefreshOutcome {
        let start = Date()
        let request = readRequest()
        guard !request.isClosed, !Task.isCancelled else {
            return AppGridRefreshOutcome(succeeded: false, appCount: 0, failureCount: 0, cancelled: true)
        }
        var admittedConfiguration = request.configuration
        if let admission = request.admission {
            let accepted = await AppSourceRootSetResolver.resolve(fixedRoots: admission.fixedRoots,
                customRoots: request.configuration.roots.filter { !admission.fixedRoots.contains($0) },
                context: admission.context, admission: admission.admitter)
            admittedConfiguration.roots = accepted.roots
        }
        guard !Task.isCancelled, isCurrent(request.generation) else {
            return AppGridRefreshOutcome(succeeded: false, appCount: 0, failureCount: 0, cancelled: true)
        }
        let result = await repository.refresh(configuration: admittedConfiguration)
        let refreshMS = Date().timeIntervalSince(start) * 1000
        let scanMS = result.report.scanDuration * 1000
        let snapshot = result.snapshot
        guard !Task.isCancelled, store(outcome: (refreshMS, scanMS, snapshot), generation: request.generation) else {
            return AppGridRefreshOutcome(succeeded: false, appCount: 0, failureCount: 0, cancelled: true)
        }
        return AppGridRefreshOutcome(
            succeeded: snapshot != nil && !result.cancelled,
            appCount: snapshot?.records.count ?? 0,
            failureCount: result.report.failureCount,
            nonBlockingFailureCount: result.report.nonBlockingFailureCount,
            cancelled: result.cancelled || result.coalesced
        )
    }

    /// Called only by the assembly transaction owner; old scans cannot publish.
    public func replaceRoots(_ roots: [URL], fixedRoots: [URL],
                             context: AppSourceRootAdmissionContext,
                             admission: any AppSourceRootAdmitting) {
        lock.lock(); defer { lock.unlock() }
        guard !isClosed else { return }
        configuration.roots = roots
        rootAdmission = RootAdmission(fixedRoots: fixedRoots, context: context, admitter: admission)
        configurationGeneration &+= 1
    }

    /// Cancel this generation without permanently disabling future source refreshes.
    public func invalidateRequests() {
        lock.lock(); defer { lock.unlock() }
        guard !isClosed else { return }
        configurationGeneration &+= 1
    }

    /// Permanent teardown gate, including controller tasks already queued on Main.
    public func close() {
        lock.lock(); defer { lock.unlock() }
        guard !isClosed else { return }
        isClosed = true; configurationGeneration &+= 1
    }

    private func readRequest() -> (configuration: ScanConfiguration, generation: UInt64, admission: RootAdmission?, isClosed: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (configuration, configurationGeneration, rootAdmission, isClosed)
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !isClosed && generation == configurationGeneration
    }

    private func store(outcome: (refreshMS: Double, scanMS: Double, snapshot: CatalogSnapshot?),
                       generation: UInt64) -> Bool {
        // 同步辅助（async 上下文经它拿锁：NSLock 在 async 函数内直调为 Swift 6 弃用）。
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed, generation == configurationGeneration else { return false }
        latestRefreshTimings = CatalogRefreshTimings(scanDurationMS: outcome.scanMS,
                                                    refreshDurationMS: outcome.refreshMS)
        if let snapshot = outcome.snapshot {
            cachedSnapshot = snapshot
            cachedSnapshotGeneration = generation
        }
        return true
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

    private var languageStrings: LocalizedStrings?

    /// Committed outer-grid shape, supplied by the composition root at idle.
    /// Updating metrics alone never performs persistence or requests icons.
    public var gridCapacity: MainGridCapacity = .default {
        didSet {
            guard gridCapacity != oldValue else { return }
            for page in pages.values { page.gridCapacity = gridCapacity }
            for page in pool { page.gridCapacity = gridCapacity }
        }
    }

    /// A language-only presentation change retains pages, bindings and icon work.
    /// The page consumer coalesces formatting outside any render/frame stack.
    public func relabel(strings: LocalizedStrings) {
        languageStrings = strings
        for page in pages.values { page.relabel(strings: strings) }
        for page in pool { page.relabel(strings: strings) }
    }

    /// Installs menu factories on live and pooled pages without a presentation refresh.
    /// Application owners should capture themselves weakly in this factory.
    public var appContextMenuProvider: ((AppGridCellView) -> NSMenu?)? {
        didSet {
            for page in pages.values { page.appContextMenuProvider = appContextMenuProvider }
            for page in pool { page.appContextMenuProvider = appContextMenuProvider }
        }
    }

    /// Updates live and pooled captions directly, without a catalog or presentation refresh.
    public var showsAppLabels: Bool = true {
        didSet {
            guard showsAppLabels != oldValue else { return }
            for page in pages.values { page.showsAppLabels = showsAppLabels }
            for page in pool { page.showsAppLabels = showsAppLabels }
        }
    }

    /// Display-only metrics propagate to every live and pooled page without rebinding.
    public var itemAppearance = GridItemAppearance.default {
        didSet {
            guard itemAppearance.isValid else { itemAppearance = oldValue; return }
            guard itemAppearance != oldValue else { return }
            for page in pages.values { page.itemAppearance = itemAppearance }
            for page in pool { page.itemAppearance = itemAppearance }
        }
    }

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

    /// Supplies the last committed presentation mode. Pending search input must not
    /// affect geometry until the provider commits the corresponding result.
    public var layoutModeProvider: (() -> AppGridLayoutMode)?

    /// Supplies the page currently committed by PagingCore. Motion anchors must come from
    /// this page only; adjacent attached pages are prewarmed for paging and are not visible
    /// source ownership.
    public var committedPageProvider: (() -> Int)?

    /// 已创建的页实例总数（证据/测试）。
    public private(set) var totalInstancesCreated = 0
    /// 当前存活页实例数（live 页；测试/诊断）。
    public var livePageInstanceCount: Int { pages.count }
    /// 池大小（测试/诊断；与 PagingSurface pool 同界）。
    public var pooledInstanceCount: Int { pool.count }

    /// Resolves a currently rendered Folder cell into the requested host coordinate space.
    /// Only the currently committed page may provide an anchor. Off-screen, prewarmed, or
    /// recycled pages intentionally produce no anchor.
    public func liveFolderFrame(for folderID: FolderID, convertedTo host: NSView) -> NSRect? {
        guard let committedPage = committedPageProvider?(),
              let page = pages[committedPage], page.superview != nil else {
            return nil
        }
        for index in 0..<page.cellCount {
            guard let cell = page.cell(at: index),
                  cell.bindingToken?.appID as? FolderID == folderID else { continue }
            return cell.convert(cell.bounds, to: host)
        }
        return nil
    }

    /// Resolves the actual visible folder glyph, excluding cell padding and captions.
    /// Reads the current committed binding each time; no cached or adjacent-page anchor
    /// survives reuse. AppKit converts between the shared hierarchy's coordinate spaces,
    /// including flipped hosts, without rounding through backing pixels.
    public func liveFolderIconFrame(for folderID: FolderID, convertedTo host: NSView) -> NSRect? {
        guard let committedPage = committedPageProvider?(),
              let page = pages[committedPage], !page.isTornDown,
              page.pageIndex == committedPage, let presentation = page.presentationID,
              let pageHost = pageHosts[committedPage]?.view,
              page.superview === pageHost, pageHost.superview != nil,
              !page.isHiddenOrHasHiddenAncestor else {
            return nil
        }

        // A shared, windowless test hierarchy is valid, but an unrelated or detached
        // destination must not acquire a guessed window/global-space anchor.
        var commonAncestor: NSView? = pageHost
        while let candidate = commonAncestor {
            if host === candidate || host.isDescendant(of: candidate) { break }
            commonAncestor = candidate.superview
        }
        guard commonAncestor != nil else { return nil }

        for index in 0..<page.cellCount {
            guard let cell = page.cell(at: index), cell.superview === page,
                  let token = cell.bindingToken,
                  token.appID as? FolderID == folderID,
                  token.pageIdentity == presentation,
                  token.catalogRevision == presentation.revision,
                  token.reuseGeneration == page.reuseGeneration,
                  token.surfaceGeneration == page.surfaceGeneration,
                  let glyphFrame = cell.folderMotionSourceFrame,
                  glyphFrame.intersects(cell.visibleRect) else { continue }
            // AppKit parents may allow drawing outside bounds; visibleRect alone
            // does not prove the glyph belongs to the committed page viewport.
            guard cell.convert(glyphFrame, to: page).intersects(page.bounds),
                  cell.convert(glyphFrame, to: pageHost).intersects(pageHost.bounds) else { continue }
            let converted = cell.convert(glyphFrame, to: host)
            guard converted.origin.x.isFinite, converted.origin.y.isFinite,
                  converted.width.isFinite, converted.height.isFinite,
                  converted.width > 0, converted.height > 0,
                  converted.maxX.isFinite, converted.maxY.isFinite else { return nil }
            return converted
        }
        return nil
    }

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
        guard !content.isPlaceholder else {
            // A placeholder must revoke this host's old ownership even if no real
            // content follows. Never let its old cells become a continuity source.
            let replaced = pages.compactMap { $0.value.superview === target ? $0.key : nil }
            for index in replaced { retire(pageIndex: index) }
            sweepRetiredHosts()
            return
        }

        // 1) host 复用换页：本 target 曾渲染别的页 → 旧实例清空回池（复用 host 内容不得残留）。
        let reusedHostPage = pages.first { $0.value.superview === target && $0.key != pageIndex }?.key
        if let reusedHostPage {
            retire(pageIndex: reusedHostPage)
        }

        // 2) 离开范围的 host（superview 已 nil，含刚被 PagingSurface 移除者）→ 清理。
        sweepRetiredHosts()

        if let previous = pages[pageIndex], previous.superview !== target {
            retire(pageIndex: pageIndex)
        }

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
        // Recycled, transferred and newly attached pages cannot donate ready icons.
        // The page additionally checks catalog, mode, capacity and every outgoing token.
        let retainingReadyIcons = pages[pageIndex] === page
            && pageHosts[pageIndex]?.view === target && page.superview === target
            && target.superview != nil
        if page.superview !== target {
            target.addSubview(page)
        }
        // T-1E-folderlab-membercount-repair：每页实例透传 folder 快照提供者
        // （含池化复用页 —— 旧 provider 可能已变，须每次 render 重设）。
        if let languageStrings { page.relabel(strings: languageStrings) }
        page.folderSnapshotProvider = folderSnapshotProvider
        // T-1E-folder-open-repair-wiring：每页实例透传 folder cell 点击回调（同源 seam）。
        page.onFolderClick = onFolderClick
        page.appContextMenuProvider = appContextMenuProvider
        page.showsAppLabels = showsAppLabels
        page.itemAppearance = itemAppearance
        page.gridCapacity = gridCapacity
        page.layoutMode = layoutModeProvider?() ?? .ordinary
        // 首次挂入时 host frame 可能尚未就位（relayout 顺序：render → 设 frame）：
        // autoresizing 让页实例随 host 尺寸变化自动跟随（含 resize，§10.5）。
        page.autoresizingMask = [.width, .height]
        page.frame = target.bounds
        page.render(pageIndex: pageIndex, content: content, pageCount: pageCount,
                    reuseGeneration: reuseGeneration, retainingReadyIconsForReorder: retainingReadyIcons)
        pages[pageIndex] = page
        pageHosts[pageIndex] = WeakHost(target)
    }

    /// 协议要求：PageHostView 离开 live 范围/进入复用池时调用（无 pageIndex 上下文）。
    /// 真实清理在这里完成：凡记录的 host 已失效或离开 surface 层级 →
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

    /// Retire cleared hosts immediately, as well as detached or released hosts.
    private func sweepRetiredHosts() {
        let stalePages = pages.compactMap { index, page -> Int? in
            // A released weak host is retired too. Otherwise its page stays in
            // the live map indefinitely and cannot be cleared or reused.
            guard let host = pageHosts[index]?.view else { return index }
            // PagingSurface normally clears a host before detaching it. Its invalidated
            // ownership must retire now, even while superview is temporarily non-nil.
            if let host = host as? PageHostView,
               host.pageIndex != index || host.reuseGeneration != page.reuseGeneration {
                return index
            }
            return host.superview == nil ? index : nil
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

    private var roots: [URL]
    private var hasBegun = false
    private var isTornDown = false
    /// 已为其生成 folder 组合的 catalog revision（避免同 revision 重复重建；folder 层绝不 mint/forge CatalogRevision）。
    private var lastFolderCatalogRevision: UInt64?
    private var lastIconSourceRevision: CatalogRevision?

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
        renderer.layoutModeProvider = { [weak provider] in
            provider?.activeQuery?.isEmpty == false ? .search : .ordinary
        }
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
            self.synchronizeIconSourcesWithCommittedCatalog()
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

    /// Phase 1E：在待提交或已提交 catalog base 上重建 folder 组合（若 lab 开启且
    /// catalog revision 变化）。
    ///
    /// 优先级基线（ADR-008 §3 Q6）：新 catalog snapshot 提交后，在**新 base** 上重建 folder
    /// 组合（folder 层绝不 mint/forge CatalogRevision；folder generation 为独立单调 token）。
    /// 首次异步扫描完成时 catalog 仍位于 provider.pendingSnapshot；优先从该待提交
    /// base 生成 folder，才能让 catalog + folder 在同一个 idle apply 中提交。
    /// 生成结果经 `provider.receiveFolderSnapshot` 暂存为 pending，由下一次 idle 边界
    /// `applyPending` 原子提交（catalog + folder 同界）。同 revision 幂等（不重复重建）。
    @MainActor
    public func rebuildFolderCompositionIfNeeded() {
        guard let generator = folderSnapshotGenerator,
              let base = provider.pendingSnapshot ?? provider.servedSnapshot,
              base.revision.value != lastFolderCatalogRevision else { return }
        lastFolderCatalogRevision = base.revision.value
        if let folderSnapshot = generator(base) {
            provider.receiveFolderSnapshot(folderSnapshot)
        }
    }

    /// Commits catalog, folder composition, and the current query at one idle boundary.
    /// Build folders against the pending base before search applies it; a later refresh
    /// apply would reset the just-committed query and expose an intermediate composition.
    @discardableResult
    public func commitPendingAtIdleBoundary(currentPage: Int) -> AppGridPresentationUpdate? {
        rebuildFolderCompositionIfNeeded()
        let update = searchPresentation.applyPendingAtIdleBoundary(currentPage: currentPage)
        if update != nil { synchronizeIconSourcesWithCommittedCatalog() }
        return update
    }

    /// Shared by refresh and search commit paths, before external rendering.
    /// The served catalog is authority; a newer pending scan cannot change icons.
    func synchronizeIconSourcesWithCommittedCatalog() {
        guard !isTornDown, let snapshot = provider.servedSnapshot,
              snapshot.revision != lastIconSourceRevision else { return }
        let changed = urlResolver.update(from: snapshot)
        iconPipeline.invalidateSources(for: changed)
        lastIconSourceRevision = snapshot.revision
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
        provider.record(for: appID)?.canonicalURL
    }

    /// Replace discovery inputs without rebuilding the renderer, icons, query or layout.
    public func replaceScanRoots(_ roots: [URL], fixedRoots: [URL],
                                 context: AppSourceRootAdmissionContext,
                                 admission: any AppSourceRootAdmitting) {
        guard !isTornDown else { return }
        self.roots = roots
        dataSource.replaceRoots(roots, fixedRoots: fixedRoots, context: context, admission: admission)
        provider.discardPending()
        provider.discardPendingFolderSnapshot()
        provider.discardPendingSearchResult()
        // A not-yet-committed query remains valid against the served base even if
        // the next catalog scan fails. Do not lose the latest text at root switch.
        if let query = searchPresentation.currentQuery, query != provider.activeQuery {
            searchPresentation.updateQuery(query)
        }
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
        dataSource.close()
        refreshController.onStateChange = nil
        refreshController.onPresentationUpdate = nil
        renderer.teardown()
        iconPipeline.shutdown()
    }
}
