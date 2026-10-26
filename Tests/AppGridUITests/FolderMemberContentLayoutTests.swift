import AppCatalogCore
import AppIconPipeline
import AppKit
import XCTest
@testable import AppGridUI
@testable import PagingUI

@MainActor
final class FolderMemberContentLayoutTests: XCTestCase {
    func testFolderStackKeepsSixPointCaptionGapAndCentersAcrossTallRows() {
        for height in [CGFloat(96), 120, 152, 240] {
            for side in [32, 48, 64] {
                let bounds = CGRect(x: 13, y: 27, width: 160, height: height)
                let geometry = GridItemContentGeometry(bounds: bounds,
                    appearance: .init(preferredIconSide: side, appLabelFontSize: 11),
                    showsLabels: true, isFolderCell: false, context: .folderGrid)
                XCTAssertEqual(geometry.iconFrame.width, CGFloat(side), accuracy: 0.001)
                XCTAssertEqual(geometry.iconFrame.minY - geometry.nameFrame.maxY, 6, accuracy: 0.001)
                XCTAssertEqual((geometry.nameFrame.minY + geometry.iconFrame.maxY) / 2,
                    bounds.midY, accuracy: 0.001)
                XCTAssertEqual(geometry.iconFrame.midX, bounds.midX, accuracy: 0.001)
            }
        }
        let standard = GridItemContentGeometry(bounds: CGRect(x: 0, y: 0, width: 160, height: 152),
            appearance: .default, showsLabels: true, isFolderCell: false)
        XCTAssertEqual(standard.iconFrame.minY - standard.nameFrame.maxY, 78)
    }

    func testHiddenNamesCenterGlyphAndDoNotReserveCaptionSpace() {
        let bounds = CGRect(x: -15, y: 19, width: 140, height: 160)
        let geometry = GridItemContentGeometry(bounds: bounds,
            appearance: .init(preferredIconSide: 64, appLabelFontSize: 16),
            showsLabels: false, isFolderCell: false, context: .folderGrid)
        XCTAssertEqual(geometry.iconFrame.size, CGSize(width: 64, height: 64))
        XCTAssertEqual(geometry.iconFrame.midY, bounds.midY)
        XCTAssertEqual(geometry.iconFrame.midX, bounds.midX)
    }

