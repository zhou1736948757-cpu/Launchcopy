# Phase 1J Layout and Folder Motion Slice

Status: PLANNING_GATE
Date: 2026-09-12

## Objective and Scope

Implement the user-approved `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md`: stable vertically centered grid geometry and restrained origin-aware Folder motion. Preserve five columns/seven rows, paging physics, `Timer.tolerance = 0ms`, persistence, hit regions, wallpaper transparency, and all release boundaries.

## Baseline and Confirmed Facts

- The checkout is dirty and contains prior Phase 1J work. Existing changes are user-owned and must be preserved.
- The handoff records 1530 executed tests with zero failures and candidate `.build/candidates/phase1j-rc-20260911/Launchcopy.app`; this slice has not yet rerun that evidence.
- The user accepted the idle black-frame repair. The macOS Dock is not an application defect and is outside this slice.
- `AppGridPageView` is top-anchored with five columns, 88pt cells, 16pt spacing, 24pt inset, and 96pt top reserve.
- `FolderOverlayView.MotionParams` exists but is not wired into open/close. AppDelegate currently removes the interactive overlay synchronously on close.

## Decisions and Rationale

- User confirmed the draft plan on 2026-09-12.
- Ordinary pages will preserve a shared seven-row envelope; search may center occupied rows through explicit state. This avoids page-to-page vertical jumps.
- Pointer Folder transitions may animate for spatial continuity; keyboard transitions remain immediate. Reduce Motion is opacity-only.
- Logical close and interaction cleanup remain immediate. Any retained exit visual must be noninteractive and generation-gated to avoid reviving the historical click-occlusion defect.
- Chief planning is serial before implementation because geometry/motion interfaces and AppDelegate integration are tightly coupled.

## Workflow Configuration

- Main: `gpt-5.6-sol`, medium.
- Chief: `gpt-6-astra`, medium.
- Worker: `gpt-6-astra`, low.
- Reviewer: `gpt-5.6-luna`, high.
- Maximum Worker concurrency: 3. Current effective planning concurrency: one Chief; zero Workers; zero Reviewers.
- These are declared identities, not proof of upstream provider routing.

## Changed Files

- `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md` (approved proposal)
- `Workflow/config.json` and `MEMORY.md` (user-authorized role reconfiguration)
- This stage summary

## Verification and Review

- Configuration JSON parsed successfully.
- Product implementation, focused tests, full suite, builds, packaging, GUI motion, and Reviewer verdict: NOT RUN.

## Risks and Gates

- Chief must approve the exact geometry input ownership and close-animation lifecycle before Worker dispatch.
- Worker waves require disjoint write scopes and serialized SwiftPM builds.
- Independent Reviewer PASS is required before task closure.
- Current A-D manual gates remain unchanged; this slice cannot promote `LOCAL_RC_VALIDATED` by itself.

## Next Executable Action

Dispatch the configured Chief to review the approved plan and current code, then produce a decision artifact and bounded task packets without editing product code.

## Superseding Verification Update — 2026-09-13

### Objective and scope

The implementation and verification slice is now recorded for the current
dirty checkout. Scope includes the stable grid layout, B1 top-level click
routing, Folder pointer motion and interruption cleanup, serialized tests,
Debug/Release builds, and a fresh unsigned candidate. Distribution and live
GUI acceptance remain outside the evidence already obtained.

### Confirmed facts and decisions

- The current `HEAD` is
  `6382bd911741831d13360e402c270bb6509b3679`; existing dirty work was
  preserved.
- The historical 1530/0 baseline increased to 1549/1549 because Phase 1J
  tests were added. The full current suite exited 0 with no failures.
- The retained real Folder overlay is used as a visual-only exit visual because
  bitmap cache capture does not preserve a live presentation transform. While
  frozen it is noninteractive and generation-gated; cleanup now restores
  move-out state directly before reuse or teardown.
- Reduce Motion remains opacity-only with identity transform. No claim is made
  about timing feel or pixel fidelity without a live current-candidate run.

### Changed files and evidence

The product/test changes are already present in the dirty tree. This update
adds only `Workflow/results/T-1J-LM-VERIFY.md` and this dated summary section.
Fresh evidence recorded there is:

- `rtk swift test`: 1549/1549, 0 failures, completed 2026-09-13
  05:56:16.471.
- Debug target build: PASS.
- Release product build: PASS, 21.34s.
- `rtk git diff --check`: PASS.
- Candidate:
  `.build/candidates/phase1j-rc-20260913-055944-42580/Launchcopy.app`.
