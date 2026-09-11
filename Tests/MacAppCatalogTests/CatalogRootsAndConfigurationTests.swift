//
//  CatalogRootsAndConfigurationTests.swift
//  MacAppCatalogTests
//
//  Phase 1B — 受限根默认值与扫描配置默认值（§5.2 隐私上界 / wave1-interfaces.md §C）。
//

import XCTest
@testable import MacAppCatalog

final class CatalogRootsAndConfigurationTests: XCTestCase {
    func testDefaultRootsAreFourRestrictedRoots() {
        let roots = CatalogRoots.defaults
        XCTAssertEqual(roots.count, 4)
        XCTAssertEqual(roots[0].path, "/Applications")
        XCTAssertEqual(roots[1].path, "/System/Applications")
        XCTAssertEqual(roots[2].path, "/System/Applications/Utilities")
        XCTAssertEqual(roots[3].path,
                       FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path)
    }

    func testDefaultRootsNeverIncludeBroadScope() {
        // 隐私上界（§3.3）：默认根不得包含 /、整个 ~、网络卷。
        for root in CatalogRoots.defaults {
            XCTAssertNotEqual(root.path, "/")
            XCTAssertNotEqual(root.path, FileManager.default.homeDirectoryForCurrentUser.path)
            XCTAssertFalse(root.path.contains("/Volumes"))
        }
    }

    func testScanConfigurationDefaults() {
        let config = ScanConfiguration()
        XCTAssertEqual(config.roots, CatalogRoots.defaults)
        XCTAssertTrue(config.dedupeOverlappingRoots)
        XCTAssertFalse(config.followDirectorySymlinks)   // 防 symlink cycle 默认不跟随
        XCTAssertTrue(config.stopAtAppBundle)            // .app 后不进入 bundle 内部
        XCTAssertTrue(config.fileManager === FileManager.default)
    }

    func testDedupeRootsDropsContainedRoots() {
        // Utilities ⊂ /System/Applications → 只保留父根；顺序与优先级保持。
        let roots = CatalogScanner.dedupeRoots(CatalogRoots.defaults)
        XCTAssertEqual(roots.count, 3)
        XCTAssertEqual(roots[0].path, "/Applications")
        XCTAssertEqual(roots[1].path, "/System/Applications")
        XCTAssertEqual(roots[2].path,
                       FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path)
        XCTAssertFalse(roots.contains { $0.path == "/System/Applications/Utilities" })
    }

    func testDedupeRootsLaterRootSubsumesEarlier() {
        let base = URL(fileURLWithPath: "/tmp/base", isDirectory: true)
        let sub = base.appendingPathComponent("sub", isDirectory: true)
        // [sub, base]：后到的 base 包含先到的 sub → sub 被移除。
        let roots = CatalogScanner.dedupeRoots([sub, base])
        XCTAssertEqual(roots, [base.standardizedFileURL])
    }

    func testDedupeRootsIdenticalDuplicates() {
        let a = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let roots = CatalogScanner.dedupeRoots([a, a])
        XCTAssertEqual(roots.count, 1)
    }
}
