# T-1E-folder-keyboard-return-repair — Reviewer r1 (independent)

Status: **PASS**
Reviewer: independent (read-only; no implementation files modified)
Date: 2026-08-30

## Verification checklist (against packet spec)

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | `currentLayout()` builds from `provider.presentationEntries` (composition) | ✅ | `KeyboardFocusController.swift:481` — `AppGridFocusLayout.build(from: snapshot, composition: provider.presentationEntries, itemsPerPage: surface.itemsPerPage)`; app-only `build(from:itemsPerPage:)` no longer used here |
| 2 | `committedPageTarget` uses `validEntry` + `entryIdentity:` construction | ✅ | `KeyboardFocusController.swift:488-491` — `layout.validSlots(on:).first` + `layout.validEntry(page:slot:)` → `AppGridFocusIdentity(..., entryIdentity: entry)` |
| 3 | `reconcileSettledCrossPage` pending validity via `validEntry`/`entryIdentity` comparison, minimal change | ✅ | `KeyboardFocusController.swift:240` — `layout.validEntry(page: pending.pageIndex, slot: pending.slotIndex) == pending.entryIdentity`; target rebuilt with `entryIdentity: pending.entryIdentity` (:241-244); fallback `committedPageTarget` path unchanged. For app-only layouts `validEntry == .app(id)` ⇔ old `validAppID == appID` — semantics preserved |
| 4 | `AppDelegate.applyPresentationUpdate` builds from `assembly.provider.presentationEntries` | ✅ | `AppDelegate.swift:506-508` — `AppGridFocusLayout.build(from: base, composition: assembly.provider.presentationEntries, itemsPerPage:)`. Search-active semantics preserved: `AppGridUIPageContentProvider.commitPendingSearchResult` (:169) sets `presentationEntries = result.records.map { .app($0) }` for non-empty query |
| 5 | `routeActivation`/`ActivationRouter`/`openFolder`/`openFolderFromClick`/`handleInnerArrow`/`applyInnerFocusVisual` untouched | ✅ | All read as T-1E-D/E-era semantics (`KeyboardFocusController.swift:269-275, 285-293, 329-343, 355-362, 393-402`). `ActivationRouter` lives in `Sources/AppGridUI/FolderDomain.swift:167` (forbidden tree; mtime 1788092136-or-older = Task A batch, not Task B). Folder slot identity `.folder` → `decide` → `.openFolder` → `openFolder(identity)` — the fix's intended chain |
| 6a | Test: setFocus folder identity → Return opens | ✅ | `testSetFocusFolderIdentityReturnOpensFolder` (`FolderIntegrationTests.swift:613`) — passes (0.040s) |
| 6b | Test: navigator path (downArrow seed → arrows → `.folder` identity → Return opens) — user Bug 4 exact repro | ✅ | `testNavigatorToFolderSlotReturnOpensFolder` (`FolderIntegrationTests.swift:637`) — downArrow seed asserts slot 0 identity `.folder(firstFolder.id)`, rightArrow asserts `.folder(secondFolder.id)`, Return → `isOpen == true`, `openFolderID == secondFolder.id`. Passes (0.034s) |
| 6c | Test: app-slot identity == `.app(actual app)` | ✅ | `testNavigatorToAppSlotIdentityIsActualApp` (`FolderIntegrationTests.swift:669`) — slot 2 identity == `.app(presentationEntries[2] record.id)`. Passes (0.071s) |
| 6d | Existing tests pass unchanged | ✅ | Full suite 785/0; `testKeyboardOpenDefersInnerRingUntilFirstArrow` etc. included. Compat path `build(from:itemsPerPage:)` retained (`AppGridFocusLayout.swift:40-43`) for app-only consumers |
| 7 | Write scope: only 3 allowed files; frozen/forbidden trees untouched | ✅ | mtime sweep: Task B window files = `KeyboardFocusController.swift` 1788092409, `AppDelegate.swift` 1788092409, `FolderIntegrationTests.swift` 1788092425 (newest in repo). All files under `Sources/PagingCore|AppCatalogCore|MacAppCatalog|AppIconPipeline|PagingTelemetry|PagingUI|AppGridUI` + `Package.swift` (1787917375) + `AppLaunchController.swift` (1787921214) + `AppCatalogAssembly.swift` (1788079459) predate Task B. Newest AppGridUI file = `AppGridFocusNavigator.swift` 1788092136 (Task A batch, 3s after `AppGridFocusLayout.swift` 1788092133). Worker-claimed frozen mtimes verified identical to current stat values |
| 8 | No git ops; no privacy leaks | ✅ | Repo has **zero commits** (`git log`/`reflog`: "branch 'main' does not have any commits yet"; all files untracked) — git ops impossible/not performed. Code/tests use neutral identifiers only (`fixture.alpha`…); no app/folder names in output channels |

## Build / test results (run serially, this review)

- `swift build -c debug` → **exit 0** (Build complete)
- `swift test` → **Executed 785 tests, with 0 failures (0 unexpected)**; exit 0. Valid execution (N=785 > 0). Filtered re-run of the 3 new tests: 3/3 pass
- `swift build -c release` → **exit 0** (Build complete)

## Issues

- **MAJOR**: none.
- **MINOR (non-blocking, report-only)**: Worker result file states "baseline 782 + Task A new + 3 new" while the packet cites baseline 772; the authoritative executed count is 785 with 0 failures, which satisfies the packet's acceptance (N > 0, 0 failures, ≥3 new tests). Arithmetic note only — no code impact.

## Conclusion

All three caller sites (plus the 4th, `applyPresentationUpdate`) are on the composition API with correct `entryIdentity`; test (b) covers the user's exact Bug 4 repro end-to-end; full suite green; both builds exit 0; frozen trees untouched; no git ops; no privacy leaks. **PASS**.
