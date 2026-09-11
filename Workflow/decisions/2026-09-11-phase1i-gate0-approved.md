# Phase 1I Gate 0 — APPROVED (pending wallpaper whitelist)

- **Date**: 2026-09-11
- **Prompt**: `Docs/PHASE1I_INDEPENDENT_VISUAL_SYSTEM_AND_PRODUCT_POLISH_PROMPT.md`
- **Prompt SHA-256**: `f3532e254a6ae33ebc46359da8c9ae9a42bab7b6975877e99a5bbc57fccf39f9`
- **User answers**: chat 2026-09-11 (Route amended A→B for wallpaper only)

## Approved decisions

| ID | Decision |
|---|---|
| **D1** | **Route B** — LaunchBetter as visual reference for **wallpaper/material pipeline only**; independently reimplement in Launchcopy. Buho reverse dirs remain forbidden. |
| **D2** | System-adaptive light / dark |
| **D3** | User wallpaper blur (LaunchBetter-inspired optimization), with Reduce Transparency opaque fallback |
| **D4** | Keep **5×7** capacity and paging semantics; scale icon/spacing within tokens only |
| **D5** | Generate original App icon (agent/tool); if blocked, deliver prompts to user |
| **D6** | Restrained, interruptible motion (Emil Kowalski craft criteria as taste guide, not asset source) |
| **D7** | Chinese + English product strings |
| **D8** | Shortcut recorder already in 1H — Phase 1I visual polish only, no major recorder redesign |

## Whitelist status

**Proposed** (filenames only so far — **contents not read until user confirms**):

### Production (recommended minimal)

1. `Packages/LaunchUI/Sources/LaunchUI/WallpaperProvider.swift`
2. `Packages/LaunchUI/Sources/LaunchUI/WallpaperDiskWriter.swift`
3. `Packages/LaunchUI/Sources/LaunchUI/PageVisual.swift`
4. `Packages/LaunchUI/Sources/LaunchUI/PageVisualCache.swift`
5. `Packages/LaunchUI/Sources/LaunchUI/PageVisualRenderer.swift`
6. `Packages/LaunchUI/Sources/LaunchUI/AccessibilityMaterialPolicy.swift`

### Tests (optional, contracts only)

7. `Packages/LaunchUI/Tests/LaunchUITests/WallpaperProviderTests.swift`
8. `Packages/LaunchUI/Tests/LaunchUITests/PageVisualCacheTests.swift`
9. `Packages/LaunchUI/Tests/LaunchUITests/PageVisualLifecycleTests.swift`
10. `Packages/LaunchUI/Tests/LaunchUITests/PageVisualRendererTests.swift`
11. `Packages/LaunchUI/Tests/LaunchUITests/AccessibilityMaterialPolicyTests.swift`

**Excluded**: `GestureCaptureEngine.swift` (name false-positive); all `buho-launchpad-reverse` / `evidence` paths; fonts/third-party unless separately listed.

## Implementation gate

Product source edits for Phase 1I **wait** until user confirms the whitelist (or a subset). After confirmation: read only listed paths → write `PHASE1I_VISUAL_REFERENCE_DIGEST.md` + provenance → implement independently.
