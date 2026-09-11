# T-frame-hitch-root-cause-correlation

## Objective

Split the unresolved post-`exit_ns` remainder of >25ms Timer entry-to-entry intervals into:

1. Timer entry → post-advanceFrame (`exit_ns`, existing meaning)
2. post-advanceFrame → closure-return-adjacent (`pre_return_ns`)
3. pre-return → next Timer entry, classified by same-clock RunLoop observer bounds when possible
4. still-unclassified remainder

Also record true Timer generation arm markers and keep first-tick delays out of raw interval distributions.

This task does **not** authorize `ROOT_CAUSE_FOUND`, production Timer-tolerance default change, or physical PASS without a human trackpad capture.

## Frozen / forbidden

- Do not read or modify `/Users/mac/Projects/LaunchBetter/` or `/Users/mac/Projects/BuhoReverseNotes/`.
- Do not modify `Sources/PagingCore/`.
- No commit, push, tag, reset, clean, or release distribution.
- Privacy: no app names, bundle IDs, paths, URLs, search terms, icon data, raw RunLoop modes, window titles, or user input.
- Mode output only: `default|eventTracking|modalPanel|other|none`.

## Expected / Allowed Write Scope

See `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md` §6. Wave 0 audits write nothing. Implementation writes are split across later Workers; `AppDelegate.swift` / `AppArguments.swift` are Main-serial; `Package.swift` is Main-only.

## Acceptance

1. Shared monotonic clock domain for callback entry, post-advanceFrame, pre-return, RunLoop activity, and generation arm.
2. Additive schema; `exit_ns` meaning unchanged.
3. Deterministic tests listed in the prompt §5 Step 3.
4. A/A overhead gate before causal interpretation.
5. SELFDRIVE recapture with per-run and per->25ms decomposition.
6. Physical status honest: captured or `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.
7. Final report sections: MEASURED / SUPPORTED INFERENCE / UNRESOLVED / INTERVENTION RESULT / PHYSICAL STATUS.
8. Swift + Python + Release verification; trailing-whitespace/conflict-marker on this round’s files; `PagingCore` unmodified.

## Current gate

```text
CAUSALITY_UNRESOLVED
```
