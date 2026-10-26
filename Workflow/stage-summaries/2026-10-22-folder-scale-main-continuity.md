# Folder scale / main reorder continuity —2026-10-22

## Objective and baseline
Human confirms correct folder reorder/no panel flash on c19a2f18 candidate (3440/0 source baseline). Separate reported main-page flash and tiny folder glyphs. Preserve dirty tree and latest human layout. See selected `Docs/FOLDER_SCALE_AND_MAIN_REORDER_CONTINUITY_SPEC_2026-10-22.md`.

## Ownership / concurrency
Main handles appearance/schema/localization/tests/docs and sole test/build/UI resource ownership. One worker handles renderer/page continuity and dedicated tests; disjoint write scopes. At most2active includingMain before review. Old workflow bypass remains.

## Gates
Implementation/tests/review/newcandidate/native acceptance pending. No new full parity, performance or release acceptance claim.

## Appearance implementation checkpoint
New5testmethodsonoriginalappearancefailed23assertions(RED), geometryalreadyfit80/96withoutpanelpolicychanges. Mainimplemented80fresh/factoryfolderdefault,32–96foldercontrol,appearanceschema4withstrict1/2/3legacy32–64validationandno-writeloads. Historicalschema1explicit48preserved. Existingexplicitpreferencesarenotoverwritten. Fourlocalizedcaptionresourcesupdated; keys/signaturesunchanged. Focusedtestsnowrunning; workerhandlesonlymainrendercontinuity. NoGUIhandover/newacceptanceyet.

## Focused appearance result
Focused R2:103XCTest/0failures. R1had4assertions from two obsolete contracts (schema1fixture must explicitly expect48rather than newfresh80; invalidfolderbound moved65→97). Corrected those expectations only; legacy loaded bytes/nil inheritance and newer-version guards remain tested. New extended geometry test passes80/96 at1000×700,700×500,520×420 with9/11/16fonts, no policycodechange. No physical scale acceptance yet.


## Bounded renderer delivery / limitations
Worker implemented per-page transaction-local ready-icon continuity, not skipped presentation updates. Only samecatalog/page/attachedhost/reusegeneration/ordinarymode/capacity/uniqueidentityset qualifies, including repeated refresh. Catalog/search/identityset/crosspage/hostrecycle/placeholder/teardown falls back to ordinary clear+async; this does not claim every possible main-page flash is eliminated. Correct new order/full tokens/generations and fresh asynchronous requests remain. No reference or pager/blur changes.

Appearance static review: Kepler SOURCE_ACCEPT_STATIC_ONLY; no writes/tests/UI. Worker Einstein closed after4files/10newtests. Combinedfocused121/0. Frozen565inputs/13code-testdeltafiles; Main running fullsuite; Kepler read-only renderer review now. New5appearance+10renderertestmethods, default expectations intentionally adjusted, no existing gate weakened.

## Full-suite contract adaptation
Full R1 completed 3455 tests with 29 failed assertions. All failures were stale appearance-contract expectations: old48 default, folder65 invalid bound, schema3/current4/future boundary, old32–64 caption, and adaptive capacity9 at540×500 (new80pt needs3×2=6). No renderer failure appeared. Main narrowly updated five existing test files, preserving legacy bytes, protection, safe deferral, title drafts and generation assertions. The owner fixture now explicitly assigns its loaded folder appearance; return-to-current uses the new80 default. The existing real drag→provider→surface→disk test additionally checks ready images by identity under fresh tokens immediately after commit, before suspension. Contract-focused R2:84/0.

Frozen R2 retains565 inputs; full R2, Debug and actual Release/package run serially. Kepler is independently inspecting renderer plus these test adaptations. The current running c19a2f18 app/profile remains untouched. No product source changed to make stale assertions pass.

## Verification blocker, not ignored
Full R2 completed 3455 tests with 2 failed assertions (1unexpected): the unchanged LibraryOwnerCardPreparationTests early-entry test timed out waiting for a fresh normal snapshot, then threw a deinit transition error. An isolated whole-class rerun reproduced the same2failures; do not label this a harmless CPU artifact. Appearance/main continuity remained green; no source drift. A bounded test-only worker now inspects synchronization in that gate/helper, with no production Library changes, no timeout enlargement/skips/sleeps, and no first-entry performance investigation. Main may prepare Debug/Release artifacts from stable product source but must not call the full gate passed until a complete successful rerun. All prior failed logs retained.

