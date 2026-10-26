import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import PagingUI
import XCTest
@testable import PagingPrototypeApp

/// Synthetic in-memory owner only. Selectors are invoked directly on their
/// explicit targets; no menu display, workspace calls, input events or store I/O.
@MainActor
final class AppFolderAssignmentMenuTests: XCTestCase {
    private static let firstID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000091")!)
    private static let secondID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000092")!)
    private static let thirdID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000093")!)
    private static let fourthID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000094")!)
    private static let peer = PersistentAppReference.bundleID("fixture.assignment.peer")
    private static let missing = PersistentAppReference.bundleID("fixture.assignment.missing")
    private static let hidden = PersistentAppReference.bundleID("fixture.assignment.hidden")
    private static let before = PersistentAppReference.bundleID("fixture.assignment.before")
    private static let after = PersistentAppReference.bundleID("fixture.assignment.after")

    private static func record(name: String = "Original", path: String = "/SyntheticApps/Original.app",
                               bundleID: String? = "fixture.assignment.original",
                               identity: String = "fixture.assignment.original") -> AppRecord {
        let id = CatalogFixture.appID(identity)
        return CatalogFixture.record(id: id, displayName: name, bundleID: bundleID,
                                     url: URL(fileURLWithPath: path), icon: .from(appID: id), rootPriority: 0)
    }

