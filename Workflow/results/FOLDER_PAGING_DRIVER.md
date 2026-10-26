# Folder Paging Input Driver

Date: 2026-10-16
Status: Implementation ready for Main verification; no Worker build/test execution.
Contract: `Docs/FOLDER_TRACKPAD_PAGING_SPEC.md` (approved).

## Owned changes

- `Sources/PagingUI/FolderPagingController.swift` — new folder-local input/lifecycle controller.
- `Tests/PagingUITests/FolderPagingControllerTests.swift` — focused state/input/lifecycle coverage.
- `Workflow/results/FOLDER_PAGING_DRIVER.md` — this handoff.

No other files were written. Existing concurrent changes were preserved. No commits,
process control, installation, fixture mutations, reference-product source inspection,
package edits, or changes to PagingSurface, PagingCore, ScrollInputMapper, parameters,
or the existing frame driver were performed.

## Implementation and integration contract

- Public API matches the requested no-argument controller initializer, observable `core`,
  `configure`, `handleScroll`, callbacks, `cancel`, `tearDown`, public manual
  `advanceFrame`, `automaticallyDrivesFrames = true`, and computed `isActive`.
- Core uses unchanged `PagingParameters()` production defaults and the unchanged
  `ScrollInputMapper` action mapping, including horizontal finger filtering, direction
  normalization, momentum cutoff/glide, and legacy/no-phase behavior. There is no new
  threshold algorithm or alternate physics model.
- Offsets are **page units**, matching `core.visualOffset`; the owner translates its
  bounded member hosts using the configured viewport width.
- Identical configuration and authoritative page are no-ops, including while active.
  Page/count/width/motion-policy changes synchronously replace the core at the supplied
  clamped authoritative page. Old core events are generation-gated. Invalid/nonfinite
  geometry disables input until usable geometry is configured; empty content is inert.
- Each natural commit updates the controller's authoritative page before notifying
  the owner. `cancel` returns to that page, emits no commit, and clears pending release
  and animation. Offset/activity reset callbacks remain available for owner cleanup.
- Core callbacks only record state; outward callbacks are delivered after the core
  operation returns. Activity activation precedes moving-offset presentation; commit
  precedes activity deactivation. Each delivery rechecks current work, so synchronous
  cancellation, replacement configuration, or terminal teardown owns subsequent work.
- A new began after a pending release delivers any immediate old commit before starting
  the new gesture. An interrupted settling gesture otherwise retains the displayed
  offset and reuses core takeover semantics. No configure-per-event requirement.
- `onCommit` can finish visuals, call the authoritative page callback, synchronously
  invoke `cancel`, and call `configure`; the old core has already returned from its
  completion operation. `onActivityChange(true)` can cancel before any moving offset.
- The injected test clock is `internal var pendingFinishTimeSource: () -> TimeInterval`
  (accessible with `@testable import PagingUI`). Pending release uses the same 100ms
  window and monotonic system-uptime default as PagingSurface.
- One weak-capture Timer exists only for pending release or actual animation/glide:
  60Hz, `RunLoop.main` `.common`, tolerance 0, maximum simulation dt 100ms. Finger
  tracking is event-driven. Idle, cancel, reconfiguration, teardown, deinit, and disabling
  automatic frames invalidate the Timer. No background/secondary permanent frame pump.
- `tearDown` is terminal, idempotent, and silent; owner teardown must clean its own views.
  Callers should observe `core` rather than mutate it directly or retain it as the
  current engine across configuration changes.

## Coverage supplied

Tests cover continuous tracking, natural/traditional direction normalization, vertical
finger filtering, slow bounce, injected-clock release timeout, momentum takeover and
production cutoff, unchanged-core glide/frame parity, settle interruption, immediate
old-release commit followed by new began, first/last edge damping, rapid reversal,
configuration idempotence, keyboard page synchronization, count/geometry/motion changes,
empty/invalid geometry, cancellation at tracking/release/settle boundaries, cancellation
after a new committed page, orphan/cancelled phases, Reduce Motion, legacy/no-phase
mapping, reentrant commit/offset/activity/teardown callbacks, terminal teardown,
Timer allocation/defaults/reuse/invalidation, weak ownership/deinit, and nonfinite input.

Tests instantiate no NSApplication or native views/windows and perform no fixture writes,
real-time sleeps, or human/native gesture claims. Timer tests inspect allocation and
invalidation synchronously; they do not claim real runloop cadence or physical smoothness.

## Verification and next action

Worker performed source review and scoped whitespace inspection only. No Swift compiler,
build, test, or SPM invocation was run, as requested to avoid contention with Main.
Main has started its combined focused verification; any resulting compile/runtime
failure remains a verification gate and should be returned to this file owner for repair.

Focused command for Main from the repository root:

```sh
rtk swift test --filter FolderPagingControllerTests
```

Main owns combined overlay/routing regressions, full suites, packaging, and native/manual
acceptance. This Worker does not self-certify a Reviewer PASS.

## Maintenance notes

- Keep release-window behavior synchronized with PagingSurface if that contract changes.
- A deliberate request to reset to the same authoritative page during a gesture should
  call `cancel`; unchanged layout configuration deliberately preserves active input.
- No additional public API was introduced beyond the requested controller surface.