    func testNonfiniteBoundsAndInvalidPreviewLimitsStayFinite() {
        for bounds in [CGRect.null, CGRect.infinite,
                       CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: 112, height: 100),
                       CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0,
                              width: CGFloat.greatestFiniteMagnitude, height: 100)] {
            let geometry = GridItemContentGeometry(bounds: bounds, appearance: .default,
                showsLabels: true, isFolderCell: false, context: .folderGrid)
            for frame in [geometry.iconFrame, geometry.nameFrame, geometry.countFrame] {
                XCTAssertTrue(frame.minX.isFinite && frame.minY.isFinite
                    && frame.maxX.isFinite && frame.maxY.isFinite)
            }
        }
        let bounds = CGRect(x: 0, y: 0, width: 160, height: 152)
        for invalid in [CGFloat.nan, CGFloat.infinity, -1] {
            let geometry = GridItemContentGeometry(bounds: bounds, appearance: .default,
                showsLabels: true, isFolderCell: false, context: .folderGrid, iconSideLimit: invalid)
            XCTAssertEqual(geometry.iconFrame.width, 48)
        }
    }

    func testEveryFontAndTinyCellKeepsRenderedIconAndCaptionBounded() {
        for width in [CGFloat(0), 1, 24, 64, 112, 170] {
            for height in [CGFloat(0), 1, 8, 14, 20, 40, 88, 152] {
                for font in 9...16 {
                    let bounds = CGRect(x: 8, y: -12, width: width, height: height)
                    let geometry = GridItemContentGeometry(bounds: bounds,
                        appearance: .init(preferredIconSide: 64, appLabelFontSize: font),
                        showsLabels: true, isFolderCell: false, context: .folderGrid)
                    for frame in [geometry.iconFrame, geometry.nameFrame, geometry.countFrame] {
                        XCTAssertTrue(frame.minX.isFinite && frame.minY.isFinite)
                        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX)
                        XCTAssertGreaterThanOrEqual(frame.minY, bounds.minY)
                        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX)
                        XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY)
                    }
                    if !geometry.iconFrame.isEmpty {
                        XCTAssertGreaterThanOrEqual(geometry.iconFrame.minY, geometry.nameFrame.maxY)
                    }
                }
            }
        }
    }

    func testFolderPreviewPreservesActualGlyphAndRetainsCapturedContentAfterSourceReuse() throws {
        for (side, width) in [(48, CGFloat(160)), (64, 160), (64, 32.5)] {
            let actualSide = min(CGFloat(side), width)
            let cell = AppGridCellView(frame: CGRect(x: 0, y: 0, width: width, height: 152))
            cell.contentLayoutContext = .folderGrid
            cell.itemAppearance = .init(preferredIconSide: side, appLabelFontSize: 16)
            cell.bind(name: "Owned folder preview", token: ItemBindingToken(catalogRevision: 1,
                pageIdentity: PagePresentationID(revision: 1, pageIndex: 0), itemSlot: 0,
                appID: AnyHashable(makeAppID("fixture.folder.preview")), reuseGeneration: 1,
                iconKey: nil, surfaceGeneration: 1))
            cell.iconView.image = makeIconImage()
            cell.layoutSubtreeIfNeeded()
            let host = NSView(frame: CGRect(x: 0, y: 0, width: 600, height: 500))
            let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
            visuals.showPreview(sourceCell: cell, at: NSPoint(x: 200, y: 200))
            let preview = try XCTUnwrap(host.subviews.first { $0.subviews.contains { $0 is NSImageView } })
            let icon = try XCTUnwrap(preview.subviews.compactMap { $0 as? NSImageView }.first)
            let label = try XCTUnwrap(preview.subviews.compactMap { $0 as? NSTextField }.first)
            XCTAssertEqual(icon.frame.width, actualSide, accuracy: 0.001)
            XCTAssertEqual(icon.frame.minY - label.frame.maxY, 6, accuracy: 0.001)
            let image = try XCTUnwrap(icon.image)
            cell.clearContent()
            for index in 0..<20 { visuals.movePreview(to: NSPoint(x: CGFloat(100 + index), y: 200)) }
            XCTAssertTrue(icon.image === image)
            XCTAssertEqual(label.stringValue, "Owned folder preview")
            XCTAssertEqual(icon.frame.width, actualSide)
        }
    }

    func testRegularReusedAndSwipeMembersShareFolderContextWithoutChangingCapacityOrFrames() throws {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown(); pipeline.shutdown() }
        overlay.frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let layout = FolderLayoutPolicy.resolve(usableBounds: overlay.bounds, appearance: .default)
        overlay.applyFolderLayout(layout)
        let entry = FolderEntry(id: FolderID(), title: "Owned folder", members:
            (0..<35).map { makeAppID("fixture.folder.layout.\($0)") })
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { _ in "Owned member" }
        overlay.layoutSubtreeIfNeeded()
        let first = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertEqual(first.contentLayoutContext, .folderGrid)
        XCTAssertEqual(overlay.membersPerPage, 15)
        XCTAssertEqual(first.frame, layout.cellFrames[0])
        let initialRequests = pipeline.stats.requests
        overlay.needsLayout = true
        overlay.layoutSubtreeIfNeeded()
        XCTAssertEqual(pipeline.stats.requests, initialRequests)
        overlay.configure(entry: entry, innerPage: 1, reduceMotion: false) { _ in "Owned next member" }
        XCTAssertTrue(first === overlay.memberCell(at: 0))
        XCTAssertEqual(first.contentLayoutContext, .folderGrid)
        overlay.trackpadPager.automaticallyDrivesFrames = false
        overlay.handleTrackpadScroll(phase: .began, momentumPhase: [], deltaX: 0, deltaY: 0,
            isDirectionInverted: true, timestamp: 1)
        overlay.handleTrackpadScroll(phase: .changed, momentumPhase: [], deltaX: -100, deltaY: 0,
            isDirectionInverted: true, timestamp: 1.1)
        func cells(in view: NSView) -> [AppGridCellView] {
            view.subviews.flatMap { child in
                (child as? AppGridCellView).map { [$0] } ?? cells(in: child)
            }
        }
        let all = cells(in: overlay)
        XCTAssertGreaterThan(all.count, overlay.memberCellCount)
        XCTAssertTrue(all.allSatisfy { $0.contentLayoutContext == .folderGrid })
    }
}
