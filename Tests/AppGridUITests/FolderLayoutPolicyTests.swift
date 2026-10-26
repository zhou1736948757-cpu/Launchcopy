import AppKit
import XCTest
@testable import AppGridUI

/// Pure value contracts; these tests do not create views, windows or processes.
@MainActor
final class FolderLayoutPolicyTests: XCTestCase {
    func testRegularViewportHasFiveByThreeFullCapacityAndExistingChrome() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        XCTAssertEqual(layout.columns, 5)
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.capacity, 15)
        XCTAssertEqual(layout.panelFrame, CGRect(x: 164, y: 122.5, width: 672, height: 455))
        XCTAssertEqual(layout.titleFrame, CGRect(x: 24, y: 403, width: 624, height: 40))
        XCTAssertEqual(layout.gridFrame, CGRect(x: 24, y: 68, width: 624, height: 323))
        XCTAssertEqual(layout.pageIndicatorFrame, CGRect(x: 0, y: 8, width: 672, height: 20))
        XCTAssertEqual(layout.previousButtonFrame, CGRect(x: 24, y: 8, width: 40, height: 24))
        XCTAssertEqual(layout.nextButtonFrame, CGRect(x: 608, y: 8, width: 40, height: 24))
        assertUseful(layout, appearance: .default, in: bounds)
    }

    func testCompactViewportPreservesDefaultAndMaximumRequestedIcons() {
        let bounds = CGRect(x: 0, y: 0, width: 700, height: 500)
        let standard = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        let maximumAppearance = GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16)
        let maximum = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: maximumAppearance)
        XCTAssertEqual(standard.columns, 4)
        XCTAssertEqual(standard.rows, 3)
        XCTAssertEqual(standard.capacity, 12)
        XCTAssertEqual(maximum.columns, 4)
        XCTAssertEqual(maximum.rows, 2)
        XCTAssertEqual(maximum.capacity, 8)
        assertUseful(standard, appearance: .default, in: bounds)
        assertUseful(maximum, appearance: maximumAppearance, in: bounds)
    }

    func testFiveHundredFortyPointWidthUsesThreeColumns() {
        let bounds = CGRect(x: 0, y: 0, width: 540, height: 700)
        let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.capacity, 9)
        assertUseful(layout, appearance: .default, in: bounds)
    }

    func testEveryColumnThresholdImmediatelyBelowAtAndAboveMinimum() {
        for columns in 1...5 {
            let threshold = 48 + 48 + CGFloat(columns) * 112 + CGFloat(columns - 1) * 16
            for delta in [CGFloat(-0.01), 0, 0.01] {
                let bounds = CGRect(x: 0, y: 0, width: threshold + delta, height: 700)
                let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
                if columns == 1 && delta < 0 {
                    assertUnavailable(layout)
                } else {
                    XCTAssertEqual(layout.columns, delta < 0 ? columns - 1 : columns)
                    assertUseful(layout, appearance: .default, in: bounds)
                }
            }
        }
    }

    func testEveryRowThresholdAndInsufficientSpaceRecoveryForAllAppearances() {
        for side in [32, 48, 64] {
            for fontSize in 9...16 {
                let appearance = GridItemAppearance(preferredIconSide: side, appLabelFontSize: fontSize)
                let font = NSFont.systemFont(ofSize: CGFloat(fontSize))
                let lineHeight = fontSize == 11 ? CGFloat(14) : ceil(font.ascender - font.descender + font.leading) + 1
                let cellHeight = max(96, CGFloat(side) + lineHeight + 22)
                for rows in 1...3 {
                    let threshold = 48 + 132 + CGFloat(rows) * cellHeight + CGFloat(rows - 1) * 16
                    for delta in [CGFloat(-0.01), 0, 0.01] {
                        let bounds = CGRect(x: 0, y: 0, width: 1000, height: threshold + delta)
                        let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: appearance)
                        if rows == 1 && delta < 0 {
                            assertUnavailable(layout)
                        } else {
                            XCTAssertEqual(layout.rows, delta < 0 ? rows - 1 : rows)
                            assertUseful(layout, appearance: appearance, in: bounds)
                        }
                    }
                }
            }
        }
    }

    func testLargeViewportIsCappedAndSoftTargetsExpandOnlyAsNeeded() {
        let largeBounds = CGRect(x: 0, y: 0, width: 10000, height: 3000)
        let large = FolderLayoutPolicy.resolve(usableBounds: largeBounds, appearance: .default)
        XCTAssertEqual(large.panelFrame.size, CGSize(width: 900, height: 620))
        XCTAssertEqual(large.capacity, 15)
        assertUseful(large, appearance: .default, in: largeBounds)
        let bounds = CGRect(x: 0, y: 0, width: 1400, height: 900)
        let soft = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        XCTAssertEqual(soft.panelFrame.size, CGSize(width: 840, height: 585))
        assertUseful(soft, appearance: .default, in: bounds)
    }

    func testSafeOffsetOnlyTranslatesPanelAndLogicalPointsIgnoreBackingScale() {
        let bounds = CGRect(x: 0, y: 0, width: 700, height: 500)
        let original = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        for scale in [CGFloat(1), 2] {
            // A caller converts display pixels into the same safe logical points.
            let pixelBounds = CGRect(x: 72 * scale, y: 110 * scale,
                                     width: 700 * scale, height: 500 * scale)
            let logical = CGRect(x: pixelBounds.origin.x / scale, y: pixelBounds.origin.y / scale,
                                 width: pixelBounds.width / scale, height: pixelBounds.height / scale)
            let offset = FolderLayoutPolicy.resolve(usableBounds: logical, appearance: .default)
            XCTAssertEqual(offset.panelFrame, original.panelFrame.offsetBy(dx: 72, dy: 110))
            XCTAssertEqual(offset.cellFrames, original.cellFrames)
            XCTAssertEqual(offset.titleFrame, original.titleFrame)
            XCTAssertEqual(offset.gridFrame, original.gridFrame)
            XCTAssertEqual(offset.pageIndicatorFrame, original.pageIndicatorFrame)
            XCTAssertEqual(offset.previousButtonFrame, original.previousButtonFrame)
            XCTAssertEqual(offset.nextButtonFrame, original.nextButtonFrame)
            assertUseful(offset, appearance: .default, in: logical)
        }
    }

    func testTinyAndNarrowBoundsHaveNoActionableSlotsAndBoundedChrome() {
        for width in [CGFloat(0), 1, 16, 47, 48, 120, 207.99] {
            for height in [CGFloat(0), 1, 24, 48, 100, 275.99, 700] {
                let bounds = CGRect(x: -30, y: 70, width: width, height: height)
                let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
                assertUnavailable(layout)
                assertChrome(layout, in: bounds)
                let local = CGRect(origin: .zero, size: layout.panelFrame.size)
                for frame in [layout.insufficientSpaceMessageFrame, layout.closeButtonFrame] {
                    assertBounded(frame, in: local)
                }
                // CoreGraphics can report an intersection for degenerate zero-area
                // rectangles. Only positive-area rendered regions can occlude content.
                let visibleRegions = [layout.titleFrame, layout.insufficientSpaceMessageFrame,
                                      layout.closeButtonFrame].filter { !$0.isEmpty }
                for (index, frame) in visibleRegions.enumerated() {
                    for other in visibleRegions.dropFirst(index + 1) {
                        XCTAssertFalse(frame.intersects(other))
                    }
                }
            }
        }
    }

    func testNonfiniteNegativeAndOverflowingInputsDoNotEscapeFiniteGeometry() {
        let malformed = [CGRect.null, CGRect.infinite,
            CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: 700, height: 500),
            CGRect(x: 12, y: 34, width: CGFloat.nan, height: CGFloat.infinity),
            CGRect(x: 12, y: 34, width: -700, height: -500),
            CGRect(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude,
                   width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)]
        for bounds in malformed {
            let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
            for frame in [layout.panelFrame, layout.titleFrame, layout.gridFrame,
                          layout.pageIndicatorFrame, layout.previousButtonFrame,
                          layout.nextButtonFrame, layout.insufficientSpaceMessageFrame, layout.closeButtonFrame] + layout.cellFrames {
                assertFinite(frame)
            }
            XCTAssertEqual(layout.capacity, max(layout.columns * layout.rows, 1))
            XCTAssertEqual(layout.cellFrames.count, layout.canPresentMembers ? layout.capacity : 0)
        }
        let repaired = FolderLayoutPolicy.resolve(usableBounds: CGRect(x: 0, y: 0, width: 700, height: 500),
                                                  appearance: .default)
        XCTAssertEqual(FolderLayoutPolicy.resolve(
            usableBounds: CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: 700, height: 500), appearance: .default), repaired)
    }

    func testInvalidAppearanceMatchesExistingDefaultFallback() {
        let bounds = CGRect(x: 10, y: -20, width: 700, height: 500)
        let expected = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        for appearance in [GridItemAppearance(preferredIconSide: Int.max, appLabelFontSize: Int.min),
                           GridItemAppearance(preferredIconSide: 31),
                           GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 17)] {
            XCTAssertEqual(FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: appearance), expected)
        }
    }

    func testFullCapacityIsDeterministicAcrossPartialPagesAndResizeRoundTrip() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let expected = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
        for memberCount in [0, 1, 9, 15, 16, 35, 36, 70, 101] {
            let layout = FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default)
            XCTAssertEqual(layout, expected)
            XCTAssertEqual(layout.cellFrames.count, 15)
            // A partial page consumes the leading slots without moving them.
            XCTAssertEqual(Array(layout.cellFrames.prefix(min(memberCount, layout.capacity))),
                           Array(expected.cellFrames.prefix(min(memberCount, expected.capacity))))
        }
        _ = FolderLayoutPolicy.resolve(usableBounds: CGRect(x: 0, y: 0, width: 1, height: 1), appearance: .default)
        _ = FolderLayoutPolicy.resolve(usableBounds: CGRect(x: 0, y: 0, width: 540, height: 500), appearance: .default)
        XCTAssertEqual(FolderLayoutPolicy.resolve(usableBounds: bounds, appearance: .default), expected)
    }

    private func assertUnavailable(_ layout: FolderLayoutSnapshot,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(layout.canPresentMembers, file: file, line: line)
        XCTAssertEqual(layout.columns, 1, file: file, line: line)
        XCTAssertEqual(layout.rows, 1, file: file, line: line)
        XCTAssertEqual(layout.capacity, 1, file: file, line: line)
        XCTAssertTrue(layout.cellFrames.isEmpty, file: file, line: line)
    }

    private func assertUseful(_ layout: FolderLayoutSnapshot, appearance: GridItemAppearance,
                              in bounds: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(layout.canPresentMembers, file: file, line: line)
        XCTAssertEqual(layout.cellFrames.count, layout.capacity, file: file, line: line)
        assertChrome(layout, in: bounds, file: file, line: line)
        XCTAssertGreaterThanOrEqual(layout.panelFrame.minX, bounds.minX + 24 - 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(layout.panelFrame.maxX, bounds.maxX - 24 + 0.000001, file: file, line: line)
        XCTAssertGreaterThanOrEqual(layout.panelFrame.minY, bounds.minY + 24 - 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(layout.panelFrame.maxY, bounds.maxY - 24 + 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(layout.gridFrame.maxY + 12, layout.titleFrame.minY + 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(layout.previousButtonFrame.maxY, layout.gridFrame.minY, file: file, line: line)
        for (index, frame) in layout.cellFrames.enumerated() {
            assertBounded(frame, in: layout.gridFrame, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.width, 112 - 0.000001, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 96 - 0.000001, file: file, line: line)
            XCTAssertEqual(frame.size, layout.cellFrames[0].size, file: file, line: line)
            for labels in [false, true] {
                let local = CGRect(origin: .zero, size: frame.size)
                let content = GridItemContentGeometry(bounds: local, appearance: appearance,
                                                      showsLabels: labels, isFolderCell: false)
                assertBounded(content.iconFrame, in: local, file: file, line: line)
                assertBounded(content.nameFrame, in: local, file: file, line: line)
                XCTAssertEqual(content.iconFrame.width, CGFloat(appearance.preferredIconSide), accuracy: 0.000001,
                               file: file, line: line)
                XCTAssertEqual(content.iconFrame.height, CGFloat(appearance.preferredIconSide), accuracy: 0.000001,
                               file: file, line: line)
                if labels {
                    XCTAssertGreaterThanOrEqual(content.iconFrame.minY, content.nameFrame.maxY + 2 - 0.000001,
                                                file: file, line: line)
                }
            }
            if index % layout.columns == 0 {
                XCTAssertEqual(frame.minX, layout.gridFrame.minX, accuracy: 0.000001, file: file, line: line)
            } else {
                XCTAssertEqual(frame.minX - layout.cellFrames[index - 1].maxX, 16, accuracy: 0.000001,
                               file: file, line: line)
            }
            if index >= layout.columns {
                XCTAssertEqual(layout.cellFrames[index - layout.columns].minY - frame.maxY, 16,
                               accuracy: 0.000001, file: file, line: line)
            } else {
                XCTAssertEqual(frame.maxY, layout.gridFrame.maxY, accuracy: 0.000001, file: file, line: line)
            }
        }
    }

    private func assertChrome(_ layout: FolderLayoutSnapshot, in bounds: CGRect,
                              file: StaticString = #filePath, line: UInt = #line) {
        assertBounded(layout.panelFrame, in: bounds, file: file, line: line)
        let local = CGRect(origin: .zero, size: layout.panelFrame.size)
        for frame in [layout.titleFrame, layout.gridFrame, layout.pageIndicatorFrame,
                      layout.previousButtonFrame, layout.nextButtonFrame] {
            assertBounded(frame, in: local, file: file, line: line)
        }
    }

    private func assertFinite(_ frame: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for value in [frame.origin.x, frame.origin.y, frame.width, frame.height, frame.maxX, frame.maxY] {
            XCTAssertTrue(value.isFinite, file: file, line: line)
        }
        XCTAssertGreaterThanOrEqual(frame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, 0, file: file, line: line)
    }

    private func assertBounded(_ frame: CGRect, in bounds: CGRect,
                               file: StaticString = #filePath, line: UInt = #line) {
        assertFinite(frame, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.000001, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, bounds.minY - 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY + 0.000001, file: file, line: line)
    }
}
