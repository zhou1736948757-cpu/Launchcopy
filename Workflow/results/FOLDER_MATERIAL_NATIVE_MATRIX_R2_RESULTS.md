# Folder Material Controlled Native Matrix R2 — Results

Date: 2026-10-16
Status: **12 BOUNDED COMPONENT-NATIVE CASES OBSERVED; NOT A FULL PRODUCT OR PERFORMANCE PASS**

## Scope and identity

Completed the previously open generated-background material check using the actual production `FolderOverlayView`, not a replacement material view. All 464 current canonical source-origin-r3 inputs were copied and verified; 463 copied inputs match exactly, and the sole manifest-listed difference is one copied `Package.swift` line adding `FolderMaterialProbe`. The additional probe entry matches the earlier compiled-only harness. No canonical implementation/test/resource change.

Copy: `.build/experiments/folder-material-native-matrix-20261016-r2/Package`.
Probe: sibling `FolderMaterialProbe.app`, unsigned/uninstalled Debug executable SHA-256 `bb2bb43383008a396ae2676b4935b546eeb6e1c9eaad7d8a73100e70ac6b7120`.
Actual build passed in 13.30 s (`.build/verification/20261016/folder-material-native-matrix-r2/build.log`). This is a build, not executed unit tests. The prior production 2809/0 result was not rerun.

Independent Hume source review found no blocking source/safety defect for this bounded experiment and verified the input isolation. Reviewer performed no builds/tests/UI and did not certify native results. Report: `Workflow/results/FOLDER_MATERIAL_NATIVE_MATRIX_R2_SOURCE_REVIEW.md`. Main alone owned build, packaging and CUA. Maximum concurrency Main + reviewer = two; reviewer closed and build terminal.

## Native observations

One ordinary non-topmost titled probe window, stable 1000×720 pt content / 2000×1504 px screenshot including titlebar, production panel with 15 generated blue/white icons and generated application names. No real catalog, app launch, wallpaper or captured screen background. Aqua/Dark Aqua are per-window overrides, not changes to OS settings. Reduce Transparency/Increase Contrast are explicit production-view policy inputs, not System Settings changes or notification integration.

| Cases | Requested appearance/background/flags | Observed |
| --- | --- | --- |
| 1–3 | Aqua × Bright, Dark, Busy; both flags OFF | Panel and all 15 icons/labels visible. Busy color edges and underlying text diffuse inside rounded panel; labels/icons stay sharp. Exterior checker/text stays sharp. |
| 4–6 | Dark Aqua × Busy, Bright, Dark; both flags OFF | Dark semantic material with light labels/title, no vanished content; busy colors diffuse within panel. |
| 7–9 | Dark Aqua / Busy; RT only, both flags, contrast only | Opaque dark panel hides busy detail; light labels/icons visible; contrast cases have stronger light border. |
| 10–12 | Aqua / Busy; contrast only, both flags, RT only | Opaque light panel hides busy detail; dark labels/title visible; contrast cases have stronger dark border. |
| Restoration | Aqua / Busy; both flags OFF again | Color-diffusing glass returns; icons and labels stay sharp. |

These are 12 distinct cases plus restoration, NOT all 24 selectable cross-product combinations. Fallback cases on uniform Bright/Dark backgrounds were not separately exercised. Stills/AX status are manual Main observations, not pixel-difference, numerical contrast, optical blur-strength or animation assertions. The status reports requested flags, not measured renderer internals. Host-wide accessibility state was not changed or independently inventoried; visible diffusion in busy glass cases establishes that a translucent path rendered under the current host conditions, not every host configuration.

Harness-only limitation: generated backdrop extends behind probe controls/status. Aqua/Dark and Dark Aqua/Bright have poor probe-chrome contrast; AX still identifies controls/flags. This strip is not production launcher chrome and is not evidence of a product-folder contrast defect. Folder content remains readable in the observed states. This experiment is not a usability design deliverable.

## Cleanup and preserved launcher

Clicked the probe's own observed `Quit Probe` control (normal `NSApp.terminate`). Read-only process check confirmed PID 86591/exact probe executable absent. Did not query the closed probe binding or relaunch it. Current launcher isolated candidate remains PID 82034, executable `bdb9a6e3…`, ordinary non-topmost window. Fresh launcher AX confirms folder open at page 1 of 3 with 15 members, original title and wallpaper ready. No existing app closed/replaced by this experiment.

Afterward, all 464 canonical hashes, 463 copied production inputs, authorized copied package/harness hashes, launcher executable and isolated layout/Library payload hashes match. No personal captured image files were saved; no formal data, source reference, OS setting, signing, install, deletion, kill or commit operation. Structured evidence: `.build/verification/20261016/folder-material-native-matrix-r2/native-results.json` (including exact per-case requests) and immutable build/package/input receipts.

## Honest remaining gates

This closes the bounded generated-background and policy-fallback component-native check, not actual OS preference notification delivery or the full 24-case cross-product. The static probe uses Reduce Motion and no launcher owner callbacks; it does not prove glyph-origin motion, retained-exit effects, first-frame/black-flash, gesture follow/settle/background isolation, lifecycle animations, real IME/spoken VoiceOver, physical 60/120 Hz, energy or whole-product parity. Human glass aesthetics were accepted earlier; new source-origin animation and physical gesture feedback still pending. Wallpaper-ready is transient runtime evidence, not a cause fix. User-reserved capacity/Library/history/destructive/OS experiment decisions remain reserved. Full objective unchanged/incomplete.
