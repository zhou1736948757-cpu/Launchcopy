# Frame Hitch Root-Cause Correlation Plan — 2026-08-29

> Status: **Step 1 design complete; implementation not started.**
> Gate: `CAUSALITY_UNRESOLVED`
> This plan does not claim scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or callback-external time as root cause.

---

## 0. Authority and current gate

Authoritative materials read, in order:

1. `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PROMPT.md`
2. `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`
3. `Docs/FRAME_HITCH_DEEP_DIVE_REPORT.md`
4. `Docs/IMPLEMENTATION_LOG.md`
5. `Docs/TIMER_TOLERANCE_AB_RESULTS.md`
6. `Workflow/results/T-targeted-callback-boundary-probe.md`
7. `Workflow/STATE.json`
8. `Workflow/config.json`
9. `Workflow/MAIN_BRIEF.md`
10. `AGENTS.md`
11. `MEMORY.md`
12. `Sources/PagingUI/FrameCallbackProfileRecorder.swift`
13. `Sources/PagingUI/RunLoopProfileRecorder.swift`
14. `Sources/PagingUI/PagingFrameDriver.swift`
15. `Sources/PagingPrototypeApp/AppDelegate.swift`
16. `Tools/analyze_callback_cadence.py`
17. `Tools/analyze_frame_hitches.py` (schema/join discipline only)
18. `Tests/PagingUITests/FrameCallbackProfileTests.swift`
19. `Tests/PagingUITests/RunLoopProfileTests.swift`
20. `Tests/PagingUITests/RunLoopFrameDriverTests.swift`

Current gate, unchanged:

```text
TIMER_ENTRY_TO_POST_ADVANCEFRAME_PROBE_IMPLEMENTED_AND_DIAGNOSTICALLY_VALIDATED
PRECEDING_RECORDED_SEGMENT_THREAD_CPU_INSUFFICIENT_FOR_5_OBSERVED_GT25MS_ENTRY_INTERVALS
POST_RECORDED_EXIT_AND_FIRST_TICK_DELAY_CAUSALITY_UNRESOLVED
FULL_TIMER_CLOSURE_EXIT_UNOBSERVED
CAUSAL_SYSTEM_COMPONENT_NOT_IDENTIFIED
SELFDRIVE_ONLY_FOR_CALLBACK_ABBA
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
REQUIRE_FULL_TIMER_CLOSURE_EXIT_AND_SAME_CLOCK_RUNLOOP_CORRELATION_FOR_DEEPER_CAUSAL_CLAIMS
CAUSALITY_UNRESOLVED
```

Forbidden starting claims: scheduler already confirmed; remainder already proven outside the callback; RunLoop/WindowServer already confirmed; all hitches fixed; 0ms tolerance should become the product default.

---

## 1. Observed hot path (current code, not desired code)

```text
RunLoopFrameDriver.start()
  generation += 1
  if callbackProfiler.isActive:
      nextNominalDeadlineNS = clock.now + interval
      // this sample is NOT written as an arm record
  Timer(interval, repeats:true) added on RunLoop.main .common
  timer.tolerance = 8.333ms or experimental 0ms

Timer fire
  guard self, owner, !owner.isTearingDown else return   // unobserved early exit
  beginCallback()
      CLOCK_MONOTONIC_RAW → entry_ns
      CLOCK_THREAD_CPUTIME_ID → thread_cpu_entry_ns
      first_tick = generation changed or no previous entry
      raw_callback_interval_ns = null if first_tick else entry - last_entry
  handleFrame(now: ProcessInfo.systemUptime)            // DIFFERENT clock domain
      dt from systemUptime lastTimestamp
      PagingSurface.advanceFrame(deltaTime:)
  endCallback()                                         // NOT closure return
      CLOCK_MONOTONIC_RAW → exit_ns          // post-advanceFrame marker
      CLOCK_THREAD_CPUTIME_ID → thread_cpu_exit_ns
      JSON line construction
      in-memory buffer append; enqueue batch at threshold (async writer)
  nextNominalDeadlineNS writeback, generation-guarded
  // lexical closure end; no marker
  Swift/runtime return
  CFRunLoop continues (beforeSources / beforeWaiting / afterWaiting / ...)
  next Timer fire → next beginCallback
```

