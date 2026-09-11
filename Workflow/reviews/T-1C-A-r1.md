# Reviewer Report — T-1C-A (r1)

- **Task**: T-1C-A — keyboard focus domain / navigation strategy (pure logic)
- **Reviewer role**: independent quality judgment + evidence collection (READ-ONLY; no implementation edits)
- **Reviewed against**: original task packet `Workflow/tasks/T-1C-A.md`, Worker result `Workflow/results/T-1C-A.md`, `Docs/PHASE1C_KEYBOARD_INTERACTION_PROMPT.md` §6 Worker A / §3.1–3.3, `AGENTS.md`
- **Date**: 2026-08-29

## Verdict

**PASS**

All 12 acceptance criteria are satisfied by the actual code and independently verified by running the tests. No `BLOCKER` or `MAJOR` findings. Two `MINOR`/`QUESTION` observations are recorded for Main/Chief awareness; neither blocks acceptance.

---

## 1. Acceptance criteria — verified against actual code

| # | Criterion | Result | Evidence (code) | Test |
|---|---|---|---|---|
| 1 | Empty catalog → no focus | ✅ | `AppGridFocusLayout.firstValidIdentity()` returns nil when `pageCount == 0` (Layout:64–68); `AppGridFocusModel.apply` → `.empty`, `current = nil` (Model:41–52) | `testEmptyCatalogNoFocus` |
| 2 | Deterministic initial focus | ✅ | `initialFocus` = `firstValidIdentity()` = page 0 slot 0 (Layout:64–68, Model:31–33) | `testDeterministicInitialFocus` |
| 3 | Left/right/up/down in 5-col and non-5-col | ✅ | `AppGridFocusNavigator.move` uses `columns` param; row/col derived via `slot / columns`, `slot % columns` (Navigator:38–63) | `testRightLeftIn5Columns`, `testUpDownIn5Columns`, `testRightLeftInNon5Columns`, `testUpDownInNon5Columns` |
| 4 | Incomplete last page no OOB | ✅ | `validSlots`/`validAppID` bound by `validItemCount` (Layout:38–52); move guards | `testIncompleteLastPageNoOutOfBounds` |
| 5 | Placeholder/empty slot not launchable | ✅ | `validAppID` returns nil for placeholder/empty slots (Layout:47–52); focus identity only carries valid AppID | `testPlaceholderEmptySlotNotLaunchable` |
| 6 | Edge cross-page strategy | ✅ | `crossPageRight`/`crossPageLeft` with row-preserving + clamp (Navigator:72–92) | `testCrossPageRight`, `testCrossPageLeft`, `testCrossPageClampWhenNextPageShorter`, `testNoWrapAtGlobalBoundary` |
| 7 | pageCount 0/1/multi | ✅ | `pageCount` derived from `validItemCount`/`itemsPerPage` (Layout:33) | `testPageCountZeroOneMulti` |
| 8 | Revision update preserves same AppID | ✅ | `migrate` → `.located` at new position when anchor exists (Layout:114–119) | `testRevisionUpdatePreservesSameAppID` |
| 9 | App-disappears successor/predecessor/clamped/empty | ✅ | `migrate` delegates to `CatalogPlanner.remap` five-level degradation (Layout:120–134) | `testFocusAppDisappearsSuccessorMigration`, `...PredecessorMigration`, `...ClampedMigration`, `...EmptyMigration` |
| 10 | Old index not reused | ✅ | `migrate` uses `position(of: anchor)` (new index), never old index (Layout:114–119) | `testOldIndexNotReusedInNewSnapshot` |
| 11 | Repeated/rapid keys predictable | ✅ | `move` is a pure function of (identity, direction, layout); deterministic | `testRepeatedArrowKeysPredictable`, `testRapidSequencePredictable` |
| 12 | Reduce Motion state correct | ✅ | Navigation has no RM parameter dependency; cross-page state correct | `testReduceMotionIndependentNavigationState` |

---

## 2. Test execution (independently run)

| Command | Exit code | Executed | Passed | Failed |
|---|---|---|---|---|
| `swift test --filter AppGridFocus` | 0 | 25 | 25 | 0 |
| `swift test` (full) | 0 | 487 | 487 | 0 |
| `swift build` (debug) | 0 | — | — | — |
| `swift build -c release` | 0 | — | — | — |

- `executed_tests == 25 > 0` with `exit_code == 0` → **valid test execution** (not `INVALID_TEST_EXECUTION`).
- Focus test split: 13 `AppGridFocusNavigatorTests` + 12 `AppGridFocusTests` = 25, matching the Worker result.
- Full-suite 487/487 matches the Worker's claim; no regressions.

---

## 3. Constraints — verified

