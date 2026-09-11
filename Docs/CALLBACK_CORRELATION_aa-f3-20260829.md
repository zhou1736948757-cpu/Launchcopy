# Correlation report aa-f3

Gate: CAUSALITY_UNRESOLVED

# Callback ↔ RunLoop Correlation Report

Gate: `CAUSALITY_UNRESOLVED`

- input records: 78877
- accepted callback records: 502
- rejected callback records: 0
- ignored non-callback records: 0
- accepted arm records: 40
- rejected arm records: 0
- accepted runloop records: 78335
- rejected runloop records: 0
- raw intervals analyzed: 477
- first ticks analyzed separately: 25
- generations observed: 40
- invalid samples: 0
- schema-without-tail callbacks: 0
- interval p95/p99/max: 18.069 / 18.550 / 24.261 ms
- >20 / >25 / >33.3 / >50 ms: 2 / 0 / 0 / 0

## Join classes (observation, not root cause)

- NO_OBSERVER_BOUNDARY: 0
- WAITING_BOUNDED: 0
- RUNLOOP_ACTIVE_BOUNDED: 5
- MIXED_OBSERVED_BOUNDARIES: 472
- UNCLASSIFIED: 0
- SCHEMA_CALLBACK_WITHOUT_TAIL: 0

## First ticks

- count: 25 (with arm=25, without arm=0)

## Long intervals

| generation | seq | interval ms | body ms | tail ms | remainder ms | join class | waiting pair ms | active pair ms | uncovered ms | mode |
|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|

> Join classes are observations of recorder-derived same-clock bounds. They do not prove Timer closure return, and they do not identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component. Gate remains CAUSALITY_UNRESOLVED.
