import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

/// Real AppKit owner/field/selector wiring in an unshown window, no machine scans.
@MainActor
final class FolderRenameAssemblyTests: XCTestCase {
    private actor Store: LayoutStore {
        nonisolated let storeDirectory = URL(fileURLWithPath: "/SyntheticRenameStore")
        let loadResult: LayoutStoreLoadResult
        private(set) var writes: [PersistentWorkspaceLayout] = []
        var outcome: LayoutStoreFlushResult = .nothingPending
        private var flushGate: CheckedContinuation<Void, Never>?
        private var holdsFlush = false
        private(set) var flushCalls = 0
        func holdFlush() { holdsFlush = true }
        func releaseFlush(_ result: LayoutStoreFlushResult) {
            outcome = result; holdsFlush = false; flushGate?.resume(); flushGate = nil
        }
        func setOutcome(_ result: LayoutStoreFlushResult) { outcome = result }
        init(_ result: LayoutStoreLoadResult) { loadResult = result }
        func load() async -> LayoutStoreLoadResult { loadResult }
        func enqueue(_ layout: PersistentWorkspaceLayout) async { writes.append(layout) }
        func flush() async -> LayoutStoreFlushResult {
            flushCalls += 1
            if holdsFlush { await withCheckedContinuation { flushGate = $0 } }
            return outcome
        }
        func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult { .failed }
        func currentState() async -> LayoutStoreState { .healthy }
        func lockMode() async -> LayoutStoreLockMode { .singleWriter }
        func staleRejectionCount() async -> UInt64 { 0 }
    }
    /// Explicit pending-acquisition model; never orders or activates an OS window.
    @MainActor
    private final class TitleFocusProbeWindow: NSWindow {
        var defersTitleFieldEditor = false
        var refusesNilResponder = false
        var recordsRequests = false
        private(set) var requestCount = 0
        private(set) weak var lastRequestedResponder: NSResponder?

