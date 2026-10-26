import AppKit
import XCTest
@testable import PagingPrototypeApp

final class WallpaperBackdropControllerTests: XCTestCase {
    private let enabled = LaunchcopyMaterialPolicy(
        reduceTransparency: false, increaseContrast: false, reduceMotion: false
    )
    private let opaque = LaunchcopyMaterialPolicy(
        reduceTransparency: true, increaseContrast: false, reduceMotion: false
    )

    @MainActor
    func testBlockedRenderDoesNotBlockRefreshOrMainQueue() async throws {
        let entered = expectation(description: "background renderer entered")
        let applied = expectation(description: "render result delivered on main actor")
        let heartbeat = expectation(description: "main queue remains responsive")
        let released = DispatchSemaphore(value: 0)
        defer { released.signal() }
        let image = try makeImage()
        let loader = WallpaperBackdropController.backgroundLoader { _, _ in
            XCTAssertFalse(Thread.isMainThread)
            entered.fulfill()
            XCTAssertEqual(released.wait(timeout: .now() + 5), .success,
                           "Main queue must release rendering before timeout")
            return image
        }
        let controller = WallpaperBackdropController(
            imageLoader: { request, source, completion in
                loader(request, source) { result in
                    XCTAssertTrue(Thread.isMainThread)
                    completion(result)
                    applied.fulfill()
                }
            },
            sourceResolver: { _ in URL(fileURLWithPath: "/synthetic-unused-wallpaper") }
        )
        let host = makeHost()
        controller.attach(to: host)
        // Queue before refresh: synchronous I/O would prevent this from releasing
        // the renderer and fail, rather than silently passing after a timeout.
        DispatchQueue.main.async { heartbeat.fulfill(); released.signal() }
        controller.refresh(for: nil, policy: enabled)
        XCTAssertNil(try imageView(in: host).image)
        await fulfillment(of: [entered, heartbeat, applied], timeout: 2)
        XCTAssertNotNil(try imageView(in: host).image)
    }

    @MainActor
    func testLatestRequestWinsWithOutOfOrderCompletions() throws {
        var completions: [@MainActor (CGImage?) -> Void] = []
        let controller = makeController { _, _, completion in completions.append(completion) }
        let host = makeHost()
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled)
        controller.refresh(for: nil, policy: enabled)
        XCTAssertEqual(completions.count, 2)
        completions[1](try makeImage())
        let current = try XCTUnwrap(imageView(in: host).image)
        completions[0](try makeImage())
        XCTAssertTrue(try imageView(in: host).image === current)
    }

    @MainActor
    func testReduceTransparencyRejectsAlreadyPendingResult() throws {
        var completions: [@MainActor (CGImage?) -> Void] = []
        let controller = makeController { _, _, completion in completions.append(completion) }
        let host = makeHost()
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled)
        controller.refresh(for: nil, policy: opaque)
        XCTAssertEqual(completions.count, 1)
        completions[0](try makeImage())
        XCTAssertNil(try imageView(in: host).image)
    }

    @MainActor
    func testHostReplacementInvalidatesOldResult() throws {
        var completion: (@MainActor (CGImage?) -> Void)?
        let controller = makeController { _, _, callback in completion = callback }
        let original = makeHost()
        controller.attach(to: original)
        controller.refresh(for: nil, policy: enabled)
        let replacement = makeHost()
        controller.attach(to: replacement)
        try XCTUnwrap(completion)(makeImage())
        XCTAssertTrue(original.subviews.isEmpty)
        XCTAssertNil(try imageView(in: replacement).image)
    }

    @MainActor
    func testFailedRenderUsesFallbackAndDoesNotBlockHitTesting() throws {
        let controller = makeController { _, _, completion in completion(nil) }
        let host = makeHost()
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled)
        XCTAssertNil(try imageView(in: host).image)
        XCTAssertNotNil(host.layer?.backgroundColor)
        for view in host.subviews {
            XCTAssertNil(view.hitTest(NSPoint(x: 10, y: 10)))
        }
    }

    @MainActor
    func testMissingSourceDoesNotInvokeLoader() throws {
        let controller = WallpaperBackdropController(
            imageLoader: { _, _, _ in XCTFail("No source must not invoke worker") },
            sourceResolver: { _ in nil }
        )
        let host = makeHost()
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled)
        XCTAssertNil(try imageView(in: host).image)
    }

    @MainActor
    func testConfiguredBlurRadiusUsesLatestRequestAndRejectsOlderImage() throws {
        var radii: [Double] = []
        var completions: [@MainActor (CGImage?) -> Void] = []
        let controller = makeController { request, _, completion in
            radii.append(request.blurRadius)
            completions.append(completion)
        }
        let host = makeHost()
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled, blurRadius: 0)
        controller.refresh(for: nil, policy: enabled, blurRadius: 60)
        XCTAssertEqual(radii, [0, 60])
        completions[0](try makeImage())
        XCTAssertNil(try imageView(in: host).image)
        completions[1](try makeImage())
        XCTAssertNotNil(try imageView(in: host).image)
    }

    @MainActor
    func testInvalidRadiusIsBoundedBeforeWorkerRequest() {
        var radii: [Double] = []
        let controller = makeController { request, _, _ in radii.append(request.blurRadius) }
        let host = makeHost()
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled, blurRadius: .nan)
        controller.refresh(for: nil, policy: enabled, blurRadius: -10)
        controller.refresh(for: nil, policy: enabled, blurRadius: 100)
        XCTAssertEqual(radii, [18, 0, 60])
    }

    @MainActor
    func testReleasedControllerRejectsResult() throws {
        var completion: (@MainActor (CGImage?) -> Void)?
        var controller: WallpaperBackdropController? = makeController { _, _, callback in completion = callback }
        weak var releasedController = controller
        let host = makeHost()
        controller?.attach(to: host)
        controller?.refresh(for: nil, policy: enabled)
        let view = try imageView(in: host)
        controller = nil
        XCTAssertNil(releasedController)
        try XCTUnwrap(completion)(makeImage())
        XCTAssertNil(view.image)
    }

    @MainActor
    private func makeController(
        loader: @escaping WallpaperBackdropController.ImageLoader
    ) -> WallpaperBackdropController {
        WallpaperBackdropController(imageLoader: loader, sourceResolver: { _ in
            URL(fileURLWithPath: "/synthetic-unused-wallpaper")
        })
    }

    @MainActor
    private func makeHost() -> NSView {
        NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 100))
    }

    @MainActor
    private func imageView(in host: NSView) throws -> NSImageView {
        try XCTUnwrap(host.subviews.compactMap { $0 as? NSImageView }.first)
    }

    private func makeImage() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        return try XCTUnwrap(context.makeImage())
    }
}
