# T-runloop-trace-audit

## Objective

Read-only audit of CFRunLoopObserver proof limits, same-clock RunLoop schema, independent `--runloop-profile` wiring, and local `xctrace`/signpost feasibility.

## Role

Read-only Explorer. Do not edit any file.

## Expected / Allowed Write Scope

None. Findings go only in the returned report. Main will persist `Workflow/results/T-runloop-trace-audit.md`.

## Frozen

- Do not access `/Users/mac/Projects/LaunchBetter/` or `/Users/mac/Projects/BuhoReverseNotes/`.
- Do not modify `Sources/PagingCore/`.
- No commit, push, tag, reset, clean.

## Must read

- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PROMPT.md`
- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md`
- `Sources/PagingUI/RunLoopProfileRecorder.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Sources/PagingPrototypeApp/AppArguments.swift`
- `Tests/PagingUITests/RunLoopProfileTests.swift`
- `Docs/FRAME_HITCH_DEEP_DIVE_REPORT.md` §5

## Also inspect locally (read-only commands allowed)

- Whether this SDK exposes `afterTimers` / `afterSources`.
- Available `xctrace` templates/commands (`xctrace list templates` or equivalent). Do not start a long trace.
- Whether `os_signpost` is already used in this project.

## Questions to answer

1. What can the current observer activities actually bound inside `pre_return → next entry`?
2. Which join classes are conservative enough (`WAITING_BOUNDED`, `RUNLOOP_ACTIVE_BOUNDED`, `MIXED_OBSERVED_BOUNDARIES`, `NO_OBSERVER_BOUNDARY`, `UNCLASSIFIED`)?
3. Should `--runloop-profile` be independent of `--frame-profile`? How to avoid double observers if both flags are set?
4. Is `thread_cpu_ns` in the observer justified, or is it extra hitch risk?
5. What local trace path exists, and what evidence would be required before saying runnable-but-unscheduled?
6. Privacy: mode vocabulary and no raw mode leakage.

## Output

Structured findings: MEASURED vs INFERRED vs RISK. Cite file:line and command output. Do not name scheduler/WindowServer as cause. Current gate remains `CAUSALITY_UNRESOLVED`.
