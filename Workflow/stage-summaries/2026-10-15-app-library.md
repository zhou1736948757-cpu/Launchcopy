# Approved App Library implementation

## Objective and authorization
Human confirmed the written default-off independent Library proposal on 2026-10-15. Approved spec: Docs/APP_LIBRARY_SPEC.md; detailed requirements: Docs/APP_LIBRARY_SLICE_PROPOSAL.md. Full parity goal remains incomplete.

## Baseline and limitations
Prior verified snapshot: 2455 tests/0 failures, Debug/Release, 221-key three-language package, wallpaper-state candidate b19af336... . Unverified wallpaper-source observer edits already exist and must be verified separately. Existing tree is dirty; no cleanup/revert. Wallpaper source open is unresolved; do not infer a rendering fix.

## Concurrency and ownership
At most three agents including Main. Foundation worker: catalog metadata and pure category/preferences/projection plus own tests. Localization worker: typed Library strings/resources plus own tests. Main: file persistence, native UI/navigation/actions, profile/Quit and owner wiring; sole Swift/process control. Disjoint write sets; source freezes before serial build/test. No Chief workflow required (human waiver).

## Evidence
Implementation in progress; no new build/test/GUI PASS yet. Independent review pending. No installation/signing/commit, no production data mutation.

## Remaining gates and next action
Implement approved foundation/localization in parallel while Main develops bounded persistence and owner seams. Integrate and run focused/full tests, packaging, independent source review and dedicated isolated native acceptance. Keep no-usage and physical-performance boundaries.

## Foundation wave checkpoint
Localization worker completed 53 typed Library keys/three languages and nine authored resource tests; static checks only, no XCTest credit yet. Main added off-main actor file storage (bounded v1 JSON, regular-file/no-follow reads, private temp/fsync/rename, explicit recovery and protected unknown/future/ambiguous versions), accepted-write owner with bounded drain, one-running/one-pending generation-gated projection owner and candidate-local Library path/namespace. Main added store/write/projection/profile tests. Native Library navigation/settings/actions/Quit assembly is NOT connected yet; no resource-library feature or runtime acceptance claimed. Independent Main-foundation source review is in progress in parallel with final domain worker; Swift remains serial after source freeze. Earlier wallpaper-source inspection is diagnostic-only and receives separate tests.

## Verification attempts (retained, not hidden)
Initial compile failed on covariant Self default argument in the new projection controller; fixed using a typed optional Work seam and concrete-class Sendable closure. Focused r2: 107 XCTest/0 failures. Full r1: 2527 XCTest/4 assertion failures, all in preexisting localization exact-schema expectation missing the approved Library keys; updated the expected enum coverage, keeping strict table equality/uniqueness checks. This is not credited as full PASS.
Main additionally reproduced projection observer loading/terminal rejection bug with one regression test (1 test/1 failure, expected true,false but saw false). Repaired loading notification order and terminal notification for nil/wrong-revision result; independent reviewer informed and inputs refrozen. Reverification in progress. Existing unrelated test warnings remain; no zero-warning claim. No native Library UI or full parity completion.

## Independent review gate — foundation not accepted
Main-foundation reviewer returned SOURCE FAIL (four findings): duplicate non-version JSON fields could be silently selected; save admission/target replacement race; superseded-success receipt lost if latest save failed; equal retry could acknowledge a previously failed post-rename flush. Main accepts these as real issues and will repair with focused regressions before final foundation acceptance. Full r2 2527/0 and Debug/Release/package 274 keys succeeded, but do not override source FAIL. Retained r1 candidate cda3b089... is superseded/unaccepted; do not use it for Library acceptance. No native UI feature wiring yet.

## Safety repair checkpoint
Implemented F1 duplicate decoded-object-key admission, including escaped equivalents and exact v1 preference shape. Implemented F2 cooperative advisory lock and expected-byte CAS with no-follow descriptor traversal/temp/rename/cleanup, detected directory inode/target substitution rejection; documented non-participating external writers are outside atomic coordination. Implemented F3 every successful persisted receipt retained independently, failed newest write reconciles to last real successful baseline without claiming failed draft saved. Implemented F4 equal-content retry repeats write/flush, no false equality receipt.
Added six regression methods (5 duplicate fixtures, protected-target swap, ancestor swap, held cooperating lock, post-replacement failure retry, older-success/newer-failure plus next draft). r4 focused119/8 assertion/throw failures exposed Foundation /var alias spelling in no-follow fixture; corrected tests to Darwin realpath and literal dot-component rejection instead of Foundation standardization equality. r5 focused119/0 passed. Full r3 and refreshed independent review still in progress. Refrozen429 source/test/script/resource/package inputs; 18 PagingCore/PagingUI inputs match prior wallpaper-state baseline. Domain/localization independent bounded SOURCEPASS; Main-foundation priorFAIL is not erased until explicit re-review disposition.

## Foundation wave verified (not Library feature completion)
Refreshed independent Main-foundation SOURCEPASS resolves F1–F4 under documented cooperative-writer contract; domain/localization SOURCEPASS retained. Final119focused/2533full0fail, Debug/Release/packageR2exit0,274-key3languagepositive/twoLibrarynegativefixtures,429inputsverified. Exe8b36c024... . Reviewers executedzeroXCTest; Main executedtests. All agents/buildjobs closed/completed; noGUIcandidateopened/install/sign/commit/productiondatachanges. FullGoalACTIVE. NextMainowns optionalnativeLibraryview/settingsenablement/mode/state/action/source/lifecycle/sharedQuitwiring and theirtests/nativeacceptance. Detailedcheckpoint: Workflow/results/APP_LIBRARY_FOUNDATION_CHECKPOINT.md.
