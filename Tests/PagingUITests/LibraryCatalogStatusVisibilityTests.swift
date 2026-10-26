import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

private actor StatusVisibilityLibraryStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

@MainActor
private final class StatusVisibilityLanguageStore: LanguagePreferencesPersisting {
    private(set) var value = LanguagePreferences(language: .english)
    func load() -> LanguagePreferencesLoadResult { .loaded(value) }
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult {
        value = preferences
        return .saved
    }
}

/// Admission visibility only; never ordered or activated. Not native GUI evidence.
private final class StatusVisibilityReportedWindow: NSWindow {
    override var isVisible: Bool { true }
}

@MainActor
final class LibraryCatalogStatusVisibilityTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let app = AppDelegate(options: .default)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticStatusVisibility")], loader: RecordingIconLoader())
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35, reduceMotion: true)
        let keyboard = KeyboardFocusController(columns: 5)
        let root = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let window: NSWindow
        let search: AppSearchController
        init() {
            window = StatusVisibilityReportedWindow(contentRect: root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = root
            root.addSubview(surface)
            surface.contentProvider = assembly.provider
            surface.renderer = assembly.renderer
            assembly.renderer.committedPageProvider = { [weak surface] in surface?.core.committedPage ?? 0 }
            assembly.searchPresentation.itemsPerPage = surface.itemsPerPage
            keyboard.install(on: surface, focusModel: AppGridFocusModel())
            search = AppSearchController(presentation: assembly.searchPresentation, keyboardController: keyboard, surface: surface)
            search.pendingCommitter = { [weak assembly] page in assembly?.commitPendingAtIdleBoundary(currentPage: page) }
            root.addSubview(search.field)
            app.window = window; app.container = root; app.surface = surface
            app.assembly = assembly; app.keyboardController = keyboard; app.search = search
            app.installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)
            app.installAppManagementPreferences(store: InMemoryAppManagementStore())
            app.installCatalogStatus(in: root)
            app.installAppLibrary(in: root, store: StatusVisibilityLibraryStore())
        }
        func present(_ records: [AppRecord]) {
            assembly.provider.receive(.init(revision: .init(1), records: records))
            app.applyPendingAtIdleBoundary()
        }
        func teardown() {
            app.appLibraryOwner?.teardown()
            app.teardownCatalogStatus()
            search.teardown(); assembly.teardown(); surface.teardown()
            window.contentView = nil; window.close()
        }
    }

    private func record() -> AppRecord {
        let id = AppID.bundleIdentifier("fixture.status.visibility")
        return .init(id: id, displayName: "Fixture", bundleIdentifier: "fixture.status.visibility",
                     canonicalURL: URL(fileURLWithPath: "/SyntheticStatusVisibility/Fixture.app"),
                     iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }
    private func drain() async {
        for _ in 0..<8 { await drainDeferredPresentationTurns() }
    }
    private func loadedOwner(_ f: Fixture) async throws -> AppLibraryOwnerController {
        let owner = try XCTUnwrap(f.app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        await drain()
        return owner
    }

    func testActualBackKeepsReadyHiddenAcrossEqualStateAndRepeatedEntry() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.present([record()])
        let owner = try await loadedOwner(f)
        let status = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertEqual(status.state, .ready); XCTAssertTrue(status.isHidden)
        for _ in 0..<3 {
            XCTAssertTrue(owner.enter())
            await drain()
            XCTAssertTrue(status.isHidden)
            owner.back()
            XCTAssertFalse(owner.isOpen)
            XCTAssertTrue(status.isHidden, "Back must not show a renderer-hidden Ready badge")
            f.app.scheduleCatalogStatusRefresh()
            await drain()
            XCTAssertEqual(status.state, .ready)
            XCTAssertTrue(status.isHidden, "An equal-state update does not rerender; visibility must already be correct")
            XCTAssertFalse(status.isAccessibilityElement())
        }
    }

    func testQueuedRendererUpdatesCannotLeakVisualOrAXStatusIntoLibrary() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.present([record()])
        let owner = try await loadedOwner(f)
        let status = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertTrue(owner.enter()); await drain()
        // Exercise the renderer/mode composition seam, not refresh-data-source results.
        for state in [AppGridUIState.loading, .refreshing, .partialFailure, .empty, .noResults, .ready] {
            status.update(state: state)
            await drain()
            XCTAssertEqual(status.state, state)
            XCTAssertTrue(status.isHidden, "Mode mask must survive the queued renderer for \(state)")
            XCTAssertFalse(status.isAccessibilityElement())
        }
    }

    func testActualBackRestoresLegitimateLoadingEmptyAndNoResults() async throws {
        for expected in [AppGridUIState.loading, .empty, .noResults] {
            let f = Fixture(); defer { f.teardown() }
            if expected == .empty { f.present([]) }
            if expected == .noResults {
                f.present([record()])
                f.search.activateSearch()
                f.search.field.stringValue = "Missing fixture"
                f.search.field.currentEditor()?.string = "Missing fixture"
                f.search.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: f.search.field))
            }
            let owner = try await loadedOwner(f)
            let status = try XCTUnwrap(f.app.catalogStatusView)
            XCTAssertEqual(status.state, expected)
            XCTAssertFalse(status.isHidden)
            XCTAssertTrue(owner.enter()); await drain()
            XCTAssertTrue(status.isHidden)
            owner.back(); await drain()
            XCTAssertEqual(status.state, expected)
            XCTAssertFalse(status.isHidden)
            XCTAssertTrue(status.isAccessibilityElement())
        }
    }

    func testPendingSemanticChangeCannotExposePreviouslyRenderedReadyText() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.present([record()])
        let owner = try await loadedOwner(f)
        let status = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertTrue(owner.enter()); await drain()
        status.update(state: .partialFailure)
        owner.back()
        XCTAssertTrue(status.isHidden, "Pending error must not temporarily expose the old Ready text")
        await drain()
        // Later status resolution may replace this injected renderer state;
        // the immediate assertion above protects only the pre-render boundary.
    }

    func testStatusReplacementAndLateOldCompletionDoNotChangeNewMask() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.present([record()])
        let owner = try await loadedOwner(f)
        let old = try XCTUnwrap(f.app.catalogStatusView)
        let oldCompletion = old.onPresentationApplied
        XCTAssertTrue(owner.enter()); await drain()
        f.app.installCatalogStatus(in: f.root)
        let current = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertFalse(old === current)
        await drain()
        current.update(state: .empty); await drain()
        XCTAssertTrue(current.isHidden)
        oldCompletion?()
        XCTAssertTrue(current.isHidden)
        let completion = current.onPresentationApplied
        f.app.teardownCatalogStatus()
        completion?(); old.update(state: .noResults); await drain()
        XCTAssertNil(f.app.catalogStatusView)
        XCTAssertNil(current.superview)
        XCTAssertTrue(current.isHidden)
    }

    func testBackRestoresCommittedBusyAndErrorRendererVisibilityBeforeNewResolution() async throws {
        for state in [AppGridUIState.refreshing, .partialFailure] {
            let f = Fixture(); defer { f.teardown() }
            f.present([record()])
            let owner = try await loadedOwner(f)
            let status = try XCTUnwrap(f.app.catalogStatusView)
            XCTAssertTrue(owner.enter()); await drain()
            // Renderer/mode seam only: the real provider still contains a ready
            // catalog and may resolve Ready on a subsequent application turn.
            status.update(state: state); await drain()
            XCTAssertTrue(status.isHidden)
            owner.back()
            XCTAssertEqual(status.state, state)
            XCTAssertFalse(status.isHidden, "Leaving Library must restore the committed non-ready render")
            XCTAssertTrue(status.isAccessibilityElement())
            await drain()
        }
    }

    func testOldHiddenCompletionCannotHideVisibleNonReadyReplacementAfterBack() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.present([record()])
        let owner = try await loadedOwner(f)
        let old = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertTrue(old.isHidden)
        let lateCompletion = try XCTUnwrap(old.onPresentationApplied)
        XCTAssertTrue(owner.enter()); await drain()
        f.app.installCatalogStatus(in: f.root)
        let current = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertFalse(current === old)
        await drain()
        current.update(state: .partialFailure); await drain()
        XCTAssertTrue(current.isHidden, "Library still masks the committed error render")
        owner.back()
        XCTAssertEqual(current.state, .partialFailure)
        XCTAssertFalse(current.isHidden)
        XCTAssertTrue(current.isAccessibilityElement())

        // No queue turn between Back and the late completion: the new non-ready
        // render is visible while the old torn-down Ready view remains hidden.
        lateCompletion()
        XCTAssertFalse(current.isHidden, "An obsolete hidden view must not overwrite the current latch")
        XCTAssertTrue(current.isAccessibilityElement(), "Old completion must not suppress current AX exposure")
        XCTAssertEqual(current.state, .partialFailure)
    }

    func testActualLanguageApplyUnderLibraryRetainsMaskAndRestoresLocalizedGridQuery() async throws {
        let f = Fixture(); defer { f.teardown() }
        let languageStore = StatusVisibilityLanguageStore()
        f.app.installLanguagePreferences(store: languageStore, preferredLanguages: { ["en"] },
                                          center: NotificationCenter())
        let settings = ActivationSettingsWindowController(draft: .init(committed: .init()),
                                                          strings: f.app.languageStrings)
        f.app.configureLanguageSettings(settings)
        defer {
            f.app.teardownLanguagePresentation()
            settings.hideSettings(); settings.window?.delegate = nil
            settings.window?.contentView = nil; settings.window?.close()
        }
        f.present([record()])
        let gridQuery = "missing grid fixture"
        f.search.activateSearch()
        f.search.field.stringValue = gridQuery
        f.search.field.currentEditor()?.string = gridQuery
        f.search.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: f.search.field))
        await drain()
        let owner = try await loadedOwner(f)
        let status = try XCTUnwrap(f.app.catalogStatusView)
        XCTAssertEqual(status.state, .noResults)
        XCTAssertFalse(status.isHidden)
        XCTAssertTrue(owner.enter()); await drain()
        let view = try XCTUnwrap(owner.view)
        view.searchField.stringValue = "independent library query"
        view.searchField.currentEditor()?.string = view.searchField.stringValue
        view.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: view.searchField))
        XCTAssertTrue(f.window.makeFirstResponder(nil))
        await drain()
        let libraryQuery = view.query
        XCTAssertEqual(libraryQuery, "independent library query")
        XCTAssertFalse(owner.hasPresentationOwnership)

        settings.languageView.languagePopup.selectItem(at: 3)
        settings.languageView.applyButton.performClick(nil)
        await drain()
        XCTAssertEqual(languageStore.value.language, .japanese)
        XCTAssertEqual(f.app.languageStrings?.language, .japanese)
        let strings = LocalizedStrings(language: .japanese)
        XCTAssertEqual(status.statusText, strings.catalogText(.noResults))
        XCTAssertTrue(status.isHidden)
        XCTAssertFalse(status.isAccessibilityElement())
        XCTAssertTrue(owner.isOpen)
        XCTAssertTrue(owner.view === view)
        XCTAssertEqual(view.query, libraryQuery)
        XCTAssertEqual(view.searchField.stringValue, libraryQuery)
        XCTAssertEqual(view.backButton.title, strings.libraryText(.back))

        owner.back(); await drain()
        XCTAssertFalse(owner.isOpen)
        XCTAssertEqual(f.search.field.stringValue, gridQuery)
        XCTAssertEqual(status.state, .noResults)
        XCTAssertEqual(status.statusText, strings.catalogText(.noResults))
        XCTAssertFalse(status.isHidden)
        XCTAssertTrue(status.isAccessibilityElement())
    }

}
