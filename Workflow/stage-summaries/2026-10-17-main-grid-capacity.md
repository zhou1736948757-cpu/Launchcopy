# Main Grid Capacity — Approved Implementation

Date:2026-10-17
Status:IMPLEMENTING

## Scope and authority
Human confirmed3–8 rows/columns, default5×7, independent adaptive folder, unchanged physics/order and safe-boundary queuing. Human also confirmed small-window readability protection without forced resize or silent capacity reduction. Source of truth: Docs/MAIN_GRID_CAPACITY_SPEC.md including dated approval. Full parity objective remains incomplete; new human decision resets prior blocked audit. No global frozen-file scope inferred from historical phase packets.

## Architecture and plan
1. Validated shape and pure stable-anchor relocation domain; separate future-protecting versioned file store with actual write receipts.
2. MainActor accepted-write coordinator, ordered writes/latest-success publication and real Quit drain.
3. Single owner transaction updates provider/search/refresh/Surface/renderer/keyboard/dots/drag bindings at idle; Library and folder defer.
4. Independent localized settings drafts/Apply/Defaults/status, readability guard and input suppression.
5. Focused/full suites, Debug/Release/package/localization, source hash freeze, independent bounded review and own native isolated test/restart. No claim of physical/120Hz/IME/VoiceOver or wallpaper repair.

## Concurrency and write ownership
Main + at most2 agents. First wave: domain/store Worker owns only new MainGridCapacity.swift in AppGridUI, new MainGridCapacityStore.swift in app, new matching tests and its result. Second bounded reader owns only a new readability/source planning report; no code/builds/UI. Main owns coordinator and integration, spec/plan/memory. Different write sets; all test/build execution by Main serially after stable edits. User waived Chief workflow. Broad dirty baseline preserved, hash snapshot under .build/verification/20261017/main-grid-capacity/source-before.json.

## Safety and evidence
No reference-code/assets access, OS preferences, formaldata, process kill, signing/install/publish, commit/reset/clean/delete. UI only CUA, own ordinary non-topmost isolated test instances and normalQuit. Old aac66f40/PID71120 retained until exact new-candidate handover. Existing2821green is baseline only, not new implementation evidence. Actual raw failures/corrections and reviewer findings must be retained.

## Open gates
Complete integrated default/endpoints, small viewport guard, same-product different-shape, anchor/deferredfocus/query, idle gating, stale callbacks, storage errors/future/recovery, Quit and restart; no new feature acceptance inferred from domain tests. Full goal can remain incomplete across stages.

## Foundation wave in progress
Main implemented separate accepted-write coordinator/tests plus optional row envelope in AppGridGeometry, outerpage/renderer metric propagation and independent readability policy/tests. All default behavior remains5×7; no settings controls, persistence factory, AppDelegate transaction, keyboard fan-out, Quit integration or nativecandidate is wired yet. FoundationWorker owns domain/store/tests, reader owns bounded geometry/readiness report. No tests/builds claimed until stable parallel edits finish. Existing aac66f40 app unchanged.

Goal tool after human reply still reports prior BLOCKED; API has no resume operation and update_goal must not be used to manufacture one. Work legitimately resumes on explicit human approval; do not claim tool status ACTIVE without verification. Earlier blocked counts are not reused.

## Integrated implementation checkpoint
Foundation worker Tesla completed/closed, reader Mencius completed/closed. Foundation Newton R1 SOURCE FAIL F1: ordinary fullgrid is not conservative for search widths because fewersearchrows increase shared spacing; Main added exact350×800/8×8/9items counterexample and probes eachpossibleoccupiedsearchrowcount(max8) plus fullordinary. Newton appended R2 SOURCE PASS; no executions, closed. Current production no per-frameconfigurationbinding/I/O or physics changes.

Settings Rawls implemented retained independentGridtab/scopedApplyDefaults/receiptfeedback/19typedkeys×3languages and19newtestmethods, no executions, closed. Main integrated ownstorefactory/acceptedowner/idlefanout/same-revisionreload/visibleidentityanchor/keyboardcolumns/search+windowinputguards/smallviewportmask/Libraryvisibility/terminationdrain+identitychecks/teardown. Main adds actualownerintegrationtests. User's oldtestapp aac66f40/PID71120 remainsunchanged; no newcandidate yet. Main+Jasonownerreviewer+Pascalsettingsreviewer atmost3, disjointreadreports; reviewersnoexecutions.

