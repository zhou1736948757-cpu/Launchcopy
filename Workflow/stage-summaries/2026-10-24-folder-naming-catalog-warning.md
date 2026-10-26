# Folder naming and catalog warning — 2026-10-24

## Objective and current baseline
Implement the user's request for meaningful new-folder names and explain/correct the broad partial-load warning. Full LaunchBetter experience remains the goal; this is not a replacement definition of completion. The preceding goal turn was progress: new live drag evidence, a successful human first attempt and 58 owner regressions. Intermittent causality remains unresolved.

Current candidate is the unchanged isolated InlineRename preview, last confirmed PID 5996 / `ab2b343b…`. Current known source baseline is 599 inputs with one test-only delta since its packaged source. Existing dirty work and the latest human arrangement are authoritative.

## Specification and ownership
`Docs/FOLDER_NAMING_AND_CATALOG_WARNING_2026-10-24.md`. Main owns critical-path drag naming integration, AppDelegate, all localization and sole tests/build/package/native. Two independent workers may own only the new pure policy/test and the catalog outcome/adapter/tests respectively. No overlap, reference reads, native real-app mutation, or test/build contention. Unimplemented reentrant-release investigation is deferred behind this explicit feedback, not silently repaired or accepted as the physical cause.

## Evidence and next action
Source confirms hard-coded `Group N` and all scan issues summed together, including admitted missing-ID apps. Exact current live issue categories are not captured. No new implementation, independent review or physical acceptance yet. Next: red production grouping regression, bounded policy/severity implementation, then integrated verification.

## Provisional verification invalidation
`naming-before-r1.log` compiled while a catalog test input changed; Swift rejected the build with “input file ... was modified during the build.” Zero tests executed: **INVALID**, neither a naming red reproduction nor a pass. Main owns the coordination mistake. Await both worker final frozen-file checkpoints before rerunning; no production naming hook has been applied yet. Existing unrelated interruption-test Void-result warnings appeared; do not claim a zero-warning baseline.

## Integration and red/green checkpoint
Both workers returned frozen files and were closed before definitive verification. `naming-before-r2.log` executed **2 tests / 2 failures**, each showing actual production window grouping produced `Group 1` instead of the category or displayed-name suggestion. Transaction count, exact target-then-source members and single generation increment passed. The provisional build invalidation is retained separately.

Main integrated a side-effect-free title policy only after token/layout/catalog validation and actual release-target resolution, forwarded the literal title into the existing single mutation, and wired committed aliases/category preferences/displayed strings. No old-title migration, editor auto-open or extra commit. Category/pair/Unicode/collision policy and severity worker changes are integrated. `focused-r1.log` executed **146/0**,5.528s. One insertion negative control was strengthened to require an actual exact-order reorder rather than a conditional assertion; final focused/full verification follows on the frozen inputs.

Source freeze `source-inputs-r1.json` and delta list record the exact current known source/test/package inputs. Independent bounded source review may now run read-only while Main alone executes tests/builds; native replacement and physical grouping remain pending.

## Final focused freeze
Final focusedR2 executes **146/0**,5.154s, including the exact-order insertion control. All607inputs match `source-inputs-r1.json`;22deltas versus inherited599baseline,8new files and14existingfiles. FullsuiteR1 now running serially; independent Kierkegaard review is read-only against that frozen source. Both implementation workers are closed. No native replacement before automated/review gates.

## Full-suite R1 contract adaptation
FullR1 executed **3762 tests / 17 failed assertions** (72.946s). All failures matched independent old catalog text (15 assertions across retained status/AX/frame-consumer tests) and the explicit old367resource count (2 assertions); no implementation-path failure was found in that run. Updated exactly those literal expected translations and count369 in four existing test files. No assertions removed, no dynamic expectation substituted, no production source changed. Retain the failed full log; regenerate source freeze and rerun expanded focus/full before claiming green. Reviewer informed of the test-only delta.

## Correction: fallback API inconsistency found during adaptation
The preceding “all17 are old test literals” characterization was too broad. **Two of those assertions exposed an actual omitted production fallback**: AppGridUIState.accessibilityDescription still hard-coded the old English copy while the retained view used the updated typed key. AppGridStatusViewTests itself was not changed. Centralized the six-state static key mapping in AppGridUIState, reused it in AppGridStatusView, and made the fallback API read the same key's English fallback. This removes duplicate switch/string definitions without IO or frame formatting. The other15assertions are the three independent locale snapshots and two exact key-count contracts. Three test files changed, not four. All original assertions remain.

Frozen R2 retains607inputs and records the source/test delta explicitly; originalR1FAIL retained. Reviewer must inspect the two additional production files and finalR2 tests. Expanded focus and fullR2 required; no product fallback mismatch is waived.

## Expanded focused verification
`focused-r3.log` executes **176/0**,5.996s on unchanged R2source607inputs/27deltas. It includes status/AX/frame-consumer and independent localization contracts in addition to naming, actual window grouping and issue severity. FullR2 is now running serially; source reviewer continuing. No candidate replacement/native claim yet.

## Full R2 verification
FullR2 **3762/0**,85.620s execution, passes on exactR2freeze607inputs/27deltas. Expandedfocus176/0 remains current. Debug/Release strict package now runs serially into a unique same-profile sibling; original top-level candidate and localization manifests are byte-preserved/restored, with separate new sidecars. Independent bounded review and native replacement pending. No physical grouping/full-parity claim.

## Strict package R1 failure and R3 verification freeze — 2026-10-25
Debugbuild and actualReleaseproduct/probe compilation passed. Strict packageR1 rejected the candidate because both standalone localization verifiers still pinned the old367key schema. The rejected FolderNamesR1 artifact was never launched; no oldQuit occurred and both original top-level manifests were restored byte-exact in finally.