## Artifact preflight, not acceptance
Debug exit0, actual Release/package exit0 (102.54s product Release build), native isolated entry accepted and365requiredkeys/signatures×3languages verified from packaged resources. New candidate `folder-scale-main-continuity-rc-20261022-r1/LaunchcopyUITest.app`, SHA d9f3ab2ffe45c78627589938dc82d413a69f644f7c7a9a56e834b1e69d4c7287, remains unlaunched/uninstalled/unsigned pending full-suite gate. Product source is frozen; subsequent test-only corrections do not alter its executable. Independent renderer/appearance SOURCE_ACCEPT_STATIC_ONLY; optional test-vacuity gap repaired by fixed expected count/iteration and unwrapping images, narrow re-review pending.

## Test-only repair and authoritative rerun
Gibbs proved a possible synchronization flaw in the unchanged Library test helper and changed only its pending-continuation/FIFO delivery contract (plus an English evidence note). The old helper could deliver canceledG1, correctly rejected by production, then leave successorG2 unserved. Exact failed-run ordering and deinit diagnostic cause remain unproved. All test bodies, canceled-request delivery and3second limit stay unchanged. Worker closed. Targeted Library10+Drag17=27/0 passed. Final R3 freeze:565 inputs/19 deltas, manifest200f00cfa498890bc678d4255c9029f4b393444187e1ef14538bda375c348f12. Product byte hashes unchanged since successful Debug/Release/package; Main running complete R3 suite. Kepler performs final read-only narrow test-repair review.

## Final source/build gate
Full R3 completed3455/0 in185.112s; frozen565 inputs unchanged. Kepler final SOURCE_ACCEPT_STATIC_ONLY covers appearance/renderer plus both narrow test repairs, with19delta hashes checked and product hashes identical to the built candidate. All agents closed, all tests/builds terminal. Earlier failed runs remain in the evidence chronology. Proceed to a normal owned-isolated candidate handover; native and human scale/flash acceptance still pending.


## Final authoritative delivery — 2026-10-22
This supersedes the pending/unlaunched state above. Full R3 passed3455/0, Debug and actual Release/package passed;565frozen inputs/19deltas and executable hashes remain stable. Kepler final bounded SOURCE_ACCEPT_STATIC_ONLY includes both test repairs. All agents closed and all verification jobs terminal.

Old owned c19a2f18 app normally quit and exact absence was verified without querying it afterward. Only249known authored fixture files were copied to the new profile with copy2, preserving82helper executable modes and the newest human layout SHA1847c20d086e356283d669438f37ac0ef465b6d18999e1c468bcdc7b5efebc00. No preferences/history/wallpaper-cache import or old-profile mutation. New d9f3ab2f candidate is running, PID40758 at receipt, ordinary non-topmost isolated window.

Native Settings shows main80/folder80 and accurate32–96captions; changing only folder80→96 produced a saved acknowledgment while main stayed80, then folder restored80. Settings was closed; main query empty and wallpaper READY. No restart-save acceptance was obtained. Generated custom folder clicks did not reliably produce an observed open panel; AX was also truncated by the long main list. Do not infer a new product defect or call actual drag/folder visual acceptance passed. The final transient view shows main page, folder closed. No screenshot file was saved. Human should open the35member folder to assess scale, then perform a same-page outer reorder to assess flash.

Final receipt: `.build/verification/20261022/folder-scale-main-continuity/final-receipt.json`. Full original parity, all-flash elimination, cross-page continuity, scanout latency and complete300ms causality remain unclaimed. Formal data, OS/security, excluded references, Git history, signing, install and publication untouched.


## Bounded human acceptance — 2026-10-22
The human replied “完美了” to the delivered candidate comparison request for folder proportions and same-page main-grid dragging. Record both requested visual/interaction outcomes as HUMAN_ACCEPTED for the d9f3ab2f candidate. Preserve the accepted folder reorder/no-panel-flash behavior and the current sizing; no further tuning is requested. This supersedes the pending human gates above, not the earlier automation limitations.

This acknowledgment does not establish cross-page/member-change continuity, a controlled performance/scanout result, restart persistence,120Hz/multi-display coverage, independent live Reviewer acceptance, installation/publication, full product parity or the complete historical300ms cause. No source edits, test reruns, app restarts or formal-data changes were made to record this acceptance. The prior3455/0 build/test receipt remains historical evidence of this candidate, not a new test execution.