Parallel, only if `--frame-profile` is on:

```text
RunLoopProfileRecorder observer (common modes)
  activities: entry, beforeTimers, beforeSources, beforeWaiting, afterWaiting, exit
  gap_ns from ContinuousClock
  timestamp from ProcessInfo.systemUptime double
  no observation_seq, no timestamp_ns, no injectable clock
```

`--frame-callback-profile` does **not** currently start the RunLoop recorder.

---

## 2. Boundary table

| Boundary | Currently measured? | Current clock | This-phase plan | Can prove | Cannot prove |
|---|---|---|---|---|---|
| Timer generation arm | No JSONL record. `start()` samples `CLOCK_MONOTONIC_RAW` only to seed `scheduled_ns = now+interval` when profiler is active. Analyzer infers arm as `scheduled_ns - interval_ns`. | Callback: `CLOCK_MONOTONIC_RAW`. Simulation dt / `handleFrame` lastTimestamp: `systemUptime`. | Emit `kind=timer_generation_arm` with `driver_generation`, `arm_ns`, `nominal_first_deadline_ns`, `interval_ns`, `tolerance_ns`. Keep this as a distinct kind so callback analyzer can ignore it. | Recorder-derived arm instant and first-tick delay `first_entry_ns - arm_ns`. Start→stop with zero ticks. Generation 2 arm after reentrant restart. | Kernel Timer arm time, CFRunLoop fire deadline, power/QoS delay, why the first fire is late. |
| Timer closure entry | Yes. `beginCallback` `entry_ns`. | `CLOCK_MONOTONIC_RAW` | Keep. Same shared clock type. | Callback has started executing application code. Raw entry-to-entry interval except first tick. | Time spent runnable-but-unscheduled before entry. |
| `advanceFrame` body | Indirectly inside `entry_ns → exit_ns`. Frame profile (`--frame-profile`) measures a narrower input/state/view window on a different clock (`ContinuousClock`) and is not this probe. | Mixed | Do not change `PagingSurface`/`PagingCore`. Keep body inside recorded segment. | Combined application work from entry through post-advanceFrame. | Which callee consumed the body; AppKit layout/display inside `advanceFrame`. |
| post-advanceFrame marker | Yes, but named `exit_ns`. Sampled at the **start** of `endCallback`, after `advanceFrame` returns. | `CLOCK_MONOTONIC_RAW` | **Keep `exit_ns` semantics unchanged** (compatibility). Document it as post-advanceFrame, not closure return. Optionally add alias field later; do not silently rename meaning. | Wall/CPU from entry to post-advanceFrame (`callback_wall_ns` / `callback_cpu_ns`). | Closure return. JSON/enqueue/deadline bookkeeping. Anything after this marker. |
| JSON + buffer enqueue | Unmeasured; currently **after** `exit_ns` sample, still inside `endCallback`. | n/a | Included in new `closure_tail` interval. | Combined tail wall/CPU after post-advanceFrame. | Individual JSON vs enqueue cost unless a nested overhead sample is added. |
| Nominal deadline writeback | Unmeasured; after `endCallback` returns to the Timer closure. | n/a | Included in `closure_tail` by sampling the tail marker **after** generation-guarded writeback. | Combined bookkeeping + recorder tail. | That writeback is expensive; it is expected to be tiny. |
| closure-return-adjacent marker | No | n/a | Add `pre_return_ns` / `closure_tail_ns` via `defer` after bookkeeping, as close as possible to lexical end. Names: `pre_return_ns`, `thread_cpu_pre_return_ns`. Forbidden names: `closure_return`, `callback_return`, `true_exit`. | `closure_tail_ns = pre_return_ns - exit_ns` and corresponding current-thread CPU. Marker order `entry <= post_advance <= pre_return`. | True closure return. Remaining Swift runtime / ARC after the `defer` body. Scheduler after return. |
| Timer closure return | No, and application code cannot record after return. | n/a | Leave unmeasured. Remainder after `pre_return_ns` is **not** named callback-external until classified. | Nothing directly. | Closure return instant. |
| RunLoop `beforeTimers` | Only with `--frame-profile`. Coarse. No afterTimers in this SDK. | `ContinuousClock` gap + `systemUptime` timestamp | Same-clock `timestamp_ns`. Independent `--runloop-profile`. | Observer fired before timers in this cycle. | That the next gap is timer work. SDK has no `afterTimers`. |
| RunLoop `beforeSources` | Same | Same mismatch | Same-clock `timestamp_ns` + `observation_seq` + `previous_activity`. | Observer fired. | afterSources work; specific source identity. |
| RunLoop `beforeWaiting` → `afterWaiting` | Same | Same mismatch | Classify as `WAITING_BOUNDED` only when both bounds are inside `pre_return_ns → next_entry_ns` on the **same** clock. | Observed waiting-bounded interval. | Scheduler delay, wake-up latency, idle sleep vs blocked wait, WindowServer. |
| RunLoop `entry` / `exit` / mode change | Same | Same mismatch | Keep anonymous mode vocabulary only. | Mode category changed or cycle entered/exited. | Named mode string; that mode-boundary is the hitch cause. |
| next Timer entry | Yes (`entry_ns` of next callback) | `CLOCK_MONOTONIC_RAW` | Keep. Join with RunLoop on same clock. | Full entry-to-entry interval. | Cause of the remainder. |
| Current-thread CPU in recorded body | Yes, `callback_cpu_ns` for `entry → exit`. Max 1.928ms on the five >25ms samples. | `CLOCK_THREAD_CPUTIME_ID` | Keep body CPU; add tail CPU. | CPU consumed by this thread in that interval. | Other threads, preemption, uncore, GPU. Wall − CPU is **not** automatically scheduler. |
| Probe I/O | Async `BufferedJSONLWriter`; hot path must not open/write. | n/a | Keep. No sync file I/O in Timer or observer. | Writer failure counts. | Zero overhead. A/A must measure whether the probe itself lengthens tails. |