        override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
            if responder == nil, refusesNilResponder { return false }
            if recordsRequests {
                requestCount += 1
                lastRequestedResponder = responder
            }
            if defersTitleFieldEditor, responder is FolderTitleEditor { return true }
            return super.makeFirstResponder(responder)
        }
    }

    @MainActor
    private final class Fixture {
        let owner: AppDelegate
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let host: NSView
        let window: NSWindow
        let search: AppSearchController?
        let store: Store
        let catalog: CatalogSnapshot
        let saved: PersistentWorkspaceLayout
        let first = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!)
        let second = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)
        init(protected: Bool = false, latent: Bool = false, withSearch: Bool = false) throws {
            catalog = .init(revision: CatalogRevision(7), records: ["Alpha", "Beta", "Gamma", "Delta"].map { name in
                let bundle = "fixture.rename.\(name.lowercased())", id = CatalogFixture.appID("fixture.rename.\(name.lowercased())")
                return CatalogFixture.record(id: id, displayName: name, bundleID: bundle,
                    url: URL(fileURLWithPath: "/SyntheticApps/\(name).app"), icon: .from(appID: id), rootPriority: 0)
            })
            let refs = catalog.records.map { PersistentAppReference.from(record: $0) }
            saved = .init(generation: LayoutGeneration(4), topLevelOrder: [.folder(first), .folder(second)],
                folders: [.init(id: first, title: "Fixture One", members: Array(refs.prefix(2)) + (latent ? [.bundleID("fixture.missing")] : [])),
                          .init(id: second, title: "Fixture Two", members: Array(refs.suffix(2)))])
            store = Store(protected ? .readOnlyProtection(.unknownFutureVersion(9)) : .loaded(saved, writeGeneration: 2))
            owner = AppDelegate(options: try AppArguments.parse([]).get())
            assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")], loader: RecordingIconLoader())
            surface = makeSurface(pageCount: 1, itemsPerPage: 35)
            host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
            window = withSearch
                ? TitleFocusProbeWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
                : NSWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            surface.frame = host.bounds; host.addSubview(surface)
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            owner.window = window; owner.container = host; owner.surface = surface; owner.assembly = assembly
            let keyboard = KeyboardFocusController(columns: 5)
            keyboard.install(on: surface, focusModel: AppGridFocusModel()); owner.keyboardController = keyboard
            if withSearch {
                let search = AppSearchController(
                    presentation: AppGridSearchPresentationController(provider: assembly.provider),
                    keyboardController: keyboard, surface: surface)
                self.search = search
                owner.search = search
                host.addSubview(search.field)
                search.install(in: window)
            } else { search = nil }
            owner.installFolderWiring(assembly: assembly, surface: surface, keyboard: keyboard,
                launch: AppLaunchController(surface: surface, assembly: assembly, session: nil))
            owner.installDragUI(surface: surface, assembly: assembly)
            assembly.provider.receive(catalog)
            _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            _ = assembly.provider.applyCommittedLayout(saved, atCurrentPage: 0, itemsPerPage: 35)
            surface.refreshPresentation(); surface.layoutSubtreeIfNeeded()
            owner.installLayoutStore(store)
        }
        func begin(_ id: FolderID? = nil) throws -> FolderTitleEditor {
            owner.openFolder(folderID: id ?? first)
            let overlay = try XCTUnwrap(owner.folderOverlay)
            overlay.layoutSubtreeIfNeeded()
            XCTAssertTrue(owner.canApplyFolderAssignment)
            XCTAssertTrue(overlay.window === window)
            XCTAssertTrue(overlay.titleEditButton.isEnabled)
            let productionRequest = try XCTUnwrap(overlay.onRequestTitleEdit)
            var requests = 0
            overlay.onRequestTitleEdit = { requests += 1; productionRequest() }
            overlay.titleEditButton.performClick(nil)
            XCTAssertEqual(requests, 1)
            let editor = try XCTUnwrap(owner.folderTitleEditor,
                "mount=\(overlay.titleEditorView != nil), outcome=\(owner.lastFolderRenameResult != nil), responder=\(window.firstResponder is FolderTitleEditor)")
            XCTAssertTrue(overlay.titleEditorView === editor)
            XCTAssertTrue(editor.superview === overlay.titleEditorHostView)
            XCTAssertTrue(editor.window === window)
            return editor
        }
        func type(_ text: String, in editor: FolderTitleEditor) {
            editor.stringValue = text
            editor.currentEditor()?.string = text
        }
        func teardown() {
            owner.closeFolder(); owner.dragCoordinator?.teardown()
            if DragUISessionCoordinator.shared === owner.dragCoordinator { DragUISessionCoordinator.shared = nil }
            search?.teardown()
            assembly.teardown(); surface.teardown(); window.contentView = nil
        }
    }
    private func ready(_ fixture: Fixture) async {
        for _ in 0..<1000 { if !fixture.owner.isRestoringLayout { return }; await Task.yield() }
        XCTFail("Restore did not finish")
    }
    private func waitWrites(_ fixture: Fixture, _ count: Int) async {
        for _ in 0..<1000 { if await fixture.store.writes.count == count { return }; await Task.yield() }
        XCTFail("Expected write count was not reached")
    }

    func testOutsideTitleClickRespectsNativeResponderRefusalWithoutSaving() async throws {
        let fixture = try Fixture(withSearch: true)
        defer { fixture.teardown() }
        await ready(fixture)
        let editor = try fixture.begin()
        fixture.type("Draft must remain", in: editor)
        let window = try XCTUnwrap(fixture.window as? TitleFocusProbeWindow)
        window.refusesNilResponder = true
        defer { window.refusesNilResponder = false }
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 2, y: 2),
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1))
        XCTAssertTrue(fixture.owner.handleFolderTitlePointerDown(event), "Refused outside click is still consumed")
        XCTAssertTrue(fixture.owner.folderTitleEditor === editor)
        XCTAssertFalse(fixture.owner.canApplyFolderAssignment)
        XCTAssertEqual(editor.currentEditor()?.string ?? editor.stringValue, "Draft must remain")
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testActualTitleButtonMountedFieldEnterCommitsExactlyOnceAndPreservesMembership() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let editor = try fixture.begin()
        fixture.type("  Renamed  ", in: editor)
        XCTAssertTrue(editor.control(editor, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:))))
        await waitWrites(fixture, 1)
        let result = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(result.folder(id: fixture.first)?.title, "Renamed")
        XCTAssertEqual(result.folder(id: fixture.first)?.members, fixture.saved.folders[0].members)
        XCTAssertEqual(result.topLevelOrder, fixture.saved.topLevelOrder)
        XCTAssertEqual(fixture.owner.folderOpenState?.openEntry?.title, "Renamed")
        XCTAssertNil(fixture.owner.folderTitleEditor); XCTAssertNil(fixture.owner.folderOverlay?.titleEditorView)
        editor.commit(); editor.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification))
        for _ in 0..<20 { await Task.yield() }
        let writes = await fixture.store.writes
        XCTAssertEqual(writes, [result])
    }

    func testPageDotActionCannotCommitMountedTitleOrChangeResponder() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        fixture.owner.pageNavigationLifecycleCheck = { true }
        fixture.owner.installPageDots(in: fixture.host)
        let editor = try fixture.begin(); fixture.type("Unaccepted draft", in: editor)
        let responder = fixture.window.firstResponder
        XCTAssertFalse(fixture.owner.requestPageFromDots(2))
        // Invoke a real target/action-capable dot, including stale enablement defense.
        let dots = try XCTUnwrap(fixture.owner.pageDotsView)
        dots.update(pageCount: 3, committedPage: 0, isEnabled: true)
        let button = try XCTUnwrap(dots.subviews.compactMap { $0 as? NSButton }.first { $0.tag == 2 })
        button.performClick(nil)
        XCTAssertTrue(fixture.owner.folderTitleEditor === editor)
        XCTAssertTrue(fixture.window.firstResponder === responder)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let writes = await fixture.store.writes; XCTAssertTrue(writes.isEmpty)
    }

    func testFieldEditorLiveTextRatherThanStaleSeedIsSaved() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let editor = try fixture.begin()
        let field = try XCTUnwrap(editor.currentEditor())
        field.string = "Live text"
        editor.commit()
        await waitWrites(fixture, 1)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title, "Live text")
    }

    func testFocusLossCommitsAndFreshSecondSessionCanCommit() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let old = try fixture.begin()
        fixture.type("First edit", in: old)
        old.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification))
        await waitWrites(fixture, 1)
        let fresh = try fixture.begin()
        XCTAssertFalse(old === fresh)
        fixture.type("Second edit", in: fresh); fresh.commit()
        await waitWrites(fixture, 2)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title, "Second edit")
    }

    func testEscapeCancelsWithoutWritesAndLateOldCallbackCannotRenameNewFolder() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let old = try fixture.begin(), oldCommit = try XCTUnwrap(fixture.owner.keyboardController?.onTitleCommit)
        fixture.type("Canceled", in: old)
        XCTAssertTrue(old.control(old, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        let fresh = try fixture.begin(fixture.second)
        oldCommit("Late callback"); old.commit(); old.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification))
        XCTAssertTrue(fixture.owner.folderTitleEditor === fresh)
        fixture.type("Accepted", in: fresh); fresh.commit(); await waitWrites(fixture, 1)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title, "Fixture One")
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.second)?.title, "Accepted")
    }

    func testCancelEndEditingDoesNotWriteAndFreshSessionCanCommit() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let old = try fixture.begin()
        fixture.type("Never persist canceled movement", in: old)
        old.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification,
            object: old, userInfo: [NSText.movementUserInfoKey: NSNumber(value: NSCancelTextMovement)]))
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        XCTAssertNil(fixture.owner.folderTitleEditor)
        XCTAssertNil(fixture.owner.folderOverlay?.titleEditorView)
        XCTAssertTrue(fixture.owner.canApplyFolderAssignment)
        let canceledWrites = await fixture.store.writes
        XCTAssertTrue(canceledWrites.isEmpty)

        let fresh = try fixture.begin(fixture.second)
        old.commit()
        old.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification, object: old))
        XCTAssertTrue(fixture.owner.folderTitleEditor === fresh)
        fixture.type("Accepted after cancellation", in: fresh)
        fresh.commit()
        await waitWrites(fixture, 1)
        let layout = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(layout.folder(id: fixture.first)?.title, "Fixture One")
        XCTAssertEqual(layout.folder(id: fixture.second)?.title, "Accepted after cancellation")
        XCTAssertEqual(layout.folder(id: fixture.first)?.members, fixture.saved.folders[0].members)
        let writes = await fixture.store.writes
        XCTAssertEqual(writes, [layout], "Only the later accepted edit reaches persistence")
    }

    func testCloseAndFolderSwitchCancelBeforeFocusLoss() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let first = try fixture.begin(); fixture.type("Never save", in: first)
        fixture.owner.closeFolder()
        first.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification))
        XCTAssertNil(fixture.owner.folderTitleEditor)
        let second = try fixture.begin(); fixture.type("Also canceled", in: second)
        fixture.owner.openFolder(folderID: fixture.second)
        second.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification))
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
    }

    func testSameAndBlankTitlesAreNoOpAndUnicodeLengthIsBounded() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        for value in ["Fixture One", "   "] {
            let editor = try fixture.begin(); fixture.type(value, in: editor); editor.commit()
            XCTAssertEqual(fixture.owner.lastFolderRenameResult, .noOp(fixture.saved))
        }
        let editor = try fixture.begin(); fixture.type(String(repeating: "👨‍👩‍👧‍👦", count: 70), in: editor); editor.commit()
        await waitWrites(fixture, 1)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title.count, 64)
    }

    func testReadonlyAndBootstrapNeverMountEditor() async throws {
        let fixture = try Fixture(protected: true); defer { fixture.teardown() }
        fixture.owner.openFolder(folderID: fixture.first)
        fixture.owner.folderOverlay?.titleEditButton.performClick(nil)
        XCTAssertNil(fixture.owner.folderTitleEditor)
        await ready(fixture)
        fixture.owner.folderOverlay?.titleEditButton.performClick(nil)
        XCTAssertNil(fixture.owner.folderTitleEditor)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testChangedCatalogOrLayoutRejectsCapturedRename() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let editor = try fixture.begin(); fixture.type("Stale", in: editor)
        fixture.assembly.provider.receive(.init(revision: CatalogRevision(8), records: fixture.catalog.records))
        _ = fixture.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        editor.commit()
        XCTAssertEqual(fixture.owner.lastFolderRenameResult, .rejected(.invalidTarget))
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title, "Fixture One")
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testResizeScreenAndOverlayTeardownCancelMountedSession() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let resized = try fixture.begin(); fixture.type("Resize", in: resized)
        fixture.owner.windowDidResize(.init(name: NSWindow.didResizeNotification, object: fixture.window)); resized.commit()
        XCTAssertNil(fixture.owner.folderTitleEditor)
        let moved = try fixture.begin(); fixture.type("Screen", in: moved)
        fixture.owner.windowDidChangeScreen(.init(name: NSWindow.didChangeScreenNotification, object: fixture.window)); moved.commit()
        XCTAssertNil(fixture.owner.folderTitleEditor)
        let torn = try fixture.begin(); fixture.type("Teardown", in: torn)
        fixture.owner.folderOverlay?.teardown(); torn.commit()
        XCTAssertNil(fixture.owner.folderTitleEditor)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testActualRenameImmediatelyDrainsAndReloadsFromRealJournalWithoutProcessRestartClaim() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-rename-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LayoutStoreActor(storeDirectory: directory)
        fixture.owner.installLayoutStore(store); await ready(fixture)
        let editor = try fixture.begin(); fixture.type("Durable rename", in: editor); editor.commit()
        // No preliminary wait: drain must include the just-accepted enqueue task.
        let result = await fixture.owner.drainAcceptedWorkspaceWrites()
        switch result {
        case .persisted, .nothingPending: break
        default: XCTFail("Expected completed private journal flush")
        }
        let fresh = LayoutStoreActor(storeDirectory: directory)
        guard case .loaded(let restored, _) = await fresh.load() else { return XCTFail("Expected valid journal") }
        XCTAssertEqual(restored.folder(id: fixture.first)?.title, "Durable rename")
        XCTAssertEqual(restored.folder(id: fixture.first)?.members, fixture.saved.folders[0].members)
        XCTAssertEqual(restored.topLevelOrder, fixture.saved.topLevelOrder)
    }
    func testKeyRestorationKeepsPendingMountedTitleOwnerWithoutFieldEditor() async throws {
        let fixture = try Fixture(withSearch: true); defer { fixture.teardown() }; await ready(fixture)
        let window = try XCTUnwrap(fixture.window as? TitleFocusProbeWindow)
        window.defersTitleFieldEditor = true
        let editor = try fixture.begin()
        XCTAssertNil(editor.currentEditor(), "The probe models admission before native editor acquisition")
        let provider = try XCTUnwrap(fixture.search?.modeFirstResponderProvider)
        XCTAssertTrue(provider() === editor, "A live mounted title owns the requested mode before acquiring a field editor")
        window.recordsRequests = true
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        XCTAssertTrue(window.lastRequestedResponder === editor)
        XCTAssertTrue(fixture.owner.folderTitleEditor === editor)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testKeyRestorationLeavesOwnedNativeTitleEditorAndSelectionUntouched() async throws {
        let fixture = try Fixture(withSearch: true); defer { fixture.teardown() }; await ready(fixture)
        let editor = try fixture.begin()
        fixture.type("Unaccepted native title draft", in: editor)
        let field = try XCTUnwrap(editor.currentEditor())
        let selection = NSRange(location: 2, length: 4)
        field.selectedRange = selection
        XCTAssertTrue(fixture.window.firstResponder === field)
        let window = try XCTUnwrap(fixture.window as? TitleFocusProbeWindow)
        window.recordsRequests = true
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        XCTAssertEqual(window.requestCount, 0, "The control's owned field editor already satisfies mode restoration")
        XCTAssertTrue(fixture.owner.folderTitleEditor === editor)
        XCTAssertTrue(editor.currentEditor() === field)
        XCTAssertTrue(window.firstResponder === field)
        XCTAssertEqual(field.string, "Unaccepted native title draft")
        XCTAssertEqual(field.selectedRange, selection)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testKeyRestorationRejectsDetachedTitleEvenWhenMovedIntoSameWindow() async throws {
        let fixture = try Fixture(withSearch: true); defer { fixture.teardown() }; await ready(fixture)
        let window = try XCTUnwrap(fixture.window as? TitleFocusProbeWindow)
        window.defersTitleFieldEditor = true
        let editor = try fixture.begin()
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.unmountTitleEditor()
        fixture.host.addSubview(editor)
        XCTAssertTrue(editor.window === window)
        XCTAssertNil(overlay.titleEditorView)
        let provider = try XCTUnwrap(fixture.search?.modeFirstResponderProvider)
        XCTAssertFalse(provider() === editor, "A stale same-window view is not the mounted title owner")
        window.recordsRequests = true
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        XCTAssertTrue(window.lastRequestedResponder === fixture.owner.keyboardController)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testNativeResponderTransferCommitsLiveTextWithoutManualDelegateNotification() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let editor = try fixture.begin()
        fixture.type("Native transfer", in: editor)
        let next = NSTextField(frame: NSRect(x: 1, y: 1, width: 100, height: 24))
        fixture.host.addSubview(next)
        XCTAssertTrue(fixture.window.makeFirstResponder(next))
        await waitWrites(fixture, 1)
        XCTAssertNil(fixture.owner.folderTitleEditor)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title, "Native transfer")
    }

    func testActualRenamePreservesHiddenAndMissingMemberReferences() async throws {
        let fixture = try Fixture(latent: true); defer { fixture.teardown() }; await ready(fixture)
        let hidden = fixture.catalog.records[0]
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingHidden(true, for: hidden))
        fixture.owner.applyAppManagementPreferences(preferences)
        let editor = try fixture.begin(); fixture.type("Preserved", in: editor); editor.commit()
        await waitWrites(fixture, 1)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.members,
                       fixture.saved.folders[0].members)
        XCTAssertTrue(fixture.owner.appManagementPreferences.isHidden(hidden))
    }

    func testStoreReplacementCancelsOldEditorBeforeLateCommit() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let old = try fixture.begin(); fixture.type("Old store", in: old)
        fixture.owner.installLayoutStore(Store(.firstLaunch))
        XCTAssertNil(fixture.owner.folderTitleEditor)
        XCTAssertFalse(fixture.owner.folderOverlay?.titleEditButton.isEnabled ?? true)
        old.commit()
        await ready(fixture)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testQuitImmediatelyAfterRenameWaitsForAcceptedWriteAndRepliesOnce() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        await fixture.store.holdFlush()
        let editor = try fixture.begin(); fixture.type("Quit durable", in: editor); editor.commit()
        var replies: [Bool] = [], prompts = 0
        let requested = fixture.owner.requestWorkspaceQuit(reply: { replies.append($0) },
            chooseOnFailure: { _, _ in prompts += 1 })
        XCTAssertEqual(requested, .terminateLater)
        XCTAssertTrue(fixture.owner.isWorkspaceQuitPending)
        XCTAssertFalse(fixture.owner.canCommitWorkspaceLayout)
        XCTAssertFalse(fixture.owner.folderOverlay?.titleEditButton.isEnabled ?? true)
        XCTAssertEqual(fixture.owner.requestWorkspaceQuit(reply: { _ in XCTFail("Duplicate reply") },
            chooseOnFailure: { _, _ in XCTFail("Duplicate dialog") }), .terminateLater)
        for _ in 0..<1000 { if await fixture.store.flushCalls > 0 { break }; await Task.yield() }
        XCTAssertTrue(replies.isEmpty)
        await fixture.store.releaseFlush(.persisted(writeGeneration: 3))
        for _ in 0..<1000 { if !replies.isEmpty { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(replies, [true]); XCTAssertEqual(prompts, 0)
        XCTAssertFalse(fixture.owner.workspaceNeedsSave)
        let writes = await fixture.store.writes
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.first?.folder(id: fixture.first)?.title, "Quit durable")
    }

    func testDelayedFailureShowsOneNoticeAndQuitCancelRestoresInputThenRetrySaves() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        await fixture.store.holdFlush()
        let editor = try fixture.begin(); fixture.type("Unsaved edit", in: editor); editor.commit()
        for _ in 0..<1000 { if await fixture.store.flushCalls > 0 { break }; await Task.yield() }
        XCTAssertNil(fixture.owner.workspaceSaveNotice)
        await fixture.store.releaseFlush(.failed)
        for _ in 0..<1000 { if fixture.owner.lastWorkspacePersistenceOutcome == .failed { break }; try? await Task.sleep(for: .milliseconds(1)) }
        let notice = try XCTUnwrap(fixture.owner.workspaceSaveNotice)
        XCTAssertFalse(notice.isHidden); XCTAssertTrue(fixture.owner.workspaceNeedsSave)
        fixture.owner.handleWorkspacePersistenceOutcome(.failed)
        XCTAssertTrue(notice === fixture.owner.workspaceSaveNotice)
        var replies: [Bool] = [], choose: ((Bool) -> Void)?
        XCTAssertEqual(fixture.owner.requestWorkspaceQuit(reply: { replies.append($0) },
            chooseOnFailure: { result, callback in XCTAssertEqual(result, .failed); choose = callback }), .terminateLater)
        for _ in 0..<1000 { if choose != nil { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(replies.isEmpty)
        try XCTUnwrap(choose)(false)
        XCTAssertEqual(replies, [false]); XCTAssertTrue(fixture.owner.canCommitWorkspaceLayout)
        XCTAssertTrue(fixture.owner.folderOverlay?.titleEditButton.isEnabled ?? false)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.title, "Unsaved edit")
        await fixture.store.setOutcome(.persisted(writeGeneration: 3))
        XCTAssertEqual(fixture.owner.requestWorkspaceQuit(reply: { replies.append($0) },
            chooseOnFailure: { _, _ in XCTFail("Recovery must not prompt") }), .terminateLater)
        for _ in 0..<1000 { if replies.count == 2 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(replies, [false, true]); XCTAssertTrue(notice.isHidden)
    }

    func testQuitTimeoutRequiresExplicitQuitAnywayAndCleanQuitNeedsNoBarrier() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        XCTAssertEqual(fixture.owner.requestWorkspaceQuit(reply: { _ in XCTFail() },
            chooseOnFailure: { _, _ in XCTFail() }), .terminateNow)
        await fixture.store.holdFlush()
        let editor = try fixture.begin(); fixture.type("Timeout", in: editor); editor.commit()
        var replies: [Bool] = [], choose: ((Bool) -> Void)?
        XCTAssertEqual(fixture.owner.requestWorkspaceQuit(enqueueWait: .seconds(1), flushWait: .milliseconds(10),
            reply: { replies.append($0) }, chooseOnFailure: { result, callback in
                XCTAssertEqual(result, .timedOut); choose = callback
            }), .terminateLater)
        for _ in 0..<1000 { if choose != nil { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(replies.isEmpty); XCTAssertTrue(fixture.owner.workspaceNeedsSave)
        try XCTUnwrap(choose)(true)
        XCTAssertEqual(replies, [true]); XCTAssertTrue(fixture.owner.workspaceNeedsSave)
        await fixture.store.releaseFlush(.failed)
    }

    func testActualStatusItemQuitCallbackDoesNotTerminateLauncherBeforeCancel() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        await fixture.store.setOutcome(.failed)
        let editor = try fixture.begin(); fixture.type("Menu quit", in: editor); editor.commit()
        let launcher = LauncherWindowController(reduceMotionProvider: { true })
        let originalState = launcher.coordinator.state
        let status = StatusItemController(visibilityProvider: { false }, targetScreenProvider: { ScreenID(index: 0) },
            onCommand: fixture.owner.statusItemCommandHandler(for: launcher))
        var choice: ((Bool) -> Void)?, replies: [Bool] = []
        status.terminateApp = {
            _ = fixture.owner.requestWorkspaceQuit(reply: { replies.append($0) },
                chooseOnFailure: { _, callback in choice = callback })
        }
        status.performQuit()
        for _ in 0..<1000 { if choice != nil { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(launcher.coordinator.state, originalState)
        XCTAssertFalse(launcher.isTornDown)
        try XCTUnwrap(choice)(false)
        XCTAssertEqual(replies, [false]); XCTAssertTrue(fixture.owner.canCommitWorkspaceLayout)
        XCTAssertEqual(launcher.coordinator.state, originalState)
        // Retry through the same actual menu action, not only delegate seam.
        await fixture.store.setOutcome(.persisted(writeGeneration: 4))
        status.performQuit()
        for _ in 0..<1000 { if replies.count == 2 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(replies, [false, true]); XCTAssertFalse(launcher.isTornDown)
    }

    func testQuitFailureDialogDefaultIsCancelWithoutShowingGUI() {
        let alert = AppDelegate.makeQuitSaveFailureAlert()
        XCTAssertEqual(alert.buttons.map(\.title), ["取消退出", "仍然退出"])
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
        XCTAssertTrue(alert.window.defaultButtonCell === alert.buttons[0].cell)
    }

    func testResidentHideAndSessionSuspendExplicitlyCancelPendingQuitAndLateChoices() async throws {
        for suspend in [false, true] {
            let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
            await fixture.store.setOutcome(.failed)
            let editor = try fixture.begin(); fixture.type("Pending decision", in: editor); editor.commit()
            var replies: [Bool] = [], choice: ((Bool) -> Void)?
            _ = fixture.owner.requestWorkspaceQuit(reply: { replies.append($0) },
                chooseOnFailure: { _, callback in choice = callback })
            for _ in 0..<1000 { if choice != nil { break }; try? await Task.sleep(for: .milliseconds(1)) }
            XCTAssertTrue(fixture.owner.isWorkspaceQuitPending)
            let launcher = LauncherWindowController(reduceMotionProvider: { true })
            launcher.onLauncherDidHide = fixture.owner.launcherDidHideHandler()
            let composition = ActivationComposition(launcher: launcher)
            composition.onPrepareHide = { fixture.owner.prepareTransientCancellationForHide() }
            if suspend { composition.handleSessionEvent(.willSleep) }
            else { _ = composition.handleBackgroundClick() }
            XCTAssertEqual(replies, [false]); XCTAssertFalse(fixture.owner.isWorkspaceQuitPending)
            XCTAssertTrue(fixture.owner.canCommitWorkspaceLayout)
            try XCTUnwrap(choice)(true)
            XCTAssertEqual(replies, [false], "Hide/sleep never implicitly approves Quit")
            await fixture.store.setOutcome(.persisted(writeGeneration: 4))
            _ = fixture.owner.requestWorkspaceQuit(reply: { replies.append($0) },
                chooseOnFailure: { _, _ in XCTFail("Saved retry must not prompt") })
            for _ in 0..<1000 { if replies.count == 2 { break }; try? await Task.sleep(for: .milliseconds(1)) }
            XCTAssertEqual(replies, [false, true])
            composition.teardownActivationServices()
        }
    }

    func testMaterialPolicyNotificationMapsFolderAndCancelsObsoleteDraftWithoutSave() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }; await ready(fixture)
        let high = LaunchcopyMaterialPolicy(reduceTransparency: true, increaseContrast: true, reduceMotion: false)
        fixture.owner.handleAccessibilityDisplayChange(wallpaperPolicy: high)
        let editor = try fixture.begin()
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        XCTAssertEqual(try XCTUnwrap(overlay.layer?.backgroundColor).alpha, 0)
        XCTAssertEqual(overlay.titleEditorHostView.layer?.backgroundColor?.alpha, 1)
        XCTAssertEqual(overlay.titleEditorHostView.layer?.borderWidth, 2)
        fixture.type("Unaccepted draft", in: editor)
        let normal = LaunchcopyMaterialPolicy(reduceTransparency: false, increaseContrast: false, reduceMotion: false)
        fixture.owner.handleAccessibilityDisplayChange(wallpaperPolicy: normal)
        XCTAssertEqual(try XCTUnwrap(overlay.layer?.backgroundColor).alpha, 0)
        XCTAssertEqual(overlay.titleEditorHostView.layer?.backgroundColor?.alpha, 0)
        let effect = try XCTUnwrap(overlay.titleEditorHostView.subviews.compactMap { $0 as? NSVisualEffectView }.first)
        XCTAssertFalse(effect.isHidden)
        XCTAssertEqual(effect.blendingMode, .withinWindow)
        XCTAssertEqual(overlay.titleEditorHostView.layer?.borderWidth, 1)
        editor.commit()
        XCTAssertNil(fixture.owner.folderTitleEditor)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        _ = await fixture.owner.drainAcceptedWorkspaceWrites()
        let writes = await fixture.store.writes
        XCTAssertTrue(writes.isEmpty)
        fixture.owner.closeFolder()
        fixture.owner.openFolder(folderID: fixture.first)
        XCTAssertEqual(fixture.owner.folderOverlay?.titleEditorHostView.layer?.borderWidth, 1)
    }

}
