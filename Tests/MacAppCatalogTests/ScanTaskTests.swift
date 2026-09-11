//
//  ScanTaskTests.swift
//  MacAppCatalogTests
//
//  Phase 1B — ScanTask 取消语义（wave1-interfaces.md §C：cancel 幂等、条目间检查）。
//

import XCTest
@testable import MacAppCatalog

final class ScanTaskTests: XCTestCase {
    func testInitiallyNotCancelled() {
        let task = ScanTask()
        XCTAssertFalse(task.isCancelled)
    }

    func testCancelFlipsFlag() {
        let task = ScanTask()
        task.cancel()
        XCTAssertTrue(task.isCancelled)
    }

    func testCancelIsIdempotent() {
        let task = ScanTask()
        task.cancel()
        task.cancel()
        task.cancel()
        XCTAssertTrue(task.isCancelled)
    }

    func testConcurrentCancelIsSafe() {
        // 并发取消无崩溃/无数据竞争（NSLock 保护）。
        let task = ScanTask()
        let group = DispatchGroup()
        for _ in 0..<32 {
            DispatchQueue.global().async(group: group) {
                task.cancel()
                _ = task.isCancelled
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(task.isCancelled)
    }
}
