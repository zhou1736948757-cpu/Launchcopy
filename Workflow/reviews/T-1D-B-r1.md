# Review: T-1D-B — Phase 1D provider/presentation layer

- **Reviewer**: independent reviewer (chef-worker-reviewer-workflow)
- **Task**: T-1D-B (Phase 1D — provider/presentation layer)
- **Date**: 2026-08-30
- **Mode**: READ-ONLY (no implementation file modified)
- **Verdict**: **PASS**

---

## 一、Verdict

**PASS** — implementation is within scope, correct against the task packet, all verification commands pass, and all red lines hold. Two MINOR findings (dead `onStateChange` callback; stale full-suite count in the result doc) and one documented naming deviation; none block acceptance.

---

## 二、Findings

### MINOR-1 — `AppGridSearchPresentationController.onStateChange` is declared but never invoked
- `Sources/AppGridUI/AppGridSearchPresentationController.swift:35` declares `public var onStateChange: ((AppGridUIState) -> Void)?`.
- Grep across `Sources/` + `Tests/` confirms it is **never called** anywhere (the `AppGridRefreshController.onStateChange` at `AppGridRefreshController.swift:37/161` is a separate, pre-existing, correctly-invoked callback).
- The task packet scope lists `onStateChange` as a controller-owned callback, and the worker result (§一) claims it as implemented ("回调 onPresentationUpdate / onSearchResultCommitted / onStateChange"). The claim is not matched by behavior.
- Impact: no test asserts it fires; the state is still derivable via the `uiState` computed property; the assembly layer (T-1D-E, out of scope) is not yet built. Latent gap, not a functional bug in current scope.
- Recommendation: either wire `onStateChange` to fire on state transitions (e.g. after `applyPendingAtIdleBoundary` / commit), or drop it from the claimed contract until T-1D-E consumes it.

### MINOR-2 — Full-suite count in result doc is stale
- Worker result §三.3 reports **593 tests**; actual `swift test` run reports **620 tests, 0 failures**. The review expectation (≥620) is met. The delta (27) is from tests added after the worker's run (e.g. Worker C's `PagingSurfaceSearchReloadTests`). Documentation staleness only, no functional impact.

### MINOR-3 (documented deviation) — `AppGridStatusView.swift` not modified
- Task packet lists `AppGridStatusView.swift` as expected write scope ("新增无结果态中性文本"). Worker left it unchanged because the view is data-driven (`state.accessibilityDescription` / `state.isBusy`), so `.noResults` renders correctly without code change. Verified: `AppGridUIState.noResults.accessibilityDescription = "No applications match the search"`, `isBusy = false`; `AppGridStatusView.updateView` renders the description and hides the spinner for non-busy states. Covered by `testNoResultsStatusViewRendersNeutralText`. Acceptable deviation.

### MINOR-4 (documented deviation) — test file naming
- Task packet lists `AppGridUIPageContentProviderSearchTests.swift`; worker used `AppGridUIPageContentProviderSearchPresentationTests.swift` to satisfy both the `*SearchPresentation*.swift` glob and the `--filter SearchPresentation` command. Both test class names contain "SearchPresentation". No functional impact.

### QUESTION — none outstanding
- No BLOCKER or MAJOR findings.

---

## 三、Scope verification (T-1D-B)

### Provider (`AppGridUIPageContentProvider.swift`)
- `baseSnapshot` = computed alias of `servedSnapshot` ✓ (`:46`)
- `presentationRecords` (committed presentation records) ✓ (`:49`)
- `activeQuery` ✓ (`:51`); `pendingSearchResult` + `hasPendingSearchResult` ✓ (`:53-54`)
- `servedPageCount` derives from `presentationRecords`; 0 results = 0 pages ✓ (`:56-60`)
- `content(for:)` slices `presentationRecords` (committed only, never pending) ✓ (`:162-190`)
- `applyPending` resets `presentationRecords` to base records on new base commit, clears `activeQuery`/`pendingSearchResult` ✓ (`:135-137`)
- `anchorCandidate`/`pageIndex(of:)` use `presentationRecords` (via lightweight `CatalogSnapshot(revision: snapshot.revision, records: presentationRecords)` — reuses base revision, no forged revision) ✓ (`:144-155`)
- `stageSearchResult`/`discardPendingSearchResult`/`commitPendingSearchResult(query:)` with latest-wins dual-axis (base revision) validation ✓ (`:90-112`)

