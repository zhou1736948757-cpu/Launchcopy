# Dedicated real-four-finger validation — checkpoint

Date:2026-10-22. Scope explicitly authorized by user. Full parity goal remains active/unproven.

## Ownership / implementation
Main integrated the native AppKit host, runtime capability policy, restricted controls and launcher presentation. Popper implemented strict startup entry/tests; Cicero implemented distinct packaging/verifier/tests. Both workers closed. James is independent read-only source reviewer; no independent live UI or physical acceptance inferred. Max3 including Main; no old workflow reactivation.

Spec: Docs/REAL_FOUR_FINGER_VALIDATION_SPEC_2026-10-22.md. Distinct com.launchcopy.gesture-validation / LaunchcopyGestureValidationEntry version1+profile; no CLI toggle. Existing com.launchcopy.ui-test fake-only behavior retained. Dedicated runtime uses default fake unrelated global adapters and exactlyone lazy existing MultitouchSupportBackend; same recognizer/readiness/host. Initial/every-applied activation preferences normalized. No application launches/removal/Finder execution, activity coordinator or custom source coordinator; readonly settings reflect that. Ordinary non-topmost window has explicit foreground Show only for dedicated mode, unlike background UI mode. No extra monitor/permission/settings/sign/install.

## Review / repairs
Initial static review found2P2 issues: packaging missed Library/LaunchActivity path guards; details advertised blocked external actions. Both repaired with negative7directory fixtures and owner/view/gallery capability propagation, while retaining host execution guards. Added host refusal, native controls/relabel, gallery/detail and unshown window-ordering tests. Final review pending. Test-only compile mistakes (plan properties vsoptional fields; source enum spelling) corrected; no product causal bug claimed from those.

## Verification checkpoints
Focused r2:52/0. Initial full3574/0 (before review repairs). Focused r3:72/0; full r2:3577/0 (before foreground-window correction). Python13/0 with expanded seven-path subcases. Focused r5:42/0 including unchanged background-window behavior and dedicated no-actual-activation ordering test. Final manifest r3:581inputs; final full/debug/release/package running serial in session89829. Do not call prior checkpoints final. Existing warnings are not claimed zero.

R1 candidate daf04adccd8025d3a2ec8327ddb2b14ac2939f41021f2480b9c4d9a7e949f05a was never launched; superseded because background-only Show is not a valid physical gesture host. Final target `.build/candidates/real-four-finger-validation-rc-20261022-r2/LaunchcopyGestureValidation.app`. New private physical profile will contain freshly seeded owned synthetic metadata/icons, no executable fixtures/formal data or copied human layout. Original d7302a18candidate/PID96873/profile249files untouched so far.

## Next
Require final stable tests/package/source review, seed bounded own fixtures, pure startup-check and resource hashes, then native normal Quit oldownedinstance/exactabsence and launch distinct candidate. Verify title/backendReady/defaultoutwardOFF/restrictedservices, normal Quit/reopen isolation. Actual physical trackpad packet requires the user; no automation claim. Unexpected OSpermission requires action-time approval. Fullscreen/multidisplay/realIME/VoiceOver/physicalperformance/120Hz remain separate.


## Final stable candidate — native pending lock
# Dedicated real-four-finger validation candidate

Date:2026-10-22. Status: SOURCE_AND_ARTIFACT_READY_NATIVE_PENDING_LOCK. Environment authorized; physical feature acceptance remains pending. Full parity objective remains active/unproven.

## Delivered boundary
Separate reserved bundle `com.launchcopy.gesture-validation`, exact version1/profile metadata, no CLI/backend escape hatch in the existing fake-only UI entry. Candidate-local independent preferences/catalog/layout; no formal data imported. Exactlyone lazy existing real touch backend only through the dedicated composition; other global adapters fake, no hotcorner/shortcut/login/history activation. Launch/removal/Finder unavailable in host and Library controls, no source expansion coordinator/activity coordinator. Normal titled/non-topmost/nonfullscreen window has foreground Show for meaningful physical testing; original UI-test path still background/noactivation. No recognition/calibration/accepted paging parameters changed.

