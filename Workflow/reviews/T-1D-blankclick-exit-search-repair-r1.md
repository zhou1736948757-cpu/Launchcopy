# Review: T-1D-blankclick-exit-search-repair — r1

- **Task**: T-1D-blankclick-exit-search-repair
- **Reviewer**: Independent Reviewer (chef-worker-reviewer-workflow, Reviewer role)
- **Date**: 2026-08-30
- **Scope**: `Sources/PagingPrototypeApp/AppDelegate.swift`, `Sources/PagingPrototypeApp/AppSearchController.swift`, `Tests/PagingUITests/BlankClickToQuitTests.swift`, `Tests/PagingUITests/AppSearchControllerTests.swift`
- **Method**: Read task spec + worker result; read full diff (both changed app files + both test files + `AppGridSearchPresentationController.swift` to validate the design claim); ran all gate commands serially; verified behavior matrix by reading code, not just tests; verified forbidden trees by mtime + git state; checked for global event monitors / Accessibility / sync I/O / privacy leaks.

---

## Independent verification results

| Command | Result |
|---|---|
| `swift test --filter 'BlankClickToQuitTests'` | **13 tests, 0 failures** (exit 0) |
| `swift test --filter 'AppSearchControllerTests'` | **16 tests, 0 failures** (exit 0) |
| `swift test` (full) | **631 tests, 0 failures (0 unexpected)** |
| `swift build -c debug` | **exit 0** |
| `swift build -c release` | **exit 0** |

Baseline check: 622 (existing baseline) + 9 new (BlankClick +4, AppSearch +5) = **631**. Matches.

### Test inventory (independently enumerated)
- **BlankClickToQuitTests** = 13: 4 new T-1D (`testBlankClickWhileSearchFocusedEmptyQueryExitsAndStaysAlive`, `testBlankClickWhileSearchQueryClearsQueryExitsAndStaysAlive`, `testBlankClickWhileSearchInactiveTerminates`, `testCellClickDuringSearchPassesThrough`) + 9 pre-existing classification tests. All present in source.
- **AppSearchControllerTests** = 16: 5 new T-1D (`testIsSearchActiveTrueWhenFieldFocusedEmptyQuery`, `testIsSearchActiveTrueWithNonEmptyQuery`, `testIsSearchActiveFalseByDefaultWhenInactive`, `testIsSearchActiveFalseAfterEscapeEmptyExit`, `testExitSearchAndRestoreFocusClearsQueryRestoresFocus`) + 11 pre-existing. All present in source.

---

## Findings

### Shared exit routine (claim 1) — VERIFIED, no finding
`AppSearchController.exitSearchAndRestoreFocus()` (AppSearchController.swift:119-129) is the single shared routine. Both consumers call it:
- Escape-empty: `handleEscape()` → `exitSearchAndRestoreFocus()` (AppSearchController.swift:162).
- Blank-click: AppDelegate wiring → `search.exitSearchAndRestoreFocus()` (AppDelegate.swift:207).

`grep exitSearch` shows only `exitSearchAndRestoreFocus` (def + 2 call sites) and the local closure var named `exitSearch` in `sendEvent` (AppDelegate.swift:602-603). No leftover private `exitSearch()`, no duplicated exit logic.

Routine order (matches spec): `clearFieldText()` → `presentation.clearQuery()` → `commitIfIdle()` → `guard field.window` → `window.makeFirstResponder(keyboardController)` → `isSearchActiveFlag = false` → `onSearchExited?()`. First-responder restoration to `KeyboardFocusController` is present (AppSearchController.swift:124-126).

### Seam definition (claim 1) — VERIFIED, key design decision correct
`isSearchActive` (AppSearchController.swift:104-114) ORs: `isSearchActiveFlag` / first-responder===`field` or `field.currentEditor()` / trimmed `currentText` non-empty / `presentation.currentQuery != nil && !query.isEmpty`.

The critical claim — must use `!query.isEmpty` not `!= nil` — is **confirmed by reading the presentation controller**: `AppGridSearchPresentationController.clearQuery()` → `updateQuery(AppSearchQuery(raw: ""))` (AppGridSearchPresentationController.swift:59-61) sets `currentQuery = query`, so a cleared query is a **non-nil empty** `AppSearchQuery`. Using `!= nil` would leave `isSearchActive == true` after exit and blank clicks would never stop being intercepted. The worker used `else if let query = presentation.currentQuery, !query.isEmpty` (line 112) — correct.

Canonical empty-query + field-focused case: `isSearchActiveFlag` may be false (plain field click does not call `activateSearch`), but the first-responder branch (line 106-109) returns true. Confirmed by test `testIsSearchActiveTrueWhenFieldFocusedEmptyQuery`.

### Escape-empty and blank-click share ONE code path — VERIFIED (no duplicated logic, claim 2)
Terminate branch unreachable while search active on blank click — VERIFIED:
`QuitOnBlankClickWindow.sendEvent` (AppDelegate.swift:592-613): on `.leftMouseDown` it computes `contentView.hitTest`, and when `!blankClickResolvesToCell(hit)` it evaluates `onBlankClickShouldExitSearch`. In production the closure (AppDelegate.swift:205-209) returns `true` whenever `search.isSearchActive`, and on `true` the method `return`s immediately (consume) without reaching `onBlankClick`/`terminateOnBackgroundClick`. While search is active the terminate path is therefore structurally unreachable for blank hits. Normal mode (search inactive) → closure returns false → `onBlankClick?()` → `terminateOnBackgroundClick()` → `NSApp.terminate` (AppDelegate.swift:615-517). Cell hits / search-field interaction-zone hits → `blankClickResolvesToCell` true → fall-through `super.sendEvent` (pass-through unchanged, AppDelegate.swift:598,610-612; `blankClickResolvesToCell` at 620-633 with search-field zone at 621-624).

