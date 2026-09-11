# Physical correlation report phys-r2

Gate: `CAUSALITY_UNRESOLVED`
Context: `PHYSICAL` (not pooled with SELFDRIVE)
Refresh rate: 60
Human gestures: ~40 (same protocol as r1; wall ~49s; accepted on matching volume)
Content: real

Callback-only interval summary (raw n=1151): p50=16.636 p95=17.735 p99=19.131 max=25.296 ms; >20=10 >25=1 >33.3=0 >50=0.

## Long intervals

| generation | seq | interval ms | body wall/CPU ms | tail ms | remainder ms | join class | waiting/active/uncovered ms | mode |
|---:|---:|---:|---|---:|---:|---|---:|---|
| 16 | 157 | 25.296 | 0.265 / 0.265 | 0.001 | 25.030 | MIXED_OBSERVED_BOUNDARIES | 14.237 / 10.768 / 0.026 | default |

Join is targeted same-clock window join for this sample (28 observer records from `exit` through `afterWaiting`). Observation, not root cause.
