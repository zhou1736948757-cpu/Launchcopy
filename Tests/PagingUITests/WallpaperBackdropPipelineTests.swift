import AppKit
import ImageIO
import XCTest
@testable import PagingPrototypeApp

final class WallpaperBackdropPipelineTests: XCTestCase {
    private let enabled = LaunchcopyMaterialPolicy(
        reduceTransparency: false, increaseContrast: false, reduceMotion: false
    )
    // These bounds detect missing progress only; they are not performance budgets.
    private let livenessTimeout: TimeInterval = 15

    @MainActor
    func testColdPipelineReachesReadyWithRenderedDimensionsAndResponsiveMainQueue() async throws {
        let fixture = try makeFixture()
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        let entered = expectation(description: "real background render entered")
        let heartbeat = expectation(description: "main queue runs while render is pending")
        let applied = expectation(description: "real rendered image applied")
        let releaseRender = DispatchSemaphore(value: 0)
        defer { releaseRender.signal() }
        let timeout = livenessTimeout
        let loader = WallpaperBackdropController.backgroundLoader { request, source in
            XCTAssertFalse(Thread.isMainThread)
            entered.fulfill()
            // Hold only the scheduling boundary, then execute the real provider.
            // Bound the wait so a synchronous-loader regression cannot hang Main.
            guard releaseRender.wait(timeout: .now() + timeout) == .success else {
                XCTFail("Main queue did not release the pending renderer")
                return nil
            }
            return provider.blurredWallpaper(for: request, sourceURL: source)
        }
        var request: WallpaperBackdropProvider.Request?
        var rendered: CGImage?
        let controller = WallpaperBackdropController(
            imageLoader: { value, source, completion in
                XCTAssertTrue(Thread.isMainThread)
                request = value
                loader(value, source) { image in
                    XCTAssertTrue(Thread.isMainThread)
                    rendered = image
                    completion(image)
                    applied.fulfill()
                }
            },
            sourceResolver: { _ in fixture.source }
        )
        let host = makeHost()
        controller.attach(to: host)
        let view = try imageView(in: host)
        var states: [WallpaperBackdropController.LoadState] = []
        controller.onLoadStateChange = { state in
            XCTAssertTrue(Thread.isMainThread)
            states.append(state)
        }
        XCTAssertEqual(provider.memoryCacheCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.cache.path))

        controller.refresh(for: nil, policy: enabled, blurRadius: 18)
        XCTAssertEqual(controller.loadState, .loading)
        XCTAssertNil(view.image)
        await fulfillment(of: [entered], timeout: livenessTimeout)
        DispatchQueue.main.async {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(controller.loadState, .loading)
            XCTAssertNil(view.image)
            heartbeat.fulfill()
            releaseRender.signal()
        }
        await fulfillment(of: [heartbeat, applied], timeout: livenessTimeout)