- Candidate executable SHA-256:
  `23733d4cf96cbbeaffac5fa51d9d45da8db6018fd71a94de8a8f58d80a6fdf1c`.
- Package-time `git_head` is
  `6382bd911741831d13360e402c270bb6509b3679`; package-time dirty count is
  `65`.

### Reviewer verdict

The formal read-only Terra Reviewer task completed at the task-status layer,
but its original and same-session re-send turns exposed no readable assistant
message (`latestAssistantMessageId=null`, empty turn items). The earlier audit
found no reproducible production click defect, but did not cover the exact
mounted hierarchy plus recognizer action or AppDelegate hide/resize during
active Folder transitions. No Reviewer PASS is claimed.

### Unresolved risks and gates

- Current-candidate GUI and physical input remain blocked while the Mac is
  locked, with the exact automation error recorded in the verification result.
- Real icon launch, visual page/search placement, Folder open/close/reversal,
  Escape, drag, Reduce Motion, hide, resize, and teardown behavior remain
  manual/runtime gates.
- `LOCAL_RC_VALIDATED` remains prohibited; the stage label is
  `RC_IMPLEMENTED_MANUAL_PENDING`.
- The pre-existing Sendable warning at
  `Sources/PagingPrototypeApp/AppDelegate.swift:1463` remains.

### Next executable action

Recover and record the formal Terra Reviewer verdict. Once the user manually
unlocks the Mac, run the current-candidate GUI matrix. Keep all GUI/physical
claims separate from static, test, build, and package evidence.

## Superseding Verification Update - 2026-09-13 07:13 local

### Objective and scope

The current Phase 1J implementation was rechecked after the read-only Terra
audit. Scope remains stable grid geometry, B1 top-level click delivery, Folder
pointer entrance/exit/interruption cleanup, lifecycle cancellation, and
serialized release-candidate verification. No distribution or live GUI claim
is made.

### Terra findings and disposition

Terra audit task `01a097cd-ddbe-73c2-8fc8-09f7af9ed202` made no edits and
reported:

- unavailable Folder source geometry must still produce an opacity-only,
  identity-transform entrance;
- an exit visual must not be retained when a reliable source/geometry anchor is
  unavailable;
- screen changes must cancel Folder visual transitions before target-screen
  refresh.

Current implementation evidence is present at
`Sources/PagingPrototypeApp/AppDelegate.swift:1052-1076`,
`Sources/PagingPrototypeApp/AppDelegate.swift:1093-1103`,
`Sources/PagingPrototypeApp/AppDelegate.swift:1456-1457`, and
`Sources/PagingPrototypeApp/ActivationComposition.swift:333-338`. The audit
also confirms that the click chain is statically connected, while real
WindowServer delivery and real `NSWorkspace` launch remain unproven.

### Changed files and source baseline

No product or test file was edited during this verification pass. The existing
dirty tree was preserved. `HEAD` is
`6382bd911741831d13360e402c270bb6509b3679`; a fresh status snapshot counted
68 entries. Only this stage summary and the current verification result are
being updated with the new evidence.

### Exact verification evidence

- Focused Phase 1J/click/Folder run: `94` XCTest executed, `0` failures,
  exit `0`.
- Full `rtk swift test`: `1553` XCTest executed, `0` failures, exit `0`,
  2026-09-13 07:11:33-07:11:57.
- Debug target build: `swift build --target PagingPrototypeApp
  --configuration debug`, exit `0`, `0.52s`.
- Release product build: `swift build -c release --product PagingPrototypeApp`,
  exit `0`, `21.14s`; the existing Sendable warning at
  `Sources/PagingPrototypeApp/AppDelegate.swift:1475` remains.
- `git diff --check`: exit `0`.
- Safe package: `LEGACY_DESTRUCTIVE=0`, candidate
  `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-071309-final/Launchcopy.app`,
  manifest dirty count `68`, executable SHA-256
  `c2a0f3750e3536e7a8c0d6005ac0a30524081efd6e6bb1f578ceed34c2a10069`,
  `Info.plist` lint PASS, unsigned/not notarized.

### Reviewer verdict and unresolved gates

The Terra result is a read-only audit, not an independent formal Reviewer
PASS. No formal Reviewer PASS is available. Native GUI automation remains
blocked by the exact lock error:
`The Mac is locked and automatic unlock could not unlock it. Ask the user to unlock the Mac manually before continuing.`

