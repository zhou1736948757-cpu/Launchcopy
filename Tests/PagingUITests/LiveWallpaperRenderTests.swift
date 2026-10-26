import AppKit
import XCTest
@testable import PagingPrototypeApp

final class LiveWallpaperRenderTests: XCTestCase {
    @MainActor
    func testBurstRetainsOnlyOneActiveAndLatestPendingBackgroundRender() async {
        let entered = expectation(description: "first render blocked")
        let newest = expectation(description: "latest render completed")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let loader = WallpaperBackdropController.backgroundLoader { request, _ in
            XCTAssertFalse(Thread.isMainThread)
            if request.blurRadius == 0 {
                entered.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            } else { XCTAssertEqual(request.blurRadius, 200, "No superseded pending render may run") }
            return nil
        }
        let url = URL(fileURLWithPath: "/synthetic-not-read")
        var completed: [Double] = []
        loader(.init(screenSize: .init(width: 1000, height: 700), backingScale: 2, blurRadius: 0), url) { _ in
            completed.append(0)
        }
        await fulfillment(of: [entered], timeout: 2)
        for i in 1...200 {
            loader(.init(screenSize: .init(width: 1000, height: 700), backingScale: 2, blurRadius: Double(i)), url) { _ in
                completed.append(Double(i))
                if i == 200 { newest.fulfill() }
                else { XCTFail("Superseded queued completion must be retired") }
            }
        }
        release.signal()
        await fulfillment(of: [newest], timeout: 3)
        XCTAssertEqual(completed, [0, 200])
    }
}
