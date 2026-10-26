import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

/// Synthetic view-only fixtures: no windows, app discovery, user defaults or disk data.
@MainActor
final class AppearanceLabelsTests: XCTestCase {
    private let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!)

    private func token(identity: AnyHashable) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 1,
                         pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: 1,
                         iconKey: nil, surfaceGeneration: 1)
    }

    private func countLabel(in cell: AppGridCellView) throws -> NSTextField {
        try XCTUnwrap(cell.subviews.compactMap { $0 as? NSTextField }
            .first { $0 !== cell.nameLabel })
    }

    func testCellDefaultAndLiveTogglePreserveBindingIconFocusAccessibilityAndGeometry() throws {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 100, height: 88))
        XCTAssertTrue(cell.showsAppLabels)
        XCTAssertFalse(cell.nameLabel.isHidden)
        let binding = token(identity: AnyHashable(makeAppID("fixture.appearance.alpha")))
        cell.bind(name: "Alpha Full Name", token: binding)
        let image = makeIconImage()
        XCTAssertTrue(cell.applyIconIfValid(image, token: binding))
        cell.setFocused(true)
        cell.layout()
        let iconFrame = cell.iconView.frame
        let labelFrame = cell.nameLabel.frame
        let hit = NSPoint(x: iconFrame.minX - 3, y: iconFrame.midY)
        let miss = NSPoint(x: iconFrame.minX - 5, y: iconFrame.midY)

        for visible in [false, false, true] {
            cell.showsAppLabels = visible
            cell.layout()
            XCTAssertEqual(cell.nameLabel.isHidden, !visible)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertEqual(cell.boundName, "Alpha Full Name")
            XCTAssertEqual(cell.nameLabel.stringValue, "Alpha Full Name")
            XCTAssertEqual(cell.accessibilityLabel(), "Alpha Full Name")
            XCTAssertEqual(cell.nameLabel.toolTip, "Alpha Full Name")
            XCTAssertTrue(cell.iconView.image === image)
            XCTAssertTrue(cell.isFocused)
            XCTAssertEqual(cell.frame, NSRect(x: 0, y: 0, width: 100, height: 88))
            XCTAssertEqual(cell.iconView.frame, iconFrame)
            XCTAssertEqual(cell.nameLabel.frame, labelFrame)
            XCTAssertEqual(cell.nameLabel.font?.pointSize, 11)
            XCTAssertEqual(iconFrame.size, NSSize(width: 48, height: 48))
            XCTAssertTrue(cell.hitTest(hit) === cell)
            XCTAssertNil(cell.hitTest(miss))
        }
    }

    func testHiddenPolicySurvivesAppFolderAndClearedCellReuse() async throws {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 100, height: 88))
        cell.showsAppLabels = false
        cell.bindFolder(title: "Group", memberCount: 2, token: token(identity: AnyHashable(folderID)))
        cell.layout()
        let count = try countLabel(in: cell)
        let countFrame = count.frame
        let iconFrame = cell.iconView.frame
        let binding = cell.bindingToken
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertTrue(count.isHidden)
        XCTAssertTrue(cell.isFolderSymbolVisible)
        XCTAssertEqual(cell.accessibilityLabel(), "Group")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.accessibilityHelp(), "Folder with 2 items")
        cell.showsAppLabels = true
        XCTAssertFalse(cell.nameLabel.isHidden)
        XCTAssertFalse(count.isHidden)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(count.stringValue, "2 items")
        XCTAssertEqual(count.font?.pointSize, 10)
        XCTAssertEqual(count.frame, countFrame)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(cell.iconView.frame, iconFrame)
        XCTAssertTrue(cell.acceptsLaunchHit(at: NSPoint(x: iconFrame.minX - 3, y: iconFrame.midY)))
        XCTAssertFalse(cell.acceptsLaunchHit(at: NSPoint(x: iconFrame.minX - 5, y: iconFrame.midY)))

        cell.showsAppLabels = false
        cell.clearContent()
        cell.bind(name: "Beta", token: token(identity: AnyHashable(makeAppID("fixture.appearance.beta"))))
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertTrue(count.isHidden)
        XCTAssertFalse(cell.isFolderSymbolVisible)
        XCTAssertEqual(cell.accessibilityLabel(), "Beta")
        cell.showsAppLabels = true
        XCTAssertFalse(cell.nameLabel.isHidden)
        XCTAssertTrue(count.isHidden, "An app must never expose the old folder caption")
        cell.clearContent()
        cell.bindFolder(title: "Other Group", memberCount: 3,
                        token: token(identity: AnyHashable(folderID)))
        XCTAssertFalse(count.isHidden)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(count.stringValue, "3 items")
    }

    func testPageToggleKeepsInFlightIconValidWithoutAdditionalRequestsOrGenerationChange() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer {
            pipeline.shutdown()
            for key in loader.pendingKeys { loader.complete(key: key) }
        }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        XCTAssertTrue(page.showsAppLabels)
        page.frame = NSRect(x: 0, y: 0, width: 800, height: 700)
        let id = makeAppID("fixture.appearance.pending")
        let applied = expectation(description: "In-flight icon applies while captions are hidden")
        page.onIconApplyResult = { _, result in
            if result == .applied { applied.fulfill() }
        }
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Pending"], appIDs: [id]),
                    pageCount: 1, reuseGeneration: 7)
        await waitForPendingLoads(loader, count: 1)
        XCTAssertEqual(loader.pendingKeyCount, 1)
        page.layout()
        let cell = try XCTUnwrap(page.cell(at: 0))
        let binding = cell.bindingToken
        let frame = cell.frame
        let generation = page.surfaceGeneration
        let stats = pipeline.stats
        page.showsAppLabels = false
        page.showsAppLabels = false
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(cell.frame, frame)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(page.reuseGeneration, 7)
        XCTAssertEqual(page.presentationID, binding?.pageIdentity)
        XCTAssertEqual(pipeline.stats, stats)

        loader.complete(key: IconKey(identity: IconIdentity.from(appID: id), pointSize: 48, displayScale: 2))
        await fulfillment(of: [applied], timeout: 3)
        XCTAssertNotNil(cell.iconView.image)
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertEqual(page.staleIconApplyCount, 0)
        page.showsAppLabels = true
        XCTAssertFalse(cell.nameLabel.isHidden)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats.requests, stats.requests)
    }

    func testPagePropagatesPolicyToNewReusedAndRecreatedCellsIncludingFolderCaptions() throws {
        let pipeline = IconPipeline(loader: AppearanceFixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        page.showsAppLabels = false
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID), title: "Group")],
            isPlaceholder: false)
        page.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 1)
        let folder = try XCTUnwrap(page.cell(at: 0))
        XCTAssertTrue(folder.nameLabel.isHidden)
        XCTAssertTrue(try countLabel(in: folder).isHidden)
        page.showsAppLabels = true
        XCTAssertFalse(try countLabel(in: folder).isHidden)
        page.showsAppLabels = false
        page.clearForReuse()
        page.render(pageIndex: 0,
                    content: makeContent(revision: 2, page: 0, titles: ["Reused"]),
                    pageCount: 1, reuseGeneration: 2)
        XCTAssertTrue(page.cell(at: 0) === folder)
        XCTAssertTrue(folder.nameLabel.isHidden)
        XCTAssertEqual(folder.accessibilityLabel(), "Reused")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 3, page: 0, titles: ["New A", "New B"]),
                    pageCount: 1, reuseGeneration: 3)
        for index in 0..<2 {
            XCTAssertTrue(try XCTUnwrap(page.cell(at: index)).nameLabel.isHidden)
        }
        XCTAssertEqual(pipeline.stats.requests, 0)
    }

    func testOverlayTogglePreservesTitleMembersGeometryAndIconRequests() throws {
        let pipeline = IconPipeline(loader: AppearanceFixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        XCTAssertTrue(overlay.showsAppLabels)
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 700)
        let ids = [makeAppID("fixture.appearance.memberA"), makeAppID("fixture.appearance.memberB")]
        let entry = FolderEntry(id: folderID, title: "Visible Folder Title", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Member" }
        overlay.layout()
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        cell.layout()
        let title = try XCTUnwrap(overlay.subviews.flatMap { $0.subviews }
            .compactMap { $0 as? NSTextField }.first { $0.stringValue == entry.title })
        let generation = overlay.surfaceGeneration
        let frame = cell.frame
        let panel = overlay.panelFrame
        let binding = cell.bindingToken
        let stats = pipeline.stats
        let image = makeIconImage()
        XCTAssertTrue(cell.applyIconIfValid(image, token: try XCTUnwrap(binding)))
        for visible in [false, false, true] {
            overlay.showsAppLabels = visible
            XCTAssertEqual(cell.nameLabel.isHidden, !visible)
            XCTAssertFalse(title.isHidden)
            XCTAssertEqual(title.stringValue, entry.title)
            XCTAssertEqual(overlay.accessibilityLabel(), entry.title)
            XCTAssertEqual(cell.accessibilityLabel(), "Member")
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertTrue(cell.iconView.image === image)
            XCTAssertEqual(cell.frame, frame)
            XCTAssertEqual(overlay.panelFrame, panel)
            XCTAssertEqual(overlay.surfaceGeneration, generation)
            XCTAssertEqual(overlay.currentEntry, entry)
            XCTAssertEqual(overlay.currentInnerPage, 0)
            XCTAssertEqual(pipeline.stats, stats)
        }
    }

    func testOverlayPolicySurvivesMemberPagingClearAndVisualResume() throws {
        let pipeline = IconPipeline(loader: AppearanceFixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        overlay.showsAppLabels = false
        overlay.membersPerPage = 2
        let ids = (0..<3).map { makeAppID("fixture.appearance.paged\($0)") }
        let entry = FolderEntry(id: folderID, title: "Paged Group", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "First" }
        let reused = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertTrue(reused.nameLabel.isHidden)
        overlay.clearContent()
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Reused" }
        XCTAssertTrue(overlay.memberCell(at: 0) === reused)
        XCTAssertTrue(reused.nameLabel.isHidden)
        overlay.configure(entry: entry, innerPage: 1, reduceMotion: true) { _ in "New" }
        let newCell = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertFalse(newCell === reused)
        XCTAssertTrue(newCell.nameLabel.isHidden)
        overlay.setVisualOnly(true)
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        overlay.showsAppLabels = true
        // The approved queued-appearance contract preserves frozen exit pixels.
        XCTAssertTrue(newCell.nameLabel.isHidden)
        XCTAssertEqual(overlay.showsAppLabels, false)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        overlay.showsAppLabels = false
        overlay.setVisualOnly(false)
        XCTAssertTrue(newCell.nameLabel.isHidden)
        XCTAssertEqual(newCell.accessibilityLabel(), "New")
    }

    func testMoveOutProxyTracksPolicyOnCreationLiveToggleAndReattachment() throws {
        let pipeline = IconPipeline(loader: AppearanceFixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        host.addSubview(overlay)
        overlay.frame = host.bounds
        // A detached coordinator provides the pointer seam without starting a drag or timer.
        let coordinator = DragUISessionCoordinator(reduceMotionProvider: { true })
        defer { coordinator.teardown() }
        overlay.dragCoordinator = coordinator
        overlay.showsAppLabels = false
        let ids = [makeAppID("fixture.appearance.dragged"), makeAppID("fixture.appearance.remaining")]
        overlay.configure(entry: FolderEntry(id: folderID, title: "Group", members: ids),
                          innerPage: 0, reduceMotion: true) { $0 == ids[0] ? "Dragged" : "Remaining" }
        overlay.layout()
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let remaining = try XCTUnwrap(overlay.memberCell(at: 1))
        let image = makeIconImage()
        XCTAssertTrue(remaining.applyIconIfValid(image, token: try XCTUnwrap(remaining.bindingToken)))
        let point = source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                                                  modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                  context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        overlay.mouseDown(with: down)
        XCTAssertEqual(overlay.moveOutRemainingAppID, ids[1])
        overlay.prepareMoveOutIconCache()
        overlay.setMoveOutPresentationCollapsed(true)
        let proxyFrame = NSRect(x: 20, y: 30, width: 100, height: 88)
        overlay.showMoveOutRemainingAppProxy(in: host, frame: proxyFrame)
        let proxy = try XCTUnwrap(overlay.moveOutRemainingAppProxy)
        let proxyHost = try XCTUnwrap(overlay.moveOutRemainingAppProxyHost)
        XCTAssertTrue(proxy.nameLabel.isHidden)
        XCTAssertEqual(proxy.accessibilityLabel(), "Remaining")
        XCTAssertNotNil(proxy.iconView.image)
        let proxyImage = proxy.iconView.image
        let binding = proxy.bindingToken
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        overlay.showsAppLabels = true
        XCTAssertFalse(proxy.nameLabel.isHidden)
        XCTAssertFalse(remaining.nameLabel.isHidden)
        overlay.showsAppLabels = false
        XCTAssertTrue(proxy.nameLabel.isHidden)
        XCTAssertEqual(proxy.bindingToken, binding)
        XCTAssertTrue(proxy.iconView.image === proxyImage)
        XCTAssertEqual(overlay.moveOutRemainingAppProxyFrame, proxyFrame)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        XCTAssertNil(proxyHost.hitTest(NSPoint(x: proxyFrame.midX, y: proxyFrame.midY)))

        // The commit seam may temporarily detach ownership while preserving the same proxy.
        overlay.clearMoveOutRemainingAppProxy()
        proxyHost.addSubview(proxy)
        host.addSubview(proxyHost)
        proxy.showsAppLabels = true
        overlay.reattachMoveOutRemainingAppProxyHost(proxyHost, frame: proxyFrame)
        XCTAssertTrue(proxy.nameLabel.isHidden, "Reattachment must use the current overlay policy")
        overlay.showsAppLabels = true
        XCTAssertFalse(proxy.nameLabel.isHidden)
        XCTAssertEqual(proxy.bindingToken, binding)
        XCTAssertTrue(proxy.iconView.image === proxyImage)
        XCTAssertEqual(pipeline.stats, stats)
    }
}

private final class AppearanceFixtureIconLoader: IconLoading, @unchecked Sendable {
    private let image = makeIconImage()
    func load(key: IconKey) async throws -> NSImage { image }
}
