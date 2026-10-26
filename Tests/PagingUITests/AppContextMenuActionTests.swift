import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import PagingUI
import XCTest
@testable import PagingPrototypeApp

/// Invoke only each item's explicit NSObject target; never show menus or call a workspace.
@MainActor
final class AppContextMenuActionTests: XCTestCase {
    private let actions = ["launch", "alias", "clearAlias", "hide", "reveal"]
    private let mutations = ["alias", "clearAlias", "hide"]

    private static func record(_ suffix: String = "original", name: String = "Original",
                               path: String = "/SyntheticApps/Original.app") -> AppRecord {
        let bundleID = "fixture.management.menu.\(suffix)"
        let id = CatalogFixture.appID(bundleID)
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

    @MainActor
    private final class Fixture {
        var currentRecord: AppRecord? = AppContextMenuActionTests.record()
        var revision: UInt64? = 1
        var hidden = false
        var readOnly = false
        var cell: AppGridCellView? = AppGridCellView(frame: .zero)
        var delivered: [String] = []
        var deliveredRecords: [AppRecord] = []
        var launched: [AppID] = []
        lazy var controller: AppContextMenuController = {
            let controller = AppContextMenuController(recordProvider: { [weak self] id in
                guard let record = self?.currentRecord, record.id == id else { return nil }
                return record
            }, revisionProvider: { [weak self] in self?.revision },
               hiddenProvider: { [weak self] _ in self?.hidden ?? true })
            controller.isReadOnlyProvider = { [weak self] in self?.readOnly ?? true }
            controller.onLaunch = { [weak self] id in
                self?.delivered.append("launch")
                self?.launched.append(id)
            }
            controller.onAlias = { [weak self] in self?.receive("alias", record: $0) }
            controller.onClearAlias = { [weak self] in self?.receive("clearAlias", record: $0) }
            controller.onHide = { [weak self] in self?.receive("hide", record: $0) }
            controller.onReveal = { [weak self] in self?.receive("reveal", record: $0) }
            return controller
        }()

        init() {
            if let record = currentRecord {
                cell?.bind(name: record.displayName,
                           token: AppContextMenuActionTests.token(AnyHashable(record.id)))
            }
        }

        private func receive(_ action: String, record: AppRecord) {
            delivered.append(action)
            deliveredRecords.append(record)
        }

        func menu() throws -> NSMenu {
            try XCTUnwrap(controller.menu(for: XCTUnwrap(cell)))
        }
    }

    private func item(_ action: String, in menu: NSMenu) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.\(action)" })
    }

    private func invoke(_ action: String, in menu: NSMenu) throws {
        let item = try item(action, in: menu)
        let target = try XCTUnwrap(item.target as? NSObject)
        let selector = try XCTUnwrap(item.action)
        guard target.responds(to: selector) else {
            XCTFail("Menu target does not implement its action")
            return
        }
        _ = target.perform(selector, with: item)
    }

    private func invokeAll(in menu: NSMenu) throws {
        for action in actions { try invoke(action, in: menu) }
    }

    func testValidMenuDispatchesEachCallbackOnceWithCanonicalIdentity() throws {
        let fixture = Fixture()
        let record = try XCTUnwrap(fixture.currentRecord)
        // Presentation text must never substitute for the canonical record or AppID.
        try XCTUnwrap(fixture.cell).bind(name: "Presentation alias", token: Self.token(AnyHashable(record.id)))
        let menu = try fixture.menu()
        XCTAssertFalse(menu.autoenablesItems)
        XCTAssertEqual(Set(menu.items.compactMap { $0.identifier?.rawValue }),
                       Set(actions.map { "management.\($0)" }))
        XCTAssertEqual(menu.items.count, actions.count)
        for action in actions {
            XCTAssertTrue(try item(action, in: menu).isEnabled)
            try invoke(action, in: menu)
        }
        XCTAssertEqual(fixture.delivered, actions)
        XCTAssertEqual(fixture.launched, [record.id])
        XCTAssertEqual(fixture.deliveredRecords, Array(repeating: record, count: 4))
    }

