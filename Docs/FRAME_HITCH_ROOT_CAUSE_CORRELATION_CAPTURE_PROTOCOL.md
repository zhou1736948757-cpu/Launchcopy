# Frame Hitch Correlation — Capture Protocol

> Date: 2026-08-29
> Owner: Worker C (protocol only; this file does not execute captures)
> Gate: **`CAUSALITY_UNRESOLVED`**
> Physical status: **`PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`**

This is an operator protocol for A/A probe-overhead, formal SELFDRIVE recapture, and physical trackpad capture. It is **not** a causal report. Old JSONL cannot be retrofitted with `pre_return_ns` or same-clock RunLoop joins. Do not write `ROOT_CAUSE_FOUND`.

Do **not** run these GUI commands from a Worker session that is only allowed to write this protocol. Main (or a human operator) executes them after the Release binary and correlation analyzer exist.

---

## 0. Gate and forbidden claims

Current gate, unchanged until new same-clock captures exist **and** the A/A overhead gate passes:

```text
CAUSALITY_UNRESOLVED
TIMER_ENTRY_TO_POST_ADVANCEFRAME_PROBE_IMPLEMENTED_AND_DIAGNOSTICALLY_VALIDATED
PRECEDING_RECORDED_SEGMENT_THREAD_CPU_INSUFFICIENT_FOR_5_OBSERVED_GT25MS_ENTRY_INTERVALS
POST_RECORDED_EXIT_AND_FIRST_TICK_DELAY_CAUSALITY_UNRESOLVED
FULL_TIMER_CLOSURE_EXIT_UNOBSERVED
CAUSAL_SYSTEM_COMPONENT_NOT_IDENTIFIED
SELFDRIVE_ONLY_FOR_CALLBACK_ABBA
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
REQUIRE_FULL_TIMER_CLOSURE_EXIT_AND_SAME_CLOCK_RUNLOOP_CORRELATION_FOR_DEEPER_CAUSAL_CLAIMS
```

Forbidden in any capture log, table, or follow-up report produced under this protocol:

```text
ROOT_CAUSE_FOUND
SCHEDULER_CONFIRMED
RUNLOOP_CONFIRMED
WINDOWSERVER_CONFIRMED
GPU_CONFIRMED
ALL_HITCHES_FIXED
FIX_VALIDATED
```

Allowed after **new** same-clock Full captures exist **and** A/A passes: `BOUNDARY_NARROWED`. Until then: `CAUSALITY_UNRESOLVED`.

Join classes (`WAITING_BOUNDED`, `RUNLOOP_ACTIVE_BOUNDED`, `MIXED_OBSERVED_BOUNDARIES`, `NO_OBSERVER_BOUNDARY`, `UNCLASSIFIED`) are **observation labels**, not causes. `beforeWaiting → afterWaiting` is waiting-bounded, not scheduler.

SELFDRIVE is synthetic. It is not a physical feel gate and cannot change the production Timer tolerance default.

---

## 1. Build the single Release binary

Project root:

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype
```

Build once. Reuse this exact binary for every A/A arm, every formal SELFDRIVE recapture, and (if a human operates the machine) physical runs in this phase.

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
swift build -c release
```

Binary path (relative to project root):

```text
.build/release/PagingPrototypeApp
```

Absolute path:

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/release/PagingPrototypeApp
```

Record SHA-256 **before the first capture** and keep it for the artifact manifest:

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
shasum -a 256 .build/release/PagingPrototypeApp
```

Rules:

- Do **not** use `swift run` for captures. It may rebuild.
- Do **not** rebuild between Control / Legacy / Full, or between A/A and formal SELFDRIVE, unless the binary is broken. A rebuild is a new experiment.
- Do **not** use Debug.
- Do **not** set `PAGING_PROTOTYPE_SMOKE` or `PAGING_PROTOTYPE_PERF`.
- Captures require a real Aqua GUI session. Headless / SSH-without-display is invalid.

---

## 2. Fixed capture constants

Pin these for every A/A and formal SELFDRIVE run in this protocol. Do not vary them to “see what happens.”

