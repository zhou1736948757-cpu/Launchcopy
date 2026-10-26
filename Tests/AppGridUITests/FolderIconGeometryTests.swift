import AppCatalogCore
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class FolderIconGeometryTests: XCTestCase {
    private func token(_ identity: AnyHashable?) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 1,
                         pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: 1,
                         iconKey: nil, surfaceGeneration: 1)
    }

    private func makeCell() -> AppGridCellView {
        let cell = AppGridCellView(frame: NSRect(x: 7, y: 9, width: 100, height: 88))
        cell.bindFolder(title: "Group", memberCount: 2, token: token(AnyHashable(FolderID())))
        cell.layout()
        return cell
    }

    private func symbol(in cell: AppGridCellView) throws -> NSImageView {
        try XCTUnwrap(cell.subviews.compactMap { $0 as? NSImageView }
            .first { $0 !== cell.iconView })
    }

    func testSourceIsActualGlyphFrameWithoutCaptionOrHitPadding() throws {
        let cell = makeCell()
        let symbol = try symbol(in: cell)
        let frame = try XCTUnwrap(cell.folderMotionSourceFrame)
        XCTAssertEqual(frame, symbol.frame)
        XCTAssertLessThan(frame.width, cell.bounds.width)
        XCTAssertLessThan(frame.height, cell.bounds.height)
        XCTAssertFalse(frame.intersects(cell.nameLabel.frame))
        XCTAssertTrue(cell.acceptsLaunchHit(at: NSPoint(x: frame.minX - 3, y: frame.midY)))
        XCTAssertFalse(frame.contains(NSPoint(x: frame.minX - 3, y: frame.midY)))

        // Distinguish actual symbol geometry from recomputation or the app-icon slot.
        let actual = frame.insetBy(dx: 3, dy: 5).offsetBy(dx: 1, dy: -1)
        symbol.frame = actual
        XCTAssertNotEqual(actual, cell.iconView.frame)
        XCTAssertEqual(cell.folderMotionSourceFrame, actual)
    }

    func testSourceTracksLayoutWithoutMutatingBindingOrLayoutOnRead() throws {
        let cell = makeCell()
        let binding = cell.bindingToken
        let original = try XCTUnwrap(cell.folderMotionSourceFrame)
        cell.itemAppearance = GridItemAppearance(preferredIconSide: 32)
        cell.showsAppLabels = false
        cell.layoutSubtreeIfNeeded()
        let symbol = try symbol(in: cell)
        cell.needsLayout = false
        XCTAssertEqual(cell.folderMotionSourceFrame, symbol.frame)
        XCTAssertNotEqual(cell.folderMotionSourceFrame, original)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertFalse(cell.needsLayout, "Reading geometry must not schedule or perform layout")
    }

    func testSourceRejectsUnboundNonFolderAndReusedCell() {
        let cell = makeCell()
        XCTAssertNotNil(cell.folderMotionSourceFrame)
        cell.clearContent()
        XCTAssertNil(cell.folderMotionSourceFrame)
        cell.bind(name: "Application", token: token(AnyHashable("app-fixture")))
        cell.layout()
        XCTAssertNil(cell.folderMotionSourceFrame)
        cell.bindFolder(title: "Wrong identity", memberCount: 0,
                        token: token(AnyHashable("non-folder-fixture")))
        cell.layout()
        XCTAssertNil(cell.folderMotionSourceFrame)
        cell.bindFolder(title: "Missing identity", memberCount: 0, token: token(nil))
        cell.layout()
        XCTAssertNil(cell.folderMotionSourceFrame)
        cell.bindFolder(title: "New folder", memberCount: 1, token: token(AnyHashable(FolderID())))
        cell.layout()
        XCTAssertNotNil(cell.folderMotionSourceFrame)
    }

    func testSourceRejectsHiddenSymbolCellAndAncestor() throws {
        let cell = makeCell()
        let symbol = try symbol(in: cell)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        host.addSubview(cell)
        XCTAssertNotNil(cell.folderMotionSourceFrame)
        symbol.isHidden = true
        XCTAssertNil(cell.folderMotionSourceFrame)
        symbol.isHidden = false
        cell.isHidden = true
        XCTAssertNil(cell.folderMotionSourceFrame)
        cell.isHidden = false
        host.isHidden = true
        XCTAssertNil(cell.folderMotionSourceFrame)
        host.isHidden = false
        symbol.alphaValue = 0
        XCTAssertNil(cell.folderMotionSourceFrame)
        symbol.alphaValue = 1
        cell.alphaValue = 0
        XCTAssertNil(cell.folderMotionSourceFrame)
        cell.alphaValue = 1
        XCTAssertNotNil(cell.folderMotionSourceFrame)
    }

    func testSourceRejectsEmptyOutOfBoundsMissingAndDetachedGlyph() throws {
        let cell = makeCell()
        let symbol = try symbol(in: cell)
        let original = symbol.frame
        symbol.frame = .zero
        XCTAssertNil(cell.folderMotionSourceFrame)
        symbol.frame = original.offsetBy(dx: cell.bounds.width, dy: 0)
        XCTAssertNil(cell.folderMotionSourceFrame)
        symbol.frame = original
        let image = symbol.image
        symbol.image = nil
        XCTAssertNil(cell.folderMotionSourceFrame)
        symbol.image = image
        XCTAssertNotNil(cell.folderMotionSourceFrame)
        symbol.removeFromSuperview()
        XCTAssertNil(cell.folderMotionSourceFrame)
    }

    func testTinyCellWithoutFittedGlyphHasNoSource() {
        let cell = makeCell()
        cell.frame.size.height = 10
        cell.layout()
        XCTAssertNil(cell.folderMotionSourceFrame)
    }
}
