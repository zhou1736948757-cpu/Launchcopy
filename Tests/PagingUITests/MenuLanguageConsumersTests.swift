import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import PagingUI
import XCTest
@testable import PagingPrototypeApp

/// Real native menus, never displayed. Invoke only their explicit NSObject targets;
/// no application launch, workspace operation, persistence, input event or run loop.
@MainActor
final class MenuLanguageConsumersTests: XCTestCase {
    private struct ExpectedCopy {
        let language: InterfaceLanguage
        let actions: [String]
        let organization: String
        let assignment: String
        let moveOut: String
    }

    private let copies: [ExpectedCopy] = [
        .init(language: .english,
              actions: ["Open", "Set Alias…", "Restore Original Name", "Hide App", "Show in Finder"],
              organization: "Organize App", assignment: "Move to Folder", moveOut: "Move to Main Page"),
        .init(language: .simplifiedChinese,
              actions: ["打开", "设置别名…", "恢复原名", "隐藏应用", "在 Finder 中显示"],
              organization: "整理应用", assignment: "移动到文件夹", moveOut: "移到主页面"),
        .init(language: .japanese,
              actions: ["開く", "別名を設定…", "元の名前に戻す", "アプリを非表示", "Finderで表示"],
              organization: "アプリを整理", assignment: "フォルダに移動", moveOut: "メインページに移動")
    ]
    private let actionIDs = ["launch", "alias", "clearAlias", "hide", "reveal"]
    private static let ownerID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
    private static let firstID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!)
    private static let secondID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!)
    private static let literalID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!)
    private static let userTitle = "Work 日本語 % %@ {count} 😀"
    private static let destinationTitles = [userTitle + " (2)", userTitle + " (3)", userTitle + " (1)"]

    private static func record(path: String = "/SyntheticApps/MenuLanguage.app",
                               name: String = "Canonical App 日本語 😀") -> AppRecord {
        let bundleID = "fixture.menu.language"
        let id = CatalogFixture.appID(bundleID)
        return CatalogFixture.record(id: id, displayName: name, bundleID: bundleID,
                                     url: URL(fileURLWithPath: path), icon: .from(appID: id), rootPriority: 0)
    }

    private static func token(_ record: AppRecord, reuse: UInt64 = 1) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 1,
                         pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
                         itemSlot: 0, appID: AnyHashable(record.id), reuseGeneration: reuse,
                         iconKey: nil, surfaceGeneration: 1)
    }

    private static func layout(record: AppRecord, isMember: Bool) -> PersistentWorkspaceLayout {
        let peer = PersistentAppReference.bundleID("fixture.menu.language.peer")
        let ownerMembers: [PersistentAppReference] = isMember ? [.from(record: record), peer] :
            [peer, .bundleID("fixture.menu.language.owner.other")]
        let folders = [
            PersistentFolderRecord(id: ownerID, title: "Owner 用户内容", members: ownerMembers),
            PersistentFolderRecord(id: firstID, title: userTitle, members: [.bundleID("fixture.menu.language.first"),
                                                                      .bundleID("fixture.menu.language.first.other")]),
            PersistentFolderRecord(id: secondID, title: userTitle, members: [.bundleID("fixture.menu.language.second"),
                                                                      .bundleID("fixture.menu.language.second.other")]),
            PersistentFolderRecord(id: literalID, title: userTitle + " (1)", members: [.bundleID("fixture.menu.language.literal"),
                                                                      .bundleID("fixture.menu.language.literal.other")])
        ]
        let folderOrder: [WorkspaceTopLevelEntry] = [.folder(ownerID), .folder(firstID),
                                                     .folder(secondID), .folder(literalID)]
        return PersistentWorkspaceLayout(generation: LayoutGeneration(7),
                                         topLevelOrder: isMember ? folderOrder : [.app(.from(record: record))] + folderOrder,
                                         folders: folders)
    }

    @MainActor
    private final class Fixture {
        let cell = AppGridCellView(frame: .zero)
        var currentRecord: AppRecord? = MenuLanguageConsumersTests.record()
        var revision: UInt64? = 1
        var currentLayout: PersistentWorkspaceLayout?
        var displayed: LocalizedStrings?
        var contextReads = 0
        var assignmentReads = 0
        var hidden = false
        var readOnly = false
        var canApply = true
        var delivered: [String] = []
        var deliveredRecords: [AppRecord] = []
        var assignments: [FolderAssignmentAction] = []
        var expectedLayouts: [PersistentWorkspaceLayout] = []
        var rejections: [LayoutMutationResult] = []

        lazy var context: AppContextMenuController = {
            let controller = AppContextMenuController(recordProvider: { [weak self] id in
                guard let record = self?.currentRecord, record.id == id else { return nil }
                return record
            }, revisionProvider: { [weak self] in self?.revision },
               hiddenProvider: { [weak self] _ in self?.hidden ?? true })
            controller.interfaceStringsProvider = { [weak self] in
                self?.contextReads += 1
                return self?.displayed
            }
            controller.isReadOnlyProvider = { [weak self] in self?.readOnly ?? true }
            controller.onLaunch = { [weak self] _ in self?.delivered.append("launch") }
            controller.onAlias = { [weak self] in self?.receive("alias", record: $0) }
            controller.onClearAlias = { [weak self] in self?.receive("clearAlias", record: $0) }
            controller.onHide = { [weak self] in self?.receive("hide", record: $0) }
            controller.onReveal = { [weak self] in self?.receive("reveal", record: $0) }
            controller.organizationMenuProvider = { [weak self] cell, record, revision in
                self?.assignment.menu(for: cell, record: record, revision: revision)
            }
            return controller
        }()

        lazy var assignment: AppFolderAssignmentMenuController = {
            let controller = AppFolderAssignmentMenuController(
                currentLayoutProvider: { [weak self] in self?.currentLayout },
                recordProvider: { [weak self] id in
                    guard let record = self?.currentRecord, record.id == id else { return nil }
                    return record
                }, revisionProvider: { [weak self] in self?.revision },
                hiddenProvider: { [weak self] _ in self?.hidden ?? true })
            controller.interfaceStringsProvider = { [weak self] in
                self?.assignmentReads += 1
                return self?.displayed
            }
            controller.isReadOnlyProvider = { [weak self] in self?.readOnly ?? true }
            controller.canApplyProvider = { [weak self] in self?.canApply ?? false }
            controller.onApply = { [weak self] record, action, expected, validate in
                guard let self, validate() else { return .cancelled }
                self.assignments.append(action)
                self.deliveredRecords.append(record)
                self.expectedLayouts.append(expected)
                // Keep the synthetic owner unchanged so every item can be inspected.
                return .noOp(expected)
            }
            controller.onRejected = { [weak self] in self?.rejections.append($0) }
            return controller
        }()

        init(strings: LocalizedStrings? = nil, isMember: Bool = true) {
            displayed = strings
            let record = MenuLanguageConsumersTests.record()
            currentLayout = MenuLanguageConsumersTests.layout(record: record, isMember: isMember)
            cell.bind(name: "User alias % %@ 日本語 😀", token: MenuLanguageConsumersTests.token(record))
        }

        private func receive(_ action: String, record: AppRecord) {
            delivered.append(action)
            deliveredRecords.append(record)
        }

        func menu() throws -> NSMenu {
            try XCTUnwrap(context.menu(for: cell))
        }

        func assignmentMenu() throws -> NSMenu {
            try XCTUnwrap(assignment.menu(for: cell, record: XCTUnwrap(currentRecord), revision: 1))
        }
    }

    private func item(_ identifier: String, in menu: NSMenu) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == identifier })
    }

    private func submenu(_ menu: NSMenu) throws -> NSMenu {
        try XCTUnwrap(item("management.organization", in: menu).submenu)
    }

    private func invoke(_ item: NSMenuItem) throws {
        let target = try XCTUnwrap(item.target as? NSObject)
        let selector = try XCTUnwrap(item.action)
        guard target.responds(to: selector) else {
            XCTFail("Menu target does not implement its action")
            return
        }
        _ = target.perform(selector, with: item)
    }

    private func invokeActions(_ menu: NSMenu) throws {
        for action in actionIDs { try invoke(item("management.\(action)", in: menu)) }
        for item in try submenu(menu).items where !item.isSeparatorItem { try invoke(item) }
    }

    private func assertCopy(_ expected: ExpectedCopy, menu: NSMenu,
                            file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(Array(menu.items.prefix(5)).map(\.title), expected.actions, file: file, line: line)
        XCTAssertEqual(menu.items.last?.title, expected.organization, file: file, line: line)
        let assignment = try submenu(menu)
        XCTAssertEqual(assignment.title, expected.assignment, file: file, line: line)
        XCTAssertEqual(Array(assignment.items.prefix(3)).map(\.title), Self.destinationTitles, file: file, line: line)
        XCTAssertEqual(assignment.items.count, 5, file: file, line: line)
        XCTAssertEqual(assignment.items.dropFirst(3).first?.isSeparatorItem, true, file: file, line: line)
        XCTAssertEqual(assignment.items.last?.title, expected.moveOut, file: file, line: line)
        for item in menu.items + assignment.items where !item.isSeparatorItem {
            XCTAssertEqual(item.accessibilityLabel(), item.title, file: file, line: line)
            XCTAssertEqual(item.keyEquivalent, "", file: file, line: line)
        }
    }

    func testRealNestedMenusUseAllThreeLanguagesAndExactlyOneSnapshotReadPerGroup() throws {
        for expected in copies {
            let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
            let token = fixture.cell.bindingToken
            let layout = fixture.currentLayout
            let menu = try fixture.menu()
            try assertCopy(expected, menu: menu)
            XCTAssertEqual(fixture.contextReads, 1)
            XCTAssertEqual(fixture.assignmentReads, 1)
            XCTAssertFalse(menu.autoenablesItems)
            XCTAssertFalse(try submenu(menu).autoenablesItems)
            XCTAssertEqual(menu.items.compactMap { $0.identifier?.rawValue },
                           actionIDs.map { "management.\($0)" } + ["management.organization"])
            XCTAssertEqual(try submenu(menu).items.compactMap { $0.identifier?.rawValue },
                           Array(repeating: "folderAssignment.moveToFolder", count: 3) + ["folderAssignment.moveToTopLevel"])
            XCTAssertEqual(fixture.cell.bindingToken, token)
            XCTAssertEqual(fixture.currentLayout, layout)
            XCTAssertTrue(fixture.delivered.isEmpty)
            XCTAssertTrue(fixture.assignments.isEmpty)
        }
    }

    func testNilSnapshotKeepsOriginalChineseCopyAndDefaultProvidersRemainCompatible() throws {
        let fixture = Fixture()
        XCTAssertNil(AppContextMenuController(recordProvider: { _ in nil }, revisionProvider: { nil },
                                             hiddenProvider: { _ in false }).interfaceStringsProvider())
        XCTAssertNil(AppFolderAssignmentMenuController(currentLayoutProvider: { nil }, recordProvider: { _ in nil },
                                                       revisionProvider: { nil }, hiddenProvider: { _ in false }).interfaceStringsProvider())
        let menu = try fixture.menu()
        try assertCopy(copies[1], menu: menu)
        XCTAssertEqual(fixture.contextReads, 1)
        XCTAssertEqual(fixture.assignmentReads, 1)
    }

    func testRetainedMenusAndBindingsFreezeWhileNewMenusUseLatestDisplayedSnapshot() throws {
        let fixture = Fixture(strings: LocalizedStrings(language: .english))
        let oldMenu = try fixture.menu()
        let oldAssignment = try submenu(oldMenu)
        let boundItems = Array(oldMenu.items.prefix(5)) + oldAssignment.items.filter { !$0.isSeparatorItem }
        let bindings = try boundItems.map { try XCTUnwrap($0.representedObject as? NSObject) }
        let targets = try boundItems.map { try XCTUnwrap($0.target as? NSObject) }
        let selectors = try boundItems.map { NSStringFromSelector(try XCTUnwrap($0.action)) }
        let token = fixture.cell.bindingToken
        for expected in [copies[2], copies[1], copies[0]] {
            fixture.displayed = LocalizedStrings(language: expected.language)
            try assertCopy(copies[0], menu: oldMenu)
            let newMenu = try fixture.menu()
            try assertCopy(expected, menu: newMenu)
            for index in boundItems.indices {
                XCTAssertTrue(boundItems[index].representedObject as? NSObject === bindings[index])
                XCTAssertTrue(boundItems[index].target as? NSObject === targets[index])
                XCTAssertEqual(boundItems[index].action.map(NSStringFromSelector), selectors[index])
            }
            XCTAssertEqual(fixture.cell.bindingToken, token)
        }
        XCTAssertEqual(fixture.contextReads, 4)
        XCTAssertEqual(fixture.assignmentReads, 4)
        let replacement = LocalizedStrings(language: .japanese)
        var replacementContextReads = 0
        var replacementAssignmentReads = 0
        fixture.context.interfaceStringsProvider = {
            replacementContextReads += 1
            return replacement
        }
        fixture.assignment.interfaceStringsProvider = {
            replacementAssignmentReads += 1
            return replacement
        }
        try assertCopy(copies[2], menu: fixture.menu())
        try assertCopy(copies[0], menu: oldMenu)
        XCTAssertEqual(replacementContextReads, 1)
        XCTAssertEqual(replacementAssignmentReads, 1)
        try invokeActions(oldMenu)
        XCTAssertEqual(replacementContextReads, 1)
        XCTAssertEqual(replacementAssignmentReads, 1)
        XCTAssertEqual(fixture.delivered, actionIDs)
        XCTAssertEqual(fixture.assignments, [.moveToFolder(Self.firstID), .moveToFolder(Self.secondID),
                                             .moveToFolder(Self.literalID), .moveToTopLevel])
        XCTAssertEqual(fixture.contextReads, 4, "Action delivery must not consult the language provider")
        XCTAssertEqual(fixture.assignmentReads, 4)
    }

    func testProviderIsCapturedOnceEvenWhenItChangesAfterReturningSnapshot() throws {
        let fixture = Fixture()
        var contextCalls = 0
        var assignmentCalls = 0
        fixture.context.interfaceStringsProvider = {
            contextCalls += 1
            return LocalizedStrings(language: contextCalls == 1 ? .english : .japanese)
        }
        fixture.assignment.interfaceStringsProvider = {
            assignmentCalls += 1
            return LocalizedStrings(language: assignmentCalls == 1 ? .english : .japanese)
        }
        let first = try fixture.menu()
        try assertCopy(copies[0], menu: first)
        XCTAssertEqual(contextCalls, 1)
        XCTAssertEqual(assignmentCalls, 1)
        let second = try fixture.menu()
        try assertCopy(copies[2], menu: second)
        try assertCopy(copies[0], menu: first)
        XCTAssertEqual(contextCalls, 2)
        XCTAssertEqual(assignmentCalls, 2)
    }

    func testLanguageDoesNotChangeSelectorsTargetsCanonicalRecordsOrFolderDestinations() throws {
        for expected in copies {
            let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
            let menu = try fixture.menu()
            for item in menu.items.prefix(5) {
                XCTAssertTrue(item.target as? AppContextMenuController === fixture.context)
                XCTAssertEqual(item.action.map(NSStringFromSelector), "handleMenuAction:")
                XCTAssertNotNil(item.representedObject)
                XCTAssertTrue(item.isEnabled)
            }
            let organization = try item("management.organization", in: menu)
            XCTAssertEqual(organization.action.map(NSStringFromSelector), "submenuAction:", "AppKit assigns its built-in submenu action when submenu is attached")
            for item in try submenu(menu).items where !item.isSeparatorItem {
                XCTAssertTrue(item.target as? AppFolderAssignmentMenuController === fixture.assignment)
                XCTAssertEqual(item.action.map(NSStringFromSelector), "handleAssignment:")
                XCTAssertNotNil(item.representedObject)
                XCTAssertTrue(item.isEnabled)
            }
            let latest = Self.record(name: "Latest canonical metadata")
            fixture.currentRecord = latest
            try invokeActions(menu)
            XCTAssertEqual(fixture.delivered, actionIDs)
            XCTAssertEqual(fixture.assignments, [.moveToFolder(Self.firstID), .moveToFolder(Self.secondID),
                                                 .moveToFolder(Self.literalID), .moveToTopLevel])
            XCTAssertEqual(fixture.deliveredRecords, Array(repeating: latest, count: 8))
            XCTAssertEqual(fixture.expectedLayouts, Array(repeating: try XCTUnwrap(fixture.currentLayout), count: 4))
            XCTAssertTrue(fixture.rejections.isEmpty)
            XCTAssertEqual(fixture.contextReads, 1)
            XCTAssertEqual(fixture.assignmentReads, 1)
        }
    }

    func testStaleRevisionAndReboundCellRejectRetainedTranslatedActions() throws {
        for expected in copies {
            for invalidateRevision in [true, false] {
                let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
                let menu = try fixture.menu()
                if invalidateRevision { fixture.revision = 2 }
                else { fixture.cell.bind(name: "Reused cell", token: Self.token(Self.record(), reuse: 2)) }
                fixture.displayed = LocalizedStrings(language: .english)
                try invokeActions(menu)
                XCTAssertTrue(fixture.delivered.isEmpty)
                XCTAssertTrue(fixture.assignments.isEmpty)
                XCTAssertEqual(fixture.rejections.count, 4)
                XCTAssertEqual(fixture.contextReads, 1)
                XCTAssertEqual(fixture.assignmentReads, 1)
                try assertCopy(expected, menu: menu)
            }
        }
    }

    func testMovedCanonicalURLAndNewlyHiddenRecordRejectRetainedTranslatedActions() throws {
        for expected in copies {
            for moveRecord in [true, false] {
                let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
                let menu = try fixture.menu()
                if moveRecord { fixture.currentRecord = Self.record(path: "/SyntheticApps/Moved.app") }
                else { fixture.hidden = true }
                try invokeActions(menu)
                XCTAssertTrue(fixture.delivered.isEmpty)
                XCTAssertTrue(fixture.assignments.isEmpty)
                XCTAssertEqual(fixture.rejections.count, 4)
            }
        }
    }

    func testStaleAndSameGenerationChangedLayoutsRefuseAssignmentWithoutRelabel() throws {
        for expected in copies {
            for changeGeneration in [true, false] {
                let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
                let menu = try fixture.assignmentMenu()
                let layout = try XCTUnwrap(fixture.currentLayout)
                var folders = layout.folders
                let first = folders[1]
                folders[1] = PersistentFolderRecord(id: first.id, title: "Edited user title", members: first.members)
                fixture.currentLayout = PersistentWorkspaceLayout(
                    generation: changeGeneration ? layout.generation.incremented() : layout.generation,
                    topLevelOrder: layout.topLevelOrder, folders: folders)
                for item in menu.items where !item.isSeparatorItem { try invoke(item) }
                XCTAssertTrue(fixture.assignments.isEmpty)
                let rejection: LayoutMutationResult = changeGeneration ?
                    .rejected(.staleGeneration(expected: layout.generation, current: layout.generation.incremented())) :
                    .rejected(.invalidTarget)
                XCTAssertEqual(fixture.rejections, Array(repeating: rejection, count: 4))
                XCTAssertEqual(fixture.assignmentReads, 1)
                XCTAssertEqual(Array(menu.items.prefix(3)).map(\.title), Self.destinationTitles)
                XCTAssertEqual(menu.items.last?.title, expected.moveOut)
            }
        }
    }

    func testReadOnlyProtectionPreservesEnabledStatesAndRevalidatesAfterBuild() throws {
        for expected in copies {
            let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
            fixture.readOnly = true
            let disabled = try fixture.menu()
            XCTAssertEqual(Array(disabled.items.prefix(5)).map(\.isEnabled), [true, false, false, false, true])
            XCTAssertTrue(try submenu(disabled).items.filter { !$0.isSeparatorItem }.allSatisfy { !$0.isEnabled })
            try invokeActions(disabled)
            XCTAssertEqual(fixture.delivered, ["launch", "reveal"])
            XCTAssertTrue(fixture.assignments.isEmpty)
            fixture.readOnly = false
            let writable = try fixture.menu()
            fixture.readOnly = true
            try invokeActions(writable)
            XCTAssertEqual(fixture.delivered, ["launch", "reveal", "launch", "reveal"])
            XCTAssertTrue(fixture.assignments.isEmpty)
            XCTAssertEqual(fixture.rejections, Array(repeating: .cancelled, count: 8))
            try assertCopy(expected, menu: writable)
        }
    }

    func testAssignmentBusyAndMissingCallbackStayDisabledInEveryLanguage() throws {
        for expected in copies {
            let fixture = Fixture(strings: LocalizedStrings(language: expected.language))
            fixture.canApply = false
            let busy = try fixture.assignmentMenu()
            XCTAssertTrue(busy.items.filter { !$0.isSeparatorItem }.allSatisfy { !$0.isEnabled })
            for item in busy.items where !item.isSeparatorItem { try invoke(item) }
            XCTAssertTrue(fixture.assignments.isEmpty)
            fixture.canApply = true
            let writable = try fixture.assignmentMenu()
            fixture.canApply = false
            for item in writable.items where !item.isSeparatorItem { try invoke(item) }
            XCTAssertTrue(fixture.assignments.isEmpty)
            fixture.canApply = true
            fixture.assignment.onApply = nil
            let missing = try fixture.assignmentMenu()
            XCTAssertTrue(missing.items.filter { !$0.isSeparatorItem }.allSatisfy { !$0.isEnabled })
            for item in missing.items where !item.isSeparatorItem { try invoke(item) }
            XCTAssertEqual(fixture.rejections, Array(repeating: .cancelled, count: 12))
            XCTAssertEqual(fixture.assignmentReads, 3)
        }
    }

    func testTopLevelAssignmentKeepsUserTitlesAndHasNoMoveOutOrSeparator() throws {
        for expected in copies {
            let fixture = Fixture(strings: LocalizedStrings(language: expected.language), isMember: false)
            let menu = try fixture.assignmentMenu()
            XCTAssertEqual(menu.title, expected.assignment)
            XCTAssertEqual(menu.items.map(\.title), ["Owner 用户内容"] + Self.destinationTitles)
            XCTAssertFalse(menu.items.contains { $0.isSeparatorItem })
            XCTAssertFalse(menu.items.contains { $0.identifier?.rawValue == "folderAssignment.moveToTopLevel" })
            XCTAssertEqual(fixture.assignmentReads, 1)
        }
    }

    func testInvalidBindingsAndUnavailableOrganizationDoNotReadUnusedSnapshots() throws {
        let fixture = Fixture(strings: LocalizedStrings(language: .japanese))
        fixture.revision = 2
        XCTAssertNil(fixture.context.menu(for: fixture.cell))
        XCTAssertNil(fixture.assignment.menu(for: fixture.cell, record: Self.record(), revision: 1))
        XCTAssertEqual(fixture.contextReads, 0)
        XCTAssertEqual(fixture.assignmentReads, 0)
        fixture.revision = 1
        fixture.currentLayout = PersistentWorkspaceLayout(generation: .zero,
            topLevelOrder: [.app(.from(record: Self.record()))], folders: [])
        let context = try fixture.menu()
        XCTAssertEqual(context.items.count, 5)
        XCTAssertEqual(fixture.contextReads, 1)
        XCTAssertEqual(fixture.assignmentReads, 0)
    }
}
