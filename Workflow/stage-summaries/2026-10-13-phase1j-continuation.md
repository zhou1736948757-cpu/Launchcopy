# Phase 1J Continuation — Startup and Interaction Verification

## Objective and baseline

Resume the approved click/Folder-motion repair, not a new product phase. Current
HEAD is `319b8cc`; September candidate/test records are historical, not current
runtime evidence. Preserve the three existing dirty Workflow files. In particular,
retain the subsequently accepted icon-plus-4pt launch hit contract.

## Plan and ownership

1. Main: remove synchronous wallpaper file reads from window startup; resolve
   AppKit screen metadata on the main actor, decode/render on a background queue,
   and invalidate late completion when Reduce Transparency or host changes.
2. Read-only audit agent: inspect live click routing, Folder motion/blank-close,
   and actual catalog-commit ordering. No overlapping writes or GUI operations.
3. Main: focused regressions, full tests, debug/release builds, unique safe package.
4. Independent read-only reviewer: inspect the stable repair and tests. Maximum
   three simultaneous agents including Main; serialize SwiftPM and GUI resources.
5. Main: exact-candidate GUI checks and a durable evidence checkpoint. Keep user
   feel/physical gesture acceptance distinct from automated and screenshot checks.

## Acceptance and boundaries

- Window startup never synchronously reads or decodes a wallpaper file.
- Worker code never resolves NSScreen/NSWorkspace state.
- Old wallpaper results cannot undo Reduce Transparency or update a new host.
- Preserve input hit regions, paging physics, Timer tolerance, persistence and
  existing user-accepted black-frame repair. No signing, installation, publishing,
  commit, process termination, cleanup, or system preference changes.
- A successful build is not GUI acceptance. Do not promote LOCAL_RC_VALIDATED
  while physical/manual gates remain unresolved.

## Current evidence

Native app inventory is accessible after the user's unlock. No Launchcopy process
is currently running. Source still contains `NSImage(contentsOf:)` in main-actor
refresh before the window is shown. Historical stack samples implicated this
read in a startup stall; underlying filesystem behavior is not established.

## Next action

Implement bounded nonblocking wallpaper refresh and deterministic regression tests.

## Progress — 2026-10-13

- Wallpaper fix independently reviewed by Rawls: source-slice PASS (not GUI or
  full product approval). Nonblocking heartbeat test strengthened as suggested;
  synthetic provider concurrency tests added, awaiting final run.
- Initial focused run: 7 executed / 1 failure due to an invalid assumption about
  AppKit NSView release. Replaced with deterministic weak-controller release test.
  Rerun: 7/0; full XCTest: 1564/0 at 14:50:35 JST. These counts precede the new
  page-label/provider tests and the interaction worker's changes.
- Debug build and safe Release packaging passed. Existing Multitouch diagnostic
  Sendable warning remains; no claim of zero-warning compilation.
- Interim candidate: `.build/candidates/phase1j-rc-20261013-wallpaper-r1/Launchcopy.app`;
  executable SHA-256 `56a310e8152bd35d89bef0b0c383e8954eb8086581d09f047e0e72eee867a0f1`.
  Not installed, distribution-signed, notarized or released.
- CUA bound this exact app path: window displayed, blurred wallpaper visible,
  non-search icon click started a previously non-running system editor and hid
  the launcher; reopening reused the launcher; Folder pointer entry showed the
  real overlay. No physical smoothness verdict from this observation.
- Audit by Carver found search-click suppression, blank-pointer close bypassing
  exit animation, double catalog commit clearing an active query, and lost
  presentation continuity during rapid same-folder reopen. Gibbs owns the
  bounded AppDelegate/coordinator repair; Main owns wallpaper and grid page label.
- User additionally requested removal of visible top page text and notch-safe
  search placement. Main hid the grid label, retaining accessibility/page data;
  worker owns search geometry. Pending tests and exact final-candidate GUI check.

## Superseding user goal

The user changed the overall objective to implement LaunchBetter UI and functions
on Launchcopy's framework. This authorizes read-only discovery of LaunchBetter,
superseding the previous source-read exclusion for that project only. Raw Buho
evidence remains excluded. Anscombe is comparing source feature/UI coverage for
a migration specification. Broad migration requires scope/spec confirmation;
current bounded bug fixes remain useful and proceed without replacing validated
paging physics or persistence contracts.

## GUI disruption boundary — user correction

The user is actively working: test the app only on Desktop 2, never cover their
working desktop. Main hid the interim candidate with Command-H; CUA reported no
visible app window afterward. Stop further GUI actions for this turn until an
agreed Desktop-2 session. macOS input automation is global, not an independent
background desktop; do not imply moving the window alone prevents input/focus
disruption. Do not create/switch Spaces, reopen candidates, or change Dock/Spaces
preferences silently. Source review, tests and builds may continue in background.

Correction: only non-presenting tests may run while the user works. Existing
LauncherWindowControllerTests call real orderFront/activation/chrome changes;
the final full suite is also a GUI-capable run and must wait for the agreed
Desktop-2 session. Do not change production assertions to manufacture a
headless full-suite pass. The earlier 1564/0 evidence precedes this boundary.

## Migration decision and draft

The user selected independent implementation without source/resource copying.
`Docs/LAUNCHBETTER_PARITY_SPEC.md` now contains the audited feature gaps,
recommended architecture, acceptance gates and migration decisions awaiting
confirmation. Reference source behavior is not reference runtime validation.

