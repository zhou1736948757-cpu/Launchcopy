import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Real controls mounted in unshown windows. These tests do not establish native
/// presentation, persistence/restart, keyboard navigation or VoiceOver acceptance.
@MainActor
final class IdentifierSearchSettingsTests: XCTestCase {
    private let frame = NSRect(x: 0, y: 0, width: 500, height: 560)
    private let languages: [InterfaceLanguage] = [.english, .simplifiedChinese, .japanese]

    private func mount(_ view: AppManagementSettingsView) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        return window
    }

    private func preferences(enabled: Bool) -> AppManagementPreferences {
        var value = AppManagementPreferences.default
        value.searchByBundleIdentifier = enabled
        return value
    }

    private func record() -> AppRecord {
        let bundle = "com.example.app"
        let id = CatalogFixture.appID(bundle)
        return CatalogFixture.record(id: id, displayName: "Example App", bundleID: bundle,
            url: URL(fileURLWithPath: "/SyntheticApps/Example.app"),
            icon: .from(appID: id), rootPriority: 0)
    }

    private func assertStatus(_ view: AppManagementSettingsView, key: SettingsTextKey,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(view.identifierSearchStatusLabel.isHidden, file: file, line: line)
        XCTAssertEqual(view.identifierSearchStatusLabel.stringValue, view.strings.settingsText(key), file: file, line: line)
        XCTAssertEqual(view.identifierSearchStatusLabel.accessibilityLabel(),
                       view.identifierSearchStatusLabel.stringValue, file: file, line: line)
    }

    func testDefaultOffAndReloadMatchStoredFlagWithoutSelectingAnAppOrSaving() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        XCTAssertFalse(window.isVisible)
        XCTAssertTrue(view.identifierSearchCheckbox.window === window)
        XCTAssertEqual(view.identifierSearchCheckbox.identifier?.rawValue, "management.search-identifiers")
        XCTAssertEqual(view.identifierSearchHelpLabel.identifier?.rawValue, "management.search-identifiers.help")
        XCTAssertEqual(view.identifierSearchStatusLabel.identifier?.rawValue, "management.search-identifiers.status")
        XCTAssertFalse(AppManagementPreferences.default.searchByBundleIdentifier)
        XCTAssertEqual(view.identifierSearchCheckbox.state, .off)
        XCTAssertTrue(view.identifierSearchCheckbox.isEnabled)
        XCTAssertNil(view.selectedRecord)
        var calls = 0
        view.onSetSearchByBundleIdentifier = { _ in calls += 1; return .saved }
        for enabled in [true, false, true] {
            let stored = preferences(enabled: enabled)
            view.reload(records: [], preferences: stored, loadResult: .loaded(stored))
            XCTAssertEqual(view.identifierSearchCheckbox.state, enabled ? .on : .off)
            XCTAssertTrue(view.identifierSearchCheckbox.isEnabled)
            XCTAssertNil(view.selectedRecord)
        }
        XCTAssertEqual(calls, 0)
    }

    func testMountedCheckboxSendsBothDirectionsWithoutSelectedAppAndShowsAppliedReceipt() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        var requests: [Bool] = []
        view.onSetSearchByBundleIdentifier = { requests.append($0); return .saved }
        view.identifierSearchPendingProvider = { false }
        view.onSetHidden = { _, _ in XCTFail("Policy changed hidden state"); return .failed }
        view.onSetAlias = { _, _ in XCTFail("Policy changed an alias"); return .failed }
        view.onRestoreAll = { XCTFail("Policy restored hidden apps"); return .failed }
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(requests, [true])
        XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
        assertStatus(view, key: .managementIdentifierSearchApplied)
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(requests, [true, false])
        XCTAssertEqual(view.identifierSearchCheckbox.state, .off)
        assertStatus(view, key: .managementIdentifierSearchApplied)
        XCTAssertNil(view.selectedRecord)
        XCTAssertTrue(view.statusLabel.isHidden)
    }

    func testSavedReceiptUsesPendingProviderAfterCallbackAndRefreshesWithoutSavingAgain() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        var pending = false
        var requests: [Bool] = []
        view.identifierSearchPendingProvider = { pending }
        view.onSetSearchByBundleIdentifier = {
            requests.append($0)
            pending = true
            return .saved
        }
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(requests, [true])
        XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
        assertStatus(view, key: .managementIdentifierSearchQueued)
        let stored = preferences(enabled: true)
        view.reload(records: [], preferences: stored, loadResult: .loaded(stored))
        assertStatus(view, key: .managementIdentifierSearchQueued)
        pending = false
        view.refreshIdentifierSearchState(storedEnabled: true, isPending: false)
        assertStatus(view, key: .managementIdentifierSearchApplied)
        XCTAssertEqual(requests, [true])
        XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
        XCTAssertTrue(view.statusLabel.isHidden)
    }

    func testSavedWithoutPresentationProviderDoesNotClaimApplied() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        view.onSetSearchByBundleIdentifier = { _ in .saved }
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
        assertStatus(view, key: .managementIdentifierSearchQueued)
    }

    func testFailedOrInvalidSaveRollsBackBothDirectionsAndSuccessfulRetryUsesStoredBaseline() {
        for enabled in [false, true] {
            for failure in [AppManagementSaveResult.failed, .invalidPreferences] {
                let view = AppManagementSettingsView(frame: frame)
                let window = mount(view)
                defer { window.close() }
                view.reload(records: [], preferences: preferences(enabled: enabled))
                var result = failure
                var requests: [Bool] = []
                view.onSetSearchByBundleIdentifier = { requests.append($0); return result }
                view.identifierSearchPendingProvider = { false }
                view.identifierSearchCheckbox.performClick(nil)
                XCTAssertEqual(requests, [!enabled])
                XCTAssertEqual(view.identifierSearchCheckbox.state, enabled ? .on : .off)
                assertStatus(view, key: .managementIdentifierSearchFailed)
                XCTAssertEqual(view.identifierSearchStatusLabel.textColor, NSColor.systemRed)
                for language in languages {
                    view.relabel(strings: LocalizedStrings(language: language))
                    XCTAssertEqual(view.identifierSearchCheckbox.state, enabled ? .on : .off)
                    assertStatus(view, key: .managementIdentifierSearchFailed)
                }
                result = .saved
                view.identifierSearchCheckbox.performClick(nil)
                XCTAssertEqual(requests, [!enabled, !enabled])
                XCTAssertEqual(view.identifierSearchCheckbox.state, enabled ? .off : .on)
                assertStatus(view, key: .managementIdentifierSearchApplied)
                XCTAssertTrue(view.statusLabel.isHidden)
            }
        }
    }

    func testMissingCallbackRollsBackAndShowsFailure() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(view.identifierSearchCheckbox.state, .off)
        assertStatus(view, key: .managementIdentifierSearchFailed)
    }

    func testCorruptAndFutureLoadsDisableOnlyPolicyAsRequiredAndGuardDirectActionDelivery() {
        for loadResult in [AppManagementLoadResult.corrupt, .futureVersion(9)] {
            let view = AppManagementSettingsView(frame: frame)
            let window = mount(view)
            defer { window.close() }
            let app = record()
            view.reload(records: [app], preferences: preferences(enabled: true), loadResult: loadResult)
            view.appPopup.selectItem(at: 1)
            view.selectionChanged(nil)
            var calls = 0
            view.onSetSearchByBundleIdentifier = { _ in calls += 1; return .saved }
            XCTAssertFalse(view.identifierSearchCheckbox.isEnabled)
            XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
            view.identifierSearchCheckbox.performClick(nil)
            XCTAssertEqual(calls, 0)
            view.identifierSearchCheckbox.state = .off
            XCTAssertTrue(view.identifierSearchCheckbox.sendAction(view.identifierSearchCheckbox.action,
                                                                  to: view.identifierSearchCheckbox.target))
            XCTAssertEqual(calls, 0)
            XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
            let isCorrupt = loadResult == .corrupt
            assertStatus(view, key: isCorrupt ? .managementIdentifierSearchCorrupt : .managementIdentifierSearchFuture)
            XCTAssertEqual(view.aliasField.isEnabled, isCorrupt, "Legacy explicit repair behavior remains unchanged")
            XCTAssertEqual(view.hiddenCheckbox.isEnabled, isCorrupt)
            view.refreshIdentifierSearchState(storedEnabled: true, isPending: false)
            XCTAssertFalse(view.identifierSearchCheckbox.isEnabled)
            assertStatus(view, key: isCorrupt ? .managementIdentifierSearchCorrupt : .managementIdentifierSearchFuture)
            let stored = preferences(enabled: true)
            view.reload(records: [app], preferences: stored, loadResult: .loaded(stored))
            XCTAssertTrue(view.identifierSearchCheckbox.isEnabled)
            view.identifierSearchCheckbox.performClick(nil)
            XCTAssertEqual(calls, 1)
            XCTAssertEqual(view.identifierSearchCheckbox.state, .off)
        }
    }

    func testFutureVersionDiscoveredByCallbackRollsBackAndDisablesPolicyOnly() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        let app = record()
        view.reload(records: [app], preferences: .default)
        view.appPopup.selectItem(at: 1)
        view.selectionChanged(nil)
        view.onSetSearchByBundleIdentifier = { _ in .futureVersion(9) }
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(view.identifierSearchCheckbox.state, .off)
        XCTAssertFalse(view.identifierSearchCheckbox.isEnabled)
        assertStatus(view, key: .managementIdentifierSearchFuture)
        XCTAssertTrue(view.aliasField.isEnabled)
        XCTAssertTrue(view.statusLabel.isHidden)
    }

    func testMountedPolicyActionWithSynchronousReceiptPreservesAliasDraftAndManagementStatus() {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        let app = record()
        view.reload(records: [app], preferences: .default)
        view.appPopup.selectItem(at: 1)
        view.selectionChanged(nil)
        view.aliasField.stringValue = "  Unsaved alias draft  "
        view.onSetAlias = { _, _ in .failed }
        view.saveAliasButton.performClick(nil)
        let legacyStatus = view.statusLabel.stringValue
        let selectedItem = view.appPopup.selectedItem
        view.identifierSearchPendingProvider = { true }
        var requests: [Bool] = []
        view.onSetSearchByBundleIdentifier = { [weak view] enabled in
            requests.append(enabled)
            view?.refreshIdentifierSearchState(storedEnabled: enabled, isPending: true)
            return .saved
        }
        view.identifierSearchCheckbox.performClick(nil)
        XCTAssertEqual(requests, [true])
        XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
        assertStatus(view, key: .managementIdentifierSearchQueued)
        XCTAssertEqual(view.aliasField.stringValue, "  Unsaved alias draft  ")
        XCTAssertTrue(view.appPopup.selectedItem === selectedItem)
        XCTAssertEqual(view.selectedRecord, app)
        XCTAssertEqual(view.statusLabel.stringValue, legacyStatus)
        XCTAssertEqual(view.statusLabel.textColor, NSColor.systemRed)
    }

    func testPolicyRefreshAndRelabelPreserveAliasEditorDraftMenuIdentityAndSeparateFeedback() throws {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.makeFirstResponder(nil); window.close() }
        let app = record()
        view.reload(records: [app], preferences: .default)
        view.appPopup.selectItem(at: 1)
        view.selectionChanged(nil)
        view.aliasField.stringValue = "  Unsaved 別名 draft  "
        view.onSetAlias = { _, _ in .failed }
        view.saveAliasButton.performClick(nil)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.settingsText(.managementSaveFailed))
        XCTAssertTrue(window.makeFirstResponder(view.aliasField))
        let editor = try XCTUnwrap(view.aliasField.currentEditor() as? NSTextView)
        editor.setSelectedRange(NSRange(location: 2, length: 3))
        let draft = editor.string
        let selectedRange = editor.selectedRange()
        let menuItems = view.appPopup.itemArray
        let controls = [view.identifierSearchCheckbox, view.identifierSearchHelpLabel,
                        view.identifierSearchStatusLabel] as [NSView]
        var policyCalls = 0
        view.onSetSearchByBundleIdentifier = { _ in policyCalls += 1; return .saved }
        for pending in [true, false, true] {
            view.refreshIdentifierSearchState(storedEnabled: true, isPending: pending)
            for language in languages {
                view.relabel(strings: LocalizedStrings(language: language))
                XCTAssertEqual(view.identifierSearchCheckbox.state, .on)
                XCTAssertTrue(view.identifierSearchCheckbox.isEnabled)
                assertStatus(view, key: pending ? .managementIdentifierSearchQueued : .managementIdentifierSearchApplied)
                XCTAssertEqual(view.identifierSearchCheckbox.title, view.strings.settingsText(.managementSearchIdentifiers))
                XCTAssertEqual(view.identifierSearchCheckbox.accessibilityLabel(), view.identifierSearchCheckbox.title)
                XCTAssertEqual(view.identifierSearchHelpLabel.stringValue, view.strings.settingsText(.managementIdentifierSearchHelp))
                XCTAssertTrue(view.identifierSearchHelpLabel.stringValue.contains("com.example.app"))
                XCTAssertEqual(view.identifierSearchCheckbox.accessibilityHelp(), view.identifierSearchHelpLabel.stringValue)
                XCTAssertEqual(view.statusLabel.stringValue, view.strings.settingsText(.managementSaveFailed))
                XCTAssertEqual(view.statusLabel.textColor, NSColor.systemRed)
                XCTAssertFalse(view.statusLabel.isHidden)
                XCTAssertEqual(view.selectedRecord, app)
                XCTAssertEqual(view.appPopup.indexOfSelectedItem, 1)
                XCTAssertEqual(view.appPopup.itemArray.count, menuItems.count)
                for (before, after) in zip(menuItems, view.appPopup.itemArray) { XCTAssertTrue(before === after) }
                XCTAssertTrue(view.aliasField.currentEditor() === editor)
                XCTAssertTrue(window.firstResponder === editor)
                XCTAssertEqual(editor.string, draft)
                XCTAssertEqual(editor.selectedRange(), selectedRange)
                XCTAssertEqual(view.aliasField.stringValue, draft)
                XCTAssertTrue(controls[0] === view.identifierSearchCheckbox)
                XCTAssertTrue(controls[1] === view.identifierSearchHelpLabel)
                XCTAssertTrue(controls[2] === view.identifierSearchStatusLabel)
            }
        }
        XCTAssertEqual(policyCalls, 0)
    }

    func testIdentifierVocabularyParticipatesInStrictSchemaAndSafeEnglishFallback() {
        let keys: [SettingsTextKey] = [.managementSearchIdentifiers, .managementIdentifierSearchHelp,
            .managementIdentifierSearchApplied, .managementIdentifierSearchQueued,
            .managementIdentifierSearchFailed, .managementIdentifierSearchFuture,
            .managementIdentifierSearchCorrupt]
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
        let english = LocalizedStrings(language: .english)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            let fallback = LocalizedStrings(language: language, resourceProvider: MissingResources())
            for key in keys {
                XCTAssertTrue(LocalizedStrings.requiredResourceKeys.contains(key.rawValue))
                XCTAssertFalse(strings.settingsText(key).isEmpty)
                XCTAssertNotEqual(strings.settingsText(key), key.rawValue)
                XCTAssertEqual(fallback.settingsText(key), english.settingsText(key))
            }
        }
    }

    private struct MissingResources: LocalizationResourceProviding {
        func localizableStringsData(for language: InterfaceLanguage) -> Data? { nil }
    }
}
