# Task Packet: T-1E-B

- **Task ID**: T-1E-B
- **Role**: Worker B (fresh context — must not inherit any old reverse-engineering context)
- **Phase**: 1E — top-level composition / provider
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §6 T-1E-B, §9.3
- **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT — read it; you implement the unified top-level composition it describes)

## Objective

Extend the existing `AppGridUIPageContentProvider` to present a **neutral top-level composition** of app entries + folder entries (per ADR-008 §2.1), with search flattening to app-only, correct page count/anchor/idle-commit/latest-wins, and refresh that never repeats/misses/forges a `CatalogRevision`. Existing Phase1B/1D provider tests must keep passing (behavior preserved).

## Dependencies

- **T-1E-A** (folder domain model, `TopLevelEntry`, folder generation, lab fixture, focus-identity generalization).
- **T-1E-H2-repair** must have passed review before you start (it fixes `servedPageCount` to use instance `itemsPerPage`; your file overlaps it — serialize on `AppGridUIPageContentProvider.swift`).

## Context

**Fresh Context requirement (source discipline)**: fresh context, no old reverse-engineering context. Never read the forbidden sources (see T-1E-A).

**Key existing seams (read-only)**:
- `AppGridUIPageContentProvider` (196 lines): `servedSnapshot`/`baseSnapshot`/`servedRevision`/`presentationRecords: [AppRecord]`/`activeQuery`/`pendingSearchResult`/`servedPageCount`/`pendingSnapshot`/`applyPending`/`anchorCandidate`/`pageIndex(of:)`/`content(for:itemsPerPage:)`/`placeholderContent(for:)`/`defaultItemsPerPage = 35`.
- `AppGridSearchPresentationController` (121 lines): `latestGeneration`/`currentQuery`/`updateQuery`/`clearQuery`/`receive`/`applyPendingAtIdleBoundary`/`uiState`/callbacks `onPresentationUpdate`/`onSearchResultCommitted`/`onStateChange` (**dead** — never invoked).
- `AppGridUIState`: `.loading/.ready/.empty/.partialFailure/.refreshing/.noResults`.
- `AppGridFocusLayout`/`AppGridFocusModel`/`AppGridFocusNavigator` (read-only; focus identity generalized in T-1E-A).

## Scope

- Change the provider's committed presentation to a **top-level composition** (`[TopLevelEntry]`), per ADR-008 §2.1. Each folder = one slot; members not duplicated at top level.
- **Search flattening**: when search is active, the presentation is app-only (members flattened); search filters by app display name only, never folder title. Exiting search restores the full top-level composition.
- **Page count**: `servedPageCount` derives from the top-level entry count (0 entries = 0 pages; `ceil(count/itemsPerPage)`), using the instance `itemsPerPage` (H2-repair baseline).
- **Anchor / pageIndex**: operate on the top-level composition; anchor is a stable top-level entry identity (app `AppID` or folder `FolderID`); `CatalogPlanner.remap` 5-level degradation applies to the composition.
- **Idle commit / latest-wins**: busy → stage only; idle boundary → atomic commit. Multiple refresh / latest query / latest folder generation → only the latest commits.
- **Refresh**: new catalog snapshot still assigned by the existing revision owner; folder layer never forges `CatalogRevision`; removed apps removed from members; new apps enter top-level ungrouped; empty folders removed; **single-member folders dissolve to the member app entry** (per ADR-008 §2.4, user decision 2026-08-30); no repeat/miss/stale.
- **Recorded cleanup**: remove the dead `onStateChange` callback from `AppGridSearchPresentationController` (nothing sets it, nothing invokes it; no behavior change). This is a recorded Phase 1E decision, not an unrecorded fix.
- **Tests**: provider/presentation tests for top-level composition, search flattening, page count/anchor/idle commit/latest-wins, refresh no-repeat/no-miss/no-forge. Existing Phase1B/1D provider tests must keep passing (update them only where the internal type changed, preserving observable behavior).

## Out of Scope

- Folder cell rendering / overlay / open layer (T-1E-C).
- Keyboard / focus controller / title editing (T-1E-D).
- AppDelegate / assembly / launch / blank-click integration (T-1E-E).
- Modifying `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`.
- Drag / persistence / Hot Corner / Spotlight / Launchpad-Dock DB / brand visuals.

## Expected / Allowed Write Scope

- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`
- `Sources/AppGridUI/AppGridSearchPresentationController.swift`
- `Sources/AppGridUI/AppGridUIState.swift` (only if needed)
- New provider/presentation tests in `Tests/AppGridUITests/` (e.g. `TopLevelCompositionTests.swift`, `FolderSearchFlatteningTests.swift`)

## Forbidden Write Scope

- `Sources/AppGridUI/AppGridCellView.swift`, `AppGridPageView.swift`, folder overlay/open-layer views (T-1E-C's files — read-only).
- `Sources/PagingPrototypeApp/` (all).
- `Sources/PagingUI/` (frozen).
- `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`.
- `Tests/PagingUITests/`, `Tests/PagingCoreTests/` and other teams' test dirs.

## Constraints

- Folder generation, search generation, and surface generation never impersonate each other.
- Never mint/forge a `CatalogRevision`; catalog revision single source = existing owner.
- No stale writeback to old pages/cells; the layer the user sees is consistent at the commit boundary.
- Privacy: folder title / membership / identity raw values and icon data **never** enter telemetry/JSONL/stdout/signpost/profile/report; only neutral counters. No PagingTelemetry schema change.
- No commit/push/tag/reset/clean/release; do not modify LaunchBetter / BuhoReverseNotes.
- Diagnostics stay `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`.

## Acceptance

- `TOP_LEVEL_COMPOSITION_TESTS = PASS`: empty-query shows apps+folders; search shows flattened apps; page count/anchor/idle commit/latest-wins correct; refresh no-repeat/no-miss/no-forge.
- Existing Phase1B/1D provider tests keep passing (behavior preserved).
- Dead `onStateChange` removed (recorded decision).
- Privacy redline clean.
