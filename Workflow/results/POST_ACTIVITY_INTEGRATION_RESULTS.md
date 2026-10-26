# Post-activity integration results

Date: 2026-10-18
Status: automated/build/package/source-review and bounded ordinary-input native smoke passed; physical IME and full parity unverified.

## Native localization
Exact previous r3 SHA310b61f2: English and Japanese Library activity-settings heading, long privacy explanation, checkbox, status and Clear fit the actual500pt-wide settings window. FollowSystem restored; no history added or collection enabled. Native settings window is non-resizable; no compact-window claim. Details native-locales-r1.json.

## Main-search composition defect
Read-only Poincare audit identified missing marked-text admission guard. Main reproduced on the actual undisplayed NSSearchField editor: marked Escape clears text/query; marked Return and Down resign editor and transfer grid focus, losing composition. Actual first run5methods/26assertionfailures on3methods in0.980s. Tab and normal post-unmark Return controls passed before repair. This is synthetic delegate delivery, not proof that a particular real input method emits that command sequence.

One early hasMarkedText check now returnsfalse, leaving command handling to AppKit/input method. No proactive commit/unmark, filtering, query change, storage, physics or alternate launch route. Five new regression methods assert marked/selected ranges, draft, query generation/results, focus and no exit/launch side effects; normal Return after unmark still selects first result without launch. Combined focused42/0 in3.166s.

## Scope and verification
Frozen501inputs: exactly one changed existing production file AppSearchController.swift and one new test AppSearchCompositionCommandTests.swift versus500baseline. Existing dirty work and prior3033baseline preserved. Full suite/Debug/actualRelease/package running serially under Main; independent bounded source reviewer Fermat running separately without file writes/build/UI. No completion inferred until receipts. No new candidate launched; previous isolated r3 remains running in ordinary mode.

## Outstanding boundaries
RealChinese/JapaneseIME, spokenVoiceOver, matched physical60/120Hz/energy/RSS, wallpaper intermittent causality and full parity remain distinct. No formal data/install/sign/kill/commit/reference source/assets/OS settings actions.

## Independent review
Fermat boundedSOURCEPASS: exact501input scope confirmed, only earlymarked-text guard/comment plus newtest; removing hunk in memory reproduces old control hash. All command effects remain after guard; false leaves native editor/IME handling. Tests use real undisplayed editor and meaningful marked range/query/focus/callback invariants; no physical IME claim. No reviewer source changes/tests/build/UI. Reviewer closed. Current own81fixture seed created for unique nextcandidate using only authored metadata/binary/layout/capacity, no old preferences/history/cache/locks. Serial final job still live; no native newcandidateclaim.

## Full test and Debug results / packaging invocation correction
Full-r1 actually3038tests/0failures,77.267s; Debug-r1PASS0.37s. Serial shell exit1 was packaging invocation only: Main mistakenly set EXECUTABLE_NAME=LaunchcopyUITest (no such SwiftPM product), retained package-r1.log. No artifact was produced/launched. Script correctly uses PRODUCT_NAME for bundle executable and default PagingPrototypeApp for SwiftPM; rerun packaging only without that incorrect override, same unique still-absentapp destination, logpackage-r2. No sourcechange/retestneeded for command error.

## Main-search composition repair delivered — 2026-10-18

Concrete progress toward the full objective: Poincare current-scope audit found a main-search delegate composition gap; Main reproduced marked Escape/Return/Down losing draft/query/focus in actual undisplayed AppKit field editors (5 tests, 3 failed methods, 26 assertion failures). Added only an early hasMarkedText returnfalse, matching the existing Library rule. Ordinary text behavior remains unchanged. Five new tests preserve marked/selected ranges, draft, query/generation/results, focus and no launch/exit effects, with Tab and post-unmark Return controls. This is delegate-level synthetic composition evidence, NOT real Chinese/Japanese IME acceptance.

Final focused42/0(3.166s), full3038/0(77.267s), Debug0.37s, actualRelease17.01s/package347keys×3languages and reserved native entry PASS. Fermat boundedSOURCEPASS, all agents/jobs closed. First package invocation used a wrong SwiftPM product override and failed before artifact creation; retained package-r1.log. Corrected invocation package-r2.log succeeded without source/test changes. 501 frozen inputs match after native; exactly1existingproductionfile+1newtest versus500baseline; PagingCore/physics unchanged.

Latest unsigned/uninstalled isolated candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/search-composition-rc-20261018-r1/LaunchcopyUITest.app`, SHA `bcf43c54566300767429a46bd471eeec113d82a3799ee0cf29c2f4eceb25b872`, RUNNING (native-handover-r1.json process receipt). Previous own activityr3 normallyQuit and exact executable absence checked before new native open. Native plainLatin search/firstReturnselect-without-launch/CmdF/Down/twoEscape priorities observed. User appearance restored28.40063010899183/54/12/namesON/6×5; Library/tracking remain defaultOFF, no activity or Library preference file. Only authored81app fixture/layout/capacity seeded; no formal data/preferences/history/cache/locks copied. Main window ordinary non-topmost/noquery/folderclosed. Newrun wallpaper stillloading/black, NOT_FIXED.

English and Japanese activity-settings new controls/privacy/status/Clear fit the preceding exact310b61f2 native500pt window; FollowSystem restored. Settings window is not resizable, so no smaller-native-window PASS fabricated. RealIME/spokenVoiceOver/matchedphysical60/120Hz/energyRSS/multidisplay/originalfolder-scroll+wallpapercausality/fullparity remain separate and incomplete. No install/sign/publish/commit/reset/clean/reference/OS/security/signal actions. Next continue actual unclosed non-destructive acceptance or reproduce a concrete approved defect, not reserved features or repeated closed tests. Full goal unachieved; previous/current goal turns are concretePROGRESS, no inheritedblockedcount.

Report: `Workflow/results/POST_ACTIVITY_INTEGRATION_RESULTS.md`; receipts: `.build/verification/20261018/post-activity-integration/`.
