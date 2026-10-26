# Optional four-finger outward Hide — proposal

Date: 2026-10-20. Status: PROPOSED, NOT APPROVED. Existing inward-only contract remains authoritative until the human explicitly changes it.

## Problem and decision
The full experience-parity ledger retains additional gestures as an unresolved branch. Existing FOUR_FINGER_ACTIVATION_SPEC §1 and the 2026-09-05 decision explicitly exclude outward Hide. Current PinchEvent has only showRequested; expansion cancels the session, the coordinator only flushes Shows, and ActivationPreferences schema2 has no outward choice. This is not a defective inward implementation or proof that the reference product behaves a particular way. Ask whether to add one optional outward action, rather than silently reopening the exclusion or claiming full parity from the already implemented subset.

## Recommended user-facing behavior (pending confirmation)
- Retain current strict four-finger inward Show, its saved setting/default and device-readiness truthfulness.
- Add an independent nested setting, off by default: four-finger outward Hide. It is effective only while the existing four-finger service is enabled and ready. Turning the parent off stops both actions; do not add a second provider or global listener.
- Only an already visible, idle main grid or Library can hide. Do not act during folder presentation, drag, rename, marked-text composition, sheets, quit/restore, or accepted-write protection. A hidden launcher cannot be shown by expansion; expansion never quits the process.
- Use the established resident Hide owner and cleanup/restoration semantics, not a new close-window path. Do not change search, folder, page or animation defaults.
- One physical contact session can produce at most one action total. Inward Show followed by expansion before all fingers release must not immediately Hide. Reversed/cancelled/three/five-finger, replaced-contact, stale/malformed-frame, device/lifecycle and generation behavior remains conservative.
- Persist the user's nested choice but make it ineffective while the parent is off. Mode changes invalidate in-progress candidates and require fresh admission rather than retrospectively firing a held gesture.

## Architecture and storage direction
Keep classification a pure value-state machine and dispatch in the existing serialized coordinator/composition. Define directional actions explicitly; do not translate a synthetic event or infer success from interface visibility alone. Disabled optional mode must preserve existing inward-only behavior and traces. Existing expansion-cancel geometry is not automatically an approved physical trigger calibration; confirm/calibrate the separately named outward threshold before claiming device success.

If approved, write the final implementation contract before edits. Expected bounded integration: PinchRecognizer action/admission policy, FourFingerActivationCoordinator event ownership/dedup, ActivationComposition resident-Hide effect path, ActivationServicePlan/preferences propagation, Settings checkbox and localized text. Existing Public enum/callback signatures require deliberate source-compatible seams or explicit exhaustive-caller updates, not hidden fallthrough behavior.

ActivationPreferences currently uses schema2. Proposed additive choice uses a versioned schema3 migration: known older values retain inward choice and existing settings, new outward false; unsupported future bytes remain protected. ActivationSettings and unrelated stores do not change merely because the outer envelope advances. Defaults/reset/save-failure/safe application semantics require tests. No automatic migration write on startup or silently enabling an existing profile.

## Safety / performance / non-goals
No new permission, framework symbol, dependency, tap, Accessibility/Input-Monitoring request, raw touch/identity logging, OS setting, or second frame/touch pump. Isolated UI must retain fake device/global/login adapters; no escape hatch for a manufactured physical PASS. No real backend activation or formal preference change as a side effect of unit/native testing. Source access to LaunchBetter/Buho/raw evidence remains prohibited. This proposal adds no code, updates no saved preference and does not turn on the new behavior.

Non-goals: toggle-on-any-pinch, outward cold launch, three-finger drag, full uninstall, global usage monitoring, changing main/folder paging, or proving universal reference parity. Keep these other original-objective branches explicitly separate.

## Acceptance if approved
1. Default-off and all inward-only regressions unchanged; event trace parity with optional mode off.
2. Synthetic device/session/direction matrix, one-action-per-session and stale/reentrant callback fencing; active-work/hidden/refusal gates.
3. Schema1/2-to3 compatibility, missing/invalid/new/future values, reset/parent gating and real accepted save failure semantics.
4. Actual executable/settings callsites plus three-language packaged labels, fake-only native toggle/save/normal reopen without changing formal data or real service activation.
5. Nonzero focused/full suites, Debug/Release unique unsigned candidate and bounded independent review on frozen inputs. Native and real-device matched acceptance remain separate, no performance or physical success claim from synthetic frames.
6. Only after suitable human authorization/environment, actual device positives/negatives and mistaken-Hide/energy checks on the exact production-shaped backend; never substitute the isolated fake adapter.

## Pending decision / current delivery
Human must choose whether to supersede the old outward exclusion with this default-off feature, or explicitly retain inward-only. No implementation begins before that answer. Current exact0b9b20ad candidate remains unchanged; its basic native smoke/reopen passed under its bounded report. Actual touchpad/IME/VoiceOver/display/production activation and other semantic gates still prevent declaring the whole objective complete. First Library hitch remains user-deferred/nonblocking and is not being investigated.


## Explicit approval —2026-10-22
Human selected the recommended default-off safe scope. The implementation spec `FOUR_FINGER_OUTWARD_HIDE_SPEC_2026-10-22.md` now supersedes the pending decision above for this branch only; no physical success is implied.
