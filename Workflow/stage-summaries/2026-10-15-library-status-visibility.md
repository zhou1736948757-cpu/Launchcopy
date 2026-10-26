# Library/grid catalog-status visibility — 2026-10-15

## Objective and baseline
Previous goal turn PROGRESS: long category counts repaired,2645/0, R2 source/native evidence and folder commit/cancel/real restart. Full independent reference-experience parity remains ACTIVE/incomplete. Current450 source inputs match; previous exact own test executable absent. Native Library Back left a persistent central Apps Ready badge over populated grid; restart initially hides it.

## Root hypothesis / bounded contract
AppDelegate's Library setGridHidden(false) unconditionally shows status, overriding AppGridStatusView's own .ready-hidden policy. The status renderer is queued and can also overwrite an external hide while Library is open. Preserve its last committed semantic visibility plus the Library mode mask, including accessibility suppression. Do not use pending semantic data to show stale text, suppress legitimate loading/error/empty/noResults permanently, rerender strings in a frame callback, add timers or change public module APIs/physics.

This is a bounded existing Library return bug, not a new feature or product contract. Main immediately reproduces actual delegate enter/Back plus queued-render leaks. Prefer a private composition-root latch of renderer-applied visibility, observed through the existing onPresentationApplied callback, reset/identity-gated on replacement/teardown. A single private projection combines that committed visibility with Library.isOpen. No new view hierarchy/public setter; status component remains independent of Library.

## Plan / concurrency
Main owns production AppDelegate and new integration tests, serial all Swift/build/package/UI. No worker needed for tightly coupled critical-path correction. After stable focused result, one independent source reviewer may run concurrently with Main full/build/package (max2includingMain), report-only/no tests/UI. User's Chief waiver and max3 total remain in force. Preserve dirty work and all prior failure/artifact records.

## Acceptance / budget / safety
Actual composition regression must fail before fix. Cover ready Back after equal-state update, non-ready queued rendering while Library open (visual+AX hidden), loading/empty/noResults restored on Back, repeated entry/Back and status replacement/teardown. Existing language/status formatting-outside-frame, catalog/search/Library lifecycle and focus regressions retained. Last committed render, not state pending, governs visibility; no raw text copied to logs.

Budget: constant-time Boolean visibility projection only on existing status presentation/Library mode transitions; no new I/O, timer, projection/catalog scan/icon work, Core callback text formatting, or frame/input/physics change. All18 PagingCore/UI frozen. Physical60Hz comparison and120Hz remain separate.

Final gates: nonzero focused/full XCTest, Debug/Release/package, strict288-key3language resources with negatives, unique unsigned isolated candidate/hash/current source freeze, supported native Library Back with populatedgrid has no ready badge, legitimate no-results still visible; exact own normalQuit/processabsence. No formal app/data, reference source/assets, install/sign/commit, cleanup/processkill or OSsetting/Space changes. RealIME/VoiceOver/physical fullparity not inferred. Next executable action: actual delegate RED.

## RED and minimal correction
Main actualcomposition RED5XCTest/19assertfailures: Readybadge afterBack/equalstate/repeat; staleReadyexposedbeforequeuederrorrender; nonreadyqueuedrenderer overwroteLibrarymask withvisible+AX; replacementmask. Legitimate loading/empty/noResults Back test passed beforefix. Implemented only AppDelegate: latch lastcompleted render's own visibility through existing onPresentationApplied, identity-gated/reset onreinstall/teardown; one privateBoolean projection combinescommittedvisibility with currentLibrary.isOpen for visual+AX. Reuse that projection onLibrarymode transition and existing scheduledrefresh, no pendingstate-to-visibility inference, forcedstringrerender/publicAPI/timer/viewhierarchy/Corechanges. Next focused execution before stablefreeze/reviewer.

## Focused/freeze/reviewer wave
Mainfocused-r1 39/0 after5regressions; finalfocused-r2 40/0,3.060s with6newregressions. Additional busy/error test explicitlychecks committed renderer/mode boundary beforelaterrealproviderresolution, not a fake scannerfailuregate. Main reversedonlyexactknownAppDelegate changes in memory and reproduced priorSHA (app-delegate-delta-proof.json). Final451sourceinputs frozen,2changed/newfiles (AppDelegate/newintegrationtest), all18Core/UI and AppGridStatusView/publicAPI untouched. Single read-onlyreviewer writesonly LIBRARY_STATUS_VISIBILITY_SOURCE_REVIEW.md inparallelMain serialfull/debug/releasepackage. Max2includingMain, no workers, allprioragentsclosed. Mainnativeapp remainsclosed untiljobsdone.

## Final current-source/native checkpoint

## Current checkpoint — Library/grid status visibility, 2026-10-15

Previous goal turn PROGRESS; full goal ACTIVE/incomplete. Reproduced Ready badge after Library Back and queued status leak into Library (5tests/19failures). AppDelegate now latches only completed renderer semantic visibility and composes current Library mask for visual+AX, with identity/reset/teardown guards; no pending-state unhide or forced text render. Only AppDelegate/new6-test integration file changed;451 current inputs match, all18 PagingCore/UI and AppGridStatusView/public API unchanged. Exact prior AppDelegate body recovered by bounded in-memory reversal.

Final Main focused40/0, full2651/0 (53.080s), Debug/Release/package and strict288-key3-language positive/two negative probes passed. Independent bounded SOURCEPASS, reviewer0tests/build/UI and449 non-asset hash checks; Main verified all451. Retained-old-callback test still has a documented non-blocking latch-discrimination gap; production identity guard verified correct. Combined locale+Library test remains a follow-up. Reviewer closed; all jobs terminal.

Latest unsigned/uninstalled candidate: .build/candidates/library-status-visibility-rc-20261015-r1/LaunchcopyUITest.app; exeSHA42bc2e9d491560c9e29966798403d4d3fa043e2d8fbec9829749a6d360d932d7. Native repeated All40 Library->Back has no Ready overlay; legitimate unmatched query/no-results appears, is suppressed inside Library, returns with main query, and clears back to populated grid without Ready panel. Initial loading observed; wallpaper later ready/visible, not a delay fix. One screenshot timeout recovered via sameobject retry, no app restart. Exact PID30718 normalQuit verified absent, no native query after finalQuit. No formaldata/install/sign/commit/OSsetting/Space/reference-source/assets or unrelated process change.

Next original parity gate: exact-candidate appearance controls Apply/restore/reopen/real-process persistence, within approved label/icon32–64/font9–16/blur0–60 scope, fixed5x7/physics. No new source/features unless reproduced defect; preserve callback/locale coverage follow-up and all realIME/VoiceOver/physical/120Hz/approval boundaries. Fullhandoff: Workflow/results/LIBRARY_STATUS_VISIBILITY_CHECKPOINT.md; evidence .build/verification/20261015/library-status-visibility/. Historical statuses below are not current authority.


All451 hashes verified after final normalQuit; own process absent. Resource probes/build/test jobs terminal, reviewer closed. Native source fix accepted within stated scope, not real scanner-error/physical/fullparity acceptance. Next appearance gate and non-blocking coverage limitations remain explicit.
