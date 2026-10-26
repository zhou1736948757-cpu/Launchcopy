# Folder Source-Origin Motion — Delivery Results

Date: 2026-10-16
Status: **IMPLEMENTED / EXECUTION VERIFIED / PARTIAL NATIVE CONTROLS OBSERVED / HUMAN MOTION ACCEPTANCE PENDING**

## Approved scope and implementation

The user approved `Docs/FOLDER_SOURCE_ORIGIN_MOTION_SPEC.md`. This is an independent implementation in the existing SwiftPM/AppKit architecture; no reference source or assets were read/copied.

- Resolve the actual live folder glyph, not the entire cell. Reject stale, reused, hidden, detached and offscreen geometry; preserve the legacy whole-cell API.
- Uniformly fit the panel into that glyph and map its center using the actual Core Animation anchor. Animate only the existing panel/material/member subtree; the full modal root, background and title-editor host remain stable.
- Standard entrance 240 ms / exit 200 ms; existing Reduce Motion 180 ms opacity-only. Missing source uses the documented fade/synchronous-close fallbacks.
- Preserve presentation-layer reversal, generation-gated completion, inert retained exit and lifecycle cancellation.
- Suppress member click/drag/menu/page/scroll admission during entrance. Restore settled input; preserve ESC and outside close. A blocked press cannot launch after settlement.
- Preserve folder layout, frosted material, outer paging parameters, Timer tolerance, icon bindings and data contracts. No exterior blur, new animation timer or screenshot path.

## Changed implementation/test inputs

Five production files:
`Sources/AppGridUI/AppGridCellView.swift`, `FolderMotion.swift`, `FolderOverlayView.swift`; `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`, `AppDelegate.swift`.

Five test files:
`Tests/AppGridUITests/FolderIconGeometryTests.swift` (new), `FolderMotionTests.swift`; `Tests/PagingUITests/AppCatalogAssemblyTests.swift`, `AppDelegateBoundedRegressionTests.swift`, `IconTypographyOwnerTests.swift`.

Final manifest contains 464 inputs: 454 unchanged from the accepted-glass inventory, nine existing inputs changed and one new test. The broad dirty worktree is preserved and is not certified by this bounded stage.

## Verification and repair history

1. Actual RED: two tests / five failed assertions against old geometry/root ownership.
2. Focused compilation initially failed ambiguous floating-point test literals; explicit CGFloat types repaired tests.
3. Focused 72 tests / one failure exposed parent viewport clipping assumptions; explicit page/pageHost bounds intersections repaired the resolver. Rerun 72/0.
4. Initial full 2807/0 and package succeeded, but source review found P2 moving-panel input admission. That pre-repair r1 candidate (`365aaaa8…`) was retained and never handed over.
5. Actual input RED: one test / two failed assertions demonstrated activation and armed press. Added the owner-controlled transition admission gate; focused 74/0.
6. Full r2 executed 2809 tests with two failed assertions in one fixed-250 ms appearance-flush wait, following the new 240 ms entrance. Replaced that fixed sleep with the existing bounded condition wait (one-second timeout that explicitly fails), preserving initial deferral and exact eventual assertions. The new release-after-settle test likewise observes transition completion. No production change for this test adaptation.
7. Final focused **90/0, 6.104 s**; final full **2809/0, 54.003 s**. Debug build and actual Release/package passed. Packaged localization: 290 required keys/signatures × three languages. `git diff --check` passed.

Actual XCTest counts above are not the trailing zero-test Swift Testing runner. Raw logs: `.build/folder-source-origin-{focused-r5,full-r3,debug-r3,package-r2}.log`. Historical failures remain in their earlier logs.

Independent reviewer Franklin inspected source only: initial F1/P2 FAIL, repaired R2 source PASS and R3 bounded-wait test adaptation PASS. Reviewer executed no tests/build/UI; Main executed the recorded checks. Worker Ampere owned the glyph seam/resolver tests, Main integrated geometry/owner/input changes and serialized tests. All agents closed; no live verification jobs. Reports: `FOLDER_SOURCE_ICON_GEOMETRY_WORKER.md`, `FOLDER_SOURCE_ORIGIN_SOURCE_REVIEW.md` in this directory.

## Exact candidate and native handover

