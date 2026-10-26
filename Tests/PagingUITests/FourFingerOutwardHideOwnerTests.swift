import AppKit
import AppGridUI
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class FourFingerOutwardHideOwnerTests: XCTestCase {
    private final class VisibleWindow: NSWindow {
        var visibleForTest = true
        override var isVisible: Bool { visibleForTest }
    }
    @MainActor
    private final class Fixture {
        let owner = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 2, itemsPerPage: 35)
        let window = VisibleWindow(contentRect: CGRect(x: 0, y: 0, width: 1000, height: 700),
                                   styleMask: [.titled], backing: .buffered, defer: false)
        init() {
            window.isReleasedWhenClosed = false
            window.contentView = surface
            owner.window = window; owner.surface = surface; owner.container = surface
        }
        func teardown() { surface.teardown(); window.contentView = nil }
    }

    func testMissingOrHiddenHostFailsClosedAndVisibleIdleHostAdmits() {
        XCTAssertFalse(AppDelegate(options: .default).fourFingerOutwardHideIsReady)
        let f = Fixture(); defer { f.teardown() }
        XCTAssertTrue(f.owner.fourFingerOutwardHideIsReady)
        f.window.visibleForTest = false
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
    }

    func testHeldPresentationAndTeardownPreventHideWithoutChangingState() {
        let f = Fixture(); defer { f.teardown() }
        f.surface.beginInteraction()
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
        f.surface.endInteraction()
        XCTAssertTrue(f.owner.fourFingerOutwardHideIsReady)
        f.surface.teardown()
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
    }

    func testUnknownTextEditorBlocksEvenEmptyDraft() {
        let f = Fixture(); defer { f.teardown() }
        let editor = NSTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        f.surface.addSubview(editor)
        XCTAssertTrue(f.window.makeFirstResponder(editor))
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
        editor.string = "Unaccepted draft"
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
    }
    func testOpenFolderBlocksOutwardWithoutClosingOrMutatingIt() throws {
        let f = Fixture(); defer { f.teardown() }
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")], loader: RecordingIconLoader())
        defer { f.owner.closeFolder(); f.owner.folderOverlay?.teardown(); assembly.teardown() }
        let keyboard = KeyboardFocusController()
        f.owner.assembly = assembly
        f.owner.keyboardController = keyboard
        f.owner.installFolderWiring(assembly: assembly, surface: f.surface, keyboard: keyboard,
            launch: AppLaunchController(surface: f.surface, assembly: assembly, session: nil))
        let entry = FolderEntry(id: FolderID(), title: "Owned folder", members: [])
        f.owner.folderOpenState?.open(entry)
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
        XCTAssertEqual(f.owner.folderOpenState?.openEntry?.id, entry.id)
    }

    func testUnfocusedSearchDraftStillBlocksAndEmptySearchDoesNot() {
        let f = Fixture(); defer { f.teardown() }
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")], loader: RecordingIconLoader())
        defer { assembly.teardown() }
        let search = AppSearchController(presentation: assembly.searchPresentation, keyboardController: nil, surface: f.surface)
        f.owner.search = search
        XCTAssertTrue(f.owner.fourFingerOutwardHideIsReady)
        search.field.stringValue = "Unsubmitted search draft"
        XCTAssertFalse(f.owner.fourFingerOutwardHideIsReady)
        XCTAssertEqual(search.field.stringValue, "Unsubmitted search draft")
        search.field.stringValue = ""
        XCTAssertTrue(f.owner.fourFingerOutwardHideIsReady)
    }

}
