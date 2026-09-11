//
//  CatalogPropertyTests.swift
//  AppCatalogCoreTests
//
//  §10.2 随机属性测试：任何输入下无重复 page slot、无越界、结果 deterministic。
//  用固定种子的确定性 LCG → 测试本身可重复（不 flaky）。
//

import XCTest
import AppCatalogCore

final class CatalogPropertyTests: XCTestCase {

    /// 确定性 LCG（种子固定 → 每次运行同一输入序列）。
    private struct SeededGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
        mutating func next() -> UInt64 {
            state = state &* 6364_1362_2384_6793_005 &+ 1442_6950_4088_9634_07
            return state
        }
        mutating func nextInt(_ bound: Int) -> Int { Int(next() % UInt64(max(1, bound))) }
        mutating func nextBool() -> Bool { next() & 1 == 1 }
    }

    /// count 条随机记录：唯一 URL/bundleID（去重不触发）；displayName 从含大小写/变音池取；
    /// 部分无 bundleID（走 fallback 身份）；rootPriority 0–2。
    private func randomRecords(_ count: Int, using gen: inout SeededGenerator) -> [AppRecord] {
        let names = ["Alpha", "alpha", "Beta", "gamma", "Notes", "notes", "Z", "ä"]
        return (0..<count).map { i in
            let name = names[gen.nextInt(names.count)]
            let hasBundleID = gen.nextBool()
            let u = URL(fileURLWithPath: "/Applications/App\(i).app")
            let id = hasBundleID
                ? AppID.bundleIdentifier("com.test.app\(i)")
                : AppID.canonicalURLFallback(u.standardizedFileURL)
            return CatalogFixture.record(id: id, displayName: name,
                                         bundleID: hasBundleID ? "com.test.app\(i)" : nil,
                                         url: u, icon: IconIdentity.from(appID: id),
                                         rootPriority: gen.nextInt(3))
        }
    }

    func testRandomPropertyNoDuplicateSlotsNoOutOfBounds() throws {
        var gen = SeededGenerator(seed: 0x5EED)
        for _ in 0..<25 {
            let count = gen.nextInt(200)
            let snapshot = try TestSupport.snapshot(randomRecords(count, using: &gen))
            let plan = CatalogPlanner().plan(snapshot: snapshot, itemsPerPage: 35)
            XCTAssertEqual(plan.itemCount, snapshot.records.count)
            XCTAssertEqual(plan.pageCount, snapshot.records.isEmpty ? 0 : (snapshot.records.count + 34) / 35)

            var seen = Set<AppID>()
            var nonNil = 0
            for page in 0..<plan.pageCount {
                for slot in 0..<35 {
                    if let id = plan.appID(page: page, slot: slot) {
                        nonNil += 1
                        XCTAssertTrue(seen.insert(id).inserted, "重复 page slot：page \(page) slot \(slot)")
                    }
                }
            }
            // 越界访问必须全部 nil（不崩溃、不越界）
            XCTAssertNil(plan.appID(page: -1, slot: 0))
            XCTAssertNil(plan.appID(page: 0, slot: -1))
            XCTAssertNil(plan.appID(page: plan.pageCount, slot: 0))
            XCTAssertNil(plan.appID(page: 0, slot: 35))
            // 每项恰好出现一次 → 无重复 slot、无遗漏、无越界
            XCTAssertEqual(nonNil, snapshot.records.count)
            XCTAssertEqual(seen.count, snapshot.records.count)
        }
    }

    func testRandomPropertyDeterministicRepeatedBuild() throws {
        var gen = SeededGenerator(seed: 0xDEAD)
        for _ in 0..<15 {
            let records = randomRecords(gen.nextInt(120), using: &gen)
            let s1 = try TestSupport.snapshot(records)
            let s2 = try TestSupport.snapshot(records)
            XCTAssertEqual(s1.records, s2.records)
        }
    }

    func testRandomPropertyShuffledInputSameOutput() throws {
        var gen = SeededGenerator(seed: 0xBEEF)
        for _ in 0..<15 {
            let records = randomRecords(gen.nextInt(120), using: &gen)
            let s1 = try TestSupport.snapshot(records)
            let s2 = try TestSupport.snapshot(records.reversed())
            XCTAssertEqual(s1.records, s2.records, "输入顺序不得影响输出")
        }
    }

    func testRandomPropertyRemapConsistency() throws {
        var gen = SeededGenerator(seed: 0xC0DE)
        for _ in 0..<20 {
            let snapshot = try TestSupport.snapshot(randomRecords(gen.nextInt(80), using: &gen))
            guard !snapshot.records.isEmpty else { continue }
            let planner = CatalogPlanner()
            // 存在的锚点 → located，且页 == pageIndex(of:)
            let anchor = snapshot.records[gen.nextInt(snapshot.records.count)].id
            let (_, outcome) = planner.remap(snapshot: snapshot, anchor: anchor, itemsPerPage: 35)
            let expectedPage = planner.pageIndex(of: anchor, in: snapshot, itemsPerPage: 35)!
            XCTAssertEqual(outcome, .located(pageIndex: expectedPage))
            // 幽灵锚点（全序最大、不在 catalog）→ 非 located / 非 emptyCatalog
            let ghost = AppID.bundleIdentifier("com.test.zzz-\(gen.nextInt(1_000_000))")
            let (_, ghostOutcome) = planner.remap(snapshot: snapshot, anchor: ghost, itemsPerPage: 35)
            switch ghostOutcome {
            case .successor, .predecessor, .clamped:
                break
            case .located, .emptyCatalog:
                XCTFail("幽灵锚点不应得到 \(ghostOutcome)")
            }
        }
    }
}