| Constant | Value | Why |
|---|---|---|
| Configuration | Release | production-like |
| Content | `--neutral-content` | Phase 1A placeholder; no catalog/icon scan |
| Telemetry bridge | `--disable-telemetry-bridge` | isolate callback/RunLoop probes; no frame-hook queue |
| `--paging-telemetry` | **omit** | telemetry-off isolation track |
| `--frame-profile` | **omit** | would add a second profiler and start RunLoop via the compat path |
| Frame source | `--frame-driver runloop` | Phase 1A Timer path; default, pinned |
| Timer tolerance | `--frame-timer-tolerance-ms 0` | remove known 8.333ms 20–25ms short-tail contributor |
| Pages / items | `--page-count 5 --items-per-page 35` | same load as prior callback ABBA |
| Reduce Motion | `--reduce-motion-override off` | freeze the system-preference confound |
| Window | **omit** `--fullscreen` | windowed, matching prior callback ABBA |
| SELFDRIVE | `PAGING_PROTOTYPE_GUI_SELFDRIVE=1` | 40 synthetic flings, then teardown + terminate |
| Fling count | 40 (hard-coded in AppDelegate) | not a CLI flag |

Documented deviation vs older binaries: **Legacy on this binary includes the new closure-tail `pre_return_ns` marker.** It is not a bit-identical replay of the 2026-08-29 callback-ABBA recorder. Control vs Legacy vs Full still isolates RunLoop-observer cost, which is the dominant probe risk.

Telemetry remains off. Completeness is **not** `run.end` / `teardown.complete` (those events require the bridge). Completeness substitutes:

```text
process exit 0
SELFDRIVE stats line printed with flings=40
process self-terminates after teardown
Legacy/Full: profiler JSONL present, last line is a complete JSON object
```

SELFDRIVE schedule (AppDelegate, not configurable):

```text
first fling at t = 0.6s
interval between flings = 0.4s
finishDelay = 0.6 + 40 * 0.4 + 2.5 = 19.1s
then print SELFDRIVE stats → teardownAll() → NSApp.terminate
```

Expected stdout fragments (do **not** paste file paths from these lines into reports):

```text
paging-telemetry-bridge: disabled for controlled callback cadence experiment
SELFDRIVE: frame source = runloop Timer 60Hz; tolerance=0.000ms; not vsync-aligned
paging-prototype: --neutral-content 回归模式：Phase 1A 中性 placeholder（不装配真实 catalog）
SELFDRIVE stats: flings=40 committed=… stales=… live=… pool=… layouts=… telemetryEvents=0
```

Legacy also prints `paging-frame-callback-profile: …`. Full also prints `paging-runloop-profile: …`. Copy **counts** from stdout, not paths.

### Artifact files (operator-only; do not copy into reports)

JSONL names are derived from the sanitized `--run-id` (`[A-Za-z0-9._-]`, max 64):

```text
/tmp/launch-copy-paging-prototype-<run-id>-callback.jsonl
/tmp/launch-copy-paging-prototype-<run-id>-runloop.jsonl
```

Before each run: if a file with that run-id already exists, **abort and pick a new run-id**. Do not append onto a previous capture.

Stdout may be redirected for operator bookkeeping. Reports must not include those redirect paths.

---

## 3. Privacy (reports)

Run IDs in this protocol contain only arm letters, a run index, and a date. They must not contain user paths, hostnames, or content names.

Published reports (Docs, Workflow results, analyzer Markdown) **must not** contain:

```text
app names
bundle IDs
application paths or user paths
URLs
search terms
icon data
raw RunLoop mode strings
window titles or user input
unknown JSON field echo
filesystem paths of JSONL / stdout / the binary
```

RunLoop `mode` in tables may only be:

```text
default | eventTracking | modalPanel | other | none
```

Identify runs in reports by **arm label + index**, for example `aa-c1`, `aa-l2`, `sd-f1`. Do not paste `--run-id` values out of JSON. Do not paste `/tmp/…` paths.

Operator commands in **this** protocol file may mention project-root and `/tmp` artifact **patterns** so the experiment is runnable. That exception does not extend to capture reports.

---

## 4. A/A overhead gate (must pass before causal interpretation)

Same Release binary, same window, same page/item counts, same SELFDRIVE sequence, same Timer tolerance, same duration/teardown.

### 4.1 Arms

| Arm | Code | Profiler flags | Interval JSONL |
|---|---|---|---|
| Control | `c` | none | none (by design) |
| Legacy | `l` | `--frame-callback-profile` | callback only |
| Full | `f` | `--frame-callback-profile --runloop-profile` | callback + runloop |

`--frame-profile` is forbidden on all three arms.

### 4.2 Interleave (≥3 runs each, 9 runs)

