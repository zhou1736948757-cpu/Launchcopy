# Action feedback and typed login failure — code checkpoint

Date:2026-10-14. Status:CODE_CHECKPOINT_VALIDATED; whole parity and whole-language native
acceptance unproven. Approved INTERFACE_LANGUAGE_SPEC + PARITY_SPEC remain source of truth.
Previous goal turn was concrete progress, not a no-progress/verified wait turn. This turn adds
37tests and actual feedback/runtime lifecycle fixes. Full objective remains active/incomplete.

## Delivered behavior and architecture

- Pointer/Return/folder/context launches still use ONE AppLaunchController validation/API path.
  Main observes its existing callback; no modifications to AppLaunchController/KeyboardLaunchAdapter.
  Success clears feedback and retains activation composition's hide behavior; no-binding stays
  silent. Failed/missing/stale/hidden outcomes show neutral, nonfatal, NONMODAL message only.
- Inert root notice below search and above folder visuals. Six-second monotonic latest-error
  expiry; relabel/material/resize do not renew or revive. Queued rendering/text/AX/sizing off
  caller/frame stack; no first responder, hitTest=nil, no icons/catalog/rescans or user data logs.
- Typed Finder requested/missing/unavailable route uses existing public void API. Requested is
  dispatch only, NOT proof of Finder displayed or observed OS failure. Canonical/hidden/file
  refusal and actual context menu route tested with injected request/file seams.
- Origin assembly/controller plus root/language epochs reject obsolete result AND menu-launch/
  reveal ingress. Genuine callbacks are rebound AFTER root construction/realm replacement so
  startup order does not silence them. Ordinary live-language relabel does not change epochs.
- Actual launcherDidHideHandler covers sleep/session order-out as well as normal hide; queued
  and displayed errors clear without tearing down resident services or accepted preferences.
  Folder attachment inserts beneath the existing notice without detaching/renewing it.
- Residual audit L1 found SMAppService's own fixed-English error reason, not native detail.
  Added semantic operationFailed(enabling:Bool), preserving legacy failure(message:) literal
  compatibility. Actual catch uses shared pure truthful-state seam; new outcome is rejected
  by existing transaction. Enable-only cleanup/disable-side no-reenable policy unchanged.
  Two localized reasons render in all3languages; fake actual Apply/store/rollback/alert tested.

## Final executed evidence

| Gate | Result |
| --- | --- |
| Focused final | focused-r8.log:62/0,15:03:47.853JST,0.634s |
| Full final | full-r1.log:2403/0,15:06:03.598JST,42.792s |
| Debug | debug-r1.log exit0 |
| Release/probe | release-package-r1.log exit0; build durations [('PagingPrototypeApp', '35.98s'), ('LocalizationResourceProbe', '1.11s')] |
| Actual app resources | 3languages/221required keys+signatures; development fallback forbidden |
| Negative app fixtures | actionFeedback.launchFailed missing in ALL3; illegal integer token in activationLoginEnableFailed in ALL3; both rejected exit1 |
| Frozen inputs | source-files-r2.sha256 + source-check-r2.json:391/391 match after package |
| Independent source reviews | ActionF1-F3 repaired boundedPASS; typedLoginL1/C1 source-clear with exact preserved rollback fixture corrections |
| Source integrity | git diff --check exit0; previous PagingCore/MacAppCatalog/launchcontroller/keyboard adapter source fingerprints unchanged |

Current unsigned candidate:`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/language-action-feedback-rc-20261014-r1/LaunchcopyUITest.app`
Executable SHA256:`dc62acf8512796001feef200af307c3327fa56fd17b098058063bc454bdcfc8e`
Resource identity: adjacent CANDIDATE_MANIFEST.txt + LOCALIZATION_RESOURCES.sha256.
Existing warnings remain; no zero-warning/distribution/performance/native/whole-projectPASS.
No install/sign/notarization/app launch/process stop/commit/reset/clean performed. All4helpers
closed; no remaining Swift process. Prior candidates/worktree history retained.

## Failure/repair chronology (all logs retained)

