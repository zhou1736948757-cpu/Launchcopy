# T-analyzer-experiment-audit — Result

## Status

`PASSED` as a read-only audit. No files modified. Gate remains `CAUSALITY_UNRESOLVED`.

## MEASURED

- `analyze_callback_cadence.py` is callback-only and treats `exit_ns` as the recorded-exit marker. It has no RunLoop join and no `pre_return_ns`.
- `analyze_frame_hitches.py` joins telemetry ordinals to frame-profile uptime and must not subtract Unix wall clock from monotonic timestamps.
- Old callback JSONL cannot invent tail or same-clock RunLoop bounds.

## JOIN RULES (for the new analyzer)

- New tool: `Tools/analyze_callback_runloop_correlation.py`. Do not silently change cadence-analyzer semantics.
- Callback without `pre_return_ns`: accept, do not split tail; label `SCHEMA_CALLBACK_WITHOUT_TAIL`.
- RunLoop without `timestamp_ns`: accept, not joinable. Never join `timestamp` (uptime) to `entry_ns`.
- Formulas use raw timestamps. Negative / overflow / missing / sequence break / cross-generation → invalid, never clamp to 0.
- Equal timestamps are zero-length bounds, not automatically `WAITING_BOUNDED`.
- Classes: `WAITING_BOUNDED`, `RUNLOOP_ACTIVE_BOUNDED`, `MIXED_OBSERVED_BOUNDARIES`, `NO_OBSERVER_BOUNDARY`, `UNCLASSIFIED`.

## PROTOCOL

- A/A Control / Legacy / Full on one Release binary is required. Legacy including new tail fields is an acceptable documented deviation.
- SELFDRIVE: per-run plus every `>25ms` sample. First ticks separate.
- Physical: capture or `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.

## Recommendation

Implement the new analyzer with explicit schema counters and synthetic tests covering old schema, missing markers, equal bounds, no/multiple observers, and cross-generation rejection.
