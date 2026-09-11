# Frame Hitch Root-Cause Correlation — Results

> Date: 2026-08-29
> Gate: **`BOUNDARY_NARROWED`**, still **`CAUSALITY_UNRESOLVED`**
> Physical: **`PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`**

This is not `ROOT_CAUSE_FOUND`. Closure-tail and same-clock RunLoop joins exist; they do not identify a system component.

---

## Narrow gate

```text
SHARED_MONOTONIC_CLOCK_AND_PRE_RETURN_MARKER_IMPLEMENTED
TIMER_GENERATION_ARM_RECORDED
A_A_PROBE_OVERHEAD_GATE_PASSED_FOR_FULL_VS_LEGACY
CLOSURE_TAIL_TOO_SMALL_TO_EXPLAIN_GT25MS_REMAINDER
POST_PRE_RETURN_REMAINDER_STILL_MAJORITY
ONE_SAME_CLOCK_GT25MS_SAMPLE_CLASSIFIED_MIXED_OBSERVED_BOUNDARIES
HISTORICAL_72MS_TAIL_NOT_REPRODUCED_IN_THIS_CAPTURE
CAUSALITY_UNRESOLVED
PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION
```

Forbidden claims that are **not** supported: `ROOT_CAUSE_FOUND`, `SCHEDULER_CONFIRMED`, `RUNLOOP_CONFIRMED`, `WINDOWSERVER_CONFIRMED`, `GPU_CONFIRMED`, `ALL_HITCHES_FIXED`, `FIX_VALIDATED`.

---

## MEASURED

### Implementation / tests

- Swift: **462 tests, 0 failures** (was 454).
- Python: **40 tests, 0 failures** (cadence 5 + hitch 15 + correlation 20).
- Release build: PASS.
- Release executable SHA-256: `e42535a9054fb5a66dd66052416c21d68519fa6b13d0c62b72900ce035726d9d`.
- Debug executable SHA-256 (this session’s test binary): `5446b7c92854c429e6c54e6bdd8010c53558fa7863a1fa4dc3f7332264d6286b`.
- `Sources/PagingCore/` not modified.

### A/A protocol notes

- Release GUI, `--neutral-content`, `--disable-telemetry-bridge`, `--frame-timer-tolerance-ms 0`, 40 SELFDRIVE flings, exit 0.
- Control `aa-c1..c3`: no interval JSONL (by design); all printed `flings=40` and terminated.
- Legacy `aa-l1..l3`: `--frame-callback-profile` only.
- Full first attempt `f1..f3` was **invalid**: two profiler flags were passed as one argv token, parse failed, app started on **defaults** (tolerance 8.333ms, no profilers). Discarded.
- Full retry `aa-f1..f3`: `--frame-callback-profile --runloop-profile` as separate argv; JSONL present. These three Full runs are consecutive, not re-interleaved with new Control/Legacy. Recorded as operator repair.
- Legacy on this binary includes the new `pre_return_ns` marker (documented deviation vs yesterday’s recorder).

### Per-run raw entry intervals (not first ticks)

| Run | raw n | p50 ms | p95 ms | p99 ms | max ms | >20 | >25 | >33.3 | >50 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| aa-l1 | 488 | 16.670 | 18.031 | 20.095 | 24.044 | 6 | 0 | 0 | 0 |
| aa-l2 | 488 | 16.672 | 18.172 | 19.330 | 21.928 | 4 | 0 | 0 | 0 |
| aa-l3 | 488 | 16.663 | 18.118 | 20.499 | 26.549 | 6 | 1 | 0 | 0 |
| aa-f1 | 451 | 16.673 | 17.914 | 18.331 | 22.079 | 2 | 0 | 0 | 0 |
| aa-f2 | 450 | 16.675 | 18.096 | 20.191 | 26.542 | 5 | 1 | 0 | 0 |
| aa-f3 | 477 | 16.663 | 18.069 | 18.550 | 24.261 | 2 | 0 | 0 | 0 |

Rejected callback/arm/runloop records: 0 on all six valid profiler runs. Invalid samples: 0.

### A/A overhead gate

