# T-frame-hitch-phys1b-06 — Independent read-only review

## Verdict

**PASS with honest-boundary requirements satisfied.** The physical run is complete and internally coherent. The result supports a narrow waiting-like pattern claim, not a root-cause claim.

## Reviewed points

- 591 telemetry frames and 591 frame-profile frames were aligned by ordinal; 17 hitches were locally verified.
- The analyzer's callback attribution was checked against the call order and repaired to use the preceding callback (`profile[i-1]`).
- The repaired run reports a maximum preceding callback of 0.937ms for the 17 physical hitches.
- Runloop decomposition distinguishes waiting-like, active-like, and unclassified observations and validates adjacent timestamp deltas before interpreting a pair.
- The comparison reports waiting-like median 14.072ms for hitches versus 10.958ms for aligned normal frames, while active-like medians remain 0.810ms versus 0.812ms.
- Minority `exit→entry` long tails remain unclassified; they are not relabeled as scheduler, WindowServer, or Core Animation evidence.
- The runloop file's idle tail is not treated as frame-hitch evidence.
- SELFDRIVE is not used as physical-feel evidence.
- The repaired analyzer test suite passes 15/15; no PagingCore change is implied.

## Limitations

This review does not establish causality, user-perceived hitch severity, 120Hz behavior, or final remediation. The next justified step is targeted A/B profiling of Timer cadence and runloop mode boundaries.