- A resource-generation Python command had a parse error before execution; it changed no files.
  Corrected generator ran once; no duplicate table keys were introduced.
- focused-r1:56/2 assertion failures. Immediate weak-view check within native autorelease scope;
  renderer fixture wrongly used same-revision reload before first catalog adoption. Kept weak
  nil/lifecycle assertions after autoreleasepool + normal main-turn drain, used real initial
  refreshPresentation/renderer/menu. This is not proof of an AppKit leak. focused-r2:56/0.
- Login C1 optional coverage gap led to real Apply-button -> transaction -> fake service/store
  -> native alert-builder matrix. focused-r3 compile-only: fixture used pref facade fields instead
  of existing prefs.settings hierarchy; corrected fixture, no production model rewrite.
- focused-r4:57/2 fixture assertions: expected one service call and tore down pooled singleton
  content between loop iterations. Retained singleton through matrix; later exact policy correction
  is enable?2:1 calls and lastRequested=false. Strong store/alert/rollback assertions remain.
- Reviewer ActionF1: obsolete root/realm results and old menu launch entered rebound route.
  Explicit epochs, valid-current rebind and guarded menu ingress; replay/new-action regressions.
- Reviewer ActionF2: sleep/session actual-hide omitted cleanup. Actual handler now clears;
  tests include before/after queued presentation and later genuine failure.
- Reviewer ActionF3: later folder backdrop covered notice. Actual mount now below notice;
  both transparent/opaque material ordering and reason/deadline/hit-testing tested.
- focused-r5 compile-only: optional FolderLab snapshot unwrapped. focused-r6:61/7 failures:
  folder absent + incorrect disable-side cleanup count expectation. Exact transaction assertions
  corrected, not production behavior. focused-r7:62/1 failure: lab intentionally leaves its last
  group ungrouped, so2apps yielded nofolder; fixture now explicit valid2member FolderEntryBuilder
  snapshot injected through sanctioned assembly generator, then real commit/open/mount route.
- focused-r8/full-r1 then62/2403zero failures. Reviewer history retained append-only. Native
  unshown controls, fake dispatch/service, synthetic files and callbacks are code evidence only.

## Current native entry / manual kit

Fresh CUA.getState succeeded with inventory. It showed existing com.launchcopy.app running;
com.launchcopy.ui-test was NOT listed/running. No screenshot/window-unlock observation was
made; inventory availability is not GUI acceptance. Do not quit/modify the user's original app.
Earlier native Terminal control policy denial was not retried/bypassed with shell/otherapps.

Prepared latest exact binary+resource-verified RUN_ISOLATED_UI_TEST.command adjacent to candidate;
zsh -n passed, NOT executed.37Info-only synthetic bundles, ordinary non-topmost window,
--ui-test-windowed --ui-test-profile gui --folder-lab; hashed separateprefs/layout/cache andfake
global/login services. No real app executable or original catalog/arrangement/prefs copied.
User async prompt asks manual start on Desktop2 and reply; no approval/launch assumed.
Real NSWorkspace/Finder, native IME/menu/VoiceOver, visual long-label/root layering/expiry,
exact-profile fresh-process persistence and physical AB are still open.

## Full objective audit and next work

See LANGUAGE_RESIDUAL_AND_PARITY_AUDIT.md (bounded inventory, not completion). Original full
UI/functions objective includes App Library/category/details/overrides/lifecycle, configurable
rows/columns/default35/identity anchors, optional usage and extra gestures/destructive actions;
those approvals/features/evidence remain incomplete. Language code integration does not waive
any of them. Existing Group N generation is creation-time naming/data policy, not permission
to translate saved folder titles or silently alter domain. Current audit's definite authored
login residual L1 is repaired; no whole-language/native certification follows from absence of
another source finding. CLI/lab/data/legacy-nil/OS strings remain intentionally excluded.

Timer0ms and existing paging physical parameters untouched. >25ms CAUSALITY_UNRESOLVED;
120Hz hardware/real performance acceptance unproven. Current native starter/user confirmations
are required for remaining gates, but this progress turn does not satisfy3-turn blocked audit.
