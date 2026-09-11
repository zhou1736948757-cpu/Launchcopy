# Review: T-1C-C — Return/Enter keyboard launch integration

- **Reviewer**: independent (read-only)
- **Date**: 2026-08-30
- **Verdict**: **PASS**
- **Review revision**: r1

## Scope reviewed

Actual diff (Worker C window ~2026-08-29 23:03–23:12):
- `Sources/PagingPrototypeApp/KeyboardLaunchAdapter.swift` (NEW)
- `Sources/PagingPrototypeApp/AppDelegate.swift` (MODIFIED — wiring)
- `Tests/PagingUITests/KeyboardLaunchTests.swift` (NEW, 10 tests)
- `Docs/PHASE1C_VALIDATION_PLAN.md` (NEW draft)

Read-only contract types inspected: `AppLaunchController` (`handleCell`/`handleClick`/`launch(from:)`/`onLaunchAttempt`/`outcomeCounts`/`AppLaunchOutcome`), `AppGridFocusModel`/`AppGridFocusLayout`/`AppGridFocusIdentity` (T-1C-A), `KeyboardFocusController`/`KeyboardPageTurner` (T-1C-B), `AppCatalogAssembly` (`AppGridRenderer.pageView(forPage:)`/`onPresentationUpdate`), `AppGridPageView.cell(at:)`, `AppGridCellView`, `AppGridRefreshController`, `PagingTelemetryBridge`/`TelemetrySession`.

## Verification executed (independent, re-run — not trusting Worker summary)

| Command | Exit | Result |
|---|---|---|
| `swift build` | 0 | Build complete, PagingPrototypeApp target compiles |
| `swift test --filter "KeyboardLaunchTests"` | 0 | **10/10 passed**, 0 failures (executed_tests=10 > 0) |
| `swift test --filter "KeyboardPageTurnerTests\|KeyboardFocusControllerTests"` | 0 | **14/14 passed** (6 turner + 8 controller) |
| `swift test` (full) | 0 | **514/514 passed**, 0 failures |
| `rg -in "bundleid\|\.app\|nsurl\|url(string\|telemetry" KeyboardLaunchAdapter.swift AppDelegate.swift` | 0 | Only `telemetry` token matches (preexisting wiring + neutral phase events); **no** `.app` / `bundleid` / `nsurl` / `url(string` in either file |

`exit_code == 0` and `executed_tests > 0` on the launch suite → **valid test execution** (not `INVALID_TEST_EXECUTION`). Worker's claimed counts (10 targeted, 514 full) are **confirmed** by independent re-run.

## Acceptance criteria — per-criterion result

| Criterion | Result | Evidence |
|---|---|---|
| Return/Enter on valid focused cell invokes launcher exactly once | ✅ | `KeyboardLaunchAdapter.activate` → `launchController.handleCell(cell)` (KeyboardLaunchAdapter.swift:37–39). `KeyboardFocusController.keyDown`/`performKeyEquivalent` guard `focusModel.current != nil` before `onActivate` (KeyboardFocusController.swift:84–101). `testReturnLaunchesFocusedAppOnce` asserts `launcher.opened == [Alpha]`, `outcomeCounts[.launched] == 1`; `testReturnOnMovedFocusLaunchesThatApp` passes |
| Stale revision rejected | ✅ | Reused pipeline `launch(from:)` guard `token.catalogRevision == servedRevision` else `.rejectedStaleRevision` (AppLaunchController.swift:134–136). `testStaleRevisionRejected` asserts `.rejectedStaleRevision`, launcher untouched |
| Current snapshot missing AppID rejected | ✅ | `bundleURL(for:)` nil → `.rejectedMissingApp` (AppLaunchController.swift:138). `testMissingAppRejected` passes |
| File-deleted rejected | ✅ | `fileExists(atPath:)` false → `.rejectedMissingFile` (AppLaunchController.swift:140). `testDeletedFileRejected` passes |
| Launch failure non-fatal | ✅ | `openApplication` false → `.failedToLaunch` (line 142); no throw/crash. `testLaunchFailureNonFatalAndRecovers` asserts recovery to `.launched` |
| No-focus / empty cell / placeholder do not launch | ✅ | No-focus: `keyDown` falls through without `onActivate` (`testNoFocusDoesNotLaunch`). Empty slot: cellResolver nil → `.rejectedNoBinding` (`testEmptySlotNoLaunch`) |
| Mouse-click and keyboard share same validation (no parallel bypass) | ✅ | Mouse: `handleClick` (hitTest→cell)→`handleCell`→`launch(from:)` (lines 109–129). Keyboard: adapter→`handleCell`→`launch(from:)`. Both end at the same `launch(from:)`; **no** parallel NSWorkspace call and **no** URL read off the cell anywhere on the keyboard path (KeyboardLaunchAdapter.swift:37–39 only resolve identity→cell then delegate). `testMouseAndKeyboardShareValidation` asserts both yield `.launched` for the same cell |
| No real URL/path/bundleID telemetry | ✅ | Only neutral phase events (`app.launch`, `catalog.presentation`, `icon.async`); `launch(from:)` records `TelemetryEvent(phase: "app.launch")` only (line 151); `recordCatalogPresentation`/`recordIconAsyncState` embed only snapshot revision, durations, enum state (PagingTelemetryBridge.swift:153–175). Grep for `.app`/`bundleid`/`nssurl`/`url(string` on both deliverable files: **clean**. `testLaunchTelemetryContainsNoURL` asserts JSONL contains no app name / bundleID / path / `.app` |

