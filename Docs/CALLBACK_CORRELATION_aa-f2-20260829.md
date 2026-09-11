# Correlation report aa-f2

Gate: CAUSALITY_UNRESOLVED

# Callback ↔ RunLoop Correlation Report

Gate: `CAUSALITY_UNRESOLVED`

- input records: 115378
- accepted callback records: 473
- rejected callback records: 0
- ignored non-callback records: 0
- accepted arm records: 40
- rejected arm records: 0
- accepted runloop records: 114865
- rejected runloop records: 0
- raw intervals analyzed: 450
- first ticks analyzed separately: 23
- generations observed: 40
- invalid samples: 0
- schema-without-tail callbacks: 0
- interval p95/p99/max: 18.096 / 20.191 / 26.542 ms
- >20 / >25 / >33.3 / >50 ms: 5 / 1 / 0 / 0

## Join classes (observation, not root cause)

- NO_OBSERVER_BOUNDARY: 0
- WAITING_BOUNDED: 0
- RUNLOOP_ACTIVE_BOUNDED: 4
- MIXED_OBSERVED_BOUNDARIES: 446
- UNCLASSIFIED: 0
- SCHEMA_CALLBACK_WITHOUT_TAIL: 0

## First ticks

- count: 23 (with arm=23, without arm=0)

## Long intervals

| generation | seq | interval ms | body ms | tail ms | remainder ms | join class | waiting pair ms | active pair ms | uncovered ms | mode |
|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| 40 | 453 | 26.542 | 6.792 | 0.004 | 19.746 | MIXED_OBSERVED_BOUNDARIES | 6.608 | 13.014 | 0.123 | default |

> Join classes are observations of recorder-derived same-clock bounds. They do not prove Timer closure return, and they do not identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component. Gate remains CAUSALITY_UNRESOLVED.
