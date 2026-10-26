// AppIconPipelineTests — 取消（单 consumer / cancelAll / 幂等 / generation 过期拒绝）

import XCTest
@testable import AppIconPipeline

final class IconPipelineCancelTests: XCTestCase {
    /// 单 consumer 取消：0 回调；底层 in-flight 被取消；重请求 = 全新加载。
    func testCancelSingleConsumerYieldsZeroCallbacks() {
        let loader = FakeLoader(delay: 0.2)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let callbacks = CallbackBox()
        let handle = pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in
            callbacks.increment()
        }
        handle.cancel()
        handle.cancel()   // 幂等

        // 泵过整个加载时长：若有投递早已发生
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertEqual(callbacks.count, 0, "cancelled consumer must never be called")
        XCTAssertEqual(pipeline.stats.cancellations, 1, "double cancel is idempotent")
        XCTAssertEqual(pipeline.stats.requests, 1)

        // Cancellation before permit admission need not invoke the loader.
        let oldLoads = loader.loadCount
        XCTAssertLessThanOrEqual(oldLoads, 1)
        // 取消后重请求 → 全新加载（旧 in-flight 已拆除）
        let e = expectation(description: "reload delivered")
        pipeline.request(key: makeKey(1), generation: 2) { _, _, result in
            guard case .success = result else { return XCTFail() }
            e.fulfill()
        }
        wait(for: [e], timeout: 3)
        XCTAssertEqual(loader.loadCount, oldLoads + 1)

        pipeline.shutdown()
    }

    /// 多 consumer 同 key：取消其中一个 → 其余仍收到结果；底层只加载一次。
    func testCancelOneConsumerOthersStillDelivered() {
        let loader = FakeLoader(delay: 0.15)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let cancelled = expectation(description: "cancelled consumer")
        cancelled.isInverted = true
        let handle = pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in
            cancelled.fulfill()
        }
        let survivor = expectation(description: "survivor delivered")
        let survivorGeneration = ValueBox<UInt64?>(nil)
        pipeline.request(key: makeKey(1), generation: 2) { _, gen, result in
            guard case .success = result else { return XCTFail() }
            survivorGeneration.set(gen)
            survivor.fulfill()
        }
        handle.cancel()

        wait(for: [survivor], timeout: 3)
        XCTAssertEqual(survivorGeneration.value, 2)
        XCTAssertEqual(loader.loadCount, 1, "other consumer keeps the load alive")
        XCTAssertEqual(pipeline.stats.cancellations, 1)
        XCTAssertEqual(pipeline.stats.inFlightMerged, 1)
        wait(for: [cancelled], timeout: 0.3)

        pipeline.shutdown()
    }

    /// cancelAll(for:)：该 key 全部 consumer 0 回调；底层取消；重请求 = 全新加载。
    func testCancelAllZeroCallbacksAndFreshReload() {
        let loader = FakeLoader(delay: 0.2)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let callbacks = CallbackBox()
        pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in callbacks.increment() }
        pipeline.request(key: makeKey(1), generation: 2) { _, _, _ in callbacks.increment() }
        XCTAssertEqual(pipeline.stats.inFlightMerged, 1)

        pipeline.cancelAll(for: makeKey(1))
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertEqual(callbacks.count, 0, "cancelAll → zero callbacks")
        XCTAssertEqual(pipeline.stats.cancellations, 2)
        let oldLoads = loader.loadCount
        XCTAssertLessThanOrEqual(oldLoads, 1, "Cancellation before admission may avoid the load entirely")

        let e = expectation(description: "fresh reload")
        pipeline.request(key: makeKey(1), generation: 3) { _, _, result in
            guard case .success = result else { return XCTFail() }
            e.fulfill()
        }
        wait(for: [e], timeout: 3)
        XCTAssertEqual(loader.loadCount, oldLoads + 1, "fresh load after cancelAll")

        pipeline.shutdown()
    }

    /// generation 过期拒绝（stale completion = 0）：
    /// 同 key 合并场景下，被取消的旧 generation consumer 的完成回调必须为 0，
    /// 存活的消费者收到自己的（新）generation —— 防复用串图。
    func testStaleGenerationCompletionIsNeverDelivered() {
        let loader = FakeLoader(delay: 0.15)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let staleCallbacks = CallbackBox()
        let staleHandle = pipeline.request(key: makeKey(1), generation: 5) { _, _, _ in
            staleCallbacks.increment()
        }
        let fresh = expectation(description: "gen6 delivered")
        let freshGeneration = ValueBox<UInt64?>(nil)
        pipeline.request(key: makeKey(1), generation: 6) { _, gen, result in
            guard case .success = result else { return XCTFail() }
            freshGeneration.set(gen)
            fresh.fulfill()
        }

        staleHandle.cancel()
        wait(for: [fresh], timeout: 3)
        XCTAssertEqual(staleCallbacks.count, 0, "stale generation completion must not land")
        XCTAssertEqual(freshGeneration.value, 6)
        XCTAssertEqual(loader.loadCount, 1)
        XCTAssertEqual(pipeline.stats.cancellations, 1)

        pipeline.shutdown()
    }

    /// 取消发生在加载完成之后（投递已定）：cancel 返回 false 语义（幂等），不重复计数。
    func testCancelAfterDeliveryIsNoOp() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e = expectation(description: "delivered")
        let handle = pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success = result else { return XCTFail() }
            e.fulfill()
        }
        wait(for: [e], timeout: 3)
        handle.cancel()
        XCTAssertEqual(pipeline.stats.cancellations, 0, "already delivered → cancel is no-op")

        pipeline.shutdown()
    }
}
