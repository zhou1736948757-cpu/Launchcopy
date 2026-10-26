# Library transition continuity

Date: 2026-10-20. Status: INVESTIGATING.

## Objective / baseline
Remove redundant main-page Library entry, reduce entry hitch and eliminate return flicker without tuning paging physics. Large dirty worktree retained. Prior a7509311 candidate has user-accepted completed-swipe wide-border correction, not performance acceptance.

## Plan and ownership
Main: inspect root composition/layer/visibility lifecycle, implement bounded fixes, serial verification and native isolated handoff. One read-only agent: gallery/projection entry workload audit; no tests/UI or source writes. Independent review after stable changes. Max 3 including Main; shared SwiftPM serialized. Specification: Docs/LIBRARY_TRANSITION_CONTINUITY_SPEC.md.

## Decisions / evidence / risks
New user report is physical observation, mechanism unproven. No changed physics/storage/default opt-in. Prior focus fix acceptance recorded separately. No other source edit yet. Next: inspect exact commit/restore/render ordering and entry gallery construction. Review/native/physical fix gates pending.

## Implementation checkpoint
Four deterministic pre-fix tests reproduced seven assertions: redundant attached entry, unchanged empty/nonempty query generation/reload, destination restored after reveal/detachment. RED log retained under `.build/verification/20261020/library-transition/red.log`.
Main implemented no grid entry control (standalone owner compatibility preserved), a localized validated View menu alternative, unchanged-query restoration without generation churn while still committing pending catalog, destination restoration before reveal, and explicit disabled implicit CA transactions across parent frame/commit/cancel changes. No physics/data changes.
Investigator Anscombe confirmed repeated gallery material writes and gallery-mode result-icon admission; assigned only AppLibraryView.swift / AppLibraryGalleryView.swift plus new LibraryTransitionGalleryWorkTests.swift. Main does not edit those files; builds remain serial. Skeleton/snapshot caching deferred without measurements; no claim of hitch causality or measured performance. Next: focused GREEN, independent source review, frozen full/build/package and native check.

## Independent review / bounded repair
Descartes r1 identified one P2 synchronous close-callback reentry hazard (current production triggering path unproven). Two new tests reproduced eight failing assertions in reentrancy-red.log. Main now blocks admission throughout cleanup, captures/detaches only the outgoing view identity, and suppresses post-teardown reveal/notifications. Worker source had no added blocking finding. Final reviewer packet review-inputs-r2.json supersedes r1; independent follow-up pending.
Earlier focused235/0 and full3261/0 are pre-reentrancy-repair snapshots, not final current-source verification. Initial focused-r1 had3failures: one historical detach-order assertion updated without removing responder checks, and two invalid cancellation-counter expectations removed while keeping real request/image/queued-delivery tests. Counter is pending-consumer cancellation only, not a universal cleanup count.

## Fixture-generation correction
Reentrancy GREEN2/0. First final-focused attempt237tests failed5asserts in pre-existing AppLibraryLaunchAndQuitTests.testFailedLibraryWriteDuringQuitDoesNotPresentCompetingCategoryWarning: it captured actionGeneration before awaiting a concurrently queued attach/startup projection refresh, then waited forever for a correctly revoked old request. Earlier235/full3261 executions passed this race; no product failure inference. Corrected only the fixture to await resolution of the current displayed generation before capturing its request. Stale-action rejection remains unchanged. Failure log/input manifest preserved with -pre-fixture-correction suffix; final verification will rerun from a new frozen snapshot. Reviewer notified with13inputpacket review-inputs-r3.json.

## Review r2 notification epilogue closure
Descartes r2: direct close repaired, remaining P2 in existing outer preferencesChanged deferred notifications after a restoration callback tears down owner. Added two deterministic preference-trigger/notification-callback tests, RED2tests/2assertions in notification-red.log. Main now checks current activity at deferred entry and between readiness/presentation callbacks, and stops preference UI work after teardown/close; no notification suppression for active owners. New restore test closures use weak owner capture; initial order test captures only host rather than fixture to avoid ownership cycles. Frozen13input review-inputs-r4.json current. Prior 7947335a candidate source/tests/package remain historical and NOT_LAUNCHED; final-r2 verification must supersede them.
Old owned41393 normal Quit completed through native application menu; exact process absence verified. Generated Cmd-Q alone had no effect and was not counted as successful exit. No process signals or formal data touched.

## Independent follow-up accepted
Descartes r3 grants bounded SOURCE_ACCEPT for frozen13input packet review-inputs-r4.json; R1/R2/P3 ownership issue closed, no new actionable finding. All agents closed. Source review does not certify native/physical smoothness. Final-r2 serial full XCTest3265/0 observed; remaining build/package/seed/native packet not yet reported complete.

## Final 2026-10-20 delivery and native packet

- Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-continuity-rc-20261020-r2/LaunchcopyUITest.app`; SHA256 `bc701b1c2a476b8a51d8d0d2ed012defff6f4913caf1db868f2cbc46324ded22`; last verified owned PID88692. Unsigned/uninstalled, normal non-topmost window. Earlier7947335a r1 NOT_LAUNCHED and all older packages are historical, not current source.
-535 frozen inputs, 13 changed source/test paths versus a750 baseline; no Core/PagingUI/AppGridUI changes. Focused239/0, full3265/0; Debug, Release, package and diff passed. Existing unrelated warning history not recast as global warning-clean. Packaged localization365keys×3languages retained.
- Independent Descartes r3 BOUNDED SOURCE_ACCEPT; R1/R2/T1 closed, prior findings preserved; all agents closed. Main owns actual verification.
- Native: old41393 normally Quit/exact absence; fresh249hash-verified authored fixtures only, no preferences/history/cache imports. Cold LibraryOFF/historyOFF→own LibraryON/Saved/historyOFF. Main AX and inline screenshot show no redundant entry after feature enable. Localized View-menu entry opens eight populated category cards; search→single synthetic result→native clear returns cards; nativeBack restores prior main query, then main query cleared. First page and wallpaperREADY observed. No formal app launches/removal/data, signals, install/sign/Git mutations or saved private screenshots. All535source/binary/249seed hashes rechecked unchanged.
- One generated horizontal-right scroll caused no observed navigation; INCONCLUSIVE, not a physical test or established app/input cause. Completed/canceled real-touchpad hitch/flicker, frame-time metrics, spokenVoiceOver/liveIME/120Hz remain unaccepted. OrdinaryBack endpoint is not proof of animated return continuity. Source risk reductions are not a measured causal/performance fix.
- Current handoff: owned ordinary main window, page1, empty query, Settings/folder/Libraryclosed; own LibraryON/historyOFF. Request one user real-touchpad entry/return check and do not operate UI during it. Full product parity remains incomplete. Receipts: `.build/verification/20261020/library-transition/final-r2/final-verification.json`, `native-results.json`, `native-fixture.json`, `source-delta.json`.

## Superseding user feedback during architecture review
User reports FIRST Library swipe still hitches onbc701; cold-entry physical gate FAIL_STILL_PRESENT. Return flicker not specifically confirmed. User explicitly requests deleting the search blue outline, superseding the local-decoration styling contract (prior wide-remnant result remains historical). Work continues under Docs/ARCHITECTURE_MAINTAINABILITY_OPTIMIZATION_SPEC.md, with empty-shell idle preparation/no-outline native controls. No retroactive physical PASS. Feedback receipt: `.build/verification/20261020/architecture-review/human-priority-feedback.json`.
