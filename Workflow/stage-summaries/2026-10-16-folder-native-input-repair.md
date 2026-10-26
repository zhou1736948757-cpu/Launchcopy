# Folder Native Input Repair — 2026-10-16

## Objective and user evidence
User reports real two-finger paging still fails on folder-interaction r2. User attributes perceived shadow to whole-background dimming during entrance; do not relabel it a proven extra black frame. Previous2788green/source review/native button/resize observations did NOT establish gesture acceptance. Native gesture gate remains FAILED_REPORTED_BY_USER.

## Plan and source baseline
Prior463source/candidate freeze matches current tree. Main critical path: reproduce actual startup order (content assembly before window), inspect window route installation, add regression and repair; then native automation evidence separately from user trackpad gate. Optional dimming visual change needs user preference confirmation. One read-only sidecar may audit startup-order test coverage while Main implements. No original reference code/assets, no outer-engine/physics changes, no install/sign/commit/kill or formal-data changes. Ordinary non-topmost isolated test windows only.

## Current source finding
applicationDidFinishLaunching installs content assembly before constructing its local NSWindow. installFolderWiring currently installs onFolderScroll only if self.window already exists. It is therefore skipped at real startup, while previous owner fixture assigned window before installing folder wiring. Later real-window setup installs folder state provider but not its scroll handler. Open-folder events are consumed with a nil callback. This is a concrete source-level lifetime/order defect; actual regression/native repair verification pending.

## Next actions
Extract real window-owned input wiring seam, call it on actual window creation, test content-before-window order, fix callback resolving current overlay dynamically. Preserve prior candidates and their historical results. Record current physical failure and future verification honestly.

## Root repair verification
Main extracted window-owned installFolderWindowInput(on:) at the actual window-creation boundary. It installs state provider and scroll callback together, each weakly resolving the live owner, not capturing an overlay created earlier. Conditional installation inside content wiring removed. Actual startup-order regression executed RED1test/2failedassertions (nilhandler and zero inneroffset). Fixed focused66/0; stronger finalowner31/0 includes actual window event release/settlecommit1 and visiblemember update for both constructionorders, unchangedouterstate plusblockedinput and retainedold/replacementoverlay isolation. Full2790/0 before strongertest-onlyassertions; final full rerun pending. Source463freeze final changedonly AppDelegate and existingownertest relative priorcandidate. Banach independently confirmed originalcausalchain; finalsource re-review requested. Dimming unchanged pending userchoice in FOLDER_BACKDROP_FEEDBACK_PROPOSAL.md.

## Final code/package checkpoint
Finalfull2790/0,86.491s; Debug/Release/probe290keys3languages/diffcheckpass; Banach boundedsource no blockingfindings/463hashes/0executions, closed. OnlyAppDelegate+existingownertestchanged;461otherinputshashesunchanged. Candidate /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-native-input-rc-20261016-r1/LaunchcopyUITest.app, SHA6b2e1ab8a6ade22249136855fcc5fdc9804083174df9b6d0aaa6e64354e8579e,40fakeapps/35memberfolder/profilehashesunchanged. CUA Maclocked; nooldquit/newlaunchoccurred. NewphysicalgatePENDING afteroldr2 userreportedFAIL. Dimming stillpendingchoice/unchanged. Allagents/jobsclosed; finalhandoff Workflow/results/FOLDER_NATIVE_INPUT_STARTUP_RESULTS.md and receiptsfolder-native-input/final-receipt.json.