Do not run all Control, then all Legacy, then all Full. Round-robin:

```text
c1  l1  f1
c2  l2  f2
c3  l3  f3
```

Minimum 3 per arm. Extra repeats, if taken, continue the same round-robin (`c4 l4 f4` …). One run is never a conclusion.

### 4.3 Run-id pattern

```text
corr-aa-{arm}{n}-YYYYMMDD
```

`{arm}` is `c` | `l` | `f`. `{n}` is the 1-based index for that arm. Substitute the actual UTC date.

Examples for 2026-08-29:

```text
corr-aa-c1-20260829
corr-aa-l1-20260829
corr-aa-f1-20260829
corr-aa-c2-20260829
corr-aa-l2-20260829
corr-aa-f2-20260829
corr-aa-c3-20260829
corr-aa-l3-20260829
corr-aa-f3-20260829
```

### 4.4 Exact argv

Shared prefix (all arms). Run from the project root. `DATE` is `YYYYMMDD`.

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
BIN=".build/release/PagingPrototypeApp"
DATE=YYYYMMDD   # operator substitutes, e.g. 20260829
```

**Control `cN`:**

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 "$BIN" \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --run-id "corr-aa-c${N}-${DATE}"
```

Worked example (`c1`, `DATE=20260829`):

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 .build/release/PagingPrototypeApp \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --run-id corr-aa-c1-20260829
```

**Legacy `lN`:**

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 "$BIN" \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --frame-callback-profile \
  --run-id "corr-aa-l${N}-${DATE}"
```

Worked example (`l1`):

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 .build/release/PagingPrototypeApp \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --frame-callback-profile \
  --run-id corr-aa-l1-20260829
```

**Full `fN`:**

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 "$BIN" \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --frame-callback-profile \
  --runloop-profile \
  --run-id "corr-aa-f${N}-${DATE}"
```

Worked example (`f1`):

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 .build/release/PagingPrototypeApp \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --frame-callback-profile \
  --runloop-profile \
  --run-id corr-aa-f1-20260829
```

Wait for each process to exit 0 before starting the next arm. Do not overlap GUI instances.

### 4.5 Control has no interval JSONL

Control turns **both** profilers off and disables the telemetry bridge, so there is **no** entry-to-entry interval distribution for Control.

Do **not** treat “Control has zero `>25ms` samples” as evidence that Control lacks a long-tail population. Control contributes:

- exit code
- SELFDRIVE stats (`flings/committed/stales/live/pool/layouts/telemetryEvents`)
- wall duration to self-terminate
- confirmation that callback and runloop JSONL were **not** created for that run-id

**Target interval comparison is Legacy vs Full** (both emit `kind=frame_callback`). Control is a behavioral / file-creation baseline only.

### 4.6 Metrics to record (per run)

Fill one row per run. First ticks stay out of the raw-interval distribution.

| Column | Control | Legacy | Full |
|---|---|---|---|
| arm label | `aa-cN` | `aa-lN` | `aa-fN` |
| exit code | required | required | required |
| SELFDRIVE `flings` | must be 40 | must be 40 | must be 40 |
| SELFDRIVE `committed` / `stales` / `live` / `pool` / `layouts` | record | record | record |
| `telemetryEvents` | expect 0 | expect 0 | expect 0 |
| callback JSONL present | must be **no** | must be **yes** | must be **yes** |
| runloop JSONL present | must be **no** | must be **no** | must be **yes** |
| callback input / accepted / rejected / ignored non-callback | n/a | cadence analyzer | cadence + correlation analyzer |
| accepted arm records / rejected arm records | n/a | if analyzer reports them | required |
| accepted / rejected runloop records | 0 / n/a | 0 / n/a | required |
| raw intervals analyzed | n/a | required | required |
| first ticks analyzed separately | n/a | required | required |
| generations observed | n/a | required | required |
| invalid samples | n/a | required | required |
| p50 / p95 / p99 / max of **raw entry-to-entry intervals** (ms) | n/a | required | required |
| `>20` / `>25` / `>33.3` / `>50` counts and /1000 rates | n/a | required | required |
| recorded-body wall/CPU summary (p50/p95/max) | n/a | required | required |
| closure-tail wall/CPU summary (p50/p95/max) | n/a | required if `pre_return_ns` present | required |
| `writeFailureCount` | n/a (no writer) | see §4.7 | see §4.7 |
| `droppedRecordCount` / `incompleteDropCount` | n/a | see §4.7 | see §4.7 |
| runloop records / s | 0 | 0 | required |

Cadence analyzer (Legacy and Full callback files). Operator-local path; do not paste it into the published report:

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
PYTHONPATH=. python3 Tools/analyze_callback_cadence.py \
  /tmp/launch-copy-paging-prototype-corr-aa-l1-YYYYMMDD-callback.jsonl \
  --format markdown
```

