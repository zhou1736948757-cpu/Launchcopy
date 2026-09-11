# T-correlation-capture-protocol

## Objective

Write the A/A overhead and SELFDRIVE/physical capture protocol for the correlation phase. Commands only; do not run long GUI captures.

## Expected / Allowed Write Scope

Only:

```text
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CAPTURE_PROTOCOL.md
Workflow/results/T-correlation-capture-protocol.md
```

## Frozen

- No LaunchBetter / BuhoReverseNotes
- No Sources/ or Tools/ edits
- No commit / push / tag / reset / clean
- Do not claim root cause

## Must read

- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CHECKPOINT.md`
- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md` §D6–D7
- `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md` (command style)
- `Sources/PagingPrototypeApp/AppDelegate.swift` SELFDRIVE env `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`

## Required content

1. Binary: Release, `--neutral-content`, `--disable-telemetry-bridge`
2. A/A arms Control / Legacy / Full, ≥3 interleaved runs, what to record (p50/p95/p99/max, >20/25/33.3/50 rates, writeFailureCount, runloop records/s)
3. Formal SELFDRIVE at tolerance=0, per-run reporting, every `>25ms` sample table
4. Physical protocol or exact status `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`
5. Privacy-safe run-id naming (no user paths in reports)
6. Analyzer invocation once Worker B’s CLI exists; if the analyzer file is not present yet, write the intended command using `Tools/analyze_callback_runloop_correlation.py`

Gate remains `CAUSALITY_UNRESOLVED`.