## Constraints verified

- **Reuses `AppLaunchController` validation — no parallel launch path.** `activate` delegates entirely to `handleCell` → `launch(from:)`; the keyboard path never reads a URL off the cell and never calls `NSWorkspace` (only `NSWorkspaceAppLauncher` in AppLaunchController.swift:37–42 touches it). Stale line untouched.
- **Launch failure non-fatal and neutral.** `.failedToLaunch` is a value outcome in `record`; no exception surface.
- **Mouse and keyboard share same `handleCell`.** Confirmed by code and by `testMouseAndKeyboardShareValidation`.
- **Privacy.** No identity literals; neutral phase events only.
- **AppDelegate wiring complete and non-overstepping.** In `installContentAssembly` (AppDelegate.swift:322–339): focus model → keyboard.install → launch adapter → `onActivate` closure; `teardownAll` nils both (260–261); first responder set post `makeKeyAndOrderFront` (194–197). No change to existing launch/assembly/perf logic — `AppLaunchController.swift` untouched (mtime 08-28 21:46, pre-window).
- **Cell resolution matches the keyboard controller's internal resolver** (`renderer.pageView(forPage:)?.cell(at:)`), verified against `AppGridRenderer.pageView(forPage:)` (AppCatalogAssembly.swift:235) and `AppGridPageView.cell(at:)` (AppGridPageView.swift:59–62).

## Forbidden trees untouched

All verified by mtime (no git baseline; all top-level untracked). Worker C's own writes are confined to its allowed write scope (23:03–23:12):

