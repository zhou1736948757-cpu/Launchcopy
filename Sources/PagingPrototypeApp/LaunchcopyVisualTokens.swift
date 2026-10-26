//
//  LaunchcopyVisualTokens.swift
//  PagingPrototypeApp
//
//  Phase 1I: Launchcopy visual tokens (NEW_ORIGINAL). Light/dark adaptive.
//  Motions stay restrained; paging physics remain frozen elsewhere.
//

import AppKit
import Foundation

/// Accessibility-facing surface policy (intent from digest; independent types).
public struct LaunchcopyMaterialPolicy: Equatable, Sendable {
    public var reduceTransparency: Bool
    public var increaseContrast: Bool
    public var reduceMotion: Bool

    public init(
        reduceTransparency: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
        increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
        reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    ) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.reduceMotion = reduceMotion
    }

    public var allowsWallpaperBlur: Bool { !reduceTransparency }
    public var prefersOpaqueChrome: Bool { reduceTransparency }
    public var emphasizesBorders: Bool { increaseContrast }
}

/// Color / spacing tokens for Launchcopy chrome (not cell paging physics).
public enum LaunchcopyVisualTokens {
    public static let gridCornerRadius: CGFloat = 14
    public static let chromeCornerRadius: CGFloat = 8
    public static let settingsButtonSize: CGFloat = 36
    public static let settingsButtonInset: CGFloat = 18
    /// Wallpaper blur radius at full logical scale (provider may downscale render).
    /// 略降：过糊 + 压暗会被看成纯黑（用户实机反馈）。
    public static let wallpaperBlurRadius = Double(AppearancePreferences.defaultBlurRadius)
    /// Downscale factor for blur renders (digest: heavy blur hides detail).
    public static let wallpaperRenderScaleFactor: CGFloat = 0.35

    public static func fallbackBackdropColor(appearance: NSAppearance = NSApp.effectiveAppearance) -> NSColor {
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark ? NSColor(calibratedWhite: 0.06, alpha: 1) : NSColor(calibratedWhite: 0.92, alpha: 1)
    }

    public static func chromeFill(policy: LaunchcopyMaterialPolicy) -> NSColor {
        if policy.prefersOpaqueChrome {
            // Fully opaque dark chrome keeps the existing white symbol legible.
            return NSColor(calibratedWhite: 0.12, alpha: 1)
        }
        return NSColor.black.withAlphaComponent(0.32)
    }

    public static func focusRingColor(policy: LaunchcopyMaterialPolicy) -> NSColor {
        policy.emphasizesBorders ? .controlAccentColor : NSColor.controlAccentColor.withAlphaComponent(0.85)
    }
}
