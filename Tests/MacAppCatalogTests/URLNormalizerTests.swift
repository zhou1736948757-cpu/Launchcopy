//
//  URLNormalizerTests.swift
//  MacAppCatalogTests
//
//  Phase 1B — URL 规范化与根内含性（wave1-interfaces.md §C）。
//

import XCTest
@testable import MacAppCatalog

final class URLNormalizerTests: XCTestCase {
    private let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)

    func testContainedChild() {
        let app = URL(fileURLWithPath: "/Applications/Safari.app", isDirectory: true)
        XCTAssertTrue(URLNormalizer.isContained(app, in: applications))
    }

    func testContainedEqual() {
        XCTAssertTrue(URLNormalizer.isContained(applications, in: applications))
    }

    func testNotContainedSiblingPrefix() {
        // 前缀陷阱：/ApplicationsX 不得被误判为位于 /Applications 内。
        let sibling = URL(fileURLWithPath: "/ApplicationsX/Secret.app", isDirectory: true)
        XCTAssertFalse(URLNormalizer.isContained(sibling, in: applications))
    }

    func testNotContainedOutside() {
        let outside = URL(fileURLWithPath: "/System/Applications/Safari.app", isDirectory: true)
        XCTAssertFalse(URLNormalizer.isContained(outside, in: applications))
    }

    func testContainedWithTrailingSlashRoot() {
        let root = URL(fileURLWithPath: "/Applications/", isDirectory: true)
        XCTAssertTrue(URLNormalizer.isContained(URL(fileURLWithPath: "/Applications/A.app"), in: root))
    }

    func testContainedFilesystemRoot() {
        let root = URL(fileURLWithPath: "/")
        XCTAssertTrue(URLNormalizer.isContained(URL(fileURLWithPath: "/Applications/A.app"), in: root))
    }

    func testCanonicalizeInsideRoot() {
        let url = URL(fileURLWithPath: "/Applications/Deep/../X.app", isDirectory: true)
        guard let canonical = URLNormalizer.canonicalize(url, under: applications) else {
            return XCTFail("expected canonicalization inside root")
        }
        XCTAssertEqual(canonical.path, "/Applications/X.app")
    }

    func testCanonicalizeOutsideRootReturnsNil() {
        let url = URL(fileURLWithPath: "/Users/Shared/X.app", isDirectory: true)
        XCTAssertNil(URLNormalizer.canonicalize(url, under: applications))
    }

    func testCanonicalizeEqualRoot() {
        XCTAssertEqual(URLNormalizer.canonicalize(applications, under: applications)?.path, "/Applications")
    }

    func testStandardizedRemovesDuplicateSlash() {
        let url = URL(fileURLWithPath: "//Applications//X.app", isDirectory: true)
        XCTAssertTrue(URLNormalizer.isContained(url, in: applications))
    }
}
