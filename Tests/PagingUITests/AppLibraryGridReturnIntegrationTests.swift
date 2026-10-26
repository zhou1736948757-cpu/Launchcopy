import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

private actor LibraryReturnPreferencesStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

/// Only the production admission predicate sees visibility. This window is never
/// ordered or activated; this fixture does not certify native desktop behavior.
private final class LibraryReturnReportedVisibleWindow: NSWindow {
    override var isVisible: Bool { true }
}

@MainActor
final class AppLibraryGridReturnIntegrationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let app = AppDelegate(options: .default)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticLibraryReturn")], loader: RecordingIconLoader())
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35, reduceMotion: true)
        let keyboard = KeyboardFocusController(columns: 5)
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let window: NSWindow
        let search: AppSearchController

        init() {
            window = LibraryReturnReportedVisibleWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.addSubview(surface)
            surface.contentProvider = assembly.provider
            surface.renderer = assembly.renderer
            assembly.renderer.committedPageProvider = { [weak surface] in surface?.core.committedPage ?? 0 }
            assembly.searchPresentation.itemsPerPage = surface.itemsPerPage
            keyboard.install(on: surface, focusModel: AppGridFocusModel())
            search = AppSearchController(presentation: assembly.searchPresentation, keyboardController: keyboard, surface: surface)
            search.pendingCommitter = { [weak assembly] page in assembly?.commitPendingAtIdleBoundary(currentPage: page) }
            host.addSubview(search.field)
            app.window = window
            app.container = host
            app.surface = surface
            app.assembly = assembly
            app.keyboardController = keyboard
            app.search = search
            app.installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)
            app.installAppManagementPreferences(store: InMemoryAppManagementStore())
            app.installAppLibrary(in: host, store: LibraryReturnPreferencesStore())
        }

        func present(_ records: [AppRecord], revision: UInt64) {
            assembly.provider.receive(.init(revision: .init(revision), records: records))
            app.applyPendingAtIdleBoundary()
        }

        func teardown() {
            app.appLibraryOwner?.teardown()
            search.teardown()
            assembly.teardown()
            surface.teardown()
            window.contentView = nil
            window.close()
        }
    }

    private func record(_ index: Int, name: String? = nil) -> AppRecord {
        let bundle = "fixture.library.return.\(index)"
        let id = AppID.bundleIdentifier(bundle)
        return .init(id: id, displayName: name ?? "Match \(index)", bundleIdentifier: bundle,
                     canonicalURL: URL(fileURLWithPath: "/SyntheticLibraryReturn/\(index).app"),
                     iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }

    private func waitForResults(_ owner: AppLibraryOwnerController) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while owner.view?.resultsTable.numberOfRows == 0, ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertGreaterThan(owner.view?.resultsTable.numberOfRows ?? 0, 0)
    }

    func testActualBackRestoresGridQueryAndFieldEditorWithoutLibraryQueryLeak() async throws {
        let fixture = Fixture()
        defer { fixture.teardown() }
        fixture.present([record(0), record(1, name: "Unrelated")], revision: 1)
        fixture.search.activateSearch()
        fixture.search.field.stringValue = "Match"
        fixture.search.field.currentEditor()?.string = "Match"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        let owner = try XCTUnwrap(fixture.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        XCTAssertTrue(owner.enter(), "Use the actual AppDelegate capture and admission callbacks")
        await waitForResults(owner)
        let library = try XCTUnwrap(owner.view)
        library.searchField.stringValue = "Unrelated"
        library.searchField.currentEditor()?.string = "Unrelated"
        library.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: library.searchField))
        owner.back()
        XCTAssertFalse(owner.isOpen)
        XCTAssertEqual(fixture.search.field.stringValue, "Match")
        XCTAssertEqual(fixture.search.field.currentEditor()?.string, "Match")
        XCTAssertTrue(fixture.window.firstResponder === fixture.search.field.currentEditor())
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.id), [record(0).id])
        XCTAssertNil(fixture.keyboard.focusModel.current)
        XCTAssertFalse(fixture.surface.isHidden)
        XCTAssertEqual(library.query, "", "Detached Library is reset, not reused as grid history")
    }

    func testActualBackRelocatesSavedAnchorAgainstNewCatalogAndCommittedPage() async throws {
        let fixture = Fixture()
        defer { fixture.teardown() }
        let records = (0..<70).map { record($0) }
        fixture.present(records, revision: 1)
        XCTAssertTrue(fixture.surface.requestPage(1))
        XCTAssertEqual(fixture.surface.core.committedPage, 1)
        let anchor = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 1, slotIndex: 1,
                                         entryIdentity: .app(records[36].id))
        fixture.keyboard.setFocus(to: anchor)
        fixture.window.makeFirstResponder(fixture.keyboard)
        let owner = try XCTUnwrap(fixture.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        XCTAssertTrue(owner.enter())
        await waitForResults(owner)
        fixture.present([records[36], records[0]], revision: 2)
        owner.back()
        XCTAssertFalse(owner.isOpen)
        XCTAssertEqual(fixture.surface.core.committedPage, 0)
        XCTAssertEqual(fixture.keyboard.focusModel.current?.entryIdentity, anchor.entryIdentity)
        XCTAssertEqual(fixture.keyboard.focusModel.current?.catalogRevision, 2)
        XCTAssertEqual(fixture.keyboard.focusModel.current?.pageIndex, 0)
        XCTAssertEqual(fixture.keyboard.focusModel.current?.slotIndex, 0)
        XCTAssertTrue(fixture.window.firstResponder === fixture.keyboard)
        XCTAssertFalse(fixture.surface.isHidden)
    }

    func testIdentifierPolicyWaitsForLibraryEditorAndUpdatesItsIndependentQuery() async throws {
        let fixture = Fixture()
        defer { fixture.teardown() }
        fixture.present([record(0), record(1)], revision: 1)
        fixture.search.field.stringValue = "Match"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        let owner = try XCTUnwrap(fixture.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        XCTAssertTrue(owner.enter())
        await waitForResults(owner)
        let library = try XCTUnwrap(owner.view)
        library.searchField.stringValue = "fixture.library.return"
        library.searchField.currentEditor()?.string = "fixture.library.return"
        library.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: library.searchField))
        XCTAssertEqual(fixture.app.setSearchByBundleIdentifier(true), .saved)
        fixture.app.flushPendingIdentifierSearchIfReady()
        XCTAssertEqual(fixture.app.pendingIdentifierSearchEnabled, true, "Do not interrupt Library text entry")
        XCTAssertFalse(fixture.app.appManagementPreferences.searchByBundleIdentifier)
        fixture.window.makeFirstResponder(library.resultsTable)
        fixture.app.flushPendingIdentifierSearchIfReady()
        await waitForResults(owner)
        XCTAssertTrue(fixture.app.appManagementPreferences.searchByBundleIdentifier)
        XCTAssertEqual(library.query, "fixture.library.return")
        XCTAssertEqual(fixture.search.field.stringValue, "Match")
        XCTAssertEqual(library.resultsTable.numberOfRows, 2)
        XCTAssertTrue(owner.isOpen)
        owner.back()
        XCTAssertEqual(fixture.search.field.stringValue, "Match")
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.count, 2)
    }
}
