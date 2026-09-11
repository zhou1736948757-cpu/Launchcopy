// AppIconPipelineTests — 有界缓存（count/cost 上界、LRU、purge、memory pressure）

import AppKit
import XCTest
@testable import AppIconPipeline

final class IconPipelineCacheTests: XCTestCase {
    /// miss → load → cache hit；cache hit 不重复底层加载。
    func testMissThenLoadThenHit() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let first = expectation(description: "first delivery")
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success = result else { return XCTFail("expected success") }
            first.fulfill()
        }
        wait(for: [first], timeout: 3)
        XCTAssertEqual(loader.loadCount, 1)
        XCTAssertEqual(pipeline.stats.cacheMisses, 1)
        XCTAssertEqual(pipeline.stats.cacheHits, 0)

        let second = expectation(description: "second delivery")
        pipeline.request(key: makeKey(1), generation: 2) { _, _, result in
            guard case .success = result else { return XCTFail("expected success") }
            second.fulfill()
        }
        wait(for: [second], timeout: 3)
        XCTAssertEqual(loader.loadCount, 1, "cache hit must not reload")
        XCTAssertEqual(pipeline.stats.cacheHits, 1)
        XCTAssertEqual(pipeline.stats.cacheMisses, 1)

        pipeline.shutdown()
    }

    /// count 上界：maxCount=2 时第 3 个 key 驱逐最旧（LRU），被驱逐 key 重请求 = 再次 miss。
    func testCountBoundEvictsLRU() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader,
                                    limits: .init(maxCount: 2, maxCost: 64 << 20))

        for n in 1...3 {
            let e = expectation(description: "deliver k\(n)")
            pipeline.request(key: makeKey(n), generation: UInt64(n)) { _, _, result in
                guard case .success = result else { return XCTFail("expected success") }
                e.fulfill()
            }
            wait(for: [e], timeout: 3)
        }
        XCTAssertEqual(loader.loadCount, 3)
        XCTAssertEqual(pipeline.stats.cacheMisses, 3)

        // k3 最新 → 命中；k1 最旧 → 已被驱逐
        let hit = expectation(description: "k3 hit")
        pipeline.request(key: makeKey(3), generation: 4) { _, _, _ in hit.fulfill() }
        wait(for: [hit], timeout: 3)
        XCTAssertEqual(loader.loadCount, 3, "k3 still cached")

        let missAgain = expectation(description: "k1 reload")
        pipeline.request(key: makeKey(1), generation: 5) { _, _, _ in missAgain.fulfill() }
        wait(for: [missAgain], timeout: 3)
        XCTAssertEqual(loader.loadCount, 4, "k1 was evicted → reload")
        XCTAssertGreaterThanOrEqual(pipeline.stats.evictions, 1)

        pipeline.shutdown()
    }

    /// cost 上界：maxCost 只容纳 1 个 64×64（cost=16384）条目时，第二个 key 插入驱逐第一个。
    func testCostBoundEvicts() {
        let image64 = makeIconImage(pixelWidth: 64, pixelHeight: 64)   // cost = 16384
        let loader = FakeLoader(image: image64)
        // 单个条目 16384 ≤ 20000；两个条目 32768 > 20000 → 只能留 1 个
        let pipeline = IconPipeline(loader: loader,
                                    limits: .init(maxCount: 8, maxCost: 20_000))

        let e1 = expectation(description: "k1")
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success = result else { return XCTFail() }
            e1.fulfill()
        }
        wait(for: [e1], timeout: 3)

        let e2 = expectation(description: "k2")
        pipeline.request(key: makeKey(2), generation: 2) { _, _, result in
            guard case .success = result else { return XCTFail() }
            e2.fulfill()
        }
        wait(for: [e2], timeout: 3)
        XCTAssertGreaterThanOrEqual(pipeline.stats.evictions, 1)

        // k1 被 cost 驱逐 → 重请求 = miss
        let reload = expectation(description: "k1 reload")
        pipeline.request(key: makeKey(1), generation: 3) { _, _, _ in reload.fulfill() }
        wait(for: [reload], timeout: 3)
        XCTAssertEqual(loader.loadCount, 3)

        pipeline.shutdown()
    }

    /// purgeExpired：插入时间早于阈值 → 全部驱逐，重请求 = miss。
    func testPurgeExpired() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e1 = expectation(description: "k1")
        pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in e1.fulfill() }
        wait(for: [e1], timeout: 3)

        pipeline.purgeExpired(before: Date().addingTimeInterval(1_000_000))
        XCTAssertEqual(pipeline.stats.evictions, 1)

        let e2 = expectation(description: "k1 reload")
        pipeline.request(key: makeKey(1), generation: 2) { _, _, _ in e2.fulfill() }
        wait(for: [e2], timeout: 3)
        XCTAssertEqual(loader.loadCount, 2)

        pipeline.shutdown()
    }

    /// purgeAll：显式清空，重请求 = miss；计入 evictions。
    func testPurgeAll() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e1 = expectation(description: "k1")
        pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in e1.fulfill() }
        wait(for: [e1], timeout: 3)

        pipeline.purgeAll()
        XCTAssertEqual(pipeline.stats.evictions, 1)

        let e2 = expectation(description: "k1 reload")
        pipeline.request(key: makeKey(1), generation: 2) { _, _, _ in e2.fulfill() }
        wait(for: [e2], timeout: 3)
        XCTAssertEqual(loader.loadCount, 2)

        pipeline.shutdown()
    }

    /// memory pressure：通知 → 清缓存；重请求 = miss；计数走 memoryPressurePurges。
    func testMemoryPressurePurge() {
        let loader = FakeLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e1 = expectation(description: "k1")
        pipeline.request(key: makeKey(1), generation: 1) { _, _, _ in e1.fulfill() }
        wait(for: [e1], timeout: 3)

        NotificationCenter.default.post(name: memoryWarningNotificationName,
                                        object: nil)
        XCTAssertEqual(pipeline.stats.memoryPressurePurges, 1)
        XCTAssertEqual(pipeline.stats.evictions, 0, "pressure purge is not an LRU eviction")

        let e2 = expectation(description: "k1 reload after pressure")
        pipeline.request(key: makeKey(1), generation: 2) { _, _, _ in e2.fulfill() }
        wait(for: [e2], timeout: 3)
        XCTAssertEqual(loader.loadCount, 2)

        pipeline.shutdown()
    }
}