Full did **not** create a `>25ms` population that Legacy lacks (both 0 or 1 sample, max ≈ 26.5ms). Full p99 is not inflated into the historical 25–72ms band. Closure-tail p99 is <0.01ms on both arms.

**A/A overhead gate: PASS** (narrow: this binary, this SELFDRIVE sequence, tolerance=0).

### `>25ms` raw-interval decomposition

Formulas:

```text
recorded_body_ns       = exit_ns - entry_ns          // preceding callback
closure_tail_ns        = pre_return_ns - exit_ns
post_tail_remainder_ns = next_entry_ns - pre_return_ns
```

| Run | gen/seq | interval ms | preceding body wall/CPU ms | tail wall/CPU ms | remainder ms | join class | waiting/active/uncovered ms | first tick? |
|---|---|---:|---:|---:|---:|---|---:|---|
| aa-l3 | 28/421 | 26.549 | 7.650 / 7.651 | 0.007 / 0.003 | 18.892 | NO_OBSERVER_BOUNDARY | 0 / 0 / 18.892 | no |
| aa-f2 | 40/453 | 26.542 | 6.792 / 6.793 | 0.004 / 0.002 | 19.746 | MIXED_OBSERVED_BOUNDARIES | 6.608 / 13.014 / 0.123 | no |

Mode: `default` only.

### First ticks (separate)

All first ticks had a matching `timer_generation_arm`. None used `scheduled_ns - interval_ns`. None exceeded 25ms. Arm p99 ≈ 18.7–18.9ms, max ≈ 18.7–19.0ms.

### Closure tail distribution

Median tail ≈ 0.001–0.003ms; p99 < 0.01ms; max ≤ 0.027ms. Too small to explain a `>25ms` entry interval.

---

## SUPPORTED INFERENCE

1. The previously unmeasured closure-tail (JSON/enqueue/deadline writeback) is **not** the main remainder of these `>25ms` samples.
2. After `pre_return_ns`, a majority remainder still exists (~19ms of ~26.5ms).
3. On the one same-clock `>25ms` sample, RunLoop observers cover almost all of that remainder (`uncovered` 0.123ms) as **mixed** waiting-like and active-like pairs, not as a single `WAITING_BOUNDED` class.
4. These two `>25ms` samples also have a substantial on-CPU recorded body (~7ms wall ≈ CPU). That is a different shape from the earlier five-sample set whose preceding CPU was ≤ 1.928ms. Do not collapse the two captures into one mechanism.
5. Full-correlation probe overhead is not a plausible explanation of the historical 72ms tail.

Join classes remain observations, not causes.

---

## UNRESOLVED

- Why the mixed waiting+active remainder is ~19ms.
- Whether the ~7ms on-CPU body is AppKit/view work, probe-adjacent work, or something else (no stacks).
- Historical 27–72ms tails and 25–35ms first-tick delays: not reproduced here.
- Runnable-but-unscheduled: **not** evidenced. System Trace was not opened because remainders were not largely `UNCLASSIFIED`.
- Physical trackpad correlation.

---

## INTERVENTION RESULT

No product intervention. Production Timer tolerance remains 8.333ms. `REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE` still holds.

---

## PHYSICAL STATUS

Four valid human trackpad runs, 60Hz, fullscreen, same Release binary, Full profilers, telemetry bridge off, normal quit. **Not pooled with SELFDRIVE.**

User-reported ~40 serious gestures per run.

| Run | Content | wall s | raw n | p99 ms | max ms | >20 | >25 | >33.3 |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| phys-n1 | neutral | ~47 | 1369 | 20.944 | 24.289 | 28 | 0 | 0 |
| phys-n2 | neutral | ~88 | 1724 | 20.596 | 21.575 | 22 | 0 | 0 |
| phys-r1 | real | ~41 | 1042 | 19.284 | 25.102 | 9 | 1 | 0 |
| phys-r2 | real | ~49 | 1151 | 19.131 | 25.296 | 10 | 1 | 0 |

Physical `>25ms` samples (real content only):

