import AppKit
import AppCatalogCore
import AppGridUI
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class PageDotOwnerTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let owner = AppDelegate(options: .default)
        let surface: PagingSurface
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")], loader: RecordingIconLoader())
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let keyboard = KeyboardFocusController(columns: 5)
        let catalog: CatalogSnapshot
        init(reduceMotion: Bool = false) {
            surface = makeSurface(pageCount: 3, itemsPerPage: 35, reduceMotion: reduceMotion)
            catalog = .init(revision: CatalogRevision(7), records: (0..<105).map { number in
                let id = CatalogFixture.appID("fixture.dot.\(number)")
                return CatalogFixture.record(id: id, displayName: "App \(number)", bundleID: "fixture.dot.\(number)",
                    url: CatalogFixture.tempURL(named: "App\(number).app"), icon: .from(appID: id), rootPriority: 0)
            })
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            assembly.provider.receive(catalog); _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            surface.refreshPresentation(); host.addSubview(surface)
            owner.surface = surface; owner.container = host; owner.assembly = assembly
            owner.keyboardController = keyboard
            keyboard.install(on: surface, focusModel: .init())
            owner.pageNavigationLifecycleCheck = { true }
            owner.installPageDots(in: host)
            surface.onIdleBoundary = { [weak owner] in owner?.applyPendingAtIdleBoundary() }
        }
        func button(_ page: Int) throws -> NSButton {
            let dots = try XCTUnwrap(owner.pageDotsView)
            return try XCTUnwrap(dots.subviews.compactMap { $0 as? NSButton }.first {
                $0.identifier?.rawValue == "launchcopy.chrome.page-dot.\(page)"
            })
        }
        func key(_ code: UInt16) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: code)!
        }
        func teardown() { surface.teardown(); assembly.teardown(); owner.pageDotsView?.removeFromSuperview() }
    }
    func testActualButtonOwnerSurfaceCoreAndDeferredFinalPageFocus() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        fixture.keyboard.keyDown(with: fixture.key(124))
        XCTAssertNotNil(fixture.keyboard.focusModel.current)
        try fixture.button(2).performClick(nil)
        XCTAssertEqual(fixture.surface.core.activeTransition?.targetPage, 2)
        XCTAssertNil(fixture.keyboard.focusModel.current)
        fixture.keyboard.keyDown(with: fixture.key(124)); XCTAssertNil(fixture.keyboard.focusModel.current)
        settleFrames(fixture.surface)
        XCTAssertEqual(fixture.surface.core.committedPage, 2)
        fixture.keyboard.keyDown(with: fixture.key(124))
        XCTAssertEqual(fixture.keyboard.focusModel.current?.pageIndex, 2)
        XCTAssertEqual(try fixture.button(2).state, .on)
    }
    func testNoOpButtonAndRejectedGestureHaveNoFocusOrTokenEffect() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        fixture.keyboard.keyDown(with: fixture.key(124)); let focus = fixture.keyboard.focusModel.current
        try fixture.button(0).performClick(nil)
        XCTAssertEqual(fixture.keyboard.focusModel.current, focus); XCTAssertEqual(fixture.surface.core.transitionToken, 0)
        gestureBegan(fixture.surface, at: 0); let pin = fixture.surface.pinnedPresentation
        XCTAssertFalse(fixture.owner.requestPageFromDots(2))
        XCTAssertEqual(fixture.keyboard.focusModel.current, focus); XCTAssertEqual(fixture.surface.pinnedPresentation, pin)
    }
    func testInactiveOwnerAndHideResignRejectOldCompletion() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        fixture.owner.pageNavigationLifecycleCheck = { false }; fixture.owner.refreshPageDots()
        XCTAssertFalse(fixture.owner.requestPageFromDots(2)); XCTAssertFalse(try fixture.button(2).isEnabled)
        fixture.owner.pageNavigationLifecycleCheck = { true }; fixture.owner.refreshPageDots()
        _ = fixture.owner.requestPageFromDots(2); let old = try XCTUnwrap(fixture.surface.core.activeTransition)
        fixture.owner.prepareTransientCancellationForHide()
        XCTAssertFalse(fixture.surface.core.completeSettle(old)); XCTAssertEqual(fixture.surface.core.commitCount, 0)
        _ = fixture.owner.requestPageFromDots(2); let second = try XCTUnwrap(fixture.surface.core.activeTransition)
        fixture.owner.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        XCTAssertFalse(fixture.surface.core.completeSettle(second))
    }
    func testReduceMotionClearsFocusBeforeSynchronousCommitAndKeepsChromeHitPath() throws {
        let fixture = Fixture(reduceMotion: true); defer { fixture.teardown() }
        fixture.keyboard.keyDown(with: fixture.key(124))
        try fixture.button(2).performClick(nil)
        XCTAssertEqual(fixture.surface.core.committedPage, 2); XCTAssertNil(fixture.keyboard.focusModel.current)
        XCTAssertTrue(blankClickResolvesToLauncherChrome(fixture.owner.pageDotsView))
        XCTAssertTrue(blankClickResolvesToLauncherChrome(try fixture.button(2)))
    }
    func testSearchInputCancelsDirectRequestAndCommitsSearchCountWithoutLosingQuery() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        let search = AppSearchController(presentation: fixture.assembly.searchPresentation,
                                        keyboardController: fixture.keyboard, surface: fixture.surface)
        fixture.owner.search = search
        fixture.assembly.searchPresentation.onSearchResultCommitted = { [weak surface = fixture.surface] in
            surface?.reloadCurrentPresentation()
        }
        _ = fixture.owner.requestPageFromDots(2); let old = try XCTUnwrap(fixture.surface.core.activeTransition)
        // Return/Down in the field must not transfer stale committed-page focus mid-jump.
        XCTAssertTrue(search.control(search.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertNil(fixture.keyboard.focusModel.current)
        search.field.stringValue = "App 104"
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertFalse(fixture.surface.core.completeSettle(old))
        XCTAssertEqual(fixture.assembly.searchPresentation.currentQuery?.raw, "App 104")
        XCTAssertEqual(fixture.surface.core.pageCount, 1); XCTAssertTrue(fixture.owner.pageDotsView?.isHidden == true)
    }
    func testFolderOpenIgnoresRequestWithoutChangingFolderOrSelection() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        let folder = FolderID()
        fixture.assembly.provider.receiveFolderSnapshot(.init(generation: .zero,
            entries: [.init(id: folder, title: "Fixture", members: Array(fixture.catalog.records.prefix(2).map(\.id)))]))
        _ = fixture.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        fixture.surface.reloadCurrentPresentation()
        fixture.owner.installFolderWiring(assembly: fixture.assembly, surface: fixture.surface, keyboard: fixture.keyboard,
            launch: AppLaunchController(surface: fixture.surface, assembly: fixture.assembly, session: nil))
        fixture.owner.openFolder(folderID: folder)
        defer { fixture.owner.closeFolder() }
        XCTAssertTrue(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertFalse(fixture.owner.requestPageFromDots(2))
        XCTAssertTrue(fixture.owner.folderOpenState?.isOpen == true)
        XCTAssertEqual(fixture.surface.core.transitionToken, 0)
    }
    func testUnloadedCatalogNeverShowsNeutralStartupDotCount() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        let unloaded = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticUnloaded")], loader: RecordingIconLoader())
        defer { unloaded.teardown() }
        fixture.owner.assembly = unloaded; fixture.owner.refreshPageDots()
        XCTAssertTrue(fixture.owner.pageDotsView?.isHidden == true)
        XCTAssertFalse(fixture.owner.requestPageFromDots(2))
        XCTAssertEqual(fixture.surface.core.transitionToken, 0)
    }
    func testActualRendererLongJumpsKeepViewAllocationBounded() {
        let fixture = Fixture(); defer { fixture.teardown() }
        // Multiple real content pages, not neutral-host-only reuse assertions.
        for target in [2, 0, 2, 1, 0, 2, 0] {
            XCTAssertTrue(fixture.owner.requestPageFromDots(target))
            settleFrames(fixture.surface)
            XCTAssertEqual(fixture.surface.core.committedPage, target)
            XCTAssertLessThanOrEqual(fixture.assembly.renderer.livePageInstanceCount, 7)
            XCTAssertLessThanOrEqual(fixture.assembly.renderer.totalInstancesCreated, 14)
        }
    }

    func testMountedDotStripFitsExistingGridGutterAcrossWindowSizes() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        for height: CGFloat in [640, 700, 956] {
            fixture.host.frame.size.height = height
            fixture.owner.windowDidResize(Notification(name: NSWindow.didResizeNotification))
            let dots = try XCTUnwrap(fixture.owner.pageDotsView)
            let grid = AppGridGeometry(bounds: fixture.host.bounds, itemCount: 35, mode: .ordinary)
            let last = try XCTUnwrap(grid.frame(for: 34, itemCount: 35))
            XCTAssertLessThanOrEqual(dots.frame.maxY, last.minY)
            XCTAssertGreaterThanOrEqual(dots.frame.minY, fixture.host.bounds.minY)
        }
    }

}
