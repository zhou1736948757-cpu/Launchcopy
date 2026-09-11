# Frame Callback Cadence Report

- input records: 533
- accepted callbacks: 533
- rejected callback records: 0
- ignored non-callback records: 0
- raw intervals analyzed: 502 (first ticks have null raw interval)
- generations with at least one recorded callback: 31
- interval p95/p99/max: 18.578 / 23.381 / 24.942 ms
- >20 / >25 / >33.3 / >50 ms: 12 / 0 / 0 / 0
- callbacks with missed periods: 1 (total missed=1)

## Long intervals

| generation | seq | interval ms | lateness ms | missed | preceding recorded-segment wall ms | preceding recorded-segment current-thread CPU ms | recorded-exit→next-entry remainder ms | mode |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 2 | 31 | 24.387 | 8.029 | 0 | 0.313 | 0.312 | 24.074 | default |
| 3 | 47 | 22.698 | 14.383 | 0 | 4.307 | 1.013 | 18.391 | default |
| 3 | 52 | 24.802 | 24.788 | 1 | 1.463 | 0.640 | 23.340 | default |
| 3 | 60 | 24.484 | 7.936 | 0 | 0.433 | 0.433 | 24.051 | default |
| 4 | 84 | 23.381 | 7.543 | 0 | 0.348 | 0.348 | 23.033 | default |
| 7 | 143 | 22.936 | 8.091 | 0 | 0.368 | 0.368 | 22.568 | default |
| 8 | 163 | 20.923 | 7.186 | 0 | 0.524 | 0.523 | 20.399 | default |
| 12 | 236 | 24.202 | 7.910 | 0 | 0.255 | 0.256 | 23.947 | default |
| 14 | 263 | 23.372 | 7.929 | 0 | 0.337 | 0.336 | 23.035 | default |
| 14 | 265 | 21.928 | 6.713 | 0 | 0.208 | 0.208 | 21.720 | default |
| 28 | 381 | 21.212 | 8.068 | 0 | 0.358 | 0.357 | 20.854 | default |
| 29 | 411 | 24.942 | 8.503 | 0 | 0.291 | 0.290 | 24.652 | default |

> Lateness and the recorded-exit-to-next-entry remainder are recorder-derived measurements. They do not prove that the Timer closure returned at the recorded exit, nor do they identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component.
