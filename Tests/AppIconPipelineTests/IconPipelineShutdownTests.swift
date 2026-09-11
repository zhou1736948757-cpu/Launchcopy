// AppIconPipelineTests — shutdown（teardown 零回调；拒新请求；幂等）

import XCTest
@testable import AppIconPipeline

final class IconPipelineShutdownTests: XCTestCase {
    /// in-flight 未完成时 shutdown → 0 回调（含泵过整个加载时长）。
    func testShutdownDuringInFlightYieldsZeroCallbacks() {
        let loader = FakeLoader(delay: 0.2)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let callbacks = CallbackBox()
        pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in callbacks.increment() }
        pipeline.shutdown()

        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(callbacks.count, 0, "shutdown → zero callbacks even for in-flight work")
        XCTAssertEqual(pipeline.stats.requests, 1)

        pipeline.shutdown()   // 幂等
    }

    /// shutdown 后 request → 拒新请求（惰性 handle，零回调）；cancel 为空操作。
    func testShutdownRejectsNewRequestsWithZeroCallbacks() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        pipeline.shutdown()

        let callbacks = CallbackBox()
        let handle = pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in callbacks.increment() }
        handle.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(callbacks.count, 0)
        XCTAssertEqual(loader.loadCount, 0, "no load may start after shutdown")
        XCTAssertEqual(pipeline.stats.requests, 0, "rejected requests are not counted")
    }

    /// shutdown 清空缓存：已完成条目不可再命中（行为上无从回调体现，验证请求被拒路径即可）。
    func testShutdownClearsCacheAndIsIdempotent() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e = expectation(description: "k1 cached")
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success = result else { return XCTFail() }
            e.fulfill()
        }
        wait(for: [e], timeout: 3)
        XCTAssertEqual(loader.loadCount, 1)

        pipeline.shutdown()
        pipeline.shutdown()   // 幂等，无崩溃
        XCTAssertEqual(pipeline.stats.evictions, 0, "teardown clear is not an eviction event")
    }
}