### PresentationController (`AppGridSearchPresentationController.swift`)
- `@MainActor` ✓ (`:18`)
- Owns `latestGeneration` (query generation, independent of `baseCatalogRevision`) + `currentQuery` ✓ (`:26-28`)
- `updateQuery` increments generation + filters (via T-1D-A matcher) + stages ✓ (`:47-56`)
- `receive` forwards pendingCatalogSnapshot ✓ (`:66-68`)
- `applyPendingAtIdleBoundary` commits at idle boundary: catalog refresh priority → re-run query on new base → commit search result ✓ (`:77-90`)
- `uiState` derives loading/empty/noResults/ready ✓ (`:95-102`)
- Callbacks `onPresentationUpdate`/`onSearchResultCommitted` invoked ✓; `onStateChange` declared but NOT invoked (see MINOR-1)

### AppGridUIState
- `.noResults` neutral state: `accessibilityDescription = "No applications match the search"` (no query text), `isBusy = false` ✓ (`:24,34,42`)

### Tests
- `AppGridUIPageContentProviderSearchPresentationTests.swift` — 11 tests ✓
- `AppGridSearchPresentationControllerTests.swift` — 9 tests ✓
- Total 20 ✓

---

## 四、Verification numbers (run by reviewer)

| Command | Result |
|---|---|
| `swift test --filter SearchPresentation` | **20 tests, 0 failures**, exit 0 |
| `swift test` (full suite) | **620 tests, 0 failures**, exit 0 |
| `swift build -c debug` | **exit 0** (Build complete) |
| `swift build -c release` | **exit 0** (Build complete) |

---

## 五、Red-line confirmation

- **NO git commit/push/tag**: confirmed — the repo has **no commits at all** (`git log` exits 128; everything untracked). No commit/push/tag performed.
- **Privacy**: no query raw/normalized/result app names in telemetry/JSONL/stdout/signpost/profile/report. Grep of in-scope files found no `os_log`/`Logger`/`print`/`NSLog`/`signpost`/`Telemetry`/`FileHandle`/`write(`. No `PagingTelemetry` schema change. `AppGridUIState.noResults` text is neutral (no query text). Focus stores opaque AppID only.
- **No global NSEvent monitor / Accessibility / Spotlight / sync I/O / persistence**: grep found none. The only "Accessibility" matches are benign `setAccessibilityRole`/`setAccessibilityLabel` on `AppGridStatusView` (standard AppKit accessibility, not assistive-tech access).
- **Diagnostics**: no `CAUSALITY_UNRESOLVED`/`PARTIAL_CONTRIBUTOR_SUPPORTED`/`PRODUCT_DEFAULT_UNCHANGED` strings introduced in these files (not required in this layer); no diagnostic status changed.
- **No CatalogRevision forged**: `servedRevision` stays `servedSnapshot?.revision.value`; query changes never mint a revision; `commitPendingSearchResult` only validates against the base revision; `anchorCandidate`/`pageIndex` reuse the base revision.

---

## 六、Forbidden-tree confirmation

- Reviewer did **not** modify any file (READ-ONLY).
- File mtimes: all in-scope files are 2026-08-30 10:54–10:55. Forbidden trees are all earlier: `Sources/PagingCore/` (08-29), `Sources/MacAppCatalog/` (08-28), `Sources/PagingPrototypeApp/AppLaunchController.swift` (08-28), `Package.swift` (08-28), `AppGridCellView/AppGridPageView/AppGridRefreshController/ItemBindingToken` (08-28/08-29), T-1D-A files `AppSearchQuery/Matcher/ResultSet` (08-30 10:47, before T-1D-B work). `Sources/PagingUI/` (08-30 10:49) is Worker C's own tree (T-1D-C), modified before T-1D-B's files; consistent with the worker's declaration that PagingUI was not touched by T-1D-B.
- No git baseline exists (repo has no commits), so mtime + worker `AccessDeclaration: NO_PRIOR_EXPOSURE` are the available evidence; both are consistent with forbidden trees being unchanged by T-1D-B.

---

## 七、Deviations summary

1. `AppGridStatusView.swift` not modified (data-driven; acceptable, covered by test).
2. Test file named `AppGridUIPageContentProviderSearchPresentationTests.swift` instead of packet's `AppGridUIPageContentProviderSearchTests.swift` (naming only).
3. `onStateChange` declared but never invoked (MINOR-1).
4. Result doc full-suite count 593 vs actual 620 (stale; MINOR-2).
