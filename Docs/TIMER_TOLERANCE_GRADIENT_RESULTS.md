# Timer Tolerance Gradient — Frame-Callback Delivery Rhythm (T-A1)

**Task:** Measure the frame-callback delivery rhythm of the app's RunLoop Timer frame source
under 4 Timer tolerance values (8.333 / 0 / 4 / 2 ms) using the built-in SELFDRIVE mode
(synthetic flings, `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`). Produces the "tolerance gradient"
table for a short-tail (20–25 ms frame gaps) investigation.

**Scope:** Investigation-only measurement. **No source, test, or default value was changed.**
Only this results document and `/tmp` logs were written.

---

## 1. Binary

- Build: `swift build -c release` → **exit 0** (Build complete).
- Binary: `.build/release/PagingPrototypeApp`
- **SHA-256:** `29ea6928e81cfaf8568d7bbe8bdeca24617cf2e9ade313aa85a6bd90764469c7`

## 2. Protocol & validity

8 SELFDRIVE sessions run in the fixed order (arm = tolerance ms):

| Run | Arm (ms) |
|-----|----------|
| G1  | 8.333    |
| G2  | 0        |
| G3  | 4        |
| G4  | 2        |
| G5  | 2        |
| G6  | 4        |
| G7  | 0        |
| G8  | 8.333    |

Each run:
```
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 .build/release/PagingPrototypeApp \
  --neutral-content --disable-telemetry-bridge --frame-callback-profile \
  --frame-timer-tolerance-ms <ARM>
```
No `--frame-profile` / `--runloop-profile` (main track). Stdout saved to `/tmp/t-a1-run-<n>.log`.
All 8 runs exited 0 and printed `SELFDRIVE stats: flings=40 …` (full tour + teardown path
reached). **All 8 runs valid; no retries required.**

> **Validity-marker adaptation (documented):** the protocol's nominal markers `run.end=1` and
> `teardown.complete=1` are telemetry events written only when telemetry is enabled. The main
> track runs with `--disable-telemetry-bridge`, which sets `effectiveTelemetryEnabled=false`
> (AppDelegate.swift:53), so no telemetry JSONL is produced and those markers cannot appear.
> The equivalent completion markers in the main track are the `SELFDRIVE stats: flings=40 …`
> stdout line (printed immediately before `teardownAll()` + `NSApp.terminate`, AppDelegate.swift:465-470)
> together with a clean exit code 0. All 8 runs satisfied both.

**Callback JSONL attribution:** `/tmp/launch-copy-paging-prototype-<runID>-callback.jsonl`
snapshotted before/after each run; the new file was attributed to that run. Schema (per
`FrameCallbackProfileRecorder`): `timer_generation_arm` records carry `arm_ns` /
`driver_generation` / `tolerance_ns`; `frame_callback` records carry `entry_ns` /
`raw_callback_interval_ns` (null for `first_tick`), `first_tick`, `driver_generation`,
`nominal_interval_ns`, `lateness_ns`, `missed_periods`.

**Interval metric:** `raw_callback_interval_ns` (delta between consecutive callback entries,
already nulled by the recorder for the first tick of each generation) converted to ms.

