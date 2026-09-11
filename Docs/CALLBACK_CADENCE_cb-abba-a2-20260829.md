# Frame Callback Cadence Report

- input records: 497
- accepted callbacks: 497
- rejected callback records: 0
- ignored non-callback records: 0
- raw intervals analyzed: 468 (first ticks have null raw interval)
- generations with at least one recorded callback: 29
- interval p95/p99/max: 18.263 / 21.122 / 25.100 ms
- >20 / >25 / >33.3 / >50 ms: 8 / 1 / 0 / 0
- callbacks with missed periods: 1 (total missed=1)

## Long intervals

| generation | seq | interval ms | lateness ms | missed | preceding recorded-segment wall ms | preceding recorded-segment current-thread CPU ms | recorded-exit→next-entry remainder ms | mode |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 2 | 30 | 23.653 | 8.094 | 0 | 0.328 | 0.328 | 23.325 | default |
| 2 | 38 | 25.100 | 16.778 | 1 | 0.416 | 0.416 | 24.684 | default |
| 2 | 39 | 23.880 | 7.325 | 0 | 0.370 | 0.369 | 23.510 | default |
| 6 | 112 | 22.462 | 8.303 | 0 | 0.334 | 0.334 | 22.128 | default |
| 11 | 212 | 22.483 | 7.959 | 0 | 0.245 | 0.245 | 22.238 | default |
| 28 | 381 | 20.225 | 6.596 | 0 | 0.383 | 0.382 | 19.842 | default |
| 28 | 390 | 20.462 | 7.739 | 0 | 0.278 | 0.278 | 20.185 | default |
| 32 | 434 | 20.233 | 7.247 | 0 | 0.563 | 0.562 | 19.670 | default |

> Lateness and the recorded-exit-to-next-entry remainder are recorder-derived measurements. They do not prove that the Timer closure returned at the recorded exit, nor do they identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component.