| Run | gen/seq | interval ms | preceding body wall/CPU ms | tail ms | remainder ms | join class | waiting/active/uncovered ms | mode |
|---|---|---:|---:|---:|---:|---|---:|---|
| phys-r1 | 98/964 | 25.102 | 0.214 / 0.214 | 0.001 | 24.888 | MIXED_OBSERVED_BOUNDARIES | 14.468 / 10.397 / 0.022 | default |
| phys-r2 | 16/157 | 25.296 | 0.265 / 0.265 | 0.001 | 25.030 | MIXED_OBSERVED_BOUNDARIES | 14.237 / 10.768 / 0.026 | default |

Neutral physical runs had **zero** `>25ms`. Real-content physical runs each had **one** barely-over-25ms interval whose remainder is almost the whole interval, with tiny on-CPU body and tiny tail. Both same-clock joins are Mixed (waiting-like ~14ms + active-like ~10ms), uncovered ~0.02ms.

This does **not** clear `ROOT_CAUSE_FOUND`. It does clear the blocked physical token for this 60Hz Full-profiler protocol:

```text
PHYSICAL_CORRELATED_CAPTURE_COMPLETED_60HZ
PHYSICAL_AND_SELFDRIVE_NOT_POOLED
CAUSALITY_UNRESOLVED
```

120Hz remains `BLOCKED_BY_HARDWARE` if the panel is 60Hz.

---

## DEEP ANALYSIS (same-clock remainder, 2026-08-29 later)

Join class `MIXED_OBSERVED_BOUNDARIES` is too coarse. Pair-level dump of the remainder:

### Physical real-content `>25ms` (repeatable)

Both phys-r1 and phys-r2:

1. Tiny preceding body (~0.2ms, wall ≈ CPU) and tiny tail (~0.001ms).
2. One or two `beforeWaiting → afterWaiting` slices totaling ~14ms.
3. A **stable ~10.0–10.2ms `exit → entry` gap** in `default` mode.
4. Uncovered ~0.02ms.

The ~10ms slice was labeled “active” only because it is not a waiting pair. **It is not evidence of 10ms of AppKit/CPU work.** `CFRunLoop` **left** this run invocation (`exit`) and **10ms later entered again** (`entry`). During that gap this observer sees no activities.

Candidate (not root cause): a timed/nested `CFRunLoopRunInMode` (~10ms), AppKit returning from a runloop run, or the thread running/waiting **outside** this runloop invocation. Not named scheduler/WindowServer.

### SELFDRIVE 36.5ms sample (System Trace run `corr-st-sd1`)

Different shape:

- Body 0.67ms CPU.
- Remainder 35.9ms.
- Almost all of it is **`beforeSources → exit` = 35.5ms**, with **no** `beforeWaiting` in that hole.
- Then a 0.2ms `exit → entry`.

That is “stuck after `beforeTimers`/`beforeSources` until `exit`”, i.e. source processing or a blocked source callback. SDK has no `afterSources`, so it cannot be split further.

SELFDRIVE aa-f2 26.5ms was yet another shape: 6.8ms on-CPU body + 6.6ms wait + 12.8ms `afterWaiting → exit`.

**Do not merge physical 25ms, SELFDRIVE 26.5ms, and SELFDRIVE 36.5ms into one mechanism.**

### Trace status

- Signposts now use category `PointsOfInterest` (`TimerGenerationArm`, `TimerCallback`, `AdvanceFrame`, `CallbackTail`). System Trace recorded them.
- Time Profiler XML stacks were unsymbolicated addresses; not used for attribution.
- System Trace `thread-narrative` rows matching the process were a GCD worker (`workq_kernreturn` idle 15ms), **not** the hitching main-thread 35ms window. Main-thread runnable-but-unscheduled is **not** proven.
- Trace binary SHA-256 `4232b607…` (signpost build). Physical binary was `e42535a9…` (no signposts). Do not mix.

```text
REMAINDER_PAIR_STRUCTURE_NARROWED
PHYSICAL_GT25_DOMINATED_BY_WAIT_PLUS_10MS_RUNLOOP_EXIT_ENTRY
SELFDRIVE_36MS_DOMINATED_BY_BEFORESOURCES_TO_EXIT
MIXED_CLASS_OVERSTATES_ACTIVE_CPU
SCHEDULER_NOT_PROVEN
CAUSALITY_UNRESOLVED
```

