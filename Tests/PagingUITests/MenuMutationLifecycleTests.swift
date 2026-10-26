import AppKit
import AppCatalogCore
import LauncherLocalization
import XCTest
@testable import AppGridUI
@testable import PagingUI
@testable import PagingPrototypeApp

@MainActor
private final class MenuLifecycleLanguageStore: LanguagePreferencesPersisting {
    var value = LanguagePreferences(language: .english)
    func load() -> LanguagePreferencesLoadResult { .loaded(value) }
    func save(_ value: LanguagePreferences) -> LanguagePreferencesSaveResult { self.value = value; return .saved }
}
@MainActor
private final class MenuLifecycleManagementStore: AppManagementPersisting {
    var value: AppManagementPreferences
    var writes = 0
    init(_ value: AppManagementPreferences) { self.value = value }
    func load() -> AppManagementLoadResult { .loaded(value) }
    func save(_ value: AppManagementPreferences) -> AppManagementSaveResult { writes += 1; self.value = value; return .saved }
}

@MainActor
final class MenuMutationLifecycleTests: XCTestCase {
    private actor Store: LayoutStore {
        nonisolated let storeDirectory = URL(fileURLWithPath: "/SyntheticMenuLifecycleStore")
        let layout: PersistentWorkspaceLayout
        private(set) var enqueued: [PersistentWorkspaceLayout] = []
        init(_ layout: PersistentWorkspaceLayout) { self.layout = layout }
        func load() async -> LayoutStoreLoadResult { .loaded(layout, writeGeneration: 3) }
        func enqueue(_ layout: PersistentWorkspaceLayout) async { enqueued.append(layout) }
        func flush() async -> LayoutStoreFlushResult { .nothingPending }
        func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult { .failed }
        func currentState() async -> LayoutStoreState { .healthy }
        func lockMode() async -> LayoutStoreLockMode { .singleWriter }
        func staleRejectionCount() async -> UInt64 { 0 }
    }

