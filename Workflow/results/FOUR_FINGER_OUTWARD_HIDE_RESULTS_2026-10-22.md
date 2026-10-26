# Optional four-finger outward resident Hide

Date: 2026-10-22. Status: SOURCE_BUILD_PACKAGE_AND_BOUNDED_NATIVE_SETTINGS_VERIFIED; physical gesture pending.

## Scope and authority
The human explicitly approved the default-OFF safe scope. See `Docs/FOUR_FINGER_OUTWARD_HIDE_SPEC_2026-10-22.md`. Preserve accepted folder/main sizing, rendering continuity and inward-only default behavior. No reference code/assets, new device subscription, permissions or global services were introduced. Main alone executes verification and native isolated handover.

## Implementation
- Independent outward growth threshold0.15 with exact4 stable contacts, shared one-action-per-session and release/cooldown protection.
- Bounded Hide queue emits a request only; resident owner alone prepares and hides, never quits. Generation/attachment and host admission rechecked across cleanup.
- Host fails closed for folders, paging/navigation, drag, editing/IME, Settings, modal/removal/save/Quit protection, restoration and teardown. Empty exact search focus is idle; any nonempty draft remains protected even without field focus.
- Activation schema3 adds optional choice; legacy1/2 ignore stray fields and do not write on load. Strict CFBoolean opt-in rejects malformed numeric values. Inner activation settings schema2 unchanged. Draft/Apply/rollback/Defaults and nested disabled-while-parent-OFF checkbox retain independent choice.
- English, Simplified Chinese and Japanese include both new strings. Resource verification independently requires367keys and the new key names.

## Review and failed-run ledger
First bounded reviewer identified malformed NSNumber1 coercion: repaired with CFBoolean type checking and explicit numeric controls/no-write checks. The same reviewer found lifecycle release loss, stale same-provider queued callbacks, and original-time masking at composition. Converted reviewer to bounded recognizer repair implementer only; a different independent final reviewer must inspect integrated repairs.

Focused-r1/r2 were compile failures: Main nested fixtures needed explicit MainActor, then the old compile-only one-case PinchEvent assertion needed an actual default-only trace assertion. No product safety assertion was removed. Focused-r3:263/0.

Full-r1:3531tests/2failures, both stale localization count365 versus367. The failed log is retained. Focused-r4 follows lifecycle/delivery/time repairs and count updates; result pending. Test logs live under `.build/verification/20261022/four-finger-outward-hide/`.

## Evidence boundaries / remaining gates
Full green suite, Debug/actual Release, packaged strict isolated metadata/resources and frozen source, independent static review, native settings Apply/parent retention/normal restart remain pending. No new candidate has been opened yet. Do not promote old d9f3ab2f tests/native/human acceptance to this new source.

Real outward gesture calibration, mistaken-Hide rate, real device energy/session behavior, physical paging/scanout,120Hz and full product parity are not established by synthetic/fake service tests. The isolated test entry must remain fake and ordinary/non-topmost; no real backend escape hatch.


## R4 and second independent review
Focused-r4 executed294tests/8failures:3new lifecycle expectations assumed stop/restart/suspend was release (contract now explicitly requires release),1negative-time assertion expected rejectedCount though mode-cutoff fences before recognition, and4assertions exposed the test helper global.sync executing inline on the main thread instead of queuing actual delivery. Repaired tests require release, distinguish pre-mode generation fences from parser rejection, and use global.async plus bounded semaphore acknowledgment before Main yields. These are not physical callbacks. Second reviewer independently found modeOFF quarantine could lose rawtime validation: added query spanning optional mode OR explicit quarantine; cutoff now applies after a mode edit regardless ofcurrentmode. New ON→OFF known/unknown-contact bufferedrelease tests cover this path. Never-enabled/noquarantine default still aligns time. Focused-r5 pending; oldfailurelogsretained.


## Full R2 and strict package check
FullR2 passes3550/0; Debug and actualRelease build pass. Independent finalstaticreview SOURCE_ACCEPT_STATIC_ONLY, allagentsclosed. Strict packageR1 refused its developer-only LocalizationResourceProbe because another independent365-key guard was stale. CandidateR1 is preserved and never launched; no validation bypass. Main updated onlythat probe to367 and independently required bothnewkeynames; frozenR3 captured, fullR3/build/packageR2 next. Oldcandidate normalQuit/exactPID50137absence was verified before this strictpackagefailure, no signals or datachanges.


## Final verified delivery — 2026-10-22

The optional feature is implemented and verified at source/build/package/native-settings layers, **not physically accepted**. Final focused295/0, fullR3 **3550/0** (95newmethods), Debug/actualRelease/package pass. Frozen574inputs/20changedexistingfiles/9newtestfiles, manifest `cba85311209f079b31579a4b8fd77a9efa2906edc33f51a9a4a2f12381c8b593`; diffcheck stable. Packaged-only probes verify367keys×3languages/1101entries, with development fallback forbidden. Failed prior runs/packages are retained, not bypassed. Independent final app-source review SOURCE_ACCEPT_STATIC_ONLY; subsequent developer-only resource probe count/required-name repair did not change app implementation.

New unsigned/uninstalled ordinary isolated app: `.build/candidates/four-finger-outward-hide-rc-20261022-r2/LaunchcopyUITest.app`, executableSHA `d7302a1875a6b7ff60365c9405428b1ce847c24091fb40879726e7baf72c2ced`. Current PID77093 at receipt, reverify before process actions. NormalQuit/exactabsence ofold50137 andnew75948 verified; no signals. All249latest authored fixtures/modes and layout `fc98962dbc55b8195d48430b67d892d9a44ff9ccffb3a37aebc61415f7e5a9f5` preserved; no preference/history/cache import.

Native CUA: initialchildOFF; enable+Apply acknowledgment; parentOFF leaveschildONdisabled; save; normalQuit/reopen retainsOFF/ON; parentON restoreschildeditable; restored childOFF andsaved. Exact candidate-derived isolated activation plist schema3 read-only confirms finalparentON/childOFF; innerpayloadschema2 unchanged. Chinese checkbox label is readable in transient1000×1184 screenshot; no screenshot was saved. Final main queryempty, Settings/folderclosed, wallpaperREADY. No current-build nativeEN/JA, realIME/VoiceOver, desktop2 orphysicalperformance claim.

The isolated entry correctly shows backend disconnected. Do not ask the human to validate a physical four-finger gesture in this fake-only test instance or enable a real-backend escape hatch. A separately scoped real-device validation gate is still required before claiming outward gesture calibration/mistaken-Hide acceptance. Allagentsclosed/allverificationjobs terminal; formaldata/OS/reference trees untouched, no commit/sign/install/publish. Full original parity objective remains incomplete. Final machine receipt: `.build/verification/20261022/four-finger-outward-hide/final-receipt.json`.