Unverified runtime gates are current-candidate real app launch, visual
page/search placement, Folder origin-aware open/close/reversal, Escape, drag,
Reduce Motion feel, hide, resize, screen change, and teardown while animation
is active. `LOCAL_RC_VALIDATED` remains prohibited; the stage label is
`RC_IMPLEMENTED_MANUAL_PENDING`.

### Next executable action

After the Mac is manually unlocked, run the current candidate against the GUI
matrix and record the exact candidate path and hash. Separately obtain a formal
independent Reviewer verdict. Until then, retain the current implementation and
keep static, XCTest, build, package, and runtime evidence in separate buckets.

## Superseding Runtime Update - 2026-09-13 12:26 local

The user reported an unlocked Mac, but the fresh native automation probe still
returned `The Mac is locked and automatic unlock could not unlock it. Ask the user to unlock the Mac manually before continuing.`
The probe also returned `unsupported Codex auth method: apikey` for browser
automation. Read-only power assertions at `2026-09-13 12:24:41 +0800` showed
`UserIsActive 0`; no native GUI claim is made.

The exact current release candidate
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-1212-final/Launchcopy.app`
was run with `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`, `--neutral-content`, five
pages, 35 items per page, and Reduce Motion off. It exited `0` after about
20 seconds and reported
`SELFDRIVE stats: flings=40 committed=30 stales=10 live=5 pool=0 layouts=19 telemetryEvents=0`,
followed by `teardownAll` and clean exit. The executable hash remained
`0e1bba9a00a4eee5bc6602d681e8b59950dba45a4a1dbb9cbe7d56351bd9f8d1`.

This is synthetic startup/paging/teardown evidence only. Pointer clicks,
Folder open/close/interruption visuals, Escape during motion, drag delivery,
Reduce Motion feel, hide/resize/screen-change behavior, real
`NSWorkspace.shared.open`, and physical input remain unverified. The stage
label remains `RC_IMPLEMENTED_MANUAL_PENDING`; no `LOCAL_RC_VALIDATED` or
independent Reviewer PASS is claimed.

## Superseding Runtime Update - 2026-09-16 23:20 local

### Source and commit state

- Phase 1J implementation, workflow artifacts, and the 2026-09-16 role
  reconfiguration were committed as `bddb0fa28af3f3c2ab9e7be0bfab9d5497738f03`
  (user-authorized commit; not pushed). Prior HEAD `6382bd9` remains the base.
- Role config now: Main/Chief/Worker = `swe-2-max` (medium); Reviewer =
  `glm-5.2-max` (high); max_worker_concurrency = 2.

### Fresh SELFDRIVE run on the committed candidate

- Command: `PAGING_PROTOTYPE_GUI_SELFDRIVE=1
  .build/candidates/phase1j-rc-20260913-1212-final/Launchcopy.app/Contents/MacOS/Launchcopy
  --neutral-content --page-count 5 --items-per-page 35 --reduce-motion-override off`
- Exit `0`. Stats: `flings=40 committed=29 stales=11 live=5 pool=0 layouts=11
  telemetryEvents=0`. Four-finger backend ready (`devices=1`); real desktop
  wallpaper loaded; `teardownAll` clean. 60 Hz runloop Timer, tolerance 0.000ms.
- Scope boundary unchanged: synthetic startup/paging/teardown only. Pointer
  clicks, Folder visuals, Escape, drag, Reduce Motion feel, hide/resize,
  screen change, real NSWorkspace launch remain unverified.

### Mac unlock state

- `pmset -g assertions` at ~23:20 +08:00 shows `UserIsActive=1` (was `0` on
  2026-09-13). The native-automation lock blocker is lifted; the Track B GUI
  matrix is now executable pending user authorization to drive real input.

### Reviewer status

- Formal independent Reviewer dispatched under the new config (GLM-5.2 Max,
  background agent `6dfbaac7`), reviewing commit `bddb0fa` against the four
  task packets and Terra audit findings. Verdict pending.
- Stage label remains `RC_IMPLEMENTED_MANUAL_PENDING`. No
  `LOCAL_RC_VALIDATED` claim.

## Superseding Review Update - 2026-09-16 23:45 local

### Formal r1 Reviewer verdict: FAIL

- GLM-5.2-Max Reviewer (agent `6dfbaac7`) completed
  `Workflow/reviews/T-1J-LM-r1.md` against commit `bddb0fa`. The agent session
  then died to a platform protocol error after artifact delivery; the complete
  review stands as the formal r1 record.
- Verified PASS: grid geometry (5×7, vertically centered envelope, no
  page-to-page jump), Folder pointer motion (180ms/0.96/≤8pt, origin-aware,
  opacity-only+identity fallback), retained exit visual genuinely
  noninteractive + generation-gated, all three Terra findings addressed at
  claimed locations, PagingCore/tolerance/persistence/wallpaper untouched.
  Reviewer re-ran 67 focused XCTest cases, 0 failures; candidate SHA-256
  verified.
- Single MAJOR finding **M1**: the committed diff changes the launch
  hit-region contract from icon±4pt to whole-cell bounds
  (`AppGridCellView.hitTest`/`acceptsLaunchHit`, consumed by
  `AppLaunchController.handleClick` and the window-level blank classifier)
  without a recorded Chief/user authorization. It contradicts five written
  preserves (plan `:42`, decision `:10`, task packets, spec `:44`) and
  falsifies acceptance docs (`PHASE1J_FAILURE_TRIAGE.md:15-24`,
  `PHASE1J_CHECKPOINT.md:126`, `PHASE1J_REPORT.md:23-27`). Reviewer judges the
  change plausibly correct (label/padding click dismissing the launcher was a
  real defect; whole-cell matches BUG9/B1 lineage) — the FAIL is about
  authorization + doc truth, not implementation quality.
- Minors: m1 `pendingPointerFolderID` same-folder re-open attribution edge;
  m2 `rebuildFolderCompositionIfNeeded` now prefers pendingSnapshot (bounded,
  test-covered, list in closeout); m3 pre-existing Sendable warning unchanged.
- STATE reconciled: T-1J-LM-GRID = PASSED, T-1J-LM-MOTION = PASSED,
  T-1J-LM-WIRING = FAILED (worker_failures=1, M1 scope), T-1J-LAYOUT-MOTION =
  FAILED pending M1 resolution.
- Stage label remains `RC_IMPLEMENTED_MANUAL_PENDING`.

### Blocking user question (Q1)

Was the whole-cell launch hit target authorized/intended? If yes: record a
decision delta and reconcile the three falsified docs; finding downgrades,
slice re-reviews to PASS. If no: dispatch Worker to restore icon±4 in
`acceptsLaunchHit` and realign Bug9/B1/AppLaunchController test expectations.

## Superseding Review Update - 2026-09-17 00:55 local — r2 PASS

- Bounded repair `T-1J-LM-HITREVERT` (Worker fc0d08a8, declared swe-2-max)
  restored `acceptsLaunchHit` to `iconFrame.insetBy(-4).contains`
  (folder: `folderSymbolView`) per user decision `D-1J-HIT-REGION-REVERT`.
  Unified contract / `appGridCellAncestor` / interaction-zone split retained.
- Independent r2 Reviewer (GLM-5.2 Max, agent `684c4bf0`) verdict: **PASS**
  (`Workflow/reviews/T-1J-LM-r2.md`). Independent re-run of the fail-before
  suite: 40 executed / 0 failures — genuine before/after pair vs the worker's
  40-exec/11-fail log.
- STATE: T-1J-LM-GRID/MOTION/WIRING/VERIFY/HITREVERT and parent
  T-1J-LAYOUT-MOTION all PASSED at the review layer.
- Open user question logged (r2 Q1, non-blocking): folder-member activation
  inside an open overlay still uses whole-cell `cell.frame.contains`
  (`FolderOverlayView.swift:381,407`) — baseline behavior outside the icon±4
  top-level contract; decide separately whether folder members should also be
  icon±4.
- Dated corrections appended by Main: `Docs/ADR-006-KEYBOARD-FOCUS.md` §8.5 and
  `Docs/PHASE1C_REPORT.md` (stale "label → super.sendEvent 透传" under icon±4).
- Stage label: remains `RC_IMPLEMENTED_MANUAL_PENDING` — review gate now
  green; Track B GUI/physical matrix is the remaining open gate (Mac
  unlocked, UserIsActive=1 as of 2026-09-16 23:20).

- Fresh candidate from committed r2-PASS HEAD `319b8cc`:
  `.build/candidates/phase1j-rc-20260917-hitrevert/Launchcopy.app`, exe SHA-256
  `79ca88713e9d3101d74aadec03652de36a030fe42737b20ac31f206a960f0c16`,
  unsigned/not notarized. This is the candidate for the Track B GUI matrix —
  the 2026-09-13 candidates still contain the reverted whole-cell contract.
