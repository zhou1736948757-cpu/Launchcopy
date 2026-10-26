import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp

/// Detached controls only; callbacks own persistence and the authoritative reload.
@MainActor
final class AppManagementSettingsTests: XCTestCase {
    private func record(_ suffix: String, name: String = "Shared", path: String? = nil) -> AppRecord {
        let bundleID = "fixture.management.settings.\(suffix)"
        let id = CatalogFixture.appID(bundleID)
        return CatalogFixture.record(id: id, displayName: name, bundleID: bundleID,
                                     url: URL(fileURLWithPath: path ?? "/SyntheticApps/\(suffix).app"),
                                     icon: .from(appID: id), rootPriority: 0)
    }

    private func select(_ record: AppRecord, in view: AppManagementSettingsView) throws {
        let item = try XCTUnwrap(view.appPopup.itemArray.first {
            ($0.representedObject as? AppRecord)?.id == record.id
        })
        view.appPopup.select(item)
        view.selectionChanged(nil)
        XCTAssertEqual(view.selectedRecord?.id, record.id)
    }

    private func assertSelectionControls(_ view: AppManagementSettingsView, enabled: Bool,
                                         file: StaticString = #filePath, line: UInt = #line) {
        for control in [view.hiddenCheckbox, view.aliasField, view.saveAliasButton,
                        view.clearAliasButton] as [NSControl] {
            XCTAssertEqual(control.isEnabled, enabled, file: file, line: line)
        }
    }

