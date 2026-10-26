import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class CellBackdropTransparencyTests: XCTestCase {
    func testInitialPaddingShowsBackdrop() throws {
        let cell = makeCell()
        try assertTransparentPadding(cell, stage: "initial")
    }

    func testFocusThenUnfocusRestoresTransparentPadding() throws {
        let cell = makeCell()
        cell.bind(name: "Synthetic App", token: token(identity: "app"))
        cell.setFocused(true)
        XCTAssertTrue(cell.isFocused)
        XCTAssertEqual(cell.layer?.borderWidth, 3)
        XCTAssertEqual(cell.layer?.borderColor, NSColor.controlAccentColor.cgColor)
        XCTAssertEqual(cell.layer?.backgroundColor, NSColor.selectedControlColor.cgColor)
        XCTAssertEqual(cell.accessibilityLabel(), "Synthetic App")
        cell.setFocused(false)
        XCTAssertFalse(cell.isFocused)
        try assertTransparentPadding(cell, stage: "unfocused")
    }

    func testClearAndAppFolderRebindKeepTransparentPaddingAndIdentity() async throws {
        let cell = makeCell()
        cell.bind(name: "First App", token: token(identity: "first"))
        cell.setFocused(true)
        cell.clearContent()
        XCTAssertNil(cell.bindingToken)
        XCTAssertFalse(cell.isFocused)
        try assertTransparentPadding(cell, stage: "cleared")

        let folderID = FolderID()
        let folderToken = token(identity: AnyHashable(folderID))
        cell.bindFolder(title: "Synthetic Folder", memberCount: 2, token: folderToken)
        XCTAssertEqual(cell.bindingToken, folderToken)
        XCTAssertTrue(cell.isFolderCell)
        XCTAssertTrue(cell.isFolderSymbolVisible)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.memberCountText, "2 items")
        XCTAssertEqual(cell.accessibilityRole(), .button)
        XCTAssertEqual(cell.accessibilityLabel(), "Synthetic Folder")
        try assertTransparentPadding(cell, stage: "folder")
        cell.setFocused(true)
        XCTAssertTrue(cell.isFocused)
        XCTAssertEqual(cell.layer?.backgroundColor, NSColor.selectedControlColor.cgColor)
        cell.setFocused(false)
        try assertTransparentPadding(cell, stage: "folder-unfocused")
        cell.setFocused(true)

        let appToken = token(identity: "second")
        cell.bind(name: "Second App", token: appToken)
        XCTAssertEqual(cell.bindingToken, appToken)
        XCTAssertFalse(cell.isFocused)
        XCTAssertFalse(cell.isFolderCell)
        XCTAssertFalse(cell.isFolderSymbolVisible)
        XCTAssertEqual(cell.memberCountText, "")
        try assertTransparentPadding(cell, stage: "rebound-app")
    }

    private func makeCell() -> AppGridCellView {
        AppGridCellView(frame: NSRect(x: 0, y: 0, width: 120, height: 96))
    }

    private func token(identity: AnyHashable) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 1,
                         pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: 1,
                         iconKey: nil, surfaceGeneration: 1)
    }

    private func assertTransparentPadding(
        _ cell: AppGridCellView, stage: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let root = NSView(frame: cell.frame)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).cgColor
        root.addSubview(cell)
        root.layoutSubtreeIfNeeded()
        cell.layout()
        defer { cell.removeFromSuperview() }
        let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
        root.cacheDisplay(in: root.bounds, to: bitmap)
        // Left-middle padding: away from the 48pt icon, text, rounded corners and focus ring.
        let x = Int(CGFloat(bitmap.pixelsWide) * 10 / root.bounds.width)
        let y = bitmap.pixelsHigh / 2
        let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
        if let directory = ProcessInfo.processInfo.environment["PAGING_CELL_ARTIFACT_DIR"],
           let label = ProcessInfo.processInfo.environment["PAGING_CELL_ARTIFACT_LABEL"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("\(label)-\(stage).png")
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        }
        print("Synthetic cell \(stage): padding RGB=\(color.redComponent),\(color.greenComponent),\(color.blueComponent)")
        XCTAssertNil(cell.layer?.backgroundColor, file: file, line: line)
        XCTAssertGreaterThan(color.redComponent, 0.9, file: file, line: line)
        XCTAssertGreaterThan(color.redComponent - color.greenComponent, 0.7, file: file, line: line)
        XCTAssertLessThan(color.blueComponent, 0.1, file: file, line: line)
        XCTAssertGreaterThan(color.alphaComponent, 0.99, file: file, line: line)
    }
}
