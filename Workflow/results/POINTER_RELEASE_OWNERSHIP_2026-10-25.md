# Pointer release ownership — bounded correction

Date:2026-10-25. Status: SOURCE_ARTIFACT_AND_BOUNDED_NATIVE_HANDOVER_VERIFIED; PHYSICAL_CAUSALITY_UNRESOLVED.

## Outcome and scope
Two independently reproduced conditional defects: an old B1 release erased capture for a reentrant same/different-cell press; ordinary coordinator click cleanup erased the newer source/suppression and caused its release to route as overlay-blank. The real intermittent physical drag failure remains causally unresolved; no actual native nested-loop occurrence was captured.

B1 now retires the completed capture before calling the target's release handler. Ordinary coordinator clicks retain the original cell/binding, retire old state, then dispatch only if no actual intervening cancellation/teardown or target reuse invalidated the release. Existing idle cancellation remains a no-op. A new admitted press alone does not cancel the original click and keeps its own ownership. No reorder commit ordering, native folder tracking flags, fallback/blank semantics, hit padding, parameters, paging, scanner/resources or persistence schema changed. This is not universal reentrancy or physical root-cause closure.

## Evidence and failures retained
- `before-r1.log`: INVALID_TEST_EXECUTION; new tests accidentally referenced a private flag. Corrected to observe the existing public suppressor callback, no access widening.
- `before-r2.log`: actual production seams,2tests/7assertionfailures.
- `initial-green-r1.log`: original two repros now2/0.
- `focused-r1.log`:113tests/1failure in a new control that incorrectly treated idle cancel as actual cancellation. Corrected that control to admit a press before cancel, and added an explicit idle-noop compatibility control; no product cancel guard changed.
- Final `focused-r2.log`:114/0,1.584s, including combined same/different-cell B1/coordinator reentry, original-target retention from an idle observer, teardown, active cancellation, replacement binding, idle-noop cancellation and duplicate-release controls plus existing click/drag/ESC/selected folder/diagnostic regressions.
- Full `full-r1.log`:3781/0,86.016s. Nine new test methods; zero-test Swift Testing footer is not the acceptance gate.
- Frozen `source-inputs-r2.json`:610inputs; `source-delta-r2.json`:threepaths versus the reviewed footer baseline. Two production files and one existing test file only.
- Debug/actualRelease/strict entry/package and packaged369keys×3language schema probe PASS; separate exact packaged-bundle smoke1107entriesPASS. Canonical manifests restored byte/mode-exact, new sidecars separate.
- Avicenna bounded SOURCE PASS; native presentation remains pending manual unlock.