- `Sources/PagingCore/` — max mtime 08-29 21:16 ✅ (frozen)
- `Package.swift` — 08-28 20:42 ✅
- `PROVENANCE/` — 08-29 21:29 ✅
- `Sources/PagingUI/` — max 08-29 22:44 (T-1C-B) ✅
- `Sources/AppGridUI/` — max 08-29 22:51:53 (`AppGridCellView.swift`, **prior** worker addressing T-1C-B F2 = focus-visual reset on reuse; before Worker C) ✅
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift` — 08-29 22:44 (T-1C-B) ✅
- `Sources/PagingPrototypeApp/AppLaunchController.swift` — 08-28 21:46 ✅ (worker correctly did not need to modify)
- `Tests/AppGridUITests/` — max 08-29 22:53 (`AppGridCellFocusReuseTests.swift`, prior F2 repair) ✅

Note for the Chief: `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift` and `Sources/AppGridUI/AppGridCellView.swift` were modified at 22:51–22:53 — **before** Worker C's window started (23:03). They are the T-1C-B F2 repair, not attributable to Worker C and not part of this review's scope. All 4 Worker-C deliverables fall strictly inside its allowed write scope.

## Findings

### F1 — MAJOR: Settle reconciliation (Reviewer F1) is not implemented for the keyboard cross-page case, and the Worker's claim + Validation Plan overstate coverage
- **Location**: `Sources/PagingPrototypeApp/AppDelegate.swift:278–281`, `:286–291`; `Sources/PagingPrototypeApp/KeyboardFocusController.swift:120–135`; `Docs/PHASE1C_VALIDATION_PLAN.md:34`.
- **Observation (verified)**: The reconciliation wired by T-1C-C is `keyboardController?.applyLayout(layout)` inside `assembly.onPresentationUpdate`, fired only from `AppGridRefreshController`'s catalog-commit/remap paths (AppGridRefreshController.swift:40, 65, 132). A keyboard cross-page turn goes through `KeyboardPageTurner.synthesizeFling` → `PagingCore` (no catalog update), so **`onPresentationUpdate` does not fire on a keyboard turn's settle or interruption** — no focus reconciliation to the displayed/committed page occurs there. `KeyboardFocusController.refreshFocusVisual()` is never called from AppDelegate (grep: only in tests). After a cross-page arrow, `handleArrow` sets `focusModel = AppGridFocusModel(current: target)` immediately (KeyboardFocusController.swift:134) before the settle commits; if that settle is interrupted by a trackpad takeover, focus can land on a page that is not displayed, with no reconcile path. The Worker result (T-1C-C.md:36–43) claims "settle 完成/中断后焦点调和（Reviewer F1：焦点始终指向已提交/已显示页面）" — that claim is **not substantiated** for the keyboard-settle case.
- **Impact**: F1 from T-1C-B was explicitly delegated to this task to confirm; the deliverable only reconciles on catalog refresh, not on keyboard settle/interruption. Also the Validation Plan §2 AC9 asserts `KeyboardLaunchTests` contains a "cross-page nav, interrupt settle" reconciliation test — **that test does not exist** (the file has 10 tests, none exercising settle reconciliation).
- **Recommended solution**: Either (a) wire a settle-completion/interruption reconcile (e.g. re-validate/`refreshFocusVisual` or re-clamp focus identity against `surface.core.committedPage` on the idle boundary), or (b) gate the cross-page focus-model update on the actual commit; and add the missing AC9-style test. Update the Validation Plan AC9 row to match real coverage.
- **Regression risk**: Low to the keyboard launch path (keyboard-only cross-page turns are velocity-forced and deterministic → focus==displayed normally); the gap only bites on settle + concurrent trackpad interruption. No wrong-app launch: if the target page host isn't live yet, `cell(at:)` returns nil → `.rejectedNoBinding`.
- **Confidence**: High (code-inspection-verified that `onPresentationUpdate` is catalog-driven and no settle hook exists; test-file inspection confirms no such test).

### F2 — MINOR: Validation Plan misstates test coverage (AC9 row)
- **Location**: `Docs/PHASE1C_VALIDATION_PLAN.md:34`.
- **Observation**: AC9 claims a `KeyboardLaunchTests` "cross-page nav, interrupt settle, assert focus points to committed/displayed page" test. No such test exists among the 10 in `Tests/PagingUITests/KeyboardLaunchTests.swift`. The plan is a draft Main will integrate, so the row must be corrected or implemented.
- **Impact**: Documentation/test-coverage mismatch; would mislead the final integrated plan.
- **Recommended solution**: Remove AC9 or align it with F1's remediation (add the test). Verify AC1–AC8 mapping is accurate (it is).
- **Regression risk**: None (doc).
- **Confidence**: High.

### F3 — MINOR: AppKit Return key reachability depends on first-responder persistence
- **Location**: `Sources/PagingPrototypeApp/AppDelegate.swift:194–197`; `Sources/PagingPrototypeApp/KeyboardFocusController.swift:72–101`.
- **Observation**: `window.makeFirstResponder(keyboardController)` runs once after launch. The keyboard proxy `acceptsFirstResponder`/`becomeFirstResponder` return true but nothing re-instates it after another view claims first responder (e.g. clicking a cell/field). While the window is key, Return only routes to the launch path while `keyboardController` remains first responder.
- **Impact**: Launch-via-Return can silently stop when focus moves to another responder. Not covered by tests (tests drive `keyboard.keyDown` directly). Matches documented scope; a UX robustness point.
- **Recommended solution**: Optional — observe window key/first-responder changes to re-set `makeFirstResponder(keyboardController)`, or accept as documented for Phase 1C.
- **Regression risk**: Low. Confidence: Medium.

## Recommended solution

- F1 (MAJOR): implement a real settle-completion/interruption focus reconciliation for the keyboard cross-page path (or gate the focus-model update on the actual commit) and add the missing reconciliation test; correct the Validation Plan AC9 row.
- F2/F3 (MINOR): doc accuracy + optional first-responder re-instatement.

## Affected scope

Worker C's 4 deliverables — all within its allowed write scope. No changes to `PagingCore`, `Package.swift`, `PROVENANCE/`, `PagingUI/`, `AppGridUI/`, `KeyboardFocusController.swift`, `AppLaunchController.swift`, or other test dirs. (`AppGridUI/AppGridCellView.swift` + `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift` were the earlier T-1C-B F2 repair at 22:51–22:53, pre-Worker-C.)

## Regression risks

- Low for the core deliverable. Full 514-test suite green; debug build clean; both launch paths verified to share the same validated funnel; privacy grep clean; forbidden trees untouched by Worker C.
- F1 is the only latent risk (focus/displayed-page divergence on keyboard cross-page settle + trackpad interruption); does not affect the tested launch path and cannot launch the wrong app.

## Confidence

High on all acceptance criteria, build/tests, forbidden-tree integrity, and privacy. Medium-high on the F1 gap being correctly characterized as a robustness gap in the explicitly delegated follow-up rather than a core-AC failure (all 8 packet ACs pass).

## Verdict

**PASS** — all 8 packet acceptance criteria are met and independently verified (build OK; KeyboardLaunchTests 10/10; controller/turner regression 14/14; full suite 514/514; privacy grep clean; forbidden trees untouched). `execute` F1 (settle reconciliation for the keyboard path) is incomplete and untested despite the Worker's claim and the Validation Plan's AC9 row — classified **MAJOR** and recommended for a small repair or explicit re-scoping by the Chief if F1 is treated as a hard gate.
