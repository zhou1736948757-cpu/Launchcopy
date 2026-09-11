# T-analyzer-experiment-audit

## Objective

Read-only audit of correlation join algorithm, statistical denominators, A/A overhead protocol, SELFDRIVE capture protocol, and physical/trace gates.

## Role

Read-only Explorer. Do not edit any file.

## Expected / Allowed Write Scope

None. Findings go only in the returned report. Main will persist `Workflow/results/T-analyzer-experiment-audit.md`.

## Frozen

- Do not access `/Users/mac/Projects/LaunchBetter/` or `/Users/mac/Projects/BuhoReverseNotes/`.
- Do not modify `Sources/PagingCore/`.
- No commit, push, tag, reset, clean.

## Must read

- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PROMPT.md`
- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md`
- `Tools/analyze_callback_cadence.py`
- `Tools/analyze_frame_hitches.py`
- `Tools/tests/test_analyze_callback_cadence.py`
- `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`
- `Docs/TIMER_TOLERANCE_AB_RESULTS.md`

## Questions to answer

1. Keep a new correlation analyzer vs extending `analyze_callback_cadence.py`? Compatibility with old schema?
2. Exact join rules for equal timestamps, missing observers, multiple observers, and cross-generation intervals.
3. Required denominators and invalid-sample handling (negative/overflow/missing markers: reject, never clamp).
4. A/A arm definitions: Control / Legacy / Full. Is “Legacy includes new tail fields” an acceptable documented deviation?
5. SELFDRIVE per-run reporting vs pooled; first tick vs raw interval split.
6. Physical gate wording if no human operator is available.
7. Privacy: no unknown JSON field echo, no paths/run IDs/raw modes.

## Output

Structured findings: MEASURED vs INFERRED vs RISK. Cite file:line. Propose analyzer test cases, not a root cause. Current gate remains `CAUSALITY_UNRESOLVED`.
