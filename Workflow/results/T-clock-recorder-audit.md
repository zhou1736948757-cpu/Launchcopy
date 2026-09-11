# T-clock-recorder-audit — Result

## Status

`PASSED` as a read-only audit. No files modified. Gate remains `CAUSALITY_UNRESOLVED`.

## MEASURED

- `exit_ns` is sampled at the start of `FrameCallbackProfileRecorder.endCallback` (`FrameCallbackProfileRecorder.swift:175-178`), after `PagingSurface.advanceFrame` returns from `handleFrame` (`PagingFrameDriver.swift:118-127, 84-90`).
- After that sample, the same Timer closure still does JSON construction, buffer append / async enqueue, then generation-guarded `nextNominalDeadlineNS` writeback (`PagingFrameDriver.swift:87-97`).
- Early `guard let self, let owner, !owner.isTearingDown` returns before `beginCallback` (`PagingFrameDriver.swift:75`).
- `start()` seeds `nextNominalDeadlineNS = now + interval` via `initialNominalDeadlineNS` when the profiler is active (`PagingFrameDriver.swift:69-70`; `FrameCallbackProfileRecorder.swift:121-126`). No arm JSONL is written.
- Callback wall clock is `CLOCK_MONOTONIC_RAW`; thread CPU is `CLOCK_THREAD_CPUTIME_ID`; `handleFrame` uses `ProcessInfo.systemUptime`; RunLoop uses `ContinuousClock` + `systemUptime`.
- Inactive `beginCallback` returns nil before any clock or mode read (`FrameCallbackProfileRecorder.swift:146`).

## INFERRED

- Place `pre_return_ns` in a `defer` after deadline writeback. Do not name it `closure_return` / `callback_return` / `true_exit`.
- `defer` is compatible with the existing generation guard. Arm records should be a distinct `kind=timer_generation_arm`.
- `handleFrame`’s `systemUptime` must stay out of join keys.

## TEST GAPS

Prompt §5 Step 3 items 2–8 and the tail/arm/order cases are missing. Inactive zero-clock is already tested for the callback recorder, not jointly with RunLoop. Driver tests assume every JSONL line is `frame_callback`.

## Recommendation

Proceed with the plan. No production-schedule change. Main should update driver tests to allow arm records.
