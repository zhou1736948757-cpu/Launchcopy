//
//  WallpaperBackdropView.swift
//  PagingPrototypeApp
//
//  Phase 1I: Bulletproof wallpaper host — NSImageView under the grid (not CALayer-only).
//  hitTest → nil so blank-click / cells still work. LaunchBetter intent: wallpaper behind UI.
//

import AppKit
import Foundation

/// 点击穿透的全屏图：不参与 hitTest，避免挡住空白点击与图标。
final class PassThroughImageView: NSImageView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class PassThroughDimView: NSView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// 壁纸控制器：在 host 最底部插入 ImageView + 轻遮罩。
@MainActor
public final class WallpaperBackdropController {
    /// Neutral diagnostic outcomes; no source paths, image data or raw errors.
    enum LoadState: String, Equatable {
        case idle
        case policyDisabled = "policy-disabled"
        case sourceUnavailable = "source-unavailable"
        case loading
        case ready
        case renderFailed = "render-failed"
    }
    private(set) var loadState: LoadState = .idle
    var onLoadStateChange: ((LoadState) -> Void)?
    struct Diagnostic: Equatable {
        let state: LoadState
        let source: WallpaperSourceInspection?
        var summary: String {
            "Wallpaper diagnostic: " + state.rawValue
                + (source.map { "; " + $0.summary } ?? "")
        }
    }
    private(set) var sourceInspection: WallpaperSourceInspection?
    var onDiagnosticChange: ((Diagnostic) -> Void)?
    var diagnostic: Diagnostic { .init(state: loadState, source: sourceInspection) }

    private func publishDiagnostic() { onDiagnosticChange?(diagnostic) }

    private func publish(_ state: LoadState) {
        guard loadState != state else { return }
        loadState = state
        onLoadStateChange?(state)
        publishDiagnostic()
    }

    private weak var host: NSView?
    private let imageView = PassThroughImageView(frame: .zero)
    private let dimView = PassThroughDimView(frame: .zero)
    // Only immutable requests/CGImages cross queues; all AppKit work stays here.
    typealias ImageLoader = @MainActor (
        WallpaperBackdropProvider.Request, URL, @escaping @MainActor (CGImage?) -> Void
    ) -> Void
    private let imageLoader: ImageLoader
    private let sourceResolver: @MainActor (NSScreen?) -> URL?
    typealias SourceInspector = @MainActor (URL, @escaping @MainActor (WallpaperSourceInspection) -> Void) -> Void
    private let sourceInspector: SourceInspector?
    private var generation = 0

    public convenience init() {
        let provider = WallpaperBackdropProvider()
        self.init(imageLoader: Self.backgroundLoader { request, sourceURL in
            provider.blurredWallpaper(for: request, sourceURL: sourceURL)
        })
    }

    init(
        imageLoader: @escaping ImageLoader,
        sourceResolver: @escaping @MainActor (NSScreen?) -> URL? = { screen in
            guard let screen else { return nil }
            return NSWorkspace.shared.desktopImageURL(for: screen)
        },
        sourceInspector: SourceInspector? = nil
    ) {
        self.imageLoader = imageLoader
        self.sourceResolver = sourceResolver
        self.sourceInspector = sourceInspector
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.isOpaque = false

        dimView.wantsLayer = true
        dimView.layer?.isOpaque = false
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor
    }

    static func backgroundLoader(
        render: @escaping @Sendable (WallpaperBackdropProvider.Request, URL) -> CGImage?
    ) -> ImageLoader {
        let worker = LatestWallpaperRenderWorker(render: render)
        return { request, sourceURL, completion in
            worker.submit(request, sourceURL: sourceURL, completion: completion)
        }
    }

    static func backgroundSourceInspector() -> SourceInspector {
        { url, completion in
            DispatchQueue.global(qos: .utility).async {
                let inspection = WallpaperSourceInspection.inspect(url)
                DispatchQueue.main.async { completion(inspection) }
            }
        }
    }

    public func attach(to host: NSView) {
        generation &+= 1 // Results belonging to the previous host are obsolete.
        sourceInspection = nil
        imageView.image = nil
        self.host = host
        imageView.removeFromSuperview()
        dimView.removeFromSuperview()
        imageView.frame = host.bounds
        dimView.frame = host.bounds
        imageView.autoresizingMask = [.width, .height]
        dimView.autoresizingMask = [.width, .height]
        // 插到所有现有 subview 之下。
        if let first = host.subviews.first {
            host.addSubview(imageView, positioned: .below, relativeTo: first)
            host.addSubview(dimView, positioned: .above, relativeTo: imageView)
        } else {
            host.addSubview(imageView)
            host.addSubview(dimView)
        }
        publish(.idle)
        publishDiagnostic()
    }

