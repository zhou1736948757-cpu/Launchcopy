# PHASE1I Visual Reference Digest (Route B — wallpaper/material only)

- **Date**: 2026-09-11
- **Exposure**: REFERENCE_EXPOSED (whitelist in `PROVENANCE/PHASE1I_SOURCE_ACCESS.md`)
- **Rule**: Implement Launchcopy independently from this digest; do not line-translate LaunchBetter.

## Intent extracted (not code)

### Wallpaper pipeline

1. Resolve desktop wallpaper URL per target screen (`NSWorkspace.desktopImageURL`).
2. Decode efficiently (prefer thumbnail / max pixel ~512 for blur backgrounds).
3. Cover-crop to screen aspect; apply Gaussian-style blur.
4. Render at **reduced resolution** (LaunchBetter uses ~0.25×) because heavy blur hides detail → large CPU/GPU win.
5. Scale blur radius with the same factor so appearance matches full-res intent.
6. **Memory cache** keyed by pixel size + scale + blur + wallpaper source identity (path/mtime/size/id); **ignore window origin**.
7. **Disk cache** under Caches (regenerable); write **asynchronously** after UI already has the image.
8. **In-flight dedupe**: concurrent same-key renders wait on one computation.
9. Failure → solid color fallback (never crash).
10. Invalidate on screen/wallpaper change.

### Accessibility materials

- Reduce Transparency → opaque surface, **avoid blur**, higher surface opacity.
- Increase Contrast → emphasized boundaries + stronger foreground separation; do not globally boost shadows.
- Map policy → view layers in the product owner (Launchcopy), not in the policy type.

### PageVisual / Cache / Renderer

- LaunchBetter also caches **rasterized page grid** tiles (prev/current/next LRU).
- Launchcopy keeps **live AppKit cells** for Phase 1I; adopt only the **backdrop** lessons unless a later task explicitly adds page raster caching.
- Do not port LaunchBetter cell placeholder colors or typography as branding.

## Launchcopy mapping

| Concern | Launchcopy approach |
|---|---|
| Backdrop | New `WallpaperBackdropProvider` + view behind grid |
| Tokens | New `LaunchcopyVisualTokens` (light/dark, spacing, radii) |
| A11y | New policy struct mirroring semantic cases only |
| Icon | Original generated asset |
| Cells/settings | Restyle with tokens; keep hit-test/behavior contracts |

## Craft guide (non-LaunchBetter)

Emil Kowalski principles: restrained motion, ease-out, Reduce Motion, press feedback, no animation on high-frequency keyboard actions.
