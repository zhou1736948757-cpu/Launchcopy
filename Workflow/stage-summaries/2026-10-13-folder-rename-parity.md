# Folder Rename, Durability and Metadata Continuity — Execution

Previous goal turn: progress. Folder-assignment callbacks, four reviewed transaction
and identity repairs,1817/0 full tests and a separately preserved r2 candidate.
Full parity is not complete; locked-GUI physical acceptance remains separate.

Baseline: current dirty319b8cc,1817/0 at18:30:34 JST; r2 executable SHA
7e6af7200c574a8b536b5f4aad183b5701b97de80120636ce1a76b07560d0706.
295 source/test/package files recorded/rechecked in prior verification directory.
Do not overwrite candidates, revert unrelated work, install/sign/commit or stop apps.

Existing approved bounded repair: Docs/LAUNCHBETTER_FOLDER_RENAME_REPAIR_PLAN.md.
Main owns editor/session/application/quit durability wiring and integrated tests.
Worker A owns overlay title-action/editor-host/lifecycle seams and tests. Worker B
owns pure metadata path/bundle continuity and tests. Disjoint files and dependency
requirements; max3 active agents including Main. Main alone runs SwiftPM/GUI/builds.
Independent source Reviewer follows stable integration; no old chef runtime routing.

No original reference sources/assets/dumps required or allowed for implementers.
Direct-page proposal remains unapproved; do not edit PagingCore for navigation.
Source/lazy settings/watching/Library and visual parity remain on the full ledger.

## Integrated rename and durability implementation

- Actual title-action button mounts a fresh app-owned editor in the live overlay.
  Enter/native responder transfer reads live field-editor text; dismiss clears
  callbacks before removal. Folder/catalog/layout/store-epoch and lifecycle token
  gate stale commits. Shared layout mutation/save retains hidden and missing refs.
- Blank/same title is a no-op, title uses existing64-grapheme normalization.
  Escape, close/switch, resize/screen changes, hide/teardown cancel old sessions.
  Title entry is disabled during bootstrap/protected storage/gesture ownership/quit.
- Metadata retains path-key hidden/alias continuity after a record gains bundle
  identity; explicit unhide/reset clears current matching keys. Settings and the
  actual alias sheet use the same fallback, without copying original resources.
- Queue owns ordered accepted writes and retained bounded flush operations.
  Observe actual persistence outcomes, not an early healthy-state sample. A single
  neutral notice preserves in-memory layout; late epoch/batch results are ignored.
- Initial source review FAIL F1–F3 plus interim R4–R6 are preserved. Repairs cover
  terminal over-limit/stale rejection, one-writer bounded final retry, cancellable
  status-menu Quit, receipt batch attribution and reentrant state-observer handoff.
- User explicitly approved failure dialog Cancel Quit(default)/Quit Anyway.
  WorkspaceQuitCoordinator + applicationShouldTerminate wait accepted writes
  before irreversible teardown. Detached real status-menu callback test exercises
  failed Quit -> Cancel -> input usable -> repeat Quit. Tests never terminate NSApp.

## Execution snapshot (source rereview pending)

- Focused143/0 after correcting alias-popup selection fixture.
- Full r1:1883 tests,2 fixture scheduling/count assertions failed; preserved.
  Main corrected eventual observeState wait and allowed separate failure retries,
  not production semantics or durability assertions. Full r2:1883/0 at19:23:22.887
  JST,24.263s. Real actor11 tests include suspended final IO, retained rejection,
  recovery/LKG and concurrent-flush ownership; owner tests use actual unshown
  AppKit windows and fresh real journal actor reload, NOT physical GUI or process restart.
- Debug success; Release package success16.48s. Existing diagBackend non-Sendable
  warning remains (not zero-warning). Source304-file manifest checked.
- Candidate `.build/candidates/folder-rename-rc-20261013-r1/Launchcopy.app`, executable
  SHA256 `5aae0bff4d7096be36bafd3fc04852a2a2e03cbd4445fbe8d05ba9ef8e5428f1`.
  No install/distribution signing/notarization/commit/app stop/launch. Candidate
  includes ordinary linker ad-hoc signature only. Exact source review pending.
- Verification: `.build/verification/20261013/folder-rename/`, full-r2.log,
  debug-r1.log, release-package-r1.log, source-files-r1.sha256, source-check-r1.log.

## Desktop/testing update and next authorized slice

CUA Finder now accessible2026-10-13 (previous lock no longer current). No candidate
was launched: existing windowed mode is NOT storage isolation. User explicitly
approved an isolated test profile and normal Quit of only our test instance.
See Docs/ISOLATED_UI_TEST_PROFILE_PROPOSAL.md (now approved specification).
New worker owns parser/profile namespace helper only; Main assembly follows rename
source review. Existing user's resident app and arrangement must remain untouched.
Full goal stays active: remaining navigation decision, visual/layout settings,
sources/watching/Library/localization and physical performance remain on ledger.

## Review r1 disposition and bounded follow-up

Final rename-r1 source review = FAIL: ordinary receipt gating passed, but a late
post-timeout callback could still attribute A success to newer B; failure sheet
could lose its visible host during resident hide/suspend. Candidate r1 preserved
as this snapshot, not promoted despite1883/0. Main repaired callback coverage +
latest-observer handoff and shared pending-Quit cancellation/endSheet/abortModal
before hide, with a didHide fallback for session suspend. Focused38/0 verifies
actual automatic two-timeout callback race and real composition hide/sleep paths.
The production observation deadline remains2s; shorter waits only injected in tests.
Final full/build/source rereview required for repair snapshot.

User approved isolated profile specification, now Main + helper worker implement
parser/namespace/candidate-local layout+cache, synthetic catalog containment and
fake global activation/login adapters. Normal production paths keep their existing
storage and adapters. Writable CUA remains gated on integration/tests/source review.
