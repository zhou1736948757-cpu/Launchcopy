# T-correlation-capture-protocol — Result

## Status

`COMPLETED` as protocol-only. No GUI SELFDRIVE captures were executed. Gate remains `CAUSALITY_UNRESOLVED`. Physical status recorded as `PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`.

## Changed files

```text
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CAPTURE_PROTOCOL.md
Workflow/results/T-correlation-capture-protocol.md
```

No other files written.

## Protocol contents (pointer)

The capture protocol includes: Release `swift build -c release` and `.build/release/PagingPrototypeApp`; interleaved A/A Control/Legacy/Full (≥3 each) with exact argv, `corr-aa-{arm}{n}-YYYYMMDD`, `--neutral-content --disable-telemetry-bridge --frame-timer-tolerance-ms 0`; metrics; probe-overhead pass/fail (do not interpret Full tails as app root cause if Full creates a new `>25ms` population); formal SELFDRIVE recapture with `--frame-callback-profile --runloop-profile`; per-run + `>25ms` sample table; physical commands plus the blocked token; privacy rules; analyzer invocation `PYTHONPATH=. python3 Tools/analyze_callback_runloop_correlation.py --callback … --runloop … --format markdown`.
