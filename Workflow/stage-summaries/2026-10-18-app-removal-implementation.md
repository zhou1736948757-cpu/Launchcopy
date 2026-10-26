# App removal implementation

Date:2026-10-18
Status:CODE_TEST_BUILD_PACKAGE_AND_BOUNDED_SOURCE_REVIEW_PASS; NATIVE_PENDING_MANUAL_UNLOCK

## Approved contract and baseline
Human explicitly approved Docs/APP_REMOVAL_PROPOSAL.md. One-app confirmed Move to Trash, local/current-user-owned/non-system/not-running/profile-bounded; no permanent deletion/privilege/forcequit/support cleanup. Current501frozeninputs/bcf43c54/3038green; large pre-existing dirtytree retained. Full parity incomplete. Actual human approval permits source progress after prior locked/nativeblocked state; fresh no-progress audit count resets to0. Do not claim goal tool ACTIVE via unsupported API.

## Plan and ownership
Main owns stateful removal coordinator, context/Library UI composition, lifecycle/refresh/Quit protection, integration tests, serialtest/build/package and sole nativeUI. Foundation worker owns new eligibility/fileidentity/Trash adapter and its newtests only. Localization worker owns new typed removalkeys and localization resources/accessors/probe/contracts/tests only. Two disjoint workers plus Main =3active; no worker test/build/UI/process operations. Workers close before independent review wave. Main integrates stable boundaries, reproduces failures instead of weakening guards; review final source then fix/reverify.

## Performance and data baseline
No added frame callback work: only explicit-action admission performs inspection, with one in-flight transaction; filesystem andTrash operations off-main. Retain501baseline and current81authoredfixture/ordinarywindow/6×5settings; matched physical budgets unverified, not inferred fromunit timing. No raw identity/path/usage telemetry. Fileidentity checks and cooperative pathvalidation are not adversarial atomic filesystem protection.

## Acceptance
Eligibility rejects protected/self/running/nested/symlink/missing/stale/nonlocal/read-only/wrongprofile; Cancel noTrash; single-use/current-realm confirmations; actual receipts, failure/latecallbacks/Quit/defaultCancel; existingcatalogrefresh/dormantorganization; three-languagekeys/accessibility; nonzero focused/fulltests/Debug/Release/package/independentsource/nativecontrolledtrash+recovery gates. Nevertrash realuserapp inacceptance.

## Next
Dispatch disjoint foundation/localization workers. Main implement coordinator and UI hooks against agreed immutable inspection/receipt interfaces. Native gate may remainlocked; no OS/security workaround.

## Main integration checkpoint
Main coordinator now owns one inspect/confirm/reinspect/move transaction; Cancel revokes unaccepted intent without forgetting a still-live inspection, platform-admitted move retains actual receipt across hide, and bounded Quit waits or reports failure/timeout with explicit defaultCancel. Context retained bindings and Library immutable requests revalidate after modal/async work. Existing neutral inert feedback view now also accepts typed removal reasons; no secondwindow/material orframeformatting. Pending operations gate shared launch pipeline (including recognizer), context menus, language/appearance transitions and Quit; no alternatelaunch route. Main adds synthetic owner/presentation/notice tests without actualTrash. Localizationworker delivered14keys×3languages/361total andclosed, noexecutions. Foundationworker stillowns onlynewFileAccess+tests; compile/test onlyafterdelivery.

## Bounded integration review dispatch
Localizationworker closed. Foundationworker is finishing no-follow bounded Info.plist validation and its tests within disjoint newfiles. Main stable10file source/test slice frozen in `.build/verification/20261018/app-removal/main-slice-r1.json`; independent integration reviewer reads that stable slice only while foundation writes its own files. Effective3agentsincludingMain, no concurrentbuild/test/native. Main will not edit reviewedslice until concretefindings. This is a bounded integration source review, not finalfoundation/fullsource/native verification.

## First executed focused result
Actual focused-r1 compiled and executed122methods/2assertionfailures in6.877s. AllMain13coordinator/4presentation/2feedback and7localizationtests plus existingselectedchecks passed. Twofailures belong to onefoundation malformed-path test: trueNUL URL returnedchangedandreachedmetadata ratherthanunsafe-beforeprobe (noTrashcalled). Main isolated Foundationprobe confirms url.path rendersNULasliteral%00 whilepathComponentscontainsactualscalar0; traversalcomponentsremainvisible. Rootandfoundationreviewersnotified; stableinputsnotpatchedduringreview. This is notstagePASS; failedlog retained.

Bothworkersclosed. Twoindependentreviewers scopedMainRoot/coordination andFoundation/localization running (max3includingMain), reportonly/noexecution. No nativeTrash/appremoval hasbeenperformed; lockeddesktopdoesnotblocksource/testprogress.509integratedinputs/14modified+8new/zeroremoved vs501baselinefrozenr1.

## Review findings reproduced and repaired
Foundation DeweyR1 scopedSOURCEFAIL1P2 (decodedNUL path guard); locality361keys SOURCEPASS. Main fixedcomponentcontrol admission andaddedactualscalar/literalpercent regressions; focused-r2 actual124/0 in8.137s. Same reviewerR2 pending. Descartes integrationR1 SOURCEFAIL2: runningURLcasealias canmisssameapp; hide→show lateoutcome revivesoldUI. Main actual review-red-r1 executed3methods/5assertionfailures (2failedmethods),0.610s afterextractingunchangedmatcher andnoninvalidatingpresentationcounter; full-UI/APFSrealcase NOT claimed.

