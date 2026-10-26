import Foundation
import XCTest
@testable import PagingPrototypeApp

final class LibraryHorizontalLayoutTests: XCTestCase {
    func testSharedMetricsMatchPreviousLayoutAcrossBoundariesAndModes() {
        for width: CGFloat in [0, 31, 32, 360, 451, 452, 632, 843.99, 844, 1000, 1600] {
            for gallery in [false, true] {
                let layout = LibraryHorizontalLayout(boundsWidth: width, showsGallery: gallery)
                let available = max(0, width - 32)
                let compact = available < 420
                let sidebar = compact ? 0 : min(200, max(130, available * 0.23))
                let x: CGFloat = gallery ? 16 : 16 + sidebar + (compact ? 0 : 12)
                let content = max(0, 16 + available - x)
                XCTAssertEqual(layout.availableWidth, available)
                XCTAssertEqual(layout.isCompact, compact)
                XCTAssertEqual(layout.sidebarWidth, sidebar)
                XCTAssertEqual(layout.contentX, x)
                XCTAssertEqual(layout.contentWidth, content)
                for details in [false, true] {
                    XCTAssertEqual(layout.showsResultsBesideDetails(detailsOpen: details), details && content >= 600)
                    XCTAssertEqual(layout.allowsResultIcons(detailsOpen: details), !gallery && (!details || content >= 600))
                }
            }
        }
    }
    func testCompactAndDetailThresholdsDoNotDriftFromWorkAdmission() {
        XCTAssertTrue(LibraryHorizontalLayout(boundsWidth: 451.99, showsGallery: false).isCompact)
        XCTAssertFalse(LibraryHorizontalLayout(boundsWidth: 452, showsGallery: false).isCompact)
        let below = LibraryHorizontalLayout(boundsWidth: 826, showsGallery: false)
        let at = LibraryHorizontalLayout(boundsWidth: 827, showsGallery: false)
        XCTAssertFalse(below.allowsResultIcons(detailsOpen: true))
        XCTAssertTrue(at.allowsResultIcons(detailsOpen: true))
    }
}
