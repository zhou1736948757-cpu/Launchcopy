import AppKit
import AppCatalogCore
import AppGridUI
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LibraryEntryProfileIntegrationTests: XCTestCase {
    func testBundleMarkerRequiresActualBooleanTrue() {
        XCTAssertTrue(LibraryEntryProfileSession.isEnabled(marker: true))
        for marker: Any? in [nil, false, 1, 0, "true", "1", NSNull()] {
            XCTAssertFalse(LibraryEntryProfileSession.isEnabled(marker: marker))
        }
    }

    func testControlsHaveNoRecorderByDefault() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: .init(language: .english))
        XCTAssertNil(view.entryProfile)
        XCTAssertNil(view.galleryView.entryProfile)
    }

    func testActualCardLayoutProducesSeparateTimingSampleWithoutReorderingLayout() throws {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: .init(language: .english))
        let recorder = LibraryEntryProfile()
        view.entryProfile = recorder
        let id = AppID.bundleIdentifier("fixture.profile.card")
        let record = AppRecord(id: id, displayName: "Card Fixture", bundleIdentifier: "fixture.profile.card",
            canonicalURL: URL(fileURLWithPath: "/SyntheticProfile/Fixture.app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
        view.apply(snapshot: .init(revision: .init(1), entries: [.init(record: record,
            displayName: "Card Fixture", category: .utilities)], counts: [.utilities: 1]),
            isLoading: false, catalogIsEmpty: false, actionGeneration: 1)
        view.layoutSubtreeIfNeeded()
        let card = try XCTUnwrap(view.galleryView.cards.first)
        card.layoutSubtreeIfNeeded()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: recorder.encodedSnapshot()) as? [String: Any])
        let samples = try XCTUnwrap(json["samples"] as? [[String: Any]])
        XCTAssertTrue(samples.contains { ($0["tag"] as? String) == "galleryLayout" })
        XCTAssertTrue(samples.contains { ($0["tag"] as? String) == "cardLayout" && ($0["count"] as? Int) == 1 })
        XCTAssertEqual(card.frame.width, view.galleryView.cards.first?.frame.width)
    }

    func testRecorderPropagatesToGalleryWithoutChangingSearchPolicy() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: .init(language: .english))
        let recorder = LibraryEntryProfile()
        view.entryProfile = recorder
        XCTAssertTrue(view.galleryView.entryProfile === recorder)
        XCTAssertEqual(view.searchField.focusRingType, .none)
        view.entryProfile = nil
        XCTAssertNil(view.galleryView.entryProfile)
    }
}