    func testMenuCreationRejectsUnboundAndNonAppIdentities() throws {
        let fixture = Fixture()
        let cell = try XCTUnwrap(fixture.cell)
        cell.clearContent()
        XCTAssertNil(fixture.controller.menu(for: cell))
        let folder = FolderID(uuid: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000081")))
        for identity: AnyHashable? in [nil, AnyHashable("opaque"), AnyHashable(folder)] {
            cell.bind(name: "Fixture", token: Self.token(identity))
            XCTAssertNil(fixture.controller.menu(for: cell))
        }
        XCTAssertTrue(fixture.delivered.isEmpty)
    }

    func testMenuCreationRejectsMissingHiddenAndUnavailableRevision() throws {
        let missing = Fixture()
        missing.currentRecord = nil
        XCTAssertNil(missing.controller.menu(for: try XCTUnwrap(missing.cell)))
        let hidden = Fixture()
        hidden.hidden = true
        XCTAssertNil(hidden.controller.menu(for: try XCTUnwrap(hidden.cell)))
        let unavailable = Fixture()
        unavailable.revision = nil
        XCTAssertNil(unavailable.controller.menu(for: try XCTUnwrap(unavailable.cell)))
    }

    func testMenuCreationRejectsStaleCatalogTokenUntilRebound() throws {
        let fixture = Fixture()
        let cell = try XCTUnwrap(fixture.cell)
        let record = try XCTUnwrap(fixture.currentRecord)
        fixture.revision = 2
        XCTAssertNil(fixture.controller.menu(for: cell))
        cell.bind(name: record.displayName, token: Self.token(AnyHashable(record.id), revision: 2, pageRevision: 2))
        let menu = try fixture.menu()
        try invoke("launch", in: menu)
        XCTAssertEqual(fixture.launched, [record.id])
    }

    func testEveryBindingTokenFieldInvalidatesRetainedMenu() throws {
        let record = Self.record()
        let id = AnyHashable(record.id)
        let tokens = [
            Self.token(id, revision: 2),
            Self.token(id, pageRevision: 2),
            Self.token(id, page: 1),
            Self.token(id, slot: 1),
            Self.token(AnyHashable(Self.record("replacement").id)),
            Self.token(id, reuse: 2),
            Self.token(id, surface: 2),
            Self.token(id, icon: IconKey(identity: record.iconIdentity, pointSize: 48, displayScale: 2))
        ]
        for token in tokens {
            let fixture = Fixture()
            let menu = try fixture.menu()
            try XCTUnwrap(fixture.cell).bind(name: "Rebound", token: token)
            try invokeAll(in: menu)
            XCTAssertTrue(fixture.delivered.isEmpty, "Retained menu must reject changed token: \(token)")
        }
    }

    func testClearedAndDeallocatedCellsInvalidateRetainedMenus() throws {
        let cleared = Fixture()
        let clearedMenu = try cleared.menu()
        cleared.cell?.clearContent()
        try invokeAll(in: clearedMenu)
        XCTAssertTrue(cleared.delivered.isEmpty)

        weak var weakCell: AppGridCellView?
        let (released, releasedMenu) = try autoreleasepool {
            let fixture = Fixture()
            let menu = try fixture.menu()
            weakCell = fixture.cell
            fixture.cell = nil
            return (fixture, menu)
        }
        XCTAssertNil(weakCell, "Menu binding must not keep a reusable cell alive")
        try invokeAll(in: releasedMenu)
        XCTAssertTrue(released.delivered.isEmpty)
    }

    func testChangedOrUnavailableRevisionRejectsAllRetainedActions() throws {
        for revision: UInt64? in [2, nil] {
            let fixture = Fixture()
            let menu = try fixture.menu()
            fixture.revision = revision
            try invokeAll(in: menu)
            XCTAssertTrue(fixture.delivered.isEmpty)
        }
    }

    func testRemovedMovedAndNewlyHiddenRecordsRejectAllRetainedActions() throws {
        for state in ["removed", "moved", "hidden"] {
            let fixture = Fixture()
            let menu = try fixture.menu()
            switch state {
            case "removed": fixture.currentRecord = nil
            case "moved": fixture.currentRecord = Self.record(path: "/SyntheticApps/Moved.app")
            default: fixture.hidden = true
            }
            try invokeAll(in: menu)
            XCTAssertTrue(fixture.delivered.isEmpty, state)
        }
    }

    func testCallbacksUseLatestRecordWhenIdentityURLAndRevisionStillMatch() throws {
        let fixture = Fixture()
        let menu = try fixture.menu()
        let updated = Self.record(name: "Updated metadata")
        fixture.currentRecord = updated
        try invokeAll(in: menu)
        XCTAssertEqual(fixture.launched, [updated.id])
        XCTAssertEqual(fixture.deliveredRecords, Array(repeating: updated, count: 4))
    }

    func testReadOnlyMenuDisablesMutationsAndRejectsDirectDeliveryButAllowsLaunchAndReveal() throws {
        let fixture = Fixture()
        fixture.readOnly = true
        let menu = try fixture.menu()
        for action in mutations { XCTAssertFalse(try item(action, in: menu).isEnabled) }
        for action in ["launch", "reveal"] { XCTAssertTrue(try item(action, in: menu).isEnabled) }
        try invokeAll(in: menu)
        XCTAssertEqual(fixture.delivered, ["launch", "reveal"])
        XCTAssertEqual(fixture.launched, [try XCTUnwrap(fixture.currentRecord).id])
        XCTAssertEqual(fixture.deliveredRecords, [try XCTUnwrap(fixture.currentRecord)])
    }

    func testReadOnlyIsRevalidatedAfterWritableMenuWasCreated() throws {
        let fixture = Fixture()
        let menu = try fixture.menu()
        for action in mutations { XCTAssertTrue(try item(action, in: menu).isEnabled) }
        fixture.readOnly = true
        try invokeAll(in: menu)
        XCTAssertEqual(fixture.delivered, ["launch", "reveal"])
        fixture.readOnly = false
        for action in mutations { try invoke(action, in: menu) }
        XCTAssertEqual(fixture.delivered, ["launch", "reveal"] + mutations)
    }

    func testDefaultReadOnlyProviderAllowsMutationsAndMissingCallbacksAreSafe() throws {
        let record = Self.record()
        let cell = AppGridCellView(frame: .zero)
        cell.bind(name: record.displayName, token: Self.token(AnyHashable(record.id)))
        let controller = AppContextMenuController(recordProvider: { _ in record },
                                                 revisionProvider: { 1 }, hiddenProvider: { _ in false })
        XCTAssertFalse(controller.isReadOnlyProvider())
        let menu = try XCTUnwrap(controller.menu(for: cell))
        for action in actions { XCTAssertTrue(try item(action, in: menu).isEnabled) }
        try invokeAll(in: menu)
        XCTAssertEqual(cell.bindingToken, Self.token(AnyHashable(record.id)))
    }
}
