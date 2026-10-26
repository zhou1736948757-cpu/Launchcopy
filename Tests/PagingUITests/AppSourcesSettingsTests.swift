import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppSourcesSettingsTests: XCTestCase {
    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        XCTFail("Bounded action did not finish")
    }
    func testActualAddControlCanonicalDraftAndNoSaveUntilApply() async {
        let view = AppSourcesSettingsView(frame: .zero)
        var saves: [AppSourcesPreferences] = []
        view.onAdmit = { _ in .accepted(URL(fileURLWithPath: "/SyntheticApps")) }
        view.onApply = { saves.append($0); return .saved }
        view.addDraftRoot(URL(fileURLWithPath: "/SelectedAlias"))
        await settle { view.draft.customRootPaths == ["/SyntheticApps"] }
        XCTAssertEqual(saves, []); XCTAssertEqual(view.rootsPopup.numberOfItems, 2)
        view.applyButton.performClick(nil)
        await settle { !saves.isEmpty && view.applyButton.isEnabled }
        XCTAssertEqual(saves, [view.draft]); XCTAssertTrue(view.statusLabel.stringValue.contains("已保存"))
    }
    func testRemoveAndAutomaticControlsAreDraftOnlyAndManualRefreshUsesCommittedCallback() {
        let view = AppSourcesSettingsView(frame: .zero)
        var refreshes = 0
        view.onRefresh = { refreshes += 1 }
        view.reload(preferences: .init(customRootPaths: ["/ExtraApps"]), fixedRoots: [], watchStatus: .active)
        view.rootsPopup.selectItem(at: 1); view.selectionChanged(nil)
        view.removeButton.performClick(nil)
        XCTAssertEqual(view.draft.customRootPaths, [])
        view.automaticCheckbox.performClick(nil)
        XCTAssertFalse(view.draft.automaticRefreshEnabled)
        view.refreshButton.performClick(nil); XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(view.applyButton.identifier?.rawValue, "sources.apply")
    }
    func testFutureSettingsDisableAllMutatorsButKeepManualRefresh() {
        let view = AppSourcesSettingsView(frame: .zero)
        view.onRefresh = { }
        view.reload(preferences: .default, fixedRoots: [], loadResult: .futureVersion(3), watchStatus: .degraded)
        for control in [view.addButton, view.removeButton, view.applyButton, view.automaticCheckbox, view.rootsPopup] as [NSControl] {
            XCTAssertFalse(control.isEnabled)
        }
        XCTAssertTrue(view.refreshButton.isEnabled)
        XCTAssertTrue(view.watchLabel.stringValue.contains("部分来源"))
        XCTAssertTrue(view.statusLabel.stringValue.contains("较新版本"))
    }
    func testAlreadyCoveredAndRejectedDoNotAddDraftPaths() async {
        let view = AppSourcesSettingsView(frame: .zero)
        view.onAdmit = { _ in .alreadyCovered }
        view.addDraftRoot(URL(fileURLWithPath: "/Apps/Child"))
        await settle { view.addButton.isEnabled }
        XCTAssertEqual(view.draft, .default)
        view.onAdmit = { _ in .rejected(.tooBroad) }
        view.addDraftRoot(URL(fileURLWithPath: "/"))
        await settle { view.addButton.isEnabled }
        XCTAssertEqual(view.draft, .default)
    }
    func testCancelOutstandingAdmissionDoesNotAppendDraftAfterReload() async {
        let view = AppSourcesSettingsView(frame: .zero)
        var continuation: CheckedContinuation<AppSourceRootAdmissionResult, Never>?
        view.onAdmit = { _ in await withCheckedContinuation { continuation = $0 } }
        view.addDraftRoot(URL(fileURLWithPath: "/ExtraApps"))
        await settle { continuation != nil }
        view.reload(preferences: .default, fixedRoots: [], watchStatus: .disabled)
        continuation?.resume(returning: .accepted(URL(fileURLWithPath: "/ExtraApps")))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(view.draft, .default); XCTAssertTrue(view.addButton.isEnabled)
    }
    func testApplyFailureRetainsDraftAndDoesNotShowSuccess() async {
        let view = AppSourcesSettingsView(frame: .zero)
        view.reload(preferences: .init(customRootPaths: ["/ExtraApps"]), fixedRoots: [], watchStatus: .active)
        view.onApply = { _ in .failed }; view.applyButton.performClick(nil)
        await settle { view.applyButton.isEnabled }
        XCTAssertEqual(view.draft.customRootPaths, ["/ExtraApps"])
        XCTAssertTrue(view.statusLabel.stringValue.contains("未应用"))
    }
}