**First-tick metric:** per generation, `arm_ns → first callback entry_ns` of that generation
(the recorder's `first_tick` boundary). Pooled p50/p99/max per arm. Run-start first-tick
(first arm → first callback of the run) also reported per run.

---

## 3. Per-run table

| Run | Arm (ms) | Exit | N int | p50 | p95 | p99 | max | >20ms | 20–25ms | >25ms | >33.3ms | >50ms | committed | stales |
|-----|----------|------|-------|-----|-----|-----|-----|-------|---------|-------|---------|-------|-----------|--------|
| G1  | 8.333    | 0    | 579   | 16.67 | 18.57 | 24.09 | 47.84 | 13 (22.5) | 7 (12.1) | 6 (10.4) | 2 (3.5) | 0 (0.0) | 12 | 28 |
| G2  | 0        | 0    | 486   | 16.67 | 17.55 | 19.62 | 31.83 | 4 (8.2)  | 2 (4.1)  | 2 (4.1)  | 0 (0.0) | 0 (0.0) | 29 | 11 |
| G3  | 4        | 0    | 527   | 16.68 | 18.74 | 21.22 | 34.44 | 9 (17.1) | 6 (11.4) | 3 (5.7)  | 1 (1.9) | 0 (0.0) | 13 | 27 |
| G4  | 2        | 0    | 580   | 16.67 | 18.04 | 19.32 | 40.93 | 5 (8.6)  | 2 (3.4)  | 3 (5.2)  | 1 (1.7) | 0 (0.0) | 12 | 28 |
| G5  | 2        | 0    | 574   | 16.67 | 17.83 | 21.10 | 94.70 | 8 (13.9) | 4 (7.0)  | 4 (7.0)  | 2 (3.5) | 1 (1.7) | 12 | 28 |
| G6  | 4        | 0    | 604   | 16.67 | 18.69 | 20.14 | 30.55 | 7 (11.6) | 6 (9.9)  | 1 (1.7)  | 0 (0.0) | 0 (0.0) | 12 | 28 |
| G7  | 0        | 0    | 491   | 16.67 | 17.57 | 19.73 | 32.04 | 5 (10.2) | 3 (6.1)  | 2 (4.1)  | 0 (0.0) | 0 (0.0) | 28 | 12 |
| G8  | 8.333    | 0    | 572   | 16.68 | 18.97 | 29.49 | 33.30 | 19 (33.2) | 11 (19.2) | 8 (14.0) | 1 (1.7) | 0 (0.0) | 12 | 28 |

Threshold counts shown as `absolute (per-1000 intervals)`. All intervals in ms.

---

## 4. Per-arm pooled table

| Arm (ms) | N int | p50 | p95 | p99 | max | mean | >20ms | 20–25ms | >25ms | >33.3ms | >50ms |
|----------|-------|-----|-----|-----|-----|------|-------|---------|-------|---------|-------|
| 8.333    | 1151  | 16.67 | 18.71 | 28.08 | 47.84 | 16.90 | 32 (27.8) | 18 (15.6) | 14 (12.2) | 3 (2.6) | 0 (0.0) |
| 4        | 1131  | 16.68 | 18.74 | 20.47 | 34.44 | 16.72 | 16 (14.1) | 12 (10.6) | 4 (3.5)  | 1 (0.9) | 0 (0.0) |
| 2        | 1154  | 16.67 | 17.91 | 20.96 | 94.70 | 16.80 | 13 (11.3) | 6 (5.2)  | 7 (6.1)  | 3 (2.6) | 1 (0.9) |
| 0        | 977   | 16.67 | 17.57 | 19.63 | 32.04 | 16.69 | 9 (9.2)  | 5 (5.1)  | 4 (4.1)  | 0 (0.0) | 0 (0.0) |

Threshold counts shown as `absolute (per-1000 intervals)`. All intervals in ms.

---

## 5. First-tick table

Per-generation first-tick latency (`arm_ns → first callback entry_ns` of that generation),
pooled per arm:

| Arm (ms) | N first-ticks | p50 (ms) | p99 (ms) | max (ms) |
|----------|---------------|----------|----------|----------|
| 8.333    | 68            | 24.46    | 31.58    | 40.44    |
| 4        | 65            | 19.99    | 26.68    | 37.01    |
| 2        | 68            | 18.35    | 30.71    | 54.76    |
| 0        | 50            | 17.59    | 31.35    | 41.83    |

Run-start first-tick (first arm → first callback of the run), per run:

| Run | Arm (ms) | run-start first-tick (ms) |
|-----|----------|---------------------------|
| G1  | 8.333    | 22.09                     |
| G2  | 0        | 20.43                     |
| G3  | 4        | 18.00                     |
| G4  | 2        | 54.76                     |
| G5  | 2        | 17.66                     |
| G6  | 4        | 37.01                     |
| G7  | 0        | 41.83                     |
| G8  | 8.333    | 27.22                     |

Note: run-start first-tick is highly variable (17–55 ms) and dominated by app startup /
fullscreen transition, not by tolerance. The per-generation first-tick table is the more
stable signal.

---

## 6. Commit / stale table

From the SELFDRIVE stdout `SELFDRIVE stats` line (committed = `surface.core.commitCount`,
stales = `surface.core.staleRejectionCount`). Pooled per arm (mean of the 2 runs):

| Arm (ms) | committed (run1, run2) | committed (pooled) | stales (run1, run2) | stales (pooled) |
|----------|------------------------|--------------------|---------------------|------------------|
| 8.333    | 12, 12                 | 12.0               | 28, 28              | 28.0             |
| 4        | 13, 12                 | 12.5               | 27, 28              | 27.5             |
| 2        | 12, 12                 | 12.0               | 28, 28              | 28.0             |
| 0        | 29, 28                 | 28.5               | 11, 12              | 11.5             |

**Interrupted count:** not available in the main track. The SELFDRIVE stdout reports only
`committed` / `stales` / `live` / `pool` / `layouts` / `telemetryEvents`; the callback JSONL
does not carry an interruption counter. The protocol's fallback telemetry track is specified
only to count commits, and commits are already available from the main track stdout (HARD
metric satisfied), so no extra telemetry track was run. Interrupted is recorded as
**not captured** in this measurement.

---

## 7. Interpretation bullets (rules applied; production default NOT decided)

1. **Short-tail monotonicity (20–25 ms rate):** 8.333 (15.6/1k) > 4 (10.6/1k) > 2 (5.2/1k) > 0 (5.1/1k).
   Monotonicity **holds**; 2 ≈ 0 (5.2 vs 5.1) is within the allowed "2≈0" tolerance.
2. **"4 ms sufficient"** iff 4 ms p95 ≤ 18.5 ms **AND** 4 ms 20–25 ms rate ≤ 40% of the 8.333 arm's rate.
   - 4 ms p95 = **18.74 ms** → fails the ≤ 18.5 ms condition.
   - 4 ms 20–25 rate = 10.6/1k vs 40% of 8.333 (6.26/1k) → 10.6 > 6.26 → fails the second condition.
   - **"4 ms sufficient" is NOT satisfied** under the stated criteria.
3. **"0 ms side effect":** 0 ms commit count (28.5) vs 8.333 (12.0) → change **+137.5%** (> 20%).
   - **0 ms side effect IS present** → note as a risk; the rule directs "prefer 4 ms".
4. **>25 ms differences:** must **NOT** be described as a tolerance effect — sample too sparse
   (pooled counts of 4–14 per arm across ~1000 intervals). No causal claim is made from >25 ms data.

**No production default is recommended or changed here.** These are measurement results and
interpretation-rule outcomes only; the production default decision is a separate, later user decision.

---

## 8. No code / default changed

- **No changes** to any file under `Sources/`, `Tests/`, or `Package.swift`.
- **No default value changed** (the `--frame-timer-tolerance-ms` flag only overrides the
  RunLoop Timer tolerance hint at runtime; the default 8.333 ms path is untouched).
- **No git operations performed.**
- **Privacy:** all content is neutral (`--neutral-content`); the JSONL contains no app names,
  bundle IDs, paths, URLs, or search terms. Only anonymous numeric/enum telemetry and
  monotonic-clock timestamps.
- **No root cause claimed; nothing "fixed".** This document reports measurements only.

## 9. Artifacts

- Results doc: `Docs/TIMER_TOLERANCE_GRADIENT_RESULTS.md` (this file).
- Stdout logs: `/tmp/t-a1-run-1.log` … `/tmp/t-a1-run-8.log`.
- Callback JSONL: `/tmp/launch-copy-paging-prototype-<runID>-callback.jsonl` (8 files, one per run;
  paths recorded in `/tmp/t-a1-manifest.tsv`).
- Analysis scripts: `/tmp/t-a1-analyze.py`, `/tmp/t-a1-pool.py`.
