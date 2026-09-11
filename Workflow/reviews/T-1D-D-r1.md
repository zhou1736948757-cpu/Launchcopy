# Review — T-1D-D (Phase 1D AppKit search UI / responder layer)

- **Reviewer**: independent (read-only; no implementation files edited)
- **Task packet**: `Workflow/tasks/T-1D-D.md` (authoritative)
- **Worker result**: `Workflow/results/T-1D-D.md`
- **Verdict**: **PASS**

## Scope reviewed

- `Sources/PagingPrototypeApp/AppSearchFieldView.swift` (NEW)
- `Sources/PagingPrototypeApp/AppSearchController.swift` (NEW)
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (minimal change)
- `Tests/PagingUITests/AppSearchControllerTests.swift` (11)
- `Tests/PagingUITests/AppSearchResponderTests.swift` (5)

## Verification numbers (run by reviewer)

| Check | Result |
|---|---|
| `swift test --filter AppSearch` | **57 tests, 0 failures** (16 new T-1D-D: 11 controller + 5 responder, all pass) |
| `swift test` (full) | **620 tests, 0 failures** |
| `swift build -c debug` | **exit 0** |
| `swift build -c release` | **exit 0** |
| Conflict markers in in-scope files | none |
| Trailing whitespace in in-scope files | none |

Note on the filter count: the worker reported 49 for `--filter AppSearch`; the reviewer measured 57. The +8 are `AppSearchIntegrationTests` (T-1D-E) that landed after the worker's result (events log: worker completed 11:11 with full suite 609/0; full suite is now 620/0). The 16 new T-1D-D tests are present and pass. The worker's 49 was accurate at write time.

## Findings

### BLOCKER
- None.

### MAJOR
- None.

### MINOR
- **M1 — Stale filter count in worker result.** Worker reported `--filter AppSearch` = 49; reviewer measured 57. Root cause: 8 `AppSearchIntegrationTests` from T-1D-E landed after the worker's result. Not a T-1D-D defect; the 16 new T-1D-D tests are present and pass. (Evidence: `Workflow/events.jsonl` worker_completed 11:11 full suite 609/0; reviewer full suite 620/0.)
- **M2 — `isSearchFieldOrSubview` is slightly over-broad.** `AppSearchFieldView.swift:41` returns true for the field editor of *any* `NSSearchField` (delegate is `NSSearchField`), not strictly `AppSearchFieldView`. Since the app owns a single search field, this is acceptable for the blank-click interaction-zone classification, but the predicate is not scoped to `AppSearchFieldView` instances. No functional impact today.

### QUESTION
- **Q1 — Field text/query retained after focus transfer.** `AppSearchController.transferFocusToFirstResult` (`AppSearchController.swift:148-157`) transfers focus to the grid but does not clear the field text or the query, so results stay filtered after ↓/Return. The spec does not require clearing; confirm this is the intended UX (query persists while grid has focus).
- **Q2 — `committedPage` vs transient displayed page.** `firstValidResultOnCurrentPage` (`AppSearchController.swift:168-181`) uses `surface.core.committedPage`. This is consistent with `KeyboardFocusController.committedPageTarget`, but during a busy cross-page settle the transient displayed page could differ from the committed page. Edge case; `canTransferFocus` guards pending generation, so no stale-result launch is possible.

## Red-line verification

- **No git commit/push/tag**: repo `main` has **zero commits** (all files untracked). Satisfied trivially.
- **Privacy**: no query raw/normalized/result app names in telemetry/log/stdout/signpost/profile/report. Grep of all 5 in-scope files for `PagingTelemetry|telemetry|signpost|os_log|print(|NSLog` found only a privacy comment. No `PagingTelemetry` schema change (no telemetry references at all). Focus stores opaque `AppID` via `AppGridFocusIdentity`.
- **No global monitor / Accessibility / Spotlight / sync I/O / persistence**: grep for `addGlobalMonitorForEvents|addLocalMonitor|AXIsProcessTrusted|AXUIElement|NSAccessibility|Spotlight|MDQuery|NSMetadataQuery|FileManager|Data(contentsOf|write(to:|UserDefaults|NSPasteboard` → **no matches**. `install(in:)` uses a window-scoped `NSWindow.didBecomeKeyNotification` observer (not a global event monitor).
- **Diagnostics**: in-scope files introduce no `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED` changes (no diagnostic references added).
- **No CatalogRevision forged**: `firstValidResultOnCurrentPage` builds `CatalogSnapshot(revision: base.revision, records: records)` reusing the served base revision; no new revision minted.

## Forbidden-tree confirmation

Reviewer-forbidden trees predate the in-scope work (mtimes):
- `Sources/PagingCore/` — 2026-08-29 21:16 (FROZEN)
- `Sources/AppGridUI/` — 2026-08-30 10:54 (specific files 10:47–10:54)
- `Sources/PagingUI/` — 2026-08-30 10:49
- `Sources/MacAppCatalog/` — 2026-08-28 21:01
- `Package.swift` — 2026-08-28 20:42
- `Sources/PagingPrototypeApp/AppLaunchController.swift` — 2026-08-28 21:46

In-scope files: 2026-08-30 11:09–11:10. All forbidden trees predate the work.

`Sources/PagingPrototypeApp/AppDelegate.swift` mtime is 2026-08-30 11:17 — **after** the T-1D-D result (11:11). This is consistent with Worker E (T-1D-E) performing the assembly/wiring (AppDelegate is T-1D-E's write scope, reserved per the concurrency_check event). Not a T-1D-D violation. The reviewer did not read forbidden sources (`BuhoReverseNotes`, `LaunchBetter`, `2026-08-25-buho-launchpad-reverse`).

## Deviations from worker result

- None material. The only delta is the filter test count (M1), explained by T-1D-E tests landing after the worker's result.

## Conclusion

All acceptance criteria verified. 16 new tests pass, full suite 620/0, debug+release builds exit 0, forbidden trees unchanged, all red lines hold. **Verdict: PASS.**
