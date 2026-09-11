# Correlation report aa-f1

Gate: CAUSALITY_UNRESOLVED

# Callback ↔ RunLoop Correlation Report

Gate: `CAUSALITY_UNRESOLVED`

- input records: 115377
- accepted callback records: 474
- rejected callback records: 0
- ignored non-callback records: 0
- accepted arm records: 40
- rejected arm records: 0
- accepted runloop records: 114863
- rejected runloop records: 0
- raw intervals analyzed: 451
- first ticks analyzed separately: 23
- generations observed: 40
- invalid samples: 0
- schema-without-tail callbacks: 0
- interval p95/p99/max: 17.914 / 18.331 / 22.079 ms
- >20 / >25 / >33.3 / >50 ms: 2 / 0 / 0 / 0

## Join classes (observation, not root cause)

- NO_OBSERVER_BOUNDARY: 0
- WAITING_BOUNDED: 0
- RUNLOOP_ACTIVE_BOUNDED: 3
- MIXED_OBSERVED_BOUNDARIES: 448
- UNCLASSIFIED: 0
- SCHEMA_CALLBACK_WITHOUT_TAIL: 0

## First ticks

- count: 23 (with arm=23, without arm=0)

## Long intervals

| generation | seq | interval ms | body ms | tail ms | remainder ms | join class | waiting pair ms | active pair ms | uncovered ms | mode |
|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|

> Join classes are observations of recorder-derived same-clock bounds. They do not prove Timer closure return, and they do not identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component. Gate remains CAUSALITY_UNRESOLVED.