Full also runs the correlation analyzer (§8).

RunLoop records/s for Full:

```text
runloop_records_per_s =
  accepted_runloop_records
  / ((last_joinable_timestamp_ns - first_joinable_timestamp_ns) / 1e9)
```

Use `timestamp_ns` only (join key). Do **not** use leftover uptime `timestamp`. If `timestamp_ns` is missing, the run is **not joinable**; still count records and mark records/s as `approximate` using the 19.1s SELFDRIVE finishDelay as denominator.

### 4.7 `writeFailureCount` (current binary)

`FrameCallbackProfileRecorder.writeFailureCount`, `droppedRecordCount`, and `incompleteDropCount` (and the RunLoop equivalents) are in-process counters. **AppDelegate does not print them.** After process exit they are gone.

Do not invent `writeFailureCount == 0`. Record:

```text
writeFailureCount: unobserved (no stdout counter)
JSONL completeness: pass | fail
```

JSONL completeness **pass** requires all of:

1. Legacy/Full printed the matching `paging-*-profile:` line;
2. the JSONL exists after exit;
3. the last non-empty line parses as a JSON object;
4. callback accepted count is in the historical SELFDRIVE band for this load (prior callback ABBA: about 489–533 accepted callbacks, about 25–31 generations with callbacks). Far below that band is a suspected drop/`incompleteDrop` and makes the run `INVALID_RUN`.

JSONL completeness **fail** → `INVALID_RUN`. Do not put that run in pooled tail rates. Keep the files; do not delete.

If a later Main change prints the counters on stdout, record the printed integers and require `writeFailureCount == 0` for a valid run. This protocol does not authorize that code change.

### 4.8 Invalid-run rules (A/A)

Mark `INVALID_RUN` and repeat that arm slot (do not silently drop the artifact) if any of:

- exit ≠ 0
- no `SELFDRIVE stats` line, or `flings` ≠ 40
- process did not self-terminate
- Control created a callback or runloop JSONL
- Legacy created a runloop JSONL, or lacked callback JSONL
- Full lacked callback or runloop JSONL
- JSONL completeness fail (§4.7)
- operator reused a run-id and appended to an old file

Keep invalid artifacts. Do not pretend the interleave is complete until each of `c1..c3`, `l1..l3`, `f1..f3` has one valid run.

### 4.9 Pass / fail rule for probe overhead

Evaluate **after** ≥3 valid runs per arm. Compare **Legacy vs Full** on the **raw entry-to-entry interval** distribution (first ticks excluded). Control is not an interval denominator.

**FAIL** (stop; do not interpret Full tails as application or system root cause) if any of the following holds:

1. **New `>25ms` population.** Full produces a cluster of raw intervals `>25ms` that Legacy counterpart runs lack. A “new population” means more than an isolated single-sample outlier: for example Full has `>25ms` in ≥2 of 3 runs while Legacy has `>25ms` in 0 of 3, or Full’s pooled `>25` rate is several times Legacy’s and is not one shared long sample.
2. **Probe-sized inflation of the historical tail.** Full p99 or max of raw entry intervals moves into (or across) the historical 25–72ms band in a way Legacy does not, such that the added probe work **could explain** those historical samples. Concrete fail examples: Legacy max stays `<25ms` in all valid runs while Full max is `≥25ms` in ≥2 runs; or Full p99 rises by several milliseconds relative to Legacy **and** Full newly occupies `>33.3ms` or `>50ms` while Legacy does not.
3. **RunLoop observer blow-up.** Full runloop records/s or JSONL completeness indicates the observer is saturating the writer (`JSONL completeness fail`, or record volume so large that drops are likely). Then reduce observer/JSON work before any causal claim.

**PASS** (narrow) only if:

- Full does **not** create a new `>25ms` population that Legacy lacks;
- Full p99/max stay the same order of magnitude as Legacy and are **not** large enough to explain the historical 25–72ms samples by themselves;
- JSONL completeness passes on every valid Legacy/Full run used in the comparison;
- Control still completes 40 flings / exit 0 with no profiler files.