    private static func token(_ identity: AnyHashable?, revision: UInt64 = 1,
                              pageRevision: UInt64 = 1, page: Int = 0, slot: Int = 0,
                              reuse: UInt64 = 1, surface: UInt64 = 1, icon: IconKey? = nil) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: revision,
                         pageIdentity: PagePresentationID(revision: pageRevision, pageIndex: page),
                         itemSlot: slot, appID: identity, reuseGeneration: reuse,
                         iconKey: icon, surfaceGeneration: surface)
    }

    private static func topLevelLayout(record: AppRecord? = nil) -> PersistentWorkspaceLayout {
        let canonical = record ?? Self.record()
        return PersistentWorkspaceLayout(generation: LayoutGeneration(7),
                                  topLevelOrder: [.app(before), .app(.from(record: canonical)),
                                                 .folder(firstID), .app(after)],
                                  folders: [PersistentFolderRecord(id: firstID, title: "Group",
                                                                   members: [hidden, missing])])
    }

    private static func memberLayout(dissolving: Bool = false) -> PersistentWorkspaceLayout {
        let members: [PersistentAppReference] = dissolving
            ? [.from(record: record()), missing]
            : [.from(record: record()), peer, missing]
        return PersistentWorkspaceLayout(generation: LayoutGeneration(7),
                                         topLevelOrder: [.app(before), .folder(firstID),
                                                        .app(after), .folder(secondID)],
                                         folders: [PersistentFolderRecord(id: secondID, title: "Destination",
                                                                          members: [hidden, .bundleID("fixture.assignment.other")]),
                                                   PersistentFolderRecord(id: firstID, title: "Owner", members: members)])
    }

    @MainActor
    private final class Fixture {
        var currentRecord: AppRecord? = AppFolderAssignmentMenuTests.record()
        var revision: UInt64? = 1
        var layout: PersistentWorkspaceLayout?
        var hidden = false
        var readOnly = false
        var canApply = true
        var cell: AppGridCellView? = AppGridCellView(frame: .zero)
        var receivedActions: [FolderAssignmentAction] = []
        var receivedRecords: [AppRecord] = []
        var receivedSnapshots: [PersistentWorkspaceLayout] = []
        var rejected: [LayoutMutationResult] = []
        var results: [LayoutMutationResult] = []
        var callbackResult: LayoutMutationResult?
        var beforeApply: (() -> Void)?
        // These counters model the owner's success-only commit contract; they
        // do not claim coverage of the real AppDelegate or persistence store.
        var commits = 0
        var enqueues = 0
        var refreshes = 0
        lazy var controller: AppFolderAssignmentMenuController = {
            let controller = AppFolderAssignmentMenuController(
                currentLayoutProvider: { [weak self] in self?.layout },
                recordProvider: { [weak self] id in
                    guard let record = self?.currentRecord, record.id == id else { return nil }
                    return record
                }, revisionProvider: { [weak self] in self?.revision },
                hiddenProvider: { [weak self] _ in self?.hidden ?? true })
            controller.isReadOnlyProvider = { [weak self] in self?.readOnly ?? true }
            controller.canApplyProvider = { [weak self] in self?.canApply ?? false }
            controller.onApply = { [weak self] record, action, expected, _ in
                guard let self else { return .cancelled }
                self.receivedActions.append(action)
                self.receivedRecords.append(record)
                self.receivedSnapshots.append(expected)
                self.beforeApply?()
                guard !self.readOnly, self.canApply, !self.hidden, let current = self.layout else {
                    return .cancelled
                }
                let result = self.callbackResult ?? FolderAssignmentPolicy.apply(
                    action: action, record: record, expectedLayout: expected, currentLayout: current)
                self.results.append(result)
                if case .success(let updated) = result {
                    self.layout = updated
                    self.commits += 1
                    self.enqueues += 1
                    self.refreshes += 1
                }
                return result
            }
            controller.onRejected = { [weak self] in self?.rejected.append($0) }
            return controller
        }()

        init(layout: PersistentWorkspaceLayout? = nil) {
            self.layout = layout ?? AppFolderAssignmentMenuTests.topLevelLayout()
            let record = AppFolderAssignmentMenuTests.record()
            cell?.bind(name: "Presentation alias", token: AppFolderAssignmentMenuTests.token(AnyHashable(record.id)))
        }

        func menu() throws -> NSMenu {
            try XCTUnwrap(controller.menu(for: XCTUnwrap(cell), record: XCTUnwrap(currentRecord), revision: 1))
        }
    }

    private func moveInItems(_ menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter { $0.identifier?.rawValue == "folderAssignment.moveToFolder" }
    }

    private func moveIn(_ menu: NSMenu, index: Int = 0) throws -> NSMenuItem {
        let items = moveInItems(menu)
        guard items.indices.contains(index) else {
            XCTFail("Missing existing-folder menu item")
            throw NSError(domain: "FolderAssignmentFixture", code: 1)
        }
        return items[index]
    }

    private func moveOut(_ menu: NSMenu) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "folderAssignment.moveToTopLevel" })
    }

    private func invoke(_ item: NSMenuItem) throws {
        let target = try XCTUnwrap(item.target as? NSObject)
        let selector = try XCTUnwrap(item.action)
        guard target.responds(to: selector) else {
            XCTFail("Menu target must implement the actual selector")
            return
        }
        _ = target.perform(selector, with: item)
    }

    private func invokeAll(_ menu: NSMenu) throws {
        for item in menu.items where !item.isSeparatorItem { try invoke(item) }
    }

    private func assertNoCommit(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(fixture.commits, 0, file: file, line: line)
        XCTAssertEqual(fixture.enqueues, 0, file: file, line: line)
        XCTAssertEqual(fixture.refreshes, 0, file: file, line: line)
    }

    private func assertNotDispatched(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(fixture.receivedActions.isEmpty, file: file, line: line)
        assertNoCommit(fixture, file: file, line: line)
    }

    func testDefaultNoFolderMenuIsAbsentAndCannotCreateFolder() throws {
        let record = Self.record()
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.app(.from(record: record))], folders: [])
        let fixture = Fixture(layout: layout)
        XCTAssertNil(fixture.controller.menu(for: try XCTUnwrap(fixture.cell), record: record, revision: 1))
        XCTAssertEqual(fixture.layout, layout)
        assertNotDispatched(fixture)
    }

    func testMoveInSelectorAppendsToCanonicalHiddenMissingFolderAndCommitsOnce() throws {
        let fixture = Fixture()
        let expected = try XCTUnwrap(fixture.layout)
        let menu = try fixture.menu()
        XCTAssertFalse(menu.autoenablesItems)
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertTrue(try moveIn(menu).isEnabled)
        try invoke(moveIn(menu))
        let updated = try XCTUnwrap(fixture.layout)
        XCTAssertEqual(updated.folder(id: Self.firstID)?.members, [Self.hidden, Self.missing, .from(record: Self.record())])
        XCTAssertEqual(updated.topLevelOrder, [.app(Self.before), .folder(Self.firstID), .app(Self.after)])
        XCTAssertEqual(updated.generation, expected.generation.incremented())
        XCTAssertEqual(fixture.receivedActions, [.moveToFolder(Self.firstID)])
        XCTAssertEqual(fixture.receivedRecords, [Self.record()])
        XCTAssertEqual(fixture.receivedSnapshots, [expected])
        XCTAssertEqual(fixture.commits, 1)
        XCTAssertEqual(fixture.enqueues, 1)
        XCTAssertEqual(fixture.refreshes, 1)
        XCTAssertEqual(fixture.revision, 1)
        XCTAssertTrue(fixture.rejected.isEmpty)
        // A second delivery from the same retained menu is stale.
        try invoke(moveIn(menu))
        XCTAssertEqual(fixture.receivedActions.count, 1)
        XCTAssertEqual(fixture.enqueues, 1)
        XCTAssertEqual(fixture.rejected.count, 1)
    }

    func testMemberMenuExcludesOwnerAndIncludesSeparatedMoveOut() throws {
        let fixture = Fixture(layout: Self.memberLayout())
        let menu = try fixture.menu()
        XCTAssertEqual(moveInItems(menu).map(\.title), ["Destination"])
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(try moveOut(menu).title, "移到主页面")
    }

    func testCrossFolderSelectorPreservesSourceMembersAndAppendsToDestination() throws {
        let fixture = Fixture(layout: Self.memberLayout())
        let expected = try XCTUnwrap(fixture.layout)
        try invoke(moveIn(fixture.menu()))
        let updated = try XCTUnwrap(fixture.layout)
        XCTAssertEqual(updated.folder(id: Self.firstID)?.members, [Self.peer, Self.missing])
        XCTAssertEqual(updated.folder(id: Self.secondID)?.members,
                       [Self.hidden, .bundleID("fixture.assignment.other"), .from(record: Self.record())])
        XCTAssertEqual(updated.topLevelOrder, expected.topLevelOrder)
        XCTAssertEqual(updated.generation, expected.generation.incremented())
        XCTAssertEqual(fixture.receivedActions, [.moveToFolder(Self.secondID)])
        XCTAssertEqual(fixture.enqueues, 1)
    }

    func testCrossFolderSelectorAtomicallyDissolvesTwoMemberSource() throws {
        let fixture = Fixture(layout: Self.memberLayout(dissolving: true))
        let expected = try XCTUnwrap(fixture.layout)
        try invoke(moveIn(fixture.menu()))
        let updated = try XCTUnwrap(fixture.layout)
        XCTAssertNil(updated.folder(id: Self.firstID))
        XCTAssertEqual(updated.topLevelOrder, [.app(Self.before), .app(Self.missing), .app(Self.after), .folder(Self.secondID)])
        XCTAssertEqual(updated.folder(id: Self.secondID)?.members.last, PersistentAppReference.from(record: Self.record()))
        XCTAssertEqual(updated.generation, expected.generation.incremented())
        XCTAssertEqual(fixture.enqueues, 1)
    }

    func testMoveOutSelectorInsertsImmediatelyAfterCanonicalOwnerPosition() throws {
        let fixture = Fixture(layout: Self.memberLayout())
        let expected = try XCTUnwrap(fixture.layout)
        try invoke(moveOut(fixture.menu()))
        let updated = try XCTUnwrap(fixture.layout)
        XCTAssertEqual(updated.folder(id: Self.firstID)?.members, [Self.peer, Self.missing])
        XCTAssertEqual(updated.folder(id: Self.secondID), expected.folder(id: Self.secondID))
        XCTAssertEqual(updated.topLevelOrder, [.app(Self.before), .folder(Self.firstID),
                                              .app(.from(record: Self.record())), .app(Self.after), .folder(Self.secondID)])
        XCTAssertEqual(updated.generation, expected.generation.incremented())
        XCTAssertEqual(fixture.receivedActions, [.moveToTopLevel])
        XCTAssertEqual(fixture.enqueues, 1)
    }

    func testMoveOutSelectorDissolvesSourceAndPreservesLatentSurvivorOrder() throws {
        let fixture = Fixture(layout: Self.memberLayout(dissolving: true))
        let expected = try XCTUnwrap(fixture.layout)
        try invoke(moveOut(fixture.menu()))
        let updated = try XCTUnwrap(fixture.layout)
        XCTAssertNil(updated.folder(id: Self.firstID))
        XCTAssertEqual(updated.topLevelOrder, [.app(Self.before), .app(Self.missing),
                                              .app(.from(record: Self.record())), .app(Self.after), .folder(Self.secondID)])
        XCTAssertEqual(updated.generation, expected.generation.incremented())
        XCTAssertEqual(fixture.enqueues, 1)
    }

    func testSoleOwnerFolderStillOffersMoveOutWithoutSeparator() throws {
        let member = Self.memberLayout(dissolving: true)
        let layout = PersistentWorkspaceLayout(generation: member.generation,
                                               topLevelOrder: [.folder(Self.firstID)],
                                               folders: [try XCTUnwrap(member.folder(id: Self.firstID))])
        let fixture = Fixture(layout: layout)
        let menu = try fixture.menu()
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertTrue(moveInItems(menu).isEmpty)
        try invoke(moveOut(menu))
        XCTAssertEqual(fixture.layout?.topLevelOrder, [.app(Self.missing), .app(.from(record: Self.record()))])
        XCTAssertTrue(try XCTUnwrap(fixture.layout).folders.isEmpty)
    }

    func testDuplicateTitlesUseLocalOrdinalButSelectorsUseCanonicalIDs() throws {
        let folders = [PersistentFolderRecord(id: Self.firstID, title: "Same", members: [Self.peer, Self.missing]),
                       PersistentFolderRecord(id: Self.secondID, title: "Same", members: [Self.hidden, Self.after])]
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.folder(Self.secondID), .app(.from(record: Self.record())), .folder(Self.firstID)],
                                               folders: folders)
        for index in 0..<2 {
            let fixture = Fixture(layout: layout)
            let menu = try fixture.menu()
            XCTAssertEqual(moveInItems(menu).map(\.title), ["Same (1)", "Same (2)"])
            let selected = try moveIn(menu, index: index)
            selected.title = "Changed presentation label"
            try invoke(selected)
            let destination = index == 0 ? Self.secondID : Self.firstID
            XCTAssertEqual(fixture.receivedActions, [.moveToFolder(destination)])
            XCTAssertEqual(fixture.layout?.folder(id: destination)?.members.last, PersistentAppReference.from(record: Self.record()))
            XCTAssertEqual(fixture.enqueues, 1)
        }
    }

    func testOrdinalSuffixAvoidsCollisionsWithLiteralUserTitles() throws {
        let folders = [PersistentFolderRecord(id: Self.firstID, title: "Same", members: [Self.peer, Self.missing]),
                       PersistentFolderRecord(id: Self.secondID, title: "Same", members: [Self.hidden, Self.after]),
                       PersistentFolderRecord(id: Self.thirdID, title: "Same (1)", members: [.bundleID("fixture.assignment.x"), .bundleID("fixture.assignment.y")])]
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.app(.from(record: Self.record())), .folder(Self.firstID),
                                                              .folder(Self.secondID), .folder(Self.thirdID)], folders: folders)
        let titles = moveInItems(try Fixture(layout: layout).menu()).map(\.title)
        XCTAssertEqual(titles, ["Same (2)", "Same (3)", "Same (1)"])
        XCTAssertEqual(Set(titles).count, 3)
    }

    func testCanonicalDestinationsIncludeEntirelyLatentGroupsInTopLevelOrder() throws {
        let ordinary = Self.topLevelLayout()
        let latent = PersistentFolderRecord(id: Self.secondID, title: "Latent",
                                            members: [.bundleID("fixture.assignment.absent1"), .bundleID("fixture.assignment.absent2")])
        let unlisted = PersistentFolderRecord(id: Self.thirdID, title: "Not a top-level destination",
                                              members: [.bundleID("fixture.assignment.unlisted1"), .bundleID("fixture.assignment.unlisted2")])
        let layout = PersistentWorkspaceLayout(generation: ordinary.generation,
                                               topLevelOrder: [.folder(Self.secondID)] + ordinary.topLevelOrder,
                                               folders: ordinary.folders + [unlisted, latent])
        let fixture = Fixture(layout: layout)
        let menu = try fixture.menu()
        XCTAssertEqual(moveInItems(menu).map(\.title), ["Latent", "Group"])
        try invoke(moveIn(menu))
        XCTAssertEqual(fixture.receivedActions, [.moveToFolder(Self.secondID)])
        XCTAssertEqual(fixture.layout?.folder(id: Self.firstID), ordinary.folder(id: Self.firstID))
        XCTAssertEqual(fixture.layout?.folder(id: Self.thirdID), unlisted)
        XCTAssertEqual(fixture.layout?.folder(id: Self.secondID)?.members, latent.members + [.from(record: Self.record())])
    }

    func testMenuCreationRejectsUnboundNonAppAndWrongAppTokens() throws {
        let fixture = Fixture()
        let cell = try XCTUnwrap(fixture.cell)
        let record = try XCTUnwrap(fixture.currentRecord)
        cell.clearContent()
        XCTAssertNil(fixture.controller.menu(for: cell, record: record, revision: 1))
        let identities: [AnyHashable?] = [nil, AnyHashable("opaque"), AnyHashable(Self.firstID),
                                         AnyHashable(Self.record(identity: "fixture.assignment.replacement").id)]
        for identity in identities {
            cell.bind(name: "Fixture", token: Self.token(identity))
            XCTAssertNil(fixture.controller.menu(for: cell, record: record, revision: 1))
        }
        assertNotDispatched(fixture)
    }

    func testMenuCreationRejectsUnavailableRecordRevisionLayoutAndHiddenApp() throws {
        for condition in ["record", "revision", "layout", "hidden", "staleToken", "staleArgument", "URL", "reference", "unowned"] {
            let fixture = Fixture()
            let record = try XCTUnwrap(fixture.currentRecord)
            let cell = try XCTUnwrap(fixture.cell)
            var revision: UInt64 = 1
            switch condition {
            case "record": fixture.currentRecord = nil
            case "revision": fixture.revision = nil
            case "layout": fixture.layout = nil
            case "hidden": fixture.hidden = true
            case "staleToken": cell.bind(name: "Stale", token: Self.token(AnyHashable(record.id), revision: 2))
            case "staleArgument": revision = 2
            case "URL": fixture.currentRecord = Self.record(path: "/SyntheticApps/Moved.app")
            case "reference": fixture.currentRecord = Self.record(bundleID: "fixture.assignment.changed")
            default: fixture.layout = PersistentWorkspaceLayout()
            }
            XCTAssertNil(fixture.controller.menu(for: cell, record: record, revision: revision), condition)
            assertNotDispatched(fixture)
        }
    }

    func testProviderReturningWrongIdentityCannotBuildOrDispatchMenu() throws {
        let fixture = Fixture()
        let menu = try fixture.menu()
        let replacement = Self.record(identity: "fixture.assignment.replacement")
        fixture.controller.recordProvider = { _ in replacement }
        XCTAssertNil(fixture.controller.menu(for: try XCTUnwrap(fixture.cell), record: Self.record(), revision: 1))
        try invokeAll(menu)
        assertNotDispatched(fixture)
    }

    func testEveryTokenFieldRejectsAllRetainedSelectors() throws {
        let record = Self.record()
        let id = AnyHashable(record.id)
        let tokens = [Self.token(id, revision: 2), Self.token(id, pageRevision: 2),
                      Self.token(id, page: 1), Self.token(id, slot: 1),
                      Self.token(AnyHashable(Self.record(identity: "fixture.assignment.replacement").id)),
                      Self.token(id, reuse: 2), Self.token(id, surface: 2),
                      Self.token(id, icon: IconKey(identity: record.iconIdentity, pointSize: 48, displayScale: 2))]
        for token in tokens {
            let fixture = Fixture(layout: Self.memberLayout())
            let expected = fixture.layout
            let menu = try fixture.menu()
            try XCTUnwrap(fixture.cell).bind(name: "Reused", token: token)
            try invokeAll(menu)
            assertNotDispatched(fixture)
            XCTAssertEqual(fixture.layout, expected)
            XCTAssertEqual(fixture.rejected.count, 2)
        }
    }

    func testClearedAndReleasedCellsRejectAllRetainedSelectors() throws {
        let cleared = Fixture(layout: Self.memberLayout())
        let menu = try cleared.menu()
        cleared.cell?.clearContent()
        try invokeAll(menu)
        assertNotDispatched(cleared)

        weak var weakCell: AppGridCellView?
        let (released, retainedMenu) = try autoreleasepool {
            let fixture = Fixture(layout: Self.memberLayout())
            let menu = try fixture.menu()
            weakCell = fixture.cell
            fixture.cell = nil
            return (fixture, menu)
        }
        XCTAssertNil(weakCell, "Menu bindings must retain only a weak cell")
        try invokeAll(retainedMenu)
        assertNotDispatched(released)
        XCTAssertEqual(released.rejected.count, 2)
    }

    func testChangedOrUnavailableCatalogRevisionRejectsAllSelectors() throws {
        for revision: UInt64? in [2, nil] {
            let fixture = Fixture(layout: Self.memberLayout())
            let menu = try fixture.menu()
            fixture.revision = revision
            try invokeAll(menu)
            assertNotDispatched(fixture)
        }
    }

    func testRemovedMovedHiddenAndChangedPersistentReferenceRejectSelectors() throws {
        for condition in ["removed", "moved", "hidden", "reference"] {
            let fixture = Fixture(layout: Self.memberLayout())
            let expected = fixture.layout
            let menu = try fixture.menu()
            switch condition {
            case "removed": fixture.currentRecord = nil
            case "moved": fixture.currentRecord = Self.record(path: "/SyntheticApps/Moved.app")
            case "hidden": fixture.hidden = true
            default: fixture.currentRecord = Self.record(bundleID: "fixture.assignment.changed")
            }
            try invokeAll(menu)
            assertNotDispatched(fixture)
            XCTAssertEqual(fixture.layout, expected)
        }
    }

    func testLatestCanonicalMetadataIsDeliveredWithoutUsingAliasAsIdentity() throws {
        let fixture = Fixture()
        let menu = try fixture.menu()
        let latest = Self.record(name: "Latest canonical name")
        fixture.currentRecord = latest
        try invoke(moveIn(menu))
        XCTAssertEqual(fixture.receivedRecords, [latest])
        XCTAssertEqual(fixture.receivedActions, [.moveToFolder(Self.firstID)])
        XCTAssertEqual(fixture.enqueues, 1)
    }

    func testLayoutGenerationChangeRejectsBeforeOwnerCallback() throws {
        let fixture = Fixture(layout: Self.memberLayout())
        let expected = try XCTUnwrap(fixture.layout)
        let menu = try fixture.menu()
        let changed = PersistentWorkspaceLayout(generation: expected.generation.incremented(),
                                                topLevelOrder: expected.topLevelOrder, folders: expected.folders)
        fixture.layout = changed
        try invokeAll(menu)
        assertNotDispatched(fixture)
        XCTAssertEqual(fixture.layout, changed)
        XCTAssertEqual(fixture.rejected, Array(repeating: .rejected(.staleGeneration(
            expected: expected.generation, current: changed.generation)), count: 2))
    }

    func testFullSnapshotRejectsSameGenerationReorderRenameMembershipAndRemoval() throws {
        let expected = Self.memberLayout()
        let owner = try XCTUnwrap(expected.folder(id: Self.firstID))
        let target = try XCTUnwrap(expected.folder(id: Self.secondID))
        let renamed = PersistentFolderRecord(id: target.id, title: "Renamed", members: target.members)
        let changedMembers = PersistentFolderRecord(id: target.id, title: target.title, members: Array(target.members.reversed()))
        let changedLayouts = [
            PersistentWorkspaceLayout(generation: expected.generation, topLevelOrder: Array(expected.topLevelOrder.reversed()), folders: expected.folders),
            PersistentWorkspaceLayout(generation: expected.generation, topLevelOrder: expected.topLevelOrder, folders: [renamed, owner]),
            PersistentWorkspaceLayout(generation: expected.generation, topLevelOrder: expected.topLevelOrder, folders: [changedMembers, owner]),
            PersistentWorkspaceLayout(generation: expected.generation, topLevelOrder: expected.topLevelOrder, folders: Array(expected.folders.reversed())),
            PersistentWorkspaceLayout(generation: expected.generation,
                                      topLevelOrder: expected.topLevelOrder.filter { $0 != .folder(target.id) }, folders: [owner])
        ]
        for changed in changedLayouts {
            let fixture = Fixture(layout: expected)
            let menu = try fixture.menu()
            fixture.layout = changed
            try invokeAll(menu)
            assertNotDispatched(fixture)
            XCTAssertEqual(fixture.layout, changed)
            XCTAssertEqual(fixture.rejected, [.rejected(.invalidTarget), .rejected(.invalidTarget)])
        }
    }

    func testUnavailableLayoutAfterMenuBuildRejectsSelectors() throws {
        let fixture = Fixture(layout: Self.memberLayout())
        let menu = try fixture.menu()
        fixture.layout = nil
        try invokeAll(menu)
        assertNotDispatched(fixture)
    }

    func testReadOnlyAndInteractionProtectionDisableItemsAndRejectDirectSelectors() throws {
        for protection in ["readOnly", "activeInteraction"] {
            let fixture = Fixture(layout: Self.memberLayout())
            if protection == "readOnly" { fixture.readOnly = true } else { fixture.canApply = false }
            let menu = try fixture.menu()
            for item in menu.items where !item.isSeparatorItem { XCTAssertFalse(item.isEnabled) }
            // Disabled presentation is not the security boundary: direct selectors
            // must independently re-read the injected protection providers.
            try invokeAll(menu)
            assertNotDispatched(fixture)
            XCTAssertEqual(fixture.rejected, [.cancelled, .cancelled])
        }
    }

    func testProtectionIsRevalidatedAfterWritableMenuWasBuilt() throws {
        // Main maps drag, title edit and teardown to this one synchronous predicate.
        for protection in ["layoutReadOnly", "drag", "titleEdit", "teardown"] {
            let fixture = Fixture(layout: Self.memberLayout())
            let menu = try fixture.menu()
            for item in menu.items where !item.isSeparatorItem { XCTAssertTrue(item.isEnabled) }
            if protection == "layoutReadOnly" { fixture.readOnly = true } else { fixture.canApply = false }
            try invokeAll(menu)
            assertNotDispatched(fixture)
            XCTAssertEqual(fixture.rejected, [.cancelled, .cancelled])
        }
    }

    func testFutureAppManagementSchemaUsesNeutralPreferencesAndIndependentLayoutProtection() throws {
        // Use the real load-result fallback without constructing/loading a store.
        let preferences = AppManagementLoadResult.futureVersion(99).preferences
        XCTAssertEqual(preferences, .default)
        for layoutProtected in [false, true] {
            let fixture = Fixture()
            fixture.readOnly = layoutProtected
            fixture.controller.hiddenProvider = { preferences.isHidden($0) }
            let menu = try fixture.menu()
            XCTAssertEqual(try moveIn(menu).isEnabled, !layoutProtected)
            try invoke(moveIn(menu))
            if layoutProtected {
                assertNotDispatched(fixture)
                XCTAssertEqual(fixture.rejected, [.cancelled])
            } else {
                XCTAssertEqual(fixture.receivedActions, [.moveToFolder(Self.firstID)])
                XCTAssertEqual(fixture.enqueues, 1)
                XCTAssertTrue(fixture.rejected.isEmpty)
            }
        }
    }

    func testMissingApplyCallbackIsDisabledAndCannotCommit() throws {
        let fixture = Fixture()
        fixture.controller.onApply = nil
        let menu = try fixture.menu()
        XCTAssertFalse(try moveIn(menu).isEnabled)
        try invoke(moveIn(menu))
        assertNotDispatched(fixture)
        XCTAssertEqual(fixture.rejected, [.cancelled])
    }

    func testOwnerNoOpProducesZeroCommitEnqueueRefreshAndNoFeedback() throws {
        let fixture = Fixture()
        let expected = try XCTUnwrap(fixture.layout)
        fixture.callbackResult = .noOp(expected)
        try invoke(moveIn(fixture.menu()))
        XCTAssertEqual(fixture.receivedActions.count, 1)
        XCTAssertEqual(fixture.results, [.noOp(expected)])
        XCTAssertEqual(fixture.layout, expected)
        XCTAssertTrue(fixture.rejected.isEmpty)
        assertNoCommit(fixture)
    }

    func testOwnerRejectionAndCancellationProduceOnlyNeutralFeedback() throws {
        for result: LayoutMutationResult in [.rejected(.invalidTarget), .cancelled] {
            let fixture = Fixture()
            let expected = fixture.layout
            fixture.callbackResult = result
            try invoke(moveIn(fixture.menu()))
            XCTAssertEqual(fixture.receivedActions.count, 1)
            XCTAssertEqual(fixture.rejected, [result])
            XCTAssertEqual(fixture.layout, expected)
            assertNoCommit(fixture)
        }
    }

    func testOwnerRevalidationRejectsChangeBetweenDispatchAndCommit() throws {
        let fixture = Fixture()
        let expected = try XCTUnwrap(fixture.layout)
        let changed = PersistentWorkspaceLayout(generation: expected.generation.incremented(),
                                                topLevelOrder: expected.topLevelOrder, folders: expected.folders)
        fixture.beforeApply = { [weak fixture] in fixture?.layout = changed }
        try invoke(moveIn(fixture.menu()))
        XCTAssertEqual(fixture.receivedSnapshots, [expected])
        XCTAssertEqual(fixture.layout, changed)
        XCTAssertEqual(fixture.rejected, [.rejected(.staleGeneration(expected: expected.generation, current: changed.generation))])
        assertNoCommit(fixture)
    }

    func testOwnerRevalidationRejectsProtectionRaisedDuringDispatch() throws {
        let fixture = Fixture()
        let expected = fixture.layout
        fixture.beforeApply = { [weak fixture] in fixture?.readOnly = true }
        try invoke(moveIn(fixture.menu()))
        XCTAssertEqual(fixture.receivedActions.count, 1)
        XCTAssertEqual(fixture.rejected, [.cancelled])
        XCTAssertEqual(fixture.layout, expected)
        assertNoCommit(fixture)
    }

    func testFeedbackCallbackIsOptionalForRetainedStaleMenu() throws {
        let fixture = Fixture()
        fixture.controller.onRejected = nil
        let menu = try fixture.menu()
        fixture.hidden = true
        try invoke(moveIn(menu))
        assertNotDispatched(fixture)
        XCTAssertTrue(fixture.rejected.isEmpty)
    }

    func testPolicyNoOpsForExistingMemberAndAlreadyTopLevelWithoutGenerationChange() {
        let record = Self.record()
        let memberLayout = Self.memberLayout()
        XCTAssertEqual(FolderAssignmentPolicy.apply(action: .moveToFolder(Self.firstID), record: record,
                                                    expectedLayout: memberLayout, currentLayout: memberLayout), .noOp(memberLayout))
        let topLevel = Self.topLevelLayout()
        XCTAssertEqual(FolderAssignmentPolicy.apply(action: .moveToTopLevel, record: record,
                                                    expectedLayout: topLevel, currentLayout: topLevel), .noOp(topLevel))
    }

    func testPolicyRejectsStaleGenerationAndSameGenerationSnapshotBeforeEitherAction() {
        let expected = Self.memberLayout()
        let newGeneration = PersistentWorkspaceLayout(generation: expected.generation.incremented(),
                                                      topLevelOrder: expected.topLevelOrder, folders: expected.folders)
        let sameGeneration = PersistentWorkspaceLayout(generation: expected.generation,
                                                       topLevelOrder: Array(expected.topLevelOrder.reversed()), folders: expected.folders)
        for action in [FolderAssignmentAction.moveToFolder(Self.firstID), .moveToFolder(Self.secondID), .moveToTopLevel] {
            XCTAssertEqual(FolderAssignmentPolicy.apply(action: action, record: Self.record(),
                                                        expectedLayout: expected, currentLayout: newGeneration),
                           .rejected(.staleGeneration(expected: expected.generation, current: newGeneration.generation)))
            XCTAssertEqual(FolderAssignmentPolicy.apply(action: action, record: Self.record(),
                                                        expectedLayout: expected, currentLayout: sameGeneration), .rejected(.invalidTarget))
        }
    }

    func testPolicyRejectsMissingOrUnlistedTargetAndUnknownApp() {
        let layout = Self.topLevelLayout()
        XCTAssertEqual(FolderAssignmentPolicy.apply(action: .moveToFolder(Self.fourthID), record: Self.record(),
                                                    expectedLayout: layout, currentLayout: layout),
                       .rejected(.folderDoesNotExist(Self.fourthID)))
        let unlisted = PersistentWorkspaceLayout(generation: layout.generation,
                                                 topLevelOrder: layout.topLevelOrder.filter { $0 != .folder(Self.firstID) }, folders: layout.folders)
        XCTAssertEqual(FolderAssignmentPolicy.apply(action: .moveToFolder(Self.firstID), record: Self.record(),
                                                    expectedLayout: unlisted, currentLayout: unlisted), .rejected(.invalidTarget))
        let unknown = Self.record(bundleID: "fixture.assignment.unknown", identity: "fixture.assignment.unknown")
        for action in [FolderAssignmentAction.moveToFolder(Self.firstID), .moveToTopLevel] {
            XCTAssertEqual(FolderAssignmentPolicy.apply(action: action, record: unknown,
                                                        expectedLayout: layout, currentLayout: layout), .rejected(.invalidTarget))
        }
    }

    func testPolicyRejectsMoveOutWhenSourceHasNoCanonicalPosition() {
        let member = Self.memberLayout()
        let layout = PersistentWorkspaceLayout(generation: member.generation,
                                               topLevelOrder: member.topLevelOrder.filter { $0 != .folder(Self.firstID) }, folders: member.folders)
        XCTAssertEqual(FolderAssignmentPolicy.apply(action: .moveToTopLevel, record: Self.record(),
                                                    expectedLayout: layout, currentLayout: layout), .rejected(.invalidTarget))
    }

    func testPolicyUsesNormalizedPersistentPathWhenBundleIdentifierIsMissing() throws {
        let record = Self.record(path: "/SyntheticApps/PathFallback.app", bundleID: nil)
        let layout = Self.topLevelLayout(record: record)
        let fixture = Fixture(layout: layout)
        fixture.currentRecord = record
        let menu = try fixture.menu()
        try invoke(moveIn(menu))
        XCTAssertEqual(fixture.layout?.folder(id: Self.firstID)?.members.last,
                       .canonicalPath("/syntheticapps/pathfallback.app"))
        XCTAssertEqual(fixture.receivedRecords, [record])
        XCTAssertEqual(fixture.enqueues, 1)
    }
}