Repairs usefixedPOSIXcase-insensitive fullcanonicalpath match onlyforrunningrefusal (conservativeextra refusal oncase-sensitivevolumes), andhide/Quit/teardown invalidatesremovalpresentationgeneration withoutlosingactualreceipt/refresh/Quitprotection. CanonicalizingrunningURLs movedoffMain viaoneawaitedbackgroundquery; coordinator revalidatesintentaftereachasyncquery andretainsbusyworkonCancel toavoidaccumulation. Addedcancelledheldqueryregression. 511 integrated inputs frozen in source-integrated-r2.json; focused-r3 running. Originalwarnings inunchangedWallpaperBackdropControllerTests noted, nozerowarningclaim.

## Focused green and final serial job
Actualfocused-r3:128/0,9.555s on511inputs. FoundationDeweyR2 scopedSOURCEPASS closed decodedcontrol issue; localization361keys SOURCEPASS. Reviewerclosed; DescartesR2integrationreviewpending. Main serialfullsuite→Debug→actualRelease/package app-removal-rc-20261018-r1 nowlive, no concurrentSwiftjob/UI. Authoredown82app fixture seeded:80metadata-only+inertprobe+uniquelynameddisposablevalidAPPLbundle reusingonlyown6972probeexecutable. No cache/preferences/locks/historyimport; no actualTrash/nativeexecution. Anycandidatecompletionbeforefinalreviewisnotrelease/nativeacceptance.

## Safe app removal code verified and packaged; native pending — 2026-10-18

The human explicitly approved the bounded Move to Trash contract. Implementation adds context-menu and Library details actions with default-Cancel single-app confirmation; one off-main eligibility/receipt service, current binding/catalog/profile/owner/lifecycle checks, conservative running-app refusal, existing refresh/dormant organization and bounded Quit protection. No force quit, privilege, permanent delete, support-file cleanup or removal of formal apps during acceptance. It is not complete uninstall.

Final executed focused128/0(9.555s), full3095/0(109.343s), Debug0.58s, actualRelease61.86s and resourceprobe2.47s/package361keys×3languages/nativeentry/diffcheck PASS. Foundation/localization DeweyR2 boundedSOURCEPASS and integration DescartesR2 boundedSOURCEPASS; all agents/jobs closed. Preserve actual focusedR1 122/2assertfails (decoded NUL path guard) and reviewRED3methods/5assertfails (case-alias running match and hide/show late presentation). Repairs retain control/path guards plus legitimate percent filenames, fixed-POSIX conservative complete-path matching only for running refusal, off-main canonicalization with post-await validation/bounded cancellation, and hide-invalidated presentation epochs preserving actual receipts/refresh/Quit. No real APFS/native Trash claim from these regressions.

All511frozeninputs match after verification,14existingmodified+10new/zero removed versus501baseline; PagingCore and paging parameters unchanged. Original unchanged WallpaperBackdropControllerTests weak-variable warning is historical, not a new zero-warning claim.

New unsigned/uninstalled candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/app-removal-rc-20261018-r1/LaunchcopyUITest.app`, executable SHA256 `975db8309a82e316c53e5c4d8f0fab189ebe521af94e9575b5f9f41c1748dbb8`, NOT LAUNCHED. Old own bcf43c54/PID30428 retained. New own82app fixture includes uniquely named valid disposable APPL app using only independently authored inert6972probe executable; no preferences/history/cache/locks imported. Disposable bundle untouched; no activity/Library preference file created. Fresh post-package CUA stilllocked, so no oldQuit/newOpen/actualTrash/Finderrecovery attempted. One concise manual-unlock request pending; no workaround or duplicate material approval request.

Current goal turn is concretePROGRESS (approved implementation, actual failure reproduction/repairs/reviews/tests/package), not a live-job wait or completion. No old blocked audit count carries forward; goal tool historicalBLOCKED cannot be setACTIVE by this API. Full parity/physicalperformance/realIME/spokenVoiceOver/120Hz/multidisplay/wallpaper and original folder-scroll causality remain incomplete. No install/sign/notarize/publish/commit/reset/clean/OS/security/reference-tree actions.

Authoritative report: `Workflow/results/APP_REMOVAL_RESULTS.md`; stage `Workflow/stage-summaries/2026-10-18-app-removal-implementation.md`; `.build/verification/20261018/app-removal/final-receipt.json`. After actual unlock: normal old-own Quit/exactabsence, exactnewcandidate open, preserve current user appearance/6×5, verify Cancel and only the authored disposable app's real Trash/refresh/dormant state/Finder recovery, then handover. Native outcome is NOT PASS yet; no need rebuild unchanged511inputs.


## Current supersession: native removal paths exercised — 2026-10-19

Manual unlock allowed actual testing of unchanged `app-removal-rc-20261018-r1` (SHA `975db830…`,511 inputs still match). Grid Cancel/real own-fixture Trash/automatic catalog disappearance and rediscovery, Library-details Cancel, real-running-probe refusal, normal Quit/restart and layout/capacity byte retention were observed. No real user app was removed. **Finder Put Back was disabled**; recovery passed only using native Finder Copy followed by Move Item Here into the exact original directory. Do not claim one-click Put Back or full native coverage.

Full dated report: `Workflow/results/APP_REMOVAL_NATIVE_ACCEPTANCE_2026-10-19.md`; receipt: `.build/verification/20261019/app-removal/native-results-r1.json`. Historical NOT LAUNCHED/locked snapshots below are preserved but superseded only for these gates. Latest own test PID98940 is available; Library/trackingOFF, FollowSystem, namesON/icon54/font12/6×5; integer blur reload28. No source changes, rebuild, install, commit or full-goal completion. Physical performance/realIME/spokenVoiceOver/wallpaper and original folder-scroll causality remain incomplete.
