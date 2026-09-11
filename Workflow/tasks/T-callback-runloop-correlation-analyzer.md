# T-callback-runloop-correlation-analyzer

## Objective

Implement the same-clock callback ↔ RunLoop correlation analyzer and deterministic Python tests.

## Expected / Allowed Write Scope

Only:

```text
Tools/analyze_callback_runloop_correlation.py
Tools/tests/test_analyze_callback_runloop_correlation.py
Workflow/results/T-callback-runloop-correlation-analyzer.md
```

Do not modify `Tools/analyze_callback_cadence.py`, `Tools/analyze_frame_hitches.py`, any Swift file, `Package.swift`, or `Sources/PagingCore/`.

## Frozen

- No LaunchBetter / BuhoReverseNotes
- No commit / push / tag / reset / clean
- Privacy: no unknown JSON field echo, no paths, run IDs, raw modes, app names

## Must read

- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CHECKPOINT.md` §3–4
- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md` §D5
- `Tools/analyze_callback_cadence.py` (style + privacy only)
- `Tools/tests/test_analyze_callback_cadence.py`

## Acceptance

See CHECKPOINT §4. Implement `analyze()`, `render_markdown()`, CLI `--callback` `--runloop` `--format json|markdown`. Tests must cover old schema, missing markers, equal bounds, no/multiple observers, cross-generation, first tick with/without arm, privacy. Run:

```bash
PYTHONPATH=. python3 -m unittest Tools.tests.test_analyze_callback_runloop_correlation
```

Gate remains `CAUSALITY_UNRESOLVED`.
