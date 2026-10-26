import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

private actor LeadingAppLibraryStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

/// Visibility is an admission fixture only: this window is never ordered or activated.
private final class LeadingLibraryReportedWindow: NSWindow {
    override var isVisible: Bool { true }
}

@MainActor
final class LeadingLibraryAppIntegrationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let app = AppDelegate(options: .default)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticLeadingLibrary")], loader: RecordingIconLoader())
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35, reduceMotion: true)
        let keyboard = KeyboardFocusController(columns: 5)
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let window: NSWindow
        let search: AppSearchController
        init() {
            window = LeadingLibraryReportedWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.addSubview(surface)
            surface.contentProvider = assembly.provider
            surface.renderer = assembly.renderer
            assembly.renderer.committedPageProvider = { [weak surface] in surface?.core.committedPage ?? 0 }
            assembly.searchPresentation.itemsPerPage = 35
            keyboard.install(on: surface, focusModel: AppGridFocusModel())
            search = AppSearchController(presentation: assembly.searchPresentation, keyboardController: keyboard, surface: surface)
            search.pendingCommitter = { [weak assembly] page in assembly?.commitPendingAtIdleBoundary(currentPage: page) }
            host.addSubview(search.field)
            app.window = window; app.container = host; app.surface = surface
            app.assembly = assembly; app.keyboardController = keyboard; app.search = search
            app.installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)
            app.installAppManagementPreferences(store: InMemoryAppManagementStore())
            app.installAppLibrary(in: host, store: LeadingAppLibraryStore())
        }
        func present() {
            let records = (0..<70).map { index -> AppRecord in
                let id = AppID.bundleIdentifier("fixture.leading.\(index)")
                return .init(id: id, displayName: "App \(index)", bundleIdentifier: "fixture.leading.\(index)",
                    canonicalURL: URL(fileURLWithPath: "/SyntheticLeadingLibrary/\(index).app"),
                    iconIdentity: .from(appID: id), sourceRootPriority: 0)
            }
            assembly.provider.receive(.init(revision: .init(1), records: records))
            app.applyPendingAtIdleBoundary()
        }
        func teardown() {
            app.leadingLibraryNavigator?.teardown()
            app.appLibraryOwner?.teardown()
            search.teardown(); assembly.teardown(); surface.teardown()
            window.contentView = nil; window.close()
        }
    }
    func testPreviewAdmissionCannotExposeLibraryBeforeParentPositionsIt() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        f.search.field.frame = AppDelegate.searchFieldFrame(in: f.host.bounds, safeAreaTop: 0)
        owner.layout(searchFrame: f.search.field.frame)
        XCTAssertTrue(owner.enter(preview: true))
        let library = try XCTUnwrap(owner.view)
        XCTAssertTrue(library.isHidden, "The parent has not positioned/revealed this preview yet")
        XCTAssertTrue(library.searchField.isHidden)
        XCTAssertNil(library.searchField.currentEditor())
        owner.cancelPreview()
        XCTAssertFalse(owner.isOpen)
    }

    func testParentTransitionKeepsOneAlignedStationarySearchHeaderInBothDirections() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        f.search.field.frame = AppDelegate.searchFieldFrame(in: f.host.bounds, safeAreaTop: 0)
        owner.layout(searchFrame: f.search.field.frame)
        let nav = try XCTUnwrap(f.app.leadingLibraryNavigator)
        XCTAssertTrue(nav.beginTransition())
        let library = try XCTUnwrap(owner.view)
        XCTAssertFalse(library.isHidden)
        XCTAssertTrue(library.searchField.superview === f.host)
        XCTAssertEqual(library.searchField.frame, f.search.field.frame)
        XCTAssertTrue(library.searchField.isHidden)
        XCTAssertFalse(f.search.field.isHidden)
        for reduced in [false, true] {
            nav.render(0.65, reduced)
            XCTAssertEqual(f.search.field.layer?.affineTransform() ?? .identity, .identity)
            XCTAssertEqual(library.searchField.layer?.affineTransform() ?? .identity, .identity)
            XCTAssertFalse(f.search.field.isHidden)
            XCTAssertTrue(library.searchField.isHidden)
        }
        XCTAssertTrue(nav.pager.requestPage(0))
        XCTAssertFalse(library.searchField.isHidden)
        XCTAssertTrue(f.search.field.isHidden)
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(f.search.field.isHidden, "Return preview must not reveal a second header")
        for reduced in [false, true] {
            nav.render(0.35, reduced)
            XCTAssertEqual(library.searchField.layer?.affineTransform() ?? .identity, .identity)
            XCTAssertEqual(library.searchField.layer?.opacity ?? 1, 1)
            XCTAssertFalse(library.searchField.isHidden)
            XCTAssertTrue(f.search.field.isHidden)
        }
        nav.cancel()
        XCTAssertFalse(library.searchField.isHidden)
        XCTAssertTrue(f.search.field.isHidden)
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(nav.pager.requestPage(1))
        XCTAssertNil(library.searchField.window)
        XCTAssertFalse(f.search.field.isHidden)
        XCTAssertEqual(f.search.field.layer?.affineTransform() ?? .identity, .identity)
    }

    func testButtonEntryPreparesHiddenFirstPageAndActualBackRestoresPriorPage() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        XCTAssertTrue(f.surface.requestPage(1))
        XCTAssertEqual(f.surface.core.committedPage, 1)
        XCTAssertTrue(owner.enter())
        XCTAssertEqual(f.app.leadingLibraryNavigator?.location, .library)
        XCTAssertTrue(f.surface.isHidden)
        XCTAssertEqual(f.surface.core.committedPage, 0, "Prepared under committed Library, not an app-prefix migration")
        owner.back()
        XCTAssertFalse(f.surface.isHidden)
        XCTAssertEqual(f.surface.core.committedPage, 1)
        XCTAssertEqual(f.surface.core.pageCount, 2)
    }
    func testActualParentCommitThenSwipeReturnKeepsAppNumberingAndRestoresVisibility() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        let nav = try XCTUnwrap(f.app.leadingLibraryNavigator)
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(owner.isPreviewing)
        XCTAssertFalse(f.surface.isHidden)
        XCTAssertFalse(f.app.languagePresentationIsReady)
        XCTAssertFalse(f.app.requestPageFromDots(1))
        XCTAssertTrue(nav.pager.requestPage(0)) // Reduce Motion commits synchronously through production owner.
        XCTAssertTrue(owner.isOpen)
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertTrue(f.surface.isHidden)
        XCTAssertTrue(nav.beginTransition())
        XCTAssertFalse(f.surface.isHidden, "Retained canonical grid is visible only as a transition preview")
        XCTAssertTrue(nav.pager.requestPage(1))
        XCTAssertFalse(owner.isOpen)
        XCTAssertFalse(f.surface.isHidden)
        XCTAssertEqual(f.surface.core.committedPage, 0)
        XCTAssertEqual(f.surface.core.pageCount, 2)
        XCTAssertEqual(f.assembly.provider.servedPageCount, 2)
        XCTAssertNil(f.keyboard.focusModel.current)
    }
    func testNonfirstPageCannotEnterViaSwipeAndResizeCancelsPreviewWithoutChangingPage() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        let nav = try XCTUnwrap(f.app.leadingLibraryNavigator)
        XCTAssertTrue(f.surface.requestPage(1))
        XCTAssertFalse(nav.beginTransition())
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(f.surface.requestPage(0))
        XCTAssertTrue(nav.beginTransition())
        f.app.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: f.window))
        XCTAssertFalse(owner.isOpen)
        XCTAssertFalse(nav.isTransitioning)
        XCTAssertFalse(nav.pager.needsFrames)
        XCTAssertEqual(f.surface.core.committedPage, 0)
        XCTAssertFalse(f.surface.isHidden)
    }
    func testWindowHookCanBeInstalledAfterNavigatorAndDoesNotRequireEarlyWindowIdentity() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        let window = QuitOnBlankClickWindow(contentRect: f.host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        XCTAssertNil(window.onLeadingLibraryEvent)
        f.app.installLeadingLibraryWindowInput(on: window)
        XCTAssertNotNil(window.onLeadingLibraryEvent)
        XCTAssertFalse(owner.isOpen)
    }
    func testMainPageHasNoRedundantLibraryEntryControl() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        XCTAssertNil(owner.entryButton)
        XCTAssertFalse(f.host.subviews.contains { $0.identifier?.rawValue == "library.entry" })
        XCTAssertTrue(f.app.leadingLibraryNavigator?.beginTransition() == true)
    }

    func testSwipeReturnDoesNotRebindUnchangedEmptyGridQuery() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        let nav = try XCTUnwrap(f.app.leadingLibraryNavigator)
        let generation = f.assembly.searchPresentation.latestGeneration
        var reloads = 0
        let original = f.assembly.searchPresentation.onSearchResultCommitted
        f.assembly.searchPresentation.onSearchResultCommitted = { reloads += 1; original?() }
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(nav.pager.requestPage(0))
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(nav.pager.requestPage(1))
        XCTAssertEqual(f.assembly.searchPresentation.latestGeneration, generation)
        XCTAssertEqual(reloads, 0, "Returning to the retained query must not recreate visible cells")
        XCTAssertFalse(f.surface.isHidden)
    }

    func testSameNonemptyLibraryReturnQueryRetainsSearchGeneration() {
        let f = Fixture(); defer { f.teardown() }; f.present()
        f.search.restoreAfterLibrary(query: "App 6", focusSearch: false)
        let generation = f.assembly.searchPresentation.latestGeneration
        let ids = f.assembly.provider.presentationRecords.map(\.id)
        f.search.restoreAfterLibrary(query: "App 6", focusSearch: false)
        XCTAssertEqual(f.assembly.searchPresentation.latestGeneration, generation)
        XCTAssertEqual(f.assembly.provider.presentationRecords.map(\.id), ids)
        f.search.restoreAfterLibrary(query: "App 1", focusSearch: false)
        XCTAssertNotEqual(f.assembly.searchPresentation.latestGeneration, generation)
        XCTAssertNotEqual(f.assembly.provider.presentationRecords.map(\.id), ids)
    }

    func testUnchangedReturnStillAdmitsPendingCatalogCommit() {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let records = f.assembly.provider.servedSnapshot!.records
        f.assembly.searchPresentation.receive(.init(revision: .init(2), records: records))
        f.search.restoreAfterLibrary(query: "", focusSearch: false)
        XCTAssertEqual(f.assembly.provider.servedSnapshot?.revision, .init(2))
        XCTAssertFalse(f.surface.isTearingDown)
    }

    func testParentLifecycleMutationsDisableImplicitAnimations() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        let nav = try XCTUnwrap(f.app.leadingLibraryNavigator)
        var visibilityChanges = 0
        var resets = 0
        let originalVisibility = nav.setGridPreviewVisible
        nav.setGridPreviewVisible = { visible in
            XCTAssertTrue(CATransaction.disableActions())
            visibilityChanges += 1
            originalVisibility(visible)
        }
        let originalReset = nav.resetPresentation
        nav.resetPresentation = {
            XCTAssertTrue(CATransaction.disableActions())
            resets += 1
            originalReset()
        }
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(nav.pager.requestPage(0))
        XCTAssertTrue(nav.beginTransition())
        nav.cancel()
        XCTAssertTrue(owner.isOpen)
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(nav.pager.requestPage(1))
        XCTAssertFalse(owner.isOpen)
        XCTAssertGreaterThanOrEqual(visibilityChanges, 6)
        XCTAssertGreaterThanOrEqual(resets, 3)
    }

    func testMenuEntryRemainsAvailableWithoutGridButtonAndHonorsOwnership() async throws {
        let f = Fixture(); defer { f.teardown() }; f.present()
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        let item = NSMenuItem(title: "App Library", action: #selector(AppDelegate.showAppLibraryFromMenu(_:)), keyEquivalent: "")
        XCTAssertTrue(f.app.validateMenuItem(item))
        f.app.showAppLibraryFromMenu(nil)
        XCTAssertTrue(owner.isOpen)
        XCTAssertFalse(f.app.validateMenuItem(item))
        owner.back()
        XCTAssertTrue(f.app.validateMenuItem(item))
        let nav = try XCTUnwrap(f.app.leadingLibraryNavigator)
        XCTAssertTrue(nav.beginTransition())
        XCTAssertFalse(f.app.validateMenuItem(item))
    }

}
