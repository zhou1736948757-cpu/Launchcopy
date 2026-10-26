import CoreGraphics
import XCTest
import AppGridUI

final class CompactGridGeometryTests: XCTestCase {
    private let tolerance: CGFloat = 0.000001

    func testCompactOrdinaryPageKeepsAllThirtyFiveFramesInsideAvailableArea() throws {
        for height in [CGFloat(400), 600, 735] {
            let geometry = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 1000, height: height),
                itemCount: 35, mode: .ordinary)

            XCTAssertEqual(geometry.columns, 5)
            XCTAssertEqual(geometry.rowCount, 7)
            XCTAssertEqual(geometry.cellHeight, (height - 120) / 7, accuracy: tolerance)
            XCTAssertEqual(geometry.spacing, 0, accuracy: tolerance)
            let frames = try assertFramesFit(geometry, itemCount: 35)
            XCTAssertEqual(frames[0].maxY, height - 96, accuracy: tolerance)
            XCTAssertEqual(frames[34].minY, 24, accuracy: tolerance)
            for index in 1..<frames.count {
                if index % 5 == 0 {
                    XCTAssertLessThan(frames[index].minY, frames[index - 1].minY)
                    XCTAssertLessThanOrEqual(frames[index].maxY, frames[index - 1].minY + tolerance)
                } else {
                    XCTAssertEqual(frames[index].minY, frames[index - 1].minY, accuracy: tolerance)
                    XCTAssertGreaterThan(frames[index].minX, frames[index - 1].minX)
                }
            }
        }
    }

    func testSufficientHeightPreservesDefaultCellsSpacingAndVerticalCentering() throws {
        let tall = AppGridGeometry(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            itemCount: 35, mode: .ordinary)
        XCTAssertEqual(tall.cellHeight, 88)
        XCTAssertEqual(tall.spacing, 16)
        let frames = try assertFramesFit(tall, itemCount: 35)
        XCTAssertEqual(frames[0].minX, 24, accuracy: tolerance)
        XCTAssertEqual(frames[0].minY, 732, accuracy: tolerance)
        XCTAssertEqual(frames[0].width, 177.6, accuracy: tolerance)
        XCTAssertEqual(frames[34].minY, 108, accuracy: tolerance)
        XCTAssertEqual((frames[0].maxY + frames[34].minY) / 2, tall.area.midY, accuracy: tolerance)

        for height in [CGFloat(736), 780] {
            let reducedSpacing = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 1000, height: height),
                itemCount: 35, mode: .ordinary)
            XCTAssertEqual(reducedSpacing.cellHeight, 88)
            XCTAssertEqual(reducedSpacing.spacing, (height - 736) / 6, accuracy: tolerance)
            _ = try assertFramesFit(reducedSpacing, itemCount: 35)
        }
    }

    func testPartialOrdinaryPagesKeepSevenRowsAndCenterTheirLastRow() throws {
        for itemCount in [1, 6, 33] {
            let geometry = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 1000, height: 600),
                itemCount: itemCount, mode: .ordinary)
            XCTAssertEqual(geometry.rowCount, 7)
            let frames = try assertFramesFit(geometry, itemCount: itemCount)
            XCTAssertEqual(frames[0].maxY, geometry.area.maxY, accuracy: tolerance)
            let lastRowStart = ((itemCount - 1) / 5) * 5
            XCTAssertEqual((frames[lastRowStart].minX + frames[itemCount - 1].maxX) / 2,
                           geometry.area.midX, accuracy: tolerance)
        }
    }

    func testCompactSingleSearchRowFitsAndCentersFullOrPartialResults() throws {
        for itemCount in [1, 4, 5] {
            let geometry = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 1000, height: 168),
                itemCount: itemCount, mode: .search)
            XCTAssertEqual(geometry.rowCount, 1)
            XCTAssertEqual(geometry.cellHeight, 48)
            XCTAssertEqual(geometry.spacing, 0)
            let frames = try assertFramesFit(geometry, itemCount: itemCount)
            XCTAssertEqual(frames[0].midY, geometry.area.midY, accuracy: tolerance)
            XCTAssertEqual((frames[0].minX + frames[itemCount - 1].maxX) / 2,
                           geometry.area.midX, accuracy: tolerance)
        }

        let sufficientHeight = AppGridGeometry(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 300),
            itemCount: 1, mode: .search)
        XCTAssertEqual(sufficientHeight.cellHeight, 88)
        XCTAssertEqual(sufficientHeight.spacing, 0)
        let frame = try XCTUnwrap(sufficientHeight.frame(for: 0, itemCount: 1))
        XCTAssertEqual(frame.midY, sufficientHeight.area.midY, accuracy: tolerance)
    }

    func testCompactMultipleSearchRowsUseExistingCountAndCenterPartialLastRow() throws {
        for (itemCount, expectedRows) in [(6, 2), (11, 3), (34, 7)] {
            let geometry = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 1000, height: 260),
                itemCount: itemCount, mode: .search)
            XCTAssertEqual(geometry.rowCount, expectedRows)
            XCTAssertEqual(geometry.cellHeight, 140 / CGFloat(expectedRows), accuracy: tolerance)
            XCTAssertEqual(geometry.spacing, 0, accuracy: tolerance)
            let frames = try assertFramesFit(geometry, itemCount: itemCount)
            let lastRowStart = (expectedRows - 1) * 5
            XCTAssertEqual((frames[lastRowStart].minX + frames[itemCount - 1].maxX) / 2,
                           geometry.area.midX, accuracy: tolerance)
            XCTAssertEqual(frames[0].maxY, geometry.area.maxY, accuracy: tolerance)
            XCTAssertEqual(frames[itemCount - 1].minY, geometry.area.minY, accuracy: tolerance)
        }
    }

    func testNonzeroOriginAndCustomInsetsTranslateCompactFramesWithoutOverflow() throws {
        for mode in [AppGridLayoutMode.ordinary, .search] {
            let local = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 800, height: 400),
                itemCount: 33, mode: mode, sideInset: 30, topInset: 110, bottomInset: 35)
            let translated = AppGridGeometry(
                bounds: CGRect(x: -125, y: 210, width: 800, height: 400),
                itemCount: 33, mode: mode, sideInset: 30, topInset: 110, bottomInset: 35)
            XCTAssertEqual(translated.area, CGRect(x: -95, y: 245, width: 740, height: 255))
            let localFrames = try assertFramesFit(local, itemCount: 33)
            let translatedFrames = try assertFramesFit(translated, itemCount: 33)
            for (localFrame, translatedFrame) in zip(localFrames, translatedFrames) {
                XCTAssertEqual(translatedFrame.minX, localFrame.minX - 125, accuracy: tolerance)
                XCTAssertEqual(translatedFrame.minY, localFrame.minY + 210, accuracy: tolerance)
                XCTAssertEqual(translatedFrame.size, localFrame.size)
            }
        }
    }

    func testEmptyHeightBudgetProducesZeroCellHeightAndNoFrames() {
        for mode in [AppGridLayoutMode.ordinary, .search] {
            for height in [CGFloat(0), 100, 120] {
                let geometry = AppGridGeometry(
                    bounds: CGRect(x: 40, y: 60, width: 1000, height: height),
                    itemCount: 35, mode: mode)
                XCTAssertEqual(geometry.area.height, 0)
                XCTAssertEqual(geometry.cellHeight, 0)
                XCTAssertEqual(geometry.spacing, 0)
                XCTAssertNil(geometry.frame(for: 0, itemCount: 35))
                XCTAssertNil(geometry.frame(for: 34, itemCount: 35))
            }
            let emptyResults = AppGridGeometry(
                bounds: CGRect(x: 0, y: 0, width: 1000, height: 600),
                itemCount: 0, mode: mode)
            XCTAssertEqual(emptyResults.rowCount, mode == .ordinary ? 7 : 1)
            XCTAssertNil(emptyResults.frame(for: 0, itemCount: 0))
        }
    }

    private func assertFramesFit(_ geometry: AppGridGeometry, itemCount: Int,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> [CGRect] {
        try (0..<itemCount).map { index in
            let frame = try XCTUnwrap(geometry.frame(for: index, itemCount: itemCount), file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minX, geometry.area.minX - tolerance, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minY, geometry.area.minY - tolerance, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, geometry.area.maxX + tolerance, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, geometry.area.maxY + tolerance, file: file, line: line)
            return frame
        }
    }
}
