import AppKit
import AppGridUI
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class FolderAppearanceScaleTests: XCTestCase {
    func testFreshFolderAndMainDefaultsUseSameReadablePointSize() {
        let preferences = AppearancePreferences.default
        XCTAssertEqual(preferences.itemAppearance.preferredIconSide, 80)
        XCTAssertEqual(preferences.mainItemAppearance.preferredIconSide, 80)
        let view = AppearanceSettingsView(frame: CGRect(x: 0, y: 0, width: 500, height: 600))
        XCTAssertEqual(view.iconSlider.maxValue, 96)
        XCTAssertEqual(view.iconSlider.integerValue, 80)
    }

    func testExtendedFolderSliderRemainsLiveAndIndependent() {
        let view = AppearanceSettingsView(frame: CGRect(x: 0, y: 0, width: 500, height: 600))
        var writes: [AppearancePreferences] = []
        view.onChange = { writes.append($0); return true }
        for size in [96, 80, 64, 32] {
            view.iconSlider.integerValue = size
            XCTAssertTrue(view.iconSlider.sendAction(view.iconSlider.action, to: view.iconSlider.target))
            XCTAssertEqual(writes.last?.preferredIconSide, size)
            XCTAssertEqual(view.draft.mainPreferredIconSide, 80)
            XCTAssertTrue(view.applyButton.isHidden)
        }
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertTrue(view.iconCaption.stringValue.contains("32–96"))
            XCTAssertEqual(view.iconSlider.integerValue, 32)
        }
    }

    func testSchemaFourRoundTripsExtendedFolderSizesWithoutTouchingOtherKeys() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "fixture.folder.scale.\(UUID().uuidString)"))
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        defaults.set("retained", forKey: "foreign")
        for side in [32, 48, 64, 65, 80, 96] {
            let value = AppearancePreferences(preferredIconSide: side, mainPreferredIconSide: 80)
            XCTAssertTrue(value.isValid)
            XCTAssertEqual(store.save(value), .saved)
            XCTAssertEqual(store.load(), .loaded(value))
            let bytes = try XCTUnwrap(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            XCTAssertEqual(object["schemaVersion"] as? Int, 4)
            XCTAssertEqual(defaults.string(forKey: "foreign"), "retained")
        }
    }

    func testSchemaThreePreservesOldSizesAndRejectsOldOutOfRangeWithoutWrites() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "fixture.folder.legacy.\(UUID().uuidString)"))
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        for side in [32, 48, 64, 65, 80, 96] {
            let bytes = Data("{\"schemaVersion\":3,\"preferences\":{\"showsAppLabels\":true,\"wallpaperBlurRadius\":18,\"preferredIconSide\":\(side),\"appLabelFontSize\":11,\"mainPreferredIconSide\":80}}".utf8)
            defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
            let expected: AppearancePreferencesLoadResult = side <= 64
                ? .loaded(.init(preferredIconSide: side, mainPreferredIconSide: 80)) : .corrupt
            XCTAssertEqual(store.load(), expected)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }

    func testExtendedFolderGeometryFitsAtRealPreferredSizeOrReducesRows() {
        for side in [80, 96] {
            for font in [9, 11, 16] {
                for size in [CGSize(width: 1000, height: 700), CGSize(width: 700, height: 500),
                             CGSize(width: 520, height: 420)] {
                    let appearance = GridItemAppearance(preferredIconSide: side, appLabelFontSize: font)
                    let layout = FolderLayoutPolicy.resolve(usableBounds: CGRect(origin: .zero, size: size),
                                                          appearance: appearance)
                    XCTAssertTrue(layout.canPresentMembers)
                    XCTAssertLessThanOrEqual(layout.capacity, 15)
                    for cell in layout.cellFrames {
                        let bounds = CGRect(origin: .zero, size: cell.size)
                        let content = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                            showsLabels: true, isFolderCell: false, context: .folderGrid)
                        XCTAssertEqual(content.iconFrame.width, CGFloat(side), accuracy: 0.001)
                        XCTAssertTrue(bounds.contains(content.iconFrame))
                        XCTAssertTrue(bounds.contains(content.nameFrame))
                        XCTAssertGreaterThanOrEqual(content.iconFrame.minY - content.nameFrame.maxY, 6)
                    }
                }
            }
        }
    }
}
