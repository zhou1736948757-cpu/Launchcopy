import AppKit
@testable import AppGridUI
import XCTest

/// Value and geometry contracts only; no windows, preferences or external assets.
@MainActor
final class GridItemAppearanceTests: XCTestCase {
    func testDefaultsAndIndependentIntegerRanges() {
        XCTAssertEqual(GridItemAppearance(), .default)
        XCTAssertEqual(GridItemAppearance.default.preferredIconSide, 48)
        XCTAssertEqual(GridItemAppearance.default.appLabelFontSize, 11)
        for side in 32...96 {
            for size in 9...16 {
                XCTAssertTrue(GridItemAppearance(preferredIconSide: side, appLabelFontSize: size).isValid)
            }
        }
        for side in [Int.min, -1, 0, 31, 97, Int.max] {
            XCTAssertFalse(GridItemAppearance(preferredIconSide: side).isValid)
        }
        for size in [Int.min, -1, 0, 8, 17, Int.max] {
            XCTAssertFalse(GridItemAppearance(appLabelFontSize: size).isValid)
        }
    }

    func testCodableRoundTripAndValidationRemainSeparate() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for value in [.default, GridItemAppearance(preferredIconSide: 32, appLabelFontSize: 9),
                      GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16),
                      GridItemAppearance(preferredIconSide: 80, appLabelFontSize: 12),
                      GridItemAppearance(preferredIconSide: 96, appLabelFontSize: 16),
                      GridItemAppearance(preferredIconSide: 65, appLabelFontSize: 8)] {
            let decoded = try decoder.decode(GridItemAppearance.self, from: encoder.encode(value))
            XCTAssertEqual(decoded, value)
            XCTAssertEqual(decoded.isValid, value.isValid)
        }
        let encoded = try encoder.encode(GridItemAppearance.default)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Int])
        XCTAssertEqual(payload, ["preferredIconSide": 48, "appLabelFontSize": 11])
        for json in ["{}", "{\"preferredIconSide\":48}",
                     "{\"preferredIconSide\":48.5,\"appLabelFontSize\":11}",
                     "{\"preferredIconSide\":48,\"appLabelFontSize\":\"11\"}",
                     "{\"preferredIconSide\":null,\"appLabelFontSize\":11}"] {
            XCTAssertThrowsError(try decoder.decode(GridItemAppearance.self, from: Data(json.utf8)))
        }
    }

    func testFittingDefaultGeometryIsExactForAppAndFolder() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 88)
        for folder in [false, true] {
            for visible in [false, true] {
                let geometry = GridItemContentGeometry(bounds: bounds, appearance: .default,
                                                       showsLabels: visible, isFolderCell: folder)
                XCTAssertEqual(geometry.iconFrame, CGRect(x: 26, y: 28, width: 48, height: 48))
                XCTAssertEqual(geometry.nameFrame, CGRect(x: 2, y: 0, width: 96, height: 14))
                XCTAssertEqual(geometry.countFrame, CGRect(x: 2, y: 14, width: 96, height: 12))
            }
        }
    }

    func testCaptionUsesReadableSystemMetricsAndCountRemainsFixed() {
        for size in 9...16 {
            let appearance = GridItemAppearance(appLabelFontSize: size)
            let font = NSFont.systemFont(ofSize: CGFloat(size))
            let geometry = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 100, height: 150),
                                                   appearance: appearance, showsLabels: true, isFolderCell: true)
            let expected = size == 11 ? CGFloat(14) : ceil(font.ascender - font.descender + font.leading) + 1
            XCTAssertEqual(geometry.nameFrame.height, expected)
            XCTAssertEqual(geometry.countFrame.minY, geometry.nameFrame.maxY)
            XCTAssertEqual(geometry.countFrame.height, 12)
        }
    }

    func testHeightFitReservesTwoPointGapAndTwelvePointTopInset() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 88)
        let appearance = GridItemAppearance(preferredIconSide: 64)
        let app = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                         showsLabels: true, isFolderCell: false)
        let folder = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                            showsLabels: true, isFolderCell: true)
        XCTAssertEqual(app.iconFrame, CGRect(x: 20, y: 16, width: 60, height: 60))
        XCTAssertEqual(folder.iconFrame, CGRect(x: 26, y: 28, width: 48, height: 48))
        XCTAssertEqual(app.iconFrame.minY - app.nameFrame.maxY, 2)
        XCTAssertEqual(folder.iconFrame.minY - folder.countFrame.maxY, 2)
        XCTAssertEqual(bounds.maxY - folder.iconFrame.maxY, 12)
        XCTAssertEqual(bounds.maxY - app.iconFrame.maxY, 12)
    }

    func testNarrowCellsFitHorizontallyWithoutChangingTopAnchor() {
        let geometry = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 20, height: 88),
                                               appearance: GridItemAppearance(preferredIconSide: 64),
                                               showsLabels: true, isFolderCell: true)
        XCTAssertEqual(geometry.iconFrame, CGRect(x: 0, y: 56, width: 20, height: 20))
        XCTAssertEqual(geometry.nameFrame.width, 16)
    }

    func testHiddenCaptionsFreeSpaceAndVisiblePolicyRestoresDeterministicFit() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 56)
        let appearance = GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16)
        let visible = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                             showsLabels: true, isFolderCell: true)
        let hidden = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                            showsLabels: false, isFolderCell: true)
        XCTAssertEqual(hidden.iconFrame.width, 44)
        XCTAssertGreaterThan(hidden.iconFrame.width, visible.iconFrame.width)
        XCTAssertEqual(hidden.nameFrame, visible.nameFrame)
        XCTAssertEqual(hidden.countFrame, visible.countFrame)
        XCTAssertEqual(visible, GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                                       showsLabels: true, isFolderCell: true))
    }

    func testPreferenceBoundsAcrossTinyCompressedAndOrdinaryCells() {
        for side in [32, 48, 64] {
            for size in 9...16 {
                for width in [CGFloat(0), 1, 3, 20, 48, 100] {
                    for height in [CGFloat(0), 1, 10, 14, 15, 25, 26, 40, 56, 65.14, 88, 120] {
                        let bounds = CGRect(x: 5, y: -7, width: width, height: height)
                        for visible in [false, true] {
                            for folder in [false, true] {
                                let geometry = GridItemContentGeometry(
                                    bounds: bounds,
                                    appearance: GridItemAppearance(preferredIconSide: side, appLabelFontSize: size),
                                    showsLabels: visible, isFolderCell: folder)
                                for frame in [geometry.iconFrame, geometry.nameFrame, geometry.countFrame] {
                                    assertBounded(frame, in: bounds)
                                }
                                XCTAssertEqual(geometry.iconFrame.width, geometry.iconFrame.height)
                                XCTAssertLessThanOrEqual(geometry.iconFrame.width, CGFloat(side))
                                assertNoOverlap(geometry.nameFrame, geometry.countFrame)
                                if visible {
                                    assertNoOverlap(geometry.iconFrame, geometry.nameFrame)
                                    if folder { assertNoOverlap(geometry.iconFrame, geometry.countFrame) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func testTinyCaptionsCompressInsideBoundsAndIconBecomesEmpty() {
        let bounds = CGRect(x: 0, y: 0, width: 1, height: 15)
        let geometry = GridItemContentGeometry(bounds: bounds, appearance: .default,
                                               showsLabels: true, isFolderCell: true)
        XCTAssertEqual(geometry.iconFrame.width, 0)
        XCTAssertEqual(geometry.nameFrame.height, 14)
        XCTAssertEqual(geometry.countFrame.height, 1)
        XCTAssertEqual(geometry.nameFrame.width, 0)
        XCTAssertEqual(geometry.countFrame.maxY, bounds.maxY)
    }

    func testInvalidAppearanceUsesSafeDefaultGeometry() {
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 88)
        let invalid = GridItemContentGeometry(bounds: bounds,
                                             appearance: GridItemAppearance(preferredIconSide: Int.max,
                                                                            appLabelFontSize: Int.min),
                                             showsLabels: true, isFolderCell: true)
        let expected = GridItemContentGeometry(bounds: bounds, appearance: .default,
                                              showsLabels: true, isFolderCell: true)
        XCTAssertEqual(invalid, expected)
        XCTAssertEqual(expected.iconFrame.origin, CGPoint(x: 36, y: 48))
    }

    func testExplicitStandardContextPreservesExistingGeometry() {
        for folder in [false, true] {
            for labels in [false, true] {
                for side in [32, 48, 54, 64] {
                    let bounds = CGRect(x: 7, y: -9, width: 100, height: 88)
                    let appearance = GridItemAppearance(preferredIconSide: side)
                    XCTAssertEqual(
                        GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                                showsLabels: labels, isFolderCell: folder),
                        GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                                showsLabels: labels, isFolderCell: folder, context: .standard))
                }
            }
        }
    }

    func testMainGridCentersActualIconAndCaptionStackAtNonzeroOrigin() {
        let bounds = CGRect(x: 10, y: 20, width: 140, height: 150)
        let appearance = GridItemAppearance(preferredIconSide: 80)
        let app = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                         showsLabels: true, isFolderCell: false, context: .mainGrid)
        XCTAssertEqual(app.iconFrame, CGRect(x: 40, y: 64, width: 80, height: 80))
        XCTAssertEqual(app.nameFrame, CGRect(x: 12, y: 46, width: 136, height: 14))
        let folder = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                            showsLabels: true, isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(folder.iconFrame, CGRect(x: 40, y: 70, width: 80, height: 80))
        XCTAssertEqual(folder.nameFrame, CGRect(x: 12, y: 40, width: 136, height: 14))
        XCTAssertEqual(folder.countFrame, CGRect(x: 12, y: 54, width: 136, height: 12))
        for geometry in [app, folder] {
            XCTAssertEqual(geometry.iconFrame.maxY - bounds.midY,
                           bounds.midY - geometry.nameFrame.minY, accuracy: 0.000001)
        }
        XCTAssertEqual(app.iconFrame.minY - app.nameFrame.maxY, 4)
        XCTAssertEqual(folder.iconFrame.minY - folder.countFrame.maxY, 4)
    }

    func testMainGridFitsToTwoPointPaddingWithoutScalingCaptionFonts() {
        let appearance = GridItemAppearance(preferredIconSide: 96)
        let bounds = CGRect(x: 0, y: 0, width: 140, height: 116)
        let geometry = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                               showsLabels: true, isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(geometry.iconFrame, CGRect(x: 29, y: 32, width: 82, height: 82))
        XCTAssertEqual(geometry.nameFrame.height, 14)
        XCTAssertEqual(geometry.countFrame.height, 12)
        XCTAssertEqual(geometry.nameFrame.minY, 2)
        XCTAssertEqual(bounds.maxY - geometry.iconFrame.maxY, 2)
        let large = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 140, height: 130),
                                            appearance: appearance, showsLabels: true,
                                            isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(large.iconFrame.width, 96)
    }

    func testMainGridEightyPointFolderGlyphFitsReferenceRowAtTwelvePointFont() {
        let geometry = GridItemContentGeometry(
            bounds: CGRect(x: 0, y: 0, width: (952.0 - 5 * 16) / 6, height: 116),
            appearance: .init(preferredIconSide: 80, appLabelFontSize: 12),
            showsLabels: true, isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(geometry.iconFrame.width, 80)
        XCTAssertEqual(geometry.iconFrame.minY - geometry.countFrame.maxY, 4)
        XCTAssertGreaterThanOrEqual(geometry.nameFrame.minY, 2)
        XCTAssertLessThanOrEqual(geometry.iconFrame.maxY, 114)
    }

    func testMainGridHiddenLabelsCenterIconAndReleaseCaptionBudget() {
        let bounds = CGRect(x: 5, y: -7, width: 140, height: 88)
        let appearance = GridItemAppearance(preferredIconSide: 80)
        let visible = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                              showsLabels: true, isFolderCell: true, context: .mainGrid)
        let hidden = GridItemContentGeometry(bounds: bounds, appearance: appearance,
                                             showsLabels: false, isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(hidden.iconFrame.width, 80)
        XCTAssertEqual(hidden.iconFrame.midY, bounds.midY)
        XCTAssertEqual(hidden.iconFrame.midX, bounds.midX)
        XCTAssertGreaterThan(hidden.iconFrame.width, visible.iconFrame.width)
    }

    func testMainGridTinyAndNarrowCellsKeepEveryFrameBounded() {
        for width in [CGFloat(0), 1, 3, 20, 80, 140] {
            for height in [CGFloat(0), 1, 3, 4, 14, 15, 26, 30, 88, 116, 150] {
                let bounds = CGRect(x: 5, y: -7, width: width, height: height)
                for labels in [false, true] {
                    for folder in [false, true] {
                        let geometry = GridItemContentGeometry(
                            bounds: bounds, appearance: .init(preferredIconSide: 96, appLabelFontSize: 16),
                            showsLabels: labels, isFolderCell: folder, context: .mainGrid)
                        for frame in [geometry.iconFrame, geometry.nameFrame, geometry.countFrame] {
                            assertBounded(frame, in: bounds)
                        }
                        XCTAssertEqual(geometry.iconFrame.width, geometry.iconFrame.height)
                        assertNoOverlap(geometry.nameFrame, geometry.countFrame)
                        if labels {
                            assertNoOverlap(geometry.iconFrame, geometry.nameFrame)
                            if folder { assertNoOverlap(geometry.iconFrame, geometry.countFrame) }
                        }
                    }
                }
            }
        }
        let empty = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 140, height: 15),
                                            appearance: .default, showsLabels: true,
                                            isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(empty.iconFrame.size, .zero)
    }

    func testMainGridSanitizesNonfiniteAndOverflowingBounds() {
        let malformed: [CGRect] = [
            CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: CGFloat.infinity, height: CGFloat.nan),
            CGRect(x: 5, y: -7, width: -1, height: -1),
            CGRect(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude,
                   width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        ]
        let sanitized = [CGRect.zero, CGRect(x: 5, y: -7, width: 0, height: 0),
                         CGRect(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude,
                                width: 0, height: 0)]
        for (bounds, expected) in zip(malformed, sanitized) {
            let geometry = GridItemContentGeometry(bounds: bounds, appearance: .default,
                                                   showsLabels: true, isFolderCell: true, context: .mainGrid)
            for frame in [geometry.iconFrame, geometry.nameFrame, geometry.countFrame] {
                assertBounded(frame, in: expected)
            }
        }
        let invalid = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 140, height: 150),
                                              appearance: .init(preferredIconSide: 97), showsLabels: true,
                                              isFolderCell: true, context: .mainGrid)
        let fallback = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 140, height: 150),
                                               appearance: .default, showsLabels: true,
                                               isFolderCell: true, context: .mainGrid)
        XCTAssertEqual(invalid, fallback)
    }

    private func assertBounded(_ frame: CGRect, in bounds: CGRect,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.000001, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, bounds.minY - 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.000001, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY + 0.000001, file: file, line: line)
    }

    private func assertNoOverlap(_ lhs: CGRect, _ rhs: CGRect,
                                 file: StaticString = #filePath, line: UInt = #line) {
        guard lhs.width > 0, lhs.height > 0, rhs.width > 0, rhs.height > 0 else { return }
        let intersection = lhs.intersection(rhs)
        XCTAssertTrue(intersection.isNull || intersection.width <= 0 || intersection.height <= 0,
                      "Content must not overlap: \(lhs), \(rhs)", file: file, line: line)
    }
}
