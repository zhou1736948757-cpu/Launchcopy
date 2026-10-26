import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

/// Synthetic AppKit events and views only; no displayed windows or product menu actions.
@MainActor
final class AppContextMenuConsumerTests: XCTestCase {
    private let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!)

    private func token(_ identity: AnyHashable?) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 1,
                         pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: 1,
                         iconKey: nil, surfaceGeneration: 1)
    }

    private func event(in view: NSView, at point: NSPoint,
                       type: NSEvent.EventType = .rightMouseDown) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil),
                                        modifierFlags: [], timestamp: 0, windowNumber: 0,
                                        context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func iconEvent(_ cell: AppGridCellView) throws -> NSEvent {
        cell.layout()
        return try event(in: cell, at: NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY))
    }

    func testCellCallsProviderOnlyForBoundAppAndRejectsUnboundFolderAndOpaqueIdentity() throws {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 100, height: 88))
        let menu = NSMenu(title: "Fixture menu")
        var calls = 0
        cell.appContextMenuProvider = { [weak cell] received in
            XCTAssertTrue(received === cell)
            calls += 1
            return menu
        }
        let request = try iconEvent(cell)
        cell.menu = NSMenu(title: "Must not fall back to a generic menu")
        XCTAssertNil(cell.menu(for: request))
        cell.bind(name: "Alpha", token: token(AnyHashable(makeAppID("fixture.menu.alpha"))))
        XCTAssertTrue(cell.menu(for: request) === menu)
        XCTAssertEqual(calls, 1)
        cell.clearContent()
        XCTAssertNil(cell.menu(for: request))
        cell.bind(name: "Blank", token: token(nil))
        XCTAssertNil(cell.menu(for: request))
        cell.bind(name: "Opaque", token: token(AnyHashable("fixture.non-app")))
        XCTAssertNil(cell.menu(for: request))
        cell.bind(name: "Folder identity", token: token(AnyHashable(folderID)))
        XCTAssertNil(cell.menu(for: request))
        cell.bindFolder(title: "Group", memberCount: 2, token: token(AnyHashable(folderID)))
        XCTAssertNil(cell.menu(for: request))
        // The visual mode itself is authoritative even for an incorrectly supplied app token.
        cell.bindFolder(title: "Group", memberCount: 2,
                        token: token(AnyHashable(makeAppID("fixture.menu.alpha"))))
        XCTAssertNil(cell.menu(for: request))
        XCTAssertEqual(calls, 1)
        cell.bind(name: "Beta", token: token(AnyHashable(makeAppID("fixture.menu.beta"))))
        cell.appContextMenuProvider = nil
        XCTAssertNil(cell.menu(for: request))
    }

    func testContextLookupPreservesIconHitRegionAndLeftClickArbitration() throws {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let cell = AppGridCellView(frame: NSRect(x: 240, y: 170, width: 100, height: 88))
        host.addSubview(cell)
        cell.bind(name: "Alpha", token: token(AnyHashable(makeAppID("fixture.alpha"))))
        cell.layout()
        let coordinator = DragUISessionCoordinator(host: host, clock: FakeDragClock())
        defer { coordinator.teardown() }
        let (layout, catalog) = makeDragLayout(titles: ["Alpha"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in topLevelGeometry(frames: [appFrame("Alpha")]) }
        cell.dragCoordinator = coordinator
        var clicks = 0
        coordinator.onCellClick = { _ in clicks += 1 }
        let menu = NSMenu(title: "Fixture menu")
        var menuCalls = 0
        cell.appContextMenuProvider = { _ in menuCalls += 1; return menu }
        let icon = cell.iconView.frame
        let hit = NSPoint(x: icon.minX - 3, y: icon.midY)
        let miss = NSPoint(x: icon.minX - 5, y: icon.midY)
        let label = NSPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY)
        XCTAssertTrue(cell.hitTest(cell.convert(hit, to: host)) === cell)
        XCTAssertNil(cell.hitTest(cell.convert(miss, to: host)))
        XCTAssertNil(cell.hitTest(cell.convert(label, to: host)))
        XCTAssertTrue(cell.menu(for: try event(in: cell, at: hit)) === menu)
        XCTAssertNil(cell.menu(for: try event(in: cell, at: miss)))
        XCTAssertNil(cell.menu(for: try event(in: cell, at: label)))
        XCTAssertEqual(menuCalls, 1)
        XCTAssertEqual(clicks, 0)
        XCTAssertFalse(coordinator.isSessionActive)
        cell.mouseDown(with: try event(in: cell, at: hit, type: .leftMouseDown))
        XCTAssertEqual(coordinator.controller.state, .pressed)
        cell.mouseUp(with: try event(in: cell, at: hit, type: .leftMouseUp))
        XCTAssertEqual(clicks, 1)
        XCTAssertEqual(menuCalls, 1)
    }

    func testPageUpdatesLiveReusedAndNewCellsWithoutInvalidatingPendingIcon() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline)
        defer {
            page.teardown()
            pipeline.shutdown()
            for key in loader.pendingKeys { loader.complete(key: key) }
        }
        page.frame = NSRect(x: 0, y: 0, width: 800, height: 700)
        let id = makeAppID("fixture.menu.pending")
        let content = makeContent(revision: 1, page: 0, titles: ["Pending"], appIDs: [id])
        let applied = expectation(description: "Pending icon remains valid after factory replacement")
        page.onIconApplyResult = { _, result in if result == .applied { applied.fulfill() } }
        page.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 7)
        await waitForPendingLoads(loader, count: 1)
        XCTAssertEqual(loader.pendingKeyCount, 1)
        page.layout()
        let cell = try XCTUnwrap(page.cell(at: 0))
        let request = try iconEvent(cell)
        let binding = cell.bindingToken
        let generation = page.surfaceGeneration
        let stats = pipeline.stats
        let frame = cell.frame
        let iconFrame = cell.iconView.frame
        let menu = NSMenu(title: "Fixture live")
        page.appContextMenuProvider = { _ in menu }
        XCTAssertTrue(cell.menu(for: request) === menu)
        page.appContextMenuProvider = { _ in nil }
        XCTAssertNil(cell.menu(for: request))
        page.appContextMenuProvider = { _ in menu }
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(page.reuseGeneration, 7)
        XCTAssertEqual(cell.frame, frame)
        XCTAssertEqual(cell.iconView.frame, iconFrame)
        XCTAssertEqual(pipeline.stats, stats)
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: id), pointSize: 48, displayScale: 2))
        await fulfillment(of: [applied], timeout: 3)
        XCTAssertNotNil(cell.iconView.image)
        XCTAssertEqual(page.staleIconApplyCount, 0)
        page.onIconApplyResult = nil
        page.clearForReuse()
        XCTAssertNil(cell.menu(for: request))
        page.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 8)
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertTrue(cell.menu(for: try iconEvent(cell)) === menu)
        let ids = [id, makeAppID("fixture.menu.new")]
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["A", "B"], appIDs: ids),
                    pageCount: 1, reuseGeneration: 9)
        page.layout()
        for index in 0..<2 {
            let newCell = try XCTUnwrap(page.cell(at: index))
            XCTAssertFalse(newCell === cell)
            XCTAssertTrue(newCell.menu(for: try iconEvent(newCell)) === menu)
        }
        await waitForPendingLoads(loader, count: 1)
        for key in loader.pendingKeys { loader.complete(key: key) }
    }

    func testFolderRoutesActualMenuLookupWithoutActivationOrBlankMenus() throws {
        let pipeline = IconPipeline(loader: ContextMenuFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 800))
        overlay.frame = NSRect(x: 30, y: 40, width: 800, height: 700)
        host.addSubview(overlay)
        let ids = [makeAppID("fixture.menu.member0"), makeAppID("fixture.menu.member1")]
        let entry = FolderEntry(id: folderID, title: "Group", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Member" }
        overlay.layout()
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let request = try iconEvent(cell)
        let binding = cell.bindingToken
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        let frame = cell.frame
        var activations = 0
        var closes = 0
        var calls = 0
        overlay.onActivateMember = { _ in activations += 1 }
        overlay.onRequestClose = { closes += 1 }
        let menu = NSMenu(title: "Fixture member")
        overlay.appContextMenuProvider = { received in
            XCTAssertTrue(received === cell)
            calls += 1
            return menu
        }
        // AppKit hits the overlay for both buttons, so its menu override is essential.
        XCTAssertTrue(overlay.hitTest(host.convert(request.locationInWindow, from: nil)) === overlay)
        XCTAssertTrue(overlay.menu(for: request) === menu)
        XCTAssertTrue(cell.menu(for: request) === menu)
        XCTAssertNil(overlay.menu(for: try event(in: overlay, at: NSPoint(x: 1, y: 1))))
        XCTAssertNil(overlay.menu(for: try event(in: cell, at: NSPoint(x: cell.nameLabel.frame.midX,
                                                                    y: cell.nameLabel.frame.midY))))
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(activations, 0)
        XCTAssertEqual(closes, 0)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(cell.frame, frame)
        XCTAssertEqual(pipeline.stats, stats)
        overlay.appContextMenuProvider = nil
        XCTAssertNil(overlay.menu(for: request))
        overlay.handleClick(at: overlay.convert(request.locationInWindow, from: nil))
        XCTAssertEqual(activations, 1)
    }

    func testFolderFactorySurvivesReusePagingAndVisualOnlyResume() throws {
        let pipeline = IconPipeline(loader: ContextMenuFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 700)
        overlay.membersPerPage = 2
        let ids = (0..<3).map { makeAppID("fixture.menu.paged\($0)") }
        let entry = FolderEntry(id: folderID, title: "Group", members: ids)
        let first = NSMenu(title: "First")
        let latest = NSMenu(title: "Latest")
        overlay.appContextMenuProvider = { _ in first }
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Member" }
        overlay.layout()
        let reused = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertTrue(reused.menu(for: try iconEvent(reused)) === first)
        overlay.clearContent()
        XCTAssertNil(reused.menu(for: try iconEvent(reused)))
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Member" }
        XCTAssertTrue(overlay.memberCell(at: 0) === reused)
        XCTAssertTrue(reused.menu(for: try iconEvent(reused)) === first)
        overlay.configure(entry: entry, innerPage: 1, reduceMotion: true) { _ in "Member" }
        overlay.layout()
        let newCell = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertFalse(newCell === reused)
        let request = try iconEvent(newCell)
        XCTAssertTrue(overlay.menu(for: request) === first)
        overlay.setVisualOnly(true)
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        overlay.appContextMenuProvider = { _ in latest }
        XCTAssertNil(newCell.menu(for: request))
        XCTAssertNil(overlay.menu(for: request))
        // Even a stale external cell factory cannot enable an exit visual.
        newCell.appContextMenuProvider = { _ in latest }
        XCTAssertNil(newCell.menu(for: request))
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        overlay.setVisualOnly(false)
        overlay.layout()
        XCTAssertTrue(overlay.menu(for: try iconEvent(newCell)) === latest)
        overlay.teardown()
        XCTAssertNil(newCell.menu(for: request))
    }

    func testDrawingOnlyMoveOutProxyRejectsDirectMenuBeforeAndAfterReattachment() throws {
        let pipeline = IconPipeline(loader: ContextMenuFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        host.addSubview(overlay)
        overlay.frame = host.bounds
        let coordinator = DragUISessionCoordinator(reduceMotionProvider: { true })
        defer { coordinator.teardown() }
        overlay.dragCoordinator = coordinator
        let ids = [makeAppID("fixture.menu.dragged"), makeAppID("fixture.menu.remaining")]
        overlay.configure(entry: FolderEntry(id: folderID, title: "Group", members: ids),
                          innerPage: 0, reduceMotion: true) { _ in "Member" }
        overlay.layout()
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let remaining = try XCTUnwrap(overlay.memberCell(at: 1))
        XCTAssertTrue(remaining.applyIconIfValid(makeIconImage(), token: try XCTUnwrap(remaining.bindingToken)))
        let menu = NSMenu(title: "Fixture")
        overlay.appContextMenuProvider = { _ in menu }
        overlay.mouseDown(with: try event(in: source, at: NSPoint(x: source.bounds.midX,
                                                                 y: source.bounds.midY), type: .leftMouseDown))
        XCTAssertEqual(overlay.moveOutRemainingAppID, ids[1])
        overlay.prepareMoveOutIconCache()
        overlay.setMoveOutPresentationCollapsed(true)
        let frame = NSRect(x: 20, y: 30, width: 100, height: 88)
        overlay.showMoveOutRemainingAppProxy(in: host, frame: frame)
        let proxy = try XCTUnwrap(overlay.moveOutRemainingAppProxy)
        let proxyHost = try XCTUnwrap(overlay.moveOutRemainingAppProxyHost)
        let request = try iconEvent(proxy)
        XCTAssertNil(proxy.appContextMenuProvider)
        XCTAssertNil(proxy.menu(for: request))
        XCTAssertNil(overlay.menu(for: try iconEvent(remaining)))
        XCTAssertNil(remaining.menu(for: try iconEvent(remaining)))
        proxy.appContextMenuProvider = { _ in menu }
        XCTAssertNil(proxy.menu(for: request))
        overlay.appContextMenuProvider = { _ in menu }
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        overlay.reattachMoveOutRemainingAppProxyHost(proxyHost, frame: frame)
        XCTAssertNil(proxy.appContextMenuProvider)
        XCTAssertNil(proxy.menu(for: request))
        XCTAssertNil(proxyHost.hitTest(NSPoint(x: frame.midX, y: frame.midY)))
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        overlay.setVisualOnly(true)
        XCTAssertNil(proxy.menu(for: request))
    }

    func testPageConsumerDoesNotRetainItsOwner() throws {
        let pipeline = IconPipeline(loader: ContextMenuFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        weak var owner: AppGridPageView?
        let cell = try autoreleasepool { () throws -> AppGridCellView in
            let page = AppGridPageView(iconPipeline: pipeline)
            page.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
            owner = page
            page.appContextMenuProvider = { _ in NSMenu(title: "Fixture") }
            // No icon task may retain the view while its loader is finishing.
            page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0, titles: ["Member"]),
                        pageCount: 1, reuseGeneration: 1)
            let cell = try XCTUnwrap(page.cell(at: 0))
            cell.bind(name: "Member", token: token(AnyHashable(makeAppID("fixture.menu.weak"))))
            page.layoutSubtreeIfNeeded()
            XCTAssertNotNil(cell.menu(for: try iconEvent(cell)))
            return cell
        }
        XCTAssertNil(owner)
        XCTAssertNil(cell.menu(for: try iconEvent(cell)))
    }
}

private final class ContextMenuFixtureLoader: IconLoading, @unchecked Sendable {
    private let image = NSImage(size: NSSize(width: 48, height: 48))
    func load(key: IconKey) async throws -> NSImage { image }
}
