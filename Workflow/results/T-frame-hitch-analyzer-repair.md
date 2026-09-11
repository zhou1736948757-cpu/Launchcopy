# T-frame-hitch-analyzer-repair — Result

## Status

**Completed.** A one-frame callback attribution defect was found after the original analyzer review and repaired.

## Defect

Telemetry hitch ordinal `i` reports the elapsed interval ending at frame callback entry `i`. The corresponding profile interval is:

```text
profile[i-1].timestamp → profile[i].timestamp
```

The callback body at the start of, and able to contribute to, that interval is `profile[i-1]`. The original analyzer incorrectly reported `profile[i].total_ns` and checked `profile[i].parts_valid`.

## Repair

- `callback_total_ms` now comes from `profile[i-1]`.
- Output includes `callback_frame_ordinal`.
- `parts_valid` is checked on the preceding callback.
- Ordinal 0 remains callback-unattributed and `UNRESOLVED`.
- Tests prevent current/future callback leakage and validate parts direction in both directions.

## Verification

```text
python3 -m unittest -v Tools/tests/test_analyze_frame_hitches.py
15 tests, 0 failures
```

Historical anonymous runs were recomputed:

| Run | Frames | >20ms | Max interval | Repaired preceding callback max |
|---|---:|---:|---:|---:|
| Human-B | 596 | 16 | 23.702ms | 0.936ms |
| SELFDRIVE-neutral | 638 | 12 | 53.510ms | 9.386ms |
| phys1b-06 | 591 | 17 | 27.986ms | 0.937ms |

The SELFDRIVE-neutral result is important: the corrected association does not support a universal “all hitch callbacks are tiny” claim. SELFDRIVE remains synthetic performance comparison only.
