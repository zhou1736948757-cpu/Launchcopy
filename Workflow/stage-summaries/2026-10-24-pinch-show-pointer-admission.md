# Pinch Show pointer admission — 2026-10-24

## Objective and baseline
Investigate the user's failed three-finger pointer drags after four-finger Show. Current isolated PID 5996, SHA `ab2b343b…`; previous 3683/0 automated baseline does not establish physical reliability. Specification: `Docs/PINCH_SHOW_POINTER_ADMISSION_2026-10-24.md`.

## Confirmed evidence
Retained mixed physical aggregate: 80 native window dragged events versus zero B1 main dragged events; earlier folder moves/commits are mixed in. No cancellation/admission-denial counters. Neither exact failed-attempt routing nor a Show-specific cause is proved. Report alert closed without resetting the capture or quitting the preview.

## Decision and ownership
Main owns critical-path production Show/content sizing/hit routing investigation and any regression-backed integration. One read-only sidecar may audit activation/input ownership; no shared writes, tests, or desktop operations. At most main plus two sidecars; no old workflow/watchdog invocation. Keep all existing unrelated dirty work. No production user data changes, installation, signing, Git mutation, or forced exit.

## Verification, review, risks, next action
No new repair or tests yet. Independent review and physical acceptance pending. Inspect and reproduce actual Show-to-pointer admission; do not modify physics or blindly enlarge launch hit targets.

## Production Show control and independent sidecar
The initial test build was compile-only invalid (attempted access to private folder glyph); the test now uses the documented shared public icon geometry, without widening production access. `show-routing-control-r2.log` executes **1/0**: three ordinary-window attach/Show/hide cycles, all35 visible app/folder slots, each real B1 down/drag/cancel/late-up. This is105 synthetic fixture sequences through the production controller and window, not105 physical tests. No production source changed and no Show sizing defect was reproduced.

Read-only Fermat audit found no pinch-release latch intercepting native pointer events. It identified a potential reentrant old-up cleanup problem and focus-counter blind spots, neither linked to this physical failure; retain as follow-up rather than claiming causality. No files/tests/UI changed by sidecar; agent closed.

The mixed report was retained before capture reset. Through the owned app's View menu, Main reset neutral counters and normally hid the preview; app inventory has the owned process but no windows. No Quit/data mutation. User was asked for one precisely bounded fresh pinch Show, then a single three-finger drag from an actual icon center (not caption), with no retries. This distinguishes main source-hit admission without mixing earlier folder attempts. Do not operate the desktop during that attempt.

## Human success and second mixed capture — 2026-10-24
The user replied **first attempt could drag** after inward pinch Show from an actual icon center. This is a positive physical observation on the unchanged running binary, not acceptance of all intermittent cases. Read the live report and closed it without reset/quit. New report `physical-report-success-mixed-r2.json`:13windowdowns,309windowdrags,8B1downs/155B1drags/8B1ups,3nativefolderdowns,7dragstarts/7commits overall; denial/cancellation counters remainzero. Although one main attempt was requested, the actual capture includes more operations and folders, so **it is not a clean single-attempt trace**. No attempt-level pairing, universal pinching success, or sole hit-zone cause may be inferred. Do not blame earlier attempts on where the user pointed.

Existing production Show control strengthened to require exactly35live cells, never skip missingcells. Final owner regression class `owner-focused-r2.log`:**58/0**,2.578sexecution. Source manifest `source-inputs-final-r3.json`:599knowninputs, one test-file delta, all production/package inputs unchanged. Earlier full3683/0 is the unchanged production baseline, NOT a newly executed fullsuite for this testdelta. No replacement candidate or new independent review required/claimed for a product change because no product source changed. Main source inspection is not formalReviewerPASS.

Runningowned5996/ab2b343b… remains ordinary integrated preview, wallpaperREADY, report/menuclosed. Capture remainsenabled/preserved. No restart, additional reset, realapp mutation byagent, installation/signing/Git mutation, or saved screenshot. The user need not repeat more scripted trials now; retain normal use. If a concrete failure recurs, preserve the current app/report before any reset. Additional fixed-label hit/ownership observation is a possible next bounded investigation, not implemented or declared a repair. Current gate: **OBSERVED_SINGLE_SUCCESS_CAUSALITY_UNRESOLVED**.
