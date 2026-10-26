import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

/// No machine scans, production preferences, displayed windows or disk writes.
@MainActor
final class AppManagementAssemblyTests: XCTestCase {
    private actor LoadGate: LayoutStore {
        nonisolated let storeDirectory = URL(fileURLWithPath: "/SyntheticLayoutStore")
        private var continuation: CheckedContinuation<LayoutStoreLoadResult, Never>?
        private var started: CheckedContinuation<Void, Never>?
        private var isLoading = false
        private(set) var writes = 0
        func load() async -> LayoutStoreLoadResult {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                isLoading = true
                started?.resume(); started = nil
            }
        }
        func waitUntilLoading() async {
            if isLoading { return }
            await withCheckedContinuation { started = $0 }
        }
        func finish(_ layout: PersistentWorkspaceLayout) {
            continuation?.resume(returning: .loaded(layout, writeGeneration: 1))
            continuation = nil
        }
        func enqueue(_ layout: PersistentWorkspaceLayout) async { writes += 1 }
        func flush() async -> LayoutStoreFlushResult { .nothingPending }
        func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult { .failed }
        func currentState() async -> LayoutStoreState { .healthy }
        func lockMode() async -> LayoutStoreLockMode { .singleWriter }
        func staleRejectionCount() async -> UInt64 { 0 }
    }

    private func snapshot() -> CatalogSnapshot {
        let records = ["Alpha", "Beta", "Gamma"].map { name in
            let id = CatalogFixture.appID("fixture.management.\(name.lowercased())")
            return CatalogFixture.record(id: id, displayName: name,
                bundleID: "fixture.management.\(name.lowercased())",
                url: CatalogFixture.tempURL(named: "\(name).app"), icon: .from(appID: id), rootPriority: 0)
        }
        return CatalogSnapshot(revision: CatalogRevision(7), records: records)
    }
    private func layout(_ catalog: CatalogSnapshot, reversed: Bool = false) -> PersistentWorkspaceLayout {
        let entries = catalog.records.map { WorkspaceTopLevelEntry.app(.from(record: $0)) }
        return .init(generation: LayoutGeneration(reversed ? 9 : 4),
                     topLevelOrder: reversed ? Array(entries.reversed()) : entries, folders: [])
    }
    private func assembly() -> AppCatalogAssembly {
        AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")], loader: RecordingIconLoader())
    }
    private func waitFor(_ condition: @escaping () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Bounded asynchronous operation did not complete")
    }

    func testLayoutRestoreBeforeCatalogRemainsPendingUntilFirstScan() async throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly()
        defer { assembly.teardown() }
        owner.assembly = assembly
        let gate = LoadGate()
        let expected = layout(snapshot(), reversed: true)
        owner.beginLayoutRestore(store: gate)
        await gate.waitUntilLoading()
        await gate.finish(expected)
        await waitFor { owner.currentPersistentLayout() == expected }
        XCTAssertNil(assembly.provider.servedSnapshot)
        assembly.provider.receive(snapshot())
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(assembly.provider.expectedLayout, expected)
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.displayName), ["Gamma", "Beta", "Alpha"])
        let writes = await gate.writes
        XCTAssertEqual(writes, 0)
    }

    func testSupersededLayoutLoadCannotOverwriteNewerRestore() async throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly()
        defer { assembly.teardown() }
        owner.assembly = assembly
        let first = LoadGate(), second = LoadGate()
        let old = layout(snapshot()), newest = layout(snapshot(), reversed: true)
        owner.beginLayoutRestore(store: first)
        await first.waitUntilLoading()
        owner.beginLayoutRestore(store: second)
        await second.waitUntilLoading()
        await second.finish(newest)
        await waitFor { owner.currentPersistentLayout() == newest }
        await first.finish(old)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(owner.currentPersistentLayout(), newest)
    }

    func testPreloadDragCommitIsRejectedSoSavedOrganizationCanRestore() async throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly(), surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        owner.assembly = assembly; owner.surface = surface
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        owner.installDragUI(surface: surface, assembly: assembly)
        defer {
            owner.dragCoordinator?.teardown()
            if DragUISessionCoordinator.shared === owner.dragCoordinator { DragUISessionCoordinator.shared = nil }
            assembly.teardown(); surface.teardown()
        }
        assembly.provider.receive(snapshot())
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let gate = LoadGate(), newest = layout(snapshot(), reversed: true)
        owner.beginLayoutRestore(store: gate)
        await gate.waitUntilLoading()
        owner.dragCoordinator?.onCommit(newest)
        await gate.finish(layout(snapshot()))
        await waitFor { !owner.isRestoringLayout }
        XCTAssertEqual(owner.currentPersistentLayout(), layout(snapshot()))
        XCTAssertEqual(assembly.provider.expectedLayout, layout(snapshot()))
    }

    func testLogicalIndexCacheDoesNotRebuildOnEachPointerGeometryLookup() throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly()
        defer { assembly.teardown() }
        owner.assembly = assembly
        assembly.provider.receive(snapshot())
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let initial = try XCTUnwrap(owner.currentPersistentLayout())
        XCTAssertEqual(owner.resolvedLayoutBuildCount, 1)
        for _ in 0..<100 { XCTAssertEqual(owner.currentPersistentLayout(), initial) }
        XCTAssertEqual(owner.resolvedLayoutBuildCount, 1)
        assembly.provider.receiveManagementPreferences(.default.settingHidden(true, for: snapshot().records[0]))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(owner.currentPersistentLayout(), initial)
        XCTAssertEqual(owner.resolvedLayoutBuildCount, 2)
        XCTAssertEqual(initial.appReferenceCount, 3)
    }

    func testResolvedDragLayoutIncludesNewCatalogTailButDoesNotRewriteExpectedLayout() throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly()
        defer { assembly.teardown() }
        owner.assembly = assembly
        let catalog = snapshot()
        let saved = PersistentWorkspaceLayout(generation: LayoutGeneration(9),
            topLevelOrder: [.app(.from(record: catalog.records[1])), .app(.from(record: catalog.records[0]))], folders: [])
        assembly.provider.receiveExpectedLayout(saved)
        assembly.provider.receive(catalog)
        assembly.provider.receiveManagementPreferences(.default.settingHidden(true, for: catalog.records[2]))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let resolved = try XCTUnwrap(owner.currentPersistentLayout())
        XCTAssertEqual(resolved.topLevelOrder, saved.topLevelOrder + [.app(.from(record: catalog.records[2]))])
        XCTAssertEqual(resolved.generation, saved.generation)
        XCTAssertEqual(assembly.provider.expectedLayout, saved)
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.displayName), ["Beta", "Alpha"])
    }

    func testMetadataOwnerPreservesQueryAndCanonicalLaunchURL() throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly(), surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        owner.assembly = assembly; owner.surface = surface
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        defer { assembly.teardown(); surface.teardown() }
        assembly.provider.receive(snapshot())
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let canonical = snapshot().records[0]
        assembly.searchPresentation.updateQuery(.init(raw: "Alpha"))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let prefs = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Shortcut", for: canonical))
        owner.applyAppManagementPreferences(prefs)
        XCTAssertEqual(assembly.searchPresentation.currentQuery?.raw, "Alpha")
        XCTAssertEqual(assembly.provider.presentationRecords.first?.displayName, "Shortcut")
        XCTAssertEqual(assembly.bundleURL(for: canonical.id), canonical.canonicalURL)
        owner.applyAppManagementPreferences(prefs.settingHidden(true, for: canonical))
        XCTAssertTrue(assembly.provider.presentationRecords.isEmpty)
        XCTAssertEqual(assembly.provider.servedRevision, 7)
    }

    func testHidingOpenFolderMemberClosesInputAndReopensSameFolderWithRemainingMember() throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let assembly = assembly(), surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
        owner.assembly = assembly; owner.surface = surface; owner.container = host
        surface.frame = host.bounds; host.addSubview(surface)
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        let keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        owner.keyboardController = keyboard
        owner.installFolderWiring(assembly: assembly, surface: surface, keyboard: keyboard,
                                  launch: AppLaunchController(surface: surface, assembly: assembly, session: nil))
        defer { owner.closeFolder(); assembly.teardown(); surface.teardown() }
        let catalog = snapshot()
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000092")!)
        let entry = FolderEntry(id: folderID, title: "Fixture group", members: Array(catalog.records.prefix(2)).map(\.id))
        assembly.provider.receive(catalog)
        assembly.provider.receiveFolderSnapshot(.init(generation: .zero, entries: [entry]))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        owner.openFolder(folderID: folderID)
        XCTAssertTrue(owner.folderOpenState?.isOpen == true)
        XCTAssertNotNil(owner.folderOverlay?.superview)
        owner.applyAppManagementPreferences(.default.settingHidden(true, for: catalog.records[0]))
        XCTAssertFalse(owner.folderOpenState?.isOpen == true)
        XCTAssertNil(owner.folderOverlay?.superview)
        owner.openFolder(folderID: folderID)
        XCTAssertEqual(owner.folderOpenState?.openFolderID, folderID)
        XCTAssertEqual(owner.folderOpenState?.memberCount, 1)
        XCTAssertEqual(assembly.provider.canonicalFolderSnapshot?.entry(for: folderID)?.members, entry.members)
    }
}
