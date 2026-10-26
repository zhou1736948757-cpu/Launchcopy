# T-1J-LM-WIRING

Status: IMPLEMENTED_PENDING_INDEPENDENT_REVIEW
Owner: Main bounded adaptation after Worker runtime failure
Date: 2026-09-12

## Outcome

The accepted layout-mode and Folder pointer-motion contracts are integrated within the task's allowed write scope. Pending search input does not affect page geometry; committed non-empty search does. Pointer Folder open and outside-click close use the live Folder cell as a motion anchor when it is available. Keyboard and lifecycle paths remain immediate.

Main performed this bounded implementation after repeated project-bound Worker turns completed without a response or file changes, and one project dispatch failed before execution with:

`function_call_output requires call_id on HTTP requests; continuation via previous_response_id is only supported on Responses WebSocket v2`

The independent Reviewer gate remains mandatory.

## Changed Files

- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`: added a committed layout-mode provider and live `FolderID` cell-frame conversion.
- `Sources/PagingPrototypeApp/AppDelegate.swift`: added pointer trigger attribution, anchored entrance, drawing-only exit snapshot, generation gating, and cancellation on reopen/hide/resize/teardown.
- `Tests/PagingUITests/AppCatalogAssemblyTests.swift`: added committed-versus-pending mode and live Folder-frame tests.

No other WIRING product or test file was changed.

## Lifecycle Evidence

- Pointer open: `handleFolderCellClick(_:)` records the matching `FolderID`; `openFolder(_:)` consumes it and requests anchored motion only for that pointer path.
- Pointer close: outside-click calls `closeFolder(animatedFromPointer: true)`. Pixels are captured first, then drag/title/open state are synchronously cleared and `refreshFolderOverlay()` removes the interactive overlay and restores the surface drag host. Only then does the drawing-only snapshot animate.
- Keyboard/Escape/Command-F/move-out: existing calls use default `closeFolder()` and remain immediate with no exit visual.
- Hide: existing `ActivationComposition.hide(source:reason:)` calls `onPrepareHide` before launcher hide; `prepareTransientCancellationForHide()` now cancels Folder visuals first.
- Resize/teardown/reopen: each cancels visual state and invalidates delayed completions.
- Exit snapshot: `FolderExitVisualView` returns `nil` from `hitTest(_:)` and is excluded from accessibility.

## Verification

- Focused: `swift test --filter 'AppCatalogAssemblyTests/testRenderer(LayoutModeTracksOnlyCommittedSearchQuery|ResolvesOnlyLiveFolderCellFrame)|FolderMotionTests|FolderOverlayTests/testReduceMotionParams'`
  - Exit 0; 6 tests executed; 0 failures.
- Broad: `rtk swift test --filter 'AppGridGeometryTests|AppGridUITests|PagingUITests'`
  - Exit 0; 1286 tests executed; 0 failures; 18.512 seconds test time.
- `git diff --check`: exit 0.
- Pre-existing warning remains at `Sources/PagingPrototypeApp/AppDelegate.swift:1406`: capture of non-Sendable `MultitouchSupportBackend` in a `@Sendable` Timer closure. This task did not alter that timer or backend.

## Deviations and Risks

- The Worker runtime failed repeatedly, so Main used the bounded-adaptation allowance in `AGENTS.md`; this is a workflow deviation, not a scope expansion.
- Actual pixels, timing feel, rapid reversal, and system Reduce Motion require GUI validation from an exact build.
- A missing or recycled source Folder cell intentionally yields an unanchored opacity transition instead of stale geometry.
- Packaging, Debug/Release candidate builds, executable hash, and GUI evidence belong to `T-1J-LM-VERIFY` and are not claimed here.

## Scope Integrity

No LaunchBetter, BuhoReverseNotes, reverse evidence, decompiled material, activation bypass, packaging, signing, or publication path was read or modified. Existing unrelated dirty worktree changes were preserved. No commit or push was performed.

## Reviewer Focus

1. Confirm committed `activeQuery` is the sole layout-mode source and is applied on every renderer pass.
2. Confirm pointer trigger attribution cannot leak into keyboard activation.
3. Confirm logical close and drag-host restoration precede the exit visual.
4. Confirm the exit visual cannot hit-test or expose accessibility and stale completions are generation-gated.
5. Confirm hide, resize, reopen, teardown, and Reduce Motion behavior.
6. Confirm allowed write scope and forbidden-source isolation.

## Concurrency Constraint

The user clarified that the maximum is **three active agents including Main**. Therefore Main occupies one slot, and at most two additional Chief/Worker/Reviewer agents may run concurrently. `Workflow/config.json` records this as `max_active_agents_including_main: 3` and `max_worker_concurrency: 2`.
