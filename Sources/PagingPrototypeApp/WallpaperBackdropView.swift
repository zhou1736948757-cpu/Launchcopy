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
    private weak var host: NSView?
    private let imageView = PassThroughImageView(frame: .zero)
    private let dimView = PassThroughDimView(frame: .zero)
    private let provider = WallpaperBackdropProvider()
    private var generation = 0

    public init() {
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.isOpaque = false

        dimView.wantsLayer = true
        dimView.layer?.isOpaque = false
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor
    }

    public func attach(to host: NSView) {
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

    public func refresh(for screen: NSScreen?, policy: LaunchcopyMaterialPolicy) {
        layoutToHost()
        let fallback = LaunchcopyVisualTokens.fallbackBackdropColor()
        host?.wantsLayer = true
        host?.layer?.backgroundColor = fallback.cgColor

        dimView.layer?.backgroundColor = policy.prefersOpaqueChrome
            ? fallback.withAlphaComponent(0.92).cgColor
            : NSColor.black.withAlphaComponent(0.10).cgColor

        guard policy.allowsWallpaperBlur else {
            imageView.image = nil
            print("paging-wallpaper: skipped (reduceTransparency)")
            fflush(stdout)
            return
        }

        let screen = screen ?? NSScreen.main
        let size = screen?.frame.size ?? host?.bounds.size ?? CGSize(width: 1470, height: 956)
        let scale = screen?.backingScaleFactor ?? 2
        generation &+= 1
        let gen = generation
        let request = WallpaperBackdropProvider.Request(
            screenSize: size,
            backingScale: scale,
            blurRadius: LaunchcopyVisualTokens.wallpaperBlurRadius
        )
        print("paging-wallpaper: refresh begin size=\(Int(size.width))x\(Int(size.height)) scale=\(scale)")
        fflush(stdout)

        // 同步先铺未模糊桌面图，证明 ImageView 已在层级里（用户反馈「完全没引入壁纸」）。
        if let screen,
           let url = NSWorkspace.shared.desktopImageURL(for: screen),
           let raw = NSImage(contentsOf: url) {
            imageView.image = raw
            imageView.isHidden = false
            imageView.alphaValue = 1
            dimView.layer?.backgroundColor = NSColor.clear.cgColor // 先零遮罩，排除「太暗」误判
            print("paging-wallpaper: sync RAW desktop shown \(url.lastPathComponent) size=\(Int(raw.size.width))x\(Int(raw.size.height))")
            fflush(stdout)
        } else {
            print("paging-wallpaper: sync RAW desktop FAILED")
            fflush(stdout)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cg = self?.provider.blurredWallpaper(for: request)
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                if let cg {
                    let image = NSImage(cgImage: cg, size: size)
                    self.imageView.image = image
                    self.imageView.isHidden = false
                    self.imageView.alphaValue = 1
                    // 模糊就绪后再加很轻遮罩
                    self.dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
                    print("paging-wallpaper: replaced with blur \(cg.width)x\(cg.height)")
                } else {
                    print("paging-wallpaper: blur failed — keeping RAW desktop image")
                }
                fflush(stdout)
            }
        }
    }
}
