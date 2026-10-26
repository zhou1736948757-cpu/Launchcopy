import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

private actor CapacityIntegrationStore: MainGridCapacityPersisting {
    var capacity: MainGridCapacity = .default
    var failing = false
    func load() -> MainGridCapacityLoadResult { .loaded(capacity) }
    func save(_ capacity: MainGridCapacity, recoveringCorruptPayload: Bool) -> MainGridCapacitySaveResult {
        if failing { return .failed }
        self.capacity = capacity
        return .saved
    }
    func setFailure(_ value: Bool) { failing = value }
}

private actor CapacityIntegrationLibraryStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

@MainActor
final class MainGridCapacityIntegrationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let owner: AppDelegate
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let keyboard: KeyboardFocusController
        let search: AppSearchController
        let host: ClickDeliveryProbeView
        let catalog: CatalogSnapshot

        init(itemCount: Int = 80) throws {
            owner = AppDelegate(options: try AppArguments.parse([]).get())
            assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/fixture")], loader: RecordingIconLoader())
            surface = makeSurface(pageCount: 1, itemsPerPage: 35, reduceMotion: true)
            host = ClickDeliveryProbeView(frame: CGRect(x: 0, y: 0, width: 1200, height: 1000))
            surface.frame = host.bounds
            host.addSubview(surface)
            surface.contentProvider = assembly.provider
            surface.renderer = assembly.renderer
            keyboard = KeyboardFocusController()
            keyboard.install(on: surface, focusModel: .init())
            search = AppSearchController(presentation: assembly.searchPresentation,
                                         keyboardController: keyboard, surface: surface)
            host.addSubview(search.field)
            owner.container = host
            owner.surface = surface
            owner.assembly = assembly
            owner.keyboardController = keyboard
            owner.search = search
            keyboard.gridInputIsAvailable = { [weak owner] in owner?.mainGridIsReadable ?? false }
            search.gridInputIsAvailable = { [weak owner] in owner?.mainGridIsReadable ?? false }
            owner.installCatalogPresentationCallbacks(assembly: assembly, surface: surface)
            let records = (0..<itemCount).map { index in
                let id = CatalogFixture.appID("capacity.fixture.\(index)")
                return CatalogFixture.record(id: id, displayName: "Fixture \(index)",
                    bundleID: "capacity.fixture.\(index)", url: CatalogFixture.tempURL(named: "Fixture\(index).app"),
                    icon: IconIdentity.from(appID: id), rootPriority: 0)
            }
            catalog = CatalogSnapshot(revision: CatalogRevision(1), records: records)
            assembly.provider.receive(catalog)
            owner.applyPendingAtIdleBoundary()
            surface.refreshPresentation()
            surface.layoutSubtreeIfNeeded()
        }

        func load(_ store: CapacityIntegrationStore) async {
            owner.installMainGridCapacityPreferences(store: store)
            await owner.mainGridCapacityCoordinator?.loadIfNeeded()
        }

        func apply(_ capacity: MainGridCapacity) async -> LayoutStoreFlushResult {
            guard let coordinator = owner.mainGridCapacityCoordinator else { return .failed }
            XCTAssertTrue(coordinator.submit(capacity))
            let receipt = await coordinator.drain()
            owner.flushPendingMainGridCapacityIfReady()
            return receipt
        }

        func teardown() {
            owner.closeFolder()
            owner.appLibraryOwner?.teardown()
            owner.dragCoordinator?.teardown()
            if DragUISessionCoordinator.shared === owner.dragCoordinator { DragUISessionCoordinator.shared = nil }
            owner.mainGridCapacityCoordinator?.invalidate()
            search.teardown()
            assembly.teardown()
            surface.teardown()
        }
    }

    func testCombinedAppearanceDefaultsAutoSubmitBothIndependentOwners() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        let large = MainGridCapacity(columns: 8, rows: 8)!
        _ = await f.apply(large)
        let appearanceStore = LiveCombinedAppearanceStore()
        f.owner.installAppearancePreferences(store: appearanceStore)
        let controller = ActivationSettingsWindowController(draft: .init(committed: .init()))
        defer { controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        f.owner.configureAppearanceSettings(controller.appearanceView)
        f.owner.configureMainGridCapacitySettings(controller.mainGridCapacityView)
        controller.appearanceView.defaultsClicked(nil)
        let result = await f.owner.mainGridCapacityCoordinator?.drain()
        if case .persisted? = result {} else { XCTFail("Expected grid default receipt") }
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(appearanceStore.value, .default)
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        XCTAssertEqual(f.owner.mainGridCapacity, .default)
        XCTAssertEqual(f.assembly.provider.itemsPerPage, 35)
        XCTAssertEqual(controller.mainGridCapacityView.draft, .default)
    }

    func testFailedLiveCapacityReceiptPreservesRequestedLayoutAndCanRetry() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let store = CapacityIntegrationStore()
        await f.load(store)
        await store.setFailure(true)
        let view = MainGridCapacitySettingsView(frame: .zero, strings: .init(language: .english))
        f.owner.configureMainGridCapacitySettings(view)
        view.columnsPopup.selectItem(withTag: 3)
        view.rowsPopup.selectItem(withTag: 3)
        view.controlChanged(nil)
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(f.owner.mainGridCapacity, MainGridCapacity(columns: 3, rows: 3))
        let failure = await f.owner.mainGridCapacityCoordinator?.drain()
        XCTAssertEqual(failure, .failed)
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(f.owner.mainGridCapacity, MainGridCapacity(columns: 3, rows: 3))
        XCTAssertTrue(f.owner.mainGridCapacityCoordinator?.requiresQuitProtection == true)
        await store.setFailure(false)
        view.applyClicked(nil)
        let receipt = await f.owner.mainGridCapacityCoordinator?.drain()
        if case .persisted? = receipt {} else { XCTFail("Expected retry receipt") }
        XCTAssertFalse(f.owner.mainGridCapacityCoordinator?.requiresQuitProtection == true)
    }

    func testAllCapacityCopiesAndStableSelectedAnchorCommitWithoutCatalogOrQueryChange() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        XCTAssertTrue(f.surface.requestPage(1))
        let entry = f.assembly.provider.presentationEntries[50].identity
        f.keyboard.setFocus(to: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 1,
                                                   slotIndex: 15, entryIdentity: entry))
        let entries = f.assembly.provider.presentationEntries.map(\.identity)
        let queryGeneration = f.assembly.searchPresentation.latestGeneration
        let capacity = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3))
        let receipt = await f.apply(capacity)
        XCTAssertEqual(receipt, .persisted(writeGeneration: 1))
        XCTAssertEqual(f.owner.mainGridCapacity, capacity)
        XCTAssertEqual(f.surface.itemsPerPage, 9)
        XCTAssertEqual(f.assembly.provider.itemsPerPage, 9)
        XCTAssertEqual(f.assembly.refreshController.itemsPerPage, 9)
        XCTAssertEqual(f.assembly.searchPresentation.itemsPerPage, 9)
        XCTAssertEqual(f.assembly.renderer.gridCapacity, capacity)
        XCTAssertEqual(f.surface.core.pageCount, 9)
        XCTAssertEqual(f.surface.core.committedPage, 5)
        XCTAssertEqual(f.keyboard.focusModel.current?.entryIdentity, entry)
        XCTAssertEqual(f.keyboard.focusModel.current?.slotIndex, 5)
        XCTAssertEqual(f.assembly.provider.servedRevision, 1)
        XCTAssertEqual(f.assembly.provider.presentationEntries.map(\.identity), entries)
        XCTAssertEqual(f.assembly.searchPresentation.latestGeneration, queryGeneration)
    }

    func testDeferredFocusAndPageLeadingAnchorRemainDeferred() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        XCTAssertTrue(f.surface.requestPage(1))
        XCTAssertNil(f.keyboard.focusModel.current)
        let receipt = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8)))
        XCTAssertEqual(receipt, .persisted(writeGeneration: 1))
        XCTAssertEqual(f.surface.core.committedPage, 0, "Old page-leading item35 belongs to the new page0")
        XCTAssertNil(f.keyboard.focusModel.current, "Configuration must not create a selection")
    }

    func testActiveSameCountFilteredAndEmptyQueriesKeepTheirGenerationAndCanonicalCatalog() async throws {
        for query in ["Fixture", "Fixture 1", "fixture-no-match"] {
            let f = try Fixture(); defer { f.teardown() }
            await f.load(CapacityIntegrationStore())
            f.search.field.stringValue = query
            f.assembly.searchPresentation.updateQuery(.init(raw: query))
            f.owner.applyPendingAtIdleBoundary()
            let generation = f.assembly.searchPresentation.latestGeneration
            let entries = f.assembly.provider.presentationEntries.map(\.identity)
            let catalogIDs = f.assembly.provider.servedSnapshot?.records.map(\.id)
            _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
            XCTAssertEqual(f.search.field.stringValue, query)
            XCTAssertEqual(f.assembly.searchPresentation.currentQuery?.raw, query)
            XCTAssertEqual(f.assembly.searchPresentation.latestGeneration, generation)
            XCTAssertEqual(f.assembly.provider.presentationEntries.map(\.identity), entries)
            XCTAssertEqual(f.assembly.provider.servedSnapshot?.records.map(\.id), catalogIDs)
            XCTAssertEqual(f.surface.core.pageCount, (entries.count + 8) / 9)
            XCTAssertNil(f.keyboard.focusModel.current)
        }
    }

    func testInvisibleOldSelectionDoesNotStealVisiblePageAnchorOrResurrectFocus() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        let entry = f.assembly.provider.presentationEntries[0].identity
        f.keyboard.setFocus(to: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0,
                                                   slotIndex: 0, entryIdentity: entry))
        XCTAssertTrue(f.surface.requestPage(1))
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertEqual(f.surface.core.committedPage, 3, "Visible old-page anchor is item35, not hidden item0")
        XCTAssertNil(f.keyboard.focusModel.current)
    }

    func testLatestAcceptedCapacityWaitsForReadinessInsteadOfChangingBindings() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        f.owner.mainGridCapacityReadinessCheck = { false }
        let small = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3))
        let large = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        _ = await f.apply(small)
        _ = await f.apply(large)
        XCTAssertEqual(f.owner.mainGridCapacity, .default)
        XCTAssertEqual(f.surface.itemsPerPage, 35)
        XCTAssertEqual(f.owner.pendingMainGridCapacity, large)
        f.owner.mainGridCapacityReadinessCheck = nil
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(f.owner.mainGridCapacity, large)
        XCTAssertNil(f.owner.pendingMainGridCapacity)
    }

    func testActualGestureDefersEvenWhenAdditionalTestCheckAllowsReadiness() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        f.owner.mainGridCapacityReadinessCheck = { true }
        gestureBegan(f.surface, at: 0)
        gestureChanged(f.surface, deltaX: 100, at: 0.01)
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertEqual(f.surface.itemsPerPage, 35)
        XCTAssertNotNil(f.owner.pendingMainGridCapacity)
        f.surface.cancel()
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(f.surface.itemsPerPage, 9)
    }

    func testSmallViewportMasksGridButCorrectiveCapacityCanStillApply() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8)))
        let entries = f.assembly.provider.presentationEntries.map(\.identity)
        f.surface.frame.size = CGSize(width: 700, height: 500)
        f.owner.refreshMainGridReadability()
        XCTAssertFalse(f.owner.mainGridIsReadable)
        XCTAssertTrue(f.surface.isHidden)
        XCTAssertEqual(f.surface.itemsPerPage, 64)
        XCTAssertFalse(f.owner.requestPageFromDots(1))
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertTrue(f.owner.mainGridIsReadable)
        XCTAssertFalse(f.surface.isHidden)
        XCTAssertEqual(f.surface.itemsPerPage, 9)
        XCTAssertEqual(f.assembly.provider.presentationEntries.map(\.identity), entries)
    }

    func testSameProductDifferentShapeReconfiguresAndInvalidatesBindings() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 8)))
        let first = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0))
        let oldToken = first.cell(at: 0)?.bindingToken
        let oldEpoch = f.owner.mainGridLayoutEpoch
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 4, rows: 6)))
        XCTAssertEqual(f.surface.itemsPerPage, 24)
        XCTAssertEqual(f.assembly.renderer.gridCapacity.columns, 4)
        XCTAssertGreaterThan(f.owner.mainGridLayoutEpoch, oldEpoch)
        XCTAssertNotEqual(first.cell(at: 0)?.bindingToken, oldToken)
    }

    func testCapacityOnlyFailureProtectsQuitAndRetryPermitsNormalQuit() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let store = CapacityIntegrationStore()
        await f.load(store)
        await store.setFailure(true)
        let capacity = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3))
        let failure = await f.apply(capacity)
        XCTAssertEqual(failure, .failed)
        let cancelled = expectation(description: "Default cancel retains failed capacity draft")
        let result = f.owner.requestWorkspaceQuit(reply: { approved in
            XCTAssertFalse(approved); cancelled.fulfill()
        }, chooseOnFailure: { result, finish in XCTAssertEqual(result, .failed); finish(false) })
        XCTAssertEqual(result, .terminateLater)
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertFalse(f.owner.isWorkspaceQuitPending)
        await store.setFailure(false)
        _ = await f.apply(capacity)
        let permitted = f.owner.requestWorkspaceQuit(reply: { _ in XCTFail("No asynchronous decision expected") },
            chooseOnFailure: { _, _ in XCTFail("No failed accepted owner remains") })
        XCTAssertEqual(permitted, .terminateNow)
    }

    func testOwnerReplacementCannotAbandonAcceptedFailedWrite() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let store = CapacityIntegrationStore()
        await f.load(store)
        await store.setFailure(true)
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        let original = f.owner.mainGridCapacityCoordinator
        f.owner.installMainGridCapacityPreferences(store: CapacityIntegrationStore())
        XCTAssertTrue(f.owner.mainGridCapacityCoordinator === original)
        XCTAssertTrue(original?.requiresQuitProtection == true)
    }

    func testKeyboardUsesNewColumnsAndDoesNotNavigateWhenGridIsProtected() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        let right = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 124))
        let down = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 125))
        f.keyboard.keyDown(with: right)
        XCTAssertEqual(f.keyboard.focusModel.current?.slotIndex, 0)
        f.keyboard.keyDown(with: down)
        XCTAssertEqual(f.keyboard.focusModel.current?.slotIndex, 3)
        let selected = f.keyboard.focusModel.current
        f.surface.frame.size = CGSize(width: 100, height: 100)
        f.owner.refreshMainGridReadability()
        f.keyboard.keyDown(with: right)
        XCTAssertTrue(f.keyboard.performKeyEquivalent(with: down))
        XCTAssertEqual(f.keyboard.focusModel.current, selected)
    }

    func testOpenFolderDefersCapacityWithoutChangingInnerLayout() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        f.owner.installFolderWiring(assembly: f.assembly, surface: f.surface, keyboard: f.keyboard,
            launch: AppLaunchController(surface: f.surface, assembly: f.assembly, session: nil))
        let folder = FolderEntry(id: FolderID(), title: "Fixture Folder",
                                 members: Array(f.catalog.records.prefix(35).map(\.id)))
        f.assembly.provider.receiveFolderSnapshot(.init(generation: FolderGeneration(1), entries: [folder]))
        f.owner.applyPendingAtIdleBoundary()
        f.owner.openFolder(folderID: folder.id)
        XCTAssertTrue(f.owner.folderOpenState?.isOpen == true)
        let membersPerPage = f.owner.folderOpenState?.membersPerPage
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertEqual(f.surface.itemsPerPage, 35)
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, membersPerPage)
        f.owner.closeFolder()
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(f.surface.itemsPerPage, 9)
        XCTAssertFalse(f.owner.folderOpenState?.isOpen == true)
    }

    func testOptionalLibraryDefersCapacityUntilBackWithoutClosingIt() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        f.owner.installAppLibrary(in: f.host, store: CapacityIntegrationLibraryStore())
        let library = try XCTUnwrap(f.owner.appLibraryOwner)
        await library.preferences.loadIfNeeded()
        // The fixture never orders an OS window; supply only the existing
        // ephemeral capture seam, not a bypass of capacity/Library readiness.
        library.captureGrid = {
            AppLibraryGridReturnContext(query: "", page: 0, selection: nil, searchWasFocused: false)
        }
        XCTAssertTrue(library.enter())
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertTrue(library.isOpen)
        XCTAssertEqual(f.surface.itemsPerPage, 35)
        library.back()
        f.owner.flushPendingMainGridCapacityIfReady()
        XCTAssertFalse(library.isOpen)
        XCTAssertEqual(f.surface.itemsPerPage, 9)
        XCTAssertFalse(f.surface.isHidden)
    }

    func testMaximumCapacityLiveSlotEnvelopeAndTransactionRequestCensus() async throws {
        let f = try Fixture(itemCount: 640); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        XCTAssertTrue(f.surface.requestPage(8))
        let requestsBefore = f.assembly.iconPipeline.stats.requests
        let started = ContinuousClock.now
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8)))
        let elapsed = started.duration(to: .now)
        let pages = (0..<f.surface.core.pageCount).compactMap { f.assembly.renderer.pageView(forPage: $0) }
        let slots = pages.reduce(0) { $0 + $1.cellCount }
        let requestDelta = f.assembly.iconPipeline.stats.requests - requestsBefore
        XCTAssertEqual(f.surface.core.committedPage, 4)
        XCTAssertEqual(f.surface.core.pageCount, 10)
        XCTAssertEqual(pages.count, 7)
        XCTAssertEqual(slots, 448)
        XCTAssertTrue(pages.allSatisfy { $0.cellCount == 64 && $0.gridCapacity.itemsPerPage == 64 })
        XCTAssertGreaterThan(requestDelta, 0)
        // Counts and synthetic timing only; not a whole-process RSS/queue bound,
        // one-pass request promise or matched physical-frame performance gate.
        print("main-grid-capacity-census: hosts=\(pages.count) slots=\(slots) icon-requests-delta=\(requestDelta) transaction=\(elapsed)")
    }

    func testProtectionDoesNotCancelAnimatedCapacityAnchorOrLoseSelection() async throws {
        for selecting in [false, true] {
            let f = try Fixture(); defer { f.teardown() }
            await f.load(CapacityIntegrationStore())
            f.surface.frame.size = CGSize(width: 700, height: 550)
            f.owner.refreshMainGridReadability()
            XCTAssertTrue(f.owner.mainGridIsReadable)
            XCTAssertTrue(f.surface.requestPage(1))
            let selected = f.assembly.provider.presentationEntries[50].identity
            if selecting {
                f.keyboard.setFocus(to: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 1,
                                                           slotIndex: 15, entryIdentity: selected))
            }
            f.surface.setReduceMotion(false)
            _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8)))
            XCTAssertFalse(f.owner.mainGridIsReadable)
            settleFrames(f.surface)
            XCTAssertEqual(f.surface.core.committedPage, 0)
            XCTAssertEqual(f.keyboard.focusModel.current?.entryIdentity, selecting ? selected : nil)
            f.surface.frame.size = CGSize(width: 1200, height: 1000)
            f.owner.refreshMainGridReadability()
            XCTAssertTrue(f.owner.mainGridIsReadable)
            XCTAssertEqual(f.surface.core.committedPage, 0)
            XCTAssertEqual(f.keyboard.focusModel.current?.entryIdentity, selecting ? selected : nil)
        }
    }

    func testReadableFolderMenuRemainsLiveWhileRetainedProtectedOuterMenuRejects() async throws {
        let f = try Fixture(); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        f.owner.installFolderWiring(assembly: f.assembly, surface: f.surface, keyboard: f.keyboard,
            launch: AppLaunchController(surface: f.surface, assembly: f.assembly, session: nil))
        let folder = FolderEntry(id: FolderID(), title: "Fixture Folder",
                                 members: Array(f.catalog.records.prefix(35).map(\.id)))
        f.assembly.provider.receiveFolderSnapshot(.init(generation: FolderGeneration(1), entries: [folder]))
        f.owner.applyPendingAtIdleBoundary()
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8)))
        let outer = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 1))
        let outerMenu = try XCTUnwrap(f.assembly.renderer.appContextMenuProvider?(outer))
        var reveals = 0
        f.owner.actionFileExists = { _ in true }
        f.owner.fileRevealRequester = { _ in reveals += 1 }
        f.owner.openFolder(folderID: folder.id)
        f.host.frame.size = CGSize(width: 700, height: 550)
        f.surface.frame = f.host.bounds
        f.owner.folderOverlay?.frame = f.host.bounds
        f.owner.windowDidResize(Notification(name: NSWindow.didResizeNotification))
        XCTAssertFalse(f.owner.mainGridIsReadable)
        XCTAssertTrue(f.owner.folderOpenState?.isOpen == true)
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let member = try XCTUnwrap(overlay.memberCell(at: 0))
        let memberMenu = try XCTUnwrap(overlay.appContextMenuProvider?(member))
        let revealOuter = try XCTUnwrap(outerMenu.items.firstIndex { $0.identifier?.rawValue == "management.reveal" })
        let revealMember = try XCTUnwrap(memberMenu.items.firstIndex { $0.identifier?.rawValue == "management.reveal" })
        outerMenu.performActionForItem(at: revealOuter)
        XCTAssertEqual(reveals, 0)
        memberMenu.performActionForItem(at: revealMember)
        XCTAssertEqual(reveals, 1)
        f.owner.closeFolder()
        memberMenu.performActionForItem(at: revealMember)
        XCTAssertEqual(reveals, 1, "A retained folder menu loses its presentation ownership on close")
    }

    func testAttachedOffPageMenuRejectsWhileCurrentAndReturnedPageMenusWork() throws {
        for animated in [false, true] {
            let f = try Fixture(); defer { f.teardown() }
            f.owner.installAppContextMenu(assembly: f.assembly)
            let oldCell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
            let token = oldCell.bindingToken
            let oldMenu = try XCTUnwrap(f.assembly.renderer.appContextMenuProvider?(oldCell))
            let index = try XCTUnwrap(oldMenu.items.firstIndex { $0.identifier?.rawValue == "management.reveal" })
            var reveals = 0
            f.owner.actionFileExists = { _ in true }
            f.owner.fileRevealRequester = { _ in reveals += 1 }
            oldMenu.performActionForItem(at: index)
            XCTAssertEqual(reveals, 1)
            f.surface.setReduceMotion(!animated)
            XCTAssertTrue(f.surface.requestPage(1))
            settleFrames(f.surface)
            XCTAssertTrue(oldCell.isDescendant(of: f.surface))
            XCTAssertEqual(oldCell.bindingToken, token)
            oldMenu.performActionForItem(at: index)
            XCTAssertEqual(reveals, 1, "Attached prewarm cells are not current presentation origins")
            let current = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 1)?.cell(at: 0))
            let currentMenu = try XCTUnwrap(f.assembly.renderer.appContextMenuProvider?(current))
            currentMenu.performActionForItem(at: index)
            XCTAssertEqual(reveals, 2)
            XCTAssertTrue(f.surface.requestPage(0))
            settleFrames(f.surface)
            oldMenu.performActionForItem(at: index)
            XCTAssertEqual(reveals, 3, "Returning to the same unchanged valid origin is allowed")
        }
    }

    func testAttachedOffPageOrganizationMenuCannotMutateWorkspace() throws {
        let f = try Fixture(); defer { f.teardown() }
        let folder = FolderEntry(id: FolderID(), title: "Fixture Folder",
                                 members: Array(f.catalog.records.prefix(2).map(\.id)))
        f.assembly.provider.receiveFolderSnapshot(.init(generation: FolderGeneration(1), entries: [folder]))
        f.owner.applyPendingAtIdleBoundary()
        f.owner.installAppContextMenu(assembly: f.assembly)
        let cell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 1))
        let menu = try XCTUnwrap(f.assembly.renderer.appContextMenuProvider?(cell))
        let organization = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.organization" }?.submenu)
        let action = try XCTUnwrap(organization.items.firstIndex { $0.identifier?.rawValue == "folderAssignment.moveToFolder" })
        let before = f.owner.currentPersistentLayout()
        XCTAssertTrue(f.surface.requestPage(1))
        organization.performActionForItem(at: action)
        XCTAssertEqual(f.owner.currentPersistentLayout(), before)
        XCTAssertFalse(f.owner.workspaceNeedsSave)
    }

    func testShrinkingToOnePageNormalizesIdleVisualOffsetAndRealViewOrigin() async throws {
        let f = try Fixture(itemCount: 46); defer { f.teardown() }
        await f.load(CapacityIntegrationStore())
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertTrue(f.surface.requestPage(1))
        f.surface.setReduceMotion(false)
        _ = await f.apply(try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8)))
        XCTAssertEqual(f.surface.core.pageCount, 1)
        XCTAssertEqual(f.surface.core.committedPage, 0)
        XCTAssertEqual(f.surface.presentedOffset, 0, accuracy: 0.000001)
        let page = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0))
        let frame = page.convert(page.bounds, to: f.surface)
        XCTAssertEqual(frame.minX, 0, accuracy: 0.000001)
        XCTAssertEqual(frame.width, f.surface.bounds.width, accuracy: 0.000001)
    }
}

@MainActor
private final class LiveCombinedAppearanceStore: AppearancePreferencesPersisting {
    var value = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 37,
        preferredIconSide: 64, appLabelFontSize: 16)
    func load() -> AppearancePreferencesLoadResult { .loaded(value) }
    func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult {
        value = preferences
        return .saved
    }
}
