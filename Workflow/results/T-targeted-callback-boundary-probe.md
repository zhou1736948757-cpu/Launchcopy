# T-targeted-callback-boundary-probe — Result

## Status

`PASSED` for recorder implementation, internal capture integrity, automated verification, and GUI SELFDRIVE diagnostic execution.

This task does **not** pass a physical feel gate, does **not** change the production Timer tolerance default, and does **not** identify a causal system component.

## Result codes

```text
TIMER_ENTRY_TO_POST_ADVANCEFRAME_PROBE_IMPLEMENTED_AND_DIAGNOSTICALLY_VALIDATED
PRECEDING_RECORDED_SEGMENT_THREAD_CPU_INSUFFICIENT_FOR_5_OBSERVED_GT25MS_ENTRY_INTERVALS
POST_RECORDED_EXIT_REMAINDER_MEASURED_FOR_ALL_5_OBSERVED_GT25MS_ENTRY_INTERVALS
ONE_OBSERVED_GT25MS_ENTRY_INTERVAL_REMAINS_A_SUBSTANTIAL_MIXED_RECORDED_SEGMENT_CASE
FIRST_TICK_GT25MS_DELAYS_EXIST_SEPARATELY_AND_ARE_EXCLUDED_FROM_RAW_INTERVAL_DISTRIBUTIONS
POST_RECORDED_EXIT_AND_FIRST_TICK_DELAY_CAUSALITY_UNRESOLVED
FULL_TIMER_CLOSURE_EXIT_UNOBSERVED
CAUSAL_SYSTEM_COMPONENT_NOT_IDENTIFIED
SELFDRIVE_ONLY_FOR_CALLBACK_ABBA
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
REQUIRE_FULL_TIMER_CLOSURE_EXIT_AND_SAME_CLOCK_RUNLOOP_CORRELATION_FOR_DEEPER_CAUSAL_CLAIMS
```

## Evidence

- Swift 454 tests, 0 failures;
- Python 20 tests, 0 failures;
- Release build exit 0;
- callback-only GUI ABBA A1/B1/B2/A2 completed with normal SELFDRIVE teardown;
- 2,017 input/accepted callback records, 0 rejected, 0 ignored non-callback; 1,907 raw intervals;
- 5 raw intervals >25ms;
- preceding recorded-segment current-thread CPU max among those five: 1.928ms;
- all five have a majority recorded-exit-to-next-entry remainder; three are 97.2%–99.1%; one 27.055ms sample remains a substantial mixed case;
- first-tick >25ms delays exist separately and are excluded from raw interval distributions;
- detailed report: `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`;
- hash manifest: `Docs/CALLBACK_BOUNDARY_ABBA_ARTIFACTS.sha256`.

## Measurement boundary

`exit_ns` is sampled at the beginning of recorder `endCallback` after `advanceFrame` returns. It does not prove that the Timer closure returned there. The remainder may include remaining work in the same closure plus all unobserved time before the next recorder entry.

## Next route

- keep default tolerance unchanged pending physical ABBA and energy evidence;
- add same-clock RunLoop/callback correlation or a closure-return-adjacent boundary before naming a root cause;
- do not write `ROOT_CAUSE_FOUND`, `SCHEDULER_CONFIRMED`, or `ALL_HITCHES_FIXED`.
