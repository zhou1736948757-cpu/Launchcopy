# Physical correlation report phys-r1

Gate: `CAUSALITY_UNRESOLVED`
Context: `PHYSICAL` (not pooled with SELFDRIVE)
Refresh rate: 60
Human gestures: ~40 (user-reported, serious)
Content: real

Callback-only interval summary (raw n=1042): p50=16.623 p95=17.731 p99=19.284 max=25.102 ms; >20=9 >25=1 >33.3=0 >50=0.

## Long intervals

| generation | seq | interval ms | body wall/CPU ms | tail ms | remainder ms | join class | waiting/active/uncovered ms | mode |
|---:|---:|---:|---:|---:|---:|---|---:|---|
| 98 | 964 | 25.102 | 0.214 / 0.214 | 0.001 | 24.888 | MIXED_OBSERVED_BOUNDARIES | 14.468 / 10.397 / 0.022 | default |

Join is targeted same-clock window join for this sample (26 observer records from `beforeTimers` through `afterWaiting`). Observation, not root cause.