Updated only the two verifier programs to require exactly369unique keys and explicitly require both newfolderkeys, preserving the removal-key/signature/no-development-fallback checks. No validator bypass, production change or resource deletion. FrozenR3:607inputs/29deltas; only these two verification tools differ from fullR2's passing production/test inputs. Run final fullR3 and a unique FolderNamesR2 package with the corrected strict tools, then source review/native gates. Previous invalid/failed logs remain.

## Final full R3 — 2026-10-25
FinalfullR3 executes **3762/0**,86.780s, with the corrected strict verifier inputs included in the607input freeze. R2strict package is running into a fresh sibling; rejected R1 is retained and never launched. Source review remains pending. Native old5996 remains unchanged, report closed; latest neutral oldtrace retained and no active title/search/folder/transition observed at report time.

## Final verified delivery — 2026-10-25

- **Focused176/0; finalfullR3 3762/0 (86.780s).** Debug and actualRelease builds pass. Corrected strict R2 packaging passes: three languages,369requiredkeys/signatures; standalone resource-only smoke additionally verifies1107entries;12integrated-entry guard tests pass. Earlier invalid compile, naming RED, fullR1FAIL, fallback correction and strictR1rejection remain retained.
- Final source freezeR3:607inputs/29deltas, independently hash-checked by Kierkegaard. Bounded sourcePASS, no independent execution/native/physical claim. All agents and build/test jobs closed. An extra ad-hoc verifier invocation with a spurious profile argument was correctly rejected as invalid invocation; the documented one-argument command and strict packaged check passed. No entry guard was weakened.
- New owned **PID51878**, `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/integrated-preview-rc-20261023-r1/LaunchcopyPreviewFolderNamesR2.app`, executable SHA256 `4d6e9ccb2184b96726832da185332cd16b8cd8d5d1124e328d2bd44a59a1d13b`. Old5996 exited through its own normal Quit menu and exact absence was verified. Rejected R1 was never launched.
- Same explicit candidate/integrated profile namespace. All five latest non-wallpaper profile file hashes and modes match beforeQuit, afterQuit, afternewstart and after native checks. No reset/import/copy/migration; original candidate and localization manifests restored byte-exact, new R2 sidecars retained. Native main, wallpaperREADY, Library menu enabled, no Settings/report/menu left open.
- Native new warning text **部分应用来源或项目无法读取** remains visible. This proves the presented wording, not the exact live failure kind or that the old warning was merely soft. Real discovery errors are deliberately not suppressed. Compact status still occupies the lower-right caption region; retain this as a visual-layout follow-up rather than silently declaring all chrome polished.
- Previous pointer counters preserved before normal oldQuit. Fresh new-preview diagnostics explicitly enabled; report enabled=1,total=0 with searchfalse/canCommittrue/noeditor/nofolder/notransition/keyactive observed, then reportclosed. No new drag/launch/group/reorder by agent, no screenshots saved.

Authoritative receipt: `.build/verification/20261024/folder-naming-catalog-warning/final-native-ready-r2.json`. Physical new-folder suggestion/grouping and earlier intermittent pointer causality remain pending/unresolved; no full-parity or formal installation/signing/publishing/Git claim. User may use the new preview normally; existing generic titles intentionally remain unchanged and editable. If pointer failure recurs, preserve this process/counters before reset.

## 2026-10-26 — one-trial grouping and non-Group name accepted

The requested single first-attempt app-on-app grouping succeeded, and the user confirmed **“可以，名字不叫group”**. The current user-created folder/arrangement is preserved; no restart, rollback or additional test is requested. The consumed neutral report supports one anonymous committed B1 sequence, not naming accuracy or a diagnosis of the earlier intermittent drag issue. Exact current candidate/PID,610 source inputs and five post-human profile hashes/modes were verified unchanged; existing3781/0 full,114/0 focused and bounded SOURCE PASS were not rerun.

Authoritative closeout: `Workflow/results/POINTER_RELEASE_OWNERSHIP_2026-10-25.md`; receipt `.build/verification/20261025/pointer-release-ownership/` `human-accepted-grouping-r1.json`. This supersedes the pending-human grouping/name field only. Exact category/pair semantics, new-grouping restart durability, intermittent drag causality and full parity remain unproved. The current diagnostic dialog is closed, main/wallpaper READY, counters not reset, and owned PID91801 remains running.

## 2026-10-26 — category-only naming supersedes pair-name aesthetics
The user accepts the earlier first grouping/non-Group operation but rejects the generated name as awkward. Future app-on-app creation now uses the target's recognized displayed category, then source category, then localized neutral Apps / 应用 / アプリ; no name/alias concatenation or brand inference. Existing saved names/arrangement never migrate. This supersedes only older pair-name requirements and aesthetic-pending statements for the old policy, not the valid earlier grouping operation.

New ConciseNames e8b70c1a…/ownedPID26223 is now running in the same isolated profile after old91801 normalQuit/exactabsence. Fivecurrentprofilehashes/modes preserved, main/wallpaperREADY and reportclosed. Full3778/0/focused132/0,610input/sixdeltas, Debug-r2/actualRelease/strictpackage/resource/entry gates and bounded SOURCEPASS verified; initialwrapperoverlap/lockwait explicitly retained in the report. New human aesthetics and native new-title creation are not observed; intermittentdrag cause/livecatalogfailurecategories/fullparity remain separate/unproved. See `Workflow/results/CONCISE_FOLDER_NAMES_2026-10-26.md` and current delivery index; no repeat of the closed first trial, no silently renamed folder.
