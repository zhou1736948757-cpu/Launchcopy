# D-1J-LAYOUT-MOTION — Grid Geometry and Folder Motion Architecture

Status: APPROVED_FOR_WORKER_EXECUTION
Date: 2026-09-12
Decision owner: Chief
Authority: user approval of `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md`

## Context

Phase 1J improves grid placement and adds restrained Folder transitions without changing paging physics, the 5x7 capacity, persistence, hit regions, drag intent, wallpaper composition, or activation behavior. The macOS Dock is outside this scope. `AppGridUI` cannot depend on the executable target.

## Decisions

### 1. Grid geometry ownership and mode input

- Add a small pure geometry value/helper in `AppGridUI`; it owns five-column frame calculation, seven-row envelope placement, and bounded row spacing.
- Keep the cell height at 88pt because `AppGridCellView` needs its existing 48pt icon and two label bands. Keep 16pt as preferred spacing. If seven rows do not fit, reduce spacing to zero before declaring the viewport unsupported; never shrink below the 88pt cell height, emit negative dimensions, or reduce the 35-item capacity.
- Ordinary pages always use the shared seven-row envelope centered vertically in the available grid region. A partial ordinary page keeps the same row origins as a full page. Search pages center their actual occupied row count.
- Mode is explicit: `AppGridRenderer` receives the committed presentation mode and passes it to every live or pooled `AppGridPageView` on each render. The composition root derives this from `AppGridUIPageContentProvider.activeQuery`; pending/uncommitted query text must not change visible geometry. A non-empty committed query means search mode; nil or empty means ordinary mode.
- The helper accepts a host-local layout region. Phase 1J uses the surface bounds with the existing 24pt side/bottom and 96pt top chrome reservation. It must honor nonzero bounds origins. Do not subtract the Dock, `visibleFrame`, or menu bar a second time. No `LaunchcopyVisualTokens` dependency is introduced.
- Cell frames remain the single geometry source for hit testing, focus lookup, drag frames, and Folder source lookup.

### 2. Source-cell coordinate conversion

- The integration layer resolves the visible source Folder by stable `FolderID` from the current committed page's rendered cells.
- It converts the actual source cell bounds into `FolderOverlayView` coordinates only after the overlay is attached and laid out. Persisted indices or assumed 5x7 arithmetic are not valid source geometry.
- The motion anchor is the source cell center normalized against the overlay bounds. Invalid, detached, stale, off-page, or non-finite geometry falls back to an opacity-only transition.

### 3. Pointer, keyboard, and Reduce Motion behavior

- Introduce an explicit transition trigger enum at the AppGridUI boundary: pointer, keyboard, and lifecycle/immediate. Do not infer trigger type from focus state.
- Pointer open and close use 180ms, scale 0.96, opacity, and at most 8pt source-directed translation with a strong non-bouncy ease-out. Animate only panel transform/opacity and scrim opacity; final model-layer values are set explicitly.
- Keyboard open/close, Escape, Command-F close, drag move-out/dissolution, launcher hide, screen/size invalidation, and teardown are immediate. Inner-page changes, title edits, refreshes, and focus moves never replay the opening transition.
- Reduce Motion pointer transitions use a 180ms opacity-only fade with identity transform and zero displacement. Keyboard and lifecycle paths remain immediate. This supersedes the old zero-duration Reduce Motion parameter expectation and requires focused test updates.
- A pointer reversal samples presentation-layer transform and opacity before retargeting. There is no input lockout.

### 4. Immediate close and exit visual lifecycle

- Logical close remains synchronous: clear move-out proxy, cancel drag, end title editing, close `FolderOpenState`, restore the drag visual host to the surface, clear interactive overlay content, and remove the interactive overlay.
- A pointer close may leave a separate AppGridUI-owned exit visual containing a transient layer snapshot. It must return nil from hit testing, be excluded from accessibility, hold no callbacks, and never become the drag visual host.
- Exit visuals have a monotonically increasing transition generation. Completion removes a visual only when its generation is current. Reopen, replacement Folder, hide, screen change, and teardown synchronously cancel and detach every older visual.
- The transient snapshot stays in memory only and is never persisted, logged, hashed, or included in telemetry. If a reliable snapshot cannot be formed, close immediately with no exit animation.

### 5. Cancellation, hide, and teardown

- `configure` for an already-open Folder updates content without replaying entry motion.
- Open A then open B cancels A's transition before configuring B. Open during exit cancels and removes the exit visual first.
- `prepareTransientCancellationForHide`, application/window resignation paths that hide the launcher, window-size/screen changes, and `teardownAll` must settle or cancel Folder motion immediately. Teardown is idempotent and permits no completion callback to mutate UI afterward.
- Active member drag and move-out presentation use the existing immediate collapse/cleanup path; decorative motion must not delay mouse capture or commit.

### 6. Test seams

- Pure grid tests cover 0/1/5/6/34/35 items, ordinary versus committed-search mode, partial-page row stability, small/current/large regions, and nonzero origins.
- Renderer tests prove explicit mode propagation to new, live, and pooled pages and prove pending query text does not alter committed layout.
- Folder motion exposes read-only transition state/generation and injectable completion scheduling or an equivalent deterministic seam. Tests cover parameters, source conversion/fallback, pointer open/close/reversal, stale completion, A-to-B replacement, refresh without replay, Reduce Motion, keyboard immediate behavior, hide, resize, and teardown.
- Integration tests assert logical close is immediate, drag host returns immediately, no exit visual intercepts events/accessibility, and existing blank-click, drag, focus, search, and Folder behavior remains intact.

## Task DAG

`T-1J-LM-GRID` and `T-1J-LM-MOTION` may run concurrently because their write scopes are disjoint. `T-1J-LM-WIRING` depends on both and runs serially. `T-1J-LM-VERIFY` depends on wiring and owns serialized builds, review evidence, packaging, and GUI gates.

## Risks and stop conditions

- Stop for Chief review if the implementation requires `PagingCore`, persistence/schema, drag-intent, `Package.swift`, or `LauncherWindowController` changes.
- Do not change test fixtures merely to conceal product geometry changes.
- No LaunchBetter/Buho/reverse-evidence reads, commit, push, signing, notarization, publication, installed-app replacement, or destructive packaging.

