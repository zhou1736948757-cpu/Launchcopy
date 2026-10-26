# Warm idle resource observations — 2026-10-22

Status: BOUNDED_OBSERVATIONS_ONLY. One unchanged d7302a18 candidate, PID96873, Main-only sampling; no concurrent agents/builds/tests. Same warm session, 82 owned fixtures, 2000×1400 screenshot pixels, wallpaper ready, Library enabled in all phases, recording disabled. Each phase excluded 5 seconds settling then measured about20 seconds.

| Phase | CPU seconds | CPU % of one core | RSS KiB range |
|---|---:|---:|---:|
| Main A1 | 0.08 | 0.393 | 39840–67792 |
| Library B | 0.01 | 0.049 | 42480–50736 |
| Main A2 | 0.00 at 0.01s resolution | 0.000 at that resolution | 43232–43264 |

External ps samples verify exact PID/executable each time. CPU% is interval cumulative CPU divided by monotonic wall time;100%=one core. RSS is not footprint, peak, energy or leak proof. Uncontrolled system/user workload and warm caches prevent attributing differences or deriving physical scrolling acceptance. A/B/A denotes view states within one binary, not old/new ABBA. No causal fix, regression threshold or production parameter change follows.

Native Settings restored Library OFF/recording OFF; query empty, folder/Settings closed, wallpaper ready. All574 source inputs and249 owned file hashes/modes preserved. Raw bounded receipts/helper: `.build/verification/20261022/idle-resource-baseline/`. No screenshot files, private app usage or raw input stored. Existing3550/0 is historical source evidence, not a new suite run.

## Next approved work
User explicitly authorized the separate real-four-finger validation environment. Existing isolated UI entry remains fake-only. A distinct fail-closed entry requires an implementation spec, tests and separate candidate before device activation. Physical gesture acceptance remains pending.
