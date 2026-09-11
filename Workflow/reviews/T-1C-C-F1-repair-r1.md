# Review: T-1C-C-F1-repair — Keyboard cross-page settle focus reconciliation (post-PASS repair)

- **Reviewer**: independent (read-only)
- **Date**: 2026-08-30
- **Verdict**: **PASS**
- **Review revision**: r1

## Scope reviewed

Actual repair diff (window 2026-08-30 00:35:45–00:36:37), 5 declared deliverables:
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (MODIFIED — marker + `reconcileSettledCrossPage` + `committedPageTarget`)
- `Sources/PagingPrototypeApp/AppDelegate.swift` (MODIFIED — `onIdleBoundary` reconcile wiring)
- `Tests/PagingUITests/KeyboardFocusControllerTests.swift` (MODIFIED — 2 new settle tests + `overlaySettleReconcile` helper)
- `Tests/PagingUITests/KeyboardLaunchTests.swift` (MODIFIED — 1 new accessibility/visual/launch consistency test)
- `Docs/PHASE1C_VALIDATION_PLAN.md` (MODIFIED — F2 AC9 + §3 matrix corrected to real test names)

Read-only contract types inspected: `KeyboardFocusController` (full), `AppDelegate` (full), `KeyboardPageTurner.turn` idle guard, `PagingSurface.handleCoreState/.idle/committedPage`, `AppLaunchController.launch(from:)`, `KeyboardLaunchAdapter.activate`, `AppGridFocusLayout` (validSlots/validAppID), `PagingSurface.updateAccessibilityDescription`.

## Verification executed (independent, re-run — not trusting Worker self-report)

Run serially from project root (SwiftPM `.build` lock respected).

| Command | Exit | Executed | Failures | Result |
|---|---|---|---|---|
| `swift test --filter KeyboardFocusControllerTests` | 0 | **10** | 0 | Both new settle tests passed: `testCrossPageSettleReconcilesFocusToCommittedPage`, `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` |
| `swift test --filter KeyboardLaunchTests` | 0 | **11** | 0 | `testAccessibilityVisualFocusLaunchObjectConsistency` passed |
| `swift test` (full) | 0 | **517** | 0 | Exit 0; `executed_tests = 517` (baseline 514 + 3 new) |

`exit_code == 0` and `executed_tests > 0` on every run → **valid test execution** (NOT `INVALID_TEST_EXECUTION`). Worker's claimed counts (10 controller, 11 launch, 517 full) independently confirmed.

## Verification table — per repair claim

