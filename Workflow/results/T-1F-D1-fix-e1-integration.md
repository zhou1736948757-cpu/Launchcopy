# T-1F-D1-fix-e1-integration — Worker result

Status: complete

## Root cause confirmation

Confirmed exactly per packet:
- `Sources/PagingPrototypeApp/AppDelegate.swift` onCommit (was :547-549) only staged `sessionLayout = newLayout`; the committed layout was never applied to the provider/rendering → grid never re-rendered → reorder and createFolder had no visible effect (user defect 2).
- `AppGridUIPageContentProvider` had no apply-layout API: `presentationEntries` is `private(set)`, derived from `TopLevelComposition.build` (folders first, ungrouped apps in catalog order) — cannot represent `layout.topLevelOrder` (arbitrary interleaving) or reorder of ungrouped apps.
- Additional finding (verified in `Sources/PagingUI/PagingSurface.swift:609-625`): `refreshPresentation()` only applies when `latest != servedRevision`; a layout commit keeps the same catalog revision, so the re-render is delivered by `setPageCount` → `refreshLiveHostContent` (PagingSurface.swift:252-259), which always re-requests content from the provider. `applyPresentationUpdate(update, overridePageCount: true)` therefore re-renders the grid in the new order — no extra seam needed.

## Changes

1. `Sources/AppGridUI/AppGridUIPageContentProvider.swift` — new public API (Fix 2a):
   `@discardableResult public func applyCommittedLayout(_ layout: PersistentWorkspaceLayout, atCurrentPage currentPage: Int, itemsPerPage: Int) -> AppGridPresentationUpdate?`
   - Resolves `layout.topLevelOrder` against `servedSnapshot` (`PersistentAppReference.matches(record:)` → `AppRecord`; `FolderID` → `PersistentFolderRecord` → `FolderEntry` with members resolved to `AppID`); unresolvable entries/members skipped.
   - Sets `presentationEntries` (layout order), `presentationRecords` (app-only projection), `servedFolderSnapshot` (`FolderSnapshot` from `layout.folders`, generation incremented from served).
   - pageCount = ceil(count/itemsPerPage) (0 for empty); currentPage clamped against old page count before anchor recording; reuses `topLevelAnchorCandidate` + `remapComposition` (five-level degradation); `plan.snapshotRevision = servedSnapshot.revision`; clears search state (`activeQuery`/`pendingSearchResult`); nil if `servedSnapshot` nil. Served catalog unchanged (no CatalogRevision mint/forge).

2. `Sources/PagingPrototypeApp/AppDelegate.swift` (Fix 2b):
   - New `private var layoutStore: LayoutStore?`; created at startup in `installContentAssembly` with production implementation `LayoutStoreActor(storeDirectory:)` + `ApplicationSupportLayoutStoreDirectory(subdirectoryName: "PagingPrototypeLayout")` (init signature verified: `LayoutStoreActor(storeDirectory:io:retrySchedule:flushTimeout:)` with defaults); directory resolution failure falls back to temp dir (persist path stays alive, no crash).
   - `onCommit` body replaced: (1) `sessionLayout = newLayout`; (2) guard provider + surface → `provider.applyCommittedLayout(newLayout, atCurrentPage: surface.core.committedPage, itemsPerPage: surface.itemsPerPage)`; (3) if update non-nil → `applyPresentationUpdate(update, overridePageCount: true)` (existing machinery: refreshPresentation, setPageCount → live-host re-render, telemetry, focus layout rebuild via `keyboardController?.applyLayout`); (4) async persist `Task { await layoutStore?.enqueue(newLayout) }` (non-blocking, coalescing sink).
   - `teardownAll`: also `layoutStore = nil`.

3. New tests (existing tests untouched):
   - `Tests/AppGridUITests/AppGridUIPageContentProviderApplyCommittedLayoutTests.swift` — 6 unit tests: reorder re-renders in layout order; createFolder shows folder cell with A+B members; unresolvable entries skipped; nil without served snapshot; pageCount + currentPage clamp (40 items/35 per page → 2 pages, out-of-range page clamps to last page anchor); folder generation increments across commits.
   - `Tests/PagingUITests/DragCommitIntegrationTests.swift` — 2 integration tests using the existing seam-driven harness (FakeAppFactory + AppCatalogAssembly + wireAssembly + DragUISessionCoordinator, onCommit wired identically to production): (1) real drag reorder → commit seam → provider presentation == committed layout order, content(for:) serves new order, surface pageCount consistent, layoutProvider == sessionLayout, layout persisted to LayoutStoreActor (flush barrier + fresh-instance load round trip), moved cell click still launches; (2) createFolder commit → folder cell with A+B members in servedFolderSnapshot, folder cell click still opens, layout persisted round trip.

## Verification evidence

- `swift build -c debug` → exit 0 (Build complete).
- `swift test` (full suite) → exit 0; **Executed 1005 tests, 0 failures** (baseline 997 all green + 8 new tests green; no out-of-scope failures).
- `swift build -c release` → exit 0 (Build complete).
- Targeted runs before full suite: provider unit tests 6/6 green; integration tests 2/2 green.

## Acceptance mapping (user defect 2)

- Drag reorder of two top-level apps → grid re-renders in new order after drop: covered by `testDragReorderCommitReRendersAndPersists` (presentation + content(for:) == committed layout order) and `testReorderReRendersInLayoutOrder`.
- Drag A onto B (createFolder) → folder cell containing A+B after drop: covered by `testCreateFolderCommitShowsFolderCellAndPersists` and `testCreateFolderShowsFolderCellWithMembers` (folder entry members == A+B; servedFolderSnapshot same source as renderer).
- Committed layout enqueued to LayoutStore, no crash: covered by both integration tests (enqueue → flush barrier → fresh-instance load round trip preserves topLevelOrder and folder members).
- After commit, clicking moved cells still works: covered by `testDragReorderCommitReRendersAndPersists` (moved cell click → launch pipeline, 1 open) and `testCreateFolderCommitShowsFolderCellAndPersists` (folder cell click → opens); layoutProvider == sessionLayout keeps drag/click resolution consistent.

## Risks

- Same-revision re-render relies on `setPageCount` → `refreshLiveHostContent` (verified); no surfaceGeneration bump on commit — in-flight icon applies from before the commit could theoretically land on a re-rendered cell (icon cache makes this benign in practice; the search path uses `reloadCurrentPresentation()` for the same class of operation). Flagged for Reviewer; not in packet scope.
- A pending catalog snapshot applied at the next idle boundary rebuilds composition via `TopLevelComposition.build` (layout order not yet the composition source) — T-1F-E (provider/persist integration) is the designated owner of that path; this task leaves pending catalog state untouched per packet.
- Folder with zero resolvable members is kept as an empty folder entry (literal packet reading: only unresolvable entries skipped); mutation engine invariants make this unreachable in practice.
- Store directory resolution failure falls back to temp dir (defensive; Application Support resolution is expected to succeed on macOS).

## Privacy

Neutral counters only; no app names/bundle IDs in this report. Test fixtures use neutral `fixture.*` names and fixed UUIDs; store tests use per-test temp roots.
