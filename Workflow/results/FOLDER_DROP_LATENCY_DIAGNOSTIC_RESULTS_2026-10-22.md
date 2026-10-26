# Folder drop latency: isolated diagnostic delivery

## Actual user result and scope
On the previous `3560657f` candidate, the user confirms the drag preview black backing is gone but still observes delayed folder placement. Close only the black-backing acceptance gate. The local image-continuity repair remains useful source evidence, not a complete explanation or physical fix for the perceived ~300ms delay.

This stage adds an opt-in diagnostic, not a new reorder algorithm. Default behavior, drag thresholds, layout semantics, persistence and paging physics are unchanged. Only a successfully resolved isolated test profile exposes the two diagnostic View-menu commands. No production preference, marker schema or backend change.

## Diagnostic design and boundaries
The probe correlates native window mouse-up entry, actual overlay release entry, five synchronous owner commit stages, handler return, a main-queue marker and the next eligible `viewWillDraw` notification. It retains at most eight samples in memory and reports only the last three, with relative durations, ordinals, icon counts and validity flags. It never reports absolute event times, application identities, paths, searches, coordinates or raw input streams; no disk/network/signpost output or global monitor is added.

Missing/invalid/backward clocks are unavailable or flagged, not clamped to successful zero. Each sample checks asynchronous observations in actual invocation order without requiring draw before next-turn or the reverse. Reset and eviction cannot attach old queued callbacks to new samples. Visual-only and torn-down overlays cannot report or own input.

`viewWillDraw` is a pre-draw notification, not compositor completion or scanout. A layer-only update may not invoke it. These clocks do not observe physical finger lift before a native event exists; short measured handler intervals alone cannot establish an OS cause. Do not infer a latency fix from test runtime.

## Implementation and independent review
Nine code/test delta files relative to the previous 554-input baseline:
- Sources/AppGridUI/FolderOverlayView.swift
- Sources/PagingPrototypeApp/AppDelegate.swift
- Sources/PagingPrototypeApp/LauncherWindowInput.swift
- Sources/PagingPrototypeApp/FolderDropLatencyProbe.swift (new)
- Sources/PagingPrototypeApp/FolderDropTimingPresentation.swift (new)
- Tests/PagingUITests/FolderAssignmentAssemblyTests.swift
- Tests/PagingUITests/FolderDropLatencyProbeTests.swift (new)
- Tests/PagingUITests/FolderDropTimingMenuTests.swift (new)
- Tests/AppGridUITests/FolderDropTimingHooksTests.swift (new)

Carson authored the bounded pure model and 31 tests; Main integrated native hooks, menus, owner composition and seven additional tests/repairs. Arendt independently found two P2 diagnostic/test issues (cross-async clock regression and fixed-yield waiting). Main repaired both, added regression coverage and bounded the native report to a read-only 300pt scrolling accessory. R2 is bounded `SOURCE_ACCEPT`, static only; no independent native, timing or full-product acceptance. Both agents are closed; Main alone ran serial verification and native actions. The older Chef workflow remains bypassed as authorized.

## Authoritative verification
- Focused: **74 tests, 0 failures**.
- Full rebuilt post-review suite: **3426 tests, 0 failures** (3388 baseline + 38 new).
- Debug build and actual Release/unique package: exit 0.
- Packaged localization: 365 keys/signatures in three languages verified.
- Frozen 559 source/test/package input hashes unchanged through native handover; exactly nine code/test delta files; `git diff --check` passed.
- The earlier 3423/0 run used the pre-review compiled test binary and is historical, not final-source certification.

## Exact candidate and data preservation
Unsigned, uninstalled isolated candidate:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-drop-probe-rc-20261022-r1/LaunchcopyUITest.app`

Executable SHA-256:
`a37036528e5fcf13133d6ad2a48a3568c5d573ab13cd17234cff318935dacae1`

Current PID at receipt: 25776. Earlier PIDs are historical. The old owned instance received normal Quit. An immediate old-app AX query inadvertently relaunched it once; a second normal Quit followed by exact process absence was verified before copying any data. No force termination/signals.

The fresh profile copies only 249 already-known authored fixture files, including the latest human-modified layout `79f5adf8f1e4d9773f54566b7d6e57080ce543562cfa9e27cedb89a9835ab752`, not the older `4302aa86` or original seed. All 248 other known files were unchanged. No preference/history/wallpaper-cache import or formal data change. All 249 destination hashes still match after native menu checks. Original candidates/profiles are retained.

## Native evidence and next actual action
Supported CUA opened the exact new candidate as an ordinary non-topmost window. Main enabled the isolated timing command, opened its native report and observed an accessible read-only scrolling report with **zero retained samples**, then closed the report. This proves the diagnostic entry/report is reachable and enabled, not native drag timing.

The app remains on the main page, query empty, Settings/report closed. Generated folder clicks and directional-key/Return attempts did not establish a changed custom view state; do not call this a product input failure or a successful drag. The previous generated native-slider positive control also failed to establish input admission. No further blind generated reorders are used. At the latest observation wallpaper was still loading; readiness and performance are not certified. Desktop 2 placement is unverified.

Next: once wallpaper is ready, the human opens the 35-item folder and performs two or three actual within-folder reorders, then reports completion. Main reads the numeric report through the native View menu and correlates measured boundaries before choosing a repair. Do not restart the process before collecting the in-memory samples. Do not change arbitrary dwell, animation or persistence parameters meanwhile.

## Retained limits
No reference project/raw reverse material, real app removal/launch, formal data, OS/backend/consent changes, signing/install/publish, Git mutation, process signals, saved screenshots/wallpaper pixels or private streams. Build/test jobs are terminal; no active subagents. Full original parity goal is incomplete. Real event timing and latency causality remain pending; optional outward Hide and other hardware/human/semantic gates remain separate. User-accepted first Library hitch stays nonblocking and is not re-investigated.

Evidence: `.build/verification/20261022/folder-drop-latency/` includes before files, pre-review/final source maps, focused/full/build/package logs, R1/R2 source reviews, fixture preservation manifest and `results-r2.json`. Contract: `Docs/FOLDER_DROP_LATENCY_DIAGNOSTIC_SPEC_2026-10-22.md`.
