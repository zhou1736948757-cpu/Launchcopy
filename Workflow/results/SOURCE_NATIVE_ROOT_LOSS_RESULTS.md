# Repaired-candidate root-loss native verification and backdrop update

Date: 2026-10-15. Main native evidence, not an independent live Reviewer run.

## Identity and scope
Same unsigned/uninstalled candidate `source-coverage-rc-20261015-r1/LaunchcopyUITest.app`, executable SHA256 `66cd55c147954f91387131a0585bb970bda5ace6925079ab45138b2ba653a32b`. Current 455 frozen inputs reverified unchanged. No production/test/build/package/physics/persistence-policy/OS-setting changes this turn. Prior 2680/0 XCTest and source review remain prior execution evidence.

Only candidate-local synthetic source/metadata-only app were used. No real app, original profile, reference resource, permission, desktop wallpaper, signing, install, commit, process kill or deletion was involved.

## Native root-loss transaction (PID 68800)
1. Cold process: one authored `Native Source Probe` app appears. Exact AX-set query matches it. Sources automatic checkbox on, status enabled.
2. Touch only owned fixture Info.plist metadata, then atomically park its Applications root under the same private profile. Root inode 38242204 and fixture inode 38242711 retained. This intentionally supplies a real filesystem-change precursor; it is **not** a RootChanged-only experiment.
3. **Without manual refresh**, native status changes to “Some sources cannot be monitored; use Refresh Now (including returned folders).” Close settings: same query retained and no results. Saved layout payload hashes equal baseline.
4. Immediately restore the exact original root/inode. Native Sources status remains degraded before retry: existence alone does not claim reattachment.
5. Native **Refresh Now** restores enabled coverage and the exact query's named result. Saved layout payload hashes still equal baseline.
6. Return the authored app to sibling staging. Re-established monitoring automatically removes its result without another explicit refresh. Clear query, normal menu Quit, verify exact executable process absence without querying the closed app.
7. Final source directory is present, same inode, empty; parked path absent; owned fixture remains staged. No fault left applied.

**Bounded native PASS:** current repaired-candidate observable degradation, preserved query/layout payloads, conservative pre-retry state, explicit recovery, and subsequent automatic event delivery. Unlike the preceding healthy-root-only run, this does exercise a real unavailable-root scenario. No internal branch trace identifies the exact callback/branch, and the metadata precursor means universal automatic root-loss/return notification is not proved. Group retention is not tested by this one-app fixture. No latency/SLA/performance/physical acceptance claim.

Receipt: `.build/verification/20261015/source-reappearance-native/coverage-repair/native-root-loss.json`.

## Wallpaper correction: transient recovery, not a code repair
Earlier PID 65891 stayed loading/black. On the same executable/profile, PID 68800 began loading but reached ready; the screenshot visibly contained a blurred wallpaper. No relevant code or OS setting had changed. One cache file now existed. After normal Quit and confirmed absence, a genuinely new PID 70038 started ready and its visible backdrop was confirmed. That second restart had an existing warm cache; cache bypass versus warm-cache causality was not instrumented.

This supersedes blanket “currently always black” wording. It does **not** prove the original source-open stall was fixed or identify its root cause. Classify as **INTERMITTENT_FAILURE_NOT_FIXED / TRANSIENT_RECOVERY_OBSERVED**; same-source cold reliability remains unproven. Original loading/source-open evidence is retained, not erased. No personal wallpaper filename/path/pixels were copied into a diagnostic artifact. Screenshot was visually inspected through the supported UI tool only.

Both test processes exited normally and exact executable absence was verified. Receipt: `coverage-repair/wallpaper-transient-recovery.json`. The separate OS-wallpaper A/B/A protocol stays PROPOSED/pending approval, now an optional causal discriminator rather than a prerequisite for observing any working backdrop. Never infer OS-setting permission from unlock/general computer use.

## Review and next actions
Previous Arendt evidence-quality PASS covers its earlier healthy-root pre-cleanup snapshot only; it does not independently certify this later native transaction or backdrop observation. Prior Meitner bounded source PASS remains separate.

Full goal remains ACTIVE and incomplete. Next useful authorized work should target a concrete remaining requirement (for example a controlled successful own-fixture application launch), not duplicate source review/builds or claim complete parity. Human physical IME/VoiceOver/120Hz and unapproved layout/destructive/usage/extra-gesture branches remain distinct.
