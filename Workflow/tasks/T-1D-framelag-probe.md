# T-1D-framelag-probe

- **Type**: investigation-only probe (no code change; no implementation — evidence for user-feel question)
- **Background**: User reported swipe/scroll feeling slightly laggy ("卡顿") during real-GUI paging; Main dispatched an independent measurement subagent to determine objective frame-delivery regularity under PRODUCTION defaults vs a `--frame-timer-tolerance-ms 0` control. Must NOT change any code/parameter; must NOT claim fixes; diagnostics stay CAUSALITY_UNRESOLVED / PRODUCT_DEFAULT_UNCHANGED.
- **Method**: headless PerfBenchmark probe (explicit advanceFrame, 1/2/5/10/20 pages) + performance-focused test suites + real-GUI SELFDRIVE collection on Release binary (SHA 29ea6928…) with `--neutral-content --disable-telemetry-bridge --frame-profile --frame-callback-profile --runloop-profile`, production-default and tolerance-0 tracks, auto-terminate.
- **Key results** (frame-interval rhythm, 60Hz target 16.67ms):
  - Production default (8.333ms tolerance): p95 22.2ms, p99 32.9ms, max 37.6ms; intervals >20ms ×47, >25ms ×12, >33ms ×3, >50ms ×0.
  - Tolerance-0 control: p95 17.6ms, p99 20.7ms, max 56.5ms*; >20ms ×8, >25ms ×4, >33ms ×3, >50ms ×1*.
  - Per-frame callback work: mean ≈0.7ms, p95 ≈1ms → lag NOT from render/UI weight; it is Timer delivery rhythm (scheduling/coalescing/wait boundaries).
  - Headless probes show 0 miss/0 hitch because advanceFrame bypasses real Timer delivery.
  - Conclusion: 8.333ms tolerance contributes the 20–25ms short tail; >25ms coarser tail persists in tolerance-0 → root cause NOT solely tolerance → stays CAUSALITY_UNRESOLVED (consistent with Docs/FRAME_HITCH_DEEP_DIVE_REPORT.md).
- **Artifacts**: /tmp/launch-copy-paging-prototype-swipelag-{callback,profile,runloop}.jsonl and -swipelag0-* controls.
- **Red lines respected**: no code changed; production Timer tolerance 8.333ms untouched; no PagingCore param change; no FIX_VALIDATED/ROOT_CAUSE_FOUND/ALL_HITCHES_FIXED claims; SELFDRIVE labeled synthetic performance comparison, not physical feel evidence.
- **Follow-up options** (user decision required, none taken): (a) manual A/B feel test with `--frame-timer-tolerance-ms 0` (no code change); (b) if user decides to change production default tolerance → decision_recorded tuning round via Worker→Reviewer.