### Largest remaining ambiguities

1. **`exit_ns` is not closure return.** Previous remainder (`exit_ns → next entry`) still mixes closure-tail work with everything after return.
2. **Clock domains are not joinable.** Callback uses `CLOCK_MONOTONIC_RAW` ns. RunLoop uses `ContinuousClock` for gaps and `ProcessInfo.systemUptime` (awake time, different epoch/precision) as `timestamp`. `handleFrame` also uses `systemUptime` for simulation dt. Direct subtraction is forbidden.
3. **First-tick delay is inferred, not armed.** `scheduled_ns - interval_ns` is not an arm record. A start with no tick is invisible.
4. **RunLoop observer is coarse and currently coupled to `--frame-profile`.** No `afterTimers`/`afterSources`. `beforeWaiting → afterWaiting` is waiting-bounded, not scheduler.
5. **Previous >25ms evidence is SELFDRIVE-only** and used the old schema. It cannot be retrofitted with tail or same-clock RunLoop joins. This phase must recapture.
6. **One mixed sample (B2 27.055ms)** already had 11.835ms recorded-segment wall vs 0.921ms CPU. Tail split may still leave a large unclassified remainder.

---

## 3. Design decisions (inside accepted plan)

### D1. Shared clock type, same domain, same nanosecond unit

Add `Sources/PagingUI/DiagnosticMonotonicClock.swift` (internal to PagingUI):

- Production wall: `clock_gettime(CLOCK_MONOTONIC_RAW)` with the existing overflow/invalid-read saturation (`0` on failure, `UInt64.max` on overflow).
- Production thread CPU: `CLOCK_THREAD_CPUTIME_ID`.
- Tests inject a fake clock.
- Inactive recorders must not call it.
- Do not treat `Date`, wall clock, `systemUptime`, or `ContinuousClock` as the join key.

