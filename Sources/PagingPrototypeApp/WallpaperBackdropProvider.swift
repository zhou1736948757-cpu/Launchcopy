//
//  WallpaperBackdropProvider.swift
//  PagingPrototypeApp
//
//  Phase 1I: Independent wallpaper blur backdrop for Launchcopy.
//  Design intent from PHASE1I_VISUAL_REFERENCE_DIGEST (Route B); NEW implementation.
//  - Thumbnail decode → cover crop → CIGaussianBlur at reduced resolution
//  - Memory cache + async disk cache under Caches
//  - In-flight dedupe; solid-color fallback; no Buho / no line-copy of LaunchBetter
//

import AppKit
import CoreImage
import CryptoKit
import Foundation
import ImageIO

public final class WallpaperBackdropProvider: @unchecked Sendable {
    public struct Request: Hashable, Sendable {
        public var screenSize: CGSize
        public var backingScale: CGFloat
        public var blurRadius: Double

        public init(screenSize: CGSize, backingScale: CGFloat, blurRadius: Double) {
            self.screenSize = screenSize
            self.backingScale = backingScale
            self.blurRadius = blurRadius
        }
    }

    private struct CacheKey: Hashable {
        var pixelWidth: Int
        var pixelHeight: Int
        var blur: Int
        var sourceDigest: String
    }

    private let lock = NSLock()
    private let condition = NSCondition()
    private var memory: [CacheKey: CGImage] = [:]
    private var inflight: Set<CacheKey> = []
    private let cacheDirectory: URL
    private let writeQueue = DispatchQueue(label: "com.launchcopy.wallpaper-disk", qos: .utility)
    private var pendingDisk: Set<URL> = []

    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.cacheDirectory = base.appendingPathComponent("LaunchcopyWallpaper", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    /// Synchronous render for background queues. Returns nil → caller uses solid fallback.
    public func blurredWallpaper(for request: Request) -> CGImage? {
        guard let sourceURL = resolveWallpaperURL(matching: request.screenSize) else { return nil }
        let key = makeKey(request: request, sourceURL: sourceURL)

        condition.lock()
        while inflight.contains(key) { condition.wait() }
        if let hit = memory[key] {
            condition.unlock()
            return hit
        }
        inflight.insert(key)
        condition.unlock()

        defer {
            condition.lock()
            inflight.remove(key)
            condition.broadcast()
            condition.unlock()
        }

        let diskURL = cacheDirectory.appendingPathComponent(diskName(for: key))
        if let disk = loadCGImage(url: diskURL) {
            lock.lock(); memory[key] = disk; lock.unlock()
            return disk
        }

        guard let source = decodeThumbnail(url: sourceURL, maxPixel: 512) else { return nil }
        let factor = LaunchcopyVisualTokens.wallpaperRenderScaleFactor
        let scale = request.backingScale * factor
        let blur = request.blurRadius * Double(factor)
        guard let rendered = Self.render(source, targetSize: request.screenSize, scale: scale, blurRadius: blur) else {
            return nil
        }
        lock.lock(); memory[key] = rendered; lock.unlock()
        enqueueDiskWrite(rendered, to: diskURL)
        return rendered
    }

    public func invalidate() {
        lock.lock(); memory.removeAll(); lock.unlock()
    }

    // MARK: - Resolve / decode

    private func resolveWallpaperURL(matching size: CGSize) -> URL? {
        let screens = NSScreen.screens
        if let best = screens.min(by: {
            sizeDistance($0.frame.size, size) < sizeDistance($1.frame.size, size)
        }), let url = NSWorkspace.shared.desktopImageURL(for: best) {
            return url
        }
        for screen in screens {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) { return url }
        }
        return nil
    }

    private func sizeDistance(_ a: CGSize, _ b: CGSize) -> CGFloat {
        abs(a.width - b.width) + abs(a.height - b.height)
    }

    private func decodeThumbnail(url: URL, maxPixel: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }

    // MARK: - Render

    static func render(_ image: CGImage, targetSize: CGSize, scale: CGFloat, blurRadius: Double) -> CGImage? {
        let width = max(1, Int(targetSize.width * scale))
        let height = max(1, Int(targetSize.height * scale))
        let ciImage = CIImage(cgImage: image)
        let cover = coverTransform(inputSize: CGSize(width: image.width, height: image.height),
                                   outputSize: CGSize(width: width, height: height))
        var transformed = ciImage.transformed(by: cover)
        if blurRadius > 0.5, let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(transformed.clampedToExtent(), forKey: kCIInputImageKey)
            blur.setValue(blurRadius, forKey: kCIInputRadiusKey)
            if let out = blur.outputImage {
                transformed = out.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(transformed, from: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private static func coverTransform(inputSize: CGSize, outputSize: CGSize) -> CGAffineTransform {
        let scale = max(outputSize.width / max(inputSize.width, 1),
                        outputSize.height / max(inputSize.height, 1))
        let scaled = CGSize(width: inputSize.width * scale, height: inputSize.height * scale)
        let tx = (outputSize.width - scaled.width) / 2
        let ty = (outputSize.height - scaled.height) / 2
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }

    // MARK: - Cache keys / disk

    private func makeKey(request: Request, sourceURL: URL) -> CacheKey {
        let factor = LaunchcopyVisualTokens.wallpaperRenderScaleFactor
        let scale = request.backingScale * factor
        let digest = sourceDigest(for: sourceURL)
        return CacheKey(
            pixelWidth: Int(request.screenSize.width * scale),
            pixelHeight: Int(request.screenSize.height * scale),
            blur: Int((request.blurRadius * Double(factor)).rounded()),
            sourceDigest: digest
        )
    }

    private func sourceDigest(for url: URL) -> String {
        let standardized = url.standardizedFileURL.path
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let material = "\(standardized)|\(values?.fileSize ?? -1)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        return SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func diskName(for key: CacheKey) -> String {
        "v1-\(key.pixelWidth)x\(key.pixelHeight)-b\(key.blur)-\(key.sourceDigest.prefix(16)).png"
    }

    private func loadCGImage(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private func enqueueDiskWrite(_ image: CGImage, to url: URL) {
        lock.lock()
        if pendingDisk.contains(url) { lock.unlock(); return }
        pendingDisk.insert(url)
        lock.unlock()
        writeQueue.async { [weak self] in
            defer {
                self?.lock.lock()
                self?.pendingDisk.remove(url)
                self?.lock.unlock()
            }
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
    }
}
