# First pointer drag repair — verification in progress

## Confirmed defect
The production owner canceled a real ordinary pointer transaction on no-change pager-idle and non-busy catalog callbacks. This can consume the first held attempt while a later attempt works. Reproduced deterministically for main/open-folder pre-threshold press and thresholded drag, plus actual main-page settle and production non-busy callback. This is not a recording of the user's real input ordering; sole physical causality remains unproven.

## Narrow repair
Only AppDelegate.applyPendingAtIdleBoundary changed: preserve an active controller transaction when provider.hasPendingPresentationChanges is false, instead of requiring collapsed-member visual state. No paging engine, native mouse synthesis, four-finger service, frame parameters, data schema or first-mouse policy changes. Actual pending update and click-only search/blank fallback invalidation remain.

## Tests
- regression-before.log: 7 executed /8 assertion failures;4new preservation cases red,2real-pending negatives and1existing prefix-selected control pass.
- production-callback-before.log: 3 executed /6 assertion failures using actual main settle and installed non-busy callbacks. Original production block restored only during this bounded red run and fixed bytes restored in finally; no native candidate touched.
- focused-r1.log: 89/0.
- focused-r2.log: 92/0 including actual settle, before/after threshold, native main window delivery and folder owner, plus existing search/escape/resign/move-out suites.
- full-r1.log: running; no final claim yet.

## Inputs and review
595inputs frozen in .build/verification/20261024/first-pointer-drag/source-inputs-r1.json; exactly2source/testdeltas versus delivered move-out R2 manifest. Readonly Beauvoir causal-path audit complete and closed. Independent Banach bounded review pending. No physical PASS or full goal completion.

## Delivery
Current running preview remains39718 MoveOutFixR2 until full gates. Preserve profile and library setting. New artifact will be unique sibling with same explicit integrated profile namespace; old instance normal Quit only after review/tests/package gates.

## Full verification checkpoint
Full XCTest3662/0 (78.383s execution), focused92/0 and targeted whitespace clean on frozen595inputs/2deltas. Independent Banach review still pending; Debug/Release package job running. No claim of physical root-cause closure.

## Build / independent gate
Debug and strict Release package passed; packaged resources3languages×367keys. SHA03b28185ed97685f114d41451f5d1ffdb8c41febba89ede22b05a298e2a9b817, unique LaunchcopyPreviewFirstDragFix.app sibling. Banach independent bounded sourcePASS, no P1/P2; reviewer did not rerun/read tests, so no independent execution claim. Both sidecars now closed. Source595/2deltas, existing5profilefilehashes/modes and canonicalmanifest still exact. Native handover authorized by prior user instructions, next action normal Quit exact39718 then open new sibling.

## Native handover wait
CUA explicitly reported Mac locked during read-only inspection of exact old39718 app, before any Quit. No new app launch or old Quit occurred. Process recheck confirms oldR2stillpresent. New first-pointer candidate is fully packaged/automatically checked but NOT RUNNING; neither native nor physical acceptance claimed. Unlock question sent once. Next executable action after user unlock: fresh exactPID/path check, normal Quit old owned instance, verify accepted profile files remain; launch exact LaunchcopyPreviewFirstDragFix.app, confirm newPID/hash and main/wallpaper/LibraryON, then user first-drag check. Overall goal remains incomplete; no source work blocked by uncertainty incorrectly declared complete.

## Locked-desktop continuation / test fidelity
Previous turn was concrete progress (production defect reproduced/fixed, full suite/package/review completed), not completion of physical acceptance or full goal. Fresh CUA recheck again reports locked; old39718 exact process remains. While waiting, strengthened first-pointer tests to assert complete expected destination order on main, unchanged main order for folder-internal reorder, and exact cross-page insertion rather than only commit count. Production source unchanged; prior3662/0 remains prior test-revision evidence until fresh focused/full runs finish. No native action/new launch or repeated unlock question.

## Exact destination assertions verified
Test-only refinement passes focusedR3 92/0 and finalfullR2 3662/0 (71.898s execution). Main and folder complete destination-order assertions and exact cross-page insertion now verified. source-inputs-r2.json595inputs differs from reviewed/packagedR1 only in the existing test file; all production/package bytes are identical, so no needless rebuild/repack/relaunch or renewed independent-review claim. Current binary hash03b28185… and canonical manifest reverified. Independent bounded production reviewR1 remains historical/current-production evidence, not a new review of added assertions.

Final CUA recheck still explicitly locked. Old39718present, no Quit, no new launch. Receipt handover-waiting-unlock-r2.json supersedes earlier wait receipt. Next action remains user manual unlock, then exact owned normal Quit/profile preservation/new sibling launch and physical first-drag validation. No repeated unlock prompt; full original goal remains unproven.

## Blocked audit — third consecutive handover-lock turn
Fresh CUA explicitly reports locked again; exact owned39718oldR2stillpresent, FirstDragFix binary03b28185… and all595current inputs reverified. No native Quit/launch occurred. Previous turn was progress (exact destination assertions and fullR2 3662/0), not live-process waiting; all build/test/agent jobs are terminal. The same actual desktop-lock condition prevented the required native handover in the original repair turn and both subsequent goal continuations.

Re-read latest closeout audit and historical full parity review: no additional already-approved source defect/work item is established. Current pending work requires native/user/device evidence; reserved uninstall/recommendation/extra-language/etc branches are not silently authorized implementation tasks. OutwardHide is superseded by the later approved/implemented feature, not missing backlog. No further rebuild, unchanged-test rerun, speculative feature work or repeated unlock prompt is justified. Overall full UI/function parity still not proved. Request goal status blocked after three repeated-lock turns; resume via user manual unlock and ordinary goal continuation.

## Manual unlock resolved / native handover complete
User clarified first drag also fails on main grid and explicitly confirmed manual unlock. Old owned39718normallyQuit via own menu; exactabsence verified. New ownedPID89871, `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/integrated-preview-rc-20261023-r1/LaunchcopyPreviewFirstDragFix.app`, SHA03b28185ed97685f114d41451f5d1ffdb8c41febba89ede22b05a298e2a9b817 verified. All5non-wallpaper profile file hashes/modes remain identical before oldQuit and after newstart; same candidate/integrated namespace retains arrangements/preferences without import/reset. Original canonicalmanifest exact; unique sidecar retained.

Native ordinary main window/wallpaperREADY/Librarymenuenabled observed; menu canceled, settingsclosed. No real-app launch/drag/grouping mutation by agent. FullR2 3662/0,focusedR3 92/0,595inputs stable; production/build/reviewR1 bytes unchanged by test-only exact-order refinements. Historical source-only reviewerPASS is not a new native/physical PASS. Prior desktop-lock blocker is resolved, but overall parity and actual first-three-finger acceptance remain unproved. User asked once to try first main drag without click prewarm, then first folder drag. Next action is handle actual result, not redundant build/static audit.

Authoritative currentreceipt `.build/verification/20261024/first-pointer-drag/final-native-ready-r1.json` supersedes wait/blocked receipts, which remain history.