Actual execution history: foundationfocusedr1 42/0 (0.740s), guardfocusedr2 43/0 (0.145s). Integratedr1 compilefailure: optional identity-array helper mismatch, fixed by exhaustiveTopLevelEntry switch (bothcurrentcasesalwaysidentity), plus removedalways-successfulwindowcast. Integratedr2 72methods/36assertfailures inONEnewsettingsAXexpectation: nativeNSTextFieldAXvalue includes Itemsperpage prefix, correctedtestonly. Integratedr3 75methods/3assertfailures innewLibraryfixture: productioncaptureGrid needsvisiblewindow, fixtureneverordersone; suppliedexistingephemeralcaptureseam, no readinessbypass/productchange. Removedtwo authoredtestredundantStringcasts warnings. Integratedr4 75/0 (1.405s), thenMain addedexplicitvalidvisiblefocus gate+newoffpagefocusregression; r4isNOTnewhunkexecutionproof. Next stablecurrentfocus/full/build/package/localization/sourcefreeze/review/native.

Stillunproven: newnativeGridsettings/layout/AX/input/savequeued/restart/Quit/physicalperformance. >25ms, wallpaper, realIME/VoiceOver/120Hz remainindependent. All rawlogs retained under .build/verification/20261017/main-grid-capacity.

## Owner review repairs and final verification in progress

Jason's independent R1 review found two P2 issues, retained in the report: (1) readability masking cancelled the just-requested animated capacity anchor, losing its target/selection; (2) a global main-grid readability predicate incorrectly disabled readable folder menus. Main authored two regressions and reproduced both: **2 methods / 8 failed assertions**, including downstream assertions of the same failures.

Repair 1 orders readability/input revocation before keyboard relocation and the existing direct-page request. No Core/physics/tolerance changes. Repair 2 validates the actual originating cell at menu creation and action, including assignment post-callback validation: current visible main cells require readable outer grid and no open folder; current folder descendants require live open entry, matching membership, no inert/entrance/exit/collapsed visual. Shared root epoch checks remain. Both menu consumers have an optional owner predicate; default standalone behavior is unchanged.

Both new regressions passed. The first repair suite ran52 methods with5 failures, all from the pre-existing organization transaction fixture's detached synthetic cells. Its helper now mounts those synthetic cells under the real Surface, providing presentation origin rather than weakening production admission. Final broadened focus **116/0, 2.560s**. An added same-count/filtered/empty-query method preserves query text/generation/canonical catalog; owner-query run **16/0, 1.359s**. Settings Pascal independent bounded SOURCE PASS, closed; no native/build executions. Jason R2 repair review pending.

Resource census is synthetic, not a physical performance gate:640 generated records, current8×8 at an interior page =>7 live pages /448 cells; observed576 icon-request calls during the transaction, about0.108–0.113s including async receipt wait. This explicitly disproves treating448 slots as a transaction-wide request bound; it is not a queue/RSS/energy cap or production timing guarantee.

Earlier full R1 (before owner review repairs and three new methods) completed2893/0 in71.355s. Current482-input freeze `source-inputs-integrated-r2.json`; final full/Debug/Release/package session80691 is live and serial. No new source edits while it runs. Native old aac66f40 remains running; fresh CUA saw wallpaper state change from earlier loading to render-failed on that unchanged old binary, which is NOT a wallpaper cause fix. No OS or formal-data actions.

## Native counterexample after verified r1 package — 2026-10-17

Final full R3 **2899/0 (58.802s)**, Debug0.44s, actual Release/package R2 and309 required keys/signatures×3 languages passed. Package R1 failed because Main incorrectly set EXECUTABLE_NAME=LaunchcopyUITest (not a SwiftPM product); log retained, environment corrected without source change. Three independent bounded reviews passed: foundation R2, settings, owner R3; all agents closed.

Exact r1 candidate SHA2083e8958fcfcc0eef5ab812c1238566d8071d9a0ea39789137e5c9dc4d55da4 launched as PID4819 after normal old71120 Quit/exact absence. First getApp reported running-not-found transiently; read-only exact process check confirmed4819 live, binding same path then succeeded (no restart). Authored80 Info-onlyfixtures,46 outeritems,35-memberfolder; no copied cache/locks/formal data.

