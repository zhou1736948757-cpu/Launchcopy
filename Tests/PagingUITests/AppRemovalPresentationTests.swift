import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import PagingUI
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppRemovalPresentationTests: XCTestCase {
    private var record: AppRecord {
        let id = AppID.bundleIdentifier("fixture.removal.presentation")
        return AppRecord(id: id, displayName: "Disposable", bundleIdentifier: "fixture.removal.presentation",
                         canonicalURL: URL(fileURLWithPath: "/SyntheticApps/Disposable.app"),
                         iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }

    func testConfirmationUsesExplicitSingleBundleScopeAndDefaultsToCancelInEveryLanguage() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let alert = AppDelegate.makeAppRemovalConfirmation(record: record, strings: strings)
            XCTAssertEqual(alert.messageText, strings.removalText(.confirmTitle))
            XCTAssertEqual(alert.buttons.map(\.title), [strings.removalText(.cancel), strings.removalText(.confirmMove)])
            XCTAssertTrue(alert.informativeText.contains(record.displayName))
            XCTAssertTrue(alert.informativeText.contains(record.canonicalURL.path))
            XCTAssertTrue(alert.informativeText.contains(strings.removalText(.confirmMessage)))
            XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
            XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
            XCTAssertTrue(alert.window.defaultButtonCell === alert.buttons[0].cell)
            XCTAssertFalse(alert.window.isVisible)
        }
    }

    private func cell() -> AppGridCellView {
        let cell = AppGridCellView(frame: .zero)
        cell.bind(name: record.displayName, token: ItemBindingToken(catalogRevision: 1,
            pageIdentity: .init(revision: 1, pageIndex: 0), itemSlot: 0, appID: AnyHashable(record.id),
            reuseGeneration: 1, iconKey: nil, surfaceGeneration: 1))
        return cell
    }

    private func invoke(_ item: NSMenuItem) throws {
        let target = try XCTUnwrap(item.target as? NSObject), action = try XCTUnwrap(item.action)
        _ = target.perform(action, with: item)
    }

    func testContextActionCarriesLiveBindingValidationIntoConfirmation() throws {
        var hidden = false, busy = false
        let controller = AppContextMenuController(recordProvider: { [record] _ in record },
                                                  revisionProvider: { 1 }, hiddenProvider: { _ in hidden })
        controller.actionsAreBusyProvider = { busy }
        var validation: (() -> Bool)?
        controller.onMoveToTrash = { [record] received, validate in
            XCTAssertEqual(received.id, record.id); validation = validate
        }
        let cell = cell(), menu = try XCTUnwrap(controller.menu(for: cell))
        let item = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.moveToTrash" })
        try invoke(item)
        XCTAssertTrue(try XCTUnwrap(validation)())
        busy = true
        XCTAssertTrue(try XCTUnwrap(validation)(), "Its own busy phase must not revoke the pending confirmation")
        XCTAssertNil(controller.menu(for: cell))
        hidden = true
        XCTAssertFalse(try XCTUnwrap(validation)())
    }

    func testBusyAndReusedMenuCannotDispatchRemoval() throws {
        var busy = false, calls = 0
        let controller = AppContextMenuController(recordProvider: { [record] _ in record },
                                                  revisionProvider: { 1 }, hiddenProvider: { _ in false })
        controller.actionsAreBusyProvider = { busy }
        controller.onMoveToTrash = { _, _ in calls += 1 }
        let cell = cell(), menu = try XCTUnwrap(controller.menu(for: cell))
        let item = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.moveToTrash" })
        busy = true; try invoke(item); XCTAssertEqual(calls, 0)
        busy = false; cell.clearContent(); try invoke(item); XCTAssertEqual(calls, 0)
    }

    func testLibraryDetailsRemovalCarriesCurrentImmutableRequestAndLocalization() {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1000, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let strings = LocalizedStrings(language: .japanese)
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        window.contentView = view
        defer { view.reset(); window.contentView = nil; window.close() }
        var requests: [AppLibraryActionRequest] = []
        view.onMoveToTrash = { requests.append($0) }
        let entry = AppLibraryEntry(record: record, displayName: record.displayName, category: .utilities, manualCategory: nil)
        view.apply(snapshot: .init(revision: .init(1), entries: [entry], counts: [.utilities: 1]),
                   isLoading: false, catalogIsEmpty: false, actionGeneration: 7)
        view.resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        view.tableViewSelectionDidChange(.init(name: NSTableView.selectionDidChangeNotification, object: view.resultsTable))
        view.showDetails(nil); view.layoutSubtreeIfNeeded()
        XCTAssertFalse(view.removalButton?.isHidden ?? true)
        XCTAssertEqual(view.removalButton?.title, strings.removalText(.moveToTrash))
        view.setAppActionsBlocked(true)
        XCTAssertFalse(view.removalButton?.isEnabled ?? true)
        XCTAssertFalse(view.openButton?.isEnabled ?? true)
        XCTAssertFalse(view.backButton.isEnabled)
        view.setAppActionsBlocked(false)
        XCTAssertTrue(view.removalButton?.isEnabled ?? false)
        view.moveSelectionToTrash(nil)
        XCTAssertEqual(requests, [.init(record: record, catalogRevision: .init(1), generation: 7)])
        view.onMoveToTrash = nil
        XCTAssertTrue(view.removalButton?.isHidden ?? false)
    }
}
