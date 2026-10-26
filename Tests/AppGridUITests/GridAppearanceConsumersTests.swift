import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

/// Synthetic consumers only. No windows, scans, production data or preference IO.
@MainActor
final class GridAppearanceConsumersTests: XCTestCase {
    private let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!)
    private let large = GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16)
    private let small = GridItemAppearance(preferredIconSide: 32, appLabelFontSize: 9)

    private func token(_ identity: AnyHashable) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 3, pageIdentity: PagePresentationID(revision: 3, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: 2, iconKey: nil, surfaceGeneration: 4)
    }

    private func countLabel(_ cell: AppGridCellView) throws -> NSTextField {
        try XCTUnwrap(cell.subviews.compactMap { $0 as? NSTextField }.first { $0 !== cell.nameLabel })
    }

    private func assertCellGeometry(_ cell: AppGridCellView,
                                    file: StaticString = #filePath, line: UInt = #line) {
        cell.layout()
        let geometry = GridItemContentGeometry(bounds: cell.bounds, appearance: cell.itemAppearance,
                                               showsLabels: cell.showsAppLabels, isFolderCell: cell.isFolderCell,
                                               context: cell.contentLayoutContext)
        XCTAssertEqual(cell.iconView.frame, geometry.iconFrame, file: file, line: line)
        XCTAssertEqual(cell.nameLabel.frame, geometry.nameFrame, file: file, line: line)
        XCTAssertEqual(cell.nameLabel.font?.pointSize, CGFloat(cell.itemAppearance.appLabelFontSize),
                       file: file, line: line)
    }

    func testCellDefaultAndCustomFolderShareSymbolGeometryAndFixedCountFont() async throws {
        let cell = AppGridCellView(frame: CGRect(x: 7, y: 9, width: 100, height: 88))
        XCTAssertEqual(cell.itemAppearance, .default)
        cell.bindFolder(title: "Folder Full Name", memberCount: 35, token: token(AnyHashable(folderID)))
        assertCellGeometry(cell)
        let count = try countLabel(cell)
        XCTAssertEqual(cell.iconView.frame, CGRect(x: 26, y: 28, width: 48, height: 48))
        XCTAssertEqual(cell.nameLabel.frame, CGRect(x: 2, y: 0, width: 96, height: 14))
        XCTAssertEqual(count.frame, CGRect(x: 2, y: 14, width: 96, height: 12))
        cell.itemAppearance = large
        assertCellGeometry(cell)
        let symbol = try XCTUnwrap(cell.subviews.compactMap { $0 as? NSImageView }.first { $0 !== cell.iconView })
        XCTAssertEqual(symbol.frame, cell.iconView.frame)
        XCTAssertEqual(count.font?.pointSize, 10)
        XCTAssertEqual(count.frame.height, 12)
        XCTAssertEqual(count.frame.minY, cell.nameLabel.frame.maxY)
        XCTAssertGreaterThanOrEqual(symbol.frame.minY, count.frame.maxY + 2)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.memberCountText, "35 items")
    }

    func testCellLiveIconAndFontChangesKeepContentFocusAccessibilityAndFittedHitRegion() throws {
        let cell = AppGridCellView(frame: CGRect(x: 7, y: 9, width: 100, height: 88))
        let binding = token(AnyHashable(makeAppID("fixture.iconType.cell")))
        let image = makeIconImage()
        cell.bind(name: "Untruncated Accessible Name", token: binding)
        XCTAssertTrue(cell.applyIconIfValid(image, token: binding))
        cell.setFocused(true)
        let frame = cell.frame
        for appearance in [GridItemAppearance(preferredIconSide: 64), large, small, .default] {
            cell.itemAppearance = appearance
            assertCellGeometry(cell)
            XCTAssertEqual(cell.frame, frame)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertTrue(cell.iconView.image === image)
            XCTAssertTrue(cell.isFocused)
            XCTAssertEqual(cell.boundName, "Untruncated Accessible Name")
            XCTAssertEqual(cell.accessibilityLabel(), cell.boundName)
            XCTAssertEqual(cell.nameLabel.toolTip, cell.boundName)
            let icon = cell.iconView.frame
            XCTAssertTrue(cell.acceptsLaunchHit(at: CGPoint(x: icon.minX - 3, y: icon.midY)))
            XCTAssertFalse(cell.acceptsLaunchHit(at: CGPoint(x: icon.minX - 5, y: icon.midY)))
            XCTAssertFalse(cell.acceptsLaunchHit(at: CGPoint(x: icon.midX, y: cell.nameLabel.frame.midY)))
        }
        cell.itemAppearance = small
        cell.layout()
        XCTAssertFalse(cell.acceptsLaunchHit(at: CGPoint(x: 25, y: 50)),
                       "The former 48pt icon region must not remain a launch target after shrinking")
    }

    func testCellEqualAndInvalidPoliciesHaveNoLayoutOrContentSideEffects() throws {
        let cell = AppGridCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 88))
        cell.itemAppearance = large
        cell.bind(name: "Stable", token: token(AnyHashable(makeAppID("fixture.iconType.noop"))))
        cell.layoutSubtreeIfNeeded()
        cell.needsLayout = false
        let binding = cell.bindingToken
        let font = cell.nameLabel.font
        let icon = cell.iconView.frame
        for appearance in [large, GridItemAppearance(preferredIconSide: 31),
                           GridItemAppearance(appLabelFontSize: 17),
                           GridItemAppearance(preferredIconSide: Int.max, appLabelFontSize: Int.min)] {
            cell.itemAppearance = appearance
            XCTAssertEqual(cell.itemAppearance, large)
            XCTAssertFalse(cell.needsLayout)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertEqual(cell.iconView.frame, icon)
            XCTAssertEqual(cell.nameLabel.font, font)
        }
    }

    func testEmptyFittedIconsNeverCreatePaddedLaunchHitsOverTinyCaptions() {
        for folder in [false, true] {
            for height in [CGFloat(0), 1, 10, 15] {
                let cell = AppGridCellView(frame: CGRect(x: 0, y: 0, width: 100, height: height))
                if folder {
                    cell.bindFolder(title: "Tiny Group", memberCount: 2, token: token(AnyHashable(folderID)))
                } else {
                    cell.bind(name: "Tiny App", token: token(AnyHashable(makeAppID("fixture.iconType.tiny"))))
                }
                cell.layout()
                let icon = cell.iconView.frame
                XCTAssertEqual(icon.width, 0)
                XCTAssertEqual(icon.height, 0)
                let points = [icon.origin,
                              CGPoint(x: icon.midX, y: icon.minY - 1),
                              CGPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY)]
                for point in points {
                    XCTAssertFalse(cell.acceptsLaunchHit(at: point))
                    XCTAssertNil(cell.hitTest(point))
                }
                cell.frame.size = CGSize(width: 0, height: 88)
                cell.showsAppLabels = false
                cell.layout()
                XCTAssertFalse(cell.acceptsLaunchHit(at: cell.iconView.frame.origin))
            }
        }
        let normal = AppGridCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 88))
        normal.layout()
        XCTAssertTrue(normal.acceptsLaunchHit(at: CGPoint(x: 23, y: 52)))
        XCTAssertFalse(normal.acceptsLaunchHit(at: CGPoint(x: 21, y: 52)))
    }

    func testVisibilityInvalidatesFittingAndRetainsAccessibleFolderNamesOnReuse() async throws {
        let cell = AppGridCellView(frame: CGRect(x: 0, y: 0, width: 100, height: 56))
        cell.itemAppearance = large
        cell.bindFolder(title: "Accessible Group", memberCount: 2, token: token(AnyHashable(folderID)))
        cell.layoutSubtreeIfNeeded()
        let fitted = cell.iconView.frame
        cell.needsLayout = false
        cell.showsAppLabels = false
        XCTAssertTrue(cell.needsLayout, "Visibility changes the icon's available fitting space")
        cell.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(cell.iconView.frame.width, fitted.width)
        XCTAssertEqual(cell.accessibilityLabel(), "Accessible Group")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.accessibilityHelp(), "Folder with 2 items")
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertTrue(try countLabel(cell).isHidden)
        cell.needsLayout = false
        cell.showsAppLabels = false
        XCTAssertFalse(cell.needsLayout)
        cell.showsAppLabels = true
        cell.layoutSubtreeIfNeeded()
        XCTAssertEqual(cell.iconView.frame, fitted)
        cell.showsAppLabels = false
        cell.clearContent()
        cell.bind(name: "Reused App", token: token(AnyHashable(makeAppID("fixture.iconType.reuse"))))
        assertCellGeometry(cell)
        XCTAssertEqual(cell.itemAppearance, large)
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertEqual(cell.accessibilityLabel(), "Reused App")
    }

    func testPagePropagatesToLiveNewRetainedPoolReusedAndRecreatedCells() throws {
        let pipeline = IconPipeline(loader: GridAppearanceFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        XCTAssertEqual(page.itemAppearance, .default)
        page.itemAppearance = large
        page.showsAppLabels = false
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0, titles: ["First"]),
                    pageCount: 1, reuseGeneration: 1)
        let retained = try XCTUnwrap(page.cell(at: 0))
        XCTAssertEqual(retained.itemAppearance, large)
        XCTAssertTrue(retained.nameLabel.isHidden)
        page.clearForReuse()
        page.itemAppearance = small
        XCTAssertEqual(retained.itemAppearance, small, "Cleared cells still held by a pooled page need updates")
        page.render(pageIndex: 0, content: makeContent(revision: 2, page: 0, titles: ["Reused"]),
                    pageCount: 1, reuseGeneration: 2)
        XCTAssertTrue(page.cell(at: 0) === retained)
        XCTAssertEqual(retained.itemAppearance, small)
        let folderContent = PagingPageContent(presentationID: PagePresentationID(revision: 3, pageIndex: 0),
                                             items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID),
                                                                          title: "Reused Folder")],
                                             isPlaceholder: false)
        page.render(pageIndex: 0, content: folderContent, pageCount: 1, reuseGeneration: 3)
        XCTAssertTrue(page.cell(at: 0) === retained)
        XCTAssertTrue(retained.isFolderCell)
        page.itemAppearance = large
        XCTAssertEqual(retained.itemAppearance, large)
        page.render(pageIndex: 0, content: makeContent(revision: 4, page: 0, titles: ["New A", "New B"]),
                    pageCount: 1, reuseGeneration: 4)
        XCTAssertFalse(page.cell(at: 0) === retained)
        for index in 0..<2 {
            let cell = try XCTUnwrap(page.cell(at: index))
            XCTAssertEqual(cell.itemAppearance, large)
            XCTAssertTrue(cell.nameLabel.isHidden)
        }
        XCTAssertEqual(pipeline.stats.requests, 0)
    }

    func testPageLivePolicyRelayoutsOrdinarySearchDropFramesAndPreservesIdentity() throws {
        let pipeline = IconPipeline(loader: GridAppearanceFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        page.frame = CGRect(x: 0, y: 0, width: 800, height: 900)
        for mode in [AppGridLayoutMode.ordinary, .search] {
            page.layoutMode = mode
            page.render(pageIndex: 0,
                        content: makeContent(revision: 6, page: 0, titles: (0..<35).map { "Item \($0)" }),
                        pageCount: 3, reuseGeneration: 7)
            page.layout()
            let cells = (0..<35).compactMap { page.cell(at: $0) }
            let frames = cells.map(\.frame)
            let bindings = cells.map(\.bindingToken)
            let generation = page.surfaceGeneration
            let presentation = page.presentationID
            let stats = pipeline.stats
            cells[0].setFocused(true)
            for appearance in [large, small, .default] {
                page.itemAppearance = appearance
                page.layout()
                let expected = MainGridLayoutMetrics.geometry(bounds: page.bounds,
                    itemCount: 35, mode: mode, capacity: page.gridCapacity, appearance: appearance)
                XCTAssertEqual(cells.map(\.frame), (0..<35).map { expected.frame(for: $0, itemCount: 35)! })
                if appearance == .default { XCTAssertEqual(cells.map(\.frame), frames) }
                XCTAssertEqual(cells.map(\.bindingToken), bindings)
                XCTAssertEqual(page.surfaceGeneration, generation)
                XCTAssertEqual(page.presentationID, presentation)
                XCTAssertEqual(page.reuseGeneration, 7)
                XCTAssertEqual(page.pageIndex, 0)
                XCTAssertEqual(page.cellCount, 35)
                XCTAssertEqual(pipeline.stats, stats)
                XCTAssertTrue(cells[0].isFocused)
                for cell in cells {
                    assertCellGeometry(cell)
                    XCTAssertTrue(page.cell(at: CGPoint(x: cell.frame.midX, y: cell.frame.midY)) === cell)
                }
            }
        }
    }

    func testPageAndOverlayRejectInvalidAndEqualUpdatesWithoutTouchingConsumers() throws {
        let pipeline = IconPipeline(loader: GridAppearanceFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { page.teardown(); overlay.teardown() }
        page.itemAppearance = small
        overlay.itemAppearance = small
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0, titles: ["Stable"]),
                    pageCount: 1, reuseGeneration: 1)
        overlay.configure(entry: FolderEntry(id: folderID, title: "Stable Group",
                                            members: [makeAppID("fixture.iconType.invalidMember")]),
                          innerPage: 0, reduceMotion: true) { _ in "Stable Member" }
        let cell = try XCTUnwrap(page.cell(at: 0))
        let member = try XCTUnwrap(overlay.memberCell(at: 0))
        // Drain native layout dirtiness before measuring a setter's no-op behavior.
        page.layoutSubtreeIfNeeded()
        overlay.layoutSubtreeIfNeeded()
        cell.layoutSubtreeIfNeeded()
        member.layoutSubtreeIfNeeded()
        XCTAssertFalse(cell.needsLayout, "The fixture must be clean before changing its policy")
        XCTAssertFalse(member.needsLayout, "The fixture must be clean before changing its policy")
        let stats = pipeline.stats
        let pageGeneration = page.surfaceGeneration
        let folderGeneration = overlay.surfaceGeneration
        for appearance in [small, GridItemAppearance(preferredIconSide: 97),
                           GridItemAppearance(appLabelFontSize: 8)] {
            page.itemAppearance = appearance
            overlay.itemAppearance = appearance
            XCTAssertEqual(page.itemAppearance, small)
            XCTAssertEqual(overlay.itemAppearance, small)
            XCTAssertEqual(cell.itemAppearance, small)
            XCTAssertEqual(member.itemAppearance, small)
            XCTAssertFalse(cell.needsLayout)
            XCTAssertFalse(member.needsLayout)
            XCTAssertEqual(page.surfaceGeneration, pageGeneration)
            XCTAssertEqual(overlay.surfaceGeneration, folderGeneration)
            XCTAssertEqual(pipeline.stats, stats)
        }
    }

    func testPagePendingAndLoadedIconsSurviveIconAndFontOnlyUpdatesWithoutNewKeys() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { drain(loader, pipeline: pipeline) }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        page.frame = CGRect(x: 0, y: 0, width: 800, height: 900)
        let id = makeAppID("fixture.iconType.pending")
        let applied = expectation(description: "Original pending request remains valid after appearance changes")
        page.onIconApplyResult = { _, result in if result == .applied { applied.fulfill() } }
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0, titles: ["Pending"], appIDs: [id]),
                    pageCount: 1, reuseGeneration: 9)
        await waitForPendingLoads(loader, count: 1)
        XCTAssertEqual(loader.pendingKeyCount, 1)
        page.layout()
        let cell = try XCTUnwrap(page.cell(at: 0))
        let binding = try XCTUnwrap(cell.bindingToken)
        let generation = page.surfaceGeneration
        let stats = pipeline.stats
        for appearance in [GridItemAppearance(preferredIconSide: 64), large, large] {
            page.itemAppearance = appearance
            assertCellGeometry(cell)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertEqual(page.surfaceGeneration, generation)
            XCTAssertEqual(pipeline.stats, stats)
        }
        page.showsAppLabels = false
        let key = IconKey(identity: IconIdentity.from(appID: id), pointSize: 48, displayScale: 2)
        XCTAssertEqual(binding.iconKey, key)
        XCTAssertEqual(loader.pendingKeys, [key])
        let image = makeIconImage()
        loader.complete(key: key, image: image)
        await fulfillment(of: [applied], timeout: 3)
        XCTAssertTrue(cell.iconView.image === image)
        page.itemAppearance = small
        page.itemAppearance = GridItemAppearance(preferredIconSide: 32, appLabelFontSize: 16)
        assertCellGeometry(cell)
        XCTAssertTrue(cell.iconView.image === image)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(page.staleIconApplyCount, 0)
        XCTAssertEqual(pipeline.stats.requests, stats.requests)
    }

    func testPageReuseAndTeardownStillRejectCallbacksAfterAppearanceChanges() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { drain(loader, pipeline: pipeline) }
        let page = AppGridPageView(iconPipeline: pipeline)
        defer { page.teardown() }
        let oldID = makeAppID("fixture.iconType.old")
        let currentID = makeAppID("fixture.iconType.current")
        let stale = expectation(description: "Old binding rejected after reuse")
        let terminal = expectation(description: "Current callback ignored after teardown")
        page.onIconApplyResult = { _, result in
            if result == .rejectedStale { stale.fulfill() }
            if result == .ignoredAfterTeardown { terminal.fulfill() }
        }
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0, titles: ["Old"], appIDs: [oldID]),
                    pageCount: 1, reuseGeneration: 1)
        await waitForPendingLoads(loader, count: 1)
        page.itemAppearance = large
        page.clearForReuse()
        page.render(pageIndex: 0, content: makeContent(revision: 2, page: 0, titles: ["Current"], appIDs: [currentID]),
                    pageCount: 1, reuseGeneration: 2)
        await waitForPendingLoads(loader, count: 2)
        let cell = try XCTUnwrap(page.cell(at: 0))
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: oldID), pointSize: 48, displayScale: 2))
        await fulfillment(of: [stale], timeout: 3)
        XCTAssertNil(cell.iconView.image)
        XCTAssertEqual(cell.boundName, "Current")
        XCTAssertEqual(cell.itemAppearance, large)
        page.teardown()
        page.itemAppearance = small
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: currentID), pointSize: 48, displayScale: 2))
        await fulfillment(of: [terminal], timeout: 3)
        XCTAssertNil(cell.iconView.image)
        XCTAssertEqual(page.cellCount, 0)
        XCTAssertEqual(page.staleIconApplyCount, 1)
        XCTAssertEqual(pipeline.stats.requests, 2)
    }

    func testFolderLiveCompressedMembersKeepFramesHeadingInputAndBindings() throws {
        let pipeline = IconPipeline(loader: GridAppearanceFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        overlay.frame = CGRect(x: 0, y: 0, width: 800, height: 900)
        let ids = (0..<35).map { makeAppID("fixture.iconType.member\($0)") }
        let entry = FolderEntry(id: folderID, title: "Unscaled Heading", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true, catalogRevision: 8) { _ in "Member" }
        overlay.layout()
        let cells = (0..<35).compactMap { overlay.memberCell(at: $0) }
        let frames = cells.map(\.frame)
        let bindings = cells.map(\.bindingToken)
        let panel = overlay.panelFrame
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        let heading = try XCTUnwrap(overlay.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }
            .first { $0.stringValue == entry.title })
        let headingFrame = heading.frame
        XCTAssertEqual(cells.count, 35)
        XCTAssertLessThan(cells[0].bounds.height, 88)
        for appearance in [.default, large, small] {
            overlay.itemAppearance = appearance
            overlay.layout()
            XCTAssertEqual(cells.map(\.frame), frames)
            XCTAssertEqual(cells.map(\.bindingToken), bindings)
            XCTAssertEqual(overlay.panelFrame, panel)
            XCTAssertEqual(overlay.currentEntry, entry)
            XCTAssertEqual(overlay.currentInnerPage, 0)
            XCTAssertEqual(overlay.surfaceGeneration, generation)
            XCTAssertEqual(pipeline.stats, stats)
            XCTAssertEqual(heading.font?.pointSize, 22)
            XCTAssertEqual(heading.frame, headingFrame)
            for cell in cells {
                assertCellGeometry(cell)
                XCTAssertGreaterThanOrEqual(cell.iconView.frame.minY, cell.nameLabel.frame.maxY + 2)
                XCTAssertLessThanOrEqual(cell.iconView.frame.maxY, cell.bounds.maxY)
            }
        }
        var activated: AppID?
        overlay.onActivateMember = { activated = $0 }
        let corner = cells[0].convert(CGPoint(x: 1, y: 1), to: overlay)
        XCTAssertFalse(cells[0].acceptsLaunchHit(at: CGPoint(x: 1, y: 1)))
        overlay.handleClick(at: corner)
        XCTAssertEqual(activated, ids[0], "Folder overlay still activates through the whole member cell")
    }

    func testFolderPolicySurvivesClearPagingNewCellsAndVisualResume() throws {
        let pipeline = IconPipeline(loader: GridAppearanceFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        XCTAssertEqual(overlay.itemAppearance, .default)
        overlay.itemAppearance = large
        overlay.showsAppLabels = false
        overlay.membersPerPage = 2
        let ids = (0..<3).map { makeAppID("fixture.iconType.paged\($0)") }
        let entry = FolderEntry(id: folderID, title: "Paged", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "First" }
        let retained = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertEqual(retained.itemAppearance, large)
        overlay.clearContent()
        overlay.itemAppearance = small
        XCTAssertEqual(retained.itemAppearance, small)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Reused" }
        XCTAssertTrue(overlay.memberCell(at: 0) === retained)
        overlay.configure(entry: entry, innerPage: 1, reduceMotion: true) { _ in "New" }
        let newCell = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertFalse(newCell === retained)
        XCTAssertEqual(newCell.itemAppearance, small)
        XCTAssertTrue(newCell.nameLabel.isHidden)
        overlay.setVisualOnly(true)
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        overlay.itemAppearance = large
        overlay.showsAppLabels = true
        XCTAssertEqual(newCell.itemAppearance, small, "A frozen exit must retain its displayed policy")
        XCTAssertTrue(newCell.nameLabel.isHidden)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        overlay.setVisualOnly(false)
        overlay.itemAppearance = large
        XCTAssertEqual(newCell.itemAppearance, large)
        XCTAssertTrue(newCell.nameLabel.isHidden)
        XCTAssertEqual(newCell.accessibilityLabel(), "New")
    }

    func testMoveOutProxyCreationLiveUpdatesReattachmentAndLateMemberIcon() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { drain(loader, pipeline: pipeline) }
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 700))
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        host.addSubview(overlay)
        overlay.frame = host.bounds
        let coordinator = DragUISessionCoordinator(reduceMotionProvider: { true })
        defer { coordinator.teardown() }
        overlay.dragCoordinator = coordinator
        overlay.itemAppearance = large
        overlay.showsAppLabels = false
        let ids = [makeAppID("fixture.iconType.dragged"), makeAppID("fixture.iconType.remaining")]
        let applied = expectation(description: "Late member icon also updates the current proxy")
        overlay.onIconApplyResult = { binding, result in
            if binding.appID == AnyHashable(ids[1]), result == .applied { applied.fulfill() }
        }
        overlay.configure(entry: FolderEntry(id: folderID, title: "Group", members: ids),
                          innerPage: 0, reduceMotion: true) { $0 == ids[0] ? "Dragged" : "Remaining" }
        await waitForPendingLoads(loader, count: 2)
        overlay.layout()
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let remaining = try XCTUnwrap(overlay.memberCell(at: 1))
        let point = source.convert(CGPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                                                   timestamp: 0, windowNumber: 0, context: nil,
                                                   eventNumber: 0, clickCount: 1, pressure: 1))
        overlay.mouseDown(with: event)
        XCTAssertEqual(overlay.moveOutRemainingAppID, ids[1])
        overlay.prepareMoveOutIconCache()
        overlay.setMoveOutPresentationCollapsed(true)
        let frame = CGRect(x: 20, y: 30, width: 100, height: 88)
        overlay.showMoveOutRemainingAppProxy(in: host, frame: frame)
        let proxy = try XCTUnwrap(overlay.moveOutRemainingAppProxy)
        let proxyHost = try XCTUnwrap(overlay.moveOutRemainingAppProxyHost)
        XCTAssertEqual(proxy.itemAppearance, large)
        XCTAssertTrue(proxy.nameLabel.isHidden)
        XCTAssertEqual(proxy.accessibilityLabel(), "Remaining")
        let binding = proxy.bindingToken
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        // Showing an uncached proxy uses the existing fallback request, not a size-specific key.
        XCTAssertEqual(stats.requests, 3)
        for appearance in [small, large, large] {
            overlay.itemAppearance = appearance
            assertCellGeometry(proxy)
            XCTAssertEqual(proxy.itemAppearance, appearance)
            XCTAssertEqual(remaining.itemAppearance, appearance)
            XCTAssertEqual(proxy.bindingToken, binding)
            XCTAssertEqual(overlay.surfaceGeneration, generation)
            XCTAssertEqual(pipeline.stats, stats)
            XCTAssertEqual(overlay.moveOutRemainingAppProxyFrame, frame)
        }
        overlay.showsAppLabels = true
        assertCellGeometry(proxy)
        XCTAssertFalse(proxy.nameLabel.isHidden)
        XCTAssertNil(proxyHost.hitTest(CGPoint(x: frame.midX, y: frame.midY)))
        let image = makeIconImage()
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: ids[1]), pointSize: 48, displayScale: 2),
                        image: image)
        await fulfillment(of: [applied], timeout: 3)
        XCTAssertTrue(proxy.iconView.image === image)
        XCTAssertTrue(remaining.iconView.image === image)
        overlay.clearMoveOutRemainingAppProxy()
        proxyHost.addSubview(proxy)
        host.addSubview(proxyHost)
        proxy.itemAppearance = small
        overlay.showsAppLabels = false
        overlay.reattachMoveOutRemainingAppProxyHost(proxyHost, frame: frame)
        assertCellGeometry(proxy)
        XCTAssertEqual(proxy.itemAppearance, large)
        XCTAssertTrue(proxy.nameLabel.isHidden)
        XCTAssertEqual(proxy.bindingToken, binding)
        XCTAssertTrue(proxy.iconView.image === image)
        XCTAssertEqual(pipeline.stats.requests, stats.requests)
    }

    func testFolderPendingCallbacksKeepBindingsAndRejectReconfigureAndTeardown() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { drain(loader, pipeline: pipeline) }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        let ids = (0..<3).map { makeAppID("fixture.iconType.callback\($0)") }
        let applied = expectation(description: "Appearance-only changes retain pending binding")
        let stale = expectation(description: "Reconfigured folder rejects old identity")
        let terminal = expectation(description: "Torn-down folder rejects current callback")
        overlay.onIconApplyResult = { _, result in
            if result == .applied { applied.fulfill() }
            if result == .rejectedStale { stale.fulfill() }
            if result == .ignoredAfterTeardown { terminal.fulfill() }
        }
        overlay.configure(entry: FolderEntry(id: folderID, title: "Old", members: Array(ids.prefix(2))),
                          innerPage: 0, reduceMotion: true, catalogRevision: 1) { _ in "Old Member" }
        await waitForPendingLoads(loader, count: 2)
        let first = try XCTUnwrap(overlay.memberCell(at: 0))
        let binding = first.bindingToken
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats
        overlay.itemAppearance = GridItemAppearance(preferredIconSide: 64)
        overlay.itemAppearance = large
        overlay.showsAppLabels = false
        XCTAssertEqual(first.bindingToken, binding)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: ids[0]), pointSize: 48, displayScale: 2))
        await fulfillment(of: [applied], timeout: 3)
        XCTAssertNotNil(first.iconView.image)
        overlay.configure(entry: FolderEntry(id: folderID, title: "Current", members: [ids[2]]),
                          innerPage: 0, reduceMotion: true, catalogRevision: 2) { _ in "Current Member" }
        await waitForPendingLoads(loader, count: 2)
        let current = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertEqual(current.itemAppearance, large)
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: ids[1]), pointSize: 48, displayScale: 2))
        await fulfillment(of: [stale], timeout: 3)
        XCTAssertNil(current.iconView.image)
        overlay.teardown()
        overlay.itemAppearance = small
        loader.complete(key: IconKey(identity: IconIdentity.from(appID: ids[2]), pointSize: 48, displayScale: 2))
        await fulfillment(of: [terminal], timeout: 3)
        XCTAssertNil(current.iconView.image)
        XCTAssertEqual(overlay.memberCellCount, 0)
        XCTAssertEqual(overlay.staleIconApplyCount, 1)
        XCTAssertEqual(pipeline.stats.requests, 3)
    }

    func testDelayedProxyFallbackRejectsFrozenClearedReplacedAndTornDownTargets() async throws {
        for disposition in ["frozen", "cleared", "replaced", "teardown"] {
            let loader = GatedIconLoader()
            let pipeline = IconPipeline(loader: loader, limits: .init())
            defer { drain(loader, pipeline: pipeline) }
            let host = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 700))
            let overlay = FolderOverlayView(iconPipeline: pipeline)
            defer { overlay.teardown() }
            host.addSubview(overlay); overlay.frame = host.bounds
            let coordinator = DragUISessionCoordinator(reduceMotionProvider: { true })
            defer { coordinator.teardown() }; overlay.dragCoordinator = coordinator
            let ids = [makeAppID("fixture.proxy.\(disposition).source"), makeAppID("fixture.proxy.\(disposition).remaining")]
            overlay.configure(entry: FolderEntry(id: folderID, title: "Proxy", members: ids),
                              innerPage: 0, reduceMotion: true) { _ in "Fixture" }
            await waitForPendingLoads(loader, count: 2); overlay.layout()
            let source = try XCTUnwrap(overlay.memberCell(at: 0))
            let point = source.convert(CGPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            overlay.mouseDown(with: event); overlay.prepareMoveOutIconCache()
            overlay.setMoveOutPresentationCollapsed(true)
            overlay.showMoveOutRemainingAppProxy(in: host, frame: CGRect(x: 10, y: 10, width: 100, height: 88))
            let original = try XCTUnwrap(overlay.moveOutRemainingAppProxy)
            XCTAssertNil(original.iconView.image)
            let key = IconKey(identity: IconIdentity.from(appID: ids[1]), pointSize: 48, displayScale: 2)
            let delivered = expectation(description: "Loader result delivered for \(disposition)")
            pipeline.request(key: key, generation: 0) { _, _, _ in delivered.fulfill() }
            switch disposition {
            case "frozen": overlay.setVisualOnly(true)
            case "cleared": overlay.clearMoveOutRemainingAppProxy()
            case "replaced": overlay.showMoveOutRemainingAppProxy(in: host, frame: CGRect(x: 20, y: 20, width: 100, height: 88))
            default: overlay.teardown()
            }
            loader.complete(key: key, image: makeIconImage())
            await fulfillment(of: [delivered], timeout: 3)
            XCTAssertNil(original.iconView.image, "An obsolete/frozen target must never receive the late fallback")
            if disposition == "frozen" {
                overlay.setVisualOnly(false)
                let resumed = expectation(description: "Fresh resumed consumer completes")
                pipeline.request(key: key, generation: 0) { _, _, _ in resumed.fulfill() }
                await fulfillment(of: [resumed], timeout: 3)
                XCTAssertNotNil(overlay.memberCell(at: 1)?.iconView.image)
            }
        }
    }

    private func drain(_ loader: GatedIconLoader, pipeline: IconPipeline) {
        pipeline.shutdown()
        for key in loader.pendingKeys { loader.complete(key: key) }
    }
}

private final class GridAppearanceFixtureLoader: IconLoading, @unchecked Sendable {
    private let image = makeIconImage()
    func load(key: IconKey) async throws -> NSImage { image }
}