Native Chinese seven tabs fit. Default5×7 observed.3×3 Apply displays real saved/applied status, screenshot9cells and6page dots; dot2 jump works after actualwindowactivation. Folder still15/page,3pages; next page16–30 andoneESCclose observed. HOWEVER8×8 frommainpage2 reducedtotal to1 but grid persisted partlyoffleft/blankright; second fresh screenshot confirms sustained defect. Do NOT mark native r1 accepted or deliver as finished. Core page-count clamp uses soft boundary even at idle, leaving fractional visualOffset; owner needs existing idle normalization, NOT a Core/physics patch. New regression native-offset-red-r1.log in progress. Native checkpoint receipt native-r1-checkpoint.json. Smallviewport/restart/language/Library native controls notyetexecuted. Wallpaperloading/black remainsunresolved.

## Native idle-offset repair

The native r1 maximum-endpoint failure reproduced in a real owner/view regression: **1 method /2 failed assertions**, idle presentedOffset0.25 and actual page origin−300pt despite committedPage0. Main invokes existing Surface.cancel only when an admitted idle reconfiguration leaves presentedOffset unequal to its clamped committed page, after reload and before new anchor navigation. No Core, physics, parameters, frame source, public pager API or Reduce Motion toggle changed. Broadened R9 **133/0 (3.954s)**; actual page origin now asserted, not just logical page. Jason resumed for the bounded incremental R4 review, appended SOURCE PASS/current hashes, then closed. Existing R3 review and native r1 FAIL remain intact. New482-input R4 freeze; final full/Debug/package-r3 (intended r2 candidate) runs next. Old r1 remains running only as failed test evidence until normal own handover.

## Main-grid capacity delivered; latest isolated r2 running — 2026-10-17

Human approved3–8 rows/columns/default5columns×7rows AND small-window readability notice. No capacity decision remains pending. Implemented versioned actual-receipt store/coordinator/Quit drain, single safe owner transaction/identity anchor, retained localized Grid tab, draft/Defaults semantics, independent folder and small-viewport input/visibility guard. Three bounded independent SOURCE reviews PASS (foundationR2/settings/ownerR3+R4); earlier FAILs preserved. All482 frozen inputs match after native;20 modified+15new/zero deleted; PagingCore unchanged. Final focused133/0(3.954s), full2900/0(67.785s), Debug/actualRelease/package/309keys×3languages PASS.

R1 native FAIL was real:3×3page2→8×8onepage retained.25offset/−300ptorigin. Reproduced automatedRED1/2; owner uses existing idleSurface.cancel normalization, no Core/physics patch. R2 exact native sequence now aligned. Also observed minimumendpoint/dotjump, folder15/page/3pages, smallwindow notice/hiddengrid/search+settings retention/enlarge restore, EN/JA draft preservation, close-discard, same-r2 normalQuit/reopen nondefault8×8, then scopedDefaults draft-only beforeApply5×7. Layout+Library hashes unchanged.

Latest candidate `.build/candidates/main-grid-capacity-rc-20261017-r2/LaunchcopyUITest.app`, SHAadbd845caf32d0dd44f01d36cfbcde59f2c66d35b42e4630746a3044816c6cfc, RUNNING PID14086; unsigned/uninstalled, ordinary non-topmost window/default5×7/page1of2/noquery/folder+settingsclosed. OwnPID10117 normallyQuit/exactabsence before samecandidate restart. Fixture80 Info-only bundles/noexecutables; not a realapp-launchgate. Fullresults Workflow/results/MAIN_GRID_CAPACITY_RESULTS.md; finalreceipt .build/verification/20261017/main-grid-capacity/native-handover-r2.json. Allagents/buildjobs terminal.

Wallpaperstillloading/black NOT_FIXED; >25mscausality/120Hz/multidisplay/realIME/spokenVoiceOver/offscreenAX/physicalperformance/energy remain distinct. Newcontrols await humanacceptance; fullparity incomplete. Goaltool oldBLOCKED cannot be agent-resumed; do not claim ACTIVE/complete or recycle oldauditcounts. No reference/OS/formaldata/install/sign/kill/commit/reset/clean actions; historical documents below are superseded where contradictory, not erased.

### Final stage boundary
Implementation/build/source-review and the bounded native matrix are closed with the exact r2 receipt. Human acceptance is not inferred. Earlier Status:IMPLEMENTING, livejob, pendingreview, notyetnative and r1 failure sections are chronological snapshots. No jobs remain live. Next executable action is human experience in Settings→Grid, or a separately confirmed branch/concrete defect; whole product remains incomplete.
