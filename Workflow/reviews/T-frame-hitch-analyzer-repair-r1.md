# T-frame-hitch-analyzer-repair — Independent review

## Verdict

**PASS.** The ordinal defect hypothesis is correct and the repaired direction matches the actual frame-driver and profile call order.

## Findings

- `dt_i` is computed before entering profiled callback `i`.
- Telemetry frame ordinal `i` is emitted inside callback `i`, after `dt_i` already exists.
- Therefore telemetry interval `i` aligns to profile timestamps `i-1 → i`.
- The measured callback able to contribute at the interval start is profile ordinal `i-1`.
- Profile ordinal `i` occurs after the interval was already measured and cannot be labeled as the interval's callback cost.
- Ordinal 0 has no preceding profile interval and must remain unattributed.
- `parts_valid` must follow the same preceding ordinal.

## Boundary

The repaired callback measurement still covers only the instrumented callback body. It does not exclude deferred AppKit work, CA/WindowServer work, runloop waiting, scheduler delay, or unclassified mode-boundary work.
