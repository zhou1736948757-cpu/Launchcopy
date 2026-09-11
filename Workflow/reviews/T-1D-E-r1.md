# Review: T-1D-E — 搜索装配 / 空白点击 / 启动集成

- **Task ID**: T-1D-E
- **Reviewer**: independent Reviewer (read-only; no implementation files edited)
- **Verdict**: **PASS**
- **Reviewed against**: `Workflow/tasks/T-1D-E.md` (authoritative scope) + `Workflow/results/T-1D-E.md` (worker result) + actual source/tests.

## 1. Scope Reviewed

- `Sources/PagingPrototypeApp/AppDelegate.swift` (search wiring + blank-click interaction zone)
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` (search wiring only)
- `Tests/PagingUITests/AppSearchIntegrationTests.swift` (8 tests)
- `Tests/PagingUITests/BlankClickToQuitTests.swift` (extended +3)

Frozen trees (`Sources/PagingCore/`, `Sources/PagingUI/`, `Sources/AppGridUI/`, `Sources/MacAppCatalog/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`) were **not read** (per instruction) and confirmed unchanged via mtime.

## 2. Six Handoff Items — Verified in Code

| # | Item | Location | Status |
|---|------|----------|--------|
| 1 | `keyboard.onSearchShortcut = { search.activateSearch() }` | `AppDelegate.swift:377-379` | ✅ |
| 2 | `search.field` as sibling overlay in window contentView (NOT inside page container) | `AppDelegate.swift:190-202` (container `NSView`; `surface` + `field` both subviews; field not child of surface) | ✅ |
| 3 | `search.install(in: window)` after adding field; `search.teardown()` in teardownAll | `AppDelegate.swift:201` (after `container.addSubview(field)` L200); `teardownAll` L545 `search?.teardown()` | ✅ |
| 4 | `blankClickResolvesToCell` returns true when `AppSearchFieldView.isSearchFieldOrSubview(hit)` | `AppDelegate.swift:604-617` (search check first, then superview-chain cell check) | ✅ |
| 5 | `search.commitPendingAtIdleBoundary()` from `surface.onIdleBoundary` (and onStateChange); search commit BEFORE refresh controller | `AppDelegate.swift:297-302` (onIdleBoundary), `307-314` (onStateChange), `412-422` (`applyPendingAtIdleBoundary`: search L418 before refresh L420) | ✅ |
| 6 | `presentation.onSearchResultCommitted` → `surface.reloadCurrentPresentation()` | `AppDelegate.swift:359-361` | ✅ |

### Additional wiring verified
- **idle-boundary ordering (search-first) vs refresh latest-wins**: `applyPendingAtIdleBoundary` calls `search.commitPendingAtIdleBoundary()` before `refreshController.applyPendingAtIdleBoundary()`. Rationale (search presentation applies pending catalog snapshot + re-runs query on new base; refresh-first would clear `pendingSearchResult`) is sound and exercised by `testRefreshRerunsQueryOnNewBase` (passed). No regression to refresh latest-wins observed.
- **`presentation.onPresentationUpdate` urlResolver consistency**: `AppDelegate.swift:365-372` updates `urlResolver` from `dataSource.currentSnapshot` before applying — same source as the refresh-controller path (`AppCatalogAssembly.swift:342-349`). Consistent.
- **Search-field click not misclassified as blank-quit**: `isSearchFieldOrSubview` (`AppSearchFieldView.swift:37-47`) covers field itself, subviews (clear button), and field editor (NSTextView whose delegate is NSSearchField). Real background blank still quits (`testBlankClickOnRealBackgroundQuits` passed).
- **Launch reuses `AppLaunchController.handleCell` (no parallel path)**: `AppSearchController` holds no launcher reference; the only launch path in `AppDelegate` is `launchController` via `keyboard.onActivate → launchAdapter.activate`. `testSearchLaunchReusesHandleCell` asserts `launcher.opened == [Beta]` and `outcomeCounts[.launched] == 1` through the unified funnel. No parallel launch path.

## 3. Verification Numbers (run by Reviewer)

| Command | Result |
|---------|--------|
| `swift test --filter AppSearchIntegration` | **8 tests, 0 failures** |
| `swift test --filter BlankClickToQuit` | **9 tests (6 original + 3 search-field), 0 failures** |
| `swift test` (full suite) | **620 tests, 0 failures, exit 0** |
| `swift build -c debug` | **exit 0** |
| `swift build -c release` | **exit 0** |

## 4. Red-Line Confirmation

- **No git commit/push/tag**: `git status` shows "No commits yet", all files untracked. No history exists. ✅
- **Privacy — no query/result name leakage**: grep of worker-E files for `displayName`/`currentQuery`/`raw`/`appName` co-located with telemetry/log/print/signpost/profile/report → **no matches**. `PagingTelemetryBridge.swift` mtime 2026-08-28 21:47 (untouched by Worker E) → **no PagingTelemetry schema change**. Focus stores opaque AppID only. ✅
- **No global NSEvent monitor / Accessibility / Spotlight**: grep for `addGlobalMonitorForEvents`/`addLocalMonitorForEvents`/`AXIsProcessTrusted`/`AXUIElement`/`NSMetadataQuery`/`kMDItem`/`MDQuery` → only one **comment** in `AppDelegate.swift:571` explicitly stating the global monitor is NOT used. No Accessibility, no Spotlight. ✅
- **No sync I/O / no persistence of query/result**: grep of search files for `FileHandle`/`write(toFile`/`Data(contentsOf`/`UserDefaults`/`.write(` → no matches. ✅
- **Diagnostics unchanged**: no new `CAUSALITY_UNRESOLVED`/`PARTIAL_CONTRIBUTOR_SUPPORTED`/`PRODUCT_DEFAULT_UNCHANGED` claims or hitch-fix declarations in worker-E files. Frame Timer tolerance unchanged (`?? (1.0 / 120.0)` = 8.333ms, `AppDelegate.swift:100`). ✅
- **No CatalogRevision forged**: worker-E files contain no `CatalogRevision(` construction; focus layout uses `CatalogSnapshot(revision: base.revision, records: presentationRecords)` (served revision), consistent with `firstValidResultOnCurrentPage`. ✅
- **Forbidden trees unchanged**: mtimes of frozen trees (PagingCore 08-29 21:16, PagingUI 08-30 10:49, AppGridUI 08-30 10:54, MacAppCatalog 08-28 21:01, Package.swift 08-28 20:42, AppLaunchController 08-28 21:46) all predate Worker-E files (AppDelegate 08-30 11:17, AppCatalogAssembly 08-30 11:16). ✅
- **No forbidden-source/brand/private-API reference**: grep for `BuhoReverseNotes`/`LaunchBetter`/`2026-08-25-buho-launchpad-reverse` in `Sources/`+`Tests/` → no matches. ✅
- **Launch tests headless-safe**: `RecordingLauncher` (`AppLaunchControllerTests.swift:19-34`) is a fake `AppLaunching` that records URLs and never opens a real bundle; `FakeAppFactory`/`RecordingIconLoader` use temp dirs, never `/Applications`. Real GUI launch is a manual acceptance item (not unit-test scope) — correctly documented. ✅

## 5. Findings

- **MINOR** — Deviation #1 (worker result §6.1): field-editor classification is not a standalone `BlankClickToQuitTests` case; it is covered by integration test `testBlankClickOnSearchFieldDoesNotQuit` (activates search → asserts `blankClickResolvesToCell(editor)`). Coverage is equivalent and the test passes. Acceptable; no functional gap.
- **MINOR** — Deviation #2 (worker result §6.2): `AppCatalogAssembly` gains a `public let searchPresentation` property (created in `init` from `provider`). This is the minimal seam to make the assembly layer the search-presentation composition root, within the "仅搜索接线" scope. No other assembly logic touched. Acceptable.
- **QUESTION** — idle-boundary ordering (search-first) vs refresh latest-wins: the design is sound and verified by `testRefreshRerunsQueryOnNewBase` (query re-runs on new base after refresh). No issue found; flagged only for Chief/Main awareness of the ordering dependency on `AppGridSearchPresentationController.applyPendingAtIdleBoundary` (frozen tree, not read).

## 6. Deviations from Packet

- The two deviations above (field-editor test placement; `searchPresentation` property) are both MINOR, documented by the worker with rationale, and verified acceptable. No BLOCKER/MAJOR findings.

## 7. Conclusion

All 6 handoff items correctly wired; all red lines hold; all verification commands pass (620 tests / 0 failures; debug & release builds exit 0). **Verdict: PASS.**
