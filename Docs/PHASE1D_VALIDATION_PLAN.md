# Phase 1D — Local App-Name Search Validation Plan

**Task:** T-1D-A..E — local app-name search (search domain + same-revision reload + keyboard/launch/refresh integration) on the independent macOS AppKit paging-launcher prototype.

**Status:** FINAL / AUTOMATED PASS (integrated 2026-08-30). AC1–AC12 verified by independent Reviewers r1 (T-1D-A..E all PASS); **620 tests green** (526 + 94 Phase 1D). Manual GUI gates (search GUI / keyboard / trackpad paging / blank-click regression) remain `NOT_RUN` pending user real full-screen + physical-keyboard acceptance; 120Hz stays `BLOCKED_BY_HARDWARE`.

---

## 1. Scope

- Local app-name search: query raw/normalized folding, literal substring match on folded displayName (never bundleID/path/URL/AppID/icon metadata), result-set paging mirroring CatalogPlanner.
- Same-revision reload: query change re-renders live hosts at the same served CatalogRevision (no CatalogRevision minted/forged); query generation + catalog revision dual-axis latest-wins.
- Keyboard/launch/refresh integration: Command-F / Escape / Down / Return / Enter / responder; launch reuses `AppLaunchController.handleCell` unified validation (no parallel path); search field + blank-click routing.
- Privacy: query raw/normalized/result app names never in telemetry/JSONL/stdout/signpost/profile/report; only in-memory neutral counters.

## 2. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Blank query returns all records; literal substring on folded displayName matches; never bundleID/path/URL/AppID/icon metadata | `AppSearchMatcherTests` (15) + `AppSearchQueryTests` (9) |
| AC2 | Result set carries baseCatalogRevision + queryGeneration; pageCount mirrors CatalogPlanner; isCurrent latest-wins both axes | `AppSearchResultSetTests` (9) |
| AC3 | Query change never touches CatalogRepository/CatalogRevision; presentationRecords = derived in-memory slice | `AppGridUIPageContentProviderSearchPresentationTests` (11) |
| AC4 | Same-revision reload correct in idle/busy/teardown; multiple pending apply latest; new catalog revision outranks old same-revision reload | `PagingSurfaceSearchReloadTests` (14) |
| AC5 | Query never forges CatalogRevision; 7-field ItemBindingToken intact; stale icon apply = 0 or all observably rejected | `PagingSurfaceSearchReloadTests` (out-of-order icon tests) |
| AC6 | Search results 0/1/35/36/multi-page correct | Provider + ResultSet tests |
| AC7 | Command-F / Escape / Down / Return / Enter / responder tests complete | `AppSearchControllerTests` (11) + `AppSearchResponderTests` (5) |
| AC8 | Search field + blank-click routing correct (field/clear button no-quit; real background blank first-click quits) | `AppSearchIntegrationTests` (8) + `BlankClickToQuitTests` (9) |
| AC9 | Launch reuses unified validation path (no parallel path) | `AppSearchIntegrationTests` + existing `KeyboardLaunchTests` |
| AC10 | Privacy redline: no query/result app name in telemetry/log; only neutral counters | Privacy scan + redline tests |
| AC11 | Full Swift tests + Debug/Release build PASS; PagingCore unmodified | `swift test` 620/0; `swift build -c debug/release` exit 0; PagingCore 6 hashes match baseline |
| AC12 | Independent Reviewer PASS per task; no conflict markers/trailing whitespace; no commit/push/tag/reset/clean/release | Reviewers T-1D-A..E r1 all PASS |

## 3. Test Matrix

