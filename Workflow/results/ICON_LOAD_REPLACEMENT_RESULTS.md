# Icon Cancellation / Replacement Ownership — Results

Date: 2026-10-17
Status: **BOUNDED SOURCE REPAIR + TEST/BUILD/PACKAGE VERIFIED; NEW CANDIDATE NOT LAUNCHED**

## Confirmed problem and scope

During follow-up of the existing icon resource lifecycle, Main found a same-key cancellation race in the public pipeline's existing behavior. A native-style loader that ignores cancellation can return success after last-consumer cancellation or cancelAll removed its entry. Previously it could insert that old image into cache and `finish(key:)` could remove a replacement entry and deliver the old result to new consumers. This is independent of the unconfirmed main-grid capacity feature and is not a diagnosis of user-perceived frame hitches.

Actual RED: two controlled-loader test methods, six assertion failures. One old completion consumed a held replacement's consumer and made a later request hit old cache instead of merging. In the other order, fresh replacement completed first and cancelled old success then overwrote its cached image. Loader admission did not time out. Synthetic images and exact ordinal continuations were generated in memory, with no real apps, files, decoders or personal data. These reproduce the specific ownership defect, not its frequency in production.

## Repair

Only `Sources/AppIconPipeline/IconPipeline.swift` changed in production:
- Private per-load UUID captured/published with the in-flight entry under the existing lock.
- `finish` checks shutdown and exact current load identity before any removal, cache write/eviction accounting or consumer delivery selection, within one lock boundary.
- A removed/replaced load cannot finish a newer entry or poison its cache, whether or not it honors task cancellation.
- Existing uncancelled coalescing, surviving merged consumers, generation delivery, MainActor callbacks, image cap, LRU/count/cost/concurrency parameters and shutdown semantics remain. No new public API, frame work, UI/page-owned cancellation policy, source scan, persistence or physics change.

New file: `Tests/AppIconPipelineTests/IconPipelineReplacementTests.swift` (two methods). Test-loader cleanup was hardened with a closed flag to reject late registration after cleanup; this changed no production behavior. Final466 inputs relative prior465:464 unchanged, one production file changed, one test file added. Previous renderer-retirement repair remains included.

## Actual execution

| Gate | Result |
| --- | --- |
| Regression RED | 2methods /6 failed assertions |
| Focused r1 (before fixture cleanup hardening) | 45/0,4.911s |
| Final focused r2 | **45/0,4.792s** |
| Full r1 | **2814/0,53.047s** |
| Explicit Debug build | PASS,0.33s |
| Actual Release build | PASS,22.46s |
| Safe packaging/localization | PASS,290required keys/signatures ×3languages |
| Diff whitespace check | PASS |

Counts refer to actual XCTest, not the separate zero-test Swift Testing footer. Focused run includes existing pipeline merge/cancel/generation/limits/cache/shutdown and AppGridPageView regressions matched by its filter; no exhaustive interleaving claim. Raw evidence in `.build/verification/20261017/icon-load-replacement/`: `red.log`, `focused-r1.log`, `focused-r2.log`, `full-r1.log`, `debug-r1.log`, `package-r1.log`, `IconPipeline.before.txt`, `source-before.json`, `source-inputs-r1.json`, `candidate-r1.json`, `final-receipt.json`.

Carson independent bounded SOURCEPASS/no blocking findings. Reviewer inspected source hashes and Main's completed logs but executed no tests/build/UI, and certified no native/performance gate. Report: `Workflow/results/ICON_LOAD_REPLACEMENT_SOURCE_REVIEW.md`. Reviewer closed, execution job terminal; maxMain+reviewer2. All466 current input hashes/executable/profile payloads verified again at closeout.

## Exact candidate and current running app

New unsigned/uninstalled candidate:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/icon-load-replacement-rc-20261017-r1/LaunchcopyUITest.app`

Executable SHA-256:
`929e7616311a5f7af3dbcecad44cc7b2f341049cbf282ab7414e0159d613b3d1`

**NOT LAUNCHED.** Static native-entry metadata verification is not native execution. It has only its own seeded40Info-only fixture apps and synthetic layout/Library payloads; no wallpaper cache/locks/formal data copied. Current running test remains the previous renderer-retirement candidate39484896, PID49361 at closeout, unchanged. Its UI/earlier human folder observations do not establish runtime acceptance of the new binary. No restart, normal Quit or other UI action this slice, and no formal version replaced.

## Limits and remaining work

The regression tests use0.2s negative observation windows. Resuming an old continuation is not acknowledgement that its pipeline finish has run; a sufficiently delayed old result could escape a particular assertion window. Actual before/after discrimination is empirical; source locking/entry-identity reasoning supplies the ownership argument, not exhaustive scheduling coverage. The source review explicitly retains this limitation. No claim of force-stopping native decoding, a global pending-key/whole-memory bound, whole-process leak elimination, zero-waste cancelled loads or matched performance/hitch causality.

No captured personal pixels, reference source/assets, OS preferences/privacy changes, signing/install/distribution/commit/reset/clean/delete/kill or formal-data writes. New candidate native/physical tests remain pending, and main-grid capacity still requires the already sent specific product confirmation plus its engineering readability/anchor/resource gates. Other reserved product/IME/VoiceOver/hardware/OS decisions remain. Full objective stays ACTIVE and incomplete; this turn made concrete source correctness progress, not a wait/status restatement.

## Latest native handover:929e running; first-Escape/search issue OPEN — 2026-10-17

The preceding NOTLAUNCHED/old394running entries are historical snapshots, superseded by this actualCUA handover. Own39484896/PID49361 normallyquit viaobservedappmenu; exactoldabsence verified before latest929e7616 candidate launch. Newordinarynon-topmostwindow search36->singlematch->clear->originalgrid, folderglyphopen/page1, nextpage2 observed. However searchfieldeditor retainedfocus whilefolderopen: firstESC onlyrestoredrootfocus andfolderstayedopen (freshAX+screenshotconfirmed), secondESCclosed. Root/no-searchfocus control opens thencloses withoneESC. NOT allnativecontrolsPASS; newconcrete modalresponderbugneeds automatedRED/narrowrepair. No proof IconPipeline causedit; allinputsourceunchanged. Fullrepro/preliminarysource/guardrails Workflow/results/FOLDER_ESCAPE_AFTER_SEARCH_REPRO.md. This provides a concrete safe next maintenance task independentofpendingcapacityquestion.

Currentnew929einstanceleftmain/noquery/folderCLOSED; processin native-handover-r1.json. WallpaperLOADING/blackstillunresolved.466sourceinputs/newexe/isolatedlayout+Libraryhashes unchangedafterUI; no savedpersonalimage, formaldata/OS/reference/install/sign/kill/commit actions. Prior2814/0andboundedsourcePASS remain completed execution/source evidence, not physical/fullnativePASS. Allagents/buildjobs terminal. FullgoalACTIVE/incomplete; currentturn concrete source+nativePROGRESS, no blockedimpasse or renewedquestion. Next automatedownerresponderregression thenboundedfix/newcandidate; preserveexistinguserfolderacceptance withinreportedcontext.