**PASS does not mean the hitch is understood.** It only means Full’s added RunLoop observer + tail marker is not an obvious manufacturer of a new long-tail population, so later Full captures **may** be interpreted as application/system behavior rather than probe artifact.

If the gate **FAIL**s:

```text
PROBE_OVERHEAD_GATE_FAILED
DO_NOT_INTERPRET_FULL_TAILS_AS_APP_ROOT_CAUSE
CAUSALITY_UNRESOLVED
```

Reduce observer/JSON work. Do not proceed to causal reading of Full remainders. Isolated one-off tails that appear in **both** Legacy and Full (or only Legacy) are **not** automatically probe overhead; they also are not root cause.

Pooled A/A numbers are descriptive only. Always publish the per-run table. One ugly Full run must not be hidden inside a pool, and one clean Full run must not wash out two dirty ones.

---

## 5. Formal SELFDRIVE recapture (after A/A PASS)

Do not start this section if §4.9 failed.

Goal: new same-clock captures with callback tail + RunLoop `timestamp_ns`. Prefer `tolerance=0` first (this section). Optional tolerance ABBA is §5.4.

These runs **are** Full-profile captures. They are still SELFDRIVE. They are not physical. Gate remains `CAUSALITY_UNRESOLVED` even if `>25ms` samples reappear.

### 5.1 Run-id pattern

```text
corr-sd-f{n}-YYYYMMDD
```

Minimum **3** valid Full runs, sequential (`f1`, `f2`, `f3`). Same binary as A/A.

### 5.2 Exact argv

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
BIN=".build/release/PagingPrototypeApp"
DATE=YYYYMMDD
```

**Formal SELFDRIVE Full `fN`:**

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 "$BIN" \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --frame-callback-profile \
  --runloop-profile \
  --run-id "corr-sd-f${N}-${DATE}"
```

Worked example (`f1`, `DATE=20260829`):

```bash
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 .build/release/PagingPrototypeApp \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --frame-callback-profile \
  --runloop-profile \
  --run-id corr-sd-f1-20260829
```

`f2` / `f3` change only `--run-id` to `corr-sd-f2-YYYYMMDD` / `corr-sd-f3-YYYYMMDD`.

Required flags on every formal recapture: `--frame-callback-profile` and `--runloop-profile` together. Do not recapture callback-only and claim same-clock joins.

### 5.3 Per-run reporting (mandatory)

Do not publish pooled-only numbers. For each valid run, record the §4.6 Full columns **plus** every raw interval **strictly `>25ms`** in the sample table in §5.5.

Analyzer invocation after each run (Worker B CLI; if the file is not present yet, this is still the intended command):

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
PYTHONPATH=. python3 Tools/analyze_callback_runloop_correlation.py \
  --callback /tmp/launch-copy-paging-prototype-corr-sd-f1-YYYYMMDD-callback.jsonl \
  --runloop /tmp/launch-copy-paging-prototype-corr-sd-f1-YYYYMMDD-runloop.jsonl \
  --format markdown
```

Markdown **must** include these denominators:

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

Also record writer/drop/failure **if the analyzer or stdout exposes them**; otherwise JSONL completeness from §4.7.

Valid formal run additionally requires:

- A/A overhead already **PASS**
- both JSONLs complete
- correlation analyzer exit 0
- first ticks **not** mixed into raw-interval p50/p95/p99/max

Old callback JSONL without `pre_return_ns` is `SCHEMA_CALLBACK_WITHOUT_TAIL` and is **not** a formal recapture. Old runloop JSONL without `timestamp_ns` is **not joinable**. Never subtract uptime `timestamp` from `entry_ns`.

### 5.4 Optional tolerance ABBA (not required to start 0ms recapture)

If time allows **after** three valid `tolerance=0` Full recaptures, repeat Full flags with:

```text
A1 = --frame-timer-tolerance-ms 8.333   corr-sd-a1-YYYYMMDD
B1 = --frame-timer-tolerance-ms 0       corr-sd-b1-YYYYMMDD
B2 = --frame-timer-tolerance-ms 0       corr-sd-b2-YYYYMMDD
A2 = --frame-timer-tolerance-ms 8.333   corr-sd-a2-YYYYMMDD
```

Same shared flags as §5.2 except tolerance and run-id. This checks whether join-class conclusions hold across tolerance. It does **not** authorize changing the production default.

### 5.5 Every `>25ms` sample table

Required columns (privacy-safe; wall **and** current-thread CPU, not wall only):

| Run | generation/seq | first tick? | entry interval ms | recorded body wall ms | recorded body CPU ms | post-advance→tail wall ms | post-advance→tail CPU ms | tail→next-entry ms | RunLoop boundary class | waiting_pair ms | active_pair ms | uncovered ms | mode |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|

`Run` is an arm label (`sd-f1`), not a path or JSON run-id. `mode` is one of the five allowed categories.

Formulas (never clamp negatives to 0; negative / missing / overflow / cross-generation / sequence break → invalid, list separately):

```text
recorded_body_ns        = exit_ns - entry_ns
closure_tail_ns         = pre_return_ns - exit_ns
post_tail_remainder_ns  = next_entry_ns - pre_return_ns
first_tick_delay_ns     = first_entry_ns - arm_ns
uncovered_ns            = (first_obs - pre_return) + (next_entry - last_obs)
                          if no observers: uncovered_ns = post_tail_remainder_ns
