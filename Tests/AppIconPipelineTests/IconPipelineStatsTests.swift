// AppIconPipelineTests — stats（无隐私字段断言 + 计数器确定性序列）

import XCTest
@testable import AppIconPipeline

final class IconPipelineStatsTests: XCTestCase {
    /// Explorer C 约束：stats 仅计数；无字节/哈希/路径/bundle/url 字段。
    func testStatsContainsNoPrivacyFields() {
        let labels = Mirror(reflecting: IconPipelineStats()).children.compactMap { $0.label }
        XCTAssertEqual(Set(labels), Set(["requests", "cacheHits", "cacheMisses",
                                         "inFlightMerged", "cancellations",
                                         "evictions", "memoryPressurePurges"]))
        for label in labels {
            let lower = label.lowercased()
            XCTAssertFalse(lower.contains("byte"), "\(label)")
            XCTAssertFalse(lower.contains("hash"), "\(label)")
            XCTAssertFalse(lower.contains("path"), "\(label)")
            XCTAssertFalse(lower.contains("bundle"), "\(label)")
            XCTAssertFalse(lower.contains("url"), "\(label)")
        }
    }

    /// 确定性计数序列：miss → 合并 → 投递 → hit。
    func testStatsCounterSequence() {
        let loader = FakeLoader(delay: 0.1)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let generations = ValueBox<[UInt64]>([])
        let e1 = expectation(description: "gen1")
        pipeline.request(key: makeKey(1), generation: 1) { _, gen, _ in
            generations.set(generations.value + [gen])
            e1.fulfill()
        }
        let e2 = expectation(description: "gen2 merged")
        pipeline.request(key: makeKey(1), generation: 2) { _, gen, _ in
            generations.set(generations.value + [gen])
            e2.fulfill()
        }
        wait(for: [e1, e2], timeout: 3)

        let e3 = expectation(description: "gen3 hit")
        pipeline.request(key: makeKey(1), generation: 3) { _, gen, _ in
            generations.set(generations.value + [gen])
            e3.fulfill()
        }
        wait(for: [e3], timeout: 3)

        XCTAssertEqual(generations.value, [1, 2, 3], "each consumer receives its own generation")
        // 不变量：requests == cacheHits + cacheMisses（gen2 合并请求同样计为未命中）
        XCTAssertEqual(pipeline.stats, IconPipelineStats(requests: 3, cacheHits: 1,
                                                         cacheMisses: 2, inFlightMerged: 1,
                                                         cancellations: 0, evictions: 0,
                                                         memoryPressurePurges: 0))

        pipeline.shutdown()
    }
}