`FrameCallbackProfileRecorder.Clock` becomes a thin wrapper around this type, or is replaced by it. `RunLoopProfileRecorder` stops using `ContinuousClock` + `systemUptime` for correlation fields.

Production sharing does not require a single object graph across modules: both recorders calling the same `CLOCK_MONOTONIC_RAW` function is the same domain. Tests **must** inject one fake instance into both.

`handleFrame` continues to use `systemUptime` for simulation dt. That value is animation input, not a correlation timestamp. Do not “fix” it in this phase; mixing it into join math remains forbidden.

### D2. Compatible callback schema, additive tail fields

Keep existing `kind=frame_callback` fields, including `exit_ns` = post-advanceFrame.

Add:

```text
pre_return_ns
thread_cpu_pre_return_ns
closure_tail_wall_ns    // pre_return_ns - exit_ns, rejected if negative
closure_tail_cpu_ns     // thread CPU over the same interval, rejected if negative
```

Do not emit `closure_return`, `callback_return`, or `true_exit`.

Implementation shape:

1. `beginCallback` returns the boundary token (unchanged).
2. `endCallback` samples post-advanceFrame into the token / pending record. It may still compute schedule metrics. It does **not** have to emit the JSON line yet.
3. Driver uses `defer { profiler.markPreReturn(boundary) }` after deadline writeback.
4. `markPreReturn` samples clocks, completes the line, then `appendLine`.

If `endCallback` is skipped, `markPreReturn` must not invent `exit_ns`. Drop or count as invalid; do not clamp.

`defer` review:

- Marker is still before ARC/runtime teardown of the closure.
- After `markPreReturn` returns, some recorder/Swift work may remain; that residual stays unclassified.
- `stop()+start()` generation guard stays on writeback, unchanged in meaning.
- `guard let self, let owner, !tearingDown` before `beginCallback` remains unobserved; that is an early exit with no in-flight callback, not a missing tail.
- Weak owner disappearing after `beginCallback`: `handleFrame` already returns nil dt; `endCallback` still runs; `defer` still runs.

### D3. True arm records

On `start()`, if profiler is active, sample `arm_ns` once and emit:

```text
kind = timer_generation_arm
driver_generation
arm_ns
nominal_first_deadline_ns
interval_ns
tolerance_ns
```

Then set `nextNominalDeadlineNS = nominal_first_deadline_ns`.

First-tick analysis uses `arm_ns`, not `scheduled_ns - interval_ns`.

Checks:

- When late: `arm_ns <= nominal_first_deadline_ns <= first_entry_ns`.
- When early: `first_entry_ns < nominal_first_deadline_ns` is valid; do not reject.
- Start then stop with no tick: arm record exists, no `frame_callback` for that generation.
- Reentrant `stop()+start()`: new generation arm record; old in-flight callback may still complete under the old generation and must not overwrite the new schedule (existing guard).

### D4. Independent same-clock RunLoop recorder

Add `--runloop-profile` (default off). `--frame-profile` continues to start RunLoop as today so old commands keep working, but new RunLoop records use `timestamp_ns`.

New/updated RunLoop schema:

```text
kind
observation_seq
activity
timestamp_ns
gap_ns
previous_activity
mode
```

`thread_cpu_ns` and `runloop_cycle_seq` are **not** in the first implementation unless A/A shows they are necessary. Extra observer work is itself a hitch risk.

Do not write callback sequence into the observer. Analyzer joins by same-clock intervals.

Mode remains `default|eventTracking|modalPanel|other|none`. Raw mode is never stored.

### D5. Analyzer: new correlation tool, old cadence tool kept

Keep `Tools/analyze_callback_cadence.py` for callback-only reports.

Add `Tools/analyze_callback_runloop_correlation.py`:

