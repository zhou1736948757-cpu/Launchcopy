# Meaningful folder creation and catalog-warning repair

Status: implementation, full automated validation, bounded source review and native handover complete. Human physical new-folder acceptance remains pending; full-objective parity is not claimed.

## User-visible changes
- Newly grouped apps receive the localized shared category name when known. Otherwise the current target/source display names (including committed aliases) form the suggestion. Committed manual category overrides apply even when the Library is disabled.
- Suggestions preserve both long names within 64 graphemes, keep meaningful Unicode/emoji, and choose a deterministic unused suffix. Only the new folder is named; existing `Group` or custom titles are never migrated. Existing inline rename remains available.
- Missing bundle identifiers are still recorded anonymously and admitted using the established canonical-path identity, but no longer alone trigger a partial-load failure. Actual unreadable sources and invalid/corrupt app bundles remain discovery failures, including an unsuccessful empty discovery.
- English, Simplified Chinese and Japanese status text now describes unreadable app sources/items rather than claiming displayed applications failed to load. The exact categories causing the previous running preview's warning have not been captured. This is not proof that its warning was harmless.

## Architecture and compatibility
`FolderCreationTitle` is a pure policy. `FolderCreationNaming` composes existing catalog/management/Library/displayed-language value snapshots. The controller calls the optional synchronous policy only after token/layout/catalog validation and actual release-target resolution; `DragMutationEngine` passes the resulting literal title into the existing atomic `LayoutMutation.createFolder`. No extra mutation, generation increment, editor, IO, sorting or frame work.

`AppGridRefreshOutcome` retains total `failureCount`, adds a bounded non-blocking subset and derives actual discovery failures. The Mac adapter maps only `missingBundleIdentifier` into that subset. Existing unclassified callers default to all-hard behavior. Cancellation/latest-wins/configuration safety, scanner policy and persisted formats remain unchanged. Scan totals saturate safely, giving hard failures precedence when the integer total saturates.

## Verification evidence
All evidence is under `.build/verification/20261024/folder-naming-catalog-warning/`.

| Gate | Current evidence | Boundary |
| --- | --- | --- |
| Provisional compile | `naming-before-r1.log`: input changed during build, zero tests | INVALID, never red/PASS |
| Original naming defect | `naming-before-r2.log`: 2 tests, 2 failed title assertions | Actual production window/drop path; commit/member/generation controls passed |
| First focused | `focused-r1.log`: 146/0, 5.528 seconds | Before strengthening an insertion negative control |
| Final focused | `focused-r2.log`: 146/0, 5.154 seconds | Includes exact insertion order, actual release target, staleness, one-time naming, metadata/alias/disabled-Library and real codec coverage |
| Source freeze | `source-inputs-r1.json`: 607 inputs; `source-delta-r1.json`: 22 deltas | 8 new files, 14 existing files; full dirty worktree retained |
| Final full/build/package | FullR3 3762/0, 86.780s; Debug/Release/strict R2 package; three languages ×369keys | Earlier failed runs retained; standalone resource smoke1107entries and12entry tests pass |
| Independent source review | Kierkegaard: BOUNDED SOURCE PASS against final607-input R3 | Read-only, not independent execution/native/physical acceptance |
| Native presentation / human grouping | New51878main/wallpaper/warning text observed; human grouping pending | No agent grouping/launch/reorder of real apps |

## Current app and preservation
The corrected FolderNamesR2 preview is now the verified running candidate. The latest human-updated isolated arrangement/settings remained authoritative throughout the normal handover. No installation, signing, Git mutation, forced exit, reference source/assets or original reverse evidence access.

## Remaining product boundaries
This delivers the newly approved default-name refinement, not an automatic creation-time editor or retroactive renaming. The earlier intermittent pointer cause and full LaunchBetter experience parity remain unproved. Reentrant-release hardening was discussed but not implemented or asserted as a cause.

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

## 2026-10-26 — Library header/cards and measured wrapper warning correction
The earlier live-warning-category unknown boundary now has a fresh equivalent-config explanation, not a retroactive report capture: fiveOSrecognizediOSwrappedAPPL candidates were false negatives of Contents-only metadata lookup. A standardfirst publicBundleAPPL fallback preserves realerrors and outercanonicalURL; old/newdefaultrootprobes137apps/5errors→142/0. NewLibraryHeader8de25194…/ownedPID58258 has no native mainwarning atinspection; same5currentprofilehashes/modespreserved after old26223normalQuit/start. No app launched/renamed/organized byagent.

Main/Library search sharedstyle/geometry/visibleplaceholder andstationaryrootheaders, hiddenbeforemount preview, passivecategorygroups with individualminiappactions. Full3793/0/focused479/0,612inputs/18deltas, two bounded SOURCEPASS andserialartifact/resource/entrygates; native staticheader/menu/background-noexpand/ESCbackverified. Physicalfirstslide/returnflash/currentIME/AXdevice/performance/fullparity/originalintermittentdragcause remainseparate. Newauthority `Workflow/results/LIBRARY_SEARCH_CONTINUITY_2026-10-26.md` and deliveryindex; no oldacceptance repeated or savedname migrated.
