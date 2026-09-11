# Task Packet: T-1E-C

- **Task ID**: T-1E-C
- **Role**: Worker C (fresh context — must not inherit any old reverse-engineering context)
- **Phase**: 1E — folder cell / thumbnail / open layer
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §6 T-1E-C, §9.4
- **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT — read it; you implement the folder visuals/open layer it describes)

## Objective

Implement the **neutral folder entry visuals and the open layer** (title + member grid + inner paging), with app-vs-folder cell distinction, thumbnail stale defense, inner paging isolated from outer paging, click-outside-closes-folder, Reduce Motion correctness, and teardown zero callbacks.

## Dependencies

- **T-1E-A** (folder domain model, `TopLevelEntry`, folder generation, focus-identity generalization).
- **T-1E-B** (provider produces the top-level composition you render — read-only dependency; you do not write B's files).

## Context

**Fresh Context requirement (source discipline)**: fresh context, no old reverse-engineering context. Never read the forbidden sources (see T-1E-A).

**Key existing seams (read-only)**:
- `AppGridCellView` (48px icon side; `nameLabel`, `iconView`, `bindingToken: ItemBindingToken?`, `bind(name:token:)`, `clearContent()`, `applyIconIfValid(_:token:)`).
- `AppGridPageView` (render builds `ItemBindingToken` with `appID: item.identity`; `iconKey(for:)` returns nil for non-`AppID`; `clearForReuse()`/`teardown()` bump `surfaceGeneration`; `onIconApplyResult`).
- `ItemBindingToken` (7 fields: `catalogRevision`, `pageIdentity`, `itemSlot`, `appID: AnyHashable?`, `reuseGeneration`, `iconKey`, `surfaceGeneration`).
- `AppGridFocusLayout`/`AppGridFocusModel`/`AppGridFocusNavigator` (read-only; focus identity generalized in T-1E-A).

## Scope

- **Folder cell rendering**: a folder entry renders a **neutral independent symbol + title + member count** (not an app-icon collage by default). App cell vs folder cell distinguishable. If a product reason exists for member runtime-icon preview, it must be justified in the ADR, go through the existing async icon pipeline with stale validation, and get a separate visual-source review — do not default to it.
- **No icon request for folders**: `iconKey(for:)` already returns nil for non-`AppID`; ensure folder cells never request app icons.
- **Open layer**: clear hierarchy and hit-test boundary from the top level. Shows title + member grid. Inner paging when members exceed one page. Inner paging must **not** drive/pollute outer paging state.
- **Open-state owner**: which folder is open + its inner page (session-only, not persisted). Open A then open B: A's old callbacks must not overwrite B.
- **Stale defense**: reuse generation / surface generation reject old member-icon callbacks; reuse clears stale folder title/thumbnail/focus; teardown zero callbacks.
- **Click outside open layer** closes the folder only (does not exit app); next real background click exits (wired in T-1E-E).
- **Reduce Motion**: open/close and inner paging reduce large displacement/scale while keeping state correct. Open/close animation params from `PRODUCT_DECISION`/`ACCESSIBILITY_REQUIREMENT`, registered in `PARAMETER_RATIONALE`.
- **Accessibility**: folder entry has explicit role/label/description; open-layer title and member hierarchy understandable; predictable focus order; visual thumbnail never the sole state expression.
- **Tests**: cell/overlay/inner-paging tests (app vs folder not confused; reuse clears title/thumbnail/focus; old member-icon callbacks rejected; overlay open/close idempotent; open A then open B no cross-overwrite; inner paging does not change outer committed page; resize/fullscreen layout legal; Reduce Motion path correct; teardown callback count 0).

## Out of Scope

- Provider / presentation composition (T-1E-B).
- Keyboard / focus controller / title editing (T-1E-D).
- AppDelegate / assembly / launch / blank-click integration (T-1E-E).
- Modifying `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`.
- Drag / persistence / Hot Corner / Spotlight / Launchpad-Dock DB / brand visuals.

## Expected / Allowed Write Scope

- `Sources/AppGridUI/AppGridCellView.swift`
- `Sources/AppGridUI/AppGridPageView.swift`
- New folder overlay/open-layer + open-state files in `Sources/AppGridUI/` (e.g. `FolderOverlayView.swift`, `FolderOpenState.swift`)
- New tests in `Tests/AppGridUITests/` (e.g. `FolderCellTests.swift`, `FolderOverlayTests.swift`, `FolderInnerPagingTests.swift`)

## Forbidden Write Scope

- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridUIState.swift` (T-1E-B's files — read-only).
- `Sources/PagingPrototypeApp/` (all).
- `Sources/PagingUI/` (frozen).
- `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`.
- `Tests/PagingUITests/`, `Tests/PagingCoreTests/` and other teams' test dirs.

## Constraints

- Neutral independent visuals; no Buho/LaunchBetter thumbnail/background/corner/shadow/spacing/animation/copy replication.
- Inner paging never drives/pollutes outer paging.
- No global NSEvent monitor / Accessibility / Input Monitoring.
- Privacy: folder title / membership / identity raw values and icon data **never** enter telemetry/JSONL/stdout/signpost/profile/report; only neutral counters. No PagingTelemetry schema change.
- No commit/push/tag/reset/clean/release; do not modify LaunchBetter / BuhoReverseNotes.
- Diagnostics stay `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`.

## Acceptance

- `FOLDER_OVERLAY_TESTS = PASS`: neutral independent visuals; folder vs app entry distinguishable; thumbnail stale defense; inner paging isolated from outer; click-outside closes folder only; Reduce Motion correct; teardown zero callbacks.
- No app-icon collage by default; no brand replication.
- Privacy redline clean.