## Artifact and native boundary
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/integrated-preview-rc-20261023-r1/LaunchcopyPreviewPointerRelease.app`

Executable SHA256 `8335c19bcf9caf977b511fd80598493a054df80aed433ec0877e0aa21cbdf06d`.

Unique unsigned integrated marker-v1/integrated profile, same reserved bundle and sibling parent; preserves current isolated namespace. Contains the separately reviewed catalog-footer correction. That earlier StatusFooterR2 candidate remains preserved/unlaunched, not overwritten. Current running preview is still51878/4d6e9ccb… FolderNamesR2. Five latest profile hashes/modes unchanged; old neutral capture preserved. CUA last reports locked; no normalQuit/newlaunch or saved screenshot. No agent real-app launch/drag/organization/removal, signing/install/publication, forced termination or Git mutation.

Next: source review, then after unlock fresh PID/path/hash/profile/neutral-report preflight, normal ownedQuit/exactabsence, launch exact new sibling, verify identity/wallpaper/footer and leave neutral diagnostics ready. Do not request or infer a physical root-cause PASS from this source control. Actual discovery failure, naming human acceptance, intermittent drag causality, IME/accessibility/environment/performance/full parity remain unproved.

## Final bounded source verdict / handover held
Avicenna independent **SOURCE PASS**, no actionable scoped findings; report `Workflow/reviews/POINTER_RELEASE_OWNERSHIP-r1.md`. Reviewer independently validated the exact three-file delta by in-memory reversal to inherited hashes and read the RED/green/full logs; the other607inputs were inherited, not independently rehashed/audited wholesale. Main reverified all610inputs, exact8335c19b… executable, strict marker/resources, both canonical manifests byte/mode-exact and allfivecurrentprofilehashes/modes unchanged. Debug0.32s/actualRelease30.73s. All agents/jobs closed.

Latest CUA still explicitly LOCKED with automatic unlock paused after physicalinput. Existing51878/4d6e9ccb… remains authoritative. No oldQuit/newlaunch, force-exit, data rollback, realapp mutation, saved screenshots, installation/signing/Git mutation or native/physical/performance PASS. User was already asked once for manualunlock in the previous stage; do not repeat it. `handover-waiting-unlock-r1.json` records the evidence separation.

PointerRelease8335c19b… is now the next native candidate; it incorporates the separately reviewed footer fix and supersedes FooterR2be5b968d… only as the intended next handover. Both prior artifacts are preserved/unlaunched, and current source is not inferred to run in51878. After unlock: fresh exactPID/path/hash/profile/neutralreport preflight; normal ownedQuit/exactabsence; launch PointerRelease; verify wallpaper/footer/chrome and report readiness without mutating realapp organization. Only later actualhuman input can evaluate intermittent first-drag behavior; the source defect is conditional callback reentrancy, not an observed physicalcause. Original full UI/functionality/performance/device/IME/accessibility gates remainunproved. This and the previous goal turn made concrete repairs/verification progress, not a new wait-only conclusion or full objective completion.

## User manual unlock — native handover resumed
User explicitly confirms manual unlock on2026-10-25. Fresh CUA reaches the exact old51878FolderNamesR2 ordinarywindow/wallpaperREADY; prior lock is cleared for this operation. Earlier blocked-turn count is historical and is revoked on this resume.610sourceinputs/new8335c19b… strictmarker/old4d6e9ccb… process verified; freshly captured current five profilehashes/modes before Quit, not an older snapshot to restore. No source/test/rebuild/reviewer repeat needed on byte-exact frozen inputs. Main alone owns the tightly ordered nativehandover, no source workers or UI agents. Next retain oldneutralreport withoutreset, normalownedQuit/exactabsence and latestprofilepreservation, exactPointerRelease launch/newidentity/footer/wallpaper checks. Old blocked receipts retained ashistory; fullgoal notcomplete and actualgoaltoolstatus not fabricated.

## User-unlocked native handover complete —2026-10-25
Manualunlock verified viaCUA; previous native-lock condition is cleared and earlier blocked-turn count revoked. Main retained oldneutralreport before closing it withoutreset (enabled1/total6; onlywindowDown2/windowUp2/windowNotKeyActive2 nonzero; no drag evidence), then normalQuit51878 viaitsownmenu and verified exactabsence. Freshcurrentfiveprofilehashes/modes matched beforeQuit, afterQuit and afternewstart; no import/reset/rollback.

Exact PointerRelease app8335c19bcf9caf977b511fd80598493a054df80aed433ec0877e0aa21cbdf06d now runs ownedPID91801, verified by exactexecutablepathanddiskhash. Ordinaryintegratedwindow/main/wallpaperREADY observed. Transient2000×1400pixelscreenshot shows compact warning belowbottom-rowcaptions andbeside unchanged dots, nooverlap inthiscurrentwindow. Fulltruthfulwarning remainsvisible; exactdiscoverycause NOTresolved. No screenshotfile, appinventory/title artifact, realapplaunch/drag/group/reorder/removal, OSpreference/Spacechange, signing/install/Git/forcedexit. Desktop2placement/notch/fullscreen/resize/VoiceOver/performance notclaimed.

NativeViewLibraryentryenabled. Explicitlystartednewprocess neutraldiagnostics: report enabled1/total0/allfixedcounters0 and report-time searchfalse/canCommittrue/noeditor/nofolder/notransition/keyactive verified; reportclosed withoutanotherreset, main/wallpaperREADY/menusreportssettingsclosed. Leaveappreadyforhuman, do not touch counters before consuming an actual failure report.610inputfreeze/canonicalmanifests/executable/profile5 remainexact. Existing3781/0/focused114/0 and source-onlyreview unchanged; no needlessrebuild/rerun/newReviewerclaim.

Authoritative newreceipt `.build/verification/20261025/pointer-release-ownership/final-native-ready-r1.json`; supporting old-pointer-before-quit-r1, normal-quit-old-r1, native-start-r1, new-pointer-ready-r1 andprofilesnapshots. This closes onlynativehandover/currentfooterpresentation. Newfolderdefault-name humanacceptance, actualintermittentdrag/native-nestedeventcausality, realinput/IME/AX/environment/matchedperformance/fullparity remainunproved. Existingfoldertitlesstayunchanged; do not automate realapporganization to obtain a newname screenshot. User-directedworkresumed; actualgoalAPIstillreportsblocked and hasnoresume transition, so do not fabricateACTIVE/complete or editgoalstatefiles. No newblocked audit is inherited from the clearedlock.

## 2026-10-26 — one-trial grouping and non-Group name accepted

The user replied **“可以，名字不叫group”** to the requested single first-attempt app-on-app grouping trial. This closes only **USER_ACCEPTED_ONE_TRIAL** for that operation and **USER_CONFIRMED** that its newly created folder is not called Group. The exact category/pair naming semantics and restart durability were not separately tested.

On the exact PointerRelease artifact `8335c19bcf9caf977b511fd80598493a054df80aed433ec0877e0aa21cbdf06d`, owned PID91801, the consumed neutral report has enabled=1/total=176, one B1 down/up,40 moves, and one anonymous commit; displayed rejection/cancellation/denial counters are zero. The counters contain no target or mutation type. Ordinary clicked=0, so this gesture does not witness callback reentrancy or establish the prior intermittent physical drag cause. Window counts include menu access.

Evidence: `.build/verification/20261025/pointer-release-ownership/` `human-accepted-grouping-r1.json`, `post-human-grouping-pointer-r1.json` and `profile-after-human-grouping-r1.json`. The user's one expected layout-file change is authoritative, not a failed preservation check. The agent did not restore the pre-human snapshot, organize or launch real apps, reset counters, quit/restart, rebuild, or modify source. The diagnostic report was closed normally; the current main window/wallpaper READY was observed, and all five post-human profile hashes/modes were then verified unchanged. All610 frozen source inputs and the executable still match; prior114/0 focused,3781/0 full and bounded SOURCE PASS remain existing evidence, not fresh executions.

This dated section supersedes only earlier pending human acceptance of this one grouping/name operation. Intermittent physical drag causality, exact live catalog failure categories, restart durability of this new grouping and whole-product parity remain unproved. No repeated human test is needed for the closed trial. Preserve the latest arrangement and consume any genuinely new failure before reset or restart.
