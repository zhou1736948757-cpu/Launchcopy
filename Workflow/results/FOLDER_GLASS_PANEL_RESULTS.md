# Folder Glass Panel Results — 2026-10-16

## Delivery and scope
Implemented the approved native panel-glass slice. The existing stable NSView panel retains editor/content identity; a single clipped pass-through NSVisualEffectView is its bottom child. Public withinWindow/popover material samples this application's content; foreground members and labels are not descendants of the blur. Normal panel-host fill is clear. Reduce Transparency or Increase Contrast hides the material and uses an opaque semantic fill with existing contrast contour. Exterior remains clear: no folder scrim, screenshot/filter/timer, wallpaper pipeline, geometry, engine, physics, canonical-data or owner-input changes.

User prefers panel + exterior blur but prioritizes performance and permits dropping exterior blur if costly. Exterior is NOT implemented or empirically rejected in this delivery: its bounded own-content snapshot feasibility, source fidelity, transition coherence and matched runtime cost remain separate required work. Panel-only is the authorized fallback, not a redefinition of the overall product goal.

## Tests and source review
- New hierarchy regression actually failed before implementation:1 test/2 assertion failures.
- First focused41/0.
- First full2793/6 assertion failures, all in AdaptiveFolderOwnerTests' old generic foreground non-overlap classifier including the new decorative full-panel effect. Corrected this classifier by positively asserting bottommost/full-panel/pass-through material, then excluding only the decoration; original visible-chrome containment, pairwise non-overlap and Close-folder assertions retained.
- Independent Zeno SOURCE FAIL F1: explicit no-active-detached-effect lifecycle contract. This was not a measured GPU leak/performance finding.
- Added a real NSWindow attach/detach/retained-exit/reuse/fallback/collapse/terminal-reattach regression; executed RED1 test/21 assertion failures. Fixed attachment-aware material state with existing policy/collapse/terminal gates. Mounted transparent drawing-only exits keep glass; detached, opaque, collapsed and torn-down effects remain inactive. Same panel/material/editor identity retained.
- Final focused48 tests/0 failures,2.703s.
- Final full2794 tests/0 failures,76.535s (XCTest actual suite, not trailing empty Swift Testing run).
- Explicit Debug product build passed; actual Release build/package passed; packaged-only localization probe verified290 keys/signatures in3 languages. Existing unrelated warnings are not represented as zero warnings.
- git diff --check passed.
- Zeno re-review SOURCE PASS closesF1; original FAIL and final hashes retained in FOLDER_GLASS_PANEL_SOURCE_REVIEW.md. Reviewer performed zero build/test/UI executions and notes owner animation-path execution coverage limits; not a runtime/physical PASS.

## Changed source/test inputs
463-input freeze has459 unchanged versus the clear-backdrop baseline,4 changed:
1. Sources/AppGridUI/FolderOverlayView.swift
2. Tests/AppGridUITests/FolderMaterialPolicyTests.swift
3. Tests/PagingUITests/FolderRenameAssemblyTests.swift
4. Tests/PagingUITests/AdaptiveFolderOwnerTests.swift

Authoritative freeze: .build/verification/20261016/folder-glass-panel/source-inputs-r2.json (supersedes early source-inputs-final.json). All463 hashes reverified after packaging. AppDelegate startup-order input routing, PagingCore, PagingUI and physics unchanged. Existing broad dirty worktree preserved, no commit/reset/clean.

## Candidate
Unsigned/uninstalled isolated ordinary non-topmost candidate:
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-glass-panel-rc-20261016-r1/LaunchcopyUITest.app
Executable SHA256:05c415a05303a0d7401581b670f13f7b67bf63167e041920edb55d174f7c14c4

Candidate-local profile copied only40 Info-only fake app bundles,35-member folder layout and Library preferences from our previous isolated fixture; no executable apps, formal data or wallpaper cache copied. Layout/library payload hashes match. No installation, signing, reference project/resource access, system-setting changes or process kills.

## Native evidence and honest boundary
Before handover, CUA inspected the actual old clear-backdrop candidate87504: ordinary2000x1400px launcher; folder click opened15-member page1/3; panel still opaque dark, no folder-induced exterior dim. These are BASELINE observations, not new glass evidence; images viewed inline only, no saved personal-wallpaper screenshot files.

After the new package passed, CUA returned Mac locked on the first fresh old-app state check. No old normal Quit, new candidate launch or visual/performance acceptance occurred. Exact old candidate process remains87504; new candidate NOT RUNNING. Asked once for manual unlock; do not bypass lock or terminate old process. Candidate/hash/profile/source inputs verified. All build/test sessions terminal and reviewer closed.

Native glass tint/clipping/legibility on controlled light/dark/busy backgrounds, first-frame/reversal behavior and real gestures/performance remain unverified.2794-green is not a physical acceptance. Existing >25ms tail causality, wallpaper intermittency, IME/VoiceOver,60/120Hz and broader product acceptance remain unresolved.

## Next executable actions
On manual unlock, normally Quit only old isolated test via CUA, verify absence, launch exact new candidate and inspect glass/resize/page controls/title cancel/outside dismissal. Then run matched performance/visual checks and continue exterior feasibility without changing physics or accepting an opening stall. If new material is too opaque or dark in native rendering, calibrate semantic material from actual evidence rather than passing source-only glass as appearance acceptance. Full migration objective stays incomplete and is not marked achieved/blocked by this first lock.

Receipts/raw logs/review copy: .build/verification/20261016/folder-glass-panel/final-receipt.json and sibling files.

## Superseding native handover — 2026-10-16
Userunlock allowed normalQuitold87504/exactabsence, then exactnewcandidate05c415a0 launch55970. Actualnative still: rounded panel reveals diffused wallpaper/grid ambient color rather than flatblack, foregroundtitle/labels remainsharp, exteriornotnewlydimmed. Pagebutton1->2 confirmed15members16–30, unchangedouterentries. Thirdpageattempt timedout; freshAXMaclocked, resultunknown. NewcandidateleftRUNNING, oldnotrunning. No source/build/testchange;463/candidate/layout+Librarypayload hashes unchanged. No persistedcaptureimage. Nativeappearanceobservation is partial, notuseracceptance, controlledmaterialmatrix, firstframe/flash orphysicalgesture/performancePASS. Titlecancel/resize/outside-dismissal and remainingphysicalgates pending. Fullstructured native-handover.json retained alongside earlierhistoricalfinalreceipt; do not continueto report NOTLAUNCHED. EarliergoalBLOCKED toolstatus persists, no newblocked/completion decision, freshauditresetbyconcreteprogress.

## Native controls completion (bounded) — 2026-10-16
New native observations close page3, title draft/cancel, nativewindowresize/materialboundsrestore, outsideclose and reuse appearance checks on exact05c415a0 candidate55970. Desktop accessible, folder leftpage1/3 withrestored2000x1400pxwindow. Canonical463/candidate/layout+Libraryhashes unchanged, no source/test/buildchange. Detailed FOLDER_GLASS_PANEL_NATIVE_RESULTS.md/native-controls.json supersedes previous third-page unknown and pending these named controls, but doesnotaccept human gestures, firstframe/flash, controlled materialmatrix or matchedperf/wholemigration.