- `Tests/AppGridUITests/AppSearchQueryTests.swift` (9) — raw/trim/normalized folding, injectable Locale.
- `Tests/AppGridUITests/AppSearchMatcherTests.swift` (15) — blank→all, literal substring, no bundleID/path/URL/AppID/icon match.
- `Tests/AppGridUITests/AppSearchResultSetTests.swift` (9) — generation monotonic, pageCount mirror, isCurrent dual-axis.
- `Tests/AppGridUITests/AppGridUIPageContentProviderSearchPresentationTests.swift` (11) — presentationRecords slice, servedPageCount, commit latest-wins.
- `Tests/AppGridUITests/AppGridSearchPresentationControllerTests.swift` (9) — updateQuery/stage/commit, idle-boundary, uiState.
- `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift` (14) — idle immediate, busy pending, latest-wins, catalog-revision priority, pageCount shrink, out-of-order icon zero-write, teardown zero-callback.
- `Tests/PagingUITests/AppSearchControllerTests.swift` (11) + `AppSearchResponderTests.swift` (5) — Command-F/Escape/Down/Return/Enter/responder.
- `Tests/PagingUITests/AppSearchIntegrationTests.swift` (8) — AppDelegate wiring, blank-click interaction zone, launch reuse.
- `Tests/PagingUITests/BlankClickToQuitTests.swift` (9) — blank/nil/unrelated→not-cell; cell/iconView/nameLabel→cell; search field/clear→interaction zone.

## 4. Privacy Redline

- Query raw/normalized/result app names must **never** enter telemetry, JSONL, stdout, signpost, profile, or report.
- Only in-memory neutral counters: query-generation count, result count, stale-rejected count, apply-duration numeric.
- No PagingTelemetry schema change; no persistence; no Spotlight; pure in-memory filter of committed CatalogSnapshot.

## 5. Verification Commands

```sh
swift build
swift test --filter AppSearch
swift test
swift build -c debug
swift build -c release
```

Gate: `exit_code == 0` AND `executed_tests > 0` (NOT `INVALID_TEST_EXECUTION`).

## 6. Reviewer Focus

- Confirm query never forges CatalogRevision; same-revision reload correct in idle/busy/teardown.
- Confirm 7-field ItemBindingToken rejects old-query icon writeback.
- Confirm launch reuses `AppLaunchController` (no parallel path).
- Confirm privacy redline (no query/result app name in telemetry/log).
- Confirm search field + blank-click routing (field/clear no-quit, real background blank quits).

## 7. Per-Task Acceptance

| Task | Criterion | Verification |
|------|-----------|--------------|
| T-1D-A | Search domain: query folding, literal substring, result-set paging, generation latest-wins | 33 tests (Query 9 + Matcher 15 + ResultSet 9) |
| T-1D-C | Same-revision reload seam: idle/busy/teardown, latest-wins, catalog-revision priority, no CatalogRevision forged | 14 tests (PagingSurfaceSearchReloadTests) |
| T-1D-B | Provider/presentation: presentationRecords slice, servedPageCount, commit dual-axis latest-wins, uiState | 20 tests (Provider 11 + Presentation 9) |
| T-1D-D | AppKit search/responder: Command-F/Escape/Down/Return/Enter, responder, isSearchFieldOrSubview | 16 tests (Controller 11 + Responder 5) |
| T-1D-E | AppDelegate/assembly/blank-click/launch integration: 6 handoff items wired, launch reuse, blank-click interaction zone | 8 tests (AppSearchIntegration) + BlankClickToQuit 9/0 |

## 8. Manual GUI Result

| Gate | Result | User evidence |
|------|--------|---------------|
| `MANUAL_SEARCH_GUI_GATE` | **NOT_RUN** | Pending user real full-screen GUI execution of §17 checklist |
| `MANUAL_SEARCH_KEYBOARD_GATE` | **NOT_RUN** | Pending user physical-keyboard matrix |
| `MANUAL_SEARCH_TRACKPAD_PAGING_GATE_60HZ` | **NOT_RUN** | Pending user real trackpad paging + search cross-page |
| `MANUAL_BLANKCLICK_REGRESSION_GATE` | **NOT_RUN** | Pending user confirmation: search field/clear no-quit, real background blank first-click quits |
| `MANUAL_120HZ_GATE` | **BLOCKED_BY_HARDWARE** | 60Hz panel; no 120Hz evidence |

This is an automated verification result; manual GUI gates remain `NOT_RUN` until the user performs real full-screen + physical-keyboard acceptance. The diagnostic status remains `CAUSALITY_UNRESOLVED`; production Timer defaults remain unchanged.
