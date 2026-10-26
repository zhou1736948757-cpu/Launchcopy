import AppCatalogCore
import AppIconPipeline
import AppKit
import XCTest
@testable import AppGridUI

@MainActor
final class FolderViewportFitTests: XCTestCase {
    private func fixture(count: Int, size: NSSize) -> (FolderOverlayView, IconPipeline) {
        let pipeline = IconPipeline(loader: EmptyLoader(), limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        overlay.frame = NSRect(origin: .zero, size: size)
        let ids = (0..<count).map { makeAppID("fixture.viewport.\($0)") }
        overlay.configure(entry: .init(id: FolderID(), title: "Viewport", members: ids),
                          innerPage: 0, reduceMotion: true) { _ in "Fixture" }
        overlay.layoutSubtreeIfNeeded()
        return (overlay, pipeline)
    }

    private func area(_ overlay: FolderOverlayView) -> NSRect {
        let panel = overlay.panelFrame
        return NSRect(x: 24, y: 56, width: panel.width - 48, height: panel.height - 120)
    }
    private func assertFits(_ overlay: FolderOverlayView, count: Int,
                            file: StaticString = #filePath, line: UInt = #line) throws {
        let grid = area(overlay)
        for index in 0..<count {
            let frame = try XCTUnwrap(overlay.memberCell(at: index), file: file, line: line).frame
            XCTAssertGreaterThanOrEqual(frame.minX, grid.minX - 0.001, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minY, grid.minY - 0.001, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, grid.maxX + 0.001, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, grid.maxY + 0.001, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.width, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 0, file: file, line: line)
            if index >= 5 {
                let previousRow = try XCTUnwrap(overlay.memberCell(at: index - 5)).frame
                XCTAssertLessThanOrEqual(frame.maxY, previousRow.minY + 0.001, file: file, line: line)
            }
        }
    }
    func testActualThirtyFiveMembersStayAboveFooterInShortPanel() throws {
        let (overlay, pipeline) = fixture(count: 35, size: .init(width: 1000, height: 600))
        defer { overlay.teardown(); pipeline.shutdown() }
        XCTAssertEqual(overlay.membersPerPage, 35)
        try assertFits(overlay, count: 35)
    }
    func testAlreadyFittingFullAndSmallFoldersKeepTheirExactLegacyFrames() throws {
        for count in [1, 5, 15, 25, 35] {
            let (overlay, pipeline) = fixture(count: count, size: .init(width: 1470, height: 956))
            defer { overlay.teardown(); pipeline.shutdown() }
            let grid = area(overlay)
            let rows = (count + 4) / 5
            let pitch = min(CGFloat(104), grid.height / CGFloat(rows))
            let height = max(pitch - 16, 56)
            let width = (grid.width - 64) / 5
            for index in 0..<count {
                let expected = CGRect(x: grid.minX + CGFloat(index % 5) * (width + 16),
                    y: grid.maxY - CGFloat(index / 5 + 1) * (height + 16), width: width, height: height)
                XCTAssertEqual(overlay.memberCell(at: index)?.frame, expected)
            }
        }
    }
    func testCompactAndPartialPagesKeepAllBoundedSlotsAndOrdering() throws {
        for height in [CGFloat(250), 350, 450, 600, 700] {
            for count in [1, 6, 31, 35] {
                let (overlay, pipeline) = fixture(count: count, size: .init(width: 500, height: height))
                defer { overlay.teardown(); pipeline.shutdown() }
                try assertFits(overlay, count: count)
            }
        }
    }
    func testRelayoutChangesNoBindingsPageCountOrIconRequests() throws {
        let (overlay, pipeline) = fixture(count: 70, size: .init(width: 1000, height: 900))
        defer { overlay.teardown(); pipeline.shutdown() }
        let tokens = (0..<35).map { overlay.memberCell(at: $0)?.bindingToken }
        let generation = overlay.surfaceGeneration
        let requests = pipeline.stats.requests
        overlay.frame.size.height = 500; overlay.layoutSubtreeIfNeeded()
        try assertFits(overlay, count: 35)
        XCTAssertEqual((0..<35).map { overlay.memberCell(at: $0)?.bindingToken }, tokens)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats.requests, requests)
        XCTAssertEqual(overlay.membersPerPage, 35)
    }
}

private struct EmptyLoader: IconLoading {
    func load(key: IconKey) async throws -> NSImage { NSImage(size: .init(width: 48, height: 48)) }
}
