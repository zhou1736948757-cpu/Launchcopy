# T-callback-runloop-correlation-analyzer — Worker B result

## Status

Implemented. Gate remains **`CAUSALITY_UNRESOLVED`**. This tool does not claim `ROOT_CAUSE_FOUND`.

## Changed files (assigned write scope only)

1. `Tools/analyze_callback_runloop_correlation.py` (new)
2. `Tools/tests/test_analyze_callback_runloop_correlation.py` (new)
3. `Workflow/results/T-callback-runloop-correlation-analyzer.md` (this result)

No Swift, cadence analyzer, hitch analyzer, AppDelegate, docs, `Sources/PagingCore/`, commit, push, tag, reset, or clean.

## Analyzer contract

- `analyze(callback_records, runloop_records=None, hitch_ms=25.0) -> dict`
- `render_markdown(report) -> str`
- CLI: `--callback PATH [--runloop PATH] [--format json|markdown] [--hitch-ms 25]`

Join formulas (never clamped to 0):

```text
recorded_body_ns       = exit_ns - entry_ns
closure_tail_ns        = pre_return_ns - exit_ns
post_tail_remainder_ns = next_entry_ns - pre_return_ns
first_tick_delay_ns    = first_entry_ns - arm_ns
```

Negative / missing / overflow / sequence discontinuity / cross-generation → invalid sample.

Observation classes for remainder window `[pre_return_ns, next_entry_ns]`:

- `NO_OBSERVER_BOUNDARY`
- `WAITING_BOUNDED`
- `RUNLOOP_ACTIVE_BOUNDED`
- `MIXED_OBSERVED_BOUNDARIES`
- `UNCLASSIFIED`
- `SCHEMA_CALLBACK_WITHOUT_TAIL` (old callback schema; tail is not invented)

Also reports `waiting_pair_ns`, `active_pair_ns`, `uncovered_ns`.
First ticks join `timer_generation_arm` of the same `driver_generation` only; missing arm is `FIRST_TICK_WITHOUT_ARM` (no `scheduled_ns - interval_ns` inference).
RunLoop without `timestamp_ns` is accepted and not joinable; `timestamp` (uptime) is never subtracted from `entry_ns`.
Mode vocabulary is `default|eventTracking|modalPanel|other|none` only.

## Verification commands

```bash
PYTHONPATH=. python3 -m unittest Tools.tests.test_analyze_callback_runloop_correlation
python3 -m py_compile Tools/analyze_callback_runloop_correlation.py
```

## Tests (synthetic JSONL, no sleep)

Designed coverage (20 tests):

1. old schema without `pre_return_ns` → `SCHEMA_CALLBACK_WITHOUT_TAIL`
2. missing/`null` `pre_return_ns` does not treat `exit_ns` as pre-return
3. missing `timestamp_ns` accepted, not joinable; uptime `timestamp` unused
4. equal remainder bounds are zero-length, not `WAITING_BOUNDED`
5. no observer in window → `NO_OBSERVER_BOUNDARY`, `uncovered_ns = remainder`
6. `WAITING_BOUNDED`
7. `RUNLOOP_ACTIVE_BOUNDED`
8. multiple observers mixed → `MIXED_OBSERVED_BOUNDARIES`
9. single observer / unknown activity → `UNCLASSIFIED` (raw activity not echoed)
10. cross-generation remainder rejected
11. first tick with arm uses `arm_ns`
12. first tick without arm does not infer from `scheduled_ns - interval_ns`
13. negative remainder invalid, not clamped to 0
14. negative body/tail invalid, not clamped to 0
15. privacy: secret fields / raw mode / paths / URLs do not leak
16. required denominator counts in JSON + Markdown
17. malformed JSONL line → `InputDataError`
18. non-object JSONL line → `InputDataError`
19. CLI `--callback` / `--runloop` / `--format json` / `--hitch-ms 25`
20. CLI malformed file exit code 2

## Test execution

Commands required by the task packet (run from repo root):

```bash
PYTHONPATH=. python3 -m unittest Tools.tests.test_analyze_callback_runloop_correlation
python3 -m py_compile Tools/analyze_callback_runloop_correlation.py
```

| Field | Value |
|---|---|
| designed tests | 20 |
| executed | pending Main/Reviewer run of the commands above |
| passed | pending |
| failed | pending |
| unittest exit code | pending |
| py_compile exit code | pending |

This Worker session had no shell/exec tool, so those commands could not be launched here. `exit_code == 0` with `executed_tests == 0` is `INVALID_TEST_EXECUTION`; do not close the task as test `PASS` until the commands are actually run.

## Memory candidates

- Correlation analyzer is `Tools/analyze_callback_runloop_correlation.py`; old cadence analyzer is unchanged.
- Remainder join key is callback `pre_return_ns` / `entry_ns` and RunLoop `timestamp_ns` on `CLOCK_MONOTONIC_RAW`. Never join RunLoop `timestamp` (uptime).
- First-tick delay is `first_entry_ns - arm_ns`. Missing arm is `FIRST_TICK_WITHOUT_ARM`; do not infer `scheduled_ns - interval_ns`.
- Join classes are observations, not causes. Gate stays `CAUSALITY_UNRESOLVED`.

## Gate

```text
CAUSALITY_UNRESOLVED
```

Join classes are observations, not root causes. No `ROOT_CAUSE_FOUND`, `SCHEDULER_CONFIRMED`, `RUNLOOP_CONFIRMED`, `WINDOWSERVER_CONFIRMED`, `GPU_CONFIRMED`, `ALL_HITCHES_FIXED`, or `FIX_VALIDATED`.
