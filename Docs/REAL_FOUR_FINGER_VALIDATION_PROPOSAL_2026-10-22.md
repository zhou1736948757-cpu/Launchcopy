# Real four-finger device validation proposal

Date:2026-10-22. Status: ENVIRONMENT_AUTHORIZED_BY_USER; explicit approval received 2026-10-22. Implementation must follow a bounded spec and fail-closed verification before real backend activation. The optional outward feature itself is already approved and implemented; do not ask for that decision again.

## Why another gate is needed
The current isolated UI entry is deliberately fake-only and displays backend disconnected. Synthetic tests and native preference/restart verify different layers from real recognition, mistakenly triggered Hide, lifecycle and calibration. Production fallback would read ordinary user preferences and may start unrelated global services; it is not an acceptable test shortcut.

## Recommended bounded environment
After explicit user approval, define and review a dedicated real-device validation contract before code. Use a separately identified unsigned/uninstalled ordinary-window candidate with independent local preferences/layout/catalog of owned synthetic fixtures. Keep the existing UI-test marker/profile and all its factories fake-only; do not add a command/metadata escape hatch there. A distinct explicit validation entry may use only the already-existing MultitouchSupportBackend and existing recognizer/composition/host readiness, with exactly one provider and bounded lifetime. Shortcut, Hot Corner, login, activity history, real application catalog/actions and formal data remain disabled/unavailable. Do not add permissions, event taps, accessibility/global monitors, OS settings or new subscriptions. If additional OS permission unexpectedly appears, stop for explicit action-time authorization rather than weakening security.

No raw touch coordinates/device identifiers/application identities are persisted. Optional neutral action/refusal counts and coarse wall-clock test steps are allowed only with an explicit diagnostic switch. Normal owned-instance Quit releases provider resources; never stop unrelated applications or use signals. Leave original candidate and all user arrangement untouched.

## Physical packet
With user present: verify backendReady first; outwardOFF noHide/inwardShow retains original behavior; outwardON idlemain and committedLibraryHide; folder/drag/edit/IME/modal/settings/pendingwrite reject; heldcontacts across mode/parent/lifecycle transitions require release; inwardShow thenoutwardreverse cannotHide in same session; freshreleased outwardHide neverQuit; ordinary reopen works. Compare supported physical60Hz input and accidentaltrigger behavior under named workload, not generatedwheel/input.120Hz remains hardwareblocked unless a real120Hzdisplayisprovided. Reject calibration changes without data; outward0.15 is only startingcalibration.

## Decision / unresolved design
Ask permission only for this real touch-input validation environment, not for reimplementing the already-approved feature. If declined, retain current verified source/native-settings state and label physical gate pending. Exact distinct-entry architecture and fail-closed metadata/schema/injection design still require a bounded approved implementation spec; this proposal doesnot authorize an unreviewed new testmode. Full reference parity staysunproven.

## Authorization update
User selected the dedicated real-device validation environment on 2026-10-22. This supersedes earlier pending authorization notes only for this environment, not physical acceptance or broader features.
