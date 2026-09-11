# Frame Hitch Correlation — Durable Checkpoint

> Date: 2026-08-29
> Owner: Main
> Gate: **`CAUSALITY_UNRESOLVED`**
> Purpose: survive context loss. This is operational memory, not a causal report.

Do not treat this file as `ROOT_CAUSE_FOUND`. Old JSONL cannot be retrofitted with tail or same-clock RunLoop joins.

---

## 1. What is already true (previous phase)

Five SELFDRIVE `>25ms` entry-to-entry samples had preceding recorded-segment current-thread CPU ≤ 1.928ms. Most wall time sat after `exit_ns`.

`exit_ns` is **post-advanceFrame**, sampled at the start of `endCallback`. It is **not** Timer closure return.

First-tick delays are a separate distribution. Historical first-tick delay used `scheduled_ns - interval_ns` as a fake arm. That inference is forbidden going forward.

Clock mismatch that blocked joins:

| Stream | Clock | Forbidden join |
|---|---|---|
| callback `entry_ns` / `exit_ns` | `CLOCK_MONOTONIC_RAW` | — |
| callback `handleFrame` dt | `ProcessInfo.systemUptime` | not a join key |
| old RunLoop `gap_ns` | `ContinuousClock` | not joinable to callback ns |
| old RunLoop `timestamp` | `systemUptime` double | never subtract from `entry_ns` |

Authoritative previous report: `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`.

---

## 2. Implementation landed this session (not yet fully verified)

### Shared clock

`Sources/PagingUI/DiagnosticMonotonicClock.swift`

- Production wall: `CLOCK_MONOTONIC_RAW`
- Production CPU: `CLOCK_THREAD_CPUTIME_ID`
- Tests inject a fake clock
- Inactive recorders must not call it

### Callback recorder

`Sources/PagingUI/FrameCallbackProfileRecorder.swift`

- `recordGenerationArm` emits `kind=timer_generation_arm`
- `beginCallback` → `entry_ns`
- `endCallback` samples post-advanceFrame into a pending record, **does not emit JSON**
- `markPreReturn` samples `pre_return_ns` and emits `kind=frame_callback`
- `flush()` of a pending without pre-return increments `incompleteDropCount` and drops it
- Negative tail deltas emit JSON `null`, not clamped 0
- `droppedRecordCount` for buffer overflow
- `exit_ns` meaning **unchanged** (post-advanceFrame)

### Driver

`Sources/PagingUI/PagingFrameDriver.swift`

```text
start() → recordGenerationArm
Timer:
  beginCallback
  defer { markPreReturn }     // NOT named closure_return
  handleFrame / advanceFrame
  endCallback                 // post-advanceFrame
  generation-guarded deadline writeback
  // defer runs here
```

Early `guard let self, owner, !tearingDown` still returns before begin.

### RunLoop recorder

`Sources/PagingUI/RunLoopProfileRecorder.swift`

- `timestamp_ns` from shared monotonic clock (join key)
- Keep legacy `timestamp` (uptime) for old hitch analyzer; **do not join it**
- New fields: `observation_seq`, `previous_activity`
- `recordObservationForTesting` for fake-clock tests
- No observer `thread_cpu_ns` in v1

### App wiring

- `--runloop-profile` independent flag
- `--frame-profile` still starts RunLoop (compat)
- Both flags together → **one** observer
- AppDelegate constructs one `DiagnosticMonotonicClock.system` and injects it into callback + RunLoop recorders
- `Sources/PagingCore/` not modified

### Formulas

```text
recorded_body_ns        = exit_ns - entry_ns
closure_tail_ns         = pre_return_ns - exit_ns
post_tail_remainder_ns  = next_entry_ns - pre_return_ns
first_tick_delay_ns     = first_entry_ns - arm_ns
```

Negative / missing / overflow / cross-generation → invalid. Never clamp to 0 in the analyzer.

---

## 3. JSON schema (emit these exact kinds)

### `timer_generation_arm`

```text
kind, driver_generation, arm_ns, nominal_first_deadline_ns, interval_ns, tolerance_ns
```

### `frame_callback` (additive vs old schema)

Old fields kept. New:

```text
pre_return_ns
thread_cpu_pre_return_ns
closure_tail_wall_ns    // null if pre_return < exit
closure_tail_cpu_ns     // null if cpu_pre < cpu_exit
```

Forbidden field names: `closure_return`, `callback_return`, `true_exit`.

### `runloop`

```text
kind=runloop
activity
observation_seq
timestamp_ns            // JOIN KEY
gap_ns
previous_activity
mode                    // default|eventTracking|modalPanel|other|none
since_same_ns
timestamp               // uptime leftover, NOT a join key
```

Privacy: never raw mode, paths, app names, bundle IDs, URLs, search terms, icon data.

---

