import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

/// Actual application assembly in unshown synthetic windows, not native acceptance.
@MainActor
final class AdaptiveFolderOwnerTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let owner = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticAdaptive")], loader: RecordingIconLoader())
        let host: NSView
        let keyboard = KeyboardFocusController(columns: 5)
        let window: NSWindow
        let folder = FolderID()
        let catalog: CatalogSnapshot
        init(size: NSSize = NSSize(width: 1000, height: 700)) {
            _ = NSApplication.shared
            host = NSView(frame: NSRect(origin: .zero, size: size))
            window = NSWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host
            catalog = .init(revision: CatalogRevision(7), records: (0..<40).map { number in
                let name = "fixture.adaptive.\(number)", id = CatalogFixture.appID(name)
                return CatalogFixture.record(id: id, displayName: "App \(number)", bundleID: name,
                    url: CatalogFixture.tempURL(named: "Adaptive\(number).app"), icon: .from(appID: id), rootPriority: 0)
            })
            surface.frame = host.bounds; host.addSubview(surface)
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            assembly.renderer.committedPageProvider = { [weak surface] in surface?.core.committedPage ?? -1 }
            owner.surface = surface; owner.container = host; owner.assembly = assembly; owner.window = window
            owner.keyboardController = keyboard; keyboard.install(on: surface, focusModel: .init())
            owner.installFolderWiring(assembly: assembly, surface: surface, keyboard: keyboard,
                launch: AppLaunchController(surface: surface, assembly: assembly, session: nil))
            owner.installDragUI(surface: surface, assembly: assembly)
            assembly.provider.receive(catalog); _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            surface.refreshPresentation()
            let refs = catalog.records.map { PersistentAppReference.from(record: $0) }
            let layout = PersistentWorkspaceLayout(generation: .zero,
                topLevelOrder: [.folder(folder)] + refs.dropFirst(35).map { .app($0) },
                folders: [.init(id: folder, title: "Adaptive Group", members: Array(refs.prefix(35)))])
            _ = assembly.provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
            surface.refreshPresentation(); surface.reloadCurrentPresentation(); surface.layoutSubtreeIfNeeded()
            owner.openFolder(folderID: folder); owner.folderOverlay?.layoutSubtreeIfNeeded()
        }
        func teardown() {
            owner.dragCoordinator?.teardown()
            if DragUISessionCoordinator.shared === owner.dragCoordinator { DragUISessionCoordinator.shared = nil }
            owner.closeFolder(); owner.folderOverlay?.teardown(); surface.teardown(); assembly.teardown()
            window.delegate = nil; window.contentView = nil
        }
    }

    func testRegularFolderUsesFifteenUsefulSlotsWithoutChangingOuterCapacity() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, 15)
        XCTAssertEqual(f.owner.folderOpenState?.innerPageCount, 3)
        XCTAssertEqual(overlay.memberCellCount, 15)
        XCTAssertEqual(f.surface.itemsPerPage, 35)
    }

    func testAllThirtyFiveMembersRemainOrderedAcrossThreePagesAndPartialPageSlotsStayFixed() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let expected = try XCTUnwrap(f.owner.folderOpenState?.openEntry?.members)
        var observed: [AppID] = []
        let firstFrame = try XCTUnwrap(overlay.memberCell(at: 0)?.frame)
        for page in 0..<3 {
            XCTAssertEqual(f.owner.folderOpenState?.innerPage, page)
            observed += (0..<overlay.memberCellCount).compactMap { overlay.memberAppID(at: $0) }
            XCTAssertEqual(overlay.memberCell(at: 0)?.frame, firstFrame)
            if page < 2 { overlay.nextPage(); overlay.layoutSubtreeIfNeeded() }
        }
        XCTAssertEqual(observed, expected)
        XCTAssertEqual(Set(observed).count, 35)
        XCTAssertEqual(overlay.memberCellCount, 5)
        XCTAssertEqual(f.surface.itemsPerPage, 35)
    }

    func testMaximumPreferencesReduceCompactCapacityWithoutShrinkingRequestedIcons() throws {
        let f = Fixture(size: NSSize(width: 700, height: 500)); defer { f.teardown() }
        f.owner.installAppearancePreferences(store: InMemoryAppearancePreferencesStore())
        f.owner.applyAppearancePreferences(.init(preferredIconSide: 64, appLabelFontSize: 16))
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, 8)
        XCTAssertEqual(overlay.memberCellCount, 8)
        for index in 0..<overlay.memberCellCount {
            let cell = try XCTUnwrap(overlay.memberCell(at: index)); cell.layoutSubtreeIfNeeded()
            XCTAssertEqual(cell.iconView.frame.width, 64, accuracy: 0.001)
        }
        f.owner.applyAppearancePreferences(.init(showsAppLabels: false, preferredIconSide: 64, appLabelFontSize: 16))
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, 8)
    }

    private func key(_ code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: code)!
    }

    func testActualPageButtonReturnNeverActivatesOldPageSelection() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        var activated: [AppID] = []
        f.keyboard.onActivateMember = { activated.append($0) }
        f.keyboard.keyDown(with: key(124))
        XCTAssertNotNil(f.keyboard.focusedFolderMember)
        overlay.nextPage()
        XCTAssertNil(f.keyboard.focusedFolderMember)
        XCTAssertEqual(f.owner.folderOpenState?.innerPage, 1)
        f.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [try XCTUnwrap(overlay.memberAppID(at: 0))])
        f.keyboard.keyDown(with: key(124))
        XCTAssertEqual(f.keyboard.focusedFolderMember, overlay.memberAppID(at: 0))
    }

    func testUnavailablePresentationBlocksPointerKeyboardAndDragThenRecoversAnchor() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        overlay.nextPage()
        let anchor = try XCTUnwrap(overlay.memberAppID(at: 0))
        var activated: [AppID] = []
        f.keyboard.onActivateMember = { activated.append($0) }
        overlay.onActivateMember = { activated.append($0) }
        f.host.setFrameSize(NSSize(width: 180, height: 150))
        f.owner.refreshFolderLayoutIfReady(); overlay.layoutSubtreeIfNeeded()
        XCTAssertFalse(try XCTUnwrap(f.owner.folderOpenState).isMemberPresentationAvailable)
        XCTAssertFalse(overlay.isMemberPresentationAvailable)
        f.keyboard.keyDown(with: key(36)); f.keyboard.keyDown(with: key(124))
        overlay.handleClick(at: NSPoint(x: overlay.panelFrame.midX, y: overlay.panelFrame.midY))
        XCTAssertTrue(activated.isEmpty)
        XCTAssertNil(f.keyboard.focusedFolderMember)
        XCTAssertTrue(overlay.memberDragItemFrames(convertedTo: f.host, catalog: f.catalog).isEmpty)
        f.host.setFrameSize(NSSize(width: 1000, height: 700))
        f.owner.refreshFolderLayoutIfReady(); overlay.layoutSubtreeIfNeeded()
        XCTAssertTrue(overlay.isMemberPresentationAvailable)
        XCTAssertEqual(f.owner.folderOpenState?.innerPage, 1)
        XCTAssertEqual(overlay.memberAppID(at: 0), anchor)
        XCTAssertEqual(f.owner.folderOpenState?.openEntry?.members.count, 35)
    }

    func testResizeKeepsMountedTitleEditorWithoutConfigureOrLosingItsDraft() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let editor = NSTextField(string: "Unaccepted title draft")
        overlay.titleEditingEnabled = true
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        let generation = overlay.surfaceGeneration
        f.host.setFrameSize(NSSize(width: 540, height: 500))
        f.owner.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: f.window))
        overlay.layoutSubtreeIfNeeded()
        XCTAssertTrue(overlay.titleEditorView === editor)
        XCTAssertEqual(editor.stringValue, "Unaccepted title draft")
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertFalse(overlay.isMemberPresentationAvailable)
        XCTAssertTrue(f.host.bounds.contains(overlay.panelFrame))
        XCTAssertTrue(overlay.titleEditorHostView.bounds.contains(editor.frame))
        overlay.unmountTitleEditor(); f.owner.refreshFolderLayoutIfReady()
        XCTAssertEqual(f.owner.folderOpenState?.columns, 3)
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, 6)
        XCTAssertTrue(overlay.isMemberPresentationAvailable)
    }

    func testSecondPageDragGeometryRetainsCanonicalMemberIndicesAndOuterMoveOutAnnotations() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        overlay.nextPage()
        let drag = try XCTUnwrap(f.owner.dragCoordinator)
        let geometry = try XCTUnwrap(drag.geometryProvider(.folder(f.folder)))
        XCTAssertEqual(geometry.page, 1)
        XCTAssertEqual(geometry.pageCount, 3)
        XCTAssertEqual(geometry.itemFrames.map(\.logicalIndex), (15..<30).map { Optional($0) })
        XCTAssertTrue(geometry.itemFrames.allSatisfy { $0.pageIndex == nil })
        XCTAssertFalse(geometry.topLevelFrames.isEmpty)
        XCTAssertTrue(geometry.topLevelFrames.allSatisfy { $0.itemsPerPage == 35 && $0.pageIndex == 0 })
        let before = try XCTUnwrap(f.owner.currentPersistentLayout())
        drag.folderPageTurn(1)
        XCTAssertEqual(f.owner.folderOpenState?.innerPage, 2)
        XCTAssertEqual(f.owner.currentPersistentLayout(), before)
    }

    func testHeldPointerFreezesCapacityUntilExplicitResizeCancellation() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let drag = try XCTUnwrap(f.owner.dragCoordinator)
        let point = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        drag.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: f.folder)
        XCTAssertTrue(drag.isSessionActive)
        f.host.setFrameSize(NSSize(width: 540, height: 500))
        f.owner.refreshFolderLayoutIfReady()
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, 15)
        XCTAssertFalse(overlay.isMemberPresentationAvailable)
        f.owner.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: f.window))
        XCTAssertFalse(drag.isSessionActive)
        XCTAssertEqual(f.owner.folderOpenState?.membersPerPage, 6)
        XCTAssertTrue(overlay.isMemberPresentationAvailable)
    }

    func testMenuCreatedBeforeMemberPresentationIsHiddenCannotLaunchIt() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let menus = AppContextMenuController(recordProvider: { id in f.catalog.records.first { $0.id == id } },
            revisionProvider: { 7 }, hiddenProvider: { _ in false })
        var launched: [AppID] = []; menus.onLaunch = { launched.append($0) }
        let menu = try XCTUnwrap(menus.menu(for: cell))
        let launch = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.launch" })
        let binding = cell.bindingToken
        overlay.setMemberPresentationAvailable(false)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertNil(menus.menu(for: cell))
        _ = NSApplication.shared.sendAction(try XCTUnwrap(launch.action), to: launch.target, from: launch)
        XCTAssertTrue(launched.isEmpty)
    }

    func testEditingTitleResizeRoundTripRestoresAllFrozenPageFramesAndEditor() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let editor = NSTextField(string: "Round trip draft")
        overlay.titleEditingEnabled = true
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        let generation = overlay.surfaceGeneration
        let original = (0..<15).compactMap { overlay.memberCell(at: $0)?.frame }
        f.host.setFrameSize(NSSize(width: 540, height: 500))
        f.owner.refreshFolderLayoutIfReady(); overlay.layoutSubtreeIfNeeded()
        f.host.setFrameSize(NSSize(width: 1000, height: 700))
        f.owner.refreshFolderLayoutIfReady(); overlay.layoutSubtreeIfNeeded()
        XCTAssertTrue(overlay.titleEditorView === editor)
        XCTAssertEqual(editor.stringValue, "Round trip draft")
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertTrue(overlay.isMemberPresentationAvailable)
        XCTAssertEqual((0..<15).compactMap { overlay.memberCell(at: $0)?.frame }, original)
        XCTAssertTrue((0..<15).allSatisfy { overlay.memberCell(at: $0)?.isHidden == false })
    }

    func testInsufficientSpaceVisibleChromeNeverOverlapsOrEscapesPanel() throws {
        let f = Fixture(); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        for size in [NSSize(width: 180, height: 150), NSSize(width: 180, height: 70), NSSize(width: 400, height: 270)] {
            f.host.setFrameSize(size); f.owner.refreshFolderLayoutIfReady(); overlay.layoutSubtreeIfNeeded()
            XCTAssertFalse(overlay.isMemberPresentationAvailable)
            let panel = overlay.titleEditorHostView
            // The material intentionally covers the panel; it is not foreground chrome.
            let material = try XCTUnwrap(panel.subviews.compactMap { $0 as? NSVisualEffectView }.first)
            XCTAssertTrue(panel.subviews.first === material)
            XCTAssertEqual(material.frame, panel.bounds)
            XCTAssertNil(material.hitTest(NSPoint(x: 1, y: 1)))
            // The transparent title edit hit target intentionally shares the title label frame.
            let visible = panel.subviews.filter {
                !$0.isHidden && $0 !== material && $0 !== overlay.titleEditButton && !$0.frame.isEmpty
            }
            for (index, view) in visible.enumerated() {
                XCTAssertTrue(panel.bounds.contains(view.frame))
                for other in visible.dropFirst(index + 1) {
                    XCTAssertFalse(view.frame.intersects(other.frame))
                }
            }
            XCTAssertTrue(visible.contains { ($0 as? NSButton)?.title == "Close folder" })
        }
    }

    func testCompactFolderKeepsDefaultRequestedIconsInsteadOfInvisibleGlyphs() throws {
        let f = Fixture(size: NSSize(width: 700, height: 500)); defer { f.teardown() }
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        XCTAssertLessThan(overlay.memberCellCount, 35)
        for index in 0..<overlay.memberCellCount {
            let cell = try XCTUnwrap(overlay.memberCell(at: index)); cell.layoutSubtreeIfNeeded()
            XCTAssertGreaterThanOrEqual(cell.iconView.frame.width, 48)
        }
    }
}