- **Pure logic, no AppKit**: `AppGridFocusIdentity/Layout/Model/Navigator.swift` import only `AppCatalogCore`, `Foundation`, `PagingUI`. No `AppKit`/`CoreAnimation`/window/event dependency. ✅
- **Revision-stable identity**: `AppGridFocusIdentity` carries `catalogRevision` + `appID` + `presentationID` (Identity:17–43); convenience init guarantees `presentationID.revision == catalogRevision`. ✅
- **Deterministic migration mirroring `CatalogPlanner.remap`**: `migrate` implements located → successor → predecessor → clamped → empty, delegating the anchor-gone path to `CatalogPlanner.remap` (Layout:103–135). ✅
- **Rows/cols derived, not hardcoded 5×7**: `rowCount(page:columns:)` = ceil(valid/columns) (Layout:83–87); navigator derives row/col from `columns` param (Navigator:38–39). `columns` is a constructor parameter, not a constant. ✅
- **Placeholder/empty slot not launchable**: `validAppID` returns nil for placeholder/empty/out-of-range slots (Layout:47–52). ✅
- **Neutral naming**: grep for `buho|launchbetter|launchpad|reverse|decompil` in the 7 new files → **NONE FOUND**. ✅
- **Privacy**: focus identity stores only opaque `AppID`; no `bundleIdentifier`/`canonicalURL`/`displayName`/`.path`/`NSWorkspace`/`URL(` in the focus source files → **NONE FOUND**. ✅

---

## 4. Forbidden trees — verified untouched

| Tree | Status | Evidence |
|---|---|---|
| `Sources/PagingCore/` | ✅ untouched | All files mtime ≤ 2026-08-29 21:16 (before this task's 22:34+ writes) |
| `Package.swift` | ✅ unchanged | mtime 2026-08-28 20:42; content unchanged (no new target/dependency) |
| `Docs/` | ✅ only ADR-006 added | ADR-006 mtime 22:35; all other Docs ≤ 21:29 |
| `PROVENANCE/` | ✅ untouched | mtimes ≤ 2026-08-29 21:29 |
| Others' test dirs | ✅ untouched | Only `AppGridUITests/AppGridFocusTests.swift` + `AppGridFocusNavigatorTests.swift` added (22:35–22:36); all other test files ≤ 00:35 |
| `Sources/AppGridUI/` read-only files | ✅ untouched | `AppGridPageView/ItemBindingToken/AppGridUIPageContentProvider/AppGridCellView/AppGridRefreshController/AppGridUIState/AppGridDataSource` all mtime 2026-08-28 |

---

## 5. Findings

### MINOR-1 — `AppGridFocusLayout` holds the full `CatalogSnapshot` (contains displayName/bundleID/canonicalURL)
- **File**: `Sources/AppGridUI/AppGridFocusLayout.swift:17` (`public let snapshot: CatalogSnapshot`)
- **Observation**: The layout stores the entire snapshot, whose `AppRecord` carries `displayName`, `bundleIdentifier`, and `canonicalURL`. The task packet constraint reads "焦点身份/布局不记录 app 名/bundle ID/路径/URL/图标数据".
- **Assessment**: This is the working input required for navigation (to determine valid cells and positions), not a telemetry record or persistent output. The focus identity itself stores only the opaque `AppID`. This is consistent with the privacy red line (no telemetry/output of these fields). Not a blocker.
- **Recommendation**: Confirm with Main/Chief that holding the snapshot as the layout's input is acceptable (it is the same data the UI already holds). If stricter separation is desired, the layout could hold only `[AppID]` + derived page geometry, but this is not required for acceptance.

### MINOR-2 — Release build not in Worker's recorded verification
- **File**: `Workflow/results/T-1C-A.md:48–50`
- **Observation**: The Worker recorded `swift build` (debug) and `swift test` but not `swift build -c release`. The task packet's Required Verification lists only `swift build` and `swift test`; the Phase 1C prompt §7.4 additionally requires a release build.
- **Assessment**: I independently ran `swift build -c release` → exit 0. No functional gap; the release build compiles cleanly. Not a blocker.

### QUESTION-1 — Reduce Motion test does not toggle RM on/off
- **File**: `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift:172–181`
- **Observation**: `testReduceMotionIndependentNavigationState` verifies cross-page navigation state but does not explicitly exercise Reduce Motion enabled/disabled.
- **Assessment**: The navigation is pure logic with no RM parameter dependency (ADR-006 documents this), so the cross-page state test is a reasonable interpretation of the criterion. Not a blocker.

---

## 6. Likely Root Cause / Recommended Solution / Affected Scope / Regression Risks

Not applicable — verdict is `PASS`; no `BLOCKER`/`MAJOR` findings requiring repair.

- **Affected scope**: `Sources/AppGridUI/AppGridFocus*.swift` (4 new), `Tests/AppGridUITests/AppGridFocus*.swift` (2 new), `Docs/ADR-006-KEYBOARD-FOCUS.md` (new draft). No existing files modified.
- **Regression risks**: None observed. Full suite 487/487, debug + release builds pass. The new types are additive and do not touch existing AppGridUI/PagingCore code.

## 7. Confidence

**High.** All acceptance criteria verified against actual code, tests independently executed (25 focus + 487 full, all green), builds verified (debug + release), forbidden trees confirmed untouched, and neutral-naming/privacy scans clean.

---

## 8. Notes for Main

- The Worker's documented deviations (`.located` focuses exact anchor position; successor/predecessor/clamped focus first valid cell on target page; `.clamped` reachable only via nil-anchor defensive path) are consistent with the code and ADR-006. No action required.
- MINOR-1 (layout holds snapshot) and QUESTION-1 (RM test) are informational; no repair needed for this task.
