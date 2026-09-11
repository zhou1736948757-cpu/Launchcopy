# T-1E-D — 键盘 / 焦点 / 标题编辑

- **Task ID**: T-1E-D
- **Role**: Worker D
- **Phase**: 1E — keyboard / focus / title editing
- **ADR**: ADR-008 (ACCEPTED) §2.2/§3 Q10/Q11/§8.1
- **Status**: IMPLEMENTED (verification complete)

## Objective

Implement keyboard/focus/title-editing behavior: Return/Enter open-vs-launch routing, inner
arrows/paging/focus restore, ESC priority, Command-F closes folder then search, title editing
Enter/Escape/focus-loss, key-window responder rebuild, no global listeners.

## Implementation

### Files changed (write scope)

- `Sources/AppGridUI/FolderKeyboardLogic.swift` — **new** (pure logic, no AppKit):
  - `FolderInnerNavigator` — inner member-grid 4-direction navigation + inner cross-page
    (focus/page consistent; mirrors `AppGridFocusNavigator` boundary/cross-page policy).
  - `FolderKeyboardPriority` — `escAction(editingTitle:folderOpen:)` (title-edit → folder →
    top-level) and `commandFAction(folderOpen:)` (close-then-search / search).
  - `FolderFocusRestore` — `position(of:in:itemsPerPage:)` + `restoreTarget(folderIdentity:in:itemsPerPage:revision:)`
    (restore to folder entry; vanished → deterministic first-entry fallback).
  - `FolderTitleEditing` — `resolve(commit:cancel:focusLoss:raw:fallback:)` (Enter commit /
    Escape cancel / focus-loss deterministic commit; normalization via `FolderTitle.normalized`).
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift` — **modified**:
  - New seams (T-1E-E wires): `folderOpenStateProvider`, `onOpenFolder`, `onCloseFolder`,
    `onActivateMember`, `onInnerPageChange`, `folderOverlayProvider`, `onTitleEditRequest`,
    `onTitleCommit`, `onTitleCancel`.
  - `keyDown`/`performKeyEquivalent` route via folder-aware logic: ESC → `handleEscape`
    (priority), arrows → inner (folder open) or top-level, activation → `routeActivation`
    (folder opens / app launches / member launches via `ActivationRouter`).
  - `openFolder`/`closeFolder`/`restoreFocusAfterClose`/`handleInnerArrow`/`activateInnerMember`/
    `applyInnerFocusVisual`/`handleCommandF`/`beginTitleEditing`/`endTitleEditing`.
  - `isEditingTitle` guard: during editing arrows/Return do not launch apps.
- `Sources/PagingPrototypeApp/AppSearchController.swift` — **modified**:
  - New `modeFirstResponderProvider` seam; `rebuildFirstResponder` consults it first
    (title editing > folder open > search > top-level) for key-window rebuild.
- `Sources/PagingPrototypeApp/FolderTitleEditor.swift` — **new** (first-responder NSTextField):
  - Enter commit / Escape cancel / focus-loss deterministic commit; blank fallback + length cap
    via `FolderTitle.normalized`; Tab falls through to AppKit; no disk write, no telemetry.
- `Tests/AppGridUITests/FolderKeyboardLogicTests.swift` — **new** (32 tests).

### Why pure logic lives in AppGridUI (deviation, justified)

`AppGridUITests` depends only on `["AppGridUI", "PagingUI", "AppCatalogCore", "AppIconPipeline"]`
(Package.swift) — it cannot test `PagingPrototypeApp` types. `PagingUITests` (which can) is
forbidden for this task, and `PagingPrototypeAppTests` does not exist and cannot be created
(Package.swift is frozen). Therefore the **testable keyboard/focus/title logic** is placed in
AppGridUI (new files, not T-1E-C's), with thin AppKit responder glue in PagingPrototypeApp.
This satisfies "tests in Tests/AppGridUITests/ … as appropriate" under the hard Package.swift /
PagingUITests constraints.

## Verification

- `swift build -c debug`: exit 0 (zero warnings).
- `swift build -c release`: exit 0.
- `swift test` full suite: **741 tests, 0 failures** (baseline 709 + 32 new; no regression).
  - New: `FolderKeyboardLogicTests` (32): activation routing (folder opens / app launches /
    member launches / nil rejects), inner 4-direction + cross-page + boundaries, ESC priority,
    Command-F close-then-search, focus restore (folder entry / vanished fallback / empty),
    title editing (Enter commit / Escape cancel / focus-loss commit / blank fallback / length cap).
- Frozen trees unchanged: `Sources/PagingCore/`, `AppCatalogCore/`, `MacAppCatalog/`,
  `AppIconPipeline/`, `PagingTelemetry/`, `PagingUI/`, `Package.swift`,
  `Sources/PagingPrototypeApp/AppLaunchController.swift` mtimes all predate this session
  (2026-08-28/29, or 08-30 10:49 for PagingSurface). T-1E-A/B/C files (FolderDomain,
  FolderOpenState, FolderOverlayView, AppGridCellView, AppGridPageView, AppGridUIPageContentProvider)
  predate this session (16:12–16:28 vs my writes 16:36+). No git operations.

## Deviations

- Pure keyboard/focus/title logic placed in AppGridUI (new file) instead of PagingPrototypeApp
  so it is testable by AppGridUITests (see justification above). AppKit responder glue remains in
  PagingPrototypeApp per the task's write scope.
- AppKit-only behaviors (Tab-to-AppKit, key-window rebuild, blank-click two-stage) are implemented
  in the responder glue but not unit-tested in AppGridUITests (target cannot import
  PagingPrototypeApp). Tab falls through to AppKit in both `FolderTitleEditor` (returns false) and
  `KeyboardFocusController` (unhandled keys → `super`). Key-window rebuild is wired via
  `AppSearchController.modeFirstResponderProvider`. Blank-click two-stage is T-1E-E wiring
  (out of scope).

## Privacy

- No folder title / membership / identity raw values in telemetry/JSONL/stdout/signpost/profile/
  report; only neutral counters and decision enums. Title text never written to disk. No
  PagingTelemetry schema change. No global NSEvent monitor / Accessibility / Input Monitoring.
