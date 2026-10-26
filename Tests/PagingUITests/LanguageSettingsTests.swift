import AppKit
import XCTest
import LauncherLocalization
@testable import PagingPrototypeApp

@MainActor
private final class LanguageStoreSpy: LanguagePreferencesPersisting {
    var result = LanguagePreferencesLoadResult.missing
    var saveResult = LanguagePreferencesSaveResult.saved
    var loads = 0
    var writes: [LanguagePreferences] = []
    func load() -> LanguagePreferencesLoadResult { loads += 1; return result }
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult {
        writes.append(preferences)
        if saveResult == .saved { result = .loaded(preferences) }
        return saveResult
    }
}

@MainActor
final class LanguageSettingsTests: XCTestCase {
    func testMissingStartupDoesNotWriteButEqualDefaultApplyDoes() {
        let store = LanguageStoreSpy()
        var accepted: [InterfaceLanguagePreference] = []
        let coordinator = LanguageSettingsCoordinator(store: store) { accepted.append($0) }
        XCTAssertEqual(coordinator.committed, .default)
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(store.writes, [.default])
        XCTAssertEqual(accepted, [.system])
    }

    func testHealthyEqualApplyInspectsOnceButDoesNotWriteAndCanRefreshSystem() {
        let store = LanguageStoreSpy(); store.result = .loaded(.default)
        var preferred = ["en"]
        var callbacks: [@MainActor () -> Void] = []
        let owner = LanguagePresentationController(preference: .system,
            preferredLanguages: { preferred }, isReady: { true }, schedule: { callbacks.append($0) })
        let coordinator = LanguageSettingsCoordinator(store: store) { owner.request($0) }
        let before = store.loads
        coordinator.apply(.default)
        XCTAssertEqual(store.loads - before, 1)
        XCTAssertTrue(store.writes.isEmpty); XCTAssertTrue(callbacks.isEmpty)
        preferred = ["ja"]; coordinator.apply(.default)
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertEqual(callbacks.count, 1)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .japanese)
    }

    func testLateMissingOrCorruptPayloadExplicitlyRepairsEvenEqualDraft() {
        for origin in [LanguagePreferencesLoadResult.missing, .corrupt] {
            let store = LanguageStoreSpy(); store.result = .loaded(.default)
            let coordinator = LanguageSettingsCoordinator(store: store) { _ in }
            store.result = origin
            XCTAssertEqual(coordinator.apply(.default), .saved)
            XCTAssertEqual(store.writes, [.default])
        }
    }

    func testFreshProtectedOrUnavailableLoadDoesNotWriteOrRequestPresentation() {
        for origin in [LanguagePreferencesLoadResult.futureVersion(3), .futureVersionUnrepresentable, .oversized, .unavailable] {
            let store = LanguageStoreSpy(); store.result = .loaded(.default)
            var count = 0
            let coordinator = LanguageSettingsCoordinator(store: store) { _ in count += 1 }
            store.result = origin
            XCTAssertNotEqual(coordinator.apply(.init(language: .japanese)), .saved)
            XCTAssertEqual(coordinator.committed, .default)
            XCTAssertTrue(store.writes.isEmpty); XCTAssertEqual(count, 0)
        }
    }

    func testFailedSaveRetainsAcceptedAndDoesNotIndependentlyRefreshSystem() {
        let store = LanguageStoreSpy(); store.saveResult = .encodingFailed
        var count = 0
        let coordinator = LanguageSettingsCoordinator(store: store) { _ in count += 1 }
        XCTAssertEqual(coordinator.apply(.init(language: .japanese)), .encodingFailed)
        XCTAssertEqual(coordinator.committed, .default)
        XCTAssertEqual(count, 0)
    }

    func testAcceptedReopenRefreshDoesNotConsultOrAcceptUnrelatedDraft() {
        let store = LanguageStoreSpy(); store.result = .loaded(.init(language: .english))
        var requests: [InterfaceLanguagePreference] = []
        let coordinator = LanguageSettingsCoordinator(store: store) { requests.append($0) }
        let view = LanguageSettingsView(frame: .zero)
        view.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        view.languagePopup.selectItem(at: 3); view.choiceChanged(nil)
        coordinator.refreshAcceptedPresentation()
        XCTAssertEqual(requests, [.english])
        XCTAssertEqual(view.draft.language, .japanese)
        XCTAssertTrue(store.writes.isEmpty)
    }

    func testNativeChoiceApplyDefaultsAndRelabelPreserveDraftAndIdentity() {
        let view = LanguageSettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 560))
        var saves: [LanguagePreferences] = []
        view.onApply = { saves.append($0); return .saved }
        view.presentationStateProvider = { .queued }
        view.reload(preferences: .default, loadResult: .missing)
        XCTAssertEqual(view.languagePopup.numberOfItems, 4)
        view.languagePopup.selectItem(at: 3); view.choiceChanged(nil)
        for language in InterfaceLanguage.allCases {
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(view.draft.language, .japanese)
            XCTAssertEqual(view.languagePopup.indexOfSelectedItem, 3)
            XCTAssertEqual(view.languagePopup.item(at: 3)?.title, "日本語")
            XCTAssertEqual(view.applyButton.identifier?.rawValue, "language.apply")
            XCTAssertEqual(view.applyButton.title, LocalizedStrings(language: language).text(.apply))
            XCTAssertEqual(view.applyButton.accessibilityLabel(), view.applyButton.title)
        }
        view.applyButton.performClick(nil)
        XCTAssertEqual(saves, [.init(language: .japanese)])
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.text(.languageQueued))
        view.defaultsButton.performClick(nil)
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(saves.count, 1)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.text(.languageDraftDefaults))
    }

    func testNativeFailureRetainsDraftAndNeverShowsApplied() {
        let view = LanguageSettingsView(frame: .zero)
        view.onApply = { _ in .encodingFailed }
        view.presentationStateProvider = { .applied }
        view.languagePopup.selectItem(at: 2); view.choiceChanged(nil)
        view.applyButton.performClick(nil)
        XCTAssertEqual(view.draft.language, .english)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.text(.languageSaveFailed))
    }

    func testProtectedControlsCannotApplyOrDefaultByAction() {
        let view = LanguageSettingsView(frame: .zero)
        var count = 0
        view.onApply = { _ in count += 1; return .saved }
        for origin in [LanguagePreferencesLoadResult.futureVersion(3), .futureVersionUnrepresentable, .oversized, .unavailable] {
            view.reload(preferences: .init(language: .japanese), loadResult: origin)
            XCTAssertFalse(view.applyButton.isEnabled)
            XCTAssertFalse(view.defaultsButton.isEnabled)
            XCTAssertFalse(view.languagePopup.isEnabled)
            view.applyClicked(nil); view.defaultsClicked(nil)
            XCTAssertEqual(view.draft.language, .japanese)
        }
        XCTAssertEqual(count, 0)
    }

    func testPresentationStatusRelabelKeepsFeedbackAndDraft() {
        let view = LanguageSettingsView(frame: .zero)
        var state = LanguagePresentationState.queued
        view.onApply = { _ in .saved }; view.presentationStateProvider = { state }
        view.languagePopup.selectItem(at: 3); view.applyClicked(nil)
        view.relabel(strings: LocalizedStrings(language: .english))
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.text(.languageQueued))
        state = .applied; view.refreshPresentationStatus()
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.text(.languageApplied))
        XCTAssertEqual(view.draft.language, .japanese)
    }
}
