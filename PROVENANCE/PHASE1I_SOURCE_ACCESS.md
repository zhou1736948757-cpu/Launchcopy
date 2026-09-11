# PHASE1I_SOURCE_ACCESS

- **Date**: 2026-09-11
- **Route**: B (wallpaper/material whitelist only)
- **Decision**: `Workflow/decisions/2026-09-11-phase1i-gate0-approved.md`
- **Exposure class for Workers reading these paths**: `REFERENCE_EXPOSED`

## Approved whitelist (opened)

### Production

| Path | Owner basis | Class |
|---|---|---|
| `/Users/mac/Projects/LaunchBetter/Packages/LaunchUI/Sources/LaunchUI/WallpaperProvider.swift` | User-owned LaunchBetter (user-stated) | USER_OWNED_LAUNCHBETTER_REFERENCE_REIMPLEMENTED |
| `.../WallpaperDiskWriter.swift` | same | same |
| `.../PageVisual.swift` | same | same |
| `.../PageVisualCache.swift` | same | same |
| `.../PageVisualRenderer.swift` | same | same |
| `.../AccessibilityMaterialPolicy.swift` | same | same |

### Tests (contracts)

| Path | Class |
|---|---|
| `.../Tests/LaunchUITests/WallpaperProviderTests.swift` | REFERENCE_EXPOSED |
| `.../PageVisualCacheTests.swift` | REFERENCE_EXPOSED |
| `.../PageVisualLifecycleTests.swift` | REFERENCE_EXPOSED |
| `.../PageVisualRendererTests.swift` | REFERENCE_EXPOSED |
| `.../AccessibilityMaterialPolicyTests.swift` | REFERENCE_EXPOSED |

## Additional reads (2026-09-11 wallpaper visibility fix)

User asked how LaunchBetter composites wallpaper. Opened (still no Buho):

| Path | Why |
|---|---|
| `Packages/LaunchUI/Sources/LaunchUI/LauncherWindow.swift` | `isOpaque=false` + `backgroundColor=.clear` |
| `Packages/LaunchUI/Sources/LaunchUI/LauncherWindowController.swift` | `backgroundLayer`/`dimLayer` CALayer hierarchy; `surface.layer.backgroundColor=nil` |

## Denied / not opened

- All Buho reverse / evidence directories under LaunchBetter
- `GestureCaptureEngine.swift` (filename false positive)
- Any LaunchBetter file outside whitelist + the two window files above

## Craft skills (not LaunchBetter)

- Emil Kowalski `emil-design-eng` used as taste criteria only (motion/polish), not asset transfer
