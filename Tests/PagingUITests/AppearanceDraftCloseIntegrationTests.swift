import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
private final class AppearanceCloseStore: AppearancePreferencesPersisting {
    var preferences: AppearancePreferences
    var result = AppearancePreferencesSaveResult.saved
    var writes: [AppearancePreferences] = []
    var loads = 0
    init(_ preferences: AppearancePreferences = .default) { self.preferences = preferences }
    func load() -> AppearancePreferencesLoadResult { loads += 1; return .loaded(preferences) }
    func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult {
        writes.append(preferences)
        if result == .saved { self.preferences = preferences }
        return result
    }
}

/// Actual AppDelegate settings configuration and controller close/hide, unshown.
/// No production store, application launch, native activation or physical input.
@MainActor
final class AppearanceDraftCloseIntegrationTests: XCTestCase {
    private let changed = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 0,
                                               preferredIconSide: 64, appLabelFontSize: 16)
    @MainActor
    private final class Fixture {
        let app = AppDelegate(options: .default)
        let store: AppearanceCloseStore
        let controller: ActivationSettingsWindowController
        init(_ preferences: AppearancePreferences = .default) {
            _ = NSApplication.shared
            store = AppearanceCloseStore(preferences)
            controller = ActivationSettingsWindowController(draft: .init(committed: .init()))
            app.installAppearancePreferences(store: store)
            app.configureAppearanceSettings(controller.appearanceView)
        }
        func draft(_ preferences: AppearancePreferences) {
            let view = controller.appearanceView
            view.labelsCheckbox.state = preferences.showsAppLabels ? .on : .off
            view.blurSlider.integerValue = preferences.wallpaperBlurRadius
            view.iconSlider.integerValue = preferences.preferredIconSide
            view.fontSlider.integerValue = preferences.appLabelFontSize
            view.controlChanged(nil)
        }
        func teardown() {
            controller.hideSettings()
            app.surface?.teardown(); app.surface = nil
            controller.window?.delegate = nil
            controller.window?.contentView = nil
            controller.window?.close()
        }
    }

    // These cases explicitly supersede the old Apply/discard contract under the approved live spec.
    func testNativeCloseFlushesLatestLiveEditWithoutRollback() throws {
        let f = Fixture(); defer { f.teardown() }
        f.draft(changed)
        XCTAssertEqual(f.app.appearancePreferences, changed)
        XCTAssertTrue(f.store.writes.isEmpty, "Visual effect must not wait for persistence")
        XCTAssertFalse(f.controller.windowShouldClose(try XCTUnwrap(f.controller.window)))
        XCTAssertEqual(f.controller.appearanceView.draft, changed)
        XCTAssertEqual(f.store.preferences, changed)
        XCTAssertEqual(f.store.writes, [changed])
    }

    func testHideRetainsAutomaticallyRequestedDefaultsRatherThanOldCustomValues() {
        let f = Fixture(changed); defer { f.teardown() }
        f.controller.appearanceView.defaultsButton.performClick(nil)
        XCTAssertEqual(f.app.appearancePreferences, .default)
        f.controller.hideSettings()
        XCTAssertEqual(f.controller.appearanceView.draft, .default)
        XCTAssertEqual(f.store.preferences, .default)
        XCTAssertEqual(f.store.writes, [.default])
    }

    func testCloseFlushesLatestIntentionButDefersVisualChangeDuringGesture() {
        let f = Fixture(); defer { f.teardown() }
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        f.app.surface = surface
        gestureBegan(surface, at: 0)
        f.draft(changed)
        f.controller.hideSettings()
        XCTAssertEqual(f.store.preferences, changed)
        XCTAssertEqual(f.controller.appearanceView.draft, changed)
        XCTAssertEqual(f.app.appearancePreferences, .default)
        XCTAssertEqual(f.app.appearancePresentationState, .queued)
        surface.cancel()
        f.app.flushPendingAppearanceIfReady()
        XCTAssertEqual(f.app.appearancePreferences, changed)
    }

    func testFailedSaveThenClosePreservesIntentAndPreviewForRetry() {
        let f = Fixture(); defer { f.teardown() }
        f.store.result = .encodingFailed
        f.draft(changed)
        f.controller.hideSettings()
        XCTAssertEqual(f.controller.appearanceView.draft, changed)
        XCTAssertEqual(f.app.appearancePreferences, changed)
        XCTAssertEqual(f.store.preferences, .default)
        XCTAssertEqual(f.app.liveAppearanceCoordinator?.state, .failed)
        XCTAssertTrue(f.app.liveAppearanceCoordinator?.requiresQuitProtection == true)
        f.store.result = .saved
        f.controller.appearanceView.applyClicked(nil)
        XCTAssertEqual(f.store.preferences, changed)
        XCTAssertFalse(f.app.liveAppearanceCoordinator?.requiresQuitProtection == true)
    }

    func testAppearanceDismissalDoesNotResetActivationOrAliasDrafts() {
        let f = Fixture(); defer { f.teardown() }
        f.controller.applyShortcutPreset(.controlCommandSpace)
        let activation = f.controller.draft
        f.controller.appManagementView.aliasField.stringValue = "Unsaved fixture alias"
        f.draft(changed)
        f.controller.hideSettings()
        XCTAssertEqual(f.controller.appearanceView.draft, changed)
        XCTAssertEqual(f.controller.draft, activation)
        XCTAssertEqual(f.controller.appManagementView.aliasField.stringValue, "Unsaved fixture alias")
    }

    func testRetainedDismissCallbackCannotFlushReplacementViewEdits() throws {
        let f = Fixture(); defer { f.teardown() }
        let oldDismiss = try XCTUnwrap(f.controller.appearanceView.onDiscardDraft)
        let replacement = AppearanceSettingsView(frame: .zero)
        f.app.configureAppearanceSettings(replacement)
        XCTAssertTrue(replacement.onChange?(changed) == true)
        oldDismiss()
        XCTAssertTrue(f.store.writes.isEmpty)
        replacement.onFlush?()
        XCTAssertEqual(f.store.writes, [changed])
    }

    private func installUnavailableAppearance(_ f: Fixture) {
        f.app.installAppearancePreferences(makePersistentStore: { _ in nil })
        f.app.configureAppearanceSettings(f.controller.appearanceView)
    }

    func testNilPersistentFactoryRejectsChangedLiveEditWithoutSessionOnlySuccess() {
        let f = Fixture(); defer { f.teardown() }
        installUnavailableAppearance(f)
        f.draft(changed)
        XCTAssertTrue(f.store.writes.isEmpty)
        XCTAssertEqual(f.app.appearancePreferences, .default)
        XCTAssertEqual(f.controller.appearanceView.liveSaveState, .unavailable)
    }

    func testNilPersistentFactoryDoesNotReportUnchangedDefaultsAsPersisted() {
        let f = Fixture(); defer { f.teardown() }
        installUnavailableAppearance(f)
        f.controller.appearanceView.defaultsClicked(nil)
        XCTAssertTrue(f.store.writes.isEmpty)
        XCTAssertEqual(f.controller.appearanceView.liveSaveState, .unavailable)
    }

    func testUnavailableCloseDoesNotPretendUnacceptedDraftWasSaved() {
        let f = Fixture(); defer { f.teardown() }
        installUnavailableAppearance(f)
        f.draft(changed)
        f.controller.hideSettings()
        XCTAssertTrue(f.store.writes.isEmpty)
        XCTAssertEqual(f.app.appearancePreferences, .default)
        XCTAssertNil(f.app.liveAppearanceCoordinator)
    }

    func testUnavailableFactoryPreservesPreviouslyAcceptedCustomAppearance() {
        let f = Fixture(changed); defer { f.teardown() }
        installUnavailableAppearance(f)
        XCTAssertEqual(f.app.appearancePreferences, changed)
        XCTAssertTrue(f.store.writes.isEmpty)
    }

    func testUnavailableFactoryDoesNotDropPreviouslyPersistedQueuedAppearance() {
        let f = Fixture(); defer { f.teardown() }
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        f.app.surface = surface
        gestureBegan(surface, at: 0)
        f.draft(changed)
        f.app.liveAppearanceCoordinator?.flush()
        installUnavailableAppearance(f)
        XCTAssertEqual(f.app.appearancePresentationState, .queued)
        surface.cancel()
        f.app.flushPendingAppearanceIfReady()
        XCTAssertEqual(f.app.appearancePreferences, changed)
        XCTAssertEqual(f.store.preferences, changed)
    }

    func testExplicitAppearanceStoreBypassesPersistentFactoryAndStillPreviewsAndSaves() {
        let f = Fixture(); defer { f.teardown() }
        f.app.installAppearancePreferences(store: f.store, makePersistentStore: { _ in
            XCTFail("Injected store must bypass factory"); return nil
        })
        f.app.configureAppearanceSettings(f.controller.appearanceView)
        f.draft(changed)
        XCTAssertEqual(f.app.appearancePreferences, changed)
        f.controller.hideSettings()
        XCTAssertEqual(f.store.preferences, changed)
    }

    func testOldLiveAndDismissCallbacksRejectReplacementOwner() throws {
        let f = Fixture(); defer { f.teardown() }
        let edit = try XCTUnwrap(f.controller.appearanceView.onChange)
        let dismiss = try XCTUnwrap(f.controller.appearanceView.onDiscardDraft)
        f.app.installAppearancePreferences(store: f.store)
        f.app.configureAppearanceSettings(f.controller.appearanceView)
        XCTAssertFalse(edit(changed))
        dismiss()
        XCTAssertTrue(f.store.writes.isEmpty)
    }

    func testCurrentExplicitPersistenceCommandSupersedesOlderLiveIntentOnReopen() throws {
        let f = Fixture(); defer { f.teardown() }
        f.draft(changed)
        let explicit = AppearancePreferences(wallpaperBlurRadius: 42, preferredIconSide: 40, appLabelFontSize: 12)
        let base = try XCTUnwrap(f.app.liveAppearanceCoordinator?.persistence)
        XCTAssertEqual(base.apply(explicit), .saved)
        f.app.configureAppearanceSettings(f.controller.appearanceView)
        XCTAssertEqual(f.controller.appearanceView.draft, explicit)
        f.controller.hideSettings()
        XCTAssertEqual(f.store.preferences, explicit)
        XCTAssertEqual(f.app.appearancePreferences, explicit)
        XCTAssertEqual(f.store.writes, [explicit])
    }

    func testUnchangedExplicitCommandCancelsAnOlderUnsavedLiveIntention() throws {
        let f = Fixture(); defer { f.teardown() }
        f.draft(changed)
        let base = try XCTUnwrap(f.app.liveAppearanceCoordinator?.persistence)
        XCTAssertEqual(base.apply(.default), .saved)
        f.app.configureAppearanceSettings(f.controller.appearanceView)
        f.controller.hideSettings()
        XCTAssertEqual(f.controller.appearanceView.draft, .default)
        XCTAssertEqual(f.app.appearancePreferences, .default)
        XCTAssertTrue(f.store.writes.isEmpty)
    }

    func testRetainedOldPersistenceCommandCannotPresentIntoReplacementOwner() throws {
        let f = Fixture(); defer { f.teardown() }
        let old = try XCTUnwrap(f.app.liveAppearanceCoordinator?.persistence)
        let replacement = AppearanceCloseStore(.init(wallpaperBlurRadius: 41))
        f.app.installAppearancePreferences(store: replacement)
        XCTAssertEqual(old.apply(changed), .saved)
        XCTAssertEqual(f.app.appearancePreferences, replacement.preferences)
        XCTAssertEqual(f.app.liveAppearanceCoordinator?.requested, replacement.preferences)
        XCTAssertTrue(replacement.writes.isEmpty)
    }

    func testQuitFlushesStillDebouncedPreferenceBeforeFastPath() {
        let f = Fixture(); defer { f.teardown() }
        f.draft(changed)
        XCTAssertTrue(f.store.writes.isEmpty)
        let reply = f.app.requestWorkspaceQuit(reply: { _ in XCTFail("Fast path is synchronous") },
            chooseOnFailure: { _, _ in XCTFail("Successful flush must not prompt") })
        XCTAssertEqual(reply, .terminateNow)
        XCTAssertEqual(f.store.preferences, changed)
    }

    func testFailedLiveSaveUsesExistingQuitCancelProtection() async {
        let f = Fixture(); defer { f.teardown() }
        f.store.result = .encodingFailed
        f.draft(changed)
        let refused = expectation(description: "quit canceled")
        let result = f.app.requestWorkspaceQuit(reply: { approved in
            XCTAssertFalse(approved); refused.fulfill()
        }, chooseOnFailure: { status, choose in
            XCTAssertEqual(status, .failed); choose(false)
        })
        XCTAssertEqual(result, .terminateLater)
        await fulfillment(of: [refused], timeout: 2)
        XCTAssertTrue(f.app.liveAppearanceCoordinator?.requiresQuitProtection == true)
        XCTAssertEqual(f.controller.appearanceView.draft, changed)
    }
}
