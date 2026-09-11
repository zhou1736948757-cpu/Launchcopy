# Review — T-1E-B (top-level composition provider + search flattening + refresh no-repeat/no-miss/no-forge)

- **Reviewer**: T-1E-B-r1 (independent, read-only)
- **Date**: 2026-08-30
- **Task packet**: `Workflow/tasks/T-1E-B.md`
- **Worker result**: `Workflow/results/T-1E-B.md`
- **Scope reviewed**: `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `Sources/AppGridUI/AppGridSearchPresentationController.swift`, `Tests/AppGridUITests/TopLevelCompositionTests.swift` (15), `Tests/AppGridUITests/FolderSearchFlatteningTests.swift` (5). Supporting domain read-only: `Sources/AppGridUI/FolderDomain.swift` (T-1E-A), `Docs/ADR-008-FOLDER-PRESENTATION.md`.

## Verdict: **PASS**

No BLOCKER, no MAJOR. Three documented deviations noted as QUESTION (none block acceptance).

---

## Findings

### BLOCKER
None.

### MAJOR
None.

### MINOR
None.

### QUESTION

- **Q1 — `rebaseFolder` discards the received folder snapshot's own generation.** In `applyPending`, `rebaseFolder` always computes `nextGeneration = (servedFolderSnapshot?.generation ?? .zero).incremented()`, so a received `FolderSnapshot(generation: 5, …)` is committed with generation 1 when served was nil (see `testFolderGenerationIndependentOfCatalogRevision`). This is a deliberate, documented design (rebase assigns a fresh monotonic token from served state; folder generation is independent of `CatalogRevision`). Not a defect — recorded for awareness.
- **Q2 — mixed-composition successor/predecessor ordering uses `hashValue`.** `identityOrder` orders folder-before-app, then same-kind by `hashValue` (runtime-determined). The worker documents this as a deviation; the successor/predecessor degradation paths in a mixed composition are rarely hit and no test depends on a specific order. Acceptable; recorded.
- **Q3 — `AppGridPresentationUpdate` gained a public `topLevelAnchor` field.** Backward-compatible `anchor: AppID?` is preserved; no external consumer constructs the struct (only the provider does). No public-interface break in frozen modules.

---

## Acceptance criteria verification

| Criterion | Result | Evidence |
|---|---|---|
| Top-level composition `[TopLevelEntry]` (app+folder, folder = one slot) | ✅ | `TopLevelComposition.build` (folders first in snapshot order, ungrouped apps after in catalog order); `testEmptyQueryShowsAppsAndFolders`, `testFolderIsOneSlot` |
| Single-member folders dissolved; empty folders removed | ✅ | `TopLevelComposition.build` + `FolderMembership.rebase`; `testSingleMemberFolderDissolves`, `testRefreshRemovesDeletedMembersAndDissolves` |
| Page count = ceil(topLevelEntryCount/itemsPerPage), instance itemsPerPage, 0 entries = 0 pages | ✅ | `servedPageCount` uses `presentationEntries.count` + instance `itemsPerPage`; `testPageCountFromTopLevelEntries`, `testServedPageCountUsesInstanceItemsPerPage` (existing H2 test) |
| Search flattening: app-only, matches app display name only, never folder title | ✅ | `commitPendingSearchResult` non-empty query → `result.records.map { .app }`; matcher only reads `AppRecord.displayName`; `testSearchFlattensToAppOnly`, `testSearchFiltersByAppNameNotFolderTitle` |
| Exiting search restores full composition; no query → no folder-title matching | ✅ | empty query → rebuild from `servedSnapshot`+`servedFolderSnapshot`; `testExitingSearchRestoresComposition` |
| Idle atomic commit (catalog + folder); folder latest-wins | ✅ | `applyPending` commits both atomically; `pendingFolderSnapshot` latest-wins; `testIdleCommitAtomicCatalogAndFolder`, `testFolderLatestWins` |
| No CatalogRevision forged/minted; folder generation independent | ✅ | `servedRevision` always from `servedSnapshot?.revision.value`; folder layer never touches `CatalogRevision`; `testRefreshNoForge`, `testFolderGenerationIndependentOfCatalogRevision` |
| Refresh: removed apps removed from members; new apps ungrouped; no repeat/miss | ✅ | `FolderMembership.rebase` + `TopLevelComposition.build`; latest-wins on `pendingSnapshot`; `testRefreshNoRepeat`, `testRefreshNoMiss`, `testRefreshRemovesDeletedMembersAndDissolves` |
| Anchor/pageIndex on composition; 5-level remap | ✅ | `topLevelAnchorCandidate`/`topLevelPageIndex`; `remapComposition` (app-only delegates to `CatalogPlanner`, mixed uses composition-aware); `testTopLevelAnchorCandidate`, `testTopLevelPageIndex`, `testRemapLocatedForFolderAnchor` |
| Dead `onStateChange` removed (recorded decision) | ✅ | No setter/invoker in `AppGridSearchPresentationController`; remaining `onStateChange` refs are on other types (PagingSurface/PagingCore/AppGridRefreshController) |
| Existing Phase1B/1D provider/search/refresh tests pass (regression) | ✅ | Full suite 709/0 (see evidence) |
| Privacy redline clean | ✅ | No print/telemetry/JSONL/signpost/profile/report/NSEvent/accessibility in modified files; only neutral counters |
| No Buho/LaunchBetter replication; no global NSEvent monitor / Accessibility / Input Monitoring | ✅ | None present in modified files |

---

## Verification evidence (measured)

1. **`swift test` (full suite)** → **709 tests, 0 failures**, exit 0. The XCTest summary line is authoritative: `Executed 709 tests, with 0 failures (0 unexpected)`. The swift-testing line `0 tests in 0 suites` is NOT the real count (it is the separate swift-testing runner with no tests). All 20 new tests (TopLevelComposition 15 + FolderSearchFlattening 5) executed and passed; all existing Phase1B/1D provider/search/refresh tests passed.
2. **`swift build -c debug`** → exit 0 (`Build complete!`).
3. **`swift build -c release`** → exit 0 (`Build complete!`).
4. **Frozen trees untouched**: mtimes of every file in `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Sources/PagingUI/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift` all predate T-1E-B's work window (latest frozen file `PagingUI/PagingFrameDriver.swift` = 15:15:30; T-1E-B files = 16:26–16:28). `Sources/AppGridUI/AppGridUIState.swift` untouched (10:54).
5. **T-1E-C files untouched by B**: `AppGridCellView.swift` (16:24), `AppGridPageView.swift` (16:20), `FolderOpenState.swift` (16:19), `FolderOverlayView.swift` (16:25) — attributed to T-1E-C per `Workflow/events.jsonl` (Worker C wrote these; B's files are 16:26–16:28). No overlap.
6. **Write scope**: T-1E-B wrote only `AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `TopLevelCompositionTests.swift`, `FolderSearchFlatteningTests.swift` (all within allowed scope) + `Workflow/results/T-1E-B.md`. No git operations performed.

---

## Deviation assessment

All deviations are documented in the Worker result §四 and are consistent with the task packet / ADR-008:
- Empty-query search semantics (restore full composition) — matches ADR-008 §2.1/§2.4 and preserves Phase1B/1D behavior when no folders exist.
- Mixed-composition remap identity ordering (folder-before-app, same-kind by hashValue) — documented; app-only path delegates to `CatalogPlanner` for exact existing behavior.
- `PagePlan` constructed via public init (internal records init unavailable cross-module) — verified no consumer uses `appID(page:slot:)`.
- `presentationRecords` retained as `[AppRecord]` app-only projection for frozen consumers — correct.
- `AppGridPresentationUpdate.topLevelAnchor` added with backward-compatible `anchor` — no external constructors.

No unrecorded fixes; the `onStateChange` removal is a recorded Phase 1E decision.

---

## Conclusion

The implementation satisfies the T-1E-B acceptance criteria. Top-level composition, search flattening, page count/anchor/idle-commit/latest-wins, refresh no-repeat/no-miss/no-forge, dead-callback removal, privacy redline, and frozen-tree integrity are all verified. Full suite 709/0, debug and release builds exit 0. **PASS.**