    func testDuplicateTitlesSelectIndependentRecordsAndSurviveReorderByAppID() throws {
        let first = record("first")
        let second = record("second")
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [first, second], preferences: .default)
        let titles = view.appPopup.itemArray.filter { $0.representedObject is AppRecord }.map(\.title)
        XCTAssertEqual(titles, ["Shared", "Shared"])
        try select(second, in: view)
        var selected: [AppID] = []
        view.onSetAlias = { app, _ in selected.append(app.id); return .saved }
        view.saveAlias(nil)
        XCTAssertEqual(selected, [second.id])
        let refreshed = record("second", name: "Renamed", path: "/SyntheticApps/Moved.app")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: refreshed))
        view.reload(records: [refreshed, first], preferences: preferences)
        XCTAssertEqual(view.selectedRecord, refreshed)
        XCTAssertEqual(view.aliasField.stringValue, "Alias")
        view.saveAlias(nil)
        XCTAssertEqual(selected, [second.id, second.id])
    }

    func testHiddenRecordsRemainSelectableWithTheirOwnAliasAndState() throws {
        let first = record("first")
        let second = record("second")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Workspace", for: second))
            .settingHidden(true, for: second)
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [first, second], preferences: preferences)
        XCTAssertEqual(view.appPopup.itemArray.compactMap { ($0.representedObject as? AppRecord)?.id },
                       [first.id, second.id])
        try select(second, in: view)
        XCTAssertEqual(view.hiddenCheckbox.state, .on)
        XCTAssertEqual(view.aliasField.stringValue, "Workspace")
        assertSelectionControls(view, enabled: true)
        try select(first, in: view)
        XCTAssertEqual(view.hiddenCheckbox.state, .off)
        XCTAssertEqual(view.aliasField.stringValue, "")
    }

    func testRemovedSelectionClearsControlsAndDoesNotTargetReplacement() throws {
        let first = record("first")
        let second = record("second")
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [first, second], preferences: .default)
        try select(second, in: view)
        view.reload(records: [first], preferences: .default)
        XCTAssertNil(view.selectedRecord)
        XCTAssertEqual(view.aliasField.stringValue, "")
        XCTAssertEqual(view.hiddenCheckbox.state, .off)
        assertSelectionControls(view, enabled: false)
        view.onSetHidden = { _, _ in XCTFail("No selected app"); return .saved }
        view.onSetAlias = { _, _ in XCTFail("No selected app"); return .saved }
        view.hiddenChanged(nil)
        view.saveAlias(nil)
        view.clearAlias(nil)
    }

    func testReloadAndEditingAliasDoNotInvokePersistenceCallbacks() throws {
        let app = record("target")
        let view = AppManagementSettingsView(frame: .zero)
        view.onSetHidden = { _, _ in XCTFail("Reload persisted hidden state"); return .saved }
        view.onSetAlias = { _, _ in XCTFail("Draft alias persisted"); return .saved }
        view.onRestoreAll = { XCTFail("Reload restored apps"); return .saved }
        view.reload(records: [app], preferences: .default)
        try select(app, in: view)
        view.aliasField.stringValue = "Unsaved draft"
        view.reload(records: [app], preferences: .default)
        XCTAssertEqual(view.aliasField.stringValue, "")
        XCTAssertEqual(view.selectedRecord, app)
    }

    func testAliasAndRestoreActionsDeliverExactIntentToCallbacks() throws {
        let app = record("target")
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [app], preferences: .default.settingHidden(true, for: app))
        try select(app, in: view)
        var aliases: [String?] = []
        var restored = 0
        view.onSetAlias = { selected, alias in
            XCTAssertEqual(selected, app)
            aliases.append(alias)
            return .saved
        }
        view.onRestoreAll = { restored += 1; return .saved }
        view.aliasField.stringValue = "  Draft alias  "
        view.saveAlias(nil)
        view.clearAlias(nil)
        view.restoreAll(nil)
        XCTAssertEqual(aliases, ["  Draft alias  ", nil], "Coordinator owns alias normalization")
        XCTAssertEqual(restored, 1)
        XCTAssertFalse(view.statusLabel.isHidden)
    }

    func testFailedHideRestoresCommittedCheckboxForBothDirections() throws {
        let app = record("target")
        for hidden in [false, true] {
            let preferences = AppManagementPreferences.default.settingHidden(hidden, for: app)
            let view = AppManagementSettingsView(frame: .zero)
            view.reload(records: [app], preferences: preferences)
            try select(app, in: view)
            var requests: [Bool] = []
            view.onSetHidden = { selected, requested in
                XCTAssertEqual(selected, app)
                requests.append(requested)
                return .failed
            }
            view.hiddenCheckbox.state = hidden ? .off : .on
            view.hiddenChanged(nil)
            XCTAssertEqual(requests, [!hidden])
            XCTAssertEqual(view.hiddenCheckbox.state, hidden ? .on : .off)
            XCTAssertFalse(view.statusLabel.isHidden)
            XCTAssertEqual(view.statusLabel.textColor, NSColor.systemRed)
        }
    }

    func testSuccessfulHideUsesAuthoritativeCallbackReload() throws {
        let app = record("target")
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [app], preferences: .default)
        try select(app, in: view)
        view.onSetHidden = { selected, hidden in
            let preferences = AppManagementPreferences.default.settingHidden(hidden, for: selected)
            view.reload(records: [app], preferences: preferences)
            return .saved
        }
        view.hiddenCheckbox.state = .on
        view.hiddenChanged(nil)
        XCTAssertEqual(view.hiddenCheckbox.state, .on)
        XCTAssertEqual(view.selectedRecord, app)
        XCTAssertTrue(view.restoreAllButton.isEnabled)
        XCTAssertEqual(view.statusLabel.textColor, NSColor.systemGreen)
        view.onSetHidden = nil
    }

    func testMissingCallbacksReportFailureWithoutImplyingHiddenChange() throws {
        let app = record("target")
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [app], preferences: .default)
        try select(app, in: view)
        view.hiddenCheckbox.state = .on
        view.hiddenChanged(nil)
        XCTAssertEqual(view.hiddenCheckbox.state, .off)
        for action in [view.saveAlias, view.clearAlias, view.restoreAll] {
            action(nil)
            XCTAssertFalse(view.statusLabel.isHidden)
            XCTAssertEqual(view.statusLabel.textColor, NSColor.systemRed)
        }
    }

    func testFutureSchemaDisablesAndGuardsAllMutationsThenWritableReloadRecovers() throws {
        let app = record("target")
        let preferences = AppManagementPreferences.default.settingHidden(true, for: app)
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [app], preferences: preferences, loadResult: .futureVersion(5))
        try select(app, in: view)
        assertSelectionControls(view, enabled: false)
        XCTAssertFalse(view.restoreAllButton.isEnabled)
        XCTAssertTrue(view.appPopup.isEnabled, "Read-only metadata remains inspectable")
        var calls = 0
        view.onSetHidden = { _, _ in calls += 1; return .saved }
        view.onSetAlias = { _, _ in calls += 1; return .saved }
        view.onRestoreAll = { calls += 1; return .saved }
        // Direct delivery must be guarded as well as the disabled control state.
        view.hiddenChanged(nil)
        view.saveAlias(nil)
        view.clearAlias(nil)
        view.restoreAll(nil)
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(view.statusLabel.isHidden)
        view.reload(records: [app], preferences: preferences, loadResult: .loaded(preferences))
        assertSelectionControls(view, enabled: true)
        XCTAssertTrue(view.restoreAllButton.isEnabled)
        view.clearAlias(nil)
        XCTAssertEqual(calls, 1)
    }

    func testCorruptLoadPermitsRepairAndRestoreIncludesUninstalledReferences() throws {
        let app = record("target")
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [app], preferences: .default, loadResult: .corrupt)
        try select(app, in: view)
        assertSelectionControls(view, enabled: true)
        XCTAssertFalse(view.restoreAllButton.isEnabled)
        var repairs = 0
        view.onSetAlias = { _, _ in repairs += 1; return .saved }
        view.saveAlias(nil)
        XCTAssertEqual(repairs, 1)
        view.reload(records: [], preferences: .init(hiddenKeys: ["bundle:fixture.uninstalled"]))
        XCTAssertNil(view.selectedRecord)
        assertSelectionControls(view, enabled: false)
        XCTAssertTrue(view.restoreAllButton.isEnabled)
        view.onRestoreAll = { repairs += 1; return .saved }
        view.restoreAll(nil)
        XCTAssertEqual(repairs, 2)
    }
    func testPathKeyAliasRemainsEditableAfterRecordGainsBundleID() throws {
        let app = record("enriched")
        let key = PersistentAppReference.canonicalPath(PersistentAppReference.normalizedPath(app.canonicalURL)).comparisonKey
        let preferences = AppManagementPreferences(hiddenKeys: [key], aliases: [key: "Legacy alias"])
        let view = AppManagementSettingsView(frame: .zero)
        view.reload(records: [app], preferences: preferences)
        try select(app, in: view)
        XCTAssertEqual(view.aliasField.stringValue, "Legacy alias")
        XCTAssertEqual(view.hiddenCheckbox.state, .on)
        var updated = preferences
        view.onSetAlias = { record, alias in
            updated = updated.settingAlias(alias, for: record) ?? updated
            return .saved
        }
        view.clearAlias(nil)
        XCTAssertNil(updated.alias(for: app))
        XCTAssertTrue(updated.isHidden(app))
    }

}