```

`exit_ns` is post-`advanceFrame`, sampled at the start of `endCallback`. It is **not** Timer closure return. `pre_return_ns` is closure-return-**adjacent**. Remainder after `pre_return_ns` is **not** named callback-external.

First-tick rows use `timer_generation_arm` of the **same** `driver_generation`. If no arm: `FIRST_TICK_WITHOUT_ARM`. Do **not** infer arm as `scheduled_ns - interval_ns`. First ticks are a separate distribution; they do not enter raw-interval p50/p95/p99/max or `>25ms` raw-interval rates. If a first tick is `>25ms`, put it in a **separate** first-tick table with the same columns, `first tick? = yes`.

Join classes (observation only):

| Class | Rule |
|---|---|
| `NO_OBSERVER_BOUNDARY` | no runloop `timestamp_ns` in `[pre_return_ns, next_entry_ns]` |
| `WAITING_BOUNDED` | ≥1 consecutive `beforeWaiting → afterWaiting` in the window, and no other consecutive pairs |
| `RUNLOOP_ACTIVE_BOUNDED` | ≥1 consecutive non-waiting pair in the window, and no waiting pairs |
| `MIXED_OBSERVED_BOUNDARIES` | both waiting and active pairs |
| `UNCLASSIFIED` | observers present but no consecutive pair, unknown activity, or invalid order |

Do not promote any class to `SCHEDULER_CONFIRMED` / `RUNLOOP_CONFIRMED`.

---

## 6. Physical trackpad protocol

SELFDRIVE cannot substitute for this section.

### 6.1 Current status

This Worker session does not operate the machine. Until a human completes §6.2 with ≥2 valid physical runs:

```text
PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION
```

That token is the **authoritative physical status** right now. More SELFDRIVE runs do not clear it.

### 6.2 When a human can operate the machine

Unset SELFDRIVE. Same Release binary. Full profilers on. Telemetry bridge still off. Neutral and real content are **separate pools** — never mix them.

**Neutral physical `nN` (windowed or fullscreen pinned per session; prefer fullscreen):**

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
# Do NOT set PAGING_PROTOTYPE_GUI_SELFDRIVE
.build/release/PagingPrototypeApp \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --fullscreen \
  --frame-callback-profile \
  --runloop-profile \
  --run-id corr-phys-n1-YYYYMMDD
```

**Real-content physical `rN` (no `--neutral-content`):**

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
.build/release/PagingPrototypeApp \
  --disable-telemetry-bridge \
  --frame-timer-tolerance-ms 0 \
  --page-count 5 \
  --items-per-page 35 \
  --frame-driver runloop \
  --reduce-motion-override off \
  --fullscreen \
  --frame-callback-profile \
  --runloop-profile \
  --run-id corr-phys-r1-YYYYMMDD