Spec: `Docs/REAL_FOUR_FINGER_VALIDATION_SPEC_2026-10-22.md`. Independent review: `Workflow/results/REAL_GESTURE_VALIDATION_SOURCE_REVIEW_2026-10-22.md` (SOURCE_ACCEPT_STATIC_ONLY, not GUI/physical review). Both2P2 findings repaired; final reviewer no actionable findings. All agents closed.

## Final stable verification
- Final full XCTest **3578/0** (3550baseline+28new methods), `full-r3.log`.
- Focused final ordering/entry/runtime42/0; earlier focused expanded Library72/0. These overlap and are not additive.
- Python verifier13/0, including7directory file/link subcases (not13+subcase testcount).
- Debug build and actualRelease/package exit0. Localization3languages×367requiredkeys/signatures; packaged resource hashes match. Existing warning history is not claimed zero.
- Frozen581product inputs `source-inputs-r3.json`, unchanged after final verification. `git diff --check` passes.
- Packaged pure startup-check exit0/isolationtrue/windowedtrue/folderLabtrue; profileoverride/fullscreen/help and headlesssmoke/perf rejectedexit2 before applicationstartup. No productAppKit/provider runtime inferred from these checks.

Candidate:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/real-four-finger-validation-rc-20261022-r2/LaunchcopyGestureValidation.app`

Executable SHA256:
`5ccd148c39ab529fe97460099ef767b18da90bee5dcdce9b3275dc9bcb5dba23`

R1 daf04adc was never launched and remains preserved/superseded (foreground validation-host correction). Nothing installed/signed/published; no git commit/reset/clean.

## Data / native status
Original fake-only d7302a18candidate and249ownedfiles/modes remain intact; latest human layout hash `fc98962dbc55b8195d48430b67d892d9a44ff9ccffb3a37aebc61415f7e5a9f5`. New physical profile seeded with80owned synthetic metadata/icon bundles (160files), **no executable fixtures and no copied human layout**, no LaunchActivity directory. Fresh layout remains empty before real startup and is assembled by the existing folderLab. Newprofile does not overwrite or re-seed the original.

Native CUA at handover returned Mac locked. No normal Quit of originalinstance or launch of dedicatedcandidate attempted; do not claim backendReady, actualforegroundShow, Hide, physicalgesture, sleep/wake, calibration or GUI acceptance. User asked once to manually unlock; no shell/UI workaround or forced termination. Currentlockdoesnot justify marking fullgoalblocked: substantial source/artifact progress occurred this turn.

## Resume after unlock
1. Verify originalownedPID/executable, normalQuit through nativeUI, exactabsence; never query old binding after Quit. Preserve originalprofile hashes/modes.
2. Launch exact r2 candidate via nativeCUA; verify real-validation title/ordinarywindow/backendReady and parentON/outwardOFF. Check restricted controls/historyunavailable and ownsynthetic catalog. Unexpectedpermissions require explicit action-time user confirmation.
3. NormalQuit/reopen dedicatedinstance to verify isolation/resource lifetime; no raw touch/private device information persisted.
4. Enable optionaloutward only in dedicatedprofile via nativeSettings, closeSettings and leaveidle. Ask user physicalpacket: outwardHide notQuit, release/inwardShow infront, folderbusy rejects. OFF/heldcontact/reversal/IME/modal and other unperformed checks stay explicitly pending until actual evidence.
5. Save exactnative/PID/fixtureintegrity receipts and updated acceptance. Do not equate mock/frozen/test/static gates with physicalPASS.

Raw bounded evidence under `.build/verification/20261022/gesture-validation/`. Other paritygates (realIME/spokenVoiceOver/physicalperformance/120Hz/multidisplay and reservedmajorvariants) remain separate; no blanketcleanroom/legalclearance or wholeparity completion claimed.


## Automatic continuation 1 — native lock revalidated
Date:2026-10-22. Previous goal turn: PROGRESS (dedicated source/3578tests/artifact completed). This continuation: NO_PROGRESS, not a verified wait. Native CUA freshly confirms Mac locked; no live build/test/agent handle remains to wait on. Reviewed controlling requirement queue and dated supersessions: outstanding actionable gates require native/physical/hardware evidence; no specific missing approved implementation or new reproducible defect is established. Reserved variants are not silently expanded. No repeated source audit, rebuild, artificial code change, screenshot or security/UI workaround is warranted. Original app not quit, dedicated app/backend not started, original fixtures preserved. Manual unlock already requested once. Same lock condition observed in two consecutive goal turns including delivery; blocked threshold not yet met. Goal remains active/unproven; next safe action is native handover after unlock.


## Automatic continuation 2 — blocked audit threshold satisfied
Date:2026-10-22. Previous continuation: NO_PROGRESS, not a verified wait. Fresh native CUA again returns Mac locked. This is the same native/physical-access blocker across three consecutive goal turns (original implementation delivery plus two automatic continuations). No live build/test/agent job remains; final581input manifest and5ccd148c candidate still match. Existing requirement reconciliation identifies remaining native/human/device/hardware gates, not a justified unimplemented approved consumer or reproducible new defect. Implementation, final3578/0, package and independent static review were completed before this impasse. Rebuilding, restating plans, silently expanding reserved features or bypassing lock would not advance the objective.

Blocked audit passes: request goal status blocked, not complete or paused. Await external-state change/manual unlock and user resume. Original app not quit; dedicated real backend not activated; original data/candidate preserved. Resume from REAL_FOUR_FINGER_VALIDATION_RESULTS_2026-10-22.md native handover steps. Full objective remains unchanged and unproven. No duplicate unlock request, forced termination, OS setting change or shell UI workaround.


## User-unlocked native handover — 2026-10-22
User explicitly unlocked/resumed. Previous lock is cleared; prior blocked checkpoint is historical. No code/build/test delta since final581inputs/3578green. OriginalownedPID96873 normallyQuitviaitsmenu, exactabsence and249originalfiles/modes verified. Dedicated5ccd148c candidate native launchedPID46500; ordinaryreal-validationtitle, syntheticGroup1(35)/Group2(10), parentON/outwardOFF, realbackendREADY and shortcut/corner/loginOFF+disabled observed. Sourcescontrolsdisabled/historycheckboxOFF+disabled observed; no permissionprompt. NormaldedicatedQuitviaCmdQ, exactPIDabsence verified; native reopened asPID47180, sameparentON/outwardOFF/backendREADY. This verifies actualrestart/readiness, not physicalrecognition or observer/session behavior.

Optionaloutward enabled only through dedicatedSettings; nativeApplyack observed, Settingsclosed/queryempty/folderclosed/mainpage. Titlebar clicked toactivate ordinarywindow. Transientscreenshot2000×1400pixels; wallpaper stillLOADING/temporaryblack, and ownednonexecutablefixtures showprohibitoryoverlays. This dedicatedhostisforgesturefunction only; no currentvisual/wallpaper/physics/performance acceptance. No saved screenshots or rawtouch/device/privateapp data. Original249files/modes andnew160metadata/iconfiles/modes preserved; no LaunchActivitydirectory. All581sourceinputs/executablematch. Newphysicalgesture gatepending actualuser; source/static/mock/nativeREADY cannot establishit. See native-first-start.json, original-normal-quit.json, dedicated-first-normal-quit.json and native-ready-for-physical.json under `.build/verification/20261022/gesture-validation/`. Allagents/jobsclosed; dedicatedinstance intentionallyleft running for user input.

Next: realtouchpad outwardHide(notQuit), fullrelease then inwardShowinfront, folderbusyoutwardreject. OFF/heldcontact/reversal/IME/modal/Library andother unperformed physicalcases remainpending. No newdefect or fullparitycompletion claimed.