    public func layoutToHost() {
        guard let host else { return }
        imageView.frame = host.bounds
        dimView.frame = host.bounds
        // 再次确保在最底（防止中间 addSubview 打乱）。
        if let first = host.subviews.first, first !== imageView {
            host.addSubview(imageView, positioned: .below, relativeTo: first)
            host.addSubview(dimView, positioned: .above, relativeTo: imageView)
        }
    }

    public func refresh(for screen: NSScreen?, policy: LaunchcopyMaterialPolicy,
                        blurRadius: Double = LaunchcopyVisualTokens.wallpaperBlurRadius) {
        generation &+= 1 // Also invalidate work when wallpaper is disabled.
        sourceInspection = nil
        publishDiagnostic()
        let gen = generation
        layoutToHost()
        let fallback = LaunchcopyVisualTokens.fallbackBackdropColor()
        host?.wantsLayer = true
        host?.layer?.backgroundColor = fallback.cgColor

        dimView.layer?.backgroundColor = policy.prefersOpaqueChrome
            ? fallback.withAlphaComponent(0.92).cgColor
            : NSColor.black.withAlphaComponent(0.10).cgColor

        guard policy.allowsWallpaperBlur else {
            imageView.image = nil
            publish(.policyDisabled)
            print("paging-wallpaper: skipped (reduceTransparency)")
            fflush(stdout)
            return
        }

        let screen = screen ?? NSScreen.main
        let size = screen?.frame.size ?? host?.bounds.size ?? CGSize(width: 1470, height: 956)
        let scale = screen?.backingScaleFactor ?? 2
        let request = WallpaperBackdropProvider.Request(
            screenSize: size,
            backingScale: scale,
            blurRadius: blurRadius.isFinite ? min(60, max(0, blurRadius)) : LaunchcopyVisualTokens.wallpaperBlurRadius
        )
        print("paging-wallpaper: refresh begin size=\(Int(size.width))x\(Int(size.height)) scale=\(scale)")
        fflush(stdout)

        guard let sourceURL = sourceResolver(screen) else {
            imageView.image = nil
            publish(.sourceUnavailable)
            print("paging-wallpaper: source unavailable — using fallback")
            return
        }

        // Never read/decode files while startup is waiting to show its window.
        publish(.loading)
        sourceInspector?(sourceURL) { [weak self] inspection in
            guard let self, self.generation == gen, self.host != nil else { return }
            self.sourceInspection = inspection
            self.publishDiagnostic()
        }
        imageLoader(request, sourceURL) { [weak self] cg in
            guard let self, self.generation == gen, self.host != nil else { return }
            if let cg {
                let image = NSImage(cgImage: cg, size: size)
                self.imageView.image = image
                self.imageView.isHidden = false
                self.imageView.alphaValue = 1
                // 模糊就绪后再加很轻遮罩
                self.dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
                self.publish(.ready)
                print("paging-wallpaper: replaced with blur \(cg.width)x\(cg.height)")
            } else {
                self.publish(.renderFailed)
                print("paging-wallpaper: blur failed — retaining backdrop or fallback")
            }
            fflush(stdout)
        }
    }
}

/// At most one active render and one replaceable pending input per controller.
/// Obsolete active work may finish, but cannot fan out a full-resolution render queue.
@MainActor
private final class LatestWallpaperRenderWorker {
    private struct Work {
        let request: WallpaperBackdropProvider.Request
        let sourceURL: URL
        let completion: @MainActor (CGImage?) -> Void
    }
    private let render: @Sendable (WallpaperBackdropProvider.Request, URL) -> CGImage?
    private var active = false
    private var pending: Work?

    init(render: @escaping @Sendable (WallpaperBackdropProvider.Request, URL) -> CGImage?) {
        self.render = render
    }

    func submit(_ request: WallpaperBackdropProvider.Request, sourceURL: URL,
                completion: @escaping @MainActor (CGImage?) -> Void) {
        let work = Work(request: request, sourceURL: sourceURL, completion: completion)
        if active { pending = work }
        else { start(work) }
    }

    private func start(_ work: Work) {
        active = true
        let render = render
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let image = render(work.request, work.sourceURL)
            DispatchQueue.main.async { [self] in
                // Keep active true during reentrant completion; a new request replaces pending.
                work.completion(image)
                active = false
                if let next = pending {
                    pending = nil
                    start(next)
                }
            }
        }
    }
}
