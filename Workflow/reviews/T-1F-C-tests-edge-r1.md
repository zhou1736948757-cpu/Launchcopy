# T-1F-C-tests-edge — Review r1

- Reviewer: independent (read-only; no files modified)
- Reviewed: 2026-08-31
- Verdict: **PASS**

## Verification points

### 1. Matrix coverage (task packet §测试矩阵, 8 items → 26 tests)

| Matrix item | Tests | Evidence |
|---|---|---|
| 进入/离开 + hysteresis 回退 | 1–6 | enter left arms dwell; leave → edgeLeft+disarm; x=45 in fallback band (40..<50) keeps .left; right band (350..360] keeps, x=340 leaves; same-zone/outside-zone → [] |
| 首尾边界 (atFirstPage/atLastPage, 不武装) | 7–11 | page 0 left → atFirstPage; last page right → atLastPage; middle page arms; **single-page pageCount=1 both edges** (test 10, incl. cross-zone boundary order); leave boundary zone → edgeLeft |
| dwell 满翻页 + 连续翻页 | 12 | turn at 100.5, stays armed, second turn at 101.0, lastTurnTime updated |
| 翻页最小间隔 | 14 | immediate second dwellElapsed → [] (armed); after 0.41s (>400ms) → turn |
| 过期 timer | 15, 16 | unarmed → []; after leave → [] |
| 左↔右跨区 | 17, 18 | both directions: [.edgeLeft(old)] + [.edgeEntered, .dwellStarted] |
| cancel | 19–21 | armed → [.dwellCancelled], zone nil, armed false, **lastTurnTime preserved**; unarmed → []; re-enter arms freshly |
| nextDwellDeadline | 22–26 | nil unarmed; nil at boundary; now+dwell; max(now+dwell, lastTurn+minInterval); min-interval dominates when dwell shorter |

### 2. Test quality

- Assertions check real behavior: event arrays, `currentZone`, `dwellArmed`, `lastTurnTime` — no tautologies.
- All expectations match `EdgePagingScheduler.swift` semantics line-by-line: `zoneFor` bands (x<40 / x>360, hysteresis 40..<50 / 350..360), `enterEvents` boundary-vs-arm, `dwellElapsed` guard/boundary/min-interval/keep-armed, `cancel` zero-residue with lastTurnTime untouched, `nextDwellDeadline` max rule, cross-zone emission order.
- Timing fully FakeDragClock-driven (`FakeDragClock(100)`, `clock.now()` injection, `clock.current` advances) per DragSessionTestSupport factory requirement.

### 3. Privacy

- Only neutral synthetic geometry (DragPoint x/y, containerWidth 400, page/pageCount ints). No app names, bundle IDs, paths, or real data.

### 4. Scope (mtimes)

- New file `Tests/AppGridUITests/EdgePagingSchedulerTests.swift` @ 09:01:30; result @ 09:02:06; STATE/events/heartbeats/watchdog @ 09:02.
- All `Sources/AppGridUI/DragSession/*` predate (latest EdgePagingScheduler.swift 05:15:14); all existing `Tests/AppGridUITests/*` predate (latest DragDropTests.swift 08:56:58, another task's deliverable). No source or existing test modified.

### 5. Executed count

- `swift test` → **Executed 972 tests, with 0 failures (0 unexpected)**, exit 0 = baseline 946 + 26 ✓
- `swift test --filter EdgePagingSchedulerTests` → Executed 26 tests, 0 failures ✓

## Verification commands (serial, project root)

1. `swift build -c debug` → Build complete!, exit 0 ✓
2. `swift test` → Executed 972 tests, 0 failures, exit 0 ✓
3. `swift build -c release` → Build complete!, exit 0 ✓

## Notes (non-blocking)

- Task packet baseline 837 is stale; orchestrator baseline 946 confirmed by actual run (972 = 946 + 26). Documented in worker result.
- Worker read 2 extra orchestrator-specified reference files (DragSessionEvents.swift, DragSessionController.swift) beyond the packet's 4-file list; consistent with review instructions, no scope violation.

## Verdict

**PASS** — all 8 matrix items covered by 26 tests; assertions match implemented semantics; privacy clean; scope clean; 972/0 confirmed.
