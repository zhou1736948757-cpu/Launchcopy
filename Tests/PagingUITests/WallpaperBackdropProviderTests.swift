import AppKit
import ImageIO
import XCTest
@testable import PagingPrototypeApp

private final class WallpaperTestResults: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [CGImage?] = []
    func append(_ image: CGImage?) {
        lock.lock(); defer { lock.unlock() }
        values.append(image)
    }
    var images: [CGImage?] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
}

final class WallpaperBackdropProviderTests: XCTestCase {
    func testConcurrentSameKeyRequestsReuseMemoryImage() throws {
        let fixture = try makeFixture()
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        let request = WallpaperBackdropProvider.Request(
            screenSize: CGSize(width: 24, height: 16), backingScale: 1, blurRadius: 0
        )
        let results = WallpaperTestResults()
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            results.append(provider.blurredWallpaper(for: request, sourceURL: fixture.source))
        }
        XCTAssertEqual(results.images.count, 8)
        let first = try XCTUnwrap(results.images.first ?? nil)
        for image in results.images {
            XCTAssertTrue(try XCTUnwrap(image) === first)
        }
        XCTAssertTrue(provider.blurredWallpaper(for: request, sourceURL: fixture.source) === first)
    }

    func testInvalidationConcurrentWithRequestsCompletesWithoutMissingImages() throws {
        let fixture = try makeFixture()
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        let request = WallpaperBackdropProvider.Request(
            screenSize: CGSize(width: 24, height: 16), backingScale: 1, blurRadius: 0
        )
        let results = WallpaperTestResults()
        DispatchQueue.concurrentPerform(iterations: 12) { index in
            if index.isMultiple(of: 3) { provider.invalidate() }
            results.append(provider.blurredWallpaper(for: request, sourceURL: fixture.source))
        }
        XCTAssertEqual(results.images.count, 12)
        XCTAssertTrue(results.images.allSatisfy { $0 != nil })
    }

    func testSettingsChurnKeepsMemoryCacheBounded() throws {
        let fixture = try makeFixture()
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        for radius in stride(from: 0, through: 60, by: 3) {
            let request = WallpaperBackdropProvider.Request(
                screenSize: CGSize(width: 24, height: 16), backingScale: 1,
                blurRadius: Double(radius)
            )
            XCTAssertNotNil(provider.blurredWallpaper(for: request, sourceURL: fixture.source))
            XCTAssertLessThanOrEqual(provider.memoryCacheCount, 6)
        }
        provider.invalidate()
        XCTAssertEqual(provider.memoryCacheCount, 0)
    }

    func testZeroBlurRendersFullRequestedResolution() throws {
        let fixture = try makeFixture()
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        let request = WallpaperBackdropProvider.Request(
            screenSize: CGSize(width: 24, height: 16), backingScale: 1, blurRadius: 0
        )
        let image = try XCTUnwrap(provider.blurredWallpaper(for: request, sourceURL: fixture.source))
        XCTAssertEqual(image.width, 24)
        XCTAssertEqual(image.height, 16)
    }

    func testAdjacentBlurRadiiHaveDistinctMemoryAndDiskCacheResults() async throws {
        let fixture = try makeFixture(patterned: true)
        let provider = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        var expected: [Int: Data] = [:]
        for radius in [16, 17, 18] {
            let request = WallpaperBackdropProvider.Request(
                screenSize: CGSize(width: 240, height: 160), backingScale: 1,
                blurRadius: Double(radius)
            )
            let image = try XCTUnwrap(provider.blurredWallpaper(for: request, sourceURL: fixture.source))
            expected[radius] = try pixels(image)
        }
        XCTAssertNotEqual(expected[16], expected[17])
        XCTAssertNotEqual(expected[17], expected[18])
        let deadline = Date().addingTimeInterval(3)
        var cacheFiles: [URL] = []
        repeat {
            cacheFiles = (try? FileManager.default.contentsOfDirectory(at: fixture.cache,
                                                                     includingPropertiesForKeys: nil)) ?? []
            // ImageIO may expose temporary files while its atomic write is in flight.
            // Await completed cache images, not a transient directory-entry count.
            cacheFiles = cacheFiles.filter { url in
                guard url.lastPathComponent.hasPrefix("v2-"), url.pathExtension == "png",
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
                return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
            }
            if cacheFiles.count >= 3 { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        } while Date() < deadline
        XCTAssertEqual(cacheFiles.count, 3, "All three radii need independent disk entries")
        XCTAssertTrue(cacheFiles.allSatisfy { $0.lastPathComponent.hasPrefix("v2-") })
        let reloaded = WallpaperBackdropProvider(cacheDirectory: fixture.cache)
        for radius in [18, 16, 17] {
            let request = WallpaperBackdropProvider.Request(
                screenSize: CGSize(width: 240, height: 160), backingScale: 1,
                blurRadius: Double(radius)
            )
            let image = try XCTUnwrap(reloaded.blurredWallpaper(for: request, sourceURL: fixture.source))
            XCTAssertEqual(try pixels(image), expected[radius])
        }
    }

    private func pixels(_ image: CGImage) throws -> Data {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Data(bytes: try XCTUnwrap(context.data), count: image.width * image.height * 4)
    }

    private func makeFixture(patterned: Bool = false) throws -> (source: URL, cache: URL) {
        // Keep generated fixtures in the project's build artifacts, not user data.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/verification/20261013/wallpaper-fixtures")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("synthetic.png")
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        if patterned {
            context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1))
            context.fill(CGRect(x: 4, y: 0, width: 4, height: 8))
        }
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            source as CFURL, "public.png" as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return (source, root.appendingPathComponent("cache"))
    }
}
