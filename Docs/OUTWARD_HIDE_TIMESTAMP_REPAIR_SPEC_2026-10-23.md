# Four-finger input timestamp repair

Date: 2026-10-23. Bounded bug fix; approved outward-hide behavior and safety scope stay unchanged.

## Problem and measured evidence
Two human outward attempts failed in diagnostic candidate `0b501389…`. The reset observation interval recorded 4738 delivered frames, every one future-dated at consumer entry; 208 exact-four frames were admitted by the host, no hide event/request. Lifetime recognizer rejected 4878 frames. See `physical-two-outward-result.json` under `.build/verification/20261023/outward-hide-diagnosis/`. These aggregates establish a time-validation blocker, not an exclusive explanation of all possible gesture failures or exact per-attempt counts.

## Scope and contract
Correct backend ingress clock normalization, not recognition thresholds or consumer admission. A synthesized valid frame must never be later than the callback-ingress `systemUptime` sample. Preserve source ordering faults, invalid time rejection, conservative release/quarantine, device isolation, generation fences and mode cutoffs. Do not stamp consumer delivery time onto queued frames: queue delay must remain visible and stale frames must still fail. No use of wall clock, broad future tolerance, reset-on-every-frame age renewal, raw data persistence or background sampling. Keep existing callback-delta timing when valid. Callback latency/clock drift magnitude and origin remain unmeasured.

## Architecture and acceptance
Use a small deterministic normalization change in `MultitouchFrameSynthesizer`, with tests for first-anchor latency bias, source-ahead timestamps, normal deltas, delayed delivery, old/reordered/nonfinite input, device isolation and actual composition outward/release/inward behavior. Independent reviewer checks no future/stale/order safety bypass. Existing production and fake-only/dedicated entry isolation contracts stay unchanged.

Main owns serial focused/full XCTest, Debug/Release and strict unique unsigned candidate. Preserve current diagnostic report/fixtures; only normal Quit of owned instance after capture. No installation/signing/Git changes/OS setting changes or reference-tree access. Native recheck readiness, start observer, leave no modal; physical user outward-hide, full-release/inward-show, folder-busy guard retest mandatory. A static test pass is not a physical fix pass.

## Maintenance and risks
Do not add an independent gesture engine or time-tolerance tuning knob. Document the ingress-vs-delivery time distinction where mapped timestamps are constructed. Mapping can make a source clock fault more conservative; it must not turn reordering or stale queued frames into fresh input. Further contact/session failure after correcting future dates is a separate measured investigation.

## Selected mapping
Keep the original fixed per-device anchor/delta, cap finite valid mapping at callback-ingress uptime with `min(mapped, receipt)`, never at consumer delivery. Do not reanchor or raise an old mapped timestamp. Ordered source/receipt sequences retain order under their pointwise minimum. Track the valid raw callback watermark independently so bounding cannot conceal a raw regression; invalid/nonfinite/overflow timestamps remain invalid (NaN) at the existing consumer validator and cannot poison anchors/watermark. Contact/session synthesis continues so invalid input reaches existing quarantine logic rather than silently dropping a fault. Duplicate source times remain permitted as before; no new strict-increasing requirement.

## Independent review refinements
The timestamp cap uses a sample captured at the top of the actual C callback, before the registry lock, touch copying and backend lock. The public synthetic injection entry similarly samples before its lock; a shared internal overload carries that receipt unchanged. An invalid-time terminal is delivered as invalid but retains synth session/contact state, allowing the following valid empty terminal to reach the consumer and clear quarantine. Never accept invalid release or swallow the subsequent valid release merely because synthesis prematurely closed its session.