### ~10ms `exit → entry` is rare and lines up with the 23–25ms physical tail

Whole-run pair histograms (physical, tolerance=0):

| Pair | Typical (p50) | ~10ms count | Notes |
|---|---:|---:|---|
| `exit → entry` | 0.012–0.014ms | r1: 6 in [9.5,10.6]; r2: 10; n1: 3; SELFDRIVE aa-f2: **0** | Not a 10ms metronome |
| `beforeWaiting → afterWaiting` | 0.015ms | hundreds near 10ms | Common idle; 60Hz-ish tail |
| `beforeSources → exit` | 0.016ms | ~0 near 10ms | Long outliers exist but not the physical >25ms shape |

Every physical `>25ms` sample’s remainder **contains** one of those rare ~10ms `exit → entry` gaps. The same gap also sits inside many **23–24.8ms** intervals (just under the 25ms line):

- phys-r1 examples overlapping a ~9–10ms `exit → entry`: 19.87, 24.71, 23.55, 24.59, 24.53, **25.10**, 24.77, 24.39ms
- phys-r2: 24.49, 23.91, **25.30**, 24.81, 24.59, 24.39, 24.33ms
- phys-n1 max **24.29ms** is the same pattern

So on **physical + tolerance=0**, a ~10ms runloop leave/re-enter is a **repeatable partial contributor to the 20–25ms band**. It is **not** the old Timer-tolerance 8.333ms contributor (that A/B was SELFDRIVE). SELFDRIVE aa-f2 had **zero** 10ms `exit → entry`.

Allowed label:

```text
PARTIAL_CONTRIBUTOR_SUPPORTED
PHYSICAL_20_TO_25MS_RUNLOOP_EXIT_ENTRY_APPROX_10MS
```

Still not `ROOT_CAUSE_FOUND`: no single-variable intervention, no ABBA after a fix, no proof of *why* the runloop leaves for 10ms (nested `CFRunLoopRunInMode`, AppKit spin, mach wait outside this invocation). Scheduler still unproven.

System Trace note: the first ST template used a **5s window** and missed JSONL hitches. A second ST with `--window 30s` kept 24s but that SELFDRIVE run had **no** `>25ms`.

### Physical + System Trace session (`phys-st-r1`, 86s window)

User trackpad, real content, same flags, app launched **under** System Trace. JSONL complete (1428 callbacks). Signposts map 1:1 onto callbacks.

This session is **not** a clean physical replicate:

| | Previous phys-r1 (no ST) | This phys-st-r1 (with ST) |
|---|---:|---:|
| `>25ms` | 1 | **25** |
| max | 25.10ms | **46.39ms** |
| `exit→entry` in 8–12ms | 17 | **322** |

System Trace itself inflated leave/re-enter gaps. Do not use this run’s rates as the physical hitch rate.

Longest hitch in this traced run (gen 142 / seq 1329, 46.385ms) still has the **same shape**, stretched:

- body 0.94ms
- `beforeWaiting→afterWaiting` 1.34ms + **10.32ms**
- then **`exit→entry` 31.99ms** (trace 01:19.716 → 01:19.748)
- next `TimerCallback` begin at 01:19.749 (matches JSONL 46.387ms)

So the 10ms leave/re-enter survived under tracing and **grew** to ~32ms. That is consistent with “runloop invocation not running”, not with extra `advanceFrame` work (AdvanceFrame signposts stay sub-millisecond except one 5ms).

Exported `thread-state` / `context-switch` / `syscall` tables from this `.trace` **contain no PagingPrototypeApp rows**, so this capture still does **not** prove whether those 32ms were Running, Blocked, Idle, or runnable-but-unscheduled. Instruments GUI on the same file may still show the main thread at 01:19.716–01:19.748.

Authoritative 10ms partial contributor remains the **untraced** phys-r1/r2 JSONL, not this ST session.

---

## Evidence files

Per-run analyzer Markdown: `Docs/CALLBACK_CORRELATION_aa-l1-20260829.md` … `aa-f3-20260829.md`.
Hash manifest: `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_ARTIFACTS.sha256`.
Checkpoint: `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CHECKPOINT.md`.
