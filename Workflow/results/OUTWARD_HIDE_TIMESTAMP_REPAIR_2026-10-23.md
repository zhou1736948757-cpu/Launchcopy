# Outward Hide: timestamp rejection repair

## Measured failure
The user performed two real outward gestures in diagnostic candidate `0b50138955ab68359d7c5283161c918f097d0fbc9c4dafdfed16d237953d0fda`; neither hid. Before any reset/quit, native report captured: reset interval 4738 frames, all 4738 future-dated; 208 exact-four frames, all admitted; 110 empty terminal frames; no expired/nonfinite/pre-cutoff frames; zero Show/Hide events and accepted Hide requests. Lifetime backend raw/delivered 4880, rejected 0; recognizer rejected 4878, fired 0. Host report idle/visible/ready.

Raw aggregate receipt: `.build/verification/20261023/outward-hide-diagnosis/physical-two-outward-result.json`. The observation interval includes ordinary touchpad use, not just two isolated gestures. No raw contacts/identities/times retained. This establishes a real timestamp-validation blocker. The exact bias magnitude and cause (initial receipt latency, source drift or another clock property) were not measured.

## Implementation
Spec: `Docs/OUTWARD_HIDE_TIMESTAMP_REPAIR_SPEC_2026-10-23.md`. Main changes only `MultitouchSupportBackend.swift` product code. Fixed anchor-plus-source-delta remains; timestamps bounded at callback-ingress uptime, not consumer delivery. Older mapping is not renewed. A separate per-device raw timestamp watermark keeps regression invalid even when bounding would hide it. Invalid time maps to NaN, preserving existing consumer rejection/quarantine instead of silently dropping a fault. No recognition threshold, cooldown, release, host guard, mode cutoff, queue, backend capability or system setting changes.

## Verification (in progress)
Existing focused XCTest 61/0 after initial source patch. New skewed-source regression tests and independent readonly source review in progress. Full suite, Debug/Release, immutable manifest, dedicated unique candidate, native readiness and physical retest not yet established for the repair.

## Evidence boundaries
Do not label physical fixed until the user actually hides with outward, releases and reopens with inward. Existing failed human gate remains authoritative until superseded by explicit new evidence. Tests, source review and READY alone cannot supersede it. Original formal/fake-only data and prior dedicated profile retained; no installation, signing, publishing, Git mutation or forced termination.

## Independent review iteration
Readonly Mill (`01a16477-ead6-7850-9eff-98018b0d5047`) identified two P2 risks in the first normalization draft: invalid terminal closed synth session before valid release; receipt sample was after copying/lock wait. Main repaired both before packaging. Re-review: `source_accept_static_only`, no remaining actionable source finding. New test-file review still pending because worker had not yet materialized it at review time. No UI/physical endorsement.

Debug product build succeeded after both repairs (13.65s). First package invocation incorrectly selected `LaunchcopyGestureValidation` as SwiftPM product, rejected before packaging (no such product); retained `package-release.log`. Corrected invocation uses default `PagingPrototypeApp` product and dedicated bundle display identity, `package-release-r2.log`; no packaging-script/code change or bypass. Release build in progress.

## Final test inputs and candidate
Singer worker delivered one new test file with12methods, statically checked only. Main extended invalid-terminal cases with invalid receipt times and added one callback-to-onFrame receipt-preservation method:13new methods. Focused final74XCTest/0 (`focused-r3.log`), after pre-refinement73/0 (`focused-r2.log`). Final585input manifest `source-inputs-final.json`, exactly2deltas versus584diagnostic inputs: one backend source and one new test file. Product input hashes match those used by Release packaging; later changes were test-only and do not require an identical rebuild. Full final suite running.

Release65.48s, strict dedicated metadata verifier and packaged localization probe3languages×367keys/signatures succeeded. Candidate `.build/candidates/outward-hide-timestamp-rc-20261023-r1/LaunchcopyGestureValidation.app`; executable SHA256 `9f5ddb04998bd7dff2f54fdf35600d849e2542e6e9e6fc1b97d42ffc54cef3ce`. Pure startup-check resolved isolated/windowed/folderLab true. Copied only160already-owned synthetic metadata/iconfiles with hashes+modes verified, zero fixtureexecutables, no humanlayout/formalpreferences/history imported. New app not launched yet; olddiagnostic remainsresident until normalhandover.

