# Frame Callback Cadence Report

- input records: 489
- accepted callbacks: 489
- rejected callback records: 0
- ignored non-callback records: 0
- raw intervals analyzed: 464 (first ticks have null raw interval)
- generations with at least one recorded callback: 25
- interval p95/p99/max: 17.560 / 22.157 / 72.458 ms
- >20 / >25 / >33.3 / >50 ms: 6 / 4 / 2 / 1
- callbacks with missed periods: 4 (total missed=6)

## Long intervals

| generation | seq | interval ms | lateness ms | missed | preceding recorded-segment wall ms | preceding recorded-segment current-thread CPU ms | recorded-exit→next-entry remainder ms | mode |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 2 | 27.372 | 13.213 | 0 | 6.830 | 1.928 | 20.543 | default |
| 1 | 4 | 72.458 | 64.010 | 3 | 0.677 | 0.643 | 71.781 | default |
| 15 | 293 | 37.325 | 21.606 | 1 | 1.030 | 0.978 | 36.295 | default |
| 16 | 313 | 21.862 | 6.778 | 0 | 0.886 | 0.723 | 20.976 | default |
| 17 | 319 | 22.661 | 7.953 | 0 | 1.762 | 0.656 | 20.898 | default |
| 17 | 320 | 27.055 | 18.341 | 1 | 11.835 | 0.921 | 15.220 | default |

> Lateness and the recorded-exit-to-next-entry remainder are recorder-derived measurements. They do not prove that the Timer closure returned at the recorded exit, nor do they identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component.