| # | Claim | Result | Evidence |
|---|---|---|---|
| 1 | `KeyboardFocusController.swift`: marker + `reconcileSettledCrossPage` + `committedPageTarget` | ✅ | `pendingCrossPageSettleTarget: Int?` (line 45); set only in `handleArrow` when `result == .turned(target.pageIndex)` (line 163); `reconcileSettledCrossPage(committedPage:)` (134–146) marker-guarded (`guard pendingCrossPageSettleTarget != nil else { return }`, clears at 136); `committedPageTarget` returns page's first valid cell via `layout.validSlots(on:).first` + `validAppID` (197–203). Empty committed page → focus cleared (140–142), no stale mapping |
| 2 | `AppDelegate.swift`: `onIdleBoundary` calls reconcile; runs on Core `.idle` | ✅ | `surface.onIdleBoundary` (288–294) calls `applyPendingAtIdleBoundary` then `keyboardController?.reconcileSettledCrossPage(committedPage: surface.core.committedPage)`. `onIdleBoundary` fires only in `PagingSurface.handleCoreState` when `state == .idle` (PagingSurface.swift:501–506). Re-clamps focus via `currentLayout()` + `applyFocusVisual()`. Reconcile stays entirely in `Sources/PagingPrototypeApp/` — zero `PagingCore` touch |
| 2a | **Ordinary trackpad gestures untouched** (marker-guarded crux) | ✅ | `pendingCrossPageSettleTarget` is written in exactly **one** place (handleArrow:163). A trackpad gesture never invokes `handleArrow`, so the marker stays `nil` and `reconcileSettledCrossPage` returns immediately at line 135 (no-op). No focus/visual mutation occurs on a trackpad-only idle. Confirmed by code-inspection + grep (write-site unique) |
| 3 | Three new tests present and passing | ✅ | `KeyboardFocusControllerTests.testCrossPageSettleReconcilesFocusToCommittedPage` (pass); `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` (pass); `KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency` (pass). All exercise a real `PagingSurface` + real Core commit (`settleFrames` drives `advanceFrame` to static) |
| 4 | F2: `PHASE1C_VALIDATION_PLAN.md` AC9 + §3 real test names | ✅ | AC9 row (line 34) references `testCrossPageSettleReconcilesFocusToCommittedPage` + `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` + `testAccessibilityVisualFocusLaunchObjectConsistency`; §3 matrix (lines 38–41) lists the same. No fabricated coverage |
| 5 | Privacy: no new redline hits; keyboard launch still via `AppLaunchController.handleCell` | ✅ | `KeyboardLaunchAdapter.activate` → `handleCell` (unchanged); grep on both changed sources for `url(string|nsurl|bundleid|.app|NSWorkspace.shared.open|openApplication` → only pre-existing AppDelegate telemetry/profile-path wiring + Reduce-Motion `accessibilityDisplayShouldReduceMotion`. No URL/bundleID/.path read off a cell anywhere on the keyboard path |
| 6 | No parallel launch path / no cell-direct URL→NSWorkspace bypass | ✅ | Entire app source has exactly **one** `NSWorkspace.shared.open(url)` — `AppLaunchController.swift:40`, reached only via `launcher.openApplication` inside `launch(from:)` (:142). Both mouse (`handleClick`) and keyboard (`KeyboardLaunchAdapter.activate`) funnel to the same `handleCell`→`launch(from:)`. `KeyboardFocusController`/`AppDelegate` keyboard path never call `NSWorkspace` open |
| 7 | Diagnostic status preserved (3 tokens), no fix/hitch claims | ✅ | Worker result (`Workflow/results/T-1C-C-F1-repair.md:90–92`) and repair task both keep `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`; explicitly state NO `FIX_VALIDATED`/`ALL_HITCHES_FIXED`/`ROOT_CAUSE_FOUND`. Repair code makes no hitching claim, changes no production default. Repair scoped strictly to keyboard focus consistency |
| 8 | Reconcile is keyboard-cross-page-only and cannot misfire | ✅ | Marker lifecycle is sound: set on accepted cross-page `.turned`; cleared on next `.idle` (reconcile). Non-idle interaction (trackpad takeover) cannot set it (turn guards `.idle` at KeyboardPageTurner.swift:51). After interruption the next idle reconciles to the actual `committedPage`. A second keyboard turn is impossible until the first returns to idle, so no double-set. Teardown is guarded (`surface.isTearingDown` no-ops) |

## Accessibility test — non-vacuous (Prompt §4.2 consistency triad)

`testAccessibilityVisualFocusLaunchObjectConsistency` (KeyboardLaunchTests.swift:291–324) is genuine, not vacuous:
- It overlays `reconcileSettledCrossPage` onto `onIdleBoundary` (production-homomorphic), navigates to page 0 slot 4, then cross-page arrow to page 1, `settleFrames`, and captures the real `surface.core.committedPage`.
- Asserts **accessibility-focus** (`surface.accessibilityDescription == "Page \(committed+1) of \(pageCount)"`), **focus pageIndex** (`identity.pageIndex == committed`), **visual focus** (`pageView(for: committed).cell(at:0).isFocused == true`), **launch object == visual-focus appID** (`identity.appID == focusedCell.bindingToken.appID`), then **launches** and asserts `launcher.opened == [the committed-page first app]`. All three triad links asserted end-to-end.
- Counters: 60 apps → pages of 35/25; `committed*35` indexing valid. Test executed and passed (0.147 s).

## Test-count evidence

- `KeyboardFocusControllerTests`: **10 executed, 0 failures** (8 baseline + 2 new settle).
- `KeyboardLaunchTests`: **11 executed, 0 failures** (10 + 1 new accessibility).
- Full suite: **517 executed, 0 failures, exit 0** (514 baseline + 3 new = 517; no deletions).

## Forbidden-tree audit

