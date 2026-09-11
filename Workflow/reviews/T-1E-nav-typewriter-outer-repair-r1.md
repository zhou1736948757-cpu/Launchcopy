# T-1E-nav-typewriter-outer-repair — Reviewer Report (r1)

- Verdict: **PASS**
- Reviewer: independent (chef-worker-reviewer-workflow, Reviewer role)
- Reviewed: 2026-08-30
- Task packet: `Workflow/tasks/T-1E-nav-typewriter-outer-repair.md`
- Worker result: `Workflow/results/T-1E-nav-typewriter-outer-repair.md` (Status: PASS)
- Follow-up (verified): `Workflow/tasks/T-1E-nav-typewriter-launch-test-repair.md` + `Workflow/results/T-1E-nav-typewriter-launch-test-repair.md`

## 1. Changed code review — `Sources/AppGridUI/AppGridFocusNavigator.swift` (110 lines)

Header comment `:5-10` documents the four-direction typewriter policy + global-boundary no-wrap — matches packet spec (packet :42).

`move(_:direction:in:)`:

- **→** `:46-55` — same-row right (`slots.first(where: { $0 > slot && $0 / columns == row })`) → next-row first (`$0 / columns == row + 1`, same page) → `crossPageRight` (next page first slot; last page nil). Matches packet :37.
- **←** `:56-65` — same-row left (`slots.last(where: { $0 < slot && $0 / columns == row })`) → prev-row last (`$0 / columns == row - 1`, same page) → `crossPageLeft` (prev page last slot; first page nil). Matches packet :38.
- **↓** `:66-75` — same-column down (`$0 > slot && $0 % columns == col`) → next-column first (`$0 % columns == col + 1`, same page) → `crossPageRight`. Matches packet :39.
- **↑** `:76-85` — same-column up (`$0 < slot && $0 % columns == col`) → prev-column last (`$0 % columns == col - 1`, same page) → `crossPageLeft`. Matches packet :40.
- Global boundary: `crossPageRight` nil when `next >= pageCount` (`:98`); `crossPageLeft` nil when `prev < 0` (`:106`). Matches packet :18.
- Guard `:35-37` (`catalogRevision == revision` + `validEntry(page:slot:) == entryIdentity`) unchanged per packet :41; `makeIdentity` `:89-93` unchanged (entryIdentity construction).
- Cross-page target: `crossPageRight` → `validSlots(on: next).first` (`:99`); `crossPageLeft` → `validSlots(on: prev).last` (`:107`) — page-first/page-last valid slot, row-preserving logic fully replaced. Matches packet :43.

All 11 navigator test expectations in `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift` were hand-traced against the implementation (row/col wrap, partial-page column wrap slot 30↓→1 / slot 1↑→30 / slot 29↓→nil, cross-page slot 19↓→page1 slot 0, global-boundary nil for all four directions, stale-identity guard) — all consistent.

`Tests/AppGridUITests/AppGridFocusCompositionTests.swift` — unchanged (Worker claim verified): all navigator moves are mid-grid same-column/same-row (slot 0→5, 0→1, 2→7), unaffected by typewriter semantics.

`Tests/PagingUITests/KeyboardFocusControllerTests.swift` — cross-page sequences updated to "34× → to page-0 slot 34, then cross" (`:134-136`, `:199-201`, `:223-225`, `:253-255`); `testCrossPageLeftSettlePreservesRowEndLanding` landing assertion slot 34 (page-last slot) — consistent with new semantics.

`Tests/PagingUITests/KeyboardLaunchTests.swift:302-305` (follow-up task) — comment + `for _ in 0..<34` updated per follow-up spec; assertions `:306-323` untouched.

## 2. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| Four-direction typewriter semantics (row/col-end wrap + page-end cross + global boundary nil) | PASS | code `:46-85`, `:98`, `:106`; tests traced |
| Cross-page target = page-first/page-last valid slot (not row-preserving) | PASS | `:99`, `:107`; `testCrossPageRightToShorterNextPageLandsOnFirstSlot` |
| Guard + makeIdentity unchanged | PASS | `:35-37`, `:89-93` |
| All tests pass | PASS | `swift test`: **Executed 787 tests, with 0 failures (0 unexpected)**, exit 0 |
| Both builds exit 0 | PASS | debug exit 0; release exit 0 |
| Frozen trees untouched | PASS | mtimes identical before/after (see §3) |

## 3. Verification (run by Reviewer, serial)

- `swift build -c debug` → exit 0 (Build complete).
- `swift test` → `Executed 787 tests, with 0 failures (0 unexpected) in 12.275s`, exit 0. (Baseline 785 + 2 new navigator tests = 787; the 3 previously failing out-of-scope `KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency` assertions now pass after the follow-up task.)
- `swift build -c release` → exit 0 (Build complete).
- Frozen-tree mtimes (before verification = after verification, all unchanged; identical to Worker's reported after-values):
  - `Sources/PagingCore` 1788057962, `Sources/AppCatalogCore` 1787917822, `Sources/MacAppCatalog` 1787918515, `Sources/AppIconPipeline` 1787930560, `Sources/PagingTelemetry` 1787918942, `Sources/PagingUI` 1788070530, `Package.swift` 1787917375, `Sources/PagingPrototypeApp/AppLaunchController.swift` 1787921214.

## 4. Notes

- MINOR (reporting only): Worker result states `AppGridFocusNavigatorTests.swift` grew 182 → 263 lines; actual file is 269 lines. Cosmetic count discrepancy, no content impact.
- MINOR (informational): Task A's 3 out-of-scope failures were correctly reported per packet rule (packet :56) and resolved by the follow-up task; full suite now green. No defect in Task A scope.
- Confirmed semantic (also in Memory candidates): ↓ column-bottom wrap targets the **top** of the next column (`slots.first` of next column), not the same-row next-column position — matches user request "到下一列的第一个" and packet :39.

## 5. Verdict

**PASS** — all acceptance criteria independently verified; no BLOCKER/MAJOR findings.
