import AppKit
import QuartzCore
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

/// Exercises the production owner and its installed callbacks without launching the app,
/// scanning the machine, installing persistence, or ordering a window on screen.
@MainActor
final class AppDelegateBoundedRegressionTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let owner: AppDelegate
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let host: ClickDeliveryProbeView
        let window: QuitOnBlankClickWindow
        let keyboard: KeyboardFocusController
        let search: AppSearchController

        init(contentBeforeWindow: Bool = false, windowed: Bool = false) throws {
            owner = AppDelegate(options: try AppArguments.parse([]).get())
            assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/fixture")],
                                          loader: RecordingIconLoader())
            surface = makeSurface(pageCount: 1, itemsPerPage: 35)
            host = ClickDeliveryProbeView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
            window = QuitOnBlankClickWindow(contentRect: host.bounds,
                                           styleMask: windowed ? [.titled, .closable, .resizable] : [.borderless],
                                           backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            surface.frame = host.bounds
            host.addSubview(surface)
            surface.contentProvider = assembly.provider
            surface.renderer = assembly.renderer
            assembly.renderer.committedPageProvider = { [weak surface] in surface?.core.committedPage ?? 0 }
            keyboard = KeyboardFocusController(columns: 5)
            keyboard.install(on: surface, focusModel: AppGridFocusModel())
            search = AppSearchController(presentation: assembly.searchPresentation,
                                         keyboardController: keyboard, surface: surface)
            search.pendingCommitter = { [weak assembly] page in
                assembly?.commitPendingAtIdleBoundary(currentPage: page)
            }
            search.field.frame = AppDelegate.searchFieldFrame(in: host.bounds, safeAreaTop: 0)
            host.addSubview(search.field)
            if !contentBeforeWindow {
                owner.window = window
                owner.installFolderWindowInput(on: window)
            }
            owner.container = host
            owner.surface = surface
            owner.assembly = assembly
            owner.keyboardController = keyboard
            owner.search = search
            owner.installFolderWiring(assembly: assembly, surface: surface, keyboard: keyboard,
                                      launch: AppLaunchController(surface: surface, assembly: assembly, session: nil))
            owner.installDragUI(surface: surface, assembly: assembly)
            if contentBeforeWindow {
                owner.window = window
                owner.installFolderWindowInput(on: window)
            }
        }

        func present(_ catalog: CatalogSnapshot, folders: [FolderEntry] = []) {
            assembly.provider.receive(catalog)
            if !folders.isEmpty {
                assembly.provider.receiveFolderSnapshot(FolderSnapshot(generation: FolderGeneration(1), entries: folders))
            }
            owner.applyPendingAtIdleBoundary()
            surface.refreshPresentation()
            surface.layoutSubtreeIfNeeded()
        }

        func teardown() {
            owner.closeFolder()
            owner.dragCoordinator?.teardown()
            if DragUISessionCoordinator.shared === owner.dragCoordinator { DragUISessionCoordinator.shared = nil }
            search.teardown()
            assembly.teardown()
            surface.teardown()
        }
    }

    func testPointerDiagnosticsDoNotEnableOrExposeMenusWithoutIsolatedProfile() throws {
        PointerInputDiagnostics.setEnabled(false)
        defer { PointerInputDiagnostics.setEnabled(false) }
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let menu = NSMenu()
        fixture.owner.installPointerInputDiagnosticMenu(in: menu)
        fixture.owner.startPointerInputDiagnostics(nil)
        XCTAssertTrue(menu.items.isEmpty)
        XCTAssertFalse(PointerInputDiagnostics.isEnabled)
    }

    func testWindowedPinchShowPreservesVisibleIconRoutingAcrossRepeatedHideShow() throws {
        let fixture = try Fixture(windowed: true)
        defer { fixture.teardown() }
        let catalog = snapshot((0..<42).map { "Fixture \($0)" })
        let folder = FolderEntry(id: FolderID(), title: "Fixture group",
                                 members: Array(catalog.records.prefix(2).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.surface.autoresizingMask = [.width, .height]
        let launcher = LauncherWindowController(reduceMotionProvider: { true })
        launcher.backgroundUITestMode = true
        launcher.attach(window: fixture.window)
        defer { _ = launcher.terminate() }
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        var clicks = 0
        coordinator.onCellClick = { _ in clicks += 1 }
        for cycle in 0..<3 {
            if cycle > 0 {
                fixture.owner.prepareTransientCancellationForHide()
                _ = launcher.hide(source: .fourFingerPinch, reason: .escape)
            }
            _ = launcher.show(source: .fourFingerPinch, targetScreen: ScreenID(index: 0))
            fixture.host.layoutSubtreeIfNeeded()
            fixture.window.makeFirstResponder(fixture.keyboard)
            let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
            page.layoutSubtreeIfNeeded()
            XCTAssertEqual(page.cellCount, 35, "The control must exercise all visible slots")
            for slot in 0..<35 {
                let cell = try XCTUnwrap(page.cell(at: slot))
                cell.layoutSubtreeIfNeeded()
                // Folder glyph and app image share the same production geometry slot.
                let icon = cell.iconView
                let point = icon.convert(NSPoint(x: icon.bounds.midX, y: icon.bounds.midY), to: nil)
                let rootPoint = fixture.host.convert(point, from: nil)
                XCTAssertTrue(blankClickResolvesToCell(fixture.host.hitTest(rootPoint),
                    at: rootPoint, in: fixture.host), "Cycle \(cycle), slot \(slot)")
                fixture.window.sendEvent(mouse(.leftMouseDown, at: point, window: fixture.window))
                XCTAssertEqual(coordinator.controller.state, .pressed, "Cycle \(cycle), slot \(slot)")
                fixture.window.sendEvent(mouse(.leftMouseDragged,
                    at: NSPoint(x: point.x + 30, y: point.y), window: fixture.window))
                XCTAssertEqual(coordinator.controller.state, .dragging, "Cycle \(cycle), slot \(slot)")
                coordinator.cancel(reason: .escape)
                fixture.window.sendEvent(mouse(.leftMouseUp, at: point, window: fixture.window))
            }
        }
        XCTAssertEqual(clicks, 0, "Cancelled fixture drags must not launch anything")
    }

    func testB1PointerDiagnosticsObserveCancellationAndLateReleaseWithoutChangingRecovery() throws {
        PointerInputDiagnostics.setEnabled(true)
        defer { PointerInputDiagnostics.setEnabled(false) }
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.present(snapshot(["Alpha", "Beta", "Gamma"]))
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        var clicks = 0
        coordinator.onCellClick = { _ in clicks += 1 }
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        cell.layoutSubtreeIfNeeded()
        let point = cell.iconView.convert(NSPoint(x: cell.iconView.bounds.midX, y: cell.iconView.bounds.midY), to: nil)
        PointerInputDiagnostics.reset()
        fixture.window.sendEvent(mouse(.leftMouseDown, at: point, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseDragged, at: NSPoint(x: point.x + 30, y: point.y), window: fixture.window))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        fixture.window.resignKey()
        fixture.owner.windowDidResignKey(.init(name: NSWindow.didResignKeyNotification, object: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseUp, at: point, window: fixture.window))
        XCTAssertEqual(PointerInputDiagnostics.count(.windowDown), 1)
        XCTAssertEqual(PointerInputDiagnostics.count(.b1Down), 1)
        XCTAssertEqual(PointerInputDiagnostics.count(.pressed), 1)
        XCTAssertEqual(PointerInputDiagnostics.count(.dragBegan), 1)
        XCTAssertEqual(PointerInputDiagnostics.count(.windowUp), 1)
        XCTAssertEqual(PointerInputDiagnostics.count(.b1Up), 0, "Resign clears native pairing before late up")
        XCTAssertEqual(PointerInputDiagnostics.count(.committed), 0)
        XCTAssertEqual(clicks, 0)
        fixture.window.sendEvent(mouse(.leftMouseDown, at: point, window: fixture.window))
        XCTAssertEqual(coordinator.controller.state, .pressed)
        fixture.window.sendEvent(mouse(.leftMouseUp, at: point, window: fixture.window))
        XCTAssertEqual(clicks, 1, "A fresh press still works after cancellation")
    }

    func testInlineTitleDraftResizesWithinTitleSlotWithoutMovingMembers() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: catalog.records.map(\.id))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.layoutSubtreeIfNeeded()
        let panel = overlay.panelFrame
        let memberFrames = (0..<overlay.memberCellCount).compactMap { overlay.memberCell(at: $0)?.frame }
        let slot = overlay.titleEditButton.frame
        fixture.owner.beginTitleEditing()
        let editor = try XCTUnwrap(fixture.owner.folderTitleEditor)
        let seedWidth = editor.frame.width
        for draft in [String(repeating: "資料庫👨‍👩‍👧‍👦", count: 40), "", "短"] {
            editor.stringValue = draft
            editor.currentEditor()?.string = draft
            editor.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: editor))
            XCTAssertTrue(fixture.owner.folderTitleEditor === editor)
            XCTAssertEqual(editor.currentEditor()?.string ?? editor.stringValue, draft)
            XCTAssertTrue(slot.contains(editor.frame))
            XCTAssertEqual(editor.frame.midX, slot.midX, accuracy: 0.01)
            XCTAssertEqual(overlay.panelFrame, panel)
            XCTAssertEqual((0..<overlay.memberCellCount).compactMap { overlay.memberCell(at: $0)?.frame }, memberFrames)
            if draft.count > 100 { XCTAssertGreaterThan(editor.frame.width, seedWidth) }
            if draft.isEmpty { XCTAssertLessThan(editor.frame.width, seedWidth) }
        }
    }

    func testTitleInsideClickDoesNotFinishAndOutsideBlankOnlyEndsRename() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installFolderWindowInput(on: fixture.window)
        let catalog = snapshot(["Alpha", "Beta"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: catalog.records.map(\.id))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        fixture.owner.beginTitleEditing()
        let editor = try XCTUnwrap(fixture.owner.folderTitleEditor)
        let inside = editor.convert(NSPoint(x: editor.bounds.midX, y: editor.bounds.midY), to: nil)
        XCTAssertFalse(fixture.owner.handleFolderTitlePointerDown(mouse(.leftMouseDown, at: inside, window: fixture.window)))
        XCTAssertTrue(fixture.owner.folderTitleEditor === editor)
        var blankExits = 0
        fixture.window.onBlankClick = { blankExits += 1 }
        let outside = NSPoint(x: 2, y: 2)
        fixture.window.sendEvent(mouse(.leftMouseDown, at: outside, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseUp, at: outside, window: fixture.window))
        XCTAssertNil(fixture.owner.folderTitleEditor)
        XCTAssertTrue(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertEqual(blankExits, 0)
        XCTAssertTrue(fixture.owner.canApplyFolderAssignment)
    }

    func testInlineTitleEditorFitsTitleAndKeepsItsTypography() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: catalog.records.map(\.id))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.layoutSubtreeIfNeeded()
        let titleSlot = overlay.titleEditButton.frame
        fixture.owner.beginTitleEditing()
        let editor = try XCTUnwrap(fixture.owner.folderTitleEditor)
        XCTAssertEqual(editor.font, overlay.titleEditButton.font)
        XCTAssertLessThan(editor.frame.width, titleSlot.width / 2,
                          "A short title must not become a full-width rename bar")
        XCTAssertEqual(editor.frame.midX, titleSlot.midX, accuracy: 0.01)
        XCTAssertEqual(editor.frame.midY, titleSlot.midY, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(editor.frame.width,
            (folder.title as NSString).size(withAttributes: [.font: editor.font!]).width)
    }

    func testOutsideTitleClickCommitsOnceAndConsumesTheGesture() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installFolderWindowInput(on: fixture.window)
        let catalog = snapshot(["Alpha", "Beta", "Gamma"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: catalog.records.map(\.id))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        fixture.owner.beginTitleEditing()
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let editor = try XCTUnwrap(fixture.owner.folderTitleEditor)
        editor.stringValue = "New name"
        editor.currentEditor()?.string = "New name"
        overlay.layoutSubtreeIfNeeded()
        let member = try XCTUnwrap(overlay.memberCell(at: 0))
        let outside = member.convert(NSPoint(x: member.bounds.midX, y: member.bounds.midY), to: nil)
        let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        var activations = 0, closes = 0
        overlay.onActivateMember = { _ in activations += 1 }
        overlay.onRequestClose = { closes += 1 }
        fixture.window.sendEvent(mouse(.leftMouseDown, at: outside, window: fixture.window))
        XCTAssertNil(fixture.owner.folderTitleEditor, "A content click outside must finish editing")
        fixture.window.sendEvent(mouse(.leftMouseDragged, at: NSPoint(x: outside.x + 35, y: outside.y), window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseUp, at: outside, window: fixture.window))
        let committed = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(committed.folder(id: folder.id)?.title, "New name")
        XCTAssertEqual(committed.generation.value, before.generation.value + 1)
        XCTAssertEqual(committed.folder(id: folder.id)?.members, before.folder(id: folder.id)?.members)
        XCTAssertTrue(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertFalse(fixture.owner.dragCoordinator?.isSessionActive == true)
        XCTAssertEqual(activations, 0)
        XCTAssertEqual(closes, 0)
        editor.commit()
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), committed)
    }

    func testFirstMainPressSurvivesNoChangeIdleBeforeMovement() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: false, moveBeforeIdle: false)
    }

    func testFirstMainDragSurvivesNoChangeIdleBeforeRelease() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: false, moveBeforeIdle: true)
    }

    func testFirstFolderPressSurvivesNoChangeIdleBeforeMovement() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: true, moveBeforeIdle: false)
    }

    func testFirstFolderDragSurvivesNoChangeIdleBeforeRelease() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: true, moveBeforeIdle: true)
    }

    func testRealPendingCatalogStillInvalidatesFirstMainPress() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: false, moveBeforeIdle: false, pendingCatalog: true)
    }

    func testRealPendingCatalogStillInvalidatesFirstFolderDrag() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: true, moveBeforeIdle: true, pendingCatalog: true)
    }

    func testFirstMainPressSurvivesNonBusyCatalogCallback() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: false, moveBeforeIdle: false, catalogCallback: true)
    }

    func testFirstFolderDragSurvivesNonBusyCatalogCallback() throws {
        try exerciseFirstPointerAcrossIdle(inFolder: true, moveBeforeIdle: true, catalogCallback: true)
    }

    func testFirstMainDragSurvivesActualPageSettleAndCommitsOnce() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installCatalogPresentationCallbacks(assembly: fixture.assembly, surface: fixture.surface)
        let catalog = snapshot((0..<80).map { "App\($0)" })
        fixture.present(catalog)
        let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let source = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        source.layoutSubtreeIfNeeded()
        let down = source.iconView.convert(NSPoint(x: source.iconView.bounds.midX,
                                                   y: source.iconView.bounds.midY), to: nil)
        var commits = 0
        let originalCommit = coordinator.onCommit
        coordinator.onCommit = { layout in commits += 1; originalCommit(layout) }
        fixture.window.sendEvent(mouse(.leftMouseDown, at: down, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseDragged, at: NSPoint(x: down.x + 30, y: down.y), window: fixture.window))
        let transaction = try XCTUnwrap(coordinator.controller.activeTransaction)
        XCTAssertEqual(KeyboardPageTurner(surface: fixture.surface).turn(direction: .next, timestamp: 30), .turned(1))
        _ = settleFrames(fixture.surface)
        XCTAssertEqual(fixture.surface.core.committedPage, 1)
        XCTAssertEqual(coordinator.controller.activeTransaction?.opaqueToken, transaction.opaqueToken)
        let target = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 1)?.cell(at: 0))
        let landing = target.convert(NSPoint(x: target.bounds.minX + 1, y: target.bounds.midY), to: nil)
        fixture.window.sendEvent(mouse(.leftMouseDragged, at: landing, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseUp, at: landing, window: fixture.window))
        XCTAssertEqual(commits, 1)
        XCTAssertFalse(coordinator.isSessionActive)
        let committed = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertEqual(committed.appReferenceCount, catalog.records.count)
        var expected = before.topLevelOrder
        let moved = expected.removeFirst()
        expected.insert(moved, at: fixture.surface.itemsPerPage - 1)
        XCTAssertEqual(committed.topLevelOrder, expected,
                       "The retained first drag must land before the visible page's first target")
    }

    private func exerciseFirstPointerAcrossIdle(inFolder: Bool, moveBeforeIdle: Bool,
                                                 pendingCatalog: Bool = false, catalogCallback: Bool = false) throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installFinalCatalogRuntimeCallbacks(assembly: fixture.assembly, surface: fixture.surface)
        let catalog = snapshot(["Alpha", "Beta", "Gamma", "Delta"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: Array(catalog.records.prefix(3).map(\.id)))
        fixture.present(catalog, folders: inFolder ? [folder] : [])
        if inFolder { fixture.owner.openFolder(folderID: folder.id) }
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.layoutSubtreeIfNeeded()
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let source = try XCTUnwrap(inFolder ? overlay.memberCell(at: 0) : page.cell(at: 0))
        let target = try XCTUnwrap(inFolder ? overlay.memberCell(at: 2) : page.cell(at: 2))
        source.layoutSubtreeIfNeeded()
        let down = source.iconView.convert(NSPoint(x: source.iconView.bounds.midX,
                                                   y: source.iconView.bounds.midY), to: nil)
        // Avoid the app-on-app grouping region while choosing a different insertion slot.
        let landing = target.convert(NSPoint(x: target.bounds.minX + 1, y: target.bounds.midY), to: nil)
        let before = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        var commits = 0, clicks = 0
        let originalCommit = coordinator.onCommit
        coordinator.onCommit = { layout in commits += 1; originalCommit(layout) }
        coordinator.onCellClick = { _ in clicks += 1 }
        func deliver(_ type: NSEvent.EventType, _ point: NSPoint) {
            let event = mouse(type, at: point, window: fixture.window)
            if inFolder {
                switch type {
                case .leftMouseDown: overlay.mouseDown(with: event)
                case .leftMouseDragged: overlay.mouseDragged(with: event)
                default: overlay.mouseUp(with: event)
                }
            } else { fixture.window.sendEvent(event) }
        }
        deliver(.leftMouseDown, down)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        if moveBeforeIdle { deliver(.leftMouseDragged, landing) }
        let transaction = try XCTUnwrap(coordinator.controller.activeTransaction)
        if pendingCatalog { fixture.assembly.provider.receive(snapshot(["Alpha", "Beta", "Gamma", "Delta"], revision: 2)) }
        XCTAssertEqual(fixture.assembly.provider.hasPendingPresentationChanges, pendingCatalog)
        // Production callback, not a copied coordinator cancellation policy.
        if catalogCallback { fixture.assembly.refreshController.onStateChange?(.ready) }
        else { fixture.surface.onIdleBoundary?() }
        if pendingCatalog {
            XCTAssertFalse(coordinator.isSessionActive)
            deliver(.leftMouseUp, landing)
            XCTAssertEqual(commits, 0)
        } else {
            XCTAssertEqual(coordinator.controller.activeTransaction?.opaqueToken, transaction.opaqueToken,
                           "A no-change boundary must not consume the first held pointer transaction")
            deliver(.leftMouseDragged, landing)
            deliver(.leftMouseUp, landing)
            XCTAssertEqual(commits, 1, "The first attempt must land without a second down")
            let committed = try XCTUnwrap(fixture.owner.currentPersistentLayout())
            XCTAssertEqual(committed.appReferenceCount, catalog.records.count)
            if inFolder {
                let original = try XCTUnwrap(before.folder(id: folder.id))
                let reordered = try XCTUnwrap(committed.folder(id: folder.id))
                XCTAssertEqual(reordered.members, [original.members[1], original.members[0], original.members[2]],
                               "The first release must insert before the target, not just commit somewhere")
                XCTAssertEqual(committed.topLevelOrder, before.topLevelOrder,
                               "An internal reorder must not change the main grid")
            } else {
                var expected = before.topLevelOrder
                let moved = expected.removeFirst()
                expected.insert(moved, at: 1) // Before original slot 2 after removing original slot 0.
                XCTAssertEqual(committed.topLevelOrder, expected,
                               "The first release must land at the indicated insertion slot")
                XCTAssertEqual(committed.folders, before.folders)
            }
        }
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(clicks, 0)
    }

    func testCollapsedMemberSurvivesActualMainPageSettleAndCommitsOnce() throws {
        try exerciseCollapsedMemberAcrossActualMainPage(injectPendingCatalog: false)
    }

    func testRealPendingCatalogStillInvalidatesCollapsedMemberAcrossMainPage() throws {
        try exerciseCollapsedMemberAcrossActualMainPage(injectPendingCatalog: true)
    }

    private func exerciseCollapsedMemberAcrossActualMainPage(injectPendingCatalog: Bool) throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installCatalogPresentationCallbacks(assembly: fixture.assembly, surface: fixture.surface)
        let titles = (0..<80).map { "App\($0)" }
        let catalog = snapshot(titles)
        let folder = FolderEntry(id: FolderID(), title: "Two apps", members: Array(catalog.records.prefix(2).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.layoutSubtreeIfNeeded()
        let member = try XCTUnwrap(overlay.memberCell(at: 0))
        let down = member.iconView.convert(NSPoint(x: member.iconView.bounds.midX,
                                                   y: member.iconView.bounds.midY), to: nil)
        let exit = overlay.convert(NSPoint(x: overlay.panelFrame.maxX + 20,
            y: member.convert(member.bounds, to: overlay).midY), to: nil)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let originalCommit = coordinator.onCommit
        var commits = 0
        coordinator.onCommit = { layout in commits += 1; originalCommit(layout) }
        overlay.mouseDown(with: mouse(.leftMouseDown, at: down, window: fixture.window))
        overlay.mouseDragged(with: mouse(.leftMouseDragged, at: exit, window: fixture.window))
        XCTAssertTrue(overlay.isMoveOutPresentationCollapsed)
        XCTAssertTrue(coordinator.isSessionActive)
        if injectPendingCatalog { fixture.assembly.provider.receive(snapshot(titles, revision: 2)) }
        XCTAssertEqual(KeyboardPageTurner(surface: fixture.surface).turn(direction: .next, timestamp: 30), .turned(1))
        _ = settleFrames(fixture.surface)
        XCTAssertEqual(fixture.surface.core.committedPage, 1)
        if injectPendingCatalog {
            XCTAssertFalse(coordinator.isSessionActive, "Real catalog change must retain invalidation")
            overlay.mouseUp(with: mouse(.leftMouseUp, at: exit, window: fixture.window))
            XCTAssertEqual(commits, 0)
            return
        }
        XCTAssertTrue(coordinator.isSessionActive, "A pure page-settle idle boundary is not a catalog refresh")
        XCTAssertTrue(overlay.isMoveOutPresentationCollapsed)
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 1))
        let target = try XCTUnwrap(page.cell(at: 0))
        let landing = target.convert(NSPoint(x: target.bounds.minX + 1, y: target.bounds.midY), to: nil)
        overlay.mouseDragged(with: mouse(.leftMouseDragged, at: landing, window: fixture.window))
        overlay.mouseUp(with: mouse(.leftMouseUp, at: landing, window: fixture.window))
        XCTAssertEqual(commits, 1)
        let layout = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        XCTAssertNil(layout.folder(id: folder.id))
        XCTAssertEqual(layout.appReferenceCount, catalog.records.count)
        XCTAssertFalse(coordinator.isSessionActive)
    }

    private func snapshot(_ titles: [String], revision: UInt64 = 1) -> CatalogSnapshot {
        let records = titles.map { title in
            let id = CatalogFixture.appID("fixture.\(title.lowercased())")
            return CatalogFixture.record(id: id, displayName: title, bundleID: "fixture.\(title.lowercased())",
                                         url: CatalogFixture.tempURL(named: "\(title).app"),
                                         icon: IconIdentity.from(appID: id), rootPriority: 0)
        }
        return CatalogSnapshot(revision: CatalogRevision(revision), records: records)
    }

    private func createFolderByWindowDrag(_ fixture: Fixture, source: AppRecord,
                                          target: AppRecord) throws -> PersistentWorkspaceLayout {
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        page.layoutSubtreeIfNeeded()
        func center(of record: AppRecord) throws -> NSPoint {
            let cell = try XCTUnwrap((0..<page.cellCount).compactMap { page.cell(at: $0) }
                .first { ($0.bindingToken?.appID as? AppID) == record.id })
            cell.layoutSubtreeIfNeeded()
            return cell.iconView.convert(NSPoint(x: cell.iconView.bounds.midX,
                                                 y: cell.iconView.bounds.midY), to: nil)
        }
        let down = try center(of: source)
        let release = try center(of: target)
        let previous = try XCTUnwrap(fixture.owner.currentPersistentLayout())
        let originalCommit = coordinator.onCommit
        var commits: [PersistentWorkspaceLayout] = []
        coordinator.onCommit = { layout in commits.append(layout); originalCommit(layout) }
        defer { coordinator.onCommit = originalCommit }
        fixture.window.sendEvent(mouse(.leftMouseDown, at: down, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseDragged, at: release, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseUp, at: release, window: fixture.window))
        XCTAssertEqual(commits.count, 1)
        let committed = try XCTUnwrap(commits.first)
        XCTAssertEqual(committed.generation, previous.generation.incremented())
        let created = try XCTUnwrap(committed.folders.first { folder in
            !previous.folders.contains { $0.id == folder.id }
        })
        XCTAssertEqual(created.members, [.from(record: target), .from(record: source)])
        XCTAssertEqual(fixture.owner.currentPersistentLayout(), committed)
        return committed
    }

    func testAppOnAppWindowDropNamesUnknownCategoriesApps() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta", "Gamma"])
        fixture.present(catalog)
        let committed = try createFolderByWindowDrag(fixture, source: catalog.records[0],
                                                     target: catalog.records[1])
        XCTAssertEqual(committed.folders.first?.title, "Apps")
    }

    func testAppOnAppWindowDropNamesSharedCategoryWithoutEnablingLibrary() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let original = snapshot(["Alpha", "Beta", "Gamma"])
        let records = original.records.map { record in
            AppRecord(id: record.id, displayName: record.displayName,
                bundleIdentifier: record.bundleIdentifier, canonicalURL: record.canonicalURL,
                iconIdentity: record.iconIdentity, sourceRootPriority: record.sourceRootPriority,
                bundleMetadata: .init(declaredCategoryIdentifier: "public.app-category.utilities"))
        }
        let catalog = CatalogSnapshot(revision: original.revision, records: records)
        fixture.present(catalog)
        XCTAssertNil(fixture.owner.appLibraryOwner)
        let committed = try createFolderByWindowDrag(fixture, source: records[0], target: records[1])
        XCTAssertEqual(committed.folders.first?.title, "Utilities")
    }

    func testAppOnAppWindowDropPrefersTheKnownTargetCategoryInEitherDropOrder() throws {
        let original = snapshot(["Alpha", "Beta", "Gamma"])
        let categories = ["public.app-category.games", "public.app-category.utilities", "public.app-category.education"]
        let records = original.records.enumerated().map { index, record in
            AppRecord(id: record.id, displayName: record.displayName,
                bundleIdentifier: record.bundleIdentifier, canonicalURL: record.canonicalURL,
                iconIdentity: record.iconIdentity, sourceRootPriority: record.sourceRootPriority,
                bundleMetadata: .init(declaredCategoryIdentifier: categories[index]))
        }
        let catalog = CatalogSnapshot(revision: original.revision, records: records)
        for (targetIndex, expectedTitle) in [(0, "Games"), (1, "Utilities")] {
            let fixture = try Fixture()
            defer { fixture.teardown() }
            fixture.present(catalog)
            XCTAssertNil(fixture.owner.appLibraryOwner)
            let committed = try createFolderByWindowDrag(fixture, source: records[1 - targetIndex],
                                                         target: records[targetIndex])
            XCTAssertEqual(committed.folders.first?.title, expectedTitle)
        }
    }

    func testAppOnAppWindowDropUsesKnownSourceWhenTargetCategoryIsMissingOrUnknown() throws {
        let targetCategories: [String?] = [nil, "fixture.unrecognized-category"]
        for targetCategory in targetCategories {
            let fixture = try Fixture()
            defer { fixture.teardown() }
            let original = snapshot(["Alpha", "Beta", "Gamma"])
            let records = original.records.enumerated().map { index, record in
                AppRecord(id: record.id, displayName: record.displayName,
                    bundleIdentifier: record.bundleIdentifier, canonicalURL: record.canonicalURL,
                    iconIdentity: record.iconIdentity, sourceRootPriority: record.sourceRootPriority,
                    bundleMetadata: .init(declaredCategoryIdentifier:
                        index == 0 ? "public.app-category.utilities" : targetCategory))
            }
            fixture.present(CatalogSnapshot(revision: original.revision, records: records))
            let committed = try createFolderByWindowDrag(fixture, source: records[0], target: records[1])
            XCTAssertEqual(committed.folders.first?.title, "Utilities")
        }
    }

    func testAppOnAppWindowDropIgnoresCommittedAliasesAndPreservesAppIdentity() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta", "Gamma"])
        var preferences = AppManagementPreferences.default
        preferences = try XCTUnwrap(preferences.settingAlias("Browser", for: catalog.records[0]))
        preferences = try XCTUnwrap(preferences.settingAlias("Notes", for: catalog.records[1]))
        fixture.assembly.provider.receiveManagementPreferences(preferences)
        fixture.present(catalog)
        XCTAssertEqual(fixture.assembly.provider.managementPreferences, preferences)
        let committed = try createFolderByWindowDrag(fixture, source: catalog.records[0],
                                                     target: catalog.records[1])
        XCTAssertEqual(committed.folders.first?.title, "Apps")
        XCTAssertEqual(fixture.assembly.provider.managementPreferences, preferences)
        XCTAssertEqual(fixture.assembly.provider.managementPreferences.alias(for: catalog.records[0]), "Browser")
        XCTAssertEqual(fixture.assembly.provider.managementPreferences.alias(for: catalog.records[1]), "Notes")
        for record in catalog.records {
            XCTAssertEqual(fixture.assembly.provider.record(for: record.id), record)
        }
    }

    func testAppOnAppWindowDropPreservesExistingTitlesAndAvoidsDuplicateName() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta"])
        let existing = FolderEntry(id: FolderID(), title: "Apps",
            members: Array(catalog.records[2...3].map(\.id)))
        let existingPair = FolderEntry(id: FolderID(), title: "Beta & Alpha",
            members: Array(catalog.records[4...5].map(\.id)))
        fixture.present(catalog, folders: [existing, existingPair])
        let committed = try createFolderByWindowDrag(fixture, source: catalog.records[0],
                                                     target: catalog.records[1])
        XCTAssertEqual(committed.folders.count, 3)
        XCTAssertEqual(committed.folder(id: existing.id)?.title, "Apps")
        XCTAssertEqual(committed.folder(id: existing.id)?.members,
                       [.from(record: catalog.records[2]), .from(record: catalog.records[3])])
        XCTAssertEqual(committed.folder(id: existingPair.id)?.title, "Beta & Alpha")
        XCTAssertEqual(committed.folder(id: existingPair.id)?.members,
                       [.from(record: catalog.records[4]), .from(record: catalog.records[5])])
        XCTAssertEqual(committed.folders.first { $0.id != existing.id && $0.id != existingPair.id }?.title, "Apps 2")
    }

    func testAppOnAppWindowDropUsesSingleCommittedTargetOverrideWithLibraryDisabled() async throws {
        let fixture = try Fixture()
        defer { fixture.owner.appLibraryOwner?.teardown(); fixture.teardown() }
        let original = snapshot(["Alpha", "Beta", "Gamma"])
        let categories = ["public.app-category.games", "public.app-category.utilities", "public.app-category.education"]
        let records = original.records.enumerated().map { index, record in
            AppRecord(id: record.id, displayName: record.displayName,
                bundleIdentifier: record.bundleIdentifier, canonicalURL: record.canonicalURL,
                iconIdentity: record.iconIdentity, sourceRootPriority: record.sourceRootPriority,
                bundleMetadata: .init(declaredCategoryIdentifier: categories[index]))
        }
        fixture.present(CatalogSnapshot(revision: original.revision, records: records))
        let preferences = AppLibraryPreferences.default.settingCategory(.education, for: records[1])
        fixture.owner.installAppLibrary(in: fixture.host, store: FolderNamingLibraryStore(preferences))
        let library = try XCTUnwrap(fixture.owner.appLibraryOwner)
        await library.preferences.loadIfNeeded()
        XCTAssertFalse(library.preferences.committed.enabled)
        let committed = try createFolderByWindowDrag(fixture, source: records[0], target: records[1])
        XCTAssertEqual(committed.folders.first?.title, "Education")
        XCTAssertEqual(library.preferences.committed, preferences)
        XCTAssertFalse(library.isOpen)
    }

    func testAppOnAppWindowDropReadsCommittedCategoryOverridesWithLibraryDisabled() async throws {
        let fixture = try Fixture()
        defer { fixture.owner.appLibraryOwner?.teardown(); fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta", "Gamma"])
        fixture.present(catalog)
        let preferences = AppLibraryPreferences.default.settingCategory(.education, for: catalog.records[0])
            .settingCategory(.education, for: catalog.records[1])
        fixture.owner.installAppLibrary(in: fixture.host, store: FolderNamingLibraryStore(preferences))
        let library = try XCTUnwrap(fixture.owner.appLibraryOwner)
        await library.preferences.loadIfNeeded()
        XCTAssertFalse(library.preferences.committed.enabled)
        let committed = try createFolderByWindowDrag(fixture, source: catalog.records[0],
                                                     target: catalog.records[1])
        XCTAssertEqual(committed.folders.first?.title, "Education")
        XCTAssertFalse(library.isOpen)
    }

    private func mouse(_ type: NSEvent.EventType, at point: NSPoint, window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                          windowNumber: window.windowNumber, context: nil, eventNumber: 1,
                          clickCount: 1, pressure: 1)!
    }

    private func exerciseSearchClick(query: String) throws {
        unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.present(snapshot(["Alpha", "Beta"]))
        fixture.search.activateSearch()
        fixture.search.field.stringValue = query
        fixture.search.field.currentEditor()?.string = query
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        fixture.surface.reloadCurrentPresentation()
        fixture.surface.layoutSubtreeIfNeeded()
        XCTAssertTrue(fixture.search.isSearchActive)
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        cell.dragCoordinator = fixture.owner.dragCoordinator
        cell.layoutSubtreeIfNeeded()
        let point = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.maxY - 30), to: nil)
        // Use the shared icon-only routing predicate to ensure the actual B1 path is reached.
        XCTAssertTrue(cell.acceptsLaunchHit(at: cell.convert(point, from: nil)))
        XCTAssertTrue(blankClickResolvesToCell(
            fixture.host.hitTest(point), at: point, in: fixture.host),
            "The fixture must resolve through the real window hit-test after search relayout")
        let recognizer = NSClickGestureRecognizer()
        fixture.surface.addGestureRecognizer(recognizer)
        var clicks = 0
        var commits = 0
        fixture.owner.dragCoordinator?.onCellClick = { _ in clicks += 1 }
        fixture.owner.dragCoordinator?.onCommit = { _ in commits += 1 }
        for _ in 0..<3 {
            fixture.window.sendEvent(mouse(.leftMouseDown, at: point, window: fixture.window))
            XCTAssertTrue(fixture.owner.dragCoordinator?.isSessionActive == true)
            XCTAssertFalse(recognizer.isEnabled)
            XCTAssertEqual(fixture.owner.dragCoordinator?.controller.state, .idle)
            fixture.window.sendEvent(mouse(.leftMouseUp, at: point, window: fixture.window))
            XCTAssertTrue(recognizer.isEnabled)
            XCTAssertFalse(fixture.owner.dragCoordinator?.isSessionActive == true)
        }
        XCTAssertEqual(clicks, 3, "One dispatch per default B1 click while search is active")
        fixture.window.sendEvent(mouse(.leftMouseDown, at: point, window: fixture.window))
        let moved = NSPoint(x: point.x + 100, y: point.y)
        fixture.window.sendEvent(mouse(.leftMouseDragged, at: moved, window: fixture.window))
        fixture.window.sendEvent(mouse(.leftMouseUp, at: moved, window: fixture.window))
        XCTAssertEqual(clicks, 3)
        XCTAssertEqual(commits, 0)
        XCTAssertEqual(fixture.owner.dragCoordinator?.controller.state, .idle)
        XCTAssertTrue(recognizer.isEnabled)
    }

    func testDefaultB1ClickInEmptyActiveSearchDispatchesOnceWithoutDrag() throws {
        try exerciseSearchClick(query: "")
    }

    func testDefaultB1ClickInNonemptyActiveSearchDispatchesOnceWithoutDrag() throws {
        try exerciseSearchClick(query: "Alpha")
    }

    private func exerciseSearchPressCancellation(_ cancel: (Fixture) -> Void) throws {
        let previous = getenv("PAGING_CLICK_MANUAL_DELIVERY").map { String(cString: $0) }
        unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
        defer {
            if let previous { setenv("PAGING_CLICK_MANUAL_DELIVERY", previous, 1) }
            else { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        }
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.present(snapshot(["Alpha", "Beta"]))
        fixture.search.activateSearch()
        fixture.search.field.stringValue = "Alpha"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        fixture.surface.reloadCurrentPresentation()
        fixture.surface.layoutSubtreeIfNeeded()
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        cell.dragCoordinator = coordinator
        cell.layoutSubtreeIfNeeded()
        let point = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.maxY - 30), to: nil)
        XCTAssertTrue(cell.acceptsLaunchHit(at: cell.convert(point, from: nil)))
        let recognizer = NSClickGestureRecognizer()
        fixture.surface.addGestureRecognizer(recognizer)
        var clicks = 0
        var commits = 0
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.onCommit = { _ in commits += 1 }
        fixture.window.sendEvent(mouse(.leftMouseDown, at: point, window: fixture.window))
        XCTAssertTrue(coordinator.isSessionActive)
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(recognizer.isEnabled)
        cancel(fixture)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertTrue(recognizer.isEnabled)
        fixture.window.sendEvent(mouse(.leftMouseUp, at: point, window: fixture.window))
        XCTAssertEqual(clicks, 0, "Canceled press must never dispatch on late release")
        XCTAssertEqual(commits, 0)
    }

    func testSearchPressEscapeCancelsClickOnlyArbitration() throws {
        try exerciseSearchPressCancellation { fixture in
            XCTAssertTrue(fixture.owner.handleEscapeDuringDrag())
        }
    }

    func testSearchPressResignCancelsClickOnlyArbitration() throws {
        try exerciseSearchPressCancellation { fixture in
            fixture.owner.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification,
                                                          object: fixture.window))
        }
    }

    func testSearchPressCatalogRefreshCancelsClickOnlyArbitration() throws {
        try exerciseSearchPressCancellation { $0.owner.applyPendingAtIdleBoundary() }
    }

    func testProductionIdleCommitStagesFoldersBeforeSingleQueryPreservingUpdate() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let old = snapshot(["Alpha", "Beta"])
        let new = snapshot(["Alpha", "Beta", "Alpine", "Delta"], revision: 2)
        fixture.present(old)
        fixture.assembly.searchPresentation.updateQuery(AppSearchQuery(raw: "Al"))
        fixture.owner.applyPendingAtIdleBoundary()
        var generatedFrom: [UInt64] = []
        fixture.assembly.folderSnapshotGenerator = { base in
            generatedFrom.append(base.revision.value)
            return FolderSnapshot(generation: FolderGeneration(2), entries: [
                FolderEntry(id: FolderID(), title: "Group", members: Array(base.records.prefix(2).map(\.id)))
            ])
        }
        var updates = 0
        var refreshUpdates = 0
        fixture.assembly.refreshController.onPresentationUpdate = { _ in refreshUpdates += 1 }
        fixture.assembly.searchPresentation.onPresentationUpdate = { _ in
            updates += 1
            XCTAssertEqual(fixture.assembly.provider.servedRevision, 2)
            XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.folderCount, 1)
            XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.displayName), ["Alpha", "Alpine"])
            XCTAssertFalse(fixture.assembly.provider.hasPendingFolderSnapshot)
            XCTAssertEqual(fixture.assembly.provider.activeQuery, AppSearchQuery(raw: "Al"))
        }
        fixture.assembly.provider.receive(new)
        fixture.owner.applyPendingAtIdleBoundary()
        fixture.owner.applyPendingAtIdleBoundary()
        XCTAssertEqual(generatedFrom, [2])
        XCTAssertEqual(updates, 1)
        XCTAssertEqual(refreshUpdates, 0)
        XCTAssertEqual(fixture.assembly.searchPresentation.currentQuery, AppSearchQuery(raw: "Al"))
    }

    func testIdentifierSearchWaitsForGestureAndReevaluatesSameQueryWithoutHiddenResults() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installFinalCatalogRuntimeCallbacks(assembly: fixture.assembly, surface: fixture.surface)
        let catalog = snapshot(["Alpha", "Beta"])
        let preferences = AppManagementPreferences.default.settingHidden(true, for: catalog.records[1])
        fixture.owner.installAppManagementPreferences(store: InMemoryAppManagementStore(preferences: preferences))
        fixture.present(catalog)
        gestureBegan(fixture.surface, at: 1)
        let state = fixture.surface.core.state
        XCTAssertEqual(state, .tracking)
        fixture.search.field.stringValue = "fixture."
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.id), [catalog.records[0].id],
                       "The held presentation is retained while query and policy are queued")
        let generation = fixture.assembly.searchPresentation.latestGeneration
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(true), .saved)
        fixture.owner.flushPendingIdentifierSearchIfReady()
        XCTAssertEqual(fixture.surface.core.state, state, "Setting does not cancel the held gesture")
        XCTAssertEqual(fixture.owner.pendingIdentifierSearchEnabled, true)
        XCTAssertFalse(fixture.owner.appManagementPreferences.searchByBundleIdentifier)
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.id), [catalog.records[0].id])
        fixture.surface.cancel() // The simulated user finishes input; the setting did not.
        fixture.owner.applyPendingAtIdleBoundary()
        XCTAssertNil(fixture.surface.pinnedPresentation)
        XCTAssertTrue(fixture.owner.languagePresentationIsReady)
        fixture.owner.flushPendingIdentifierSearchIfReady()
        XCTAssertTrue(fixture.owner.appManagementPreferences.searchByBundleIdentifier)
        XCTAssertNil(fixture.owner.pendingIdentifierSearchEnabled)
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.id), [catalog.records[0].id])
        XCTAssertEqual(fixture.assembly.provider.servedRevision, catalog.revision.value)
        XCTAssertEqual(fixture.search.field.stringValue, "fixture.")
        XCTAssertNotEqual(fixture.assembly.searchPresentation.latestGeneration, generation)
    }

    func testIdentifierSearchLatestChoiceAndCoordinatorReplacementRejectOldScheduledApply() async throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.owner.installAppManagementPreferences(store: InMemoryAppManagementStore())
        fixture.owner.identifierSearchPresentationReadinessCheck = { false }
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(true), .saved)
        XCTAssertEqual(fixture.owner.pendingIdentifierSearchEnabled, true)
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(false), .saved)
        XCTAssertNil(fixture.owner.pendingIdentifierSearchEnabled)
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(true), .saved)
        fixture.owner.installAppManagementPreferences(store: InMemoryAppManagementStore())
        fixture.owner.identifierSearchPresentationReadinessCheck = { true }
        await Task.yield()
        fixture.owner.flushPendingIdentifierSearchIfReady()
        XCTAssertFalse(fixture.owner.appManagementPreferences.searchByBundleIdentifier)
        XCTAssertNil(fixture.owner.pendingIdentifierSearchEnabled)
    }

    func testIdentifierSearchDoesNotCloseOpenFolderOrReplaceItsOverlay() throws {
        let (fixture, folder, _) = try folderFixture(reduceMotion: true)
        defer { fixture.teardown() }
        fixture.owner.installFinalCatalogRuntimeCallbacks(assembly: fixture.assembly, surface: fixture.surface)
        fixture.owner.installAppManagementPreferences(store: InMemoryAppManagementStore())
        fixture.owner.openFolder(folderID: folder.id) // Finish the pointer entrance via normal keyboard-open behavior.
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, folder.id)
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(true), .saved)
        fixture.owner.flushPendingIdentifierSearchIfReady()
        XCTAssertTrue(fixture.owner.appManagementPreferences.searchByBundleIdentifier)
        XCTAssertTrue(fixture.owner.folderOverlay === overlay)
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, folder.id)
        XCTAssertEqual(fixture.owner.folderOpenState?.innerPage, 0)
    }

    private func identifierAnchorFixture() throws -> (Fixture, [AppRecord]) {
        let fixture = try Fixture()
        fixture.surface.setReduceMotion(true)
        fixture.owner.installFinalCatalogRuntimeCallbacks(assembly: fixture.assembly, surface: fixture.surface)
        fixture.owner.installAppManagementPreferences(store: InMemoryAppManagementStore())
        let records = (0..<70).map { index -> AppRecord in
            let bundle = "fixture.needle.\(index)"
            let id = CatalogFixture.appID(bundle)
            return CatalogFixture.record(id: id, displayName: index == 0 || index == 69 ? "Needle\(index)" : "Other\(index)",
                bundleID: bundle, url: URL(fileURLWithPath: "/SyntheticIdentifierAnchor/\(index).app"),
                icon: .from(appID: id), rootPriority: 0)
        }
        fixture.present(.init(revision: .init(1), records: records))
        return (fixture, records)
    }

    func testIdentifierSearchReanchorsSelectedIdentityAcrossSameRevisionResultPageChanges() throws {
        let (fixture, records) = try identifierAnchorFixture()
        defer { fixture.teardown() }
        fixture.search.field.stringValue = "Needle"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.count, 2)
        fixture.keyboard.setFocus(to: .init(catalogRevision: 1, pageIndex: 0, slotIndex: 1,
                                            entryIdentity: .app(records[69].id)))
        for (enabled, page, slot) in [(true, 1, 34), (false, 0, 1)] {
            XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(enabled), .saved)
            fixture.owner.flushPendingIdentifierSearchIfReady()
            XCTAssertEqual(fixture.surface.core.committedPage, page)
            XCTAssertEqual(fixture.keyboard.focusModel.current?.entryIdentity, .app(records[69].id))
            XCTAssertEqual(fixture.keyboard.focusModel.current?.pageIndex, page)
            XCTAssertEqual(fixture.keyboard.focusModel.current?.slotIndex, slot)
            XCTAssertEqual(fixture.keyboard.focusModel.current?.catalogRevision, 1)
            XCTAssertEqual(fixture.search.field.stringValue, "Needle")
        }
    }

    func testIdentifierOnlySelectionIsClearedWhenModeTurnsOffWithoutClearingQuery() throws {
        let (fixture, records) = try identifierAnchorFixture()
        defer { fixture.teardown() }
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(true), .saved)
        fixture.owner.flushPendingIdentifierSearchIfReady()
        fixture.search.field.stringValue = "fixture.needle."
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertTrue(fixture.surface.requestPage(1))
        fixture.keyboard.setFocus(to: .init(catalogRevision: 1, pageIndex: 1, slotIndex: 34,
                                            entryIdentity: .app(records[69].id)))
        XCTAssertEqual(fixture.owner.setSearchByBundleIdentifier(false), .saved)
        fixture.owner.flushPendingIdentifierSearchIfReady()
        XCTAssertTrue(fixture.assembly.provider.presentationRecords.isEmpty)
        XCTAssertNil(fixture.keyboard.focusModel.current)
        XCTAssertEqual(fixture.search.field.stringValue, "fixture.needle.")
        XCTAssertNil(fixture.owner.pendingIdentifierSearchEnabled)
    }

    func testFirstPendingCatalogAndFolderCommitPreservesQueryTypedBeforeBaseExists() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.assembly.searchPresentation.updateQuery(AppSearchQuery(raw: "Al"))
        fixture.assembly.folderSnapshotGenerator = { base in
            FolderSnapshot(generation: FolderGeneration(1), entries: [
                FolderEntry(id: FolderID(), title: "Group", members: Array(base.records.prefix(2).map(\.id)))
            ])
        }
        var updates = 0
        fixture.assembly.searchPresentation.onPresentationUpdate = { _ in updates += 1 }
        fixture.assembly.provider.receive(snapshot(["Alpha", "Beta", "Alpine"]))
        fixture.owner.applyPendingAtIdleBoundary()
        XCTAssertEqual(updates, 1)
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.folderCount, 1)
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.map(\.displayName), ["Alpha", "Alpine"])
        XCTAssertEqual(fixture.assembly.provider.activeQuery, AppSearchQuery(raw: "Al"))
        fixture.assembly.searchPresentation.clearQuery()
        fixture.owner.applyPendingAtIdleBoundary()
        XCTAssertEqual(fixture.assembly.provider.presentationEntries.count, 2,
                       "Clearing the query restores the already-committed folder composition")
        XCTAssertEqual(updates, 1)
    }

    func testSearchFieldInputCommitAlsoStagesPendingCatalogFolders() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.present(snapshot(["Alpha", "Beta"]))
        let new = snapshot(["Alpha", "Alpine", "Beta"], revision: 2)
        fixture.assembly.folderSnapshotGenerator = { base in
            FolderSnapshot(generation: FolderGeneration(2), entries: [
                FolderEntry(id: FolderID(), title: "Group", members: Array(base.records.prefix(2).map(\.id)))
            ])
        }
        fixture.assembly.provider.receive(new)
        fixture.search.field.stringValue = "Al"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertEqual(fixture.assembly.provider.servedRevision, 2)
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.folderCount, 1)
        XCTAssertEqual(fixture.assembly.provider.activeQuery, AppSearchQuery(raw: "Al"))
        XCTAssertEqual(fixture.assembly.provider.presentationRecords.count, 2)
        XCTAssertFalse(fixture.assembly.provider.hasPendingFolderSnapshot)
    }

    private func folderFixture(reduceMotion: Bool = false) throws -> (Fixture, FolderEntry, FolderEntry) {
        let fixture = try Fixture()
        fixture.surface.reduceMotionProvider = { reduceMotion }
        let catalog = snapshot(["Alpha", "Beta", "Gamma", "Delta"])
        let a = FolderEntry(id: FolderID(), title: "Group A", members: Array(catalog.records.prefix(2).map(\.id)))
        let b = FolderEntry(id: FolderID(), title: "Group B", members: Array(catalog.records.suffix(2).map(\.id)))
        fixture.present(catalog, folders: [a, b])
        fixture.owner.openFolder(folderID: a.id, animatedFromPointer: true)
        return (fixture, a, b)
    }

    func testPointerFolderOpeningAfterSearchHandsOffEditorAndFirstEscapeClosesFolder() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.surface.reduceMotionProvider = { true }
        let catalog = snapshot(["Alpha", "Beta", "Outside"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: Array(catalog.records.prefix(2).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.search.activateSearch()
        let editor = try XCTUnwrap(fixture.search.field.currentEditor() as? NSTextView)
        editor.string = "Outside"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        editor.string = ""
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertTrue(fixture.window.firstResponder === editor)
        let query = fixture.assembly.searchPresentation.currentQuery
        let generation = fixture.assembly.searchPresentation.latestGeneration

        fixture.assembly.renderer.onFolderClick?(folder.id)

        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, folder.id)
        XCTAssertTrue(fixture.window.firstResponder === fixture.keyboard,
                      "An open folder must own the first Escape, not the background search editor.")
        XCTAssertNil(fixture.keyboard.focusedFolderMember, "Pointer opening keeps deferred member selection.")
        XCTAssertEqual(fixture.search.field.stringValue, "")
        XCTAssertEqual(fixture.assembly.searchPresentation.currentQuery, query)
        XCTAssertEqual(fixture.assembly.searchPresentation.latestGeneration, generation)
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 1, windowNumber: fixture.window.windowNumber,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false, keyCode: 53))
        // Interpret on the actual current responder; never post an OS event or synthesize a second Escape.
        if let fieldEditor = fixture.window.firstResponder as? NSTextView {
            fieldEditor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        } else {
            fixture.window.firstResponder?.keyDown(with: escape)
        }
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertNil(fixture.owner.folderOverlay?.superview)
    }

    func testFolderOpeningFromNonemptySearchPreservesQueryAndDeferredSelection() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta", "Outside"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: Array(catalog.records.prefix(2).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.search.activateSearch()
        let editor = try XCTUnwrap(fixture.search.field.currentEditor() as? NSTextView)
        editor.string = "Outside"
        fixture.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        let query = fixture.assembly.searchPresentation.currentQuery
        let generation = fixture.assembly.searchPresentation.latestGeneration
        fixture.assembly.renderer.onFolderClick?(folder.id)
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, folder.id)
        XCTAssertTrue(fixture.window.firstResponder === fixture.keyboard)
        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        XCTAssertEqual(fixture.search.field.stringValue, "Outside")
        XCTAssertEqual(fixture.assembly.searchPresentation.currentQuery, query)
        XCTAssertEqual(fixture.assembly.searchPresentation.latestGeneration, generation)
    }

    func testFolderOpeningRespectsSearchEditorsNativeRefusalToResign() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: catalog.records.map(\.id))
        fixture.present(catalog, folders: [folder])
        let delegate = FolderSearchFieldEditorDelegate(field: fixture.search.field)
        fixture.window.delegate = delegate
        fixture.search.activateSearch()
        let editor = try XCTUnwrap(fixture.search.field.currentEditor() as? FolderSearchRefusingEditor)
        XCTAssertTrue(editor === delegate.editor)
        editor.string = "Retained draft"
        editor.refusesResignation = true
        fixture.assembly.renderer.onFolderClick?(folder.id)
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertNil(fixture.owner.folderOverlay?.superview)
        XCTAssertTrue(fixture.window.firstResponder === editor)
        XCTAssertEqual(editor.string, "Retained draft")
        editor.refusesResignation = false
        fixture.window.makeFirstResponder(fixture.keyboard)
        fixture.window.delegate = nil
        withExtendedLifetime(delegate) {}
    }

    func testFolderOpeningRejectsOwnerWindowReplacementDuringSearchResignation() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot(["Alpha", "Beta"])
        let folder = FolderEntry(id: FolderID(), title: "Group", members: catalog.records.map(\.id))
        fixture.present(catalog, folders: [folder])
        let delegate = FolderSearchFieldEditorDelegate(field: fixture.search.field)
        fixture.window.delegate = delegate
        fixture.search.activateSearch()
        let editor = try XCTUnwrap(fixture.search.field.currentEditor() as? FolderSearchRefusingEditor)
        var callbackRan = false
        editor.onResign = {
            callbackRan = true
            fixture.owner.window = nil
        }
        fixture.assembly.renderer.onFolderClick?(folder.id)
        XCTAssertTrue(callbackRan, "The test must exercise native responder negotiation reentrancy.")
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertNil(fixture.owner.folderOverlay?.superview)
        fixture.owner.window = fixture.window
        fixture.window.delegate = nil
        withExtendedLifetime(delegate) {}
    }

    func testPointerTransitionMovesOnlyPanelNotModalRoot() throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        XCTAssertNil(overlay.layer?.animation(forKey: "folder.enter"))
        XCTAssertNotNil(overlay.titleEditorHostView.layer?.animation(forKey: "folder.enter"))
        XCTAssertEqual(overlay.layer?.affineTransform(), .identity)
        XCTAssertEqual(overlay.layer?.opacity, 1)
    }

    func testPointerPanelStartsAtActualGlyphAndExitReturnsToIt() throws {
        let (fixture, folder, _) = try folderFixture()
        defer { fixture.teardown() }
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let layer = try XCTUnwrap(overlay.motionPresentationView.layer)
        let glyph = try XCTUnwrap(fixture.assembly.renderer.liveFolderIconFrame(for: folder.id, convertedTo: overlay))
        func projectedCenter(_ transform: CGAffineTransform) -> CGPoint {
            let bounds = layer.bounds
            let relative = CGPoint(x: bounds.midX - (bounds.minX + layer.anchorPoint.x * bounds.width),
                                   y: bounds.midY - (bounds.minY + layer.anchorPoint.y * bounds.height)).applying(transform)
            return CGPoint(x: layer.position.x + relative.x, y: layer.position.y + relative.y)
        }
        let start = try entranceStart(overlay)
        XCTAssertEqual(projectedCenter(start.transform).x, glyph.midX, accuracy: 0.001)
        XCTAssertEqual(projectedCenter(start.transform).y, glyph.midY, accuracy: 0.001)
        XCTAssertEqual(start.transform.a, start.transform.d)
        XCTAssertLessThanOrEqual(layer.bounds.width * start.transform.a, glyph.width + 0.001)
        XCTAssertLessThanOrEqual(layer.bounds.height * start.transform.d, glyph.height + 0.001)
        XCTAssertEqual(layer.animation(forKey: "folder.enter")?.duration, 0.24)
        fixture.owner.closeFolder(animatedFromPointer: true)
        let exit = try XCTUnwrap(layer.animation(forKey: "folder.exit") as? CAAnimationGroup)
        let movement = try XCTUnwrap(exit.animations?.last as? CABasicAnimation)
        let value = try XCTUnwrap(movement.toValue as? NSValue)
        let target = CATransform3DGetAffineTransform(value.caTransform3DValue)
        XCTAssertEqual(projectedCenter(target).x, glyph.midX, accuracy: 0.001)
        XCTAssertEqual(projectedCenter(target).y, glyph.midY, accuracy: 0.001)
        XCTAssertEqual(exit.duration, 0.20)
        XCTAssertEqual(overlay.layer?.affineTransform(), .identity)
    }

    func testPointerEntranceRejectsMemberPressButKeepsOutsideClose() throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let local = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: overlay)
        var activations = 0
        overlay.onActivateMember = { _ in activations += 1 }
        overlay.handleClick(at: local)
        XCTAssertEqual(activations, 0, "A moving miniature must not launch at the settled hit region")
        let point = overlay.convert(local, to: nil)
        overlay.mouseDown(with: mouse(.leftMouseDown, at: point, window: fixture.window))
        XCTAssertFalse(fixture.owner.dragCoordinator?.isSessionActive == true,
                       "A blocked down must never arm a click that releases after settlement")
        overlay.mouseUp(with: mouse(.leftMouseUp, at: point, window: fixture.window))
        overlay.handleClick(at: NSPoint(x: 2, y: 2))
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true, "Outside close remains available")
    }

    func testBlockedEntrancePressCannotLaunchOnReleaseAfterSettlement() async throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let local = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: overlay)
        let point = overlay.convert(local, to: nil)
        var activations = 0
        overlay.onActivateMember = { _ in activations += 1 }
        XCTAssertTrue(overlay.isPanelTransitionActive)
        overlay.mouseDown(with: mouse(.leftMouseDown, at: point, window: fixture.window))
        _ = await waitUntil({ !overlay.isPanelTransitionActive }, timeout: 1)
        XCTAssertFalse(overlay.isPanelTransitionActive)
        overlay.mouseUp(with: mouse(.leftMouseUp, at: point, window: fixture.window))
        XCTAssertEqual(activations, 0)
        XCTAssertFalse(fixture.owner.dragCoordinator?.isSessionActive == true)
        overlay.handleClick(at: local)
        XCTAssertEqual(activations, 1, "Settled member input is restored without rebinding")
    }

    func testCoordinatorBlankClickClosesLogicallyAndRetainsOnlyInertExit() throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        coordinator.pointerDown(locationInWindow: .zero, sourceCell: nil, memberFolderID: nil)
        coordinator.pointerUp(locationInWindow: .zero)
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertTrue(coordinator.visualHost === fixture.surface)
        XCTAssertTrue(overlay.isVisualOnly)
        XCTAssertNotNil(overlay.superview)
        XCTAssertNil(overlay.hitTest(NSPoint(x: 10, y: 10)))
        XCTAssertNotNil(overlay.motionPresentationView.layer?.animation(forKey: "folder.exit"))
        XCTAssertTrue(fixture.owner.handleEscapeDuringDrag()) // The production window Escape hook.
        XCTAssertNil(overlay.superview)
        XCTAssertFalse(overlay.isVisualOnly)
        XCTAssertNil(overlay.motionPresentationView.layer?.animation(forKey: "folder.exit"))
    }

    func testKeyboardEscapeDuringEntranceClosesImmediately() throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                     timestamp: 0, windowNumber: fixture.window.windowNumber, context: nil,
                                     characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                                     isARepeat: false, keyCode: 53)!
        fixture.keyboard.keyDown(with: escape)
        XCTAssertFalse(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertNil(overlay.superview)
        XCTAssertNil(overlay.motionPresentationView.layer?.animation(forKey: "folder.enter"))
        XCTAssertFalse(overlay.isVisualOnly)
    }

    func testEscapeCancelsBothExitVisualAndNewTopLevelPress() throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        fixture.owner.closeFolder(animatedFromPointer: true)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        let coordinator = try XCTUnwrap(fixture.owner.dragCoordinator)
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let recognizer = NSClickGestureRecognizer()
        fixture.surface.addGestureRecognizer(recognizer)
        var clicks = 0
        var commits = 0
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.onCommit = { _ in commits += 1 }
        let point = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.maxY - 30), to: nil)
        coordinator.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        XCTAssertTrue(coordinator.isSessionActive)
        XCTAssertTrue(overlay.isVisualOnly)
        XCTAssertFalse(recognizer.isEnabled)
        XCTAssertTrue(fixture.owner.handleEscapeDuringDrag())
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertNil(overlay.superview)
        XCTAssertTrue(recognizer.isEnabled)
        coordinator.pointerUp(locationInWindow: point)
        XCTAssertEqual(clicks, 0)
        XCTAssertEqual(commits, 0)
    }

    func testPointerExitCompletionDetachesAndClearsVisual() async throws {
        let (fixture, _, _) = try folderFixture()
        defer { fixture.teardown() }
        fixture.owner.closeFolder(animatedFromPointer: true)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        XCTAssertTrue(overlay.isVisualOnly)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(overlay.superview)
        XCTAssertNil(overlay.currentEntry)
        XCTAssertFalse(overlay.isVisualOnly)
    }

    private func interruptedExit(_ fixture: Fixture) throws -> (FolderOverlayView, FolderMotionPresentation) {
        fixture.owner.closeFolder(animatedFromPointer: true)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        XCTAssertTrue(overlay.isVisualOnly)
        // An unattached Core Animation presentation tree may be absent in unit tests.
        // Exercise the production model fallback with the exact interrupted layer values.
        overlay.motionPresentationView.layer?.removeAllAnimations()
        let sampled = FolderMotionPresentation(opacity: 0.43,
                                              transform: CGAffineTransform(translationX: -3, y: 5).scaledBy(x: 0.98, y: 0.98))
        overlay.motionPresentationView.layer?.opacity = sampled.opacity
        overlay.motionPresentationView.layer?.setAffineTransform(sampled.transform)
        return (overlay, sampled)
    }

    private func entranceStart(_ overlay: FolderOverlayView) throws -> FolderMotionPresentation {
        let group = try XCTUnwrap(overlay.motionPresentationView.layer?.animation(forKey: "folder.enter") as? CAAnimationGroup)
        let opacity = try XCTUnwrap(group.animations?.first as? CABasicAnimation)
        let transform = try XCTUnwrap(group.animations?.last as? CABasicAnimation)
        let value = try XCTUnwrap(transform.fromValue as? NSValue)
        return FolderMotionPresentation(opacity: try XCTUnwrap(opacity.fromValue as? NSNumber).floatValue,
                                        transform: CATransform3DGetAffineTransform(value.caTransform3DValue))
    }

    func testPointerReopensSameFolderFromInterruptedExitAndRejectsStaleCompletion() async throws {
        let (fixture, a, _) = try folderFixture()
        defer { fixture.teardown() }
        let (overlay, sampled) = try interruptedExit(fixture)
        fixture.owner.openFolder(folderID: a.id, animatedFromPointer: true)
        XCTAssertEqual(try entranceStart(overlay), sampled)
        XCTAssertFalse(overlay.isVisualOnly)
        XCTAssertTrue(fixture.owner.dragCoordinator?.visualHost === overlay)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNotNil(overlay.superview, "The stale exit completion must not detach a reopened folder")
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, a.id)
        XCTAssertEqual(overlay.motionPresentationView.layer?.opacity, 1)
        XCTAssertEqual(overlay.motionPresentationView.layer?.affineTransform(), .identity)
    }

    func testPointerSwitchToOtherFolderUsesNormalEntranceAndSurvivesOldCompletion() async throws {
        let (fixture, _, b) = try folderFixture()
        defer { fixture.teardown() }
        let (overlay, sampled) = try interruptedExit(fixture)
        fixture.owner.openFolder(folderID: b.id, animatedFromPointer: true)
        let start = try entranceStart(overlay)
        XCTAssertEqual(start.opacity, 0)
        XCTAssertNotEqual(start.transform, sampled.transform)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNotNil(overlay.superview)
        XCTAssertEqual(fixture.owner.folderOpenState?.openFolderID, b.id)
    }

    func testReduceMotionReversalPreservesOpacityAndUsesIdentityTransform() throws {
        let (fixture, a, _) = try folderFixture(reduceMotion: true)
        defer { fixture.teardown() }
        let (overlay, sampled) = try interruptedExit(fixture)
        fixture.owner.openFolder(folderID: a.id, animatedFromPointer: true)
        let start = try entranceStart(overlay)
        XCTAssertEqual(start.opacity, sampled.opacity)
        XCTAssertEqual(start.transform, .identity)
    }

    func testKeyboardReopenSettlesImmediately() throws {
        let (fixture, a, _) = try folderFixture()
        defer { fixture.teardown() }
        let (overlay, _) = try interruptedExit(fixture)
        fixture.owner.openFolder(folderID: a.id)
        XCTAssertNil(overlay.motionPresentationView.layer?.animation(forKey: "folder.enter"))
        XCTAssertEqual(overlay.motionPresentationView.layer?.opacity, 1)
        XCTAssertEqual(overlay.motionPresentationView.layer?.affineTransform(), .identity)
        XCTAssertFalse(overlay.isVisualOnly)
    }

    func testProductionWindowConfigurationRetainsScreenCoveringDefaults() {
        let screen = NSRect(x: -1400, y: 100, width: 1400, height: 900)
        let configuration = AppDelegate.initialWindowConfiguration(
            screenFrame: screen, visibleFrame: screen.insetBy(dx: 0, dy: 30), uiTestWindowed: false)
        XCTAssertEqual(configuration.frame, screen)
        XCTAssertEqual(configuration.styleMask, [.borderless])
        XCTAssertEqual(configuration.collectionBehavior, [.canJoinAllSpaces, .fullScreenAuxiliary])
    }

    func testOptInWindowConfigurationCentersWithinVisibleFrameWithoutJoiningSpaces() {
        for visible in [NSRect(x: -1400, y: 100, width: 1400, height: 860),
                        NSRect(x: 200, y: 80, width: 800, height: 600)] {
            let configuration = AppDelegate.initialWindowConfiguration(
                screenFrame: visible, visibleFrame: visible, uiTestWindowed: true)
            XCTAssertTrue(visible.contains(configuration.frame))
            XCTAssertEqual(configuration.frame.midX, visible.midX)
            XCTAssertEqual(configuration.frame.midY, visible.midY)
            XCTAssertLessThanOrEqual(configuration.frame.width, 1000)
            XCTAssertLessThanOrEqual(configuration.frame.height, 700)
            XCTAssertEqual(configuration.styleMask, [.titled, .closable, .resizable])
            XCTAssertEqual(configuration.collectionBehavior, [])
        }
    }

    func testSearchFrameHonorsSafeAreaAndNonzeroHostOrigin() {
        let bounds = NSRect(x: 90, y: 70, width: 1000, height: 900)
        for inset: CGFloat in [0, 32, 64] {
            let frame = AppDelegate.searchFieldFrame(in: bounds, safeAreaTop: inset)
            XCTAssertEqual(frame.midX, bounds.midX)
            XCTAssertEqual(bounds.maxY - frame.maxY, inset + 12)
            XCTAssertEqual(frame.size, NSSize(width: 300, height: 28))
            XCTAssertTrue(bounds.contains(frame))
        }
    }

    func testSearchFrameClampsSmallBoundsAndInvalidSafeArea() {
        let bounds = NSRect(x: 5, y: 8, width: 100, height: 35)
        XCTAssertTrue(bounds.contains(AppDelegate.searchFieldFrame(in: bounds, safeAreaTop: 64)))
        XCTAssertTrue(bounds.contains(AppDelegate.searchFieldFrame(in: bounds, safeAreaTop: .nan)))
    }

    func testWindowResizeAndScreenChangeRecomputeSearchFrame() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        fixture.host.setBoundsSize(NSSize(width: 800, height: 700))
        fixture.search.field.frame = .zero
        fixture.owner.windowDidResize(Notification(name: NSWindow.didResizeNotification))
        let expected = AppDelegate.searchFieldFrame(in: fixture.host.bounds,
                                                    safeAreaTop: fixture.window.screen?.safeAreaInsets.top ?? 0)
        XCTAssertEqual(fixture.search.field.frame, expected)
        fixture.search.field.frame = .zero
        fixture.owner.windowDidChangeScreen(Notification(name: NSWindow.didChangeScreenNotification))
        XCTAssertEqual(fixture.search.field.frame, expected)
    }
    private final class FolderMountObserver: NSView {
        var onMount: ((FolderOverlayView) -> Void)?
        override func didAddSubview(_ subview: NSView) {
            super.didAddSubview(subview)
            if let overlay = subview as? FolderOverlayView { onMount?(overlay) }
        }
    }

    func testPointerEntranceMountsTransparentWithFinalGeometry() throws {
        let (fixture, folder, _) = try folderFixture()
        defer { fixture.teardown() }
        fixture.owner.closeFolder()
        let observer = FolderMountObserver(frame: fixture.host.bounds)
        fixture.host.addSubview(observer)
        fixture.owner.container = observer
        var mounts = 0
        observer.onMount = { overlay in
            mounts += 1
            XCTAssertEqual(overlay.motionPresentationView.layer?.opacity, 0, "Panel must be transparent before mount")
            XCTAssertEqual(overlay.layer?.opacity, 1, "Modal coverage stays fixed and untransformed")
            XCTAssertEqual(overlay.frame, observer.bounds)
            XCTAssertGreaterThan(overlay.titleEditorFrame.width, 0)
        }
        fixture.owner.openFolder(folderID: folder.id, animatedFromPointer: true)
        XCTAssertEqual(mounts, 1)
        XCTAssertEqual(try entranceStart(XCTUnwrap(fixture.owner.folderOverlay)).opacity, 0)
    }

    private func scrollEvent(_ phase: NSEvent.Phase, x: Int32 = 0) throws -> NSEvent {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                         wheelCount: 2, wheel1: 0, wheel2: x, wheel3: 0))
        // CGScrollPhase and NSEvent.Phase have different raw values for changed/ended.
        let cgPhase: CGScrollPhase = phase == .began ? .began : phase == .changed ? .changed : .ended
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(cgPhase.rawValue))
        let native = try XCTUnwrap(NSEvent(cgEvent: event))
        XCTAssertEqual(native.phase, phase)
        return native
    }

    func testFolderSmallScrollEventsSurviveProductionLikeChromeLayoutRefresh() throws {
        let fixture = try Fixture(contentBeforeWindow: true)
        defer { fixture.owner.teardownLanguagePresentation(); fixture.teardown() }
        fixture.owner.installLanguagePreferences(store: FolderScrollLanguageStore(), preferredLanguages: { ["en"] })
        fixture.host.frame.size = NSSize(width: 1000, height: 668)
        fixture.surface.frame = fixture.host.bounds
        fixture.owner.windowDidResize(Notification(name: NSWindow.didResizeNotification))
        fixture.host.onLayout = { [weak owner = fixture.owner] in
            owner?.refreshMainGridReadability()
            owner?.refreshFolderLayoutIfReady()
        }
        let catalog = snapshot((0..<80).map { "SmallScroll\($0)" })
        let folder = FolderEntry(id: FolderID(), title: "Small-event folder",
            members: Array(catalog.records.prefix(35).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.trackpadPager.automaticallyDrivesFrames = false
        XCTAssertTrue(overlay.canBeginTrackpadPaging?() == true)
        let outerOffset = fixture.surface.presentedOffset
        fixture.window.sendEvent(try scrollEvent(.began))
        for _ in 0..<30 {
            fixture.window.sendEvent(try scrollEvent(.changed, x: 15))
            fixture.host.needsLayout = true
            fixture.host.layoutSubtreeIfNeeded()
        }
        XCTAssertTrue(overlay.isTrackpadPagingActive)
        XCTAssertGreaterThan(overlay.trackpadPager.core.visualOffset, 0.5)
        XCTAssertEqual(fixture.surface.presentedOffset, outerOffset)
        var clock = 20.0
        overlay.trackpadPager.pendingFinishTimeSource = { clock }
        fixture.window.sendEvent(try scrollEvent(.ended))
        clock += 0.101
        for _ in 0..<180 { overlay.trackpadPager.advanceFrame(deltaTime: 1.0 / 60) }
        XCTAssertEqual(overlay.currentInnerPage, 1)
        XCTAssertEqual(fixture.owner.folderOpenState?.innerPage, 1)
    }

    func testWindowRoutesScrollToInnerPagerWithoutMovingOuterPage() throws {
        try exerciseWindowScrollRoute(contentBeforeWindow: false)
    }

    func testContentBeforeWindowRoutesScrollToInnerPagerWithoutMovingOuterPage() throws {
        try exerciseWindowScrollRoute(contentBeforeWindow: true)
    }

    private func exerciseWindowScrollRoute(contentBeforeWindow: Bool) throws {
        let fixture = try Fixture(contentBeforeWindow: contentBeforeWindow)
        defer { fixture.teardown() }
        let catalog = snapshot((0..<80).map { "App\($0)" })
        let folder = FolderEntry(id: FolderID(), title: "Paging folder", members: Array(catalog.records.prefix(35).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        XCTAssertNotNil(fixture.window.onFolderScroll, "Real startup assembles content before creating its window")
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.trackpadPager.automaticallyDrivesFrames = false
        XCTAssertGreaterThan(fixture.surface.core.pageCount, 1, "Background must actually be pageable")
        let outerOffset = fixture.surface.core.visualOffset
        let outerPage = fixture.surface.core.committedPage
        fixture.window.sendEvent(try scrollEvent(.began))
        fixture.window.sendEvent(try scrollEvent(.changed, x: 400))
        XCTAssertGreaterThan(overlay.trackpadPager.core.visualOffset, 0)
        XCTAssertEqual(fixture.surface.core.visualOffset, outerOffset)
        XCTAssertEqual(fixture.surface.core.committedPage, outerPage)
        XCTAssertEqual(fixture.surface.core.state, .idle)
        var clock = 20.0
        overlay.trackpadPager.pendingFinishTimeSource = { clock }
        fixture.window.sendEvent(try scrollEvent(.ended))
        clock += 0.101
        for _ in 0..<180 { overlay.trackpadPager.advanceFrame(deltaTime: 1.0 / 60) }
        XCTAssertEqual(fixture.owner.folderOpenState?.innerPage, 1)
        XCTAssertEqual(overlay.currentInnerPage, 1)
        XCTAssertEqual(overlay.memberAppID(at: 0), folder.members[overlay.membersPerPage])
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(fixture.surface.core.visualOffset, outerOffset)
        XCTAssertEqual(fixture.surface.core.committedPage, outerPage)
        overlay.canBeginTrackpadPaging = { false }
        fixture.window.sendEvent(try scrollEvent(.changed, x: 400))
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(fixture.surface.core.visualOffset, outerOffset, "Rejected folder input cannot fall through")
    }

    func testKeyEquivalentReturnAndEnterCancelFolderMotionBeforeActivation() throws {
        let fixture = try Fixture()
        defer { fixture.teardown() }
        let catalog = snapshot((0..<40).map { "KeyApp\($0)" })
        let folder = FolderEntry(id: FolderID(), title: "Key paging folder", members: Array(catalog.records.prefix(35).map(\.id)))
        fixture.present(catalog, folders: [folder])
        fixture.owner.openFolder(folderID: folder.id)
        let overlay = try XCTUnwrap(fixture.owner.folderOverlay)
        overlay.trackpadPager.automaticallyDrivesFrames = false
        var activations = 0
        fixture.keyboard.onActivateMember = { member in
            activations += 1
            XCTAssertFalse(overlay.isTrackpadPagingActive, "Activation must settle/cancel before choosing an on-screen member")
            XCTAssertFalse(overlay.memberCell(at: 0)?.isHidden ?? true)
            XCTAssertEqual(member, overlay.memberAppID(at: 0))
        }
        for code: UInt16 in [36, 76] {
            overlay.handleTrackpadScroll(phase: .began, momentumPhase: [], deltaX: 0, deltaY: 0,
                                          isDirectionInverted: true, timestamp: 1)
            overlay.handleTrackpadScroll(phase: .changed, momentumPhase: [], deltaX: -400, deltaY: 0,
                                          isDirectionInverted: true, timestamp: 1.1)
            XCTAssertTrue(overlay.isTrackpadPagingActive)
            let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: 1.2, windowNumber: fixture.window.windowNumber,
                context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: code))
            XCTAssertTrue(fixture.keyboard.performKeyEquivalent(with: key))
            overlay.cancelTrackpadPaging()
        }
        XCTAssertEqual(activations, 2)
    }

    func testInstalledWindowScrollRouteResolvesReplacementContentOverlay() throws {
        let fixture = try Fixture(contentBeforeWindow: true)
        defer { fixture.teardown() }
        let catalog = snapshot((0..<40).map { "Replacement\($0)" })
        let folder = FolderEntry(id: FolderID(), title: "Replacement folder", members: Array(catalog.records.prefix(35).map(\.id)))
        fixture.present(catalog, folders: [folder])
        let oldOverlay = try XCTUnwrap(fixture.owner.folderOverlay)
        defer { oldOverlay.teardown() }
        oldOverlay.trackpadPager.automaticallyDrivesFrames = false
        fixture.owner.installFolderWiring(assembly: fixture.assembly, surface: fixture.surface,
            keyboard: fixture.keyboard,
            launch: AppLaunchController(surface: fixture.surface, assembly: fixture.assembly, session: nil))
        fixture.owner.openFolder(folderID: folder.id)
        let replacement = try XCTUnwrap(fixture.owner.folderOverlay)
        XCTAssertFalse(oldOverlay === replacement)
        replacement.trackpadPager.automaticallyDrivesFrames = false
        // Do not reinstall window wiring: its original route must resolve the live overlay.
        fixture.window.sendEvent(try scrollEvent(.began))
        fixture.window.sendEvent(try scrollEvent(.changed, x: 400))
        XCTAssertGreaterThan(replacement.trackpadPager.core.visualOffset, 0)
        XCTAssertEqual(oldOverlay.trackpadPager.core.visualOffset, 0)
        XCTAssertFalse(oldOverlay.isTrackpadPagingActive)
        XCTAssertEqual(fixture.surface.core.visualOffset, 0)
    }

}

@MainActor
private final class FolderSearchRefusingEditor: NSTextView {
    var refusesResignation = false
    var onResign: (() -> Void)?
    override func resignFirstResponder() -> Bool {
        let callback = onResign
        onResign = nil
        callback?()
        return refusesResignation ? false : super.resignFirstResponder()
    }
}

@MainActor
private final class FolderSearchFieldEditorDelegate: NSObject, NSWindowDelegate {
    let field: NSControl
    let editor = FolderSearchRefusingEditor(frame: .zero)
    init(field: NSControl) { self.field = field; super.init(); editor.isFieldEditor = true }
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        (client as? NSControl) === field ? editor : nil
    }
}

@MainActor
private final class FolderScrollLanguageStore: LanguagePreferencesPersisting {
    func load() -> LanguagePreferencesLoadResult { .loaded(.default) }
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult { .saved }
}

private actor FolderNamingLibraryStore: AppLibraryPersisting {
    let value: AppLibraryPreferences
    init(_ value: AppLibraryPreferences) { self.value = value }
    func load() -> AppLibraryLoadResult { .loaded(value) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}