```

Human script, each valid run:

1. Real physical trackpad (not a mouse, not synthetic scroll).
2. Enter fullscreen; wait until the Space is stable.
3. Record **numeric refresh rate only** (60 or 120). Do not record display product names.
4. Perform about **30–60** forward / back / interrupt gestures over 30–90s. Do not script them with SELFDRIVE.
5. Quit via the app’s normal teardown (close window or Quit) so profilers flush. Do not force-kill.
6. Repeat for ≥2 valid runs **per content pool** that will be claimed (`n1 n2` and/or `r1 r2`).
7. Analyze with the same correlation command as §8, using that run’s callback + runloop JSONL.
8. Fill the §5.5 table. Mark the run context `PHYSICAL`, never pool with SELFDRIVE.

Valid physical run: exit 0, both JSONLs complete, human gesture count in band, refresh rate recorded as a number, teardown flush observed.

If the human cannot complete this, leave the status token as:

```text
PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION
```

---

## 7. System trace (later; not part of this capture wave)

Only if **multiple** formal-SELFDRIVE `>25ms` samples still have large `UNCLASSIFIED` remainders after same-clock join. Then, and only then:

1. Add low-overhead `os_signpost` around Timer closure / `advanceFrame` / tail / generation arm (requires a separate implementation task; not this protocol).
2. List local `xctrace` templates on the machine; do not guess names.
3. Capture Time Profiler or System Trace on a later wave.

Runnable-but-unscheduled requires System Trace evidence. Time-adjacent WindowServer/GPU samples are not confirmation.

If trace is not taken:

```text
APPLICATION_INTERNAL_BOUNDARIES_NARROWED   # only if new same-clock captures exist
SYSTEM_CAUSAL_COMPONENT_UNRESOLVED
CAUSALITY_UNRESOLVED
```

Do not run `xctrace` as part of A/A or the first formal SELFDRIVE recapture.

---

## 8. Analyzer command

New tool (Worker B). Do not change `Tools/analyze_callback_cadence.py` semantics for this protocol. If `Tools/analyze_callback_runloop_correlation.py` is not on disk yet, still use this command once it exists.

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
PYTHONPATH=. python3 Tools/analyze_callback_runloop_correlation.py \
  --callback /tmp/launch-copy-paging-prototype-<run-id>-callback.jsonl \
  --runloop /tmp/launch-copy-paging-prototype-<run-id>-runloop.jsonl \
  --format markdown
```

Worked example (formal SELFDRIVE `f1`):

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
PYTHONPATH=. python3 Tools/analyze_callback_runloop_correlation.py \
  --callback /tmp/launch-copy-paging-prototype-corr-sd-f1-20260829-callback.jsonl \
  --runloop /tmp/launch-copy-paging-prototype-corr-sd-f1-20260829-runloop.jsonl \
  --format markdown
```

A/A Full `f1`:

```bash
PYTHONPATH=. python3 Tools/analyze_callback_runloop_correlation.py \
  --callback /tmp/launch-copy-paging-prototype-corr-aa-f1-20260829-callback.jsonl \
  --runloop /tmp/launch-copy-paging-prototype-corr-aa-f1-20260829-runloop.jsonl \
  --format markdown
```

Legacy A/A has no runloop file. Use cadence only (§4.6). Do not invent a runloop path.

Successful analyzer Markdown must not echo paths, run IDs, raw modes, or unknown fields. CLI stderr may mention an input path on failure; do not copy that into Docs reports.

First-tick analysis in the **new** analyzer must use `arm_ns`, not `scheduled_ns - interval_ns`.

---

## 9. Order of operations (checklist)

1. `cd` project; `swift build -c release`; record SHA-256 of `.build/release/PagingPrototypeApp`.
2. Confirm correlation analyzer exists, or wait for Worker B; the command in §8 is still the contract.
3. A/A 9-run interleave `c1 l1 f1 c2 l2 f2 c3 l3 f3` at tolerance 0, same binary (§4).
4. Apply §4.9. If FAIL: stop causal reading; reduce probe cost.
5. If PASS: formal SELFDRIVE Full recapture `corr-sd-f1..f3` with `--frame-callback-profile --runloop-profile` (§5).
6. Per-run tables + every `>25ms` sample row. First ticks separate.
7. Physical: execute §6.2 **or** keep `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.
8. System trace only if remainders stay largely `UNCLASSIFIED` (§7).
9. Gate stays `CAUSALITY_UNRESOLVED` unless the seven causal conditions in the correlation prompt §6 are all met. This protocol alone cannot meet them.

---

## 10. What this protocol does not do

- It does not execute 40-fling GUI captures.
- It does not modify Swift, Python analyzers, CHECKPOINT, PLAN, IMPLEMENTATION_LOG, or STATE.
- It does not change production Timer tolerance.
- It does not treat historical 5 `>25ms` samples as same-clock evidence.
- It does not claim scheduler, RunLoop, WindowServer, AppKit, Core Animation, or GPU.
- It does not write `ROOT_CAUSE_FOUND`.
