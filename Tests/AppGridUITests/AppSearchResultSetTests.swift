// AppGridUITests — AppSearchResultSetTests（Phase 1D 纯搜索域；§16.1 搜索域测试）
// 实现：T-1D-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 覆盖：resultCount / isEmpty、0/1/35/36/70 结果分页、query generation 单调、
// 旧 generation / 旧 catalog revision 拒绝、records 保持 base 顺序。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class AppSearchResultSetTests: XCTestCase {

    private func makeRecords(_ count: Int) -> [AppRecord] {
        (0..<count).map { i in
            let id = AppID.bundleIdentifier("fixture.record\(i)")
            return CatalogFixture.record(id: id, displayName: "Record \(i)", bundleID: "fixture.record\(i)",
                                         url: CatalogFixture.tempURL(named: "record\(i).app"),
                                         icon: IconIdentity.from(appID: id), rootPriority: 0)
        }
    }

    // MARK: - resultCount / isEmpty

    func testResultCount() {
        let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(3),
                                     queryGeneration: AppSearchGeneration(7),
                                     records: makeRecords(5))
        XCTAssertEqual(set.resultCount, 5)
        XCTAssertFalse(set.isEmpty)
    }

    func testIsEmpty() {
        let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(3),
                                     queryGeneration: AppSearchGeneration(7),
                                     records: [])
        XCTAssertEqual(set.resultCount, 0)
        XCTAssertTrue(set.isEmpty)
    }

    // MARK: - 0/1/35/36/70 结果分页（pageCount = ceil(resultCount / itemsPerPage)）

    func testPagingZeroOneThirtyFiveThirtySixSeventy() {
        let cases: [(Int, Int)] = [
            (0, 0),   // 0 结果 → 0 页
            (1, 1),   // 1 结果 → 1 页
            (35, 1),  // 35 结果 → 1 页
            (36, 2),  // 36 结果 → 2 页
            (70, 2),  // 70 结果 → 2 页
        ]
        for (count, expectedPages) in cases {
            let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(1),
                                         queryGeneration: AppSearchGeneration(1),
                                         records: makeRecords(count))
            XCTAssertEqual(set.pageCount(itemsPerPage: 35), expectedPages,
                           "\(count) 结果应得 \(expectedPages) 页")
        }
    }

    // MARK: - query generation 单调

    func testQueryGenerationMonotonic() {
        var g = AppSearchGeneration.zero
        var previous = g.value
        for _ in 0..<100 {
            g = g.incremented()
            XCTAssertGreaterThan(g.value, previous)
            previous = g.value
        }
        XCTAssertGreaterThan(AppSearchGeneration(5), AppSearchGeneration(4))
        XCTAssertLessThan(AppSearchGeneration(4), AppSearchGeneration(5))
    }

    // MARK: - 旧 generation / 旧 catalog revision 拒绝（latest-wins）

    func testCurrentGenerationAndRevisionAccepted() {
        let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(9),
                                     queryGeneration: AppSearchGeneration(4),
                                     records: makeRecords(2))
        XCTAssertTrue(set.isCurrent(latestGeneration: AppSearchGeneration(4),
                                   latestRevision: CatalogRevision(9)))
    }

    func testOldGenerationRejected() {
        let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(9),
                                     queryGeneration: AppSearchGeneration(3),
                                     records: makeRecords(2))
        XCTAssertFalse(set.isCurrent(latestGeneration: AppSearchGeneration(4),
                                     latestRevision: CatalogRevision(9)))
    }

    func testOldCatalogRevisionRejected() {
        let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(8),
                                     queryGeneration: AppSearchGeneration(4),
                                     records: makeRecords(2))
        XCTAssertFalse(set.isCurrent(latestGeneration: AppSearchGeneration(4),
                                     latestRevision: CatalogRevision(9)))
    }

    func testBothAxesStaleRejected() {
        let set = AppSearchResultSet(baseCatalogRevision: CatalogRevision(7),
                                     queryGeneration: AppSearchGeneration(2),
                                     records: makeRecords(2))
        XCTAssertFalse(set.isCurrent(latestGeneration: AppSearchGeneration(4),
                                     latestRevision: CatalogRevision(9)))
    }

    // MARK: - records 保持 base 顺序

    func testRecordsPreserveBaseOrder() {
        let snapshot = try! makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"],
                                         revision: 1)
        // 取 base 快照的稳定子序列（第 0、2、4 项；不假设具体 displayName 排序）
        let subset = [snapshot.records[0], snapshot.records[2], snapshot.records[4]]
        let set = AppSearchResultSet(baseCatalogRevision: snapshot.revision,
                                     queryGeneration: AppSearchGeneration(1),
                                     records: subset)
        XCTAssertEqual(set.records.count, 3)
        // 相对顺序与 base 一致：subset 中相邻项的 base 索引严格递增
        let baseIndex = Dictionary(uniqueKeysWithValues: snapshot.records.enumerated().map { ($0.element.id, $0.offset) })
        let indices = set.records.map { baseIndex[$0.id]! }
        XCTAssertEqual(indices, indices.sorted())
        XCTAssertEqual(Set(indices).count, indices.count)
    }
}
