# T-1F-D1-fix-e1-integration — Review r1

Status: PASS

Reviewer: independent read-only verification. No code modified.

## 1. applyCommittedLayout (Fix 2a) — PASS

`Sources/AppGridUI/AppGridUIPageContentProvider.swift:252-307`:
- Guards `servedSnapshot` nil → returns nil (no-op) ✓
- Resolves `layout.topLevelOrder` against served snapshot: `.app(ref)` → `served.records.first(where: ref.matches(record:))`; `.folder(folderID)` → resolved `FolderEntry`; unresolvable entries skipped ✓
- Folder members resolved to AppIDs via `ref.matches(record:)`, unresolvable members skipped; folder kept even with empty members (literal packet reading) ✓
- Sets `presentationEntries` (layout order), `presentationRecords` (app-only projection via `appOnlyProjection`), `servedFolderSnapshot` (FolderSnapshot from `layout.folders`, generation incremented from served) ✓
- pageCount = ceil(count/itemsPerPage) via `remapComposition` (empty → 0, non-empty ≥ 1) ✓
- currentPage clamped against OLD page count before anchor recording (`min(max(currentPage,0), oldPageCount-1)`) ✓
- Reuses `topLevelAnchorCandidate` + `remapComposition` (five-level degradation; app-only delegates to CatalogPlanner) ✓
- `plan.snapshotRevision = served.revision`; served catalog unchanged (no revision mint/forge); search state cleared ✓

## 2. onCommit wiring (Fix 2b) — PASS

`Sources/PagingPrototypeApp/AppDelegate.swift:557-577`:
- `sessionLayout = newLayout` staged first ✓
- guard provider + surface; `provider.applyCommittedLayout(newLayout, atCurrentPage: surface.core.committedPage, itemsPerPage: surface.itemsPerPage)` ✓
- non-nil update → `applyPresentationUpdate(update, overridePageCount: true)` (refreshPresentation + setPageCount + telemetry + keyboard focus layout rebuild) ✓
- `Task { await self.layoutStore?.enqueue(newLayout) }` — non-blocking, coalescing sink ✓
- `layoutStore` created at startup (`installContentAssembly`, :440-443): `LayoutStoreActor(storeDirectory:)` (init verified: `storeDirectory:io:retrySchedule:flushTimeout:` with defaults) + `ApplicationSupportLayoutStoreDirectory(subdirectoryName: "PagingPrototypeLayout")` with temp-dir fallback ✓
- `teardownAll` (:965): `layoutStore = nil` (sessionLayout already reset at :964) ✓
- Worker's additional finding verified: `setPageCount` → `refreshLiveHostContent` (PagingSurface.swift:252-259) always re-requests content, so same-revision re-render is delivered; `refreshPresentation` alone is revision-gated (:609-625) ✓

## 3. Write scope — PASS

No git baseline exists (repo has zero commits; all files untracked), so scope verified by mtime forensics:
- Changed: AppDelegate.swift (15:39:51), AppGridUIPageContentProvider.swift (15:39:39), 2 new test files (16:04-16:05) — only files modified after worker session start
- Frozen trees untouched: newest file in PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI = 2026-08-30 15:15:30; Package.swift 2026-08-28; AppLaunchController.swift 2026-08-28
- Docs/PROVENANCE newest = 2026-08-31 01:52:24 (pre-worker) — untouched
- Existing tests newest = 2026-08-31 09:41:47 (prior task) — untouched
- No git operations: no commits, no staged changes

## 4. Privacy — PASS

- No print/log in new onCommit body or applyCommittedLayout
- Telemetry path (`recordCatalogPresentation`, PagingTelemetryBridge.swift:153-163) records only neutral numerics (snapshotRevision, scan/refresh duration ms)
- Test fixtures: neutral `fixture.*` bundle IDs, fixed UUIDs, per-test temp store roots; worker report contains no app names/bundle IDs/paths

## 5. Tests — PASS (meaningful)

- `testReorderReRendersInLayoutOrder`: reorder → presentation + content(for:) in committed order, revision unchanged
- `testCreateFolderShowsFolderCellWithMembers`: folder cell with A+B members, generation 1, app-only projection
- `testUnresolvableEntriesSkipped` / `testNoServedSnapshotReturnsNil` / `testPageCountAndCurrentPageClamp` (40/35 → 2 pages, page 99 clamps to anchor) / `testFolderGenerationIncrementsAcrossCommits`
- `testDragReorderCommitReRendersAndPersists`: real pointer drag → commit seam → presentation == committed order, content serves new order, pageCount 1, layoutProvider == sessionLayout, LayoutStore flush/load round trip, moved-cell click launches (1 open)
- `testCreateFolderCommitShowsFolderCellAndPersists`: folder cell A+B in servedFolderSnapshot, folder click opens, store round trip preserves topLevelOrder + members

## Verification evidence

- `swift build -c debug` → exit 0 (Build complete)
- `swift test` (full suite) → exit 0; **Executed 1005 tests, 0 failures (0 unexpected)**; 8 new tests (6 provider + 2 integration) all passed within the run; no failure lines in log
- `swift build -c release` → exit 0 (Build complete)

## MINOR notes (non-blocking)

1. First `swift test` attempt exited 1 (transient; no failure lines in visible tail — consistent with .build lock contention after the debug build). Retry per packet guidance passed cleanly with the exact expected count (1005/0).
2. Integration tests replicate the onCommit wiring isomorphically in a seam-driven harness (standard repo pattern) rather than invoking AppDelegate directly; production wiring verified by direct code read.
3. Worker's flagged risk (same-revision re-render depends on setPageCount → refreshLiveHostContent; in-flight icon applies could theoretically land on re-rendered cells) is accurate and benign (icon cache); out of packet scope.
