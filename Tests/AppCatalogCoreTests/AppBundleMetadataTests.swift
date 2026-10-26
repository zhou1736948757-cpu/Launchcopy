import AppCatalogCore
import Foundation
import XCTest

final class AppBundleMetadataTests: XCTestCase {
    private func record(metadata: AppBundleMetadata = .init()) -> AppRecord {
        let id = AppID.bundleIdentifier("fixture.library.core")
        return AppRecord(id: id, displayName: "Fixture", bundleIdentifier: "fixture.library.core",
                         canonicalURL: URL(fileURLWithPath: "/SyntheticApps/Fixture.app"),
                         iconIdentity: .from(appID: id), sourceRootPriority: 0,
                         bundleMetadata: metadata)
    }

    func testCompatibleRecordInitializerDefaultsToEmptyMetadata() {
        let id = AppID.bundleIdentifier("fixture.library.legacy")
        let value = AppRecord(id: id, displayName: "Legacy", bundleIdentifier: "fixture.library.legacy",
                              canonicalURL: URL(fileURLWithPath: "/SyntheticApps/Legacy.app"),
                              iconIdentity: .from(appID: id), sourceRootPriority: 0)
        XCTAssertEqual(value.bundleMetadata, AppBundleMetadata())
        XCTAssertNil(value.bundleMetadata.declaredCategoryIdentifier)
        XCTAssertNil(value.bundleMetadata.version)
        XCTAssertNil(value.bundleMetadata.build)
    }

    func testMetadataNormalizesOptionalDeclarationsWithoutVersionInference() {
        let value = AppBundleMetadata(declaredCategoryIdentifier: " public.app-category.utilities ",
                                      version: " 2026 beta ", build: " 007 ")
        XCTAssertEqual(value.declaredCategoryIdentifier, "public.app-category.utilities")
        XCTAssertEqual(value.version, "2026 beta")
        XCTAssertEqual(value.build, "007")
        XCTAssertEqual(AppBundleMetadata(version: "1.2").build, nil)
        XCTAssertEqual(AppBundleMetadata(build: "42").version, nil)
    }

    func testBlankAndEmbeddedControlMetadataDegradeIndependentlyToUnknown() {
        for malformed in ["", " \t\r\n ", "\u{00A0}\u{3000}", "1\u{0000}2", "1\n2", "1\t2"] {
            XCTAssertEqual(AppBundleMetadata(declaredCategoryIdentifier: malformed,
                                             version: malformed, build: malformed), .init())
            XCTAssertEqual(AppBundleMetadata(version: malformed, build: "10").build, "10")
        }
    }

    func testMetadataChangesValueEqualityButNotAppOrIconIdentity() {
        let old = record()
        let updated = record(metadata: .init(version: "2", build: "200"))
        XCTAssertNotEqual(old, updated)
        XCTAssertEqual(old.id, updated.id)
        XCTAssertEqual(old.iconIdentity, updated.iconIdentity)
        XCTAssertEqual(old.canonicalURL, updated.canonicalURL)
        XCTAssertEqual(Set([old, updated]).count, 2)
    }

    func testOptionalStringsAcceptExactly1024UTF8BytesAndRejectOversizeBeforeTrimming() {
        for boundary in [String(repeating: "a", count: 1024),
                         String(repeating: "é", count: 512),
                         String(repeating: "😀", count: 256)] {
            XCTAssertEqual(boundary.utf8.count, 1024)
            let accepted = AppBundleMetadata(declaredCategoryIdentifier: boundary, version: boundary, build: boundary)
            XCTAssertEqual(accepted.declaredCategoryIdentifier, boundary)
            XCTAssertEqual(accepted.version, boundary)
            XCTAssertEqual(accepted.build, boundary)
            for oversize in [boundary + "a", " " + boundary, boundary + " "] {
                XCTAssertEqual(AppBundleMetadata(declaredCategoryIdentifier: oversize,
                                                 version: oversize, build: oversize), .init())
            }
        }
        let oversizedWhitespace = String(repeating: " ", count: 1024) + "1"
        XCTAssertNil(AppBundleMetadata(version: oversizedWhitespace).version)
        let oversized = String(repeating: "x", count: 1025)
        XCTAssertEqual(AppBundleMetadata(declaredCategoryIdentifier: oversized, version: "2", build: "20"),
                       .init(version: "2", build: "20"))
    }

    func testCatalogBuilderRetainsMetadataAndCallerRevision() throws {
        let source = record(metadata: .init(declaredCategoryIdentifier: "public.app-category.business",
                                            version: "2.1", build: "300"))
        let snapshot = try CatalogBuilder.build(rawRecords: [source], policy: .init(), revision: .init(7))
        XCTAssertEqual(snapshot.records, [source])
        XCTAssertEqual(snapshot.revision, .init(7))
    }
}
