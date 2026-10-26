import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppearancePreferencesTests: XCTestCase {
    private final class Store: AppearancePreferencesPersisting {
        var result: AppearancePreferencesSaveResult = .saved
        var loaded: AppearancePreferencesLoadResult = .loaded(.default)
        var saves = 0
        func load() -> AppearancePreferencesLoadResult { loaded }
        func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult {
            saves += 1
            if result == .saved { loaded = .loaded(preferences) }
            return result
        }
    }

    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "fixture.appearance.\(UUID().uuidString)"))
    }

    /// Observe writes while retaining the real payload decoding and future-version guard.
    private final class RealStoreProbe: AppearancePreferencesPersisting {
        let store: UserDefaultsAppearancePreferencesStore
        var saves = 0
        var saveFailure: AppearancePreferencesSaveResult?
        var beforeSave: (() -> Void)?

        init(defaults: UserDefaults) {
            store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        }

        func load() -> AppearancePreferencesLoadResult { store.load() }

        func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult {
            saves += 1
            beforeSave?()
            if let saveFailure { return saveFailure }
            return store.save(preferences)
        }
    }

    private func nativeAppearanceView(coordinator: AppearanceSettingsCoordinator)
        -> (AppearanceSettingsView, LiveAppearanceSettingsCoordinator) {
        let view = AppearanceSettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        // Tests drive interaction-end flushing explicitly; no wall-clock debounce.
        let live = LiveAppearanceSettingsCoordinator(persistence: coordinator, schedule: { _ in {} })
        live.onChange = { [weak view, weak live] in
            guard let live else { return }
            view?.updateLiveStatus(live.state, presentation: .applied)
        }
        coordinator.onAcknowledged = { [weak live] value in
            guard let live, !live.isFlushing else { return }
            live.acceptPersistenceCommand(value)
        }
        view.onChange = { live.submit($0) }
        view.onApply = { live.retry($0) }
        view.onFlush = { _ = live.flush() }
        view.onDiscardDraft = view.onFlush
        view.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        return (view, live)
    }

    func testCleanDefaultsUseMatchingIndependentMainAndFolderSizes() {
        XCTAssertEqual(AppearancePreferences.default, .init(showsAppLabels: true, wallpaperBlurRadius: 18))
        XCTAssertEqual(AppearancePreferences.default.preferredIconSide, 80)
        XCTAssertEqual(AppearancePreferences.default.mainPreferredIconSide, 80)
        XCTAssertEqual(AppearancePreferences.default.itemAppearance.preferredIconSide, 80)
        XCTAssertEqual(AppearancePreferences.default.mainItemAppearance.preferredIconSide, 80)
        XCTAssertEqual(LaunchcopyVisualTokens.wallpaperBlurRadius, 18)
        XCTAssertTrue(AppearancePreferences(wallpaperBlurRadius: 0).isValid)
        XCTAssertTrue(AppearancePreferences(wallpaperBlurRadius: 60).isValid)
        XCTAssertFalse(AppearancePreferences(wallpaperBlurRadius: -1).isValid)
        XCTAssertFalse(AppearancePreferences(wallpaperBlurRadius: 61).isValid)
    }

    func testDedicatedPayloadRoundTripsAndPreservesOtherKeys() throws {
        let defaults = try defaults()
        defaults.set("untouched", forKey: "foreign.key")
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .loaded(.default))
        let preferences = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42)
        XCTAssertEqual(store.save(preferences), .saved)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(preferences))
        XCTAssertEqual(defaults.string(forKey: "foreign.key"), "untouched")
    }

    func testMainOverrideValidationRemainsIndependentOfLegacyBaseRange() {
        for side in 32...96 {
            let preferences = AppearancePreferences(preferredIconSide: 54, appLabelFontSize: 12,
                                                    mainPreferredIconSide: side)
            XCTAssertTrue(preferences.isValid)
            XCTAssertEqual(preferences.itemAppearance.preferredIconSide, 54)
            XCTAssertEqual(preferences.mainItemAppearance.preferredIconSide, side)
            XCTAssertEqual(preferences.mainItemAppearance.appLabelFontSize, 12)
        }
        for side in [Int.min, 31, 97, Int.max] {
            XCTAssertFalse(AppearancePreferences(mainPreferredIconSide: side).isValid)
        }
        for side in [Int.min, 31, 97, Int.max] {
            XCTAssertFalse(AppearancePreferences(preferredIconSide: side, mainPreferredIconSide: 80).isValid)
        }
        let inherited = AppearancePreferences(preferredIconSide: 54, mainPreferredIconSide: nil)
        XCTAssertTrue(inherited.isValid)
        XCTAssertNil(inherited.mainPreferredIconSide)
        XCTAssertEqual(inherited.mainItemAppearance, inherited.itemAppearance)
    }

    func testCleanLoadDoesNotPersistDefaultMainOverride() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .loaded(.default))
        XCTAssertEqual(store.load().preferences.mainPreferredIconSide, 80)
        XCTAssertNil(defaults.object(forKey: UserDefaultsAppearancePreferencesStore.payloadKey))
    }

    func testSchemaOneInheritsOldFortyEightPointDefaultWithoutWriting() throws {
        let defaults = try defaults()
        let bytes = Data(#"{"schemaVersion":1,"preferences":{"showsAppLabels":false,"wallpaperBlurRadius":42}}"#.utf8)
        defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        let legacy = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42,
                                           preferredIconSide: 48,
                                           mainPreferredIconSide: nil)
        XCTAssertEqual(store.load(), .loaded(legacy))
        XCTAssertEqual(store.load().preferences.mainItemAppearance.preferredIconSide, 48)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
    }

    func testSchemaTwoPreservesSavedPointMeaningAndNilOverrideWithoutWriting() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        for side in [32, 48, 54, 64] {
            let bytes = Data("{\"schemaVersion\":2,\"preferences\":{\"showsAppLabels\":true,\"wallpaperBlurRadius\":18,\"preferredIconSide\":\(side),\"appLabelFontSize\":12}}".utf8)
            defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
            let expected = AppearancePreferences(preferredIconSide: side, appLabelFontSize: 12,
                                                 mainPreferredIconSide: nil)
            XCTAssertEqual(store.load(), .loaded(expected))
            XCTAssertEqual(store.load().preferences.mainItemAppearance.preferredIconSide, side)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }

    func testExpandedDomainDoesNotAdmitInvalidSchemaTwoBaseOrMalformedFields() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        for fields in [
            #""preferredIconSide":65,"appLabelFontSize":11"#,
            #""preferredIconSide":96,"appLabelFontSize":11"#,
            #""preferredIconSide":48"#,
            #""preferredIconSide":48.5,"appLabelFontSize":11"#,
            #""preferredIconSide":48,"appLabelFontSize":null"#
        ] {
            let bytes = Data((#"{"schemaVersion":2,"preferences":{"showsAppLabels":true,"wallpaperBlurRadius":18,"# + fields + "}}").utf8)
            defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
            XCTAssertEqual(store.load(), .corrupt)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }

    func testSchemaFourRoundTripsExplicitAndInheritedMainSizes() throws {
        let defaults = try defaults()
        defaults.set("untouched", forKey: "foreign.key")
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        for override in [nil, 32, 80, 96] as [Int?] {
            let preferences = AppearancePreferences(preferredIconSide: 54, appLabelFontSize: 12,
                                                    mainPreferredIconSide: override)
            XCTAssertEqual(store.save(preferences), .saved)
            let bytes = try XCTUnwrap(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            XCTAssertEqual(object["schemaVersion"] as? Int, 4)
            XCTAssertEqual(store.load(), .loaded(preferences))
            XCTAssertEqual(store.load().preferences.mainPreferredIconSide, override)
            XCTAssertEqual(defaults.string(forKey: "foreign.key"), "untouched")
            XCTAssertEqual(store.save(.init(preferredIconSide: 97)), .invalidPreferences)
            XCTAssertEqual(store.save(.init(mainPreferredIconSide: 97)), .invalidPreferences)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }

    func testSchemaThreeRejectsInvalidOverrideWithoutRepairingPayload() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        for value in ["31", "97", "80.5", "\"80\"", "true"] {
            let bytes = Data("{\"schemaVersion\":3,\"preferences\":{\"showsAppLabels\":true,\"wallpaperBlurRadius\":18,\"preferredIconSide\":48,\"appLabelFontSize\":11,\"mainPreferredIconSide\":\(value)}}".utf8)
            defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
            XCTAssertEqual(store.load(), .corrupt)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
        }
    }

    func testUnrelatedExplicitEditsPreserveOverrideOrInheritanceWhenSavedAsSchemaFour() throws {
        let store = UserDefaultsAppearancePreferencesStore(defaults: try defaults())
        for override in [nil, 96] as [Int?] {
            var edited = AppearancePreferences(preferredIconSide: 54, mainPreferredIconSide: override)
            edited.showsAppLabels = false
            edited.wallpaperBlurRadius = 42
            edited.appLabelFontSize = 12
            XCTAssertEqual(store.save(edited), .saved)
            XCTAssertEqual(store.load(), .loaded(edited))
            XCTAssertEqual(store.load().preferences.mainPreferredIconSide, override)
            XCTAssertEqual(store.load().preferences.mainItemAppearance.preferredIconSide, override ?? 54)
        }
    }

    func testImmediateFutureSchemaProtectsUnknownBodyBeforeDecodingOrSaving() throws {
        let defaults = try defaults()
        let bytes = Data(#"{"schemaVersion":5,"preferences":"unknown body"}"#.utf8)
        defaults.set(bytes, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .futureVersion(5))
        XCTAssertEqual(store.save(.default), .futureVersion(5))
        XCTAssertEqual(store.save(.init(preferredIconSide: 65)), .futureVersion(5))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), bytes)
    }

    func testCorruptPayloadFallsBackWithoutWritingUntilExplicitSave() throws {
        let defaults = try defaults()
        let malformed = Data("not JSON".utf8)
        defaults.set(malformed, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .corrupt)
        XCTAssertEqual(store.load().preferences, .default)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), malformed)
        XCTAssertEqual(store.save(.default), .saved)
        XCTAssertEqual(store.load(), .loaded(.default))
    }

    func testFutureSchemaIsPreservedEvenWithUnknownPayloadShape() throws {
        let defaults = try defaults()
        let future = Data(#"{"schemaVersion":9,"newerField":[1,2,3]}"#.utf8)
        defaults.set(future, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        let store = UserDefaultsAppearancePreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .futureVersion(9))
        XCTAssertEqual(store.save(.default), .futureVersion(9))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), future)
    }

    func testInvalidPreferencesDoNotReplaceStoredState() throws {
        let store = UserDefaultsAppearancePreferencesStore(defaults: try defaults())
        XCTAssertEqual(store.save(.init(wallpaperBlurRadius: 61)), .invalidPreferences)
        XCTAssertEqual(store.load(), .loaded(.default))
    }

    func testCoordinatorPersistsBeforeApplyingAndSkipsEqualApply() {
        let store = Store()
        var applied: [AppearancePreferences] = []
        let coordinator = AppearanceSettingsCoordinator(store: store) { value in
            XCTAssertEqual(store.loaded, .loaded(value))
            applied.append(value)
        }
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(store.saves, 0)
        XCTAssertEqual(coordinator.apply(.init(showsAppLabels: false)), .saved)
        XCTAssertEqual(store.saves, 1)
        XCTAssertEqual(applied.count, 1)
        XCTAssertEqual(coordinator.apply(.init(showsAppLabels: false)), .saved)
        XCTAssertEqual(store.saves, 1)
        XCTAssertEqual(applied.count, 1)
    }

    func testFailedSaveDoesNotChangeCommittedOrUI() {
        let store = Store()
        store.result = .encodingFailed
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in XCTFail("Failed persistence must not apply") }
        XCTAssertEqual(coordinator.apply(.init(showsAppLabels: false)), .encodingFailed)
        XCTAssertEqual(coordinator.committed, .default)
    }

    func testFutureSchemaRejectsEqualAndChangedDrafts() {
        let store = Store()
        store.loaded = .futureVersion(5)
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in XCTFail("Read-only schema") }
        XCTAssertEqual(coordinator.apply(.default), .futureVersion(5))
        XCTAssertEqual(coordinator.apply(.init(showsAppLabels: false)), .futureVersion(5))
        XCTAssertEqual(store.saves, 0)
    }

    func testExplicitCorruptRepairWritesOnlyOnce() {
        let store = Store()
        store.loaded = .corrupt
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in XCTFail("Equal defaults need no UI work") }
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(coordinator.loadResult, .loaded(.default))
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(store.saves, 1)
    }

    func testExplicitRecoveryRepairsCorruptionIntroducedAfterInitialization() throws {
        let defaults = try defaults()
        let store = RealStoreProbe(defaults: defaults)
        let preferences = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42)
        XCTAssertEqual(store.store.save(preferences), .saved)
        var applications = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applications += 1 }
        let (view, _) = nativeAppearanceView(coordinator: coordinator)
        let malformed = Data("not JSON".utf8)
        defaults.set(malformed, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)

        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .corrupt)
        view.reload(preferences: coordinator.committed, loadResult: store.load())
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), malformed)
        XCTAssertEqual(store.saves, 0, "Loading and reopening must not repair persistence")
        XCTAssertFalse(view.applyButton.isHidden, "Fresh corruption inspection exposes explicit recovery")
        view.applyButton.performClick(nil)

        XCTAssertEqual(store.saves, 1)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(view.draft))
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(coordinator.loadResult, .loaded(preferences))
        XCTAssertEqual(view.statusLabel.textColor, .systemGreen)
        XCTAssertFalse(view.statusLabel.isHidden)
        XCTAssertEqual(applications, 0, "Persistence repair must not reapply unchanged effective values")
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertEqual(coordinator.apply(view.draft), .saved)
        XCTAssertEqual(store.saves, 1, "A repaired matching payload must become a no-op")
        XCTAssertEqual(applications, 0)
    }

    func testExplicitCommandRestoresRemovedNondefaultPayload() throws {
        let defaults = try defaults()
        let store = RealStoreProbe(defaults: defaults)
        let preferences = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42)
        XCTAssertEqual(store.store.save(preferences), .saved)
        var applications = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applications += 1 }
        let (view, live) = nativeAppearanceView(coordinator: coordinator)
        defaults.removeObject(forKey: UserDefaultsAppearancePreferencesStore.payloadKey)

        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(.default))
        view.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        XCTAssertNil(defaults.object(forKey: UserDefaultsAppearancePreferencesStore.payloadKey))
        XCTAssertEqual(store.saves, 0)
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertEqual(live.retry(view.draft), .saved)

        XCTAssertEqual(store.saves, 1)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(view.draft))
        let freshCoordinator = AppearanceSettingsCoordinator(
            store: UserDefaultsAppearancePreferencesStore(defaults: defaults)
        ) { _ in XCTFail("Reload must not apply runtime preferences") }
        XCTAssertEqual(freshCoordinator.committed, preferences)
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(view.statusLabel.textColor, .systemGreen)
        XCTAssertEqual(applications, 0)
    }

    func testExplicitCommandReplacesDifferentHealthyPayloadIntroducedAfterInitialization() throws {
        let defaults = try defaults()
        let store = RealStoreProbe(defaults: defaults)
        let preferences = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42)
        XCTAssertEqual(store.store.save(preferences), .saved)
        var applications = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applications += 1 }
        let (view, live) = nativeAppearanceView(coordinator: coordinator)
        let externalPreferences = AppearancePreferences(showsAppLabels: true, wallpaperBlurRadius: 7)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).save(externalPreferences), .saved)

        view.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(externalPreferences))
        XCTAssertEqual(store.saves, 0)
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertEqual(live.retry(view.draft), .saved)

        XCTAssertEqual(store.saves, 1, "A healthy payload must represent the draft before an equal Apply can skip saving")
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(view.draft))
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(view.statusLabel.textColor, .systemGreen)
        XCTAssertEqual(applications, 0)
    }

    func testExplicitCommandPreservesLateFuturePayloadIncludingSaveRecheck() throws {
        let defaults = try defaults()
        let store = RealStoreProbe(defaults: defaults)
        let preferences = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42)
        XCTAssertEqual(store.store.save(preferences), .saved)
        var applications = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applications += 1 }
        let (view, live) = nativeAppearanceView(coordinator: coordinator)
        let future = Data(#"{ "schemaVersion": 9, "newerField": [1, 2, 3] }"#.utf8)
        defaults.set(future, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        XCTAssertEqual(live.retry(view.draft), .futureVersion(9))

        XCTAssertEqual(store.saves, 0)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), future)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .futureVersion(9))
        XCTAssertEqual(view.statusLabel.textColor, .systemRed)
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(applications, 0)

        // A future payload arriving after the coordinator's load must still be refused by save.
        defaults.set(Data("not JSON".utf8), forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        store.beforeSave = {
            defaults.set(future, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        }
        XCTAssertEqual(live.retry(view.draft), .futureVersion(9))
        XCTAssertEqual(store.saves, 1)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), future)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .futureVersion(9))
        XCTAssertEqual(view.statusLabel.textColor, .systemRed)
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(applications, 0)
    }

    func testNativeFailedRepairPreservesCommittedDraftAndSuppressesRuntimeApplication() throws {
        let defaults = try defaults()
        let store = RealStoreProbe(defaults: defaults)
        let preferences = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 42)
        XCTAssertEqual(store.store.save(preferences), .saved)
        var applications = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applications += 1 }
        let (view, _) = nativeAppearanceView(coordinator: coordinator)
        let malformed = Data("not JSON".utf8)
        defaults.set(malformed, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        store.saveFailure = .encodingFailed
        view.reload(preferences: coordinator.committed, loadResult: store.load())
        view.applyButton.performClick(nil)

        XCTAssertEqual(store.saves, 1, "An equal draft must attempt explicit repair and surface its failure")
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), malformed)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .corrupt)
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(view.draft, preferences)
        XCTAssertEqual(view.statusLabel.textColor, .systemRed)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.liveAppearanceText(.recoveryFailed))
        XCTAssertEqual(applications, 0)

        view.labelsCheckbox.performClick(nil)
        view.applyButton.performClick(nil)
        XCTAssertEqual(store.saves, 2)
        XCTAssertEqual(coordinator.committed, preferences)
        XCTAssertEqual(view.draft, .init(showsAppLabels: true, wallpaperBlurRadius: 42))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), malformed)
        XCTAssertEqual(view.statusLabel.textColor, .systemRed)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.liveAppearanceText(.recoveryFailed))
        XCTAssertEqual(applications, 0, "A changed draft must also remain staged when persistence fails")
    }

    func testExplicitCommandLeavesHealthyMatchingSchemaOneBytesUntouched() throws {
        let defaults = try defaults()
        let payload = Data(#"{ "preferences": { "wallpaperBlurRadius": 42, "showsAppLabels": false }, "schemaVersion": 1 }"#.utf8)
        defaults.set(payload, forKey: UserDefaultsAppearancePreferencesStore.payloadKey)
        defaults.set("untouched", forKey: "foreign.key")
        let store = RealStoreProbe(defaults: defaults)
        var applications = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applications += 1 }
        let (view, _) = nativeAppearanceView(coordinator: coordinator)
        XCTAssertEqual(coordinator.committed, .init(showsAppLabels: false, wallpaperBlurRadius: 42,
                                                  preferredIconSide: 48,
                                                  mainPreferredIconSide: nil))
        XCTAssertEqual(coordinator.apply(view.draft), .saved)
        XCTAssertEqual(coordinator.apply(view.draft), .saved)

        XCTAssertEqual(store.saves, 0, "Healthy matching values must not rewrite even differently formatted schema 1 bytes")
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppearancePreferencesStore.payloadKey), payload)
        XCTAssertEqual(UserDefaultsAppearancePreferencesStore(defaults: defaults).load(), .loaded(view.draft))
        XCTAssertEqual(defaults.string(forKey: "foreign.key"), "untouched")
        XCTAssertEqual(view.statusLabel.textColor, .systemGreen)
        XCTAssertEqual(applications, 0)
    }

    func testLiveControlsAutosaveOnFlushAndDefaultsPersistWithoutApplyOrCloseDiscard() {
        let store = Store()
        var applyCount = 0
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in applyCount += 1 }
        let (view, live) = nativeAppearanceView(coordinator: coordinator)
        var previews: [AppearancePreferences] = []
        live.onPreview = { previews.append($0) }
        view.labelsCheckbox.state = .off
        view.blurSlider.doubleValue = 32
        view.controlChanged(nil)
        XCTAssertEqual(view.draft, .init(showsAppLabels: false, wallpaperBlurRadius: 32))
        XCTAssertEqual(live.requested, view.draft)
        XCTAssertEqual(previews, [view.draft], "Preview precedes the persistence flush")
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertEqual(store.saves, 0)
        view.onFlush?()
        XCTAssertEqual(coordinator.committed, view.draft)
        XCTAssertEqual(store.saves, 1)
        XCTAssertEqual(applyCount, 1)
        view.defaultsButton.performClick(nil)
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(store.saves, 2, "Defaults submit immediately and flush without Apply")
        XCTAssertEqual(coordinator.committed, .default)
        view.blurSlider.integerValue = 41
        view.controlChanged(nil)
        XCTAssertEqual(store.saves, 2)
        view.onDiscardDraft?()
        XCTAssertEqual(store.saves, 3, "Dismissal flushes the latest accepted edit")
        view.reload(preferences: live.requested, loadResult: coordinator.loadResult)
        XCTAssertEqual(view.draft, .init(wallpaperBlurRadius: 41))
        XCTAssertEqual(view.draft, coordinator.committed, "Reopen retains the autosaved edit")
    }

    func testFutureVersionDisablesAppearanceControlsOnly() {
        let view = AppearanceSettingsView(frame: .zero)
        view.reload(preferences: .default, loadResult: .futureVersion(5))
        XCTAssertFalse(view.labelsCheckbox.isEnabled)
        XCTAssertFalse(view.blurSlider.isEnabled)
        XCTAssertFalse(view.applyButton.isEnabled)
        XCTAssertFalse(view.defaultsButton.isEnabled)
        view.reload(preferences: .default, loadResult: .loaded(.default))
        XCTAssertTrue(view.applyButton.isEnabled)
    }

    func testWorkspaceDisplayObserverDeliversAndCanBeRemovedFromItsCenter() {
        let center = NotificationCenter()
        var events = 0
        let token = AppDelegate.observeAccessibilityDisplayChanges(center: center) { events += 1 }
        center.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        XCTAssertEqual(events, 1)
        center.removeObserver(token)
        center.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        XCTAssertEqual(events, 1)
    }

    func testDisplayNotificationReappliesPolicyAndRejectsPendingWallpaper() throws {
        let owner = AppDelegate(options: .default)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        owner.window = NSWindow(contentRect: host.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        owner.window?.isReleasedWhenClosed = false
        var completion: (@MainActor (CGImage?) -> Void)?
        let backdrop = WallpaperBackdropController(imageLoader: { _, _, callback in completion = callback },
                                                   sourceResolver: { _ in URL(fileURLWithPath: "/synthetic") })
        backdrop.attach(to: host)
        owner.wallpaperBackdrop = backdrop
        backdrop.refresh(for: nil, policy: .init(reduceTransparency: false, increaseContrast: false, reduceMotion: false))
        let center = NotificationCenter()
        let token = AppDelegate.observeAccessibilityDisplayChanges(center: center) {
            owner.handleAccessibilityDisplayChange(wallpaperPolicy:
                .init(reduceTransparency: true, increaseContrast: false, reduceMotion: false))
        }
        defer { center.removeObserver(token) }
        center.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        let context = try XCTUnwrap(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
                                             bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        try XCTUnwrap(completion)(XCTUnwrap(context.makeImage()))
        let imageView = try XCTUnwrap(host.subviews.first { $0 is NSImageView } as? NSImageView)
        XCTAssertNil(imageView.image, "Late wallpaper must not undo the display notification policy")
    }

    func testSettingsUsesOneWindowWithBothSectionsWithoutShowingIt() throws {
        let controller = ActivationSettingsWindowController(draft: .init(committed: ActivationPreferences()))
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        XCTAssertEqual(tabs.numberOfTabViewItems, 6)
        XCTAssertFalse(tabs.tabViewItems.contains { $0.identifier as? String == "grid" })
        XCTAssertTrue(controller.appearanceView.mainGridSection === controller.mainGridCapacityView)
        XCTAssertTrue(controller.mainGridCapacityView.isDescendant(of: controller.appearanceView))
        XCTAssertTrue(tabs.tabViewItem(at: 5).view === controller.appLibrarySettingsView)
        XCTAssertTrue(tabs.tabViewItem(at: 4).view === controller.languageView)
        XCTAssertTrue(tabs.tabViewItem(at: 3).view === controller.appSourcesView)
        XCTAssertTrue(tabs.tabViewItem(at: 1).view === controller.appearanceView)
        XCTAssertFalse(controller.window?.isVisible == true)
    }

    func testLeavingActivationTabStopsShortcutRecording() throws {
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.globalShortcutEnabled = true
        let controller = ActivationSettingsWindowController(draft: draft)
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        func findRecordButton(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.action.map(NSStringFromSelector) == "shortcutRecordClicked:" {
                return button
            }
            for child in view.subviews {
                if let button = findRecordButton(child) { return button }
            }
            return nil
        }
        let button = try XCTUnwrap(findRecordButton(try XCTUnwrap(tabs.tabViewItem(at: 0).view)))
        button.performClick(nil)
        XCTAssertTrue(controller.isRecordingShortcut)
        let original = controller.draft.shortcut
        tabs.selectTabViewItem(at: 1)
        XCTAssertFalse(controller.isRecordingShortcut)
        XCTAssertEqual(button.title, LocalizedStrings(language: .simplifiedChinese).activationText(.shortcutRecord))
        XCTAssertEqual(controller.draft.shortcut, original)
        tabs.selectTabViewItem(at: 0)
        XCTAssertFalse(controller.isRecordingShortcut, "Returning must not restart recording")
    }

    func testAppearanceTabScrollsToUsableUnclippedControlsAndActionableFooter() throws {
        let controller = ActivationSettingsWindowController(draft: .init(committed: ActivationPreferences()))
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        tabs.selectTabViewItem(at: 1)
        tabs.layoutSubtreeIfNeeded()
        let view = controller.appearanceView
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.bounds.width, 300)
        XCTAssertGreaterThan(view.bounds.height, 300)
        let scroll = try XCTUnwrap(view.subviews.compactMap { $0 as? NSScrollView }.first)
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertTrue(scroll.hasVerticalScroller)
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertFalse(view.defaultsButton.isHidden)
        XCTAssertTrue(view.defaultsButton.isEnabled)
        for control in [view.labelsCheckbox, view.blurSlider, view.iconSlider, view.fontSlider,
                        controller.mainGridCapacityView.columnsPopup,
                        controller.mainGridCapacityView.rowsPopup, view.defaultsButton] as [NSView] {
            XCTAssertGreaterThan(control.bounds.width, 0)
            XCTAssertGreaterThan(control.bounds.height, 0)
            let rect = control.convert(control.bounds, to: document)
            XCTAssertTrue(document.bounds.contains(rect), "Controls must fit within the scrollable document")
            document.scrollToVisible(rect)
            scroll.layoutSubtreeIfNeeded()
            XCTAssertTrue(scroll.contentView.documentVisibleRect.contains(rect),
                          "Each actionable control must be reachable in the viewport")
        }
        XCTAssertFalse(view.hasAmbiguousLayout)
    }

    func testLabelOnlyApplicationDoesNotRequestWallpaperAndEqualApplyIsNoOp() {
        let owner = AppDelegate(options: .default)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        owner.window = NSWindow(contentRect: host.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        owner.window?.isReleasedWhenClosed = false
        var requests = 0
        let backdrop = WallpaperBackdropController(imageLoader: { request, _, _ in
            requests += 1
            XCTAssertEqual(request.blurRadius, 30)
        }, sourceResolver: { _ in URL(fileURLWithPath: "/synthetic") })
        backdrop.attach(to: host)
        owner.wallpaperBackdrop = backdrop
        owner.applyAppearancePreferences(.init(showsAppLabels: false))
        XCTAssertEqual(requests, 0)
        owner.applyAppearancePreferences(.init(showsAppLabels: false, wallpaperBlurRadius: 30))
        XCTAssertEqual(requests, 1)
        owner.applyAppearancePreferences(.init(showsAppLabels: false, wallpaperBlurRadius: 30))
        owner.applyAppearancePreferences(.init(showsAppLabels: true, wallpaperBlurRadius: 30))
        XCTAssertEqual(requests, 1)
    }
}
