import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class FolderAssignmentAssemblyTests: XCTestCase {
    private actor Store: LayoutStore {
        nonisolated let storeDirectory = URL(fileURLWithPath: "/SyntheticFolderStore")
        let result: LayoutStoreLoadResult
        private let suspendsLoad: Bool
        private var loadContinuation: CheckedContinuation<LayoutStoreLoadResult, Never>?
        private(set) var loadStarted = false
        private(set) var enqueued: [PersistentWorkspaceLayout] = []
        init(_ result: LayoutStoreLoadResult, suspendsLoad: Bool = false) {
            self.result = result; self.suspendsLoad = suspendsLoad
        }
        func load() async -> LayoutStoreLoadResult {
            loadStarted = true
            if !suspendsLoad { return result }
            return await withCheckedContinuation { loadContinuation = $0 }
        }
        func releaseLoad() { loadContinuation?.resume(returning: result); loadContinuation = nil }
        func enqueue(_ layout: PersistentWorkspaceLayout) async { enqueued.append(layout) }
        func flush() async -> LayoutStoreFlushResult { .nothingPending }
        func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult { .failed }
        func currentState() async -> LayoutStoreState {
            if case .readOnlyProtection(let reason) = result { return .readOnlyProtection(reason) }
            return .healthy
        }
        func lockMode() async -> LayoutStoreLockMode { .singleWriter }
        func staleRejectionCount() async -> UInt64 { 0 }
    }

    @MainActor
    private final class Fixture {
        let owner: AppDelegate
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let host: NSView
        let catalog: CatalogSnapshot
        let saved: PersistentWorkspaceLayout
        let first = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let second = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!)
        let store: Store

        init(protected: Bool = false, itemsPerPage: Int = 35,
             customLayout: PersistentWorkspaceLayout? = nil, suspendsLoad: Bool = false,
             appOptions: AppArguments.Options = .default) throws {
            catalog = CatalogSnapshot(revision: CatalogRevision(7), records: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"].map { name in
                let bundleID = "fixture.folderassignment.\(name.lowercased())"
                let id = CatalogFixture.appID(bundleID)
                return CatalogFixture.record(id: id, displayName: name, bundleID: bundleID,
                    url: URL(fileURLWithPath: "/SyntheticApps/\(name).app"), icon: .from(appID: id), rootPriority: 0)
            })
            let refs = catalog.records.map { PersistentAppReference.from(record: $0) }
            saved = customLayout ?? .init(generation: LayoutGeneration(4), topLevelOrder: [.folder(first), .app(refs[4]), .folder(second), .app(refs[5])],
                folders: [.init(id: first, title: "Fixture One", members: Array(refs.prefix(2))),
                          .init(id: second, title: "Fixture Two", members: Array(refs[2...3]))])
            store = Store(protected ? .readOnlyProtection(.unknownFutureVersion(9)) : .loaded(saved, writeGeneration: 3), suspendsLoad: suspendsLoad)
            owner = AppDelegate(options: appOptions)
            assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")], loader: RecordingIconLoader())
            surface = makeSurface(pageCount: 1, itemsPerPage: itemsPerPage)
            host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
            host.addSubview(surface); surface.frame = host.bounds
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            assembly.provider.itemsPerPage = itemsPerPage
            assembly.searchPresentation.itemsPerPage = itemsPerPage
            owner.assembly = assembly; owner.surface = surface; owner.container = host
            let keyboard = KeyboardFocusController(columns: 5)
            keyboard.install(on: surface, focusModel: AppGridFocusModel())
            owner.keyboardController = keyboard
            owner.installFolderWiring(assembly: assembly, surface: surface, keyboard: keyboard,
                launch: AppLaunchController(surface: surface, assembly: assembly, session: nil))
            owner.installDragUI(surface: surface, assembly: assembly)
            assembly.provider.receive(catalog)
            _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            _ = assembly.provider.applyCommittedLayout(saved, atCurrentPage: 0, itemsPerPage: itemsPerPage)
            surface.refreshPresentation(); surface.layoutSubtreeIfNeeded()
            owner.installAppContextMenu(assembly: assembly)
            owner.installLayoutStore(store)
        }

        func cell(_ index: Int) -> AppGridCellView {
            let record = catalog.records[index]
            let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 100, height: 88))
            cell.bind(name: record.displayName, token: .init(catalogRevision: 7,
                pageIdentity: .init(revision: 7, pageIndex: 0), itemSlot: 0, appID: AnyHashable(record.id),
                reuseGeneration: 1, iconKey: nil, surfaceGeneration: 1))
            // This transaction fixture supplies synthetic bindings, but must
            // still supply a real presentation origin for menu admission.
            surface.addSubview(cell)
            return cell
        }
        func submenu(_ cell: AppGridCellView) throws -> NSMenu {
            let menu = try XCTUnwrap(assembly.renderer.appContextMenuProvider?(cell))
            return try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.organization" }?.submenu)
        }
        func teardown() {
            owner.closeFolder(); owner.dragCoordinator?.teardown()
            if DragUISessionCoordinator.shared === owner.dragCoordinator { DragUISessionCoordinator.shared = nil }
            assembly.teardown(); surface.teardown()
        }
    }

    private func waitFor(_ condition: @escaping () -> Bool) async {
        for _ in 0..<1000 { if condition() { return }; await Task.yield() }
        XCTFail("Bounded owner operation did not finish")
    }
    private func waitForEnqueue(_ fixture: Fixture, count: Int) async {
        for _ in 0..<1000 { if await fixture.store.enqueued.count == count { return }; await Task.yield() }
        XCTFail("Expected enqueue count was not reached")
    }

    func testRealFolderDragReorderCommitsAndRetainsMemberImagesBeforeSuspension() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let initialWrites = await fixture.store.enqueued
        XCTAssertTrue(initialWrites.isEmpty)
        let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(before, fixture.saved)
        fixture.owner.openFolder(folderID: fixture.first)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let originalEntry = try XCTUnwrap(overlay.currentEntry)
        let folderGeneration = try XCTUnwrap(fixture.assembly.provider.servedFolderSnapshot?.generation)
        let mainGeneration = fixture.surface.surfaceGeneration
        let mainPage = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let mainPageGeneration = mainPage.surfaceGeneration
        let mainCells = try (0..<fixture.saved.topLevelOrder.count).map { try XCTUnwrap(mainPage.cell(at: $0)) }
        let mainTokens = try mainCells.map { try XCTUnwrap($0.bindingToken) }
        let cells = try (0..<2).map { try XCTUnwrap(overlay.memberCell(at: $0)) }
        let tokens = try cells.map { try XCTUnwrap($0.bindingToken) }
        let images = [NSColor.systemRed, NSColor.systemBlue].map { color in
            NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
                color.setFill()
                NSBezierPath(rect: rect).fill()
                return true
            }
        }
        XCTAssertEqual(originalEntry.members.count, 2)
        XCTAssertTrue(coordinator.visualHost === overlay)
        for index in cells.indices {
            XCTAssertEqual(tokens[index].appID as? AppID, originalEntry.members[index])
            XCTAssertEqual(tokens[index].surfaceGeneration, overlay.surfaceGeneration)
            XCTAssertEqual(tokens[index].catalogRevision, fixture.assembly.provider.servedRevision)
            XCTAssertNotNil(tokens[index].iconKey)
            XCTAssertTrue(cells[index].applyIconIfValid(images[index], token: tokens[index]))
        }
        let geometry = try XCTUnwrap(coordinator.geometryProvider(.folder(fixture.first)))
        XCTAssertEqual(geometry.itemFrames.count, 2)
        let target = try XCTUnwrap(geometry.itemFrames.last).frame
        let down = cells[0].convert(NSPoint(x: cells[0].bounds.midX, y: cells[0].bounds.midY), to: nil)
        // Stay inside the second member's right half: insertion after both members.
        let drop = overlay.convert(NSPoint(x: CGFloat(target.maxX - target.width / 8),
                                            y: CGFloat(target.minY + target.height / 2)), to: nil)
        let expectedMembers = Array(originalEntry.members.reversed())
        let expected = PersistentWorkspaceLayout(generation: LayoutGeneration(5),
            topLevelOrder: before.topLevelOrder, folders: before.folders.map { folder in
                folder.id == fixture.first
                    ? PersistentFolderRecord(id: folder.id, title: folder.title, members: Array(folder.members.reversed()))
                    : folder
            })

        coordinator.pointerDown(locationInWindow: down, sourceCell: cells[0], memberFolderID: fixture.first)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        XCTAssertEqual(coordinator.controller.activeTransaction?.scope, .folder(fixture.first))
        coordinator.pointerDragged(locationInWindow: drop)
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertEqual(coordinator.controller.lastIntent, .insertion(index: 2))
        XCTAssertTrue(coordinator.visuals.isPreviewVisible)
        XCTAssertTrue(coordinator.visuals.isInsertionIndicatorVisible)
        coordinator.pointerUp(locationInWindow: drop)

        // No suspension or callback delivery is allowed before these release assertions.
        XCTAssertEqual(coordinator.controller.lastOutcome, .committed(expected))
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), expected)
        XCTAssertEqual(coordinator.layoutProvider(), expected)
        XCTAssertEqual(fixture.assembly.provider.expectedLayout, expected)
        XCTAssertEqual(fixture.assembly.provider.servedRevision, fixture.catalog.revision.value)
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.generation, folderGeneration.incremented())
        XCTAssertEqual(fixture.surface.surfaceGeneration, mainGeneration,
                       "A member permutation must not reload the unchanged main surface")
        XCTAssertTrue(fixture.assembly.renderer.pageView(forPage: 0) === mainPage)
        XCTAssertEqual(mainPage.surfaceGeneration, mainPageGeneration)
        for index in mainCells.indices {
            XCTAssertTrue(mainPage.cell(at: index) === mainCells[index])
            XCTAssertEqual(mainCells[index].bindingToken, mainTokens[index])
        }
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.entry(for: fixture.first)?.members, expectedMembers)
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, fixture.first)
        XCTAssertEqual(fixture.owner.folderOpenState?.openEntry?.members, expectedMembers)
        XCTAssertTrue(fixture.owner.folderOverlay === overlay)
        XCTAssertTrue(overlay.superview === fixture.host)
        XCTAssertEqual(overlay.currentEntry?.id, originalEntry.id)
        XCTAssertEqual(overlay.currentEntry?.title, originalEntry.title)
        XCTAssertEqual(overlay.currentEntry?.members, expectedMembers)
        XCTAssertEqual(overlay.memberCellCount, 2)
        XCTAssertEqual(expected.appReferenceCount, before.appReferenceCount)
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertNil(coordinator.controller.activeTransaction)
        XCTAssertNil(coordinator.controller.edgeDwellDeadline)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
        XCTAssertFalse(coordinator.visuals.isInsertionIndicatorVisible)
        XCTAssertFalse(coordinator.visuals.isFolderHighlightVisible)
        XCTAssertFalse(coordinator.visuals.isCreateFolderIndicatorVisible)
        XCTAssertNil(coordinator.visuals.previewIconImage)
        XCTAssertEqual(coordinator.visuals.previewNameText, "")
        for index in cells.indices {
            let cell = try XCTUnwrap(overlay.memberCell(at: index))
            let token = try XCTUnwrap(cell.bindingToken)
            let oldIndex = 1 - index
            XCTAssertEqual(overlay.memberAppID(at: index), expectedMembers[index])
            XCTAssertEqual(token.appID, tokens[oldIndex].appID)
            XCTAssertEqual(token.itemSlot, index)
            XCTAssertEqual(token.catalogRevision, tokens[oldIndex].catalogRevision)
            XCTAssertEqual(token.pageIdentity, tokens[oldIndex].pageIdentity)
            XCTAssertEqual(token.reuseGeneration, tokens[oldIndex].reuseGeneration)
            XCTAssertEqual(token.iconKey, tokens[oldIndex].iconKey)
            XCTAssertEqual(token.surfaceGeneration, overlay.surfaceGeneration)
            XCTAssertGreaterThan(token.surfaceGeneration, tokens[oldIndex].surfaceGeneration)
            XCTAssertTrue(cell.iconView.image === images[oldIndex], "The known image must follow its member identity synchronously")
        }

        // Normal async icon results may replace the seeds after this first suspension.
        // Drain all accepted submissions before checking the complete, exactly-once batch.
        let drain = await fixture.owner.drainAcceptedWorkspaceWrites()
        XCTAssertEqual(drain, .nothingPending)
        let writes = await fixture.store.enqueued
        XCTAssertEqual(writes, [expected])

        // Retaining the hosts must not retain a drag owner that swallows the next click.
        let clickedCell = try XCTUnwrap(overlay.memberCell(at: 0))
        let clickPoint = clickedCell.convert(NSPoint(x: clickedCell.bounds.midX,
            y: clickedCell.bounds.midY), to: nil)
        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }
        coordinator.pointerDown(locationInWindow: clickPoint, sourceCell: clickedCell,
                                memberFolderID: fixture.first)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        coordinator.pointerUp(locationInWindow: clickPoint)
        XCTAssertEqual(clicks.count, 1)
        XCTAssertTrue(clicks.first === clickedCell)
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), expected)
    }

    func testMemberPermutationFallsBackForStaleEntryPageCountOrOwnerLayoutMismatch() async throws {
        for mismatch in ["openEntry", "pageCount", "ownerLayout"] {
            let fixture = try Fixture(); defer { fixture.teardown() }
            await waitFor { !fixture.owner.isRestoringLayout }
            fixture.owner.openFolder(folderID: fixture.first)
            let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
            let expected = PersistentWorkspaceLayout(generation: before.generation.incremented(),
                topLevelOrder: before.topLevelOrder, folders: before.folders.map { folder in
                    folder.id == fixture.first
                        ? PersistentFolderRecord(id: folder.id, title: folder.title,
                            members: Array(folder.members.reversed())) : folder
                })
            switch mismatch {
            case "openEntry":
                let entry = try XCTUnwrap(fixture.owner.folderOpenState?.openEntry)
                fixture.owner.folderOpenState?.updateOpenEntry(.init(id: entry.id,
                    title: "Stale title", members: entry.members))
            case "pageCount":
                fixture.surface.setPageCount(3)
            default:
                let providerOnly = PersistentWorkspaceLayout(generation: LayoutGeneration(777),
                    topLevelOrder: before.topLevelOrder, folders: before.folders)
                _ = fixture.assembly.provider.applyCommittedLayout(providerOnly, atCurrentPage: 0,
                    itemsPerPage: fixture.surface.itemsPerPage)
            }
            let mainGeneration = fixture.surface.surfaceGeneration
            XCTAssertTrue(fixture.owner.commitWorkspaceLayout(expected), mismatch)
            XCTAssertGreaterThan(fixture.surface.surfaceGeneration, mainGeneration, mismatch)
            XCTAssertEqual(fixture.surface.core.pageCount, fixture.assembly.provider.servedPageCount, mismatch)
            XCTAssertEqual(fixture.owner.folderOpenState?.openEntry?.members,
                Array(fixture.catalog.records.prefix(2).map(\.id).reversed()), mismatch)
            await assertDrainedSingleWrite(fixture, expected: expected)
        }
    }

    /// Uses the owner's installed commit callback and the real pointer transaction.
    /// Pending work is staged after drag admission, before the synchronous release.
    private func releaseMemberReorderRequiringFullRefresh(
        _ fixture: Fixture, stagePendingWork: () throws -> Void
    ) throws -> PersistentWorkspaceLayout {
        fixture.owner.openFolder(folderID: fixture.first)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let geometry = try XCTUnwrap(coordinator.geometryProvider(.folder(fixture.first)))
        let target = try XCTUnwrap(geometry.itemFrames.last).frame
        let down = source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        let drop = overlay.convert(NSPoint(x: CGFloat(target.maxX - target.width / 8),
                                           y: CGFloat(target.minY + target.height / 2)), to: nil)
        let expected = PersistentWorkspaceLayout(generation: before.generation.incremented(),
            topLevelOrder: before.topLevelOrder, folders: before.folders.map { folder in
                folder.id == fixture.first
                    ? PersistentFolderRecord(id: folder.id, title: folder.title, members: Array(folder.members.reversed()))
                    : folder
            })
        coordinator.pointerDown(locationInWindow: down, sourceCell: source, memberFolderID: fixture.first)
        coordinator.pointerDragged(locationInWindow: drop)
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertEqual(coordinator.controller.lastIntent, .insertion(index: 2))
        let generation = fixture.surface.surfaceGeneration
        let revision = fixture.assembly.provider.servedRevision
        let mainPage = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let pageGeneration = mainPage.surfaceGeneration
        try stagePendingWork()
        XCTAssertEqual(fixture.surface.surfaceGeneration, generation, "Staging alone must not refresh the main grid")
        XCTAssertEqual(mainPage.surfaceGeneration, pageGeneration)
        coordinator.pointerUp(locationInWindow: drop)
        XCTAssertGreaterThan(mainPage.surfaceGeneration, pageGeneration,
                             "Unrelated pending work or search must rerender the main page")
        // A new catalog uses refreshPresentation; only same-revision reloads bump
        // the surface token. Both paths must render instead of retaining bindings.
        if fixture.assembly.provider.servedRevision == revision {
            XCTAssertGreaterThan(fixture.surface.surfaceGeneration, generation)
        }
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), expected)
        XCTAssertEqual(fixture.assembly.provider.expectedLayout, expected)
        XCTAssertEqual(fixture.owner.folderOpenState?.openEntry?.members,
                       Array(fixture.catalog.records.prefix(2).map(\.id).reversed()))
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertNil(coordinator.controller.activeTransaction)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
        return expected
    }

    private func assertDrainedSingleWrite(_ fixture: Fixture, expected: PersistentWorkspaceLayout) async {
        let result = await fixture.owner.drainAcceptedWorkspaceWrites()
        XCTAssertEqual(result, .nothingPending)
        let writes = await fixture.store.enqueued
        XCTAssertEqual(writes, [expected])
    }

    func testRealMemberReorderWithPendingCatalogUsesFullRefreshAndLatestCatalog() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let provider = fixture.assembly.provider
        XCTAssertFalse(provider.hasPendingPresentationChanges)
        let expected = try releaseMemberReorderRequiringFullRefresh(fixture) {
            provider.receive(.init(revision: CatalogRevision(8), records: fixture.catalog.records))
            provider.receive(.init(revision: CatalogRevision(9), records: fixture.catalog.records))
            XCTAssertTrue(provider.hasPendingSnapshot)
            XCTAssertTrue(provider.hasPendingPresentationChanges)
        }
        XCTAssertEqual(provider.servedRevision, 9)
        XCTAssertFalse(provider.hasPendingPresentationChanges)
        await assertDrainedSingleWrite(fixture, expected: expected)
    }

    func testRealMemberReorderWithPendingManagementFolderOrExpectedLayoutUsesFullRefresh() async throws {
        for pendingKind in ["management", "folder", "expectedLayout"] {
            let fixture = try Fixture(); defer { fixture.teardown() }
            await waitFor { !fixture.owner.isRestoringLayout }
            let provider = fixture.assembly.provider
            XCTAssertFalse(provider.hasPendingPresentationChanges)
            let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Latest alias", for: fixture.catalog.records[0]))
            let expected = try releaseMemberReorderRequiringFullRefresh(fixture) {
                switch pendingKind {
                case "management":
                    let older = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Older alias", for: fixture.catalog.records[0]))
                    provider.receiveManagementPreferences(older)
                    provider.receiveManagementPreferences(preferences)
                case "folder":
                    let folders = try XCTUnwrap(provider.servedFolderSnapshot)
                    provider.receiveFolderSnapshot(.init(generation: folders.generation.incremented(), entries: folders.entries))
                    XCTAssertTrue(provider.hasPendingFolderSnapshot)
                default:
                    provider.receiveExpectedLayout(fixture.saved)
                }
                XCTAssertTrue(provider.hasPendingPresentationChanges, pendingKind)
            }
            XCTAssertFalse(provider.hasPendingPresentationChanges, pendingKind)
            XCTAssertEqual(provider.servedRevision, fixture.catalog.revision.value)
            if pendingKind == "management" {
                XCTAssertEqual(provider.managementPreferences, preferences)
                XCTAssertEqual(provider.displayName(for: fixture.catalog.records[0].id), "Latest alias")
            }
            await assertDrainedSingleWrite(fixture, expected: expected)
        }
    }

    func testRealMemberReorderWithActiveOrPendingSearchUsesFullRefreshAndKeepsLatestQuery() async throws {
        // Enter search through its public presentation seam after the gesture starts.
        // This covers both a committed provider query and a latest-wins pending query.
        for commitBeforeRelease in [true, false] {
            let fixture = try Fixture(); defer { fixture.teardown() }
            await waitFor { !fixture.owner.isRestoringLayout }
            let provider = fixture.assembly.provider
            let search = fixture.assembly.searchPresentation
            let expected = try releaseMemberReorderRequiringFullRefresh(fixture) {
                search.updateQuery(.init(raw: "Alpha"))
                search.updateQuery(.init(raw: "Beta"))
                XCTAssertTrue(provider.hasPendingPresentationChanges)
                if commitBeforeRelease {
                    _ = search.applyPendingAtIdleBoundary(currentPage: 0)
                    XCTAssertEqual(provider.activeQuery?.raw, "Beta")
                    XCTAssertFalse(provider.hasPendingPresentationChanges)
                }
            }
            XCTAssertEqual(search.currentQuery?.raw, "Beta")
            XCTAssertEqual(provider.activeQuery?.raw, "Beta")
            XCTAssertEqual(provider.presentationRecords.map(\.id), [fixture.catalog.records[1].id])
            XCTAssertFalse(provider.hasPendingSearchResult)
            XCTAssertFalse(provider.hasPendingPresentationChanges)
            await assertDrainedSingleWrite(fixture, expected: expected)
            search.clearQuery()
            _ = search.applyPendingAtIdleBoundary(currentPage: 0)
            XCTAssertEqual(provider.presentationEntries.first?.identity, .folder(fixture.first))
            XCTAssertEqual(provider.servedFolderSnapshot?.entry(for: fixture.first)?.members,
                           Array(fixture.catalog.records.prefix(2).map(\.id).reversed()))
            XCTAssertEqual(fixture.owner.currentPersistentLayout(), expected)
        }
    }

    func testOptInDropDiagnosticsWrapRealOverlayReleaseAndOwnerCommitWithoutChangingLayout() async throws {
        let options = try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "drop-test"]).get()
        let fixture = try Fixture(appOptions: options)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundle = root.appendingPathComponent(".build/candidates/diagnostic/Launchcopy.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let window = QuitOnBlankClickWindow(contentRect: fixture.host.bounds, styleMask: [.borderless],
                                            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            fixture.owner.stopFolderDropTiming()
            fixture.teardown()
            window.contentView = nil
            fixture.owner.window = nil
            window.close()
            try? FileManager.default.removeItem(at: root)
        }
        try fixture.owner.configureUITestProfile(bundleURL: bundle)
        fixture.owner.window = window
        window.contentView = fixture.host
        fixture.owner.installFolderWindowInput(on: window)
        await waitFor { !fixture.owner.isRestoringLayout }
        fixture.owner.openFolder(folderID: fixture.first)
        fixture.owner.toggleFolderDropTiming(nil)
        let probe = try XCTUnwrap(fixture.owner.folderDropLatencyProbe)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let original = try XCTUnwrap(overlay.currentEntry)
        let geometry = try XCTUnwrap(coordinator.geometryProvider(.folder(fixture.first)))
        let target = try XCTUnwrap(geometry.itemFrames.last).frame
        let down = source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        let drop = overlay.convert(NSPoint(x: CGFloat(target.maxX - target.width / 8),
                                           y: CGFloat(target.minY + target.height / 2)), to: nil)
        coordinator.pointerDown(locationInWindow: down, sourceCell: source, memberFolderID: fixture.first)
        coordinator.pointerDragged(locationInWindow: drop)
        let timestamp = ProcessInfo.processInfo.systemUptime
        // Window admission is tested separately. This composition test enters the actual overlay
        // release method and real owner commit, not a duplicate onCommit implementation.
        window.onFolderMouseUpTiming?(timestamp, timestamp)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: drop,
            modifierFlags: [], timestamp: timestamp, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        overlay.mouseUp(with: event)
        XCTAssertEqual(overlay.currentEntry?.members, Array(original.members.reversed()))
        XCTAssertEqual(probe.samples.count, 1)
        let sample = try XCTUnwrap(probe.samples.last)
        for stage in FolderDropLatencyProbe.Stage.allCases {
            XCTAssertNotNil(sample.stageOffsetsMS[stage], stage.rawValue)
        }
        XCTAssertNotNil(sample.releaseToReturnMS)
        XCTAssertNotNil(sample.windowToOverlayMS)
        XCTAssertFalse(sample.invalidClock)
        XCTAssertFalse(coordinator.isSessionActive)
        let nextTurnBarrier = expectation(description: "Queued drop diagnostic marker completed")
        DispatchQueue.main.async { nextTurnBarrier.fulfill() }
        await fulfillment(of: [nextTurnBarrier], timeout: 2)
        XCTAssertNotNil(probe.samples.last?.nextTurnMS)
        overlay.viewWillDraw()
        XCTAssertNotNil(probe.samples.last?.willDrawMS)
        fixture.owner.stopFolderDropTiming()
        XCTAssertNil(overlay.onDropDiagnosticEvent)
        XCTAssertNil(window.onFolderMouseUpTiming)
        XCTAssertNil(fixture.owner.folderDropLatencyProbe)
    }

    func testRealFolderDragNoOpPreservesLayoutBindingsAndImagesWithoutEnqueue() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        fixture.owner.openFolder(folderID: fixture.first)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        let entry = try XCTUnwrap(overlay.currentEntry)
        let presentationGeneration = fixture.assembly.provider.canonicalPresentationGeneration
        let surfaceGeneration = overlay.surfaceGeneration
        let cells = try (0..<2).map { try XCTUnwrap(overlay.memberCell(at: $0)) }
        let tokens = try cells.map { try XCTUnwrap($0.bindingToken) }
        let images = [NSColor.systemRed, NSColor.systemBlue].map { color in
            NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
                color.setFill()
                NSBezierPath(rect: rect).fill()
                return true
            }
        }
        for index in cells.indices {
            XCTAssertTrue(cells[index].applyIconIfValid(images[index], token: tokens[index]))
        }
        let geometry = try XCTUnwrap(coordinator.geometryProvider(.folder(fixture.first)))
        let target = try XCTUnwrap(geometry.itemFrames.first).frame
        let down = cells[0].convert(NSPoint(x: cells[0].bounds.midX, y: cells[0].bounds.midY), to: nil)
        // Cross the drag threshold but remain before the source's original slot.
        let drop = overlay.convert(NSPoint(x: CGFloat(target.minX + target.width / 8),
                                            y: CGFloat(target.minY + target.height / 2)), to: nil)
        coordinator.pointerDown(locationInWindow: down, sourceCell: cells[0], memberFolderID: fixture.first)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        coordinator.pointerDragged(locationInWindow: drop)
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertEqual(coordinator.controller.lastIntent, .insertion(index: 0))
        XCTAssertTrue(coordinator.visuals.isPreviewVisible)
        coordinator.pointerUp(locationInWindow: drop)

        XCTAssertEqual(coordinator.controller.lastOutcome, .noOp)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), before)
        XCTAssertEqual(coordinator.layoutProvider(), before)
        XCTAssertEqual(fixture.assembly.provider.expectedLayout, before)
        XCTAssertEqual(fixture.assembly.provider.canonicalPresentationGeneration, presentationGeneration)
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.entry(for: fixture.first), entry)
        XCTAssertEqual(fixture.owner.folderOpenState?.openEntry, entry)
        XCTAssertEqual(overlay.currentEntry, entry)
        XCTAssertEqual(overlay.surfaceGeneration, surfaceGeneration)
        XCTAssertTrue(overlay.superview === fixture.host)
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertNil(coordinator.controller.activeTransaction)
        XCTAssertNil(coordinator.controller.edgeDwellDeadline)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
        XCTAssertFalse(coordinator.visuals.isInsertionIndicatorVisible)
        XCTAssertFalse(coordinator.visuals.isFolderHighlightVisible)
        XCTAssertFalse(coordinator.visuals.isCreateFolderIndicatorVisible)
        XCTAssertNil(coordinator.visuals.previewIconImage)
        for index in cells.indices {
            XCTAssertTrue(overlay.memberCell(at: index) === cells[index])
            XCTAssertEqual(cells[index].bindingToken, tokens[index])
            XCTAssertTrue(cells[index].iconView.image === images[index])
        }

        for _ in 0..<20 { await Task.yield() }
        let writes = await fixture.store.enqueued
        XCTAssertTrue(writes.isEmpty)
    }

    func testRealMenuMovesTopLevelAppAndEnqueuesSharedCommitExactlyOnce() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let cell = fixture.cell(4), menu = try fixture.submenu(cell)
        let index = try XCTUnwrap(menu.items.firstIndex { $0.title == "Fixture One" })
        menu.performActionForItem(at: index)
        await waitForEnqueue(fixture, count: 1)
        let result = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(result.generation, LayoutGeneration(5))
        XCTAssertEqual(result.folder(id: fixture.first)?.members.last, .from(record: fixture.catalog.records[4]))
        XCTAssertFalse(result.topLevelOrder.contains(.app(.from(record: fixture.catalog.records[4]))))
        XCTAssertEqual(fixture.assembly.provider.expectedLayout, result)
        let enqueued = await fixture.store.enqueued
        XCTAssertEqual(enqueued, [result])
        // A retained menu cannot apply the old snapshot a second time.
        menu.performActionForItem(at: index)
        for _ in 0..<20 { await Task.yield() }
        let final = await fixture.store.enqueued
        XCTAssertEqual(final.count, 1)
    }

    func testMemberMenuMovesOutAfterSourceAndClosesOverlay() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        fixture.owner.openFolder(folderID: fixture.first)
        XCTAssertTrue(fixture.owner.folderOpenState?.isOpen == true)
        let cell = try XCTUnwrap(fixture.owner.folderOverlay?.memberCell(at: 0))
        XCTAssertEqual(cell.bindingToken?.catalogRevision, 7)
        let menu = try fixture.submenu(cell)
        let index = try XCTUnwrap(menu.items.firstIndex { $0.identifier?.rawValue == "folderAssignment.moveToTopLevel" })
        menu.performActionForItem(at: index)
        await waitForEnqueue(fixture, count: 1)
        let result = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertNil(result.folder(id: fixture.first))
        XCTAssertEqual(Array(result.topLevelOrder.prefix(2)),
                       [.app(.from(record: fixture.catalog.records[1])), .app(.from(record: fixture.catalog.records[0]))])
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertNil(fixture.owner.folderOverlay?.superview)
    }

    func testActiveOriginalAndAliasSearchSurvivesOrganizationAndClearsToNewOrder() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let record = fixture.catalog.records[4]
        let prefs = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Shortcut", for: record))
        fixture.owner.applyAppManagementPreferences(prefs)
        let search = fixture.assembly.searchPresentation
        search.updateQuery(.init(raw: "Echo")); _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let cell = fixture.cell(4), menu = try fixture.submenu(cell)
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Fixture One" }))
        await waitForEnqueue(fixture, count: 1)
        XCTAssertEqual(search.currentQuery?.raw, "Echo")
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.displayName), ["Shortcut"])
        search.updateQuery(.init(raw: "Shortcut")); _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.id), [record.id])
        search.clearQuery(); _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(fixture.assembly.provider.presentationEntries.first?.identity, .folder(fixture.first))
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.entry(for: fixture.first)?.members.last, record.id)
        XCTAssertEqual(fixture.assembly.provider.servedRevision, 7)
    }

    func testNoOpAndHiddenRejectionDoNotEnqueueOrChangePresentationGeneration() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let initial = fixture.assembly.provider.canonicalPresentationGeneration
        let record = fixture.catalog.records[0], expected = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(fixture.owner.applyFolderAssignment(record: record, action: .moveToFolder(fixture.first), expectedLayout: expected), .noOp(expected))
        XCTAssertEqual(fixture.assembly.provider.canonicalPresentationGeneration, initial)
        fixture.owner.applyAppManagementPreferences(.default.settingHidden(true, for: record))
        XCTAssertEqual(fixture.owner.applyFolderAssignment(record: record, action: .moveToFolder(fixture.second), expectedLayout: expected), .cancelled)
        for _ in 0..<20 { await Task.yield() }
        let enqueued = await fixture.store.enqueued
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testLayoutProtectionAndBootstrapDisableMenuAndRejectDirectMutation() async throws {
        let fixture = try Fixture(protected: true); defer { fixture.teardown() }
        XCTAssertFalse(fixture.owner.canApplyFolderAssignment)
        await waitFor { !fixture.owner.isRestoringLayout }
        XCTAssertEqual(fixture.owner.layoutPersistenceState, .readOnlyProtection(.unknownFutureVersion(9)))
        let cell = fixture.cell(4), menu = try fixture.submenu(cell)
        XCTAssertTrue(menu.items.filter { !$0.isSeparatorItem }.allSatisfy { !$0.isEnabled })
        let expected = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(fixture.owner.applyFolderAssignment(record: fixture.catalog.records[4], action: .moveToFolder(fixture.first), expectedLayout: expected), .cancelled)
        let enqueued = await fixture.store.enqueued
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testActiveGestureAndTeardownRejectWithoutLayoutMutation() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let expected = try XCTUnwrap(fixture.owner.currentPersistentLayout()), record = fixture.catalog.records[4]
        _ = fixture.surface.core.handleGesturePhase(.began, delta: 0, timestamp: 1)
        XCTAssertFalse(fixture.owner.canApplyFolderAssignment)
        XCTAssertEqual(fixture.owner.applyFolderAssignment(record: record, action: .moveToFolder(fixture.first), expectedLayout: expected), .cancelled)
        fixture.surface.cancel(); fixture.surface.teardown()
        XCTAssertFalse(fixture.owner.canApplyFolderAssignment)
        XCTAssertEqual(fixture.owner.applyFolderAssignment(record: record, action: .moveToFolder(fixture.first), expectedLayout: expected), .cancelled)
        let enqueued = await fixture.store.enqueued
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testSharedDragCommitClosesWhenVisibleMemberRemovedDespiteHiddenCanonicalMember() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let extra = PersistentAppReference.from(record: fixture.catalog.records[4])
        let hidden = fixture.catalog.records[1]
        let initial = PersistentWorkspaceLayout(generation: LayoutGeneration(5),
            topLevelOrder: [.folder(fixture.first), .folder(fixture.second), .app(.from(record: fixture.catalog.records[5]))],
            folders: [.init(id: fixture.first, title: "Fixture One", members: [.from(record: fixture.catalog.records[0]), .from(record: hidden), extra]), fixture.saved.folders[1]])
        fixture.owner.commitWorkspaceLayout(initial)
        await waitForEnqueue(fixture, count: 1)
        fixture.owner.applyAppManagementPreferences(.default.settingHidden(true, for: hidden))
        fixture.owner.openFolder(folderID: fixture.first)
        XCTAssertEqual(fixture.owner.folderOpenState?.memberCount, 2)
        guard case .success(let moved) = LayoutMutation(expectedGeneration: initial.generation).moveOutOfFolder(in: initial, folderID: fixture.first, member: extra, toIndex: 1) else {
            return XCTFail("Expected valid move")
        }
        fixture.owner.dragCoordinator?.onCommit(moved)
        await waitForEnqueue(fixture, count: 2)
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.members.count, 2)
    }

    func testPendingCatalogDeliveredByCancellationRejectsOldLayoutTransaction() async throws {
        let fixture = try Fixture(itemsPerPage: 2); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let expected = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        _ = fixture.surface.core.handleGesturePhase(.began, timestamp: 1)
        _ = fixture.surface.core.handleGesturePhase(.changed, delta: -1000, timestamp: 1.1)
        _ = fixture.surface.core.handleGesturePhase(.ended, timestamp: 1.2)
        _ = fixture.surface.core.finishGesture(timestamp: 1.21)
        XCTAssertEqual(fixture.surface.core.state, .settling)
        XCTAssertTrue(fixture.owner.canApplyFolderAssignment)
        let refreshed = CatalogSnapshot(revision: CatalogRevision(8), records: fixture.catalog.records)
        fixture.assembly.provider.receive(refreshed)
        fixture.surface.appEvents.onStateChange = { [weak fixture] state in
            guard state == .cancelled, let fixture else { return }
            _ = fixture.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        }
        let result = fixture.owner.applyFolderAssignment(record: fixture.catalog.records[4],
            action: .moveToFolder(fixture.first), expectedLayout: expected)
        XCTAssertEqual(result, .rejected(.invalidTarget))
        XCTAssertEqual(fixture.assembly.provider.servedRevision, 8)
        XCTAssertEqual(fixture.assembly.provider.expectedLayout, fixture.saved)
        for _ in 0..<20 { await Task.yield() }
        let enqueued = await fixture.store.enqueued
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testActiveDragRejectsMenuWithoutCancelingPhysicalInteraction() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let cell = fixture.cell(4), expected = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        fixture.owner.dragCoordinator?.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertTrue(fixture.owner.dragCoordinator?.isSessionActive == true)
        let result = fixture.owner.applyFolderAssignment(record: fixture.catalog.records[4],
            action: .moveToFolder(fixture.first), expectedLayout: expected)
        XCTAssertEqual(result, .cancelled)
        XCTAssertTrue(fixture.owner.dragCoordinator?.isSessionActive == true)
        let enqueued = await fixture.store.enqueued
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testBootstrapBlocksDragCommitButPreservesClickFallbackAndRestoresSavedLayout() async throws {
        let fixture = try Fixture(suspendsLoad: true); defer { fixture.teardown() }
        for _ in 0..<1000 { if await fixture.store.loadStarted { break }; await Task.yield() }
        XCTAssertFalse(fixture.owner.canCommitWorkspaceLayout)
        let cell = fixture.cell(4)
        var clicks = 0
        fixture.owner.dragCoordinator?.onCellClick = { _ in clicks += 1 }
        fixture.owner.dragCoordinator?.pointerDown(locationInWindow: .init(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(fixture.owner.dragCoordinator?.controller.state, .idle)
        fixture.owner.dragCoordinator?.pointerUp(locationInWindow: .init(x: 40, y: 40))
        XCTAssertEqual(clicks, 1)
        let alternative = PersistentWorkspaceLayout(generation: LayoutGeneration(5),
            topLevelOrder: Array(fixture.saved.topLevelOrder.reversed()), folders: fixture.saved.folders)
        XCTAssertFalse(fixture.owner.commitWorkspaceLayout(alternative))
        XCTAssertEqual(fixture.assembly.provider.expectedLayout, fixture.saved)
        await fixture.store.releaseLoad()
        await waitFor { !fixture.owner.isRestoringLayout }
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let enqueued = await fixture.store.enqueued
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testReadOnlyRaisedAfterPressBlocksSharedCommitAndEnqueue() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let cell = fixture.cell(4)
        fixture.owner.dragCoordinator?.pointerDown(locationInWindow: .init(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(fixture.owner.dragCoordinator?.controller.state, .pressed)
        let protected = Store(.readOnlyProtection(.unknownFutureVersion(9)))
        fixture.owner.installLayoutStore(protected)
        await waitFor { !fixture.owner.isRestoringLayout }
        let alternative = PersistentWorkspaceLayout(generation: LayoutGeneration(5),
            topLevelOrder: Array(fixture.saved.topLevelOrder.reversed()), folders: fixture.saved.folders)
        fixture.owner.dragCoordinator?.onCommit(alternative)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        let oldWrites = await fixture.store.enqueued, newWrites = await protected.enqueued
        XCTAssertTrue(oldWrites.isEmpty); XCTAssertTrue(newWrites.isEmpty)
    }

    func testQueuedAcceptedWriteNeverRoutesToReplacementStore() async throws {
        let fixture = try Fixture(); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let alternative = PersistentWorkspaceLayout(generation: LayoutGeneration(5),
            topLevelOrder: Array(fixture.saved.topLevelOrder.reversed()), folders: fixture.saved.folders)
        XCTAssertTrue(fixture.owner.commitWorkspaceLayout(alternative))
        // No suspension between accepted commit and store replacement.
        let replacement = Store(.readOnlyProtection(.unknownFutureVersion(9)))
        fixture.owner.installLayoutStore(replacement)
        await waitFor { !fixture.owner.isRestoringLayout }
        for _ in 0..<20 { await Task.yield() }
        let oldWrites = await fixture.store.enqueued, newWrites = await replacement.enqueued
        XCTAssertTrue(oldWrites.isEmpty); XCTAssertTrue(newWrites.isEmpty)
        XCTAssertEqual(fixture.owner.layoutPersistenceState, .readOnlyProtection(.unknownFutureVersion(9)))
    }

    private func startSettle(_ fixture: Fixture) {
        _ = fixture.surface.core.handleGesturePhase(.began, timestamp: 1)
        _ = fixture.surface.core.handleGesturePhase(.changed, delta: -1000, timestamp: 1.1)
        _ = fixture.surface.core.handleGesturePhase(.ended, timestamp: 1.2)
        _ = fixture.surface.core.finishGesture(timestamp: 1.21)
        XCTAssertEqual(fixture.surface.core.state, .settling)
    }

    func testActualMenuRejectsSameRevisionRenderedCellRebindingDuringCancellation() async throws {
        let fixture = try Fixture(itemsPerPage: 2); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let record = fixture.catalog.records[4]
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap((0..<page.cellCount).compactMap { page.cell(at: $0) }.first { $0.bindingToken?.appID as? AppID == record.id })
        let oldToken = cell.bindingToken, menu = try fixture.submenu(cell)
        let expected = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        startSettle(fixture)
        fixture.assembly.searchPresentation.updateQuery(.init(raw: "Alpha"))
        fixture.surface.appEvents.onStateChange = { [weak fixture, weak cell] state in
            guard state == .cancelled, let fixture else { return }
            _ = fixture.assembly.commitPendingAtIdleBoundary(currentPage: 0)
            fixture.surface.reloadCurrentPresentation()
            cell?.clearContent()
        }
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Fixture One" }))
        XCTAssertNotEqual(cell.bindingToken, oldToken)
        XCTAssertEqual(fixture.assembly.provider.servedRevision, 7)
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), expected)
        for _ in 0..<20 { await Task.yield() }
        let writes = await fixture.store.enqueued
        XCTAssertTrue(writes.isEmpty)
    }

    func testRejectedMemberMenuDoesNotCloseFolderBeforeFinalValidation() async throws {
        let fixture = try Fixture(itemsPerPage: 2); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        fixture.owner.openFolder(folderID: fixture.first)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay), cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let menu = try fixture.submenu(cell)
        startSettle(fixture)
        fixture.assembly.provider.receive(.init(revision: CatalogRevision(8), records: fixture.catalog.records))
        fixture.surface.appEvents.onStateChange = { [weak fixture] state in
            guard state == .cancelled, let fixture else { return }
            _ = fixture.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        }
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "移到主页面" }))
        XCTAssertEqual(fixture.assembly.provider.servedRevision, 8)
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, fixture.first)
        XCTAssertTrue(overlay.superview === fixture.host)
        let writes = await fixture.store.enqueued
        XCTAssertTrue(writes.isEmpty)
    }

    private func savedPathMemberLayout() -> PersistentWorkspaceLayout {
        let first = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let second = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!)
        func ref(_ name: String) -> PersistentAppReference { .bundleID("fixture.folderassignment.\(name.lowercased())") }
        return .init(generation: LayoutGeneration(4),
            topLevelOrder: [.folder(first), .app(ref("Alpha")), .folder(second), .app(ref("Beta")), .app(ref("Foxtrot"))],
            folders: [.init(id: first, title: "Fixture One", members: [.canonicalPath("/syntheticapps/echo.app"), .bundleID("fixture.unavailable")]),
                      .init(id: second, title: "Fixture Two", members: [ref("Gamma"), ref("Delta")])])
    }
    private func visibleOccurrences(_ id: AppID, fixture: Fixture) -> Int {
        fixture.assembly.provider.presentationEntries.reduce(0) { count, entry in
            switch entry {
            case .app(let record): return count + (record.id == id ? 1 : 0)
            case .folder(let folder): return count + folder.members.filter { $0 == id }.count
            }
        }
    }

    func testPathMemberWithNewBundleIDMovesThroughRealMenusWithoutDuplicationOrMigration() async throws {
        let fixture = try Fixture(customLayout: savedPathMemberLayout()); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let record = fixture.catalog.records[4], stored = PersistentAppReference.canonicalPath("/syntheticapps/echo.app")
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), fixture.saved)
        XCTAssertEqual(visibleOccurrences(record.id, fixture: fixture), 1)
        let cell = fixture.cell(4), menu = try fixture.submenu(cell)
        XCTAssertFalse(menu.items.contains { $0.title == "Fixture One" })
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Fixture Two" }))
        await waitForEnqueue(fixture, count: 1)
        let moved = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(moved.folder(id: fixture.second)?.members.last, stored)
        XCTAssertNil(moved.folder(id: fixture.first))
        XCTAssertTrue(moved.topLevelOrder.contains(.app(.bundleID("fixture.unavailable"))))
        XCTAssertFalse(moved.topLevelOrder.contains(.app(.from(record: record))))
        XCTAssertEqual(visibleOccurrences(record.id, fixture: fixture), 1)
        // Keep the source cell alive across actual selector dispatch.
        let currentCell = fixture.cell(4), moveOutMenu = try fixture.submenu(currentCell)
        moveOutMenu.performActionForItem(at: try XCTUnwrap(moveOutMenu.items.firstIndex { $0.title == "移到主页面" }))
        await waitForEnqueue(fixture, count: 2)
        XCTAssertTrue(fixture.owner.currentPersistentLayout()?.topLevelOrder.contains(.app(stored)) == true)
        XCTAssertEqual(visibleOccurrences(record.id, fixture: fixture), 1)
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.appReferenceCount, fixture.saved.appReferenceCount)
    }

    func testMovingAnotherAppIntoPathMemberFolderPreservesOriginalReferenceAndLatentSurvivor() async throws {
        let fixture = try Fixture(customLayout: savedPathMemberLayout()); defer { fixture.teardown() }
        await waitFor { !fixture.owner.isRestoringLayout }
        let cell = fixture.cell(0), menu = try fixture.submenu(cell)
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Fixture One" }))
        await waitForEnqueue(fixture, count: 1)
        let expected = fixture.saved.folders[0].members + [.from(record: fixture.catalog.records[0])]
        XCTAssertEqual(fixture.owner.currentPersistentLayout()?.folder(id: fixture.first)?.members, expected)
        XCTAssertEqual(visibleOccurrences(fixture.catalog.records[4].id, fixture: fixture), 1)
    }
}