Wiring order safe: `installContentAssembly` (creates `self.search`, AppDelegate.swift:379-386) runs at line 124-126, before window creation (line 183) and `onBlankClickShouldExitSearch` wiring (line 205).

### No global event monitor / no Accessibility / no sync I/O (claim 2) — VERIFIED
`grep` of AppDelegate.swift + AppSearchController.swift for `addGlobalMonitor|addLocalMonitor|AXIsProcessTrusted|accessibility|FileHandle|DispatchQueue|write(` → no occurrences except the pre-existing Reduce-Motion system reads (`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` AppDelegate.swift:70,93; `accessibilityDisplayOptionsDidChangeNotification` :256) and a doc-comment explicitly stating the window-level `sendEvent` is *not* a global `NSEvent` monitor (AppDelegate.swift:572-579). `sendEvent` is a window-level override scoped to this window. No file/network/sync I/O in either changed routine. Threading: `sendEvent` calls `MainActor.assumeIsolated({ exitSearch() })` (AppDelegate.swift:603), valid on the main thread that NSWindow event delivery guarantees; class is `@MainActor`.

### Behavior matrix (claim 4) — VERIFIED by code, not just tests
| Scenario | Code path | Result |
|---|---|---|
| Search ACTIVE, field-focused empty query + blank click | seam true (first-responder) → `exitSearchAndRestoreFocus`, `return` | exit-search only, consume, app ALIVE ✓ |
| Non-empty query + blank click | seam true → clear query, restore focus | exit-search, app ALIVE ✓ |
| Normal mode blank click | seam false → `onBlankClick` → `NSApp.terminate` | terminate unchanged ✓ |
| Cell click during search | `blankClickResolvesToCell` true → `super.sendEvent` | pass-through / launch unchanged ✓ |
| Field/clear-button click during search | interaction zone → `super.sendEvent` | pass-through ✓ (existing tests 11-13) |

`AppLaunchController.swift` untouched — no change to launch funnel.

### Red lines / forbidden trees (claim 1) — VERIFIED
mtime evidence:
- `Sources/PagingPrototypeApp/AppLaunchController.swift` — 2026-08-28 21:46 **UNCHANGED** ✓
- `Package.swift` — 2026-08-28 20:42 **UNCHANGED** ✓
- `Sources/MacAppCatalog/` — all files 2026-08-28 **UNCHANGED** ✓
- `Sources/PagingCore/` — only `PagingParameters.swift` 2026-08-30 11:46 (pre-landed velocityThreshold 800→700, within allow-exception; earlier than this task's 11:53 edits); all other PagingCore files 08-28/08-29 **UNCHANGED** ✓
- Changed files only the 4 allowed: AppDelegate.swift 11:53:41, AppSearchController.swift 11:52:25, AppSearchControllerTests.swift 11:53:03, BlankClickToQuitTests.swift 11:53:11 (all 08-30) ✓

**No git ops**: repo has **zero commits** (`git reflog`: "current branch 'main' does not have any commits yet"); `git status` shows everything untracked (`??`), so no commit/push/tag was possible. Consistent with worker's "repo 全 untracked" claim. ✓

**Privacy**: no query/result name in logs/telemetry. AppSearchController contains no `print` at all (grep for `print(` → no matches). AppDelegate `print` statements are pre-existing telemetry/frame diagnostics (runID/logPath/fullscreen/frame-driver), none include query text. Search seam + exit routine emit no logging. `onSearchEntered`/`onSearchExited` are neutral no-arg callbacks. ✓

---

## Findings summary (BLOCKER / MAJOR / MINOR / QUESTION)

- **BLOCKER**: none.
- **MAJOR**: none.
- **MINOR (informational, non-blocking)**: The seam's two query checks are slightly asymmetric in whitespace handling — `currentText` is trimmed before the non-empty check (AppSearchController.swift:111) while `presentation.currentQuery.isEmpty` (line 112) depends on `AppSearchQuery.isEmpty` without an explicit trim in the controller. In practice a whitespace-only query leaves the field as first responder, so the first-responder branch (line 106-109) keeps `isSearchActive == true`; the asymmetry therefore does not create a reachable behavior defect. Noted for transparency; no action required.
- **QUESTION**: none. (Only clarification already resolved by code reading: the `!query.isEmpty` vs `!= nil` choice is correct and intentional — see Seam finding.)

---

## Verdict

All acceptance criteria independently verified: both filtered suites green (13/13, 16/16), full suite green (**631 tests, 0 failures**), debug and release builds exit 0, shared exit routine used by both Escape-empty and blank-click (no duplicated logic), terminate branch structurally unreachable while search active, first-responder restoration present, cell/field pass-through intact, launch funnel unchanged, all forbidden trees untouched, no git operations (zero-commit repo, all untracked), no global event monitor / Accessibility / sync I/O, and no privacy leak.

**VERDICT: PASS**
