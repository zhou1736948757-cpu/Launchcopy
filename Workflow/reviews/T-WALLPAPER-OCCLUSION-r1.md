# T-WALLPAPER-OCCLUSION — Reviewer r1

- Role: Independent Reviewer → Main
- Verdict: **PASS** (patch-level; broader integration gate remains pending)
- Date: 2026-09-11
- Reviewed against: `Workflow/tasks/T-WALLPAPER-OCCLUSION.md`, `Workflow/results/T-WALLPAPER-OCCLUSION.md`, `HEAD 6382bd911741831d13360e402c270bb6509b3679`, and the stored before snapshot.
- Method: Read-only independent review of source, test, logs, hashes, and synthetic PNGs. No SwiftPM build/test was run by this Reviewer. No implementation source or test file was edited.

## Summary

The scoped fix is minimal and addresses the demonstrated occlusion mechanism: `PageHostView` keeps the original neutral laboratory background when `customRenderer == nil`, but removes the host layer fill when a custom renderer is active. The fail-before and pass-after pixel evidence is consistent with that change, and the resize/reuse, neutral-renderer, seam, and production assembly evidence is present.

No reviewed source diff changes paging input, `PagingCore`, `PagingSurface`, `AppDelegate`, wallpaper provider/view code, packaging, or the target-binding contract. The broader Main-owned full-suite result is not green yet, but its reported failures are in unrelated click/drag/preview areas and baseline comparison is still pending; this Reviewer does not count that result as a patch failure.

## Findings

### BLOCKER

None.

### MAJOR

None.

### MINOR

None.

### QUESTION / BOUNDARY

- The new pixel test uses a minimal non-`NSView` binding renderer rather than instantiating `AppGridRenderer` in the pixel fixture. This is not a blocker: the production renderer is independently confirmed to be non-`NSView`, implements `PagingPageRenderingTargetBinding`, and is exercised by the targeted `AppCatalogAssemblyTests` run.
- Main's full-suite integration gate remains **PENDING BASELINE COMPARISON**. Main reported 1,525 tests with 12 failed assertions across 7 tests in `full-suite-authorized.log`; Release build and candidate smoke both exit 0 under Main ownership. No claim of full-suite green or GUI acceptance is made here.
- Real packaged-app wallpaper visibility, live GUI behavior, and physical user acceptance remain outside this patch-level verdict.

## Acceptance verification

| Criterion | Result | Evidence |
|---|---|---|
| Synthetic fail-before/pass-after repro | PASS | `fail-before.log` reports 1 executed test with 4 failures and center pixel `(23, 23, 23, 255)`; `pass-after.log` reports 3/3 passed and center pixel `(251, 0, 7, 255)`. The before PNG shows the host interior occluding the red backdrop; the after PNG shows the saturated red backdrop through the host. |
| Small transparent-host fix | PASS | `Sources/PagingUI/PageHostView.swift:35-38,46-52,65-68,116-117` centralizes renderer-dependent host appearance. Custom-renderer hosts get `backgroundColor = nil`; the nil renderer keeps `controlBackgroundColor`. Existing border width/color, corner radius, render state, reuse generation, and layout paths remain unchanged. |
| Production non-`NSView` target binding | PASS | `Sources/PagingUI/PageHostView.swift:78` still assigns `renderTarget = self` through `PagingPageRenderingTargetBinding`. Production `AppGridRenderer` is a non-`NSView` class at `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:144`, stores the weak target at `:147`, and renders into that target at `:208-246`. The targeted log reports `AppCatalogAssemblyTests` 6/6 passed. |
| Resize/reuse/custom-renderer behavior | PASS | `Tests/PagingUITests/PageHostBackdropTests.swift:69-99` checks renderer frame sizing, `clearForReuse`, generation bump, renderer detachment, re-render, reattachment, resize, and red-pixel visibility. The targeted log reports `PagingSeamTests` 15/15 passed. |
| Neutral behavior | PASS | `Tests/PagingUITests/PageHostBackdropTests.swift:101-118` verifies neutral content still renders, retains a non-nil host background, border width `1`, and corner radius `12`. |
| Input/core and unrelated source boundary | PASS | The actual diff is 13 insertions/2 deletions in `PageHostView.swift`; the only source/test paths in scope are that file and the new test. Static diff checks show no changes to `Package.swift`, `Sources/PagingCore`, `Sources/PagingUI/PagingSurface.swift`, `Sources/PagingPrototypeApp/AppDelegate.swift`, `WallpaperBackdropProvider.swift`, or `WallpaperBackdropView.swift`. |
| Synthetic/privacy boundary | PASS | The new test creates the saturated red `NSColor` in memory and writes only an explicitly requested synthetic PNG. It contains no desktop-wallpaper or display lookup, and the reviewed evidence does not establish or claim real wallpaper pixels. |

## Baseline and diff checks

- `Workflow/artifacts/T-WALLPAPER-OCCLUSION/PageHostView.before.swift` matches `HEAD 6382bd9` byte-for-byte; verified SHA-256 is `acee7c804ce7ce71325c902f1316736be2766ff92b8a357770b1758029a9a83d`.
- Current `Sources/PagingUI/PageHostView.swift` SHA-256 is `b552714856e3d1ebb3a22691580136f479e0ed8531436308e0d8a9724a84bcef`.
- The reviewed source diff is confined to the renderer-dependent appearance policy; the existing binding line and all input/reuse contract code outside that policy remain intact.
- Artifact hashes recorded in the Worker result match the files on disk for the before/after PNGs and logs.

## Evidence boundaries

- The synthetic regression proves the page-host compositing behavior, not the packaged application's real wallpaper path.
- No real wallpaper path or pixels were used for this review, and no running GUI process was modified, relaunched, activated, or terminated by the Reviewer.
- The Reviewer did not run SwiftPM, build, full-suite, packaging, signing, or installation commands; those remain Main-owned gates.
- This is a patch-level **PASS**, not a claim that the full suite is green. Main must complete the baseline comparison before treating the broader integration gate as resolved.

## Dated integration evidence — 2026-09-11

- Baseline `HEAD 6382bd9` is recorded in `Workflow/artifacts/T-WALLPAPER-OCCLUSION/baseline-full-suite.log` as 1,522 tests with 12 failed assertions across the same seven named tests reported by the patched `full-suite-authorized.log` run (1,525 tests, 12 failed assertions). The existing failure set is unchanged; the patched run's three additional tests passed. The global suite is therefore **not green**.
- This comparison does not add a patch failure signal: the patch-specific `PageHostBackdropTests` remain 3/3 passed, and the scoped verdict remains **PASS**.
- Main's candidate was confirmed as PID `5663` at the exact candidate path. Repeated CUA connection attempts timed out even though a one-second sample showed the app main thread in a normal run loop. The real-wallpaper GUI gate remains **UNVERIFIED**; no live wallpaper visibility or packaged-app GUI acceptance is claimed.
