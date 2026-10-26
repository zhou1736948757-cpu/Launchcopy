# Appearance Parity Slice — Independent Source Review

Date: 2026-10-13
Reviewer: Linnaeus (`01a1341d-b085-7c72-a372-22c157e4bbad`), read-only
Contract: `Docs/LAUNCHBETTER_APPEARANCE_SLICE.md`

## Initial result: FAIL

Three high-confidence P2 findings: rounded effective blur radii shared cache keys;
workspace policy change did not invalidate/reapply the backdrop; local shortcut
recording remained active when switching to Appearance.

## Repairs and final result: scoped PASS

- Exact effective-radius bits in v2 cache keys. Nonuniform adjacent16/17/18
  pixel results and independent cross-instance disk entries are tested.
- Workspace-specific notification center for register/remove; production display
  handler refreshes wallpaper/accessibility and cancels input before folder view
  reconfiguration. Notification-to-handler-to-stale-image regression added.
- Settings tab delegate stops shortcut recording outside Activation. Local
  monitor filters by live recording state and settings window. Leave/reenter
  test verifies cleanup and unchanged hidden draft.
- Reviewer rechecked all repairs and the nonisolated immutable suite-name
  annotation. No additional blocking findings; final source-slice PASS.

Reviewer did not edit files or run builds, tests or GUI. Main owns final suite,
build and package evidence in the current stage summary. Source review is not
full parity completion, candidate GUI validation, physical smoothness approval
or a measured no-performance-regression result. Those gates remain explicit.