        XCTAssertEqual(controller.loadState, .ready)
        XCTAssertEqual(states, [.loading, .ready])
        XCTAssertEqual(provider.memoryCacheCount, 1)
        try assertInstalledImage(in: host, rendered: XCTUnwrap(rendered), request: XCTUnwrap(request))
    }

    @MainActor
    func testRepeatedPipelineRequestsShareProviderImageAcrossWarmRefresh() async throws {
        let fixture = try makeFixture()
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        let initialCompletions = expectation(description: "both same-key renders completed")
        initialCompletions.expectedFulfillmentCount = 2
        let warmCompletion = expectation(description: "warm same-key render completed")
        let loader = WallpaperBackdropController.backgroundLoader { request, source in
            XCTAssertFalse(Thread.isMainThread)
            return provider.blurredWallpaper(for: request, sourceURL: source)
        }
        var requests: [WallpaperBackdropProvider.Request] = []
        var results: [CGImage?] = []
        let controller = WallpaperBackdropController(
            imageLoader: { request, source, completion in
                requests.append(request)
                // Capture submission order; background completion order is unspecified.
                let submission = requests.count
                loader(request, source) { image in
                    XCTAssertTrue(Thread.isMainThread)
                    results.append(image)
                    completion(image)
                    if submission <= 2 {
                        initialCompletions.fulfill()
                    } else {
                        warmCompletion.fulfill()
                    }
                }
            },
            sourceResolver: { _ in fixture.source }
        )
        let host = makeHost()
        controller.attach(to: host)
        var states: [WallpaperBackdropController.LoadState] = []
        controller.onLoadStateChange = { states.append($0) }

        // Both refreshes precede the first main-queue delivery. The controller
        // must accept its current generation while both use the real provider.
        controller.refresh(for: nil, policy: enabled, blurRadius: 18)
        controller.refresh(for: nil, policy: enabled, blurRadius: 18)
        XCTAssertEqual(controller.loadState, .loading)
        XCTAssertNil(try imageView(in: host).image)
        await fulfillment(of: [initialCompletions], timeout: livenessTimeout)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(requests.count, 2)
        let first = try XCTUnwrap(results.first ?? nil)
        for result in results {
            XCTAssertTrue(try XCTUnwrap(result) === first,
                          "Same-key requests should reuse the provider's CGImage")
        }
        let firstRequest = try XCTUnwrap(requests.first)
        XCTAssertTrue(requests.allSatisfy { $0 == firstRequest })
        XCTAssertEqual(controller.loadState, .ready)
        XCTAssertEqual(states, [.loading, .ready])
        XCTAssertEqual(provider.memoryCacheCount, 1)
        try assertInstalledImage(in: host, rendered: first, request: firstRequest)

        controller.refresh(for: nil, policy: enabled, blurRadius: 18)
        XCTAssertEqual(controller.loadState, .loading)
        XCTAssertNotNil(try imageView(in: host).image, "Keep the backdrop during warm refresh")
        await fulfillment(of: [warmCompletion], timeout: livenessTimeout)
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests.allSatisfy { $0 == firstRequest })
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(try XCTUnwrap(results.last ?? nil) === first)
        XCTAssertEqual(provider.memoryCacheCount, 1)
        XCTAssertEqual(controller.loadState, .ready)
        XCTAssertEqual(states, [.loading, .ready, .loading, .ready])
        try assertInstalledImage(in: host, rendered: first, request: firstRequest)
    }

    @MainActor
    private func makeHost() -> NSView {
        NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 100))
    }

    @MainActor
    private func imageView(in host: NSView) throws -> NSImageView {
        try XCTUnwrap(host.subviews.compactMap { $0 as? NSImageView }.first)
    }

    @MainActor
    private func assertInstalledImage(
        in host: NSView,
        rendered: CGImage,
        request: WallpaperBackdropProvider.Request,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        // refresh uses the available screen geometry (or the host fallback).
        // Derive the expected pixel dimensions from that actual submitted request.
        let factor = request.blurRadius == 0 ? 1 : LaunchcopyVisualTokens.wallpaperRenderScaleFactor
        let scale = request.backingScale * factor
        let width = max(1, Int(request.screenSize.width * scale))
        let height = max(1, Int(request.screenSize.height * scale))
        XCTAssertEqual(rendered.width, width, file: file, line: line)
        XCTAssertEqual(rendered.height, height, file: file, line: line)
        let view = try imageView(in: host)
        let image = try XCTUnwrap(view.image, file: file, line: line)
        // AppKit may wrap the CGImage in a scale-dependent representation.
        // Reduced render pixels are asserted above, not against that wrapper's
        // device-dependent pixel size. The controller owns logical image size.
        XCTAssertFalse(image.representations.isEmpty, file: file, line: line)
        XCTAssertTrue(image.isValid, file: file, line: line)
        XCTAssertEqual(image.size, request.screenSize, file: file, line: line)
        XCTAssertFalse(view.isHidden, file: file, line: line)
        XCTAssertEqual(view.alphaValue, 1, file: file, line: line)
    }

    private func makeFixture() throws -> (source: URL, cache: URL) {
        // Match provider-test isolation: authored artifacts only, unique per test.
        // Deliberately retain this directory under .build; no deletion is authorized.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/verification/20261015/wallpaper-pipeline-fixtures")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("authored-8x8.png")
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 4, y: 0, width: 4, height: 8))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            source as CFURL, "public.png" as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return (source, root.appendingPathComponent("cache", isDirectory: true))
    }
}
