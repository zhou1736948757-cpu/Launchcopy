import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

final class BundleMetadataForwardingTests: XCTestCase {
    func testAliasPresentationAndVisibleProjectionRetainEveryCanonicalField() throws {
        let id = AppID.bundleIdentifier("fixture.library.forwarding")
        let record = AppRecord(id: id, displayName: "Original", bundleIdentifier: "fixture.library.forwarding",
                               canonicalURL: URL(fileURLWithPath: "/SyntheticApps/Original.app"),
                               iconIdentity: .from(appID: id), sourceRootPriority: 2,
                               bundleMetadata: .init(declaredCategoryIdentifier: "public.app-category.utilities",
                                                     version: "4", build: "400"))
        let management = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: record))
        let presentation = management.presentationRecord(for: record)
        XCTAssertEqual(presentation.displayName, "Alias")
        XCTAssertEqual(presentation.bundleMetadata, record.bundleMetadata)
        XCTAssertEqual(presentation.id, record.id)
        XCTAssertEqual(presentation.canonicalURL, record.canonicalURL)
        XCTAssertEqual(presentation.iconIdentity, record.iconIdentity)
        XCTAssertEqual(presentation.bundleIdentifier, record.bundleIdentifier)
        XCTAssertEqual(presentation.sourceRootPriority, record.sourceRootPriority)
        XCTAssertEqual(management.visibleRecords([record]), [presentation])
        XCTAssertEqual(AppManagementPreferences.default.presentationRecord(for: record), record)
        XCTAssertEqual(record.displayName, "Original")
    }
}