## Final independent static verdict
Mill re-read final13methodfile: `source_accept_static_only`, no new actionable findings. Invalid-terminal receipt cases, receipt-preserving internalbackend path, stale/modecutoff/raw-order and skewed bidirectional/release regressions inspected. Reviewer did not build/run/native-test/verify packaging SHA; C callback first-line sample is source-confirmed, not a timed callback or async-delivery experiment. Main owns actual final74/0 evidence; full suite pending at this checkpoint. All agents now closed.

Data preservation pre-handover verified: original249files/modes, priorphysical161, currentdiagnostic161, newrepair160 allmatch their own manifests; each history directory absent. See `data-preservation-pre-handover.json` in repairverification directory.

## Final delivery / native retest ready
Final full XCTest3609/0 (157.054s), focused74/0, Debug/Release, strictmetadata/localizationprobe and diffcheck succeeded.585frozeninputs stillmatch. Independent static reviewer accepted source/final13newtestmethods; no independentruntimePASS. All agents/jobs closed.

OldowneddiagnosticPID99781 normallyQuit and exactabsence/profile161files+modes verified; no stale binding queries afterward. Newcandidate9f5ddb04 native launchedPID13366, ordinary real-validationwindow, realbackendREADY,parentON/outwardON only in newisolatedprofile, Applyack observed. Globalshortcut/corner/loginOFF+disabled. Reportbeforehuman: all counters0,hostReadytrue,presentationvisible,dirty/restore/settings/folder/dragfalse,pending0,pageridle. Reportclosed thenobservationreset; leftemptyquery/mainpage1 with no modal. WallpaperstillLOADING atlastobservation, so this is gesturefunctiononly, not wallpaper/visual/performanceacceptance.

Currentcandidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/outward-hide-timestamp-rc-20261023-r1/LaunchcopyGestureValidation.app`
ExecutableSHA256: `9f5ddb04998bd7dff2f54fdf35600d849e2542e6e9e6fc1b97d42ffc54cef3ce`
Receipt: `.build/verification/20261023/outward-hide-timestamp-repair/native-ready-for-retest.json`. Raw baseline separate. No further reset/quit until actualhumantrial/resultcountercapture. Original249files/modes and priorphysical161/currentdiagnostic161 preserved; new160syntheticmetadata/iconfixtures, no executables/humanlayout/formalpreferences/historyimport. Nothinginstalled/signed/published; noOS/reference/Git/signals.

Measured future-time blocker repaired in source/synthetictests; physical fix acceptance remainsPENDING. Next: useractualoutwardHide(notQuit), fullrelease/inwardShow, folderbusyoutwardreject; inspectneutralcounters before anyreset. Other whole-parity/IME/VoiceOver/120Hz/performance/sessiongates remain separate, fullusergoal incomplete.

## User physical acceptance and launch-scope clarification — 2026-10-23
User confirms all three requested actual checks normal: outward Hide, full-release/inward Show, folder-open outward refusal. Record this as USER_ACCEPTED for those three observable cases on9f5ddb04, not full gesture matrix/whole-parity acceptance. Main confirmed same ownedPID13366/executable before native report access. Viewmenu opened; report action then returned MacLOCKED, so post-trial aggregate counts were NOT read. Report state unknown; no reset/quit/restart attempted. Current native wallpaper diagnostic is render-failed, not a visual/performance PASS.

User also reports main/folder app clicks cannot launch. Verified the approved dedicated harness deliberately rejects sharedlaunch interaction (`AppDelegate.installLaunchAttemptFeedback`) and injects `GestureValidationAppLauncher.openApplication` returningfalse; owned synthetic fixtures have no executables. This explains this build's behavior without inventing a launch regression or certifying normal-mode launch. Keep capability policy unchanged. No source/build/test changes;585inputs/executable stillmatch. Do not use old native launch evidence as a new current acceptance. After manualunlock: capture counters before reset/quit, then a separately identified functional test environment may resume; never remove dedicated launch guards just to make placeholders clickable.

Receipt: `.build/verification/20261023/outward-hide-timestamp-repair/user-physical-acceptance-and-launch-scope.json`.

## 2026-10-23 post-trial report retained and functional handover
After userunlock nativecounterread succeeded:18371frames/future0/expired2302, Show4/Hide2/acceptedHide2, fire6. Exact full neutral receipt `native-post-human-result.json`; aggregate is not per-case attribution and does not explain expiry. Combined with bounded userthree-caseacceptance, future-time blocker repair is supported; broader tests remain separate. Ownedgesture13366 normalQuit aftercapture; ordinary isolatedfunctional71815 nowresident, with actual main/folder inertfixtureclicklaunches verified. Fullhandover report at Workflow/results/FUNCTIONAL_LAUNCH_HANDOVER_2026-10-23.md.