## 4. Analyzer contract (Worker B must implement)

New file only:

```text
Tools/analyze_callback_runloop_correlation.py
Tools/tests/test_analyze_callback_runloop_correlation.py
```

Do **not** change `analyze_callback_cadence.py` semantics. Old cadence analyzer may keep using `scheduled_ns - interval` for historical files; the new analyzer must use `arm_ns`.

Join classes (observation, not root cause):

| Class | Rule |
|---|---|
| `NO_OBSERVER_BOUNDARY` | no runloop `timestamp_ns` in `[pre_return_ns, next_entry_ns]` |
| `WAITING_BOUNDED` | ≥1 consecutive pair `beforeWaiting → afterWaiting` in window, and no other consecutive pairs |
| `RUNLOOP_ACTIVE_BOUNDED` | ≥1 consecutive non-waiting pair in window, and no waiting pairs |
| `MIXED_OBSERVED_BOUNDARIES` | both waiting and active pairs |
| `UNCLASSIFIED` | observers present but no consecutive pair, unknown activity, or invalid order |

Also report `waiting_pair_ns`, `active_pair_ns`, `uncovered_ns` where:

```text
uncovered_ns = (first_obs - pre_return) + (next_entry - last_obs)
```

if no observers, `uncovered_ns = post_tail_remainder_ns`. Do not clamp negatives; mark invalid.

Old callback without `pre_return_ns`: accept as `SCHEMA_CALLBACK_WITHOUT_TAIL`; do not invent tail.

Old runloop without `timestamp_ns`: accept as runloop, **not joinable**. Never join `timestamp` to `entry_ns`.

First ticks: join `timer_generation_arm` of the same `driver_generation`. If no arm, `FIRST_TICK_WITHOUT_ARM`, do not infer from `scheduled_ns - interval_ns`.

Denominators required in Markdown:

```text
input records
accepted callback records
rejected callback records
ignored non-callback records
accepted arm records
rejected arm records
accepted runloop records
rejected runloop records
raw intervals analyzed
first ticks analyzed separately
generations observed
invalid samples
```

---

## 4b. A/A outcome (this session)

- Swift 462/0, Python 40/0, Release `e42535a9054fb5a66dd66052416c21d68519fa6b13d0c62b72900ce035726d9d`.
- A/A overhead gate **PASS** vs Legacy. Full first argv attempt invalid; retries valid.
- Two `>25ms` samples ~26.5ms: tail <0.01ms; remainder ~19ms; Full sample `MIXED_OBSERVED_BOUNDARIES`.
- Gate now: `BOUNDARY_NARROWED` + `CAUSALITY_UNRESOLVED`.
- Physical still `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.
- Details: `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md`.

## 5. Remaining work

1. **Worker B**: correlation analyzer + Python tests (`Tools/` only).
2. **Worker C**: A/A + SELFDRIVE capture protocol (`Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CAPTURE_PROTOCOL.md` only).
3. **Main**: `swift test`, `swift build -c release`, then Python tests after B returns.
4. A/A overhead gate before causal interpretation:

```text
Control: no profilers
Legacy:  --frame-callback-profile
Full:    --frame-callback-profile --runloop-profile
```

Release, `--neutral-content`, `--disable-telemetry-bridge`, `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`, ≥3 interleaved runs/arm, same tolerance. Legacy on this binary includes the new tail marker (documented deviation).

5. Formal SELFDRIVE recapture; per-run + every `>25ms` sample.
6. Physical: capture or `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.
7. System trace only if remainders stay largely `UNCLASSIFIED`.

---

## 6. File ownership right now

| Owner | May write | Must not write |
|---|---|---|
| Main | Swift sources/tests already landed; CHECKPOINT; STATE/events; verification | `Tools/analyze_callback_runloop_correlation.py` while B is live; C's protocol file while C is live |
| Worker B | the two Tools analyzer files + `Workflow/results/T-callback-runloop-correlation-analyzer.md` | `Sources/`, `Docs/`, `Package.swift`, `PagingCore/` |
| Worker C | `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CAPTURE_PROTOCOL.md` + `Workflow/results/T-correlation-capture-protocol.md` | `Sources/`, `Tools/`, `Package.swift` |
| Frozen | `Sources/PagingCore/` | everyone |
| Forbidden trees | LaunchBetter, BuhoReverseNotes | everyone |

No commit / push / tag / reset / clean.

---

## 7. Claims still forbidden

```text
ROOT_CAUSE_FOUND
SCHEDULER_CONFIRMED
RUNLOOP_CONFIRMED
WINDOWSERVER_CONFIRMED
GPU_CONFIRMED
ALL_HITCHES_FIXED
FIX_VALIDATED
```

Allowed: `BOUNDARY_NARROWED` only after new same-clock captures exist. Until then: `CAUSALITY_UNRESOLVED`.
