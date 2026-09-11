# T-frame-hitch-phys1b-06 — Worker result

## Status

**Completed.** This record uses the project historical date basis **2026-08-28**. Machine-generated timestamps dated 2026-08-29 were not used to infer ordering.

## Physical capture

The repaired probe completed one real-trackpad run on a 60Hz display. Anonymous environment facts:

- display: 60Hz
- screen: 1470×956pt
- fullscreen app frame: 1470×923pt
- low-power mode: off
- gesture begin/end sequences: 30/30
- teardown completion: present

Final anonymous artifacts:

| Artifact | Lines | SHA-256 |
|---|---:|---|
| telemetry | 1,259 | `b8dcd028e873714a54cb911e2e022808b432b9081af5724cd5b43c4aec172482` |
| frame profile | 1,494 | `8e4b5a0501a44f684afc05c7ac7c1bbb8777a59a0210c1800bda7279b205c1f6` |
| runloop profile | 254,766 | `3100b291849469eae8545324b4179d6935fcbbb7311d574aa2888bb3e8d5105c` |

All JSONL lines parsed successfully. The runloop artifact is large because the observer remained active while the application waited idle; analysis was restricted to frame windows.

## Repaired analyzer result

- telemetry frame count: **591**
- intervals `>20ms`: **17**
- intervals `>25ms`: **3**
- intervals `>33.3ms`: **0**
- maximum interval: **27.986ms**
- frame/profile count: **591 / 591**
- adjacent intervals within tolerance: **561 / 590**
- adjacent mismatches: **29**
- all 17 hitch ordinals locally verified
- preceding callback maximum: **0.937ms**

The analyzer now attributes hitch interval `i` to preceding callback `profile[i-1]`, not the callback at `profile[i]`. The repaired Python suite is **15 tests, 0 failures**.

## Runloop comparison

A read-only decomposition compared the 17 hitches with 544 aligned non-hitch frames:

| Component | Hitch median per frame | Normal median per frame |
|---|---:|---:|
| waiting-like | 14.072ms | 10.958ms |
| active-like | 0.810ms | 0.812ms |
| unclassified | 5.093ms | 4.830ms |
| preceding callback | 0.647ms | 0.632ms |

Interpretation is deliberately narrow:

- supports a descriptive pattern of more waiting-like absolute time in typical hitches;
- does not prove wake-up latency, scheduler delay, Timer tolerance, WindowServer, Core Animation, or AppKit as the cause;
- three of 17 hitches contain an `exit→entry` unclassified per-frame sum above 10ms, and one exceeds 20ms; this is a minority tail, not a universal pattern;
- active-like work does not show a general increase.

## Required boundaries

- This is one physical run, not a final physical-feel acceptance gate.
- SELFDRIVE remains performance comparison only.
- No app names, bundle identifiers, URLs, filesystem paths, or icon payloads are included in generated analytical output.
- No PagingCore source was modified.

## Next action

Proceed to a targeted wake/mode-boundary profiling phase: A/B Timer tolerance, preserve the repaired asynchronous probe, and add only minimal anonymous boundary evidence. Keep unclassified runloop pairs unclassified until independently validated.
