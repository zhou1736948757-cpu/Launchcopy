# ADR-007 — Search Presentation (Phase 1D)

- **Status**: **ACCEPTED** (Chief architecture decision transcribed by Main)
- **Date**: 2026-08-30
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` §19 (authoritative)
- **Scope**: how search results are presented over the existing catalog/paging/icon pipeline without forging `CatalogRevision`, without modifying `PagingCore`, and without a parallel launch path.

> This document is Main-exclusive. The architecture decisions below are transcribed from the Chief's Phase 1D planning (subagent 36e74e1e). Decisions are recorded as product/architecture decisions, not "old product did it".

---

## 1. Context

Phase 1D adds local app-name search as an independent presentation slice over the committed `CatalogSnapshot`. Search must reuse the existing paging engine, page reuse, icon pipeline, keyboard focus, and `AppLaunchController` launch validation. The central risk is that query changes look like catalog changes; we must keep `CatalogRevision` owned solely by `CatalogRepository` and express query-driven re-presentation through a narrow same-revision reload seam.

## 2. Decision (transcribed from Chief)

### 2.1 Provider shape: modify existing provider vs search-filtering wrapper
- **Choice**: **Modify existing provider** to hold `baseSnapshot` + `presentationRecords`; `servedRevision` stays `baseSnapshot.revision.value`.
- **Rationale**: keeps single-provider revision ownership so `AppLaunchController`'s stale check and PagingUI pin/latest-wins keep working.

### 2.2 Same-revision reload vs catalog-revision single owner
- **Choice**: **Reject wrapper**; `presentationRecords` is a derived in-memory slice keyed by `(baseCatalogRevision, queryGeneration)`; `servedRevision` stays base revision; new narrow `PagingUI` seam `reloadCurrentPresentation()` re-renders live hosts with the same `servedRevision`.
- **Rationale**: a wrapper would split revision ownership and fight the existing single-provider pin/latest-wins; a presentation-records field is the minimal single-owner change.

### 2.3 Query generation vs catalog revision independence
- **Choice**: `queryGeneration` is a search-controller-internal latest-wins token, fully independent of `baseCatalogRevision`; `AppSearchResultSet` carries both; commit requires latest generation AND latest base revision.
- **Rationale**: query change never touches `CatalogRepository`/`CatalogRevision`; the two axes are orthogonal and both must be latest to write UI.

### 2.4 Busy-state pending vs catalog refresh priority
- **Choice**: catalog refresh (new base revision) has priority over same-revision query reload; both stage at the idle boundary, but a new catalog revision supersedes any older same-revision query result; latest-wins on both axes.
- **Rationale**: a new catalog revision is a stronger truth than a same-revision query result; never let an old same-revision reload override a new catalog revision.

### 2.5 Focus / anchor / pageCount-shrink rules
- **Choice**: anchor = current visible/focused AppID; on query change keep anchor if still in results (located), else successor→predecessor→clamped→empty (mirror `CatalogPlanner.remap`); pageCount shrink clamps legally via existing `setPageCount` (never shrink-then-restore, never rebuild Core); focus never points to an invisible/expired cell.
- **Rationale**: continuity-first; legal clamp preserves PagingCore invariants.

### 2.6 Seven-field ItemBindingToken sufficiency
- **Choice**: **YES, keep 7 fields**; same-revision reload re-renders → surfaceGeneration/reuseGeneration bump + full appID/slot/iconKey rebind → old icon callbacks rejected by generation/token; prove with out-of-order icon callback tests; if tests prove 7 fields insufficient → STOP and flag (no 8th field without Chief decision).
- **Rationale**: re-render + generation bump is the existing stale-icon defense; no contract expansion needed.

### 2.7 Search field vs blank-click window dispatch boundary
- **Choice**: search field/editor/clear button are explicit "interaction zone"; `QuitOnBlankClickWindow.sendEvent` must NOT quit when the hit resolves to the search field (extend `blankClickResolvesToCell` or add a search-field classification); real background blank still quits on first click; no hitTest rewrite (preserves scrollWheel routing).
- **Rationale**: search controls are interactive, not blank; hitTest untouched keeps trackpad paging routing intact.

### 2.8 Why not modify PagingCore
- **Choice**: PagingCore is FROZEN (hard constraint); search is a presentation slice over the committed catalog, not a paging-state change; all search behavior lives in AppGridUI (domain + presentation) + PagingUI (narrow reload seam) + PagingPrototypeApp (responder/assembly).
- **Rationale**: no paging-state mutation; search never touches committedPage/visualOffset/transition token.

### 2.9 Privacy / no-persistence / no-Spotlight
- **Choice**: query raw/normalized/result names NEVER in telemetry/JSONL/stdout/signpost/profile/report; no `PagingTelemetry` schema change (only in-memory neutral counters: query-generation count, result count, stale-rejected count, apply-duration numeric); no persistence (query not restored on reopen); no Spotlight/NSMetadataQuery/rescan — pure in-memory filter of the committed CatalogSnapshot.
- **Rationale**: search is user input; stricter privacy than 1B/1C; no new telemetry contract.

## 3. Consequences

- `AppGridUIPageContentProvider` gains `baseSnapshot` + `presentationRecords` (single-owner change).
- New `PagingUI` seam `reloadCurrentPresentation()` (narrow, same-revision re-render).
- `AppSearchResultSet` carries `(baseCatalogRevision, queryGeneration, records, resultCount)`.
- `QuitOnBlankClickWindow` blank-click classification extended to treat search field as interaction zone.
- No `PagingCore`/`Package.swift`/`AppLaunchController.swift` change; no new Swift target.

## 4. References

- `Docs/PHASE1D_SEARCH_PROMPT.md` §8 (architecture hard constraints), §9 (state model), §15 (worker split), §19 (ADR-007 requirements)
- `Docs/ADR-003-PAGING-CONTENT-PROVIDER.md`, `Docs/ADR-004-APP-CATALOG-SNAPSHOT.md`, `Docs/ADR-005-ICON-PIPELINE.md`, `Docs/ADR-006-KEYBOARD-FOCUS.md`
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `Sources/AppGridUI/ItemBindingToken.swift`, `Sources/PagingUI/PagingSurface.swift`
