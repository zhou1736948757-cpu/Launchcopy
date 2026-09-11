# Review: T-1E-D — 键盘 / 焦点 / 标题编辑

- **Reviewer**: Independent Reviewer (read-only)
- **Task**: T-1E-D (Worker D)
- **Verdict**: **PASS** (with 1 MAJOR finding recommended for a repair follow-up)
- **Date**: 2026-08-30

## Scope reviewed

- Task packet `Workflow/tasks/T-1E-D.md` (authoritative spec)
- ADR `Docs/ADR-008-FOLDER-PRESENTATION.md` (§2.2, §3 Q10/Q11, §8.1)
- Worker result `Workflow/results/T-1E-D.md`
- Implementation: `Sources/AppGridUI/FolderKeyboardLogic.swift` (NEW), `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (modified), `Sources/PagingPrototypeApp/AppSearchController.swift` (modified), `Sources/PagingPrototypeApp/FolderTitleEditor.swift` (NEW), `Tests/AppGridUITests/FolderKeyboardLogicTests.swift` (32 tests)
- Supporting types: `FolderDomain.swift` (ActivationRouter/FolderTitle/TopLevelEntry), `FolderOpenState.swift`, `FolderOverlayView.swift`, `AppGridFocusIdentity.swift`, `AppGridUIPageContentProvider.swift`, `AppLaunchController.swift`

## Verdict

**PASS.** All core acceptance criteria are implemented and verified by the full test suite (741/0). The documented deviation (pure logic in AppGridUI) is acceptable. One MAJOR finding (stale `isEditingTitle` after Command-F during title editing) is a narrow edge-case functional regression that should be repaired in a follow-up; it does not violate privacy, launch-safety, or the frozen-tree constraints.

## Findings

### BLOCKER
None.

### MAJOR

1. **Command-F during title editing leaves `isEditingTitle` stale → keyboard navigation breaks after search exits.**
   - Location: `Sources/PagingPrototypeApp/KeyboardFocusController.swift` — `performKeyEquivalent` handles Command-F *before* the `isEditingTitle` guard; `handleCommandF()` → `closeFolder()` does **not** reset `isEditingTitle`.
   - Flow: folder open + title editing active → Command-F → `commandFAction(folderOpen: true)` = `.closeFolderThenSearch` → `closeFolder()` (resets `openedFolderIdentity`/`innerFocusIndex` but **not** `isEditingTitle`) + `onSearchShortcut?()` → search field becomes first responder. After search exits and `KeyboardFocusController` regains first responder, `isEditingTitle` is still `true`, so `keyDown`/`performKeyEquivalent` route arrows/Return to `super` and navigation is dead until the user presses ESC (which resets the flag via `.cancelTitleEdit`).
   - Impact: functional regression in a documented path (Command-F), recoverable but broken navigation.
   - Fix (minimal): reset `isEditingTitle = false` inside `closeFolder()` (covers both ESC-close and Command-F-close), or in `handleCommandF()` before `onSearchShortcut?()`.

### MINOR

1. **AppKit-only behaviors listed in the task's test scope are implemented but not unit-tested.** Tab-to-AppKit, key-window responder rebuild, and blank-click two-stage are wired in the responder glue (`FolderTitleEditor` returns `false` for Tab; `AppSearchController.rebuildFirstResponder` via `modeFirstResponderProvider`) but have no unit tests. Justified by the hard constraints (AppGridUITests cannot import PagingPrototypeApp; PagingUITests is forbidden; PagingPrototypeAppTests does not exist and cannot be created with Package.swift frozen). **Recommend a follow-up**: a manual GUI gate (Phase 1E final) or a PagingUITests-based test in a later phase when Package.swift can be modified.
2. **Initial inner focus visual not applied on folder open.** `openFolder` sets `innerFocusIndex = 0` but does not call `applyInnerFocusVisual()`, so the first member is not highlighted until the first arrow. Consistent with the deferred-focus pattern (top-level also starts deferred); minor UX, not a correctness bug.

### QUESTION

1. **T-1E-E must ensure `endTitleEditing()` is called on all folder-close paths** (blank-click close via `onRequestClose`, overlay clear) to avoid the same stale-`isEditingTitle` class of issue as MAJOR-1. This is T-1E-E wiring scope, but the reviewer flags it so the assembly layer resets the editing flag whenever the open layer closes.

## Acceptance-criteria verification

| Criterion | Status | Evidence |
|---|---|---|
| Return/Enter open-vs-launch routing | PASS | `routeActivation` → `ActivationRouter.decide`: folder→`.openFolder`→`openFolder`; app→`.launchApp`→`onActivate`; member→`activateInnerMember`→`onActivateMember(AppID)`. Tests `testActivationRouting*` (4). |
| Folder identity never passes app-launch validation | PASS | `AppLaunchController.launch(from:)` uses `token.appID as? AppID` (line 131); folder `appID` computed property returns nil → `.rejectedNoBinding`. No weakened second launch path. |
| Inner arrows/paging/focus restore | PASS | `FolderInnerNavigator` 4-direction + cross-page (page = index/membersPerPage consistent); `FolderFocusRestore` locates folder entry / first-entry fallback / empty→nil. Tests `testInner*` (12) + `testRestore*` (6). |
| ESC priority | PASS | `FolderKeyboardPriority.escAction`: title-edit→cancel; folder→close; else→clear-grid-selection. Tests `testEscPriority*` (3). |
| Command-F closes folder then search | PASS (core) | `commandFAction(folderOpen:true)`→`.closeFolderThenSearch`→`closeFolder()`+`onSearchShortcut?()`. Tests `testCommandF*` (2). **See MAJOR-1 for stale-flag side effect.** |
| Title editing Enter/Escape/focus-loss | PASS | `FolderTitleEditing.resolve` + `FolderTitleEditor` (Enter commit / Escape cancel / focus-loss commit, idempotent via `didFinish`); blank fallback + 64-char cap + Unicode-safe via `FolderTitle.normalized`. Tests `testTitle*` (6). |
| During editing arrows/Return do not launch apps | PASS | `isEditingTitle` guard in `keyDown`/`performKeyEquivalent`; editor is first responder during editing. |
| key-window responder rebuild | PASS (implemented, untested) | `AppSearchController.rebuildFirstResponder` consults `modeFirstResponderProvider` first (title-edit > folder > search > top-level). See MINOR-1. |
| Tab not swallowed | PASS (implemented, untested) | `FolderTitleEditor`/`AppSearchController` return `false` for Tab; `KeyboardFocusController` falls through to `super`. See MINOR-1. |
| No global listeners | PASS | No `addGlobalMonitor`/`addLocalMonitor`/`CGEventTap`/`AXIsProcessTrusted` in T-1E-D files (grep verified). |
| Privacy redline | PASS | No `print`/`NSLog`/`os_signpost`/`PagingTelemetry`/`JSONL`/`FileHandle`/`UserDefaults` in T-1E-D files (grep verified). Only neutral counters/decision enums. No PagingTelemetry schema change (tree frozen). |

## Deviation assessment

**Placement of pure logic in `Sources/AppGridUI/FolderKeyboardLogic.swift` (new file) instead of PagingPrototypeApp — ACCEPTABLE.**

- Justification is technically sound and verified: `AppGridUITests` depends only on `["AppGridUI", "PagingUI", "AppCatalogCore", "AppIconPipeline"]` (Package.swift line 80) and cannot import `PagingPrototypeApp`. `PagingUITests` (which can) is forbidden for this task. `PagingPrototypeAppTests` does not exist and cannot be created (Package.swift frozen, line 3 "Main 独占维护").
- The new file is in AppGridUI's allowed write area: it is a **new** pure-logic file, not one of T-1E-C's files (`AppGridCellView.swift`, `AppGridPageView.swift`, `FolderOpenState.swift`, `FolderOverlayView.swift` — all untouched, mtimes 16:04–16:28 predate T-1E-D writes 16:36+).
- AppKit responder glue stays thin in PagingPrototypeApp (`KeyboardFocusController`, `AppSearchController`, `FolderTitleEditor`), matching the task's expected write scope.
- This is a reasonable interpretation of "New keyboard/focus/title tests (in Tests/AppGridUITests/ … as appropriate)".

## Verification evidence (measured)

- `swift build -c debug`: **exit 0** (Build complete, 0 warnings).
- `swift build -c release`: **exit 0** (Build complete).
- `swift test` (full suite): **741 tests, 0 failures** — XCTest line `Executed 741 tests, with 0 failures (0 unexpected) in 13.627s`. (The swift-testing `0 tests in 0 suites` line is NOT the count.) Exit 0.
- `swift test --filter FolderKeyboardLogicTests`: **32 tests, 0 failures** — matches the worker's claim of 32 new tests. Baseline = 741 − 32 = 709, consistent with the worker's "baseline 709 + 32 new" claim.
- **Frozen trees unchanged**: `Sources/PagingCore/`, `AppCatalogCore/`, `MacAppCatalog/`, `AppIconPipeline/`, `PagingTelemetry/`, `PagingUI/`, `Package.swift`, `AppLaunchController.swift` — all mtimes predate this session (08-28/29; PagingSurface 08-30 10:49, PagingFrameDriver 08-30 15:15).
- **T-1E-B/C files untouched by T-1E-D**: `AppGridUIPageContentProvider.swift` (16:28), `AppGridSearchPresentationController.swift` (16:26), `AppGridCellView.swift` (16:24), `AppGridPageView.swift` (16:20), `FolderOpenState.swift` (16:19), `FolderOverlayView.swift` (16:25), `FolderDomain.swift` (16:12) — all predate T-1E-D writes (16:36+).
- **Write scope exactly 5 files**, all within allowed scope (verified via `find -newermt 16:30`): `FolderKeyboardLogic.swift`, `KeyboardFocusController.swift`, `AppSearchController.swift`, `FolderTitleEditor.swift`, `FolderKeyboardLogicTests.swift`.
- **No git operations** performed by reviewer; no implementation files modified.

## Recommendation

PASS. Address MAJOR-1 (reset `isEditingTitle` in `closeFolder()`) in a small repair task, and ensure T-1E-E calls `endTitleEditing()` on all folder-close paths (QUESTION-1). Schedule a manual GUI gate or later-phase test for the untested AppKit surface (MINOR-1).
