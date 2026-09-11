// AppGridUITests — AppGridRefreshController（§3.1.11/3.1.12：状态机
// loading/empty/partialFailure/refreshing/ready；手动 refresh；可取消 debounced rescan；
// latest-wins pending；idle 边界 anchor remap 接线）

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class AppGridRefreshControllerTests: XCTestCase {

    private func makeController(dataSource: ImmediateDataSource) -> AppGridRefreshController {
        AppGridRefreshController(dataSource: dataSource)
    }

    /// 等待状态到达 target（onStateChange 驱动；避免裸 sleep）。
    private func awaitState(_ controller: AppGridRefreshController,
                            _ target: AppGridUIState,
                            timeout: TimeInterval = 3) async {
        if controller.state == target { return }
        let expectation = expectation(description: "state \(target)")
        let token = StateObserver(controller: controller, target: target, expectation: expectation)
        await fulfillment(of: [expectation], timeout: timeout)
        token.cancel()
    }

    /// 观察器：目标状态到达即 fulfill；cancel 时移除。
    @MainActor
    private final class StateObserver {
        private let controller: AppGridRefreshController
        private let target: AppGridUIState
        private let expectation: XCTestExpectation
        init(controller: AppGridRefreshController, target: AppGridUIState,
             expectation: XCTestExpectation) {
            self.controller = controller
            self.target = target
            self.expectation = expectation
            controller.onStateChange = { [weak self] state in
                if state == self?.target {
                    self?.expectation.fulfill()
                }
            }
        }
        func cancel() {
            controller.onStateChange = nil
        }
    }

    // MARK: - begin（首次加载）

    func testBeginWithExistingSnapshotPresentsImmediately() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let dataSource = ImmediateDataSource(snapshot: snapshot)
        let controller = makeController(dataSource: dataSource)

        var updates: [AppGridPresentationUpdate] = []
        controller.onPresentationUpdate = { updates.append($0) }

        controller.begin()

        XCTAssertEqual(controller.state, .ready)
        XCTAssertEqual(controller.provider.servedRevision, 1)
        XCTAssertEqual(updates.count, 1, "已有快照 → 立即呈现（remap 无锚点 → clamped/空目录之外合法页）")
        XCTAssertEqual(updates.first?.newRevision, 1)
        XCTAssertEqual(dataSource.refreshCount, 0, "已有快照不触发扫描")
    }

    func testBeginWithoutSnapshotGoesLoadingThenReady() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 2, failureCount: 0),
        ])
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        XCTAssertEqual(controller.state, .loading, "无快照 → 先 loading")

        // 扫描完成前快照就位（begin 的刷新任务在首个 await 点后才会读 currentSnapshot）
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1))
        await awaitState(controller, .ready)
        XCTAssertEqual(controller.state, .ready)
        XCTAssertEqual(controller.provider.pendingRevision, 1, "刷新后 pending 最新快照（idle 边界由装配层 apply）")
        XCTAssertEqual(dataSource.refreshCount, 1)
    }

    // MARK: - 空目录 / 失败 / 部分失败

    func testEmptyCatalogState() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 0, failureCount: 0),
        ])
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        XCTAssertEqual(controller.state, .loading)
        dataSource.setSnapshot(try makeSnapshot(titles: [], revision: 1))
        await awaitState(controller, .empty)
        XCTAssertEqual(controller.state, .empty, "空目录 → .empty（pageCount 0 合法空态）")
        XCTAssertEqual(dataSource.refreshCount, 1)
        XCTAssertEqual(controller.provider.pendingRevision, 1)
        XCTAssertNil(controller.provider.servedSnapshot, "pending 未提交 → served 无内容")
    }

    func testTotalFailureGoesPartialFailure() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: false, appCount: 0, failureCount: 3),
        ])
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        await awaitState(controller, .partialFailure)
        XCTAssertEqual(controller.state, .partialFailure, "整体失败 → .partialFailure")
    }

    func testSuccessWithFailureCountsGoesPartialFailure() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 5, failureCount: 2),
        ])
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        dataSource.setSnapshot(try makeSnapshot(titles: (0..<5).map { "App\($0)" }, revision: 1))
        await awaitState(controller, .partialFailure)
        XCTAssertEqual(controller.state, .partialFailure, "有失败分类计数 → .partialFailure（内容仍展示）")
        XCTAssertEqual(controller.provider.pendingRevision, 1)
    }

    // MARK: - 手动刷新：refreshing → 回稳定态

    func testManualRefreshTransitionsThroughRefreshing() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 0),
        ])
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha"], revision: 1))
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        await awaitState(controller, .ready)

        let refreshingSeen = expectation(description: "refreshing seen")
        controller.onStateChange = { state in
            if state == .refreshing { refreshingSeen.fulfill() }
        }
        controller.refreshNow()
        await fulfillment(of: [refreshingSeen], timeout: 3)
        await awaitState(controller, .ready)

        XCTAssertEqual(controller.state, .ready)
        XCTAssertEqual(dataSource.refreshCount, 1, "begin 走已有快照即时路径，仅手动刷新触发一次扫描")
    }

    /// cancelled 刷新 → 恢复刷新前状态。
    func testCancelledRefreshRestoresPreviousState() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 0),
            AppGridRefreshOutcome(succeeded: false, appCount: 0, failureCount: 0, cancelled: true),
        ])
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha"], revision: 1))
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        await awaitState(controller, .ready)
        controller.refreshNow()
        await awaitState(controller, .ready)
        XCTAssertEqual(controller.state, .ready, "被取代/取消的刷新不破坏稳定态")
        XCTAssertEqual(dataSource.refreshCount, 1)
    }

    // MARK: - 并发刷新 latest-wins（provider pending 只保留最新）

    func testRapidRefreshLatestWins() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 0),
            AppGridRefreshOutcome(succeeded: true, appCount: 3, failureCount: 0),
        ])
        let controller = makeController(dataSource: dataSource)

        controller.begin()
        // 第一轮进行中触发第二轮 → queued；两轮都完成后 pending = 最新快照
        dataSource.setSnapshot(try makeSnapshot(titles: ["A", "B", "C"], revision: 2))
        controller.refreshNow()

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(dataSource.refreshCount, 2, "进行中再触发 → 完成后补一轮")
        XCTAssertEqual(controller.provider.pendingRevision, 2, "latest-wins：pending 只保留最新 revision")
        XCTAssertEqual(controller.provider.servedRevision, nil, "手势期间绝不替换 served")
    }

    // MARK: - debounced rescan（可取消）

    func testDebouncedRescanFiresAfterInterval() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 0),
        ])
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha"], revision: 1))
        let controller = AppGridRefreshController(dataSource: dataSource, debounceInterval: 0.1)
        controller.begin()
        await awaitState(controller, .ready)

        let fired = expectation(description: "debounced refresh fired")
        dataSource.onRefresh = { fired.fulfill() }
        controller.scheduleRescan()
        await fulfillment(of: [fired], timeout: 3)
        XCTAssertEqual(dataSource.refreshCount, 1, "begin 即时路径无扫描；debounce 触发一次刷新")
    }

    func testCancelScheduledRescanPreventsFire() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 0),
        ])
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha"], revision: 1))
        let controller = AppGridRefreshController(dataSource: dataSource, debounceInterval: 0.1)
        controller.begin()
        await awaitState(controller, .ready)

        let unexpectedFire = expectation(description: "should not fire")
        unexpectedFire.isInverted = true
        dataSource.onRefresh = { unexpectedFire.fulfill() }

        controller.scheduleRescan()
        controller.cancelScheduledRescan()
        try await Task.sleep(nanoseconds: 400_000_000)

        await fulfillment(of: [unexpectedFire], timeout: 0.5)
        XCTAssertEqual(dataSource.refreshCount, 0, "取消后 debounce 不触发（begin 即时路径本就无扫描）")
    }

    func testMultipleSchedulesOnlyLastFires() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 0),
        ])
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha"], revision: 1))
        let controller = AppGridRefreshController(dataSource: dataSource, debounceInterval: 0.1)
        controller.begin()
        await awaitState(controller, .ready)

        let fired = expectation(description: "debounced refresh fired")
        dataSource.onRefresh = { fired.fulfill() }
        controller.scheduleRescan()
        controller.scheduleRescan()   // 覆盖前一个
        await fulfillment(of: [fired], timeout: 3)
        XCTAssertEqual(dataSource.refreshCount, 1, "间隔内多次调度只保留最后一次")
    }

    // MARK: - idle 边界 anchor remap 接线（§6.2 idle）

    func testApplyPendingAtIdleBoundaryFiresPresentationUpdate() async throws {
        let dataSource = ImmediateDataSource(outcomes: [
            AppGridRefreshOutcome(succeeded: true, appCount: 2, failureCount: 0),
        ])
        let controller = makeController(dataSource: dataSource)

        let updateSeen = expectation(description: "presentation update")
        controller.onPresentationUpdate = { _ in updateSeen.fulfill() }

        controller.begin()
        dataSource.setSnapshot(try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1))
        await awaitState(controller, .ready)
        XCTAssertEqual(controller.provider.hasPendingSnapshot, true, "刷新完成 → pending 就位（不打断手势）")

        // idle 边界（模拟 surface.onIdleBoundary → committedPage 0）
        let update = controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.newRevision, 1)
        XCTAssertEqual(controller.provider.servedRevision, 1)
        XCTAssertEqual(controller.provider.hasPendingSnapshot, false)

        await fulfillment(of: [updateSeen], timeout: 3)

        // 无 pending 时 idle 边界无操作
        XCTAssertNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
    }
}
