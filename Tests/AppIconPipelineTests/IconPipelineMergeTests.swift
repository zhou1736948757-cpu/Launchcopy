// AppIconPipelineTests — in-flight 合并 / 并发上限 / 失败 placeholder

import XCTest
@testable import AppIconPipeline

final class IconPipelineMergeTests: XCTestCase {
    /// 同 key 并发请求 → 单次底层加载；两 consumer 各自收到自己的 generation。
    func testInFlightMergeSingleLoadPerKey() {
        let loader = FakeLoader(delay: 0.15)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let first = expectation(description: "gen1 delivered")
        let firstGeneration = ValueBox<UInt64?>(nil)
        let second = expectation(description: "gen2 delivered")
        let secondGeneration = ValueBox<UInt64?>(nil)

        pipeline.request(key: makeKey(1), generation: 1) { _, gen, result in
            guard case .success = result else { return XCTFail("expected success") }
            firstGeneration.set(gen)
            first.fulfill()
        }
        pipeline.request(key: makeKey(1), generation: 2) { _, gen, result in
            guard case .success = result else { return XCTFail("expected success") }
            secondGeneration.set(gen)
            second.fulfill()
        }

        wait(for: [first, second], timeout: 3)
        XCTAssertEqual(loader.loadCount, 1, "same key in-flight → single load")
        XCTAssertEqual(firstGeneration.value, 1)
        XCTAssertEqual(secondGeneration.value, 2)
        XCTAssertEqual(pipeline.stats.inFlightMerged, 1)
        // 计数不变量：requests == cacheHits + cacheMisses（合并请求也属未命中）
        XCTAssertEqual(pipeline.stats.cacheMisses, 2)
        XCTAssertEqual(pipeline.stats.requests, 2)

        pipeline.shutdown()
    }

    /// 不同 key 并发 → 各自加载；maxConcurrentLoads=2 限制并发峰值 ≤ 2。
    func testMaxConcurrentLoadsBound() {
        let loader = FakeLoader(delay: 0.08)
        let pipeline = IconPipeline(loader: loader,
                                    limits: .init(maxConcurrentLoads: 2))

        var expectations: [XCTestExpectation] = []
        for n in 1...6 {
            let e = expectation(description: "k\(n)")
            expectations.append(e)
            pipeline.request(key: makeKey(n), generation: UInt64(n)) { _, _, result in
                guard case .success = result else { return XCTFail("expected success") }
                e.fulfill()
            }
        }

        wait(for: expectations, timeout: 5)
        XCTAssertEqual(loader.loadCount, 6)
        XCTAssertLessThanOrEqual(loader.maxActiveCount, 2, "concurrency must not exceed limit")

        pipeline.shutdown()
    }

    /// loader 失败 → 全部 consumer 收到 failed(.loadFailed)（UI 显示中性 placeholder）；
    /// 失败结果不入缓存 → 重请求再次 miss。
    func testLoadFailureDeliversFailedPlaceholder() {
        let loader = FakeLoader(failingKeys: [makeKey(1)])
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let failed = expectation(description: "failed delivered")
        let deliveredFailure = ValueBox<IconFailure?>(nil)
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .failed(let failure) = result else { return XCTFail("expected failure") }
            deliveredFailure.set(failure)
            failed.fulfill()
        }
        wait(for: [failed], timeout: 3)
        XCTAssertEqual(deliveredFailure.value, .loadFailed)
        XCTAssertEqual(loader.loadCount, 1)

        // 失败不缓存：再次请求 → 再次 miss → 再次 load
        let again = expectation(description: "failed again")
        pipeline.request(key: makeKey(1), generation: 2) { _, _, result in
            guard case .failed = result else { return XCTFail("expected failure") }
            again.fulfill()
        }
        wait(for: [again], timeout: 3)
        XCTAssertEqual(loader.loadCount, 2)
        XCTAssertEqual(pipeline.stats.cacheHits, 0)

        pipeline.shutdown()
    }
}