    @MainActor
    private final class Fixture {
        let host = AppDelegate(options: .default)
        var surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let window: NSWindow
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticMenuLifecycle")], loader: RecordingIconLoader())
        let records: [AppRecord]
        let folder = FolderID()
        let layout: PersistentWorkspaceLayout
        let preferences: AppManagementPreferences
        let store: MenuLifecycleManagementStore
        var sheets = 0
        init(layoutBuilder: (([AppRecord], FolderID) -> PersistentWorkspaceLayout)? = nil) throws {
            _ = NSApplication.shared
            records = ["Alpha", "Beta", "Gamma"].map { name in
                let id = CatalogFixture.appID("fixture.menu.lifecycle.\(name)")
                return CatalogFixture.record(id: id, displayName: name, bundleID: "fixture.menu.lifecycle.\(name)",
                    url: CatalogFixture.tempURL(named: "\(name).app"), icon: .from(appID: id), rootPriority: 0)
            }
            layout = layoutBuilder?(records, folder) ?? PersistentWorkspaceLayout(generation: LayoutGeneration(4),
                topLevelOrder: [.folder(folder), .app(.from(record: records[1]))],
                folders: [.init(id: folder, title: "User Folder", members: [.from(record: records[0]), .from(record: records[2])])])
            preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("User Alias", for: records[1]))
            store = MenuLifecycleManagementStore(preferences)
            window = NSWindow(contentRect: root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = root
            host.window = window; host.container = root; host.surface = surface; host.assembly = assembly
            root.addSubview(surface)
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            host.installLanguagePreferences(store: MenuLifecycleLanguageStore(), preferredLanguages: { ["en"] }, center: NotificationCenter())
            host.installAppManagementPreferences(store: store)
            assembly.provider.receive(.init(revision: CatalogRevision(7), records: records))
            assembly.provider.receiveExpectedLayout(layout)
            assembly.provider.receiveManagementPreferences(preferences)
            _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            surface.refreshPresentation(); surface.layoutSubtreeIfNeeded()
            host.installActionFeedback(in: root)
            host.installAppContextMenu(assembly: assembly)
            host.applicationSheetPresenter = { [weak self] _, _, _ in self?.sheets += 1 }
        }
        func cell() throws -> AppGridCellView {
            let page = try XCTUnwrap(assembly.renderer.pageView(forPage: 0))
            return try XCTUnwrap((0..<page.cellCount).compactMap { page.cell(at: $0) }.first {
                ($0.bindingToken?.appID as? AppID) == records[1].id
            })
        }
        func menu() throws -> NSMenu { let cell = try cell(); return try XCTUnwrap(cell.appContextMenuProvider?(cell)) }
        func item(_ identifier: String, from menu: NSMenu) throws -> NSMenuItem {
            try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == identifier })
        }
        func action(_ item: NSMenuItem) throws { _ = NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item) }
        func invalidateRoot() {
            let replacement = NSView(frame: root.bounds); window.contentView = replacement
            // A removed Surface permanently tears down. Fresh-action assertions
            // must use a new mounted presentation, not cells from the old root.
            surface = makeSurface(pageCount: 1, itemsPerPage: 35)
            surface.frame = replacement.bounds
            replacement.addSubview(surface)
            surface.contentProvider = assembly.provider
            surface.renderer = assembly.renderer
            surface.refreshPresentation()
            surface.layoutSubtreeIfNeeded()
            host.surface = surface
            host.container = replacement; host.installActionFeedback(in: replacement)
        }
        func invalidateLanguage() { host.installLanguagePreferences(store: MenuLifecycleLanguageStore(), preferredLanguages: { ["en"] }, center: NotificationCenter()) }
        func teardown() {
            host.teardownActionFeedback(); host.teardownLanguagePresentation(); surface.teardown(); assembly.teardown()
            window.delegate = nil; window.contentView = nil
        }
    }

    func testOldHideAndClearAliasMenusCannotWriteAfterRootOrLanguageReplacement() throws {
        for rootReplacement in [true, false] {
            for identifier in ["management.hide", "management.clearAlias"] {
                let f = try Fixture(); defer { f.teardown() }
                let menu = try f.menu(), item = try f.item(identifier, from: menu)
                let controller = try XCTUnwrap(item.target as? AppContextMenuController)
                if rootReplacement { f.invalidateRoot() } else { f.invalidateLanguage() }
                try f.action(item)
                XCTAssertEqual(f.store.writes, 0)
                XCTAssertEqual(f.store.value, f.preferences)
                XCTAssertEqual(f.host.currentPersistentLayout(), f.layout)
                XCTAssertEqual(f.sheets, 0)
                _ = controller // Keep original native target alive through replay.
            }
        }
    }

    func testOldAliasEditorMenuCannotPresentSheetInReplacementWindowRoot() throws {
        let f = try Fixture(); defer { f.teardown() }
        let menu = try f.menu(), item = try f.item("management.alias", from: menu)
        let controller = try XCTUnwrap(item.target as? AppContextMenuController)
        f.invalidateRoot(); try f.action(item)
        XCTAssertEqual(f.sheets, 0)
        XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
        _ = controller
    }

    func testOldMutationMenuCannotWriteReplacementManagementStoreAndFreshMenuCan() throws {
        let f = try Fixture(); defer { f.teardown() }
        let oldMenu = try f.menu(), old = try f.item("management.hide", from: oldMenu)
        let controller = try XCTUnwrap(old.target as? AppContextMenuController)
        let replacement = MenuLifecycleManagementStore(f.preferences)
        f.host.installAppManagementPreferences(store: replacement)
        try f.action(old)
        XCTAssertEqual(replacement.writes, 0)
        XCTAssertEqual(f.store.writes, 0)
        let currentMenu = try f.menu(), current = try f.item("management.hide", from: currentMenu)
        try f.action(current)
        XCTAssertEqual(replacement.writes, 1)
        XCTAssertTrue(replacement.value.isHidden(f.records[1]))
        _ = controller
    }

    func testOldAssignmentMenuCannotChangeLayoutOrPresentRejectionInReplacementRoot() throws {
        let f = try Fixture(); defer { f.teardown() }
        let menu = try f.menu()
        let organization = try f.item("management.organization", from: menu)
        let submenu = try XCTUnwrap(organization.submenu)
        let item = try XCTUnwrap(submenu.items.first { $0.identifier?.rawValue == "folderAssignment.moveToFolder" })
        let target = try XCTUnwrap(item.target as? AppFolderAssignmentMenuController)
        f.invalidateRoot(); try f.action(item)
        XCTAssertEqual(f.host.currentPersistentLayout(), f.layout)
        XCTAssertEqual(f.sheets, 0)
        _ = target
    }

    func testOpenedAliasConfirmationRejectsReplacementAssemblyOrCanonicalURL() throws {
        for replaceAssembly in [true, false] {
            let f = try Fixture(); defer { f.teardown() }
            var completion: ((NSApplication.ModalResponse) -> Void)?
            f.host.applicationSheetPresenter = { [weak f] alert, _, callback in
                guard let f else { return }
                f.sheets += 1
                (alert.accessoryView as? NSTextField)?.stringValue = "Changed Alias"
                completion = callback
            }
            let menu = try f.menu()
            try f.action(f.item("management.alias", from: menu))
            XCTAssertEqual(f.sheets, 1)
            XCTAssertTrue(f.host.languagePresentationController?.hasInteractionOwners == true)
            let replacement = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticReplacement")], loader: RecordingIconLoader())
            defer { replacement.teardown() }
            let target = replaceAssembly ? replacement : f.assembly
            var records = f.records
            if !replaceAssembly {
                let record = records[1]
                records[1] = CatalogFixture.record(id: record.id, displayName: record.displayName,
                    bundleID: "fixture.menu.lifecycle.Beta", url: URL(fileURLWithPath: "/SyntheticMoved/Beta.app"),
                    icon: .from(appID: record.id), rootPriority: 0)
            }
            target.provider.receive(.init(revision: CatalogRevision(7), records: records))
            target.provider.receiveExpectedLayout(f.layout)
            _ = target.commitPendingAtIdleBoundary(currentPage: 0)
            if replaceAssembly { f.host.assembly = replacement }
            try XCTUnwrap(completion)(.alertFirstButtonReturn)
            XCTAssertEqual(f.store.writes, 0)
            XCTAssertEqual(f.store.value, f.preferences)
            XCTAssertEqual(f.sheets, 1)
            XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
        }
    }

    func testFreshAliasAndClearMenusRemainValidAfterRootOrLanguageReplacement() throws {
        for rootReplacement in [true, false] {
            let f = try Fixture(); defer { f.teardown() }
            if rootReplacement { f.invalidateRoot() } else { f.invalidateLanguage() }
            var completion: ((NSApplication.ModalResponse) -> Void)?
            f.host.applicationSheetPresenter = { [weak f] alert, _, callback in
                guard let f else { return }
                f.sheets += 1
                (alert.accessoryView as? NSTextField)?.stringValue = "Changed Alias"
                completion = callback
            }
            try f.action(f.item("management.alias", from: f.menu()))
            XCTAssertEqual(f.sheets, 1)
            try XCTUnwrap(completion)(.alertFirstButtonReturn)
            XCTAssertEqual(f.store.writes, 1)
            XCTAssertEqual(f.store.value.alias(for: f.records[1]), "Changed Alias")
            // The native completion gate rejects duplicate delivery without another save.
            completion?(.alertFirstButtonReturn)
            XCTAssertEqual(f.store.writes, 1)
            try f.action(f.item("management.clearAlias", from: f.menu()))
            XCTAssertEqual(f.store.writes, 2)
            XCTAssertNil(f.store.value.alias(for: f.records[1]))
            XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
        }
    }

    private func waitForRestore(_ f: Fixture) async {
        for _ in 0..<1000 { if !f.host.isRestoringLayout { return }; await Task.yield() }
        XCTFail("Bounded restore did not finish")
    }

    func testOldAssignmentCannotCrossIdenticalLayoutWriterReplacementButFreshMenuCan() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let originalStore = Store(f.layout)
        f.host.installLayoutStore(originalStore)
        await waitForRestore(f)
        func assignment(_ menu: NSMenu) throws -> NSMenuItem {
            let submenu = try XCTUnwrap(f.item("management.organization", from: menu).submenu)
            return try XCTUnwrap(submenu.items.first { $0.identifier?.rawValue == "folderAssignment.moveToFolder" })
        }
        let old = try assignment(f.menu())
        let controller = try XCTUnwrap(old.target as? AppFolderAssignmentMenuController)
        let apply = try XCTUnwrap(controller.onApply)
        let replacementStore = Store(f.layout)
        f.host.installLayoutStore(replacementStore)
        await waitForRestore(f)
        XCTAssertEqual(f.host.currentPersistentLayout(), f.layout)
        try f.action(old)
        // Even a caller with valid identity/snapshot cannot bypass the writer-origin epoch.
        XCTAssertEqual(apply(f.records[1], .moveToFolder(f.folder), f.layout, { true }), .cancelled)
        XCTAssertEqual(f.host.currentPersistentLayout(), f.layout)
        XCTAssertEqual(f.sheets, 0)
        let oldWrites = await originalStore.enqueued
        let replacementWritesBefore = await replacementStore.enqueued
        XCTAssertTrue(oldWrites.isEmpty)
        XCTAssertTrue(replacementWritesBefore.isEmpty)
        try f.action(assignment(f.menu()))
        for _ in 0..<1000 {
            if await replacementStore.enqueued.count == 1 { break }
            await Task.yield()
        }
        let current = try XCTUnwrap(f.host.currentPersistentLayout())
        XCTAssertNotEqual(current, f.layout)
        XCTAssertEqual(current.folder(id: f.folder)?.members.last, .from(record: f.records[1]))
        let writes = await replacementStore.enqueued
        XCTAssertEqual(writes, [current])
        let originalWritesAfter = await originalStore.enqueued
        XCTAssertTrue(originalWritesAfter.isEmpty)
    }
    private actor LibraryStore: AppLibraryPersisting {
        func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
        func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
    }

    func testOldLibraryFolderSheetCannotCrossIdenticalWriterReplacement() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let first = Store(f.layout)
        f.host.installLayoutStore(first)
        await waitForRestore(f)
        f.host.installAppLibrary(in: f.root, store: LibraryStore())
        let owner = try XCTUnwrap(f.host.appLibraryOwner)
        defer { owner.teardown() }
        await owner.preferences.loadIfNeeded()
        owner.canTransition = { true }
        owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        XCTAssertTrue(owner.enter())
        var callbacks: [(NSApplication.ModalResponse) -> Void] = []
        f.host.applicationSheetPresenter = { alert, _, completion in
            guard let popup = alert.accessoryView as? NSPopUpButton,
                  let destination = popup.itemArray.first(where: {
                      ($0.representedObject as? FolderAssignmentAction) == .moveToFolder(f.folder)
                  }) else { return XCTFail("A fresh sheet must retain the canonical destination") }
            popup.select(destination)
            callbacks.append(completion)
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        var request = AppLibraryActionRequest(record: f.records[1], catalogRevision: .init(7), generation: owner.actionGeneration)
        // Initial preference/catalog fanout can retire the first projection.
        // Make that contract-valid generation change deterministic here.
        owner.catalogDidCommit()
        XCTAssertNotEqual(request.generation, owner.actionGeneration)
        XCTAssertNil(owner.resolve(request))
        while owner.resolve(request) == nil, ContinuousClock.now < deadline {
            request = AppLibraryActionRequest(record: f.records[1], catalogRevision: .init(7), generation: owner.actionGeneration)
            if owner.resolve(request) == nil { await Task.yield() }
        }
        XCTAssertEqual(request.generation, owner.actionGeneration)
        XCTAssertNotNil(owner.resolve(request))
        owner.view?.onFolderAssignment?(request)
        XCTAssertEqual(callbacks.count, 1)
        let replacement = Store(f.layout)
        f.host.installLayoutStore(replacement)
        await waitForRestore(f)
        try XCTUnwrap(callbacks.first)(.alertFirstButtonReturn)
        let oldWrites = await first.enqueued, newWrites = await replacement.enqueued
        XCTAssertTrue(oldWrites.isEmpty)
        XCTAssertTrue(newWrites.isEmpty)
        XCTAssertEqual(f.host.currentPersistentLayout(), f.layout)
        request = .init(record: f.records[1], catalogRevision: .init(7), generation: owner.actionGeneration)
        owner.view?.onFolderAssignment?(request)
        XCTAssertEqual(callbacks.count, 2)
        callbacks[1](.alertFirstButtonReturn)
        let freshDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await replacement.enqueued.isEmpty, ContinuousClock.now < freshDeadline { await Task.yield() }
        let freshWrites = await replacement.enqueued
        XCTAssertEqual(freshWrites.count, 1)
        XCTAssertEqual(f.host.currentPersistentLayout()?.folder(id: f.folder)?.members.last, .from(record: f.records[1]))
    }

    private func prepareLibrary(_ fixture: Fixture, store: Store) async throws -> AppLibraryOwnerController {
        fixture.host.installLayoutStore(store)
        await waitForRestore(fixture)
        fixture.host.installAppLibrary(in: fixture.root, store: LibraryStore())
        let owner = try XCTUnwrap(fixture.host.appLibraryOwner)
        await owner.preferences.loadIfNeeded()
        owner.canTransition = { true }
        owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        XCTAssertTrue(owner.enter())
        return owner
    }

    private func currentLibraryRequest(_ fixture: Fixture, owner: AppLibraryOwnerController) async throws -> AppLibraryActionRequest {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        repeat {
            let request = AppLibraryActionRequest(record: fixture.records[1], catalogRevision: .init(7),
                                                  generation: owner.actionGeneration)
            if owner.resolve(request) != nil { return request }
            await Task.yield()
        } while ContinuousClock.now < deadline
        XCTFail("The actual Library owner did not publish the controlled catalog")
        throw NSError(domain: "LibraryFolderChoices", code: 1)
    }

    func testLibraryFolderChoicesUseCanonicalOrderOwnerExclusionAndCollisionSafeTitles() async throws {
        let source = FolderID(), first = FolderID(), second = FolderID(), literal = FolderID()
        let f = try Fixture(layoutBuilder: { records, _ in
            .init(generation: LayoutGeneration(4),
                topLevelOrder: [.folder(second), .folder(literal), .folder(first), .folder(source)],
                folders: [
                    .init(id: source, title: "Same", members: [.from(record: records[1]), .bundleID("fixture.choices.source")]),
                    .init(id: first, title: "Same", members: [.from(record: records[0]), .bundleID("fixture.choices.first")]),
                    .init(id: second, title: "Same", members: [.from(record: records[2]), .bundleID("fixture.choices.second")]),
                    .init(id: literal, title: "Same (1)", members: [.bundleID("fixture.choices.latent1"), .bundleID("fixture.choices.latent2")])])
        })
        defer { f.teardown() }
        let writer = Store(f.layout), owner = try await prepareLibrary(f, store: writer)
        defer { owner.teardown() }
        var captured: NSAlert?, completion: ((NSApplication.ModalResponse) -> Void)?
        f.host.applicationSheetPresenter = { alert, _, callback in captured = alert; completion = callback }
        owner.view?.onFolderAssignment?(try await currentLibraryRequest(f, owner: owner))
        let popup = try XCTUnwrap(captured?.accessoryView as? NSPopUpButton)
        let expected: [FolderAssignmentAction] = [.moveToFolder(second), .moveToFolder(literal),
                                                 .moveToFolder(first), .moveToTopLevel]
        let actions = popup.itemArray.filter { !$0.isSeparatorItem }
        XCTAssertEqual(actions.count, 4)
        XCTAssertEqual(actions.map { $0.representedObject as? FolderAssignmentAction }, expected.map(Optional.some))
        XCTAssertEqual(actions.map(\.title), ["Same (2)", "Same (1)", "Same (3)", "Move to Main Page"])
        XCTAssertEqual(Set(actions.map(\.title)).count, actions.count)
        XCTAssertEqual(popup.accessibilityLabel(), "Move to Folder")
        try XCTUnwrap(completion)(.alertSecondButtonReturn)
        XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
        let writes = await writer.enqueued
        XCTAssertTrue(writes.isEmpty)
        XCTAssertEqual(f.host.currentPersistentLayout(), f.layout)
    }

    func testLibraryFolderChoiceCommitsStableIDOnceAndPreservesDissolvedSourcePosition() async throws {
        let destination = FolderID()
        let f = try Fixture(layoutBuilder: { records, source in
            .init(generation: LayoutGeneration(4), topLevelOrder: [.folder(destination), .folder(source)],
                folders: [
                    .init(id: source, title: "Same", members: [.from(record: records[1]), .from(record: records[0])]),
                    .init(id: destination, title: "Same", members: [.from(record: records[2]), .bundleID("fixture.choices.missing")])])
        })
        defer { f.teardown() }
        let writer = Store(f.layout), owner = try await prepareLibrary(f, store: writer)
        defer { owner.teardown() }
        var completion: ((NSApplication.ModalResponse) -> Void)?
        f.host.applicationSheetPresenter = { alert, _, callback in
            guard let popup = alert.accessoryView as? NSPopUpButton,
                  let selected = popup.itemArray.first(where: {
                      ($0.representedObject as? FolderAssignmentAction) == .moveToFolder(destination)
                  }) else { return XCTFail("Expected a stable destination ID") }
            selected.title = "Changed presentation only"
            popup.select(selected)
            completion = callback
        }
        owner.view?.onFolderAssignment?(try await currentLibraryRequest(f, owner: owner))
        let finish = try XCTUnwrap(completion)
        finish(.alertFirstButtonReturn)
        finish(.alertFirstButtonReturn)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await writer.enqueued.isEmpty, ContinuousClock.now < deadline { await Task.yield() }
        let current = try XCTUnwrap(f.host.currentPersistentLayout())
        XCTAssertEqual(current.folder(id: destination)?.members,
                       [.from(record: f.records[2]), .bundleID("fixture.choices.missing"), .from(record: f.records[1])])
        XCTAssertNil(current.folder(id: f.folder))
        XCTAssertEqual(current.topLevelOrder, [.folder(destination), .app(.from(record: f.records[0]))])
        let writes = await writer.enqueued
        XCTAssertEqual(writes, [current])
    }

    func testLibraryTopLevelAppOffersOnlyRealFolderDestinations() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let writer = Store(f.layout), owner = try await prepareLibrary(f, store: writer)
        defer { owner.teardown() }
        var captured: NSAlert?, completion: ((NSApplication.ModalResponse) -> Void)?
        f.host.applicationSheetPresenter = { alert, _, callback in captured = alert; completion = callback }
        owner.view?.onFolderAssignment?(try await currentLibraryRequest(f, owner: owner))
        let popup = try XCTUnwrap(captured?.accessoryView as? NSPopUpButton)
        XCTAssertEqual(popup.itemTitles, ["User Folder"])
        XCTAssertEqual(popup.itemArray.map { $0.representedObject as? FolderAssignmentAction },
                       [Optional.some(.moveToFolder(f.folder))])
        try XCTUnwrap(completion)(.alertSecondButtonReturn)
        let writes = await writer.enqueued
        XCTAssertTrue(writes.isEmpty)
    }

    func testLibraryWithoutAnyAssignmentChoiceDoesNotPresentOrAcquireModalOwnership() async throws {
        let f = try Fixture(layoutBuilder: { records, _ in
            .init(generation: LayoutGeneration(4), topLevelOrder: records.map { .app(.from(record: $0)) }, folders: [])
        })
        defer { f.teardown() }
        let writer = Store(f.layout), owner = try await prepareLibrary(f, store: writer)
        defer { owner.teardown() }
        var sheets = 0
        f.host.applicationSheetPresenter = { _, _, _ in sheets += 1 }
        owner.view?.onFolderAssignment?(try await currentLibraryRequest(f, owner: owner))
        XCTAssertEqual(sheets, 0)
        XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
        let writes = await writer.enqueued
        XCTAssertTrue(writes.isEmpty)
    }

    func testLibraryFolderTitleMatchingMoveOutLabelKeepsBothStableActions() async throws {
        let destination = FolderID()
        let f = try Fixture(layoutBuilder: { records, source in
            .init(generation: LayoutGeneration(4), topLevelOrder: [.folder(destination), .folder(source)],
                folders: [
                    .init(id: source, title: "Owner", members: [.from(record: records[1]), .from(record: records[0])]),
                    .init(id: destination, title: "Move to Main Page",
                          members: [.from(record: records[2]), .bundleID("fixture.choices.reserved")])])
        })
        defer { f.teardown() }
        let writer = Store(f.layout), owner = try await prepareLibrary(f, store: writer)
        defer { owner.teardown() }
        var captured: NSAlert?, completion: ((NSApplication.ModalResponse) -> Void)?
        f.host.applicationSheetPresenter = { alert, _, callback in captured = alert; completion = callback }
        owner.view?.onFolderAssignment?(try await currentLibraryRequest(f, owner: owner))
        let popup = try XCTUnwrap(captured?.accessoryView as? NSPopUpButton)
        let actions = popup.itemArray.filter { !$0.isSeparatorItem }
        XCTAssertEqual(actions.map { $0.representedObject as? FolderAssignmentAction },
                       [Optional.some(.moveToFolder(destination)), Optional.some(.moveToTopLevel)])
        XCTAssertEqual(actions.map(\.title), ["Move to Main Page", "Move to Main Page"])
        XCTAssertTrue(popup.itemArray.contains(where: \.isSeparatorItem))
        XCTAssertEqual(popup.selectedItem?.representedObject as? FolderAssignmentAction, .moveToFolder(destination))
        try XCTUnwrap(completion)(.alertSecondButtonReturn)
        let writes = await writer.enqueued
        XCTAssertTrue(writes.isEmpty)
    }

}