Candidate:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-source-origin-rc-20261016-r2/LaunchcopyUITest.app`

Executable SHA-256:
`bdb9a6e37882cb4257f45c7045c707b0d42843b85d51dc31f5cc8a598464350a`

Unsigned and uninstalled. Uses only its own isolated configuration and 40 Info-only fixture bundles, with 35 members in the dense folder; no fixture launch is claimed. Old own glass instance 55970 was normally quit; exact old process absence verified before new launch. Last read-only process check confirmed new PID 82034. No formal app or user data was modified.

CUA observations on this exact candidate:
- Ordinary non-topmost 2000 × 1400 px test window.
- Clicking the folder glyph opened 15 members/page 1 of 3.
- Settled Next button reached page 2/members 16–30.
- Outside click closed only the folder; launcher stayed open.
- Later reopen attempt returned Mac locked/physical input detected. **Final confirmed folder state: CLOSED.** Reopen success is not claimed.

Wallpaper diagnostic remained `loading`. This is the pre-existing intermittent backdrop issue, not a diagnosed motion regression or resolved cause. Do not claim the new run reproduced the old wallpaper-ready ambient glass appearance. No wallpaper/cache/permission/system-setting manipulation was used.

All 464 source hashes, executable and isolated layout/Library payload hashes were unchanged after handover. Structured receipts under `.build/verification/20261016/folder-source-origin/`: `source-inputs-r3.json`, `candidate-r2.json`, `native-handover-r2.json`. The native receipt supersedes packaging-time not-launched status without rewriting history. No personal screenshot files were saved.

## Remaining gates and next action

Human/native assessment of actual source-origin expansion/collapse, interruption continuity, flash and perceived fluidity remains pending. Geometry/actual-layer tests and settled screenshots do not establish frame-by-frame motion. Physical two-finger paging/background isolation, resize/multiple-source visual matrix, IME/VoiceOver, matched 60/120 Hz and energy/performance gates remain open. Known wallpaper intermittency and long-tail causality are not fixed by this change. The optional native material matrix harness remains compiled-only against its older baseline; no matrix PASS.

Next: user clicks the folder on the running isolated candidate and assesses whether it visibly grows from and returns to the glyph, without background movement. Preserve ordinary window mode and user control. No new installation, system-setting change or broad feature expansion is implied. The complete LaunchBetter-to-Launchcopy objective is not complete.

## Current native source-origin resize/editor checkpoint — 2026-10-16

New actual CUA observations on unchanged r2 / `bdb9a6e3…` / PID 82034: wallpaper is now ready (regular/local) and visible; the panel visibly diffuses ambient colors while exterior remains undimmed. This supersedes the earlier loading-only observation, NOT the unresolved intermittent cause. Folder opened at 15 members/page 1 of 3. Actual resize 2000×1400 ->1400×1000 px retained folder and reflowed to four members/page 1 of 9; Next reached members 05–08/page 2. ESC closed only folder and restored source focus; the resized source glyph reopened page 1. Restoring 2000×1400 retained the panel and restored 15/page 1 of 3. Title editing accepted a Latin draft; ESC restored original title without closing folder. Final: normal non-topmost window at original size, folder OPEN/page 1, original title, wallpaper ready, left for human assessment.

All 464 frozen inputs, candidate executable and isolated layout/Library hashes reverified unchanged. No new code/test/build, agent, system preference, formal data, install/sign/commit or saved personal screenshot. Previous goal turn PROGRESS (approved implementation/delivery); this turn PROGRESS (new native coverage changes remaining gates). No blocked audit count carried forward. This is basic native-control/material evidence, NOT real two-finger, three-finger window drag, first-frame source-origin/black-flash/continuity, IME/VoiceOver, physical performance or whole-parity acceptance. Native material multi-appearance matrix still not run; source-position tests are not a rendered multi-position matrix. Full objective remains incomplete. Receipt `.build/verification/20261016/folder-source-origin/native-controls-r2.json`; report `Workflow/results/FOLDER_SOURCE_ORIGIN_RESULTS.md`. Next: human actual opening/closing and physical gesture feedback on this exact running candidate; other explicitly reserved product decisions remain pending.


## User accepted folder experience; next-slice discovery — 2026-10-17

User replied “没问题，继续做吧” to the explicit request to assess source-origin expansion/collapse and real two-finger folder navigation. Record acceptance of the reported folder experience (opening/closing and folder-local paging) on the handed-over isolated r2 candidate, not a new matched performance benchmark, instrumented physical trace, universal flash guarantee, IME/VoiceOver/120Hz or wallpaper cause fix. Current source manifest464 and executable bdb9a6e3 verified unchanged; PID82034 remains running. This new human evidence supersedes the previous pending human gate and authorizes continuation; do not carry forward earlier blocked counts. Full objective remains unchanged and incomplete.

Next discovery: the explicitly pending main-grid row/column configuration contract, preserving existing5×7 default, independent adaptive folder layout and paging physics. No implementation or numeric-range approval inferred from the general continuation. Main prepares a concrete English bounded specification after code discovery, then requests confirmation of the new contract. No reference project/assets/OSpreferences/formal data/installation/commit or live UI action.

