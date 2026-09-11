# T-runloop-trace-audit — Result

## Status

`PASSED` as a read-only audit. No files modified. Gate remains `CAUSALITY_UNRESOLVED`.

## MEASURED

- Observer mask is `.entry, .beforeTimers, .beforeSources, .beforeWaiting, .afterWaiting, .exit` (`RunLoopProfileRecorder.swift:60-62`). Comments already record that this SDK’s `CFRunLoop.h` lacks `afterTimers` / `afterSources`.
- Gaps use `ContinuousClock`; emitted `timestamp` is `ProcessInfo.systemUptime` (`RunLoopProfileRecorder.swift:126-134`).
- Recorder starts only under `--frame-profile` (`AppDelegate.swift:132-140`). `--frame-callback-profile` does not start it.
- `os_signpost` is not used in this project.
- `xcrun xctrace list templates` is the local discovery path; this audit did not start a capture.

## INFERRED

- `beforeWaiting → afterWaiting` inside `pre_return → next entry` is `WAITING_BOUNDED`, not scheduler.
- `RUNLOOP_ACTIVE_BOUNDED` remains usable when non-waiting observer pairs fully cover the remainder. It is coarse, not a source attribution.
- AppDelegate must own at most one RunLoop observer if `--frame-profile` and `--runloop-profile` are both set.
- Do not add observer `thread_cpu_ns` unless A/A proves it is necessary.

## TRACE FEASIBILITY

System Trace / Time Profiler only after same-clock join still leaves large `UNCLASSIFIED` remainders. Runnable-but-unscheduled requires System Trace evidence tied to signposts. Not authorized yet.

## Recommendation

Add independent `--runloop-profile`, keep a single observer instance, emit `timestamp_ns` on the shared monotonic clock, and retain legacy `timestamp` only as a non-join field for old hitch-analyzer compatibility.