- Counts: input / accepted callback / rejected callback / ignored non-callback / accepted runloop / rejected runloop / arm records / raw intervals / first ticks / generations / writer failures if present.
- Old callback schema without `pre_return_ns`: accepted as callback, but remainder cannot be split into tail vs post-tail; report `SCHEMA_CALLBACK_WITHOUT_TAIL` and do not silently treat `exit_ns` as pre-return.
- Old runloop schema without `timestamp_ns`: accepted as runloop, **not joinable**; do not subtract `timestamp` (uptime) from `entry_ns`.
- Formulas:

```text
recorded_body_ns = exit_ns - entry_ns
closure_tail_ns = pre_return_ns - exit_ns
post_tail_remainder_ns = next_entry_ns - pre_return_ns
first_tick_delay_ns = first_entry_ns - arm_ns
```

Negative, overflow, missing marker, generation mismatch, or sequence discontinuity → reject or list as invalid. Never clamp to 0.

Join classes for `pre_return_ns → next_entry_ns` (observation classes, not causes):

```text
WAITING_BOUNDED
RUNLOOP_ACTIVE_BOUNDED
MIXED_OBSERVED_BOUNDARIES
NO_OBSERVER_BOUNDARY
UNCLASSIFIED
```

Privacy: no unknown field echo; no paths, run IDs, raw modes, or free text.

### D6. A/A overhead gate before causal capture

Same Release binary, neutral content, same window/fullscreen, same page/item counts, same SELFDRIVE sequence, same Timer tolerance, same duration/teardown.

Arms, interleaved, ≥3 runs each:

| Arm | Flags |
|---|---|
| Control | no callback, no runloop, no frame profile |
| Legacy | `--frame-callback-profile` only |
| Full | `--frame-callback-profile --runloop-profile` |

Telemetry bridge off (`--disable-telemetry-bridge`) for this gate.

Pass rule (narrow): Full must not create a new `>25ms` population that Control/Legacy lack, and must not inflate p99/max of the **target** entry-interval distribution enough to explain the historical 25–72ms samples. If it does, reduce observer/JSON work before any causal claim.

Note: after this implementation, “Legacy” includes the new tail marker. That is an additive field on the existing callback recorder, not a bit-identical replay of yesterday’s binary. Control vs Legacy vs Full still isolates RunLoop-observer cost, which is the dominant probe-risk.

### D7. Formal SELFDRIVE, then physical, then system trace

Formal capture: Release GUI, neutral, 40 SELFDRIVE flings, `run.end` + `teardown.complete`, callback + same-clock runloop on, writeFailureCount == 0. Prefer `tolerance=0` first; optional ABBA `8.333/0/0/8.333` if time allows.

Per-run reporting is mandatory. Every `>25ms` raw interval gets the privacy-safe decomposition table. First ticks stay separate.

Physical trackpad: if a human can operate the machine, collect ≥2 valid runs (real trackpad, fullscreen, real vs neutral content separate, 30–60 gestures, refresh rate recorded, clean teardown). Otherwise:

```text
PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION
```

System trace only if multiple `>25ms` samples remain largely `UNCLASSIFIED` after same-clock join. Then `os_signpost` around Timer closure / advanceFrame / tail / arm, and only then `xctrace` after listing local templates. Runnable-but-unscheduled requires System Trace evidence.

---

## 4. Subagent split (no overlapping writes)

`subagent_mode = ENABLED`. Declared models in `Workflow/config.json` are `glm-5.2` / `deepseek-v4-flash:0731` / `glm-5.3-flash:cloud`. This harness can only spawn `grok-46` / `grok-build` / `packygrok`. **Declared-versus-observed routing is unverified.** First-wave audits inherit the current Main model and are read-only.

### Wave 0 — concurrent read-only audits (3, writes none)

| Task | Objective | Writable scope | Isolation |
|---|---|---|---|
| `T-clock-recorder-audit` | Shared clock, tail marker, disabled fast path, arm records, generation guard | none | read-only |
| `T-runloop-trace-audit` | CFRunLoopObserver proof limits; `--runloop-profile`; local `xctrace` templates | none | read-only |
| `T-analyzer-experiment-audit` | Join algorithm, denominators, A/A and SELFDRIVE protocol | none | read-only |

