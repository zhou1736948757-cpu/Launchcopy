# Phase 1D — Local App-Name Search Specification

**Date:** 2026-08-30
**Status:** FINAL (implemented + reviewed; manual GUI gates NOT_RUN)
**Source:** `Docs/PHASE1D_SEARCH_PROMPT.md` (authoritative, SHA-256 `78a0e5acdc4f082f1f274a94cd11ea93200a150c1c20d94fd87b279e56c00154`)
**Architecture:** `Docs/ADR-007-SEARCH-PRESENTATION.md` (Accepted, 10 decisions)

---

## 1. Overview

Add local app-name search to the independent macOS AppKit paging-launcher prototype. Search is a **presentation slice** over the committed catalog snapshot — it never mutates paging state, never forges a CatalogRevision, and never persists. Query/result app names are privacy-neutral (never in telemetry/log).

## 2. Search Domain (T-1D-A)

- **`AppSearchQuery`**: `raw` + injectable `Locale`; `trimmed` = whitespacesAndNewlines; `normalized` = trim → case/diacritic/width folding; `isEmpty`.
- **`AppSearchMatcher.matches(_:query:)`**: blank query → all records; literal substring on folded displayName; **never** bundleID/path/URL/AppID/icon metadata; no pinyin/fuzzy/ranking.
- **`AppSearchResultSet`**: `AppSearchGeneration` monotonic latest-wins token independent of CatalogRevision; carries `baseCatalogRevision` + `queryGeneration` + records (base order) + `resultCount` + `isEmpty` + `pageCount(itemsPerPage:)` mirroring CatalogPlanner + `isCurrent(latestGeneration:latestRevision:)`; no debug description reverse-outputting AppID.

## 3. Same-Revision Reload (T-1D-C)

- `PagingSurface` gains `pendingSameRevisionReload` (independent of `pendingLatestSnapshot` catalog-revision pending).
- `reloadCurrentPresentation()`: idle/cancelled → apply immediately; tracking/settling/interrupted → only set pending (latest-wins, idempotent).
- `applySameRevisionReload()`: `surfaceGeneration &+= 1` (field-7 gating); legal `core.setPageCount` if servedPageCount differs; explicit `relayoutPages()` (pageCount shrink with unchanged offset doesn't fire Core relayout); `refreshLiveHostContent(effectiveRevisionForPass())` at same servedRevision — never mints/forges CatalogRevision.
- `endInteraction()`: catalog revision (pendingLatestSnapshot) applies first and supersedes same-revision reload (ADR-007 §2.4); else applies pending same-revision reload.
- `teardown()`: clears pendingSameRevisionReload → zero writeback.

## 4. Provider / Presentation (T-1D-B)

- `AppGridUIPageContentProvider` extended: `baseSnapshot` (alias of servedSnapshot), `presentationRecords`, `activeQuery`, `pendingSearchResult` + `hasPendingSearchResult`; `servedPageCount` derives from presentationRecords (0 results = 0 pages); `content(for:)` slices presentationRecords (committed only, never pending); `applyPending` resets presentationRecords to base records on new base commit; `anchorCandidate`/`pageIndex(of:)` use presentationRecords; `stageSearchResult`/`discardPendingSearchResult`/`commitPendingSearchResult(query:)` with latest-wins dual-axis (base revision) validation.
- `AppGridSearchPresentationController` (@MainActor): owns `latestGeneration` (query generation token independent of baseCatalogRevision) + `currentQuery`; `updateQuery` increments generation + filters via T-1D-A matcher + stages; `receive` forwards pendingCatalogSnapshot; `applyPendingAtIdleBoundary` commits at idle boundary (catalog refresh priority → re-run query on new base → commit search result); `uiState` derives loading/empty/noResults/ready; callbacks `onPresentationUpdate`/`onSearchResultCommitted`/`onStateChange`.
- `AppGridUIState` adds `.noResults` neutral state ('No applications match the search', isBusy=false, no query text).

## 5. AppKit Search / Responder (T-1D-D)

- `AppSearchFieldView`: neutral NSSearchField, accessible label 'Search applications', `static isSearchFieldOrSubview(_:)` blank-click interaction-zone classification helper.
- `AppSearchController`: Command-F → field first responder + clears grid focus visual; real-time input → presentation.updateQuery + idle commit; Escape non-empty clears query/keeps field; Escape empty exits/restores KeyboardFocusController (deferred); ↓/Return/Enter transfers focus to first valid result on current page (no launch first time); grid Return/Enter launches via existing onActivate pipeline; Tab not swallowed; no committed results or pending generation → no launch of old results; F3 follow-up via NSWindow.didBecomeKeyNotification rebuilds first responder per state; `commitPendingAtIdleBoundary()` public seam.
- `KeyboardFocusController` minimal: `onSearchShortcut` + Command-F in performKeyEquivalent, `clearFocusForSearch()`, `setFocus(to:)`, commandF keycode.

## 6. Integration (T-1D-E)

- Wire `keyboard.onSearchShortcut = { search.activateSearch() }`.
- Add `search.field` as sibling overlay in window contentView (NOT inside page container).
- `search.install(in: window)` after adding field; `search.teardown()` on teardown.
- Extend `blankClickResolvesToCell` to also return true when `AppSearchFieldView.isSearchFieldOrSubview(hit)`.
- Call `search.commitPendingAtIdleBoundary()` from `surface.onIdleBoundary` (alongside refresh controller).
- Wire `presentation.onSearchResultCommitted` → `surface.reloadCurrentPresentation()`.
- Launch reuses `AppLaunchController.handleCell` unified validation (no parallel path).

## 7. Privacy

- Query raw/normalized/result app names **never** in telemetry/JSONL/stdout/signpost/profile/report.
- Only in-memory neutral counters: query-generation count, result count, stale-rejected count, apply-duration numeric.
- No PagingTelemetry schema change; no persistence; no Spotlight; pure in-memory filter of committed CatalogSnapshot.

## 8. Constraints

- `Sources/PagingCore/`, `Sources/MacAppCatalog/`, `Package.swift`, `AppLaunchController.swift` frozen/forbidden.
- No global NSEvent monitor, no Accessibility, no Input Monitoring, no Spotlight, no disk index, no query persistence.
- Timer tolerance 8.333ms unchanged; diagnostics stay CAUSALITY_UNRESOLVED/PARTIAL_CONTRIBUTOR_SUPPORTED/PRODUCT_DEFAULT_UNCHANGED.
- No git commit/push/tag/reset/clean/release.

## 9. Deliverables

`Docs/ADR-007-SEARCH-PRESENTATION.md`, `Docs/PHASE1D_SPEC.md`, `Docs/PHASE1D_VALIDATION_PLAN.md`, `Docs/PHASE1D_REPORT.md`, `Docs/VALIDATION_RESULTS.md` (append), `Docs/PRIVACY_DATA_MAP.md` (append), `Docs/PARAMETER_RATIONALE.md` (append), `PROVENANCE/COMPONENTS.md` (append), `Workflow/tasks/T-1D-*.md`, `Workflow/results/T-1D-*.md`, `Workflow/reviews/T-1D-*-r*.md`.
