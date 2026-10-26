import AppKit
import AppGridUI
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class IconTypographyPreferencesTests: XCTestCase {
    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "fixture.icon-type.\(UUID().uuidString)"))
    }
    func testDefaultRangesAndInvalidIntegralValues() {
        XCTAssertEqual(AppearancePreferences.default.preferredIconSide, 80)
        XCTAssertEqual(AppearancePreferences.default.mainPreferredIconSide, 80)
        XCTAssertEqual(AppearancePreferences.default.appLabelFontSize, 11)
        for side in [32, 48, 64, 80, 96] {
            for font in [9, 11, 16] {
                XCTAssertTrue(AppearancePreferences(preferredIconSide: side, appLabelFontSize: font).isValid)
            }
        }
        for side in [Int.min, 31, 97, Int.max] {
            XCTAssertFalse(AppearancePreferences(preferredIconSide: side).isValid)
        }
        for side in [32, 80, 96] {
            let preferences = AppearancePreferences(mainPreferredIconSide: side)
            XCTAssertTrue(preferences.isValid)
            XCTAssertEqual(preferences.mainItemAppearance.preferredIconSide, side)
            XCTAssertEqual(preferences.itemAppearance.preferredIconSide, 80)
        }
        for side in [Int.min, 31, 97, Int.max] {
            XCTAssertFalse(AppearancePreferences(mainPreferredIconSide: side).isValid)
        }
        for font in [Int.min, 8, 17, Int.max] {
            XCTAssertFalse(AppearancePreferences(appLabelFontSize: font).isValid)
        }
    }
    func testLegacySchemaDefaultsNewFieldsWithoutRewritingBytes() throws {
        let defaults = try defaults()
        let legacy = Data(#"{"schemaVersion":1,"preferences":{"showsAppLabels":false,"wallpaperBlurRadius":42}}"#.utf8)
        defaults.set(legacy, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .loaded(.init(showsAppLabels: false, wallpaperBlurRadius: 42, preferredIconSide: 48, mainPreferredIconSide: nil)))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), legacy)
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in XCTFail("No startup mutation") }
        XCTAssertEqual(coordinator.apply(coordinator.committed), .saved)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), legacy)
    }
    func testSchemaTwoInheritsExplicitBaseSizesWithoutRewritingBytes() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        for side in [48, 54, 64] {
            let bytes = Data(("{\"schemaVersion\":2,\"preferences\":{\"showsAppLabels\":true,\"wallpaperBlurRadius\":18,\"preferredIconSide\":\(side),\"appLabelFontSize\":11}}").utf8)
            defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
            let expected = AppearancePreferences(preferredIconSide: side, mainPreferredIconSide: nil)
            XCTAssertEqual(store.load(), .loaded(expected))
            XCTAssertEqual(expected.mainItemAppearance.preferredIconSide, side)
            XCTAssertEqual(expected.itemAppearance.preferredIconSide, side)
            let coordinator = AppearanceSettingsCoordinator(store: store) { _ in XCTFail("No legacy startup mutation") }
            XCTAssertEqual(coordinator.apply(coordinator.committed), .saved)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }
    func testSchemaFourRoundTripAndInvalidSaveProtectPriorBytes() throws {
        let defaults = try defaults()
        defaults.set("other", forKey: "foreign")
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        let draft = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 7,
                                          preferredIconSide: 64, appLabelFontSize: 16, mainPreferredIconSide: 96)
        XCTAssertEqual(store.save(draft), .saved)
        let data = try XCTUnwrap(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 4)
        let preferences = try XCTUnwrap(object["preferences"] as? [String: Any])
        XCTAssertEqual(preferences["preferredIconSide"] as? Int, 64)
        XCTAssertEqual(preferences["mainPreferredIconSide"] as? Int, 96)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(draft))
        XCTAssertEqual(store.save(.init(preferredIconSide: 97)), .invalidPreferences)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), data)
        XCTAssertEqual(defaults.string(forKey: "foreign"), "other")
    }
    func testSchemaTwoMissingWrongTypeFractionalAndOutOfRangeAreCorruptWithoutWrites() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        let variants = [
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18}"#,
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18,"preferredIconSide":64}"#,
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18,"preferredIconSide":64,"appLabelFontSize":null}"#,
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18,"preferredIconSide":"48","appLabelFontSize":11}"#,
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18,"preferredIconSide":48.5,"appLabelFontSize":11}"#,
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18,"preferredIconSide":65,"appLabelFontSize":11}"#,
            #"{"showsAppLabels":true,"wallpaperBlurRadius":18,"preferredIconSide":48,"appLabelFontSize":17}"#
        ]
        for preferences in variants {
            let bytes = Data(("{\"schemaVersion\":2,\"preferences\":" + preferences + "}").utf8)
            defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
            XCTAssertEqual(store.load(), .corrupt)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }
    func testFutureVersionProtectsOpaqueBytesAndDisablesNewControls() throws {
        let defaults = try defaults()
        let bytes = Data(#"{"schemaVersion":5,"opaque":[1,2,3]}"#.utf8)
        defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        let view = AppearanceSettingsView(frame: .zero)
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in XCTFail("Future data") }
        view.onApply = { coordinator.apply($0) }
        view.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        XCTAssertFalse(view.mainIconSlider.isEnabled)
        XCTAssertFalse(view.iconSlider.isEnabled); XCTAssertFalse(view.fontSlider.isEnabled)
        XCTAssertFalse(view.applyButton.isEnabled); XCTAssertFalse(view.defaultsButton.isEnabled)
        XCTAssertEqual(store.load(), .futureVersion(5))
        XCTAssertEqual(coordinator.apply(.init(preferredIconSide: 64)), .futureVersion(5))
        XCTAssertEqual(store.save(.init(mainPreferredIconSide: 96)), .futureVersion(5))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
    }
    func testNativeLiveSliderActionsPreserveAllFieldsAndDefaultsPersistAutomatically() {
        let store = InMemoryAppearancePreferencesStore()
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in }
        let view = AppearanceSettingsView(frame: .zero)
        let live = LiveAppearanceSettingsCoordinator(persistence: coordinator)
        live.onChange = { [weak view] in view?.updateLiveStatus(live.state, presentation: .applied) }
        view.onChange = { live.submit($0) }
        view.onFlush = { live.flush() }
        view.onApply = { live.retry($0) }
        view.mainIconSlider.integerValue = 96
        _ = view.mainIconSlider.sendAction(view.mainIconSlider.action, to: view.mainIconSlider.target)
        view.iconSlider.integerValue = 64
        _ = view.iconSlider.sendAction(view.iconSlider.action, to: view.iconSlider.target)
        view.fontSlider.integerValue = 16
        _ = view.fontSlider.sendAction(view.fontSlider.action, to: view.fontSlider.target)
        view.labelsCheckbox.performClick(nil)
        view.blurSlider.integerValue = 42
        _ = view.blurSlider.sendAction(view.blurSlider.action, to: view.blurSlider.target)
        let draft = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42,
                                          preferredIconSide: 64, appLabelFontSize: 16, mainPreferredIconSide: 96)
        XCTAssertEqual(view.draft, draft)
        XCTAssertEqual(store.load(), .loaded(draft))
        XCTAssertTrue(view.applyButton.isHidden)
        view.defaultsButton.performClick(nil)
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(store.load(), .loaded(.default))
        view.reload(preferences: coordinator.committed)
        XCTAssertEqual(view.mainIconSlider.integerValue, 80)
        XCTAssertEqual(view.iconSlider.integerValue, 80); XCTAssertEqual(view.fontSlider.integerValue, 11)
        live.invalidate()
    }
    func testScrollableControlsAndDefaultsRemainReachable() throws {
        let view = AppearanceSettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 280))
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        let scroll = try XCTUnwrap(view.subviews.compactMap { $0 as? NSScrollView }.first)
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertTrue(scroll.hasVerticalScroller)
        XCTAssertGreaterThan(document.bounds.height, scroll.contentView.bounds.height)
        XCTAssertGreaterThan(document.bounds.width, 300)
        XCTAssertTrue(view.applyButton.isHidden)
        let last = view.fontSlider.convert(view.fontSlider.bounds, to: document)
        XCTAssertGreaterThan(last.width, 0); XCTAssertGreaterThan(last.height, 0)
        document.scrollToVisible(last)
        XCTAssertTrue(document.visibleRect.intersects(last))
        let defaultsFrame = view.defaultsButton.convert(view.defaultsButton.bounds, to: document)
        XCTAssertGreaterThan(defaultsFrame.width, 0)
        XCTAssertGreaterThan(defaultsFrame.height, 0)
        document.scrollToVisible(defaultsFrame)
        XCTAssertTrue(document.visibleRect.contains(defaultsFrame), "Scoped Defaults must be fully reachable by scrolling")
        XCTAssertEqual(view.mainIconSlider.accessibilityLabel(), "主页面图标首选尺寸")
        XCTAssertEqual(view.iconSlider.accessibilityLabel(), "基础及文件夹内图标首选尺寸")
        XCTAssertEqual(view.mainIconCaption.stringValue, "主页面图标首选尺寸（32–96 pt）")
        XCTAssertEqual(view.iconCaption.stringValue, "基础／文件夹内图标首选尺寸（32–96 pt）")
        XCTAssertEqual(view.fontSlider.accessibilityLabel(), "应用名称字号")
        XCTAssertFalse(view.hasAmbiguousLayout)
    }

    func testQueuedStatusRefreshPreservesLatestLiveIntentAndActualSaveState() {
        let view = AppearanceSettingsView(frame: .zero)
        var state = AppearancePresentationState.queued
        view.presentationStateProvider = { state }
        view.onChange = { _ in true }
        view.updateLiveStatus(.saved, presentation: state)
        XCTAssertTrue(view.statusLabel.stringValue.contains(view.strings.liveAppearanceText(.saved)))
        XCTAssertTrue(view.statusLabel.stringValue.contains(view.strings.liveAppearanceText(.queued)))
        state = .applied; view.refreshPresentationStatus()
        XCTAssertEqual(view.statusLabel.textColor, .systemGreen)
        view.fontSlider.integerValue = 16
        view.controlChanged(nil)
        state = .queued; view.refreshPresentationStatus()
        XCTAssertTrue(view.statusLabel.stringValue.contains(view.strings.liveAppearanceText(.saving)))
        XCTAssertTrue(view.statusLabel.stringValue.contains(view.strings.liveAppearanceText(.queued)))
        XCTAssertEqual(view.draft.appLabelFontSize, 16)
    }
}