Quality rationale: no shared writes, no tests that contend on GUI, semantic inputs already materialized as this plan.

### Wave 1 — implementation (serial default unless audits stay disjoint)

If audits do not force a design change:

| Worker | Writable scope |
|---|---|
| A | `Sources/PagingUI/DiagnosticMonotonicClock.swift` (new), `FrameCallbackProfileRecorder.swift`, `RunLoopProfileRecorder.swift`, `PagingFrameDriver.swift`, corresponding Swift tests |
| B | `Tools/analyze_callback_runloop_correlation.py` (new) + `Tools/tests/test_analyze_callback_runloop_correlation.py` (new); may extend but not semantically break `analyze_callback_cadence.py` |
| C | Docs, experiment scripts, Workflow results; no A/B files |

`AppDelegate.swift` / `AppArguments.swift` are a **shared seam**. Main applies that wiring serially after Worker A’s recorder APIs exist. `Package.swift` remains Main-only; no new target is required if the clock file lives in `PagingUI`.

`Sources/PagingCore/` is frozen.

Reviewer is independent and read-only. Main integrates, runs full Swift/Python/Release verification, and closes Workflow.

---

## 5. Gates

### A/A overhead gate

Must pass before interpreting Full-correlation tails as application/system behavior.

### SELFDRIVE diagnostic gate

Per-run + pooled; every `>25ms` sample decomposed; first tick separate; write failures = 0; no `ROOT_CAUSE_FOUND` from this gate alone.

### Physical gate

SELFDRIVE ≠ physical. Missing human operation → `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.

### System trace gate

Only after application-internal boundaries still leave large `UNCLASSIFIED` remainders. Scheduler talk requires runnable-but-unscheduled proof.

### Causal claim gate

`ROOT_CAUSE_FOUND` requires all seven conditions in the prompt §6. Otherwise only:

```text
CANDIDATE_SUPPORTED
PARTIAL_CONTRIBUTOR_SUPPORTED
BOUNDARY_NARROWED
CAUSALITY_UNRESOLVED
```

`FIX_VALIDATED` is out of scope unless a single-variable fix is justified **and** physically retested. This phase is measurement-first.

---

## 6. Planned file range

Expected writes after audits:

```text
Sources/PagingUI/DiagnosticMonotonicClock.swift          (new)
Sources/PagingUI/FrameCallbackProfileRecorder.swift
Sources/PagingUI/RunLoopProfileRecorder.swift
Sources/PagingUI/PagingFrameDriver.swift
Sources/PagingPrototypeApp/AppDelegate.swift             (Main serial)
Sources/PagingPrototypeApp/AppArguments.swift            (Main serial)
Tests/PagingUITests/FrameCallbackProfileTests.swift
Tests/PagingUITests/RunLoopProfileTests.swift
Tests/PagingUITests/RunLoopFrameDriverTests.swift
Tests/PagingUITests/AppArgumentsTests.swift
Tools/analyze_callback_runloop_correlation.py            (new)
Tools/tests/test_analyze_callback_runloop_correlation.py (new)
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md          (this file)
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_ARTIFACTS.sha256
Docs/IMPLEMENTATION_LOG.md
Workflow/tasks/T-*.md
Workflow/results/T-*.md
Workflow/STATE.json
Workflow/events.jsonl
```

Frozen: `Sources/PagingCore/`, LaunchBetter, BuhoReverseNotes. No commit/push/tag/reset/clean.

---

## 7. Execution order

1. Wave 0 read-only audits (this step).
2. Main absorbs audit findings into this plan if they are evidence-backed. Design-level reversals go to Chief; local adaptations stay with Main.
3. Tests first, then recorder/driver implementation, then App wiring.
4. Swift + Python tests, Release build.
5. A/A overhead.
6. Formal SELFDRIVE.
7. Physical or explicit blocked status.
8. System trace only if still unclassified.
9. Results + artifact manifest + Workflow close.

Until step 6 produces new same-clock captures, the five historical >25ms samples remain **old-schema evidence only**.