Verified by mtime (no git baseline; repo has no commits, all untracked). Definitive sweep of `Sources/` + `Tests/` for files at/after 2026-08-30 00:30 → only the 4 declared repair files. All forbidden trees predate 00:30:

| Tree / file | Max/pinned mtime | vs repair window | Status |
|---|---|---|---|
| `Sources/PagingCore/` (6 files) | 2026-08-29 21:16 | older | ✅ frozen |
| `Package.swift` | 2026-08-28 20:42 | older | ✅ |
| `Sources/PagingPrototypeApp/AppLaunchController.swift` | 2026-08-28 21:46 | older | ✅ untouched |
| `Sources/AppGridUI/` | 2026-08-29 22:51 | older | ✅ |
| `Sources/PagingUI/` (incl. `KeyboardPageTurner.swift`) | 2026-08-29 22:44 | older | ✅ |
| `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/` | ≤ 2026-08-29 00:22 | older | ✅ |
| Test support (`Tests/PagingUITests/TestSupport.swift`, `AppContentTestSupport.swift`) | ≤ 2026-08-28 21:58 | older | ✅ (helpers reused, not modified) |

Only changed source/test files in window: `KeyboardFocusController.swift` (00:35:45), `AppDelegate.swift` (00:35:51), `KeyboardFocusControllerTests.swift` (00:36:21), `KeyboardLaunchTests.swift` (00:36:27), plus `Docs/PHASE1C_VALIDATION_PLAN.md` (00:36:37). No `Sources/PagingCore/` file, `AppLaunchController.swift`, or `Package.swift` touched.

## Findings

No BLOCKER or MAJOR findings.

- **MINOR (QUESTION, no action required)** — Wiring of `reconcileSettledCrossPage` into the *real* `AppDelegate.onIdleBoundary` closure is verified by code inspection only; no integration test drives `AppDelegate` end-to-end (the 3 new tests overlay the reconcile onto `onIdleBoundary` in the test harness instead). The reconcile method and the seam contract are thoroughly tested, and the two-line production wiring is trivially correct by inspection. A future AppDelegate-instantiating integration test would close this residual gap; not a defect in this repair.
- **MINOR — F3 remains open (correctly)**. First-responder loss after another responder claims focus can silently disable Return. Worker recorded it as an open follow-up, explicitly out of the bounded repair scope (Worker result §F3). Consistent with the original T-1C-C-r1 F3 recommendation; no action taken is appropriate to this repair's scope.

## Affected scope

Exactly the 5 declared deliverables within the repair window. No `Sources/PagingCore/`, `Package.swift`, `AppLaunchController.swift`, `PagingUI/`, `AppGridUI/`, or other test trees touched. Reconcile logic entirely inside `Sources/PagingPrototypeApp/` + 2 test files.

## Regression risks

- Low. Full 517-suite green; 27 keyboard-path tests (controller+launch+turner) green under the full run. Marker-guard makes the reconcile a strict no-op for ordinary trackpad gestures and normal settles, so existing trackpad/settle behavior is unchanged. Launch correctness unchanged (single `handleCell` funnel; no new NSWorkspace call, no URL-read off cell).

## Confidence

High on all verified items: marker-guard exclusivity (write-site unique + idle-turn-guarded), forbidden-tree integrity (only 4 declared files), real (non-vacuous) test assertions, diagnostic-token discipline, privacy, and serial test re-runs (10/10, 11/11, 517/517).

## Verdict

**PASS** — Reviewer F1 is now genuinely implemented and covered: the reconcile is marker-guarded to fire only for the keyboard cross-page settle path (trackpad/ordinary settle untouched), runs on the Core `.idle` boundary, re-clamps focus to the committed page's first valid cell, stays entirely outside `PagingCore`, is covered by three real passing tests plus the accessibility/visual/launch consistency triad, the Validation Plan AC9 + §3 correctly reference real test names (F2), and the diagnostic status tokens are preserved with no fix/hitch claims. Independent re-runs: 10 + 11 targeted and 517 full, all green with valid `executed_tests > 0`; forbidden trees frozen. No blockers.

## Recommendation to Main

**APPROVE.** Integrate the repair and close Reviewer F1/F2. Treat F3 (first-responder retention) as an optional open follow-up outside the keyboard-launch integration scope.
