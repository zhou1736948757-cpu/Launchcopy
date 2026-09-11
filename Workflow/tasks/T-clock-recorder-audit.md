# T-clock-recorder-audit

## Objective

Read-only audit of shared clock, closure-tail marker placement, disabled fast path, generation arm records, and reentrant `stop()+start()` safety for the frame-hitch correlation phase.

## Role

Read-only Explorer. Do not edit any file.

## Expected / Allowed Write Scope

None. Findings go only in the returned report. Main will persist `Workflow/results/T-clock-recorder-audit.md`.

## Frozen

- Do not access `/Users/mac/Projects/LaunchBetter/` or `/Users/mac/Projects/BuhoReverseNotes/`.
- Do not modify `Sources/PagingCore/`.
- No commit, push, tag, reset, clean.

## Must read

- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PROMPT.md`
- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md`
- `Sources/PagingUI/FrameCallbackProfileRecorder.swift`
- `Sources/PagingUI/PagingFrameDriver.swift`
- `Sources/PagingUI/RunLoopProfileRecorder.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Tests/PagingUITests/FrameCallbackProfileTests.swift`
- `Tests/PagingUITests/RunLoopFrameDriverTests.swift`

## Questions to answer

1. Confirm the current `exit_ns` sample site and everything that still runs after it inside the Timer closure.
2. Where exactly should `pre_return_ns` be sampled so it is adjacent to lexical return without being named a true return?
3. Is `defer` safe across owner teardown, weak-self, and reentrant `stop()+start()`?
4. How should arm records be emitted so first-tick delay is not inferred from `scheduled_ns - interval_ns`?
5. How to unify clocks without reading clocks when inactive, and without mixing `systemUptime` into join keys?
6. What existing tests already cover generation guard, first tick raw interval null, and inactive zero-I/O? What is missing?
7. Any plan error that would change production paging behavior or nominal schedule?

## Output

Structured findings: MEASURED vs INFERRED vs RISK. Cite file:line. Do not propose root cause. Current gate remains `CAUSALITY_UNRESOLVED`.
