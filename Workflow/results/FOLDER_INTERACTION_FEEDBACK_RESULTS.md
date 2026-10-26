# Folder Interaction Feedback — Repair Results

Date: 2026-10-16
Status: CODE_AND_PACKAGE_VERIFIED; NATIVE_AND_HUMAN_ACCEPTANCE_PENDING

## User feedback and contract
The user accepts adaptive folder layout/proportions, clarified this is an ordinary windowed test, and approved continuous folder-local two-finger paging in Docs/FOLDER_TRACKPAD_PAGING_SPEC.md. The folder is an in-window panel, not a separately resizable window. Drag the application window border to test responsive sizing. Existing outer physics/5x7 capacity, Timer0ms, canonical member order and storage schema remain unchanged.

## Changes
- Window routes every scroll to the open folder, including rejected input; it cannot fall through to the background pager. Native titled-window title-bar and four-point resize-edge input is delegated to AppKit, not launcher blank-close classification.
- Folder-local FolderPagingController uses unchanged PagingCore and ScrollInputMapper, including direction, damping, settling and delayed release semantics. Clock is demand-driven (60Hz/0ms, common mode), stopped at idle/cancel/teardown; tracking without animation does not need a timer.
- Folder member presentation has a clipped viewport and at most three drawing-only live page hosts following the continuous visual offset. Title/panel/footer/backdrop remain fixed. Geometry and names are frozen once at the input boundary; unchanged hosts are translated, not rebound each frame. Hidden originals and visual-only AX hosts prevent duplicate interactive members. Generation/weak binding gates reject late images.
- Keyboard/page controls, title editing, application drag/move-out, resize, screen change, hide/unmount/teardown, unavailable geometry and content changes cancel safely. Return/Enter cancellation covers both keyDown and performKeyEquivalent before activation. Locale/appearance updates wait for safe inner idle.
- Pointer entrance is transparent with final geometry before mount; model-layer writes disable implicit actions while explicit entrance animation remains enabled. Interrupted reversal and Reduce Motion behavior are preserved. This removes a source-ordering flash risk; no causal human flash-fix claim yet.

## Regression evidence
1. Initial two owner/window regressions actually executed RED: 2 tests/2 failures (.build/folder-feedback-red.log). Native titlebar was passed into search-exit classification; mount observed opacity1 before entrance.
2. First focused run86/1: generated CGScrollPhase and NSEvent.Phase raw enum mismatch, not a product finding. Helper now explicitly maps SDK enums and asserts the resulting phase. Focused rerun86/0; first full2786/0,59.142s.
3. Independent Linnaeus source review identified two P2 issues: fixed committed-page host window could omit farther visible pages on long drag; performKeyEquivalent could activate old members without cancelling. New two-test regression actually executed RED with5 failed assertions (.build/folder-feedback-review-red.log). Both repaired; focused88/0 (.build/folder-feedback-focused-r3.log). Final full suite and post-repair package pending at this checkpoint.
4. Driver worker Hooke supplied controller and30test cases, did not execute SPM; Main owns all actual test/build execution. Planck supplied read-only entrance audit, no source changes. All use inherited model. Old mandatory Chief workflow waived by user.

## Evidence boundary and delivery
Source/input freeze r2:463 inputs. Relative to prior460-input baseline,455 unchanged,5 changed existing files,3 new source/test files. No modification to PagingCore, ScrollInputMapper, PagingSurface, PagingFrameDriver, Package.swift, build scripts, resources or reference sources. Broad pre-existing dirty tree preserved.

Unsigned candidate r1 is retained but superseded by review fixes; do not use it for final acceptance. Native automation returned Mac locked when trying to inspect the old adaptive-folder r2 test instance; no interaction, normal Quit or new candidate launch succeeded. No real trackpad, three-finger window drag, resize-border or flash-frame acceptance claimed. Existing old test app may still be running. No install/sign/publish/commit/reset/clean/process kill/formal-data edits/OS-setting changes. Wallpaper intermittency and previous long-tail causality remain unresolved and unrelated.

## Next action
Complete final full suite, Debug/Release/package and bounded source re-review; write final candidate/hash. Once Mac is manually unlocked, normally Quit only the old isolated test instance, launch the new isolated ordinary window and perform native smoke checks. User physical gate: two-finger finger-following/settling without background movement, native window drag without dismissal, opening/closing with no transient black flash. Fake fixture apps cannot launch; outer single-page fixture cannot establish outer paging performance.

## Final verification (supersedes pending post-review entries above)
- Main actual full suite:2788tests/0failures,52.073s; .build/folder-feedback-full-r2.log (archived in verification directory).
- Actual Debug build and Release package exit0; packaged localization probe290keys/signatures across3languages. git diff --check passed.
- Linnaeus re-review appended to original report: original2P2 closed, no newP1/P2 in bounded source scope; reviewer ran0tests/builds/UI.
-463 final input hashes all match source-inputs-r2.json.455 previous inputs unchanged;5changed existing files+3newfiles. Final8 source/test files copied into verification/final-source for recovery.
- Final candidate: /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-interaction-rc-20261016-r2/LaunchcopyUITest.app
- Executable SHA256:b9446444a9b3e807db9e66f36150ff3d855e0ef2e733d96af1b0b123fc731c9b
- Old candidate-r1 retained but superseded; no install/signing/overwrite. Final candidate has40authored Info-only fake apps,35-member folder and exact copied layout/library bytes. Did not copy wallpaper cache, lock files or formal user data/preferences.
- Mac locked prevents native handover; latest candidate has never been launched, old isolated adaptive candidate was last observed running. All agents closed. Real trackpad/motion, native titlebar/resize and human flash acceptance remain pending, not automated PASS.

## Changed source/test files (this stage only)
- Sources/PagingUI/FolderPagingController.swift (new)
- Sources/AppGridUI/FolderOverlayView.swift
- Sources/PagingPrototypeApp/AppDelegate.swift
- Sources/PagingPrototypeApp/KeyboardFocusController.swift
- Tests/PagingUITests/FolderPagingControllerTests.swift (new)
- Tests/AppGridUITests/FolderTrackpadPresentationTests.swift (new)
- Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift
- Tests/PagingUITests/BlankClickToQuitTests.swift

## Native handover after unlock — 2026-10-16
The user manually unlocked the Mac. Main normally Quit the old isolated adaptive-folder test app through its observed application menu, verified exact old process absent, then launched exact folder-interaction r2 (PID23375/SHA b9446444...). No post-Quit old-app query. New ordinary non-topmost window loaded40fakeapps/35-memberfolder; wallpaper ready was transient observed status, not causal wallpaper-fix evidence.

Actual CUA native titlebar drag did not dismiss the window/folder. Actual border resize changed2000x1400pixels ->1400x1000pixels,15members/3pages ->4members/9pages; restoring original size returned15members/3pages. Next-page button showed16-30; previous restored01-15. Folder remains open onpage1 atoriginalsize for human testing. Three-finger gesture itself and flicker/smoothness were NOT verified. CUA horizontal scroll attempts showed no committed page transition; this is not physical gesture evidence and does not establish either PASS or a new product defect. Source463/candidatehash and fixture layout/library bytes reverified unchanged. No source/test/build changes or suite rerun in this handover. Native structured receipt .build/verification/20261016/folder-interaction/native-handover.json supersedes earlier not-launched/locked handover status; original receipts retained as history. No personal-wallpaper screenshot files saved.
