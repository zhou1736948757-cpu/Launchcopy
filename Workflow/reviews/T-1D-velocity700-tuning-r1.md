# T-1D-velocity700-tuning — Review (r1)

- **Task**: T-1D-velocity700-tuning (参数-only 调参第 16 轮)
- **Reviewer**: chef-worker-reviewer-workflow / Reviewer
- **Date**: 2026-08-30
- **Scope**: Verify worker's parameter-value-only change `velocityThreshold` 800 → 700 plus the required test/comment alignment, against the task spec and gate. Read-only review; no implementation file edited.
- **Method**: Re-read task spec + worker result; `grep -rn "800"` in `Sources/` + `Tests/`; read `PagingParameters.swift` (full), `PagingCoreTests.swift` affected regions, `PagingSurfacePendingFinishTests.swift`; verified `PageTargetPolicy.swift` threshold comparison; forbidden-tree `find -newer` sweep; ran `swift test --filter PagingCoreTests`, full `swift test`, `swift build -c debug`, `swift build -c release` serially.

## Verification results

| Check | Result |
|---|---|
| `PagingParameters.swift` `velocityThreshold` value | `700` at :74 (was 800) ✅ |
| Round-16 comment entry added, history/来源 line preserved | ✅ :70-73; round 10–15 entries intact (:49-54, :58-64); `来源：INDEPENDENT_EXPERIMENT；TUNING_REQUIRED；合法范围 200–2000` intact (:73) |
| Other params intact | `displacementThreshold` 0.42 (:56); `retreatDisplacementFactor` 35.0/42.0 (:64); `velocityContribution` 0.3 (:68); `maximumOverscroll` 0.25 (:78); `settleDuration` 0.250 (:82) — unchanged ✅ |
| `PagingCoreTests.swift` asserts follow parameter | :946 & :1028 use `parameters.velocityThreshold`; helper `overshootParameters()` (:906-912) does not override velocityThreshold → reads live 700 ✅ |
| `PagingCoreTests.swift` 5 boundary comments → 700 | ✅ :235 `600 < 700`, :246 `4000 ≥ 700`, :326 `857 ≥ 700`, :918 `≫ 700`, :1090 `600 < 700` |
| `PagingSurfacePendingFinishTests.swift` 2 comments | ✅ :36, :56 correctly present gesture speed 800px/s (400px/0.5s) as `≥ 700` forced path |
| No test asserts literal 800 as velocity constant/threshold | ✅ remaining `800` in Tests are geometry (PagingSurface / AppSearchResponder / KeyboardFocusController frame widths), telemetry iteration counts (TelemetrySessionTests :395/:402/:408), or correct gesture-speed descriptions (TestSupport.swift:81, PagingSurfacePendingFinishTests) |
| `swift test --filter PagingCoreTests` | Executed 70 tests, 0 failures, exit 0 (suite `PagingCoreTests` = 63 green) ✅ |
| `swift test` (full) | **Executed 622 tests, with 0 failures (0 unexpected)**, exit 0 ✅ (matches worker claim exactly) |
| `swift build -c debug` | exit 0 ✅ |
| `swift build -c release` | exit 0 ✅ |
| Forbidden-tree changes | `find Sources/PagingCore Sources/MacAppCatalog Sources/AppGridUI -name '*.swift' -newer <task>` → only `PagingParameters.swift` ✅; AppLaunchController / Package.swift / PagingSurface / AppGridUI / MacAppCatalog untouched ✅ |
| `PageTargetPolicyGesture` logic untouched, uses `>=` | ✅ `PageTargetPolicy.swift` :57/:74/:80 `absVelocity >= parameters.velocityThreshold` |
| No git ops | Repo has no commits (all files `??` untracked); no commit/push/tag possible/performed ✅ |

## Findings

### MINOR
- **`Sources/PagingUI/KeyboardPageTurner.swift:65`** — stale reference comment `远超 velocityThreshold(800)`: after this change the threshold is 700, so the comment is now factually inaccurate. Comment-only; no behavior impact (synthesized fling = 12000px/s ≫ either value; forced-turn path unaffected, and `synthesizeFling` never consults the literal constant). This file sits in `PagingUI/` (not in the task's test-doc scope nor a forbidden tree), and the task forbade "cleanup/formatting outside the two touched lines", so leaving it is defensible — but it is a genuine doc inconsistency this change exposed. Recommend a one-line follow-up doc touch (800 → 700) in a future task; not a blocker.

### QUESTION (non-actionable, informational)
- **`Tests/PagingCoreTests/PagingCoreTests.swift:1090`** — the 5th comment update (`testMomentumOvershootSlowFlingUnclamped`) changed both the described value (`400px/s` → `600px/s`) and the threshold (`< 800` → `< 700`). The threshold update is required and correct; the value 400→600 adjustment presumably matches the actual test gesture velocity and keeps the "non-forced" statement truthful. Verified acceptable; no behavior change.

### BLOCKER / MAJOR
- None.

## Independent conclusion

The worker's claims 1–5 are all independently confirmed. All red lines clean; full suite green at exactly the claimed count (622 / 0 failures); both builds exit 0. The only issue found is a single stale doc comment in a `PagingUI` source file (comment-only, out of the strict change scope). Verdict:

**VERDICT: PASS**

- Executed test count (full suite): **622 (0 failures, exit 0)**
- Build exits: debug **0**, release **0**
- Findings: 1 MINOR (stale `velocityThreshold(800)` doc comment, `KeyboardPageTurner.swift:65`), 1 informational QUESTION — no blockers.
- Report: `Workflow/reviews/T-1D-velocity700-tuning-r1.md`
