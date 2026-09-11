# Physical correlation report phys-n1

Gate: `CAUSALITY_UNRESOLVED`
Context: `PHYSICAL` (not pooled with SELFDRIVE)
Refresh rate: 60
Human gestures: ~40 (user-reported)
Content: neutral

# Callback ↔ RunLoop Correlation Report

Gate: `CAUSALITY_UNRESOLVED`

- input records: 343685
- accepted callback records: 1440
- rejected callback records: 0
- ignored non-callback records: 0
- accepted arm records: 142
- rejected arm records: 0
- accepted runloop records: 342103
- rejected runloop records: 0
- raw intervals analyzed: 1369
- first ticks analyzed separately: 71
- generations observed: 142
- invalid samples: 0
- schema-without-tail callbacks: 0
- interval p95/p99/max: 18.817 / 20.944 / 24.289 ms
- >20 / >25 / >33.3 / >50 ms: 28 / 0 / 0 / 0

## Join classes (observation, not root cause)

- NO_OBSERVER_BOUNDARY: 0
- WAITING_BOUNDED: 0
- RUNLOOP_ACTIVE_BOUNDED: 0
- MIXED_OBSERVED_BOUNDARIES: 1369
- UNCLASSIFIED: 0
- SCHEMA_CALLBACK_WITHOUT_TAIL: 0

## First ticks

- count: 71 (with arm=71, without arm=0)

## Long intervals

| generation | seq | interval ms | body ms | tail ms | remainder ms | join class | waiting pair ms | active pair ms | uncovered ms | mode |
|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|

> Join classes are observations of recorder-derived same-clock bounds. They do not prove Timer closure return, and they do not identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component. Gate remains CAUSALITY_UNRESOLVED.
