import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

private actor LibraryQuitTestStore: AppLibraryPersisting {
    private var value = AppLibraryPreferences.default
    init(enabled: Bool = false) { value.enabled = enabled }
    private var continuation: CheckedContinuation<AppLibrarySaveResult, Never>?
    private(set) var submissions = 0
    func load() -> AppLibraryLoadResult { .loaded(value) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) async -> AppLibrarySaveResult {
        submissions += 1
        let result = await withCheckedContinuation { continuation = $0 }
        if result == .saved { value = preferences }
        return result
    }
    func complete(_ result: AppLibrarySaveResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

/// Reports visibility to exercise the production admission predicate without
/// ever ordering a window, activating the application or producing a real sheet.
private final class LibraryQuitReportedVisibleWindow: NSWindow {
    override var isVisible: Bool { true }
}

@MainActor
private final class LibraryQuitLanguageStore: LanguagePreferencesPersisting {
    func load() -> LanguagePreferencesLoadResult { .loaded(.init(language: .english)) }
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult { .saved }
}

@MainActor
final class AppLibraryLaunchAndQuitTests: XCTestCase {
    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(condition())
    }

    func testIdentifierPolicyAutomaticallyRetriesWhenAcceptedLibraryWriteCompletes() async throws {
        for open in [false, true] {
            for result: AppLibrarySaveResult in [.saved, .failed] {
                let store = LibraryQuitTestStore(enabled: true)
                let app = AppDelegate(options: .default)
                let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
                app.installAppManagementPreferences(store: InMemoryAppManagementStore())
                app.installAppLibrary(in: host, store: store)
                let owner = try XCTUnwrap(app.appLibraryOwner)
                await owner.preferences.loadIfNeeded()
                if open {
                    owner.canTransition = { true }
                    owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
                    XCTAssertTrue(owner.enter())
                }
                XCTAssertTrue(owner.preferences.submit(.init(enabled: true)))
                XCTAssertEqual(app.setSearchByBundleIdentifier(true), .saved)
                // This marker is ordered after the policy's already-enqueued
                // attempt. It observes rejection; it does not wake or flush it.
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async { continuation.resume() }
                }
                XCTAssertEqual(owner.preferences.pendingCount, 1)
                XCTAssertFalse(app.appManagementPreferences.searchByBundleIdentifier)
                XCTAssertEqual(app.pendingIdentifierSearchEnabled, true)
                let deadline = ContinuousClock.now.advanced(by: .seconds(2))
                while await store.submissions == 0, ContinuousClock.now < deadline { await Task.yield() }
                let submissions = await store.submissions
                XCTAssertEqual(submissions, 1)
                await store.complete(result)
                await waitUntil { app.appManagementPreferences.searchByBundleIdentifier }
                XCTAssertNil(app.pendingIdentifierSearchEnabled)
                XCTAssertEqual(owner.isOpen, open)
                owner.teardown()
            }
        }
    }

    func testLibraryWriteCompletionAfterApplicationTeardownCannotApplyQueuedPolicy() async throws {
        let store = LibraryQuitTestStore(enabled: true)
        let app = AppDelegate(options: .default)
        app.installAppManagementPreferences(store: InMemoryAppManagementStore())
        let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
        app.installAppLibrary(in: host, store: store)
        let owner = try XCTUnwrap(app.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        XCTAssertTrue(owner.preferences.submit(.init(enabled: true)))
        XCTAssertEqual(app.setSearchByBundleIdentifier(true), .saved)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await store.submissions == 0, ContinuousClock.now < deadline { await Task.yield() }
        let submissions = await store.submissions
        XCTAssertEqual(submissions, 1)
        // Invoke only this unstarted fixture delegate's lifecycle; no NSApp quit,
        // UI, activation/global hook, process or real preference store is used.
        app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        XCTAssertNil(app.pendingIdentifierSearchEnabled)
        await store.complete(.saved)
        await waitUntil { owner.preferences.pendingCount == 0 }
        XCTAssertFalse(app.appManagementPreferences.searchByBundleIdentifier)
        XCTAssertNil(app.appLibraryOwner)
        XCTAssertEqual(app.setSearchByBundleIdentifier(false), .failed)
    }

    func testNonCellLaunchUsesDisplayedRevisionURLHiddenAndFileChecks() async throws {
        let factory = try FakeAppFactory()
        defer { factory.removeRoot() }
        _ = try factory.makeApps(names: ["Alpha"])
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        defer { assembly.teardown(); surface.teardown() }
        wireAssembly(assembly, to: surface)
        assembly.begin()
        await waitUntil { assembly.provider.servedSnapshot != nil }
        let catalog = try XCTUnwrap(assembly.provider.servedSnapshot)
        let record = try XCTUnwrap(catalog.records.first)
        let launcher = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: .zero, expectedURL: record.canonicalURL), .rejectedStaleRevision)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: catalog.revision,
            expectedURL: URL(fileURLWithPath: "/WrongSelection.app")), .rejectedMissingApp)
        XCTAssertTrue(launcher.opened.isEmpty)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: catalog.revision,
            expectedURL: record.canonicalURL), .launched)
        XCTAssertEqual(launcher.opened, [record.canonicalURL])
        try FileManager.default.removeItem(at: record.canonicalURL)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: catalog.revision,
            expectedURL: record.canonicalURL), .rejectedMissingFile)
        XCTAssertEqual(launcher.opened.count, 1)
    }

    func testLibraryOnlyAcceptedSaveMakesRealApplicationQuitPathWait() async throws {
        let store = LibraryQuitTestStore()
        let app = AppDelegate(options: .default)
        let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
        app.installAppLibrary(in: host, store: store)
        let owner = try XCTUnwrap(app.appLibraryOwner)
        defer { owner.teardown() }
        await owner.preferences.loadIfNeeded()
        XCTAssertTrue(owner.preferences.submit(.init(enabled: true)))
        var replies: [Bool] = []
        let reply = app.requestWorkspaceQuit(reply: { replies.append($0) }, chooseOnFailure: { _, _ in XCTFail("Successful save must not prompt") })
        XCTAssertEqual(reply, .terminateLater)
        XCTAssertTrue(replies.isEmpty)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await store.submissions == 0, ContinuousClock.now < deadline { await Task.yield() }
        await store.complete(.saved)
        await waitUntil { !replies.isEmpty }
        XCTAssertEqual(replies, [true])
        XCTAssertTrue(owner.preferences.committed.enabled)
    }

    func testLibraryOnlyFailureOffersCancelAndDoesNotAutoQuit() async throws {
        let store = LibraryQuitTestStore()
        let app = AppDelegate(options: .default)
        let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
        app.installAppLibrary(in: host, store: store)
        let owner = try XCTUnwrap(app.appLibraryOwner)
        defer { owner.teardown() }
        await owner.preferences.loadIfNeeded()
        owner.preferences.submit(.init(enabled: true))
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await store.submissions == 0, ContinuousClock.now < deadline { await Task.yield() }
        await store.complete(.failed)
        _ = await owner.preferences.drain()
        XCTAssertTrue(owner.preferences.requiresQuitProtection)
        var replies: [Bool] = [], choose: ((Bool) -> Void)?
        XCTAssertEqual(app.requestWorkspaceQuit(reply: { replies.append($0) }, chooseOnFailure: { result, decision in
            XCTAssertEqual(result, .failed)
            choose = decision
        }), .terminateLater)
        await waitUntil { choose != nil }
        XCTAssertTrue(replies.isEmpty)
        try XCTUnwrap(choose)(false)
        XCTAssertEqual(replies, [false])
    }

    func testLibraryEscapeUsesSeparateWindowRouteWithoutGridOrBlankExit() throws {
        _ = NSApplication.shared
        let window = QuitOnBlankClickWindow(contentRect: .init(x: 0, y: 0, width: 400, height: 300),
                                           styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        var libraryEscapes = 0, gridEscapes = 0, blankExits = 0
        window.libraryActiveProvider = { true }
        window.onLibraryEscape = { libraryEscapes += 1; return true }
        window.onEscapeDuringDrag = { gridEscapes += 1; return true }
        window.onBlankClick = { blankExits += 1 }
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        window.sendEvent(event)
        XCTAssertEqual(libraryEscapes, 1)
        XCTAssertEqual(gridEscapes, 0)
        XCTAssertEqual(blankExits, 0)
    }

    func testFailedLibraryWriteDuringQuitDoesNotPresentCompetingCategoryWarning() async throws {
        _ = NSApplication.shared
        let app = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticQuitCatalog")], loader: RecordingIconLoader())
        let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
        let window = LibraryQuitReportedVisibleWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.addSubview(surface)
        app.window = window; app.surface = surface; app.assembly = assembly
        surface.contentProvider = assembly.provider
        surface.renderer = assembly.renderer
        app.installLanguagePreferences(store: LibraryQuitLanguageStore(), preferredLanguages: { ["en"] }, center: NotificationCenter())
        let id = AppID.bundleIdentifier("fixture.quit.category")
        let record = AppRecord(id: id, displayName: "Fixture", bundleIdentifier: "fixture.quit.category",
            canonicalURL: URL(fileURLWithPath: "/SyntheticQuit.app"), iconIdentity: .from(appID: id), sourceRootPriority: 0)
        assembly.provider.receive(.init(revision: .init(1), records: [record]))
        _ = assembly.provider.applyPending(atCurrentPage: 0, itemsPerPage: 35)
        let store = LibraryQuitTestStore(enabled: true)
        app.installAppLibrary(in: host, store: store)
        let owner = try XCTUnwrap(app.appLibraryOwner)
        defer { owner.teardown(); app.teardownLanguagePresentation(); assembly.teardown(); surface.teardown() }
        await owner.preferences.loadIfNeeded()
        owner.canTransition = { true }
        owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        XCTAssertTrue(owner.enter())
        // Attach startup can still refresh the projection after preferences load.
        // Wait for the currently displayed generation, then capture its action;
        // a request captured before that refresh must correctly remain revoked.
        await waitUntil {
            owner.resolve(.init(record: record, catalogRevision: .init(1), generation: owner.actionGeneration)) != nil
        }
        let request = AppLibraryActionRequest(record: record, catalogRevision: .init(1), generation: owner.actionGeneration)
        var categoryWarnings = 0, quitChoices = 0, replies: [Bool] = [], decision: ((Bool) -> Void)?
        app.applicationSheetPresenter = { _, _, _ in categoryWarnings += 1 }
        owner.view?.onSetCategory?(request, .music)
        XCTAssertEqual(app.requestWorkspaceQuit(reply: { replies.append($0) }, chooseOnFailure: { result, choice in
            XCTAssertEqual(result, .failed)
            quitChoices += 1
            decision = choice
        }), .terminateLater)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await store.submissions == 0, ContinuousClock.now < deadline { await Task.yield() }
        await store.complete(.failed)
        await waitUntil { decision != nil }
        XCTAssertEqual(categoryWarnings, 0)
        XCTAssertEqual(quitChoices, 1)
        XCTAssertTrue(replies.isEmpty)
        try XCTUnwrap(decision)(false)
        XCTAssertEqual(replies, [false])
        XCTAssertTrue(owner.preferences.requiresQuitProtection)
    }
}
