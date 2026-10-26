# Folder Scroll No Response — Bounded Defect Repair

Date: 2026-10-17
Status: INVESTIGATING

## Human report and scope
Current native main-grid-capacity r2/adbd845c test app: folder has three pages, but horizontal trackpad motion produces no response. Prior native acceptance checked button paging, not real two-finger follow-through; do not inherit that as a scroll PASS. CUA horizontal scroll inside open folder also left AX unchanged, but its events are not proof of physical trackpad phase delivery.

## Plan
Main inspects live input/lifecycle/guards and reproduces with production-owner regression. A sidecar reviewer audits missing production-like test coverage and narrow input hazards, read-only except its report. Keep maximum3 agents including Main. Only Main executes builds and UI. Fix the demonstrated defect, focused/full/debug/release tests, stable source review, own normal Quit/new isolated candidate, observed native controls. User acceptance/physical trackpad gate stays distinct.

## Boundaries
Existing approved follow-finger folder paging, modal consumption and outer physics unchanged. No new feature contract/spec decision required for restoring that behavior. No reference repository/assets access, OS settings, formal-data changes, kill/sign/install/commit/reset/clean. Huge dirty worktree preserved. No UI via shell; CUA only. Read RTK/AGENTS; user waived Chief ceremony. Baseline source hashes in .build/verification/20261017/folder-scroll-no-response/source-before.json.

## Open evidence
Find input rejection or lifecycle reset with a failing regression; do not assume direction or event routing solely from unchanging AX. Current candidate remains running until new verified handover.

## Input-evidence checkpoint
Sidecar Leibniz source audit completed and closed: no unconditional controller failure for admitted stable began→changed; concrete cancellation/reentrant-layout risks are hypotheses, not runtime rootcause. Main added an actual owner regression with installed language owner,1000×668 viewport,30×15pt changed events and repeated production-like chrome/readability/folder layout. It PASSED1/0(0.297s), log owner-small-events-r1.log; not a physical result. No actual bug repair has been claimed.

Two diagnostic packages created; r1 attached Help to a currently non-AX-element overlay, so its absent Help was not event-delivery evidence. r2 attaches path/identity-free in-memory phase/admission/state to existing title button Help, and native CUA scroll now demonstrably reaches window→folder route: last snapshot phase0/momentum0/horizontalfalse/dominanttrue/admittedtrue/transitionfalse/availabletrue/stateidle/offset0/page0. Last-event-only snapshot cannot characterize a whole injected stream or physical trackpad. No direction/physics change made.

Own previous capacity r2 then diagnostic r1 normallyQuit via observed menu; each exactprocess absence checked. Only own fixture Info.plists and layout/Library/capacity JSON transferred, no cache/locks/formal data. Current diagnostic r2 `.build/candidates/folder-scroll-diagnostic-rc-20261017-r2/LaunchcopyUITest.app` running, folder open page1of3, ordinary non-topmost. Awaiting actual human physical swipe via existing async request, not asking to install/sign/launchscript. This is DIAGNOSIS_IN_PROGRESS, NOT_FIXED. No reviewer source PASS or new full-suite result yet.

## Human physical outcome
Human answered “成功了这个” after actual two-finger swipes. Current exposed summary records terminalmomentum8/stateidle/offset1/page1 (secondfolderpage), outerpage1/2 unchanged. No scrolling behavior changed; CURRENT_PHYSICAL_SUCCESS, originalCAUSE_UNRESOLVED. Keep diagnosticinstance, no speculativefix/parameterchange. Wallpaper AX nowready without source/OSchange; no wallpaperrootcauseclaim. Structuredreceipt physical-user-confirmation-r1.json. Addeddiagnostics+oneownerregression only; fullsuite/debug session30226 and Pasteur boundeddiagnostic/source review pending.

## Folder physical swipe currently succeeds; no behavioral repair proven — 2026-10-17

After userreported nonresponsivefolderscroll, Main inspectedroutes/guards and sidecarLeibniz innercontroller/view. Only2inputs changed: AppDelegate adds resolved-testprofile-only in-memory identity/pathfree last-event AX Help on existing foldertitlebutton; ownerregression adds installedlanguage/smallviewport/30smallchanged/chromelayout case. Focused1/0(0.297s),full2901/0(105.376s),Debug1.25s,actualRelease34.24s/package309keys×3languages/diffcheck PASS. Pasteur boundeddiagnostic SOURCEPASS; bothagentsclosed, no jobsrunning. No paginglogic/physics/parameters/layoutfix was made.

Human actualtwofingertrial replied“成功了这个”. Freshnative terminalmomentum8/stateidle/offset1/page1 confirmsfoldersecondpage, outerpage1of2unchanged. CURRENT_PHYSICAL_SUCCESS on diagnostic r2, ORIGINAL_CAUSALITY_UNRESOLVED; restart/transientstate is hypothesisonly. Do not repeat older“nativebuttonswork”asphysicalproof or callthis a confirmedcodefix. Ifrecurs, inspectstate before restarting; no speculativeorphanresurrection/modalguardrelaxation.

Currentunsigned/uninstalledisolatedcandidate `.build/candidates/folder-scroll-diagnostic-rc-20261017-r2/LaunchcopyUITest.app`,SHA38a1905d3cc371fc09671104012692b89abf98e7c463d51e63f997876a334fd2,PID2042 atreceipt; ordinarynon-topmost/5×7mainpage1of2/folderopenpage2of3. Previousowncapacityr2anddiagnosticr1 normallyQuit/exactabsencechecked. OwnfixtureInfo-onlyapps+JSONonly transferred,no cache/locks/formaldata. Layout+Libraryhashesunchanged. No reference/OS/formaldata/kill/sign/install/publish/commit/reset/clean actions. CurrentwallpaperAXbecamereadywithoutwallpaperchanges; rootcauseNOTprovenfixed. Longtail/120Hz/IME/VoiceOver/fullparityremaindistinct.

Results Workflow/results/FOLDER_SCROLL_NO_RESPONSE_RESULTS.md; stage Workflow/stage-summaries/2026-10-17-folder-scroll-no-response.md; receipt .build/verification/20261017/folder-scroll-no-response/physical-user-confirmation-r1.json. Preserveearlierfailuresandstale-statehistory; fullobjectiveincomplete.

Final status: CURRENT PHYSICAL SWIPE SUCCEEDED; CAUSALITY UNRESOLVED. No further product change inferred.
