# T-1D-velocity700-tuning — Result

- **Worker**: chef-worker-reviewer-workflow / PagingPrototype
- **Type**: user-decision tuning round 第 16 轮 (parameter-value-only)
- **Date**: 2026-08-30
- **Verdict**: PASS

## Change summary

Single parameter tuned: `velocityThreshold` 800 → 700. Decision logic in
`PageTargetPolicy.swift` / `GestureSession.swift` untouched — the forced-turn
branch reads `parameters.velocityThreshold` so the change is a pure parameter
edit plus test-doc alignment. No commit/push/tag performed.

## Exact before/after

### `Sources/PagingCore/PagingParameters.swift` (lines 70–74)

Before:
```swift
    /// 超过此速度强制翻页（px/s；方向由符号决定）。
    /// 来源：INDEPENDENT_EXPERIMENT；TUNING_REQUIRED；合法范围 200–2000。
    public var velocityThreshold: Double = 800
```

After:
```swift
    /// 超过此速度强制翻页（px/s；方向由符号决定）。
    /// 第 16 轮（2026-08-30）用户决策：强制翻页速度门槛 800 → 700
    /// （"滑了没翻页被回弹太频繁，降低强制翻页速度门槛"）。
    /// 来源：INDEPENDENT_EXPERIMENT；TUNING_REQUIRED；合法范围 200–2000。
    public var velocityThreshold: Double = 700
```

Historical round entries and the `来源：INDEPENDENT_EXPERIMENT；TUNING_REQUIRED；
合法范围 200–2000` line are preserved verbatim (only the round-16 entry added,
value changed). No other `PagingParameters` field changed.

## Test file changes (before/after)

### `Tests/PagingCoreTests/PagingCoreTests.swift`

Only two tests asserted a literal `800` as a velocity constant; both updated to
follow the parameter so they track the live threshold:

- `testMomentumOvershootClampedFastFling`
  - Before: `let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 5), initialPage: 2)`
  - After: `let parameters = overshootParameters(frames: 5)` + harness uses `parameters`
  - Assertion Before: `XCTAssertGreaterThan(h.core.currentSession?.velocityPxPerSecond ?? 0, 800, ...)`
  - Assertion After:  `XCTAssertGreaterThan(h.core.currentSession?.velocityPxPerSecond ?? 0, parameters.velocityThreshold, ...)`
- `testMomentumOvershootSoftDampReverse`
  - Before: `let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 5), initialPage: 3)`
  - After: `let parameters = overshootParameters(frames: 5)` + harness uses `parameters`
  - Assertion Before: `XCTAssertGreaterThan(abs(h.core.currentSession?.velocityPxPerSecond ?? 0), 800, ...)`
  - Assertion After:  `XCTAssertGreaterThan(abs(h.core.currentSession?.velocityPxPerSecond ?? 0), parameters.velocityThreshold, ...)`

Stale boundary comments updated 800 → 700 (behavior identical — verified every
test gesture velocity is either comfortably below 700 or above 800, none in
[700, 800)):
- `testTurnConditionMet`: comment `600 px/s < 800` → `600 px/s < 700`
- `testHighVelocitySmallDisplacement`: comment `4000 px/s ≥ 800` → `≥ 700`
- `testRetreatVelocityForcedPathUnaffected`: comment `857 px/s（≥ 800）` → `（≥ 700）`
- `testMomentumOvershootClampedFastFling`: comment `delta/dt ≫ 800` → `≫ 700`
- `testMomentumOvershootSlowFlingUnclamped`: comment `速度 400px/s < 800 非强制` → `速度 600px/s < 700 非强制`

### `Tests/PagingUITests/PagingSurfacePendingFinishTests.swift`

`testEndedWithNoFurtherEventsAutoFinishes` gesture is 400px/0.5s = 800px/s, which
is ≥ 700, i.e. the forced-turn path (and was already forced under `>=800`). Only
comments reworded to be truthful; no gesture/behavior change, test still passes:
- `gestureChanged(...) // 慢滑（800px/s < 强制阈值 → 位移主导）` →
  `// 400px/0.5s = 800px/s ≥ 强制阈值（700）→ 速度强制翻页`
- assert message `"慢滑位移 0.4 ≥ 0.5 阈值 → 翻页"` → `"速度强制（800px/s ≥ 700）→ 翻页"`

Other `800` occurrences in `Tests/` were checked and left intact as unrelated:
telemetry iteration/event counts (TelemetrySessionTests) and view/page-size
geometry (`800` px frame/pageWidth in PagingSurfaceTests, AppSearchResponderTests,
KeyboardFocusControllerTests). `TestSupport.swift:81` doc comment references the
computed speed 800px/s (400/0.5) which remains a forced-turn gesture (≥ 700) — kept.

No test file asserts a literal `800` as a velocity constant after this change.

## Gate results

- **`swift test`**: `Executed 622 tests, with 0 failures (0 unexpected)` — exit **0**.
  (Baseline 620 + 2 tests landed by the parallel T-1D-layout-centering-repair task;
  full suite green at the tree as-of-run-time.)
- **`swift build -c debug`**: exit **0**.
- **`swift build -c release`**: exit **0**.
- **Forbidden-tree check**
  `find Sources/PagingCore Sources/MacAppCatalog Sources/AppGridUI -name '*.swift' -newer Workflow/tasks/T-1D-velocity700-tuning.md`
  → returned **only `Sources/PagingCore/PagingParameters.swift`** (the single intended
  parameter file; it changes by design). No `PageTargetPolicy.swift`,
  `GestureSession.swift`, `AppLaunchController.swift`, `Package.swift`,
  `PagingSurface.swift`, `AppGridUI/`, `MacAppCatalog/` touched.

## Files changed

1. `Sources/PagingCore/PagingParameters.swift` (velocityThreshold 800→700 + round-16 comment)
2. `Tests/PagingCoreTests/PagingCoreTests.swift` (two assertions → `parameters.velocityThreshold`; 5 comments 800→700)
3. `Tests/PagingUITests/PagingSurfacePendingFinishTests.swift` (2 truthfulness comments)

Note: this is user-decision tuning round 16 — no logic change, parameter-only, per
Main's round-16 decision to lower the forced-page-turn velocity gate because
snap-back ("滑了没翻页被回弹") happened too often.
