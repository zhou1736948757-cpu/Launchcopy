# Appearance Parity — Current Execution

Objective: independently add the reference product's label and wallpaper-blur
controls on the existing performant framework. Spec: `Docs/LAUNCHBETTER_APPEARANCE_SLICE.md`;
approved product scope: `Docs/LAUNCHBETTER_PARITY_SPEC.md`.

Previous goal turn made concrete progress: bounded production repairs, independent
review, new passing tests and a hashed r3 candidate. Full objective remains active.

Baseline: `319b8cc` plus current preserved dirty repair files. r3 binary SHA
`85e0f5f3765f0570106a5f370cab48f3d9b32f9cd4b02b5939082bc57c6353c7`.
Current source baseline full XCTest pending rerun at slice start. Preserve all work.

User is away and explicitly allowed computer use: a GUI/input window is now
available. Prefer Desktop 2, keep installation/commit/signing/publishing and
unrelated preference changes excluded. Previously constrained GUI/full tests may
now run; no claim of physical human smoothness acceptance from automated input.

Plan: Main owns appearance preferences, settings and wallpaper/application wiring;
worker owns label consumers/renderer and their tests; stable independent review
followed by complete verification. Maximum three agents including Main.

Next: complete the copied pre-appearance XCTest baseline, implement disjoint
appearance changes, then capture the exact new candidate's control behavior.

## Source/test progress

- Baseline copied XCTest executable SHA:
  `6290b136ac7d9a09222e51a64845ef4410ac5edf746b8f83e1a9f26e74388f1f`.
  Full 1590/0, exit 0 at 15:59:29 JST; immutable pre-appearance bundle/log in
  `.build/verification/20261013/r3-full-suite/`.
- Worker Bacon implemented consistent label policy on cells/pages/Folder/proxy and
  renderer live/pool/new instances, plus 10 regressions. No source assets copied.
- Main added versioned independent preference store/coordinator, staged appearance
  controls and two-section existing settings window, startup/application wiring and
  blur-radius requests. Blur zero renders sharp requested resolution off-main;
  memory cache capped at six images/48MiB to prevent setting churn growth.
- Defaults preserved: labels visible, blur18, capacity/geometry/hit contracts.
- Initial compile identified missing MainActor annotations on two new AppDelegate
  methods; fixed before execution. Current focused run: 45/0, exit0 at16:13:41 JST,
  log `.build/verification/20261013/appearance/focused.log`.
- Independent read-only review dispatched on stable source. Full suite in progress;
  no GUI/physical/performance-AB result claimed yet.

## Independent review / corrective pass

First review by Linnaeus: FAIL with three P2 findings. Adjacent blur radii were
quantized into one memory/disk key, Workspace accessibility changes did not
reach/reapply wallpaper, and shortcut recording continued after switching tabs.

Main repairs: exact effective-radius bits in v2 cache filenames (old files kept),
nonuniform adjacent-radius/cross-instance regression; correct Workspace register/
remove center plus display-policy reapplication; end recording on tab switch and
filter local monitor by recording state/settings window. Added production-wiring
observer and tab-switch tests. Apple API authority for the notification center:
[Accessibility display change notification](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayoptionsdidchangenotification).

Pre-repair full suite was 1617/0 at16:15:48; does not prove the post-review tree.
Observer-only run14/0 passed16:19:34; final focused/full runs remain to be recorded.

## Current GUI limit

CUA reported locked Mac while attempting Mission Control from Finder. No Desktop2
selection or unlock is claimed. User permits computer use but lock cannot be
bypassed; do not change lock/security preferences or keep repeating locked probes.
Continue source/tests/builds. Live candidate visual/settings/performance checks
remain pending a real unlocked UI session.

## Verification updates

- Repair focused: 48/0 at16:26:32 JST. Initial adjacent-cache wait mistakenly
  counted transient ImageIO files; failure log kept as
  `appearance/repair-focused-tempfile-failure.log`. Final predicate waits for
  three valid v2 PNGs, without waiving missing entries. Pixel differences and
  cross-instance radius-specific results are covered by nonuniform images.
- Selected-tab geometry test: 1/0 at16:28:31; real NSWindow/NSTabView has nonzero,
  unclipped controls and no ambiguous appearance-root layout. Not a GUI screenshot.
- Added notification->production display handler->late wallpaper rejection test;
  policy refresh cancels any active pointer before reconfiguring folder views.
- Full post-repair suite: 1622/0 at16:32:32 JST, 27.006s; log
  `appearance/final-full.log`. Annotation-only follow-up marks immutable suite-name
  String nonisolated to avoid a new Swift6 actor warning; final rerun/build pending.
- No physical performance comparison, Desktop2 selection or candidate GUI
  acceptance was completed. Structural tests prove appearance-only work budgets
  (no icon reload/frame mutation, label-only no wallpaper request), not real-device
  regression-free performance or full LaunchBetter parity.

## Current final checkpoint

- Immutable suite-name annotation fixed the new warning. Verified current full
  suite: 1622 executed/0 failures, exit0 at16:34:13 JST,21.725s; log
  `.build/verification/20261013/appearance/verified-full.log`. Only the existing
  Multitouch diagnostic Sendable warning remains.
- Independent source re-review: scoped PASS after all three P2 findings were
  repaired; `Docs/APPEARANCE_SLICE_REVIEW.md` records scope/limits. All subagents
  completed and closed; no overlapping writes or concurrent SwiftPM runs.
- Debug build exit0; Release build/safe packaging exit0 (12.49s product build).
  Logs under `.build/verification/20261013/appearance/`.
- Candidate: `.build/candidates/appearance-rc-20261013-r1/Launchcopy.app`.
- Executable SHA-256:
  `146246c7a7c2e985225b6f35ff536700ba9a871f4f8414d60e12fe8f72a4214e`.
- Candidate is preserved, not launched/installed/distribution-signed/notarized/
  published. No commit/reset/clean or unrelated preference changes.
- Status: APPEARANCE_SOURCE_VERIFIED_GUI_PENDING. Full thread goal remains active;
  only first appearance controls are implemented, not complete reference parity.

Next actions: when unlocked, use an agreed Desktop2 session and test-window flag
for exact-candidate settings Apply/reopen, labels/folder visibility, blur0/18/60,
search-launch/Folder reversal and matched performance checks. Meanwhile, continue
the approved app-management metadata/actions slice; preserve the full remaining
roadmap in `Docs/LAUNCHBETTER_PARITY_STATUS.md` rather than waiting on the lock.
