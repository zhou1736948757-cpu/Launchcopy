# Frame Callback Cadence Report

- input records: 498
- accepted callbacks: 498
- rejected callback records: 0
- ignored non-callback records: 0
- raw intervals analyzed: 473 (first ticks have null raw interval)
- generations with at least one recorded callback: 25
- interval p95/p99/max: 17.438 / 18.884 / 21.055 ms
- >20 / >25 / >33.3 / >50 ms: 3 / 0 / 0 / 0
- callbacks with missed periods: 0 (total missed=0)

## Long intervals

| generation | seq | interval ms | lateness ms | missed | preceding recorded-segment wall ms | preceding recorded-segment current-thread CPU ms | recorded-exit→next-entry remainder ms | mode |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 10 | 20.598 | 8.441 | 0 | 0.550 | 0.523 | 20.048 | default |
| 3 | 61 | 20.549 | 4.691 | 0 | 0.836 | 0.825 | 19.712 | default |
| 3 | 67 | 21.055 | 9.177 | 0 | 0.718 | 0.717 | 20.337 | default |

> Lateness and the recorded-exit-to-next-entry remainder are recorder-derived measurements. They do not prove that the Timer closure returned at the recorded exit, nor do they identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component.