## Test-mode correction

User authorized an unobtrusive testing alternative. Main adds opt-in
`--ui-test-windowed`: ordinary titled/resizable window, normal level, no
canJoinAllSpaces, background ordering, no automatic activation or menu/Dock
hiding. Worker wires AppDelegate startup; normal production defaults remain.
This is a separate launch flag, not a temporary production default change.

## Integrated source and nonfronting verification

- Gibbs completed the interaction/search/motion and safe-area repairs plus test-mode
  AppDelegate wiring. Production icon-plus-4pt hit regions and paging parameters
  remain unchanged. 17 new tests use the real production wiring/helpers.
- Worker final nonfronting selection: 145/0, exit 0. Preserved log at
  `.build/verification/20261013/worker-nonfronting-tests.log`.
- Disclosure: an earlier worker batch of 146 tests accidentally included one
  existing front-activation test. That batch does not satisfy the disruption
  constraint; final selection excludes it. Do not repeat that test on Desktop 1.
- Main selection: 41/0, exit 0 at 15:11:00 JST; strengthened wallpaper tests,
  provider concurrent-cache/invalidation tests, top-label regression, argument
  defaults and background-window behavior. Log:
  `.build/verification/20261013/final-nonfronting-tests.log`.
- These separate selections are not a full-suite result and must not be summed
  into a claimed full test baseline. Sagan is reviewing the stable integrated diff.
- User approved the migration's recommended staged scope, then clarified that
  existing LaunchBetter product UI/features are the desired experience; the
  rewrite must retain Launchcopy performance, not invent a replacement product.
  The specification now records approved scope and performance-first acceptance.

## Current preserved candidate

- Debug build: exit 0. Release build and safe packaging: exit 0 (14.64s product
  build). Existing Multitouch diagnostic Sendable warning remains.
- Candidate: `.build/candidates/phase1j-rc-20261013-background-r2/Launchcopy.app`.
- Executable SHA-256:
  `fc2b906e9921b3ed0e00ca4c4ed6aef227df6f29f1c8e4ee7b2634b2592dea54`.
- This candidate contains the final interaction, notch-safe search, page-label
  removal, wallpaper and opt-in test-window edits. Not launched or installed.
  No processes stopped, no commit, no distribution signing/notarization/publishing.
- Logs: `.build/verification/20261013/final-debug-build.log` and
  `final-release-package.log`. Source-slice reviewer and exact-candidate GUI
  acceptance are not interchangeable; full GUI-capable suite remains pending.

## Next executable actions

1. Address the independent review if actionable issues are reported.
2. Arrange a Desktop-2 input window for the final GUI-capable full suite and
   exact-candidate checks (safe-area/labels, search launch, pointer close/reversal,
   Escape, Reduce Motion and persistence regressions).
3. Begin the approved parity visual/settings slice with matched performance
   baselines, preserving the performant launcher foundation. No whole-parity
   completion claim until every agreed feature and performance gate is verified.

## Independent review and repair

Sagan's first integrated review: FAIL, two P2 cancellation defects. Search-only
pointer arbitration was active while the drag controller stayed idle, so cancel
returned before recognizer/session cleanup. Also Escape removed an exiting
Folder visual without canceling a simultaneously started top-level press.

Main fixed both: cancel now recognizes the click-only press; Escape clears the
exit visual and any active pointer session in the same call. Four new regressions
cover search press canceled by Escape/resign/catalog-refresh plus simultaneous
exit/new press canceled by Escape. All assert no late release click/commit and
restored recognition. Latest nonfronting selection: 62/0, exit 0 at 15:20:40 JST;
log `.build/verification/20261013/repair-nonfronting-tests.log`. This is not the
full GUI-capable suite. Re-review requested on the stable repaired source.

The r2 candidate is superseded by this repair; it was never launched. Final r3
packaging is underway; do not use r2 as evidence for the canceled-session fixes.

## Final checkpoint for this turn

- Independent source-slice re-review: PASS; both P2 findings closed, no additional
  findings. Scope and limitations preserved in `Docs/PHASE1J_CONTINUATION_REVIEW.md`.
- Debug build exit 0; Release build/safe packaging exit 0 (19.69s product build).
  Existing diagnostic Sendable warning remains.
- Current candidate:
  `.build/candidates/phase1j-rc-20261013-background-r3/Launchcopy.app`.
- Executable SHA-256:
  `85e0f5f3765f0570106a5f370cab48f3d9b32f9cd4b02b5939082bc57c6353c7`.
- r3 is not installed or launched. The earlier r1 test app was hidden, not killed.
  No system preferences, Spaces assignments or production fullscreen defaults
  were changed. All dispatched subagents have completed and been closed.
- New candidate remains LOCAL_CANDIDATE_MANUAL_PENDING, not LOCAL_RC_VALIDATED,
  RELEASED, full product parity or a performance-regression-free result.

When a Desktop-2 input slot is agreed, launch the candidate with
`--ui-test-windowed` and background launch ordering for windowed checks; use
production fullscreen only for the explicitly scheduled physical/visual gate.
Do not run the GUI-capable full XCTest suite on the user's working Desktop 1.
Resume broad migration from the approved scope in `Docs/LAUNCHBETTER_PARITY_SPEC.md`.
