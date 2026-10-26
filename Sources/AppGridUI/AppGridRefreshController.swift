// AppGridUI — AppGridRefreshController（§3.1.11/3.1.12：状态机 + 手动 refresh + 可取消 debounced rescan）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 接线职责（AppGridUI 不含 scanner/icon loader 所有权，§14.A）：
// - 数据源经 AppGridDataSource 协议注入（装配层适配 MacAppCatalog.CatalogRepository）；
// - 扫描结果 → provider.receive（latest-wins pending）→ idle 边界
//   applyPendingAtIdleBoundary（anchor remap）→ onPresentationUpdate 通知装配层
//   （surface.setPageCount + refreshPresentation，Wave 3 接线）；
// - 手动 refresh / debounced rescan（可取消）；
// - 中性状态机：loading / ready / empty / partialFailure / refreshing。
//
// 线程模型：@MainActor（UI 层契约）；refresh 的 async 段在数据源侧执行，回主线程应用状态。

import AppCatalogCore
import Foundation

/// 刷新编排器：状态机 + 手动刷新 + 可取消 debounce。
@MainActor
public final class AppGridRefreshController {

    public let provider: AppGridUIPageContentProvider
    public let dataSource: any AppGridDataSource

    /// 每页 item 数（与 PagingSurface 默认 35 对齐；remap/plan 用）。
    public var itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage

    /// rescan debounce 间隔。
    public var debounceInterval: TimeInterval

    /// 当前中性状态。
    public private(set) var state: AppGridUIState = .loading

    /// 最近一次刷新结果（中性计数；nil = 尚未完成任何刷新）。
    public private(set) var lastOutcome: AppGridRefreshOutcome?

    /// 状态变化回调（中性状态，无任何身份信息）。
    public var onStateChange: ((AppGridUIState) -> Void)?

    /// 呈现更新回调（idle 边界 commit + remap 后触发；装配层据此刷新 surface）。
    public var onPresentationUpdate: ((AppGridPresentationUpdate) -> Void)?

    private var hasBegun = false
    private var isRefreshing = false
    private var refreshQueuedAgain = false
    private var stateBeforeRefresh: AppGridUIState?
    private var scheduledWork: DispatchWorkItem?

    public init(dataSource: any AppGridDataSource,
                provider: AppGridUIPageContentProvider = AppGridUIPageContentProvider(),
                debounceInterval: TimeInterval = 0.5) {
        self.dataSource = dataSource
        self.provider = provider
        self.debounceInterval = debounceInterval
    }

    // MARK: - 生命周期

    /// 首次加载：数据源已有快照 → 立即呈现；否则 .loading + 首次扫描。
    public func begin() {
        guard !hasBegun else { return }
        hasBegun = true
        if let snapshot = dataSource.currentSnapshot {
            provider.receive(snapshot)
            if let update = provider.applyPending(atCurrentPage: 0, itemsPerPage: itemsPerPage) {
                onPresentationUpdate?(update)
            }
            setState(snapshot.records.isEmpty ? .empty : .ready)
        } else {
            setState(.loading)
            refreshNow()
        }
    }

    // MARK: - 刷新

    /// 手动刷新：立即触发（已有内容 → .refreshing；首次 → 保持 .loading）。
    /// 进行中再触发 → 标记 refreshQueuedAgain，当前轮完成后补一轮（latest-wins 语义）。
    public func refreshNow() {
        guard !isRefreshing else {
            refreshQueuedAgain = true
            return
        }
        isRefreshing = true
        switch state {
        case .ready, .empty, .partialFailure:
            stateBeforeRefresh = state
            setState(.refreshing)
        default:
            break // .loading（首次）/ .refreshing 不可能在此
        }
        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.dataSource.refresh()
            self.isRefreshing = false
            self.applyOutcome(outcome)
            if self.refreshQueuedAgain {
                self.refreshQueuedAgain = false
                self.refreshNow()
            }
        }
    }

    /// 可取消的 debounced rescan：间隔内多次调用只保留最后一次。
    public func scheduleRescan() {
        cancelScheduledRescan()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// 取消未触发的 debounced rescan（幂等）。
    public func cancelScheduledRescan() {
        scheduledWork?.cancel()
        scheduledWork = nil
    }

    // MARK: - idle 边界（§6.2：tracking/settling 期间只写 pending；idle 一次性 apply）

    /// idle/cancelled 边界：anchor remap + 原子替换 presentation（装配层从 surface 的
    /// onIdleBoundary 事件调用，currentPage = surface.core.committedPage）。
    @discardableResult
    public func applyPendingAtIdleBoundary(currentPage: Int,
                                           itemsPerPage: Int? = nil) -> AppGridPresentationUpdate? {
        let ipp = itemsPerPage ?? self.itemsPerPage
        guard let update = provider.applyPending(atCurrentPage: currentPage, itemsPerPage: ipp) else {
            return nil
        }
        onPresentationUpdate?(update)
        return update
    }

    // MARK: - 内部

    private func applyOutcome(_ outcome: AppGridRefreshOutcome) {
        lastOutcome = outcome
        if outcome.succeeded, let snapshot = dataSource.currentSnapshot {
            provider.receive(snapshot) // latest-wins pending（不打断手势）
        }
        setState(resolveState(after: outcome))
    }

    /// Cancellation retains the previous state. Whole-scan or discovery failures
    /// take precedence over empty results; non-blocking issues preserve ready/empty.
    private func resolveState(after outcome: AppGridRefreshOutcome) -> AppGridUIState {
        if outcome.cancelled {
            return stateBeforeRefresh ?? state
        }
        guard outcome.succeeded, outcome.discoveryFailureCount == 0 else { return .partialFailure }
        return outcome.appCount == 0 ? .empty : .ready
    }

    private func setState(_ newState: AppGridUIState) {
        guard newState != state else { return }
        state = newState
        onStateChange?(newState)
    }
}
