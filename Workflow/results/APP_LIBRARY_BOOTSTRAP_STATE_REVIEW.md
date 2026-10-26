# App Library bootstrap-state independent review

Date: 2026-10-15
Status: NOT PASS — confirmed P2 source-state race; awaiting Main's announced re-freeze and bounded re-review.
Reviewer test executions: **0**.

## Authority and boundary

Independent, bounded source review of the approved maintenance only. The human authorized agents and waived the formal workflow; maximum three participants including Main. This reviewer dispatched no agents. All shell commands used RTK. The sole reviewer write is this report. No implementation or test edits, Swift commands, builds, application/process control, GUI actions, reference-product files, evidence directories, or assets were used. Existing dirty work was preserved.

Read project AGENTS.md, Docs/APP_LIBRARY_SPEC.md, Docs/APP_LIBRARY_SLICE_PROPOSAL.md, and Workflow/stage-summaries/2026-10-15-library-bootstrap-state.md. The approved spec supersedes historical PROPOSED markers. This is an existing loading/unavailable/empty contract repair, not feature or architecture approval.

## Blocking source finding

**[P2] Closed projection work can mask a terminal source failure indefinitely.**

- Evidence: Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:184-199 closes the projection during source invalidation and renders again on `.partialFailure`. At :257-260, `projection.isProjecting` unconditionally contributes to `isLoading`.
- Evidence: Sources/PagingPrototypeApp/AppLibraryProjectionController.swift:63-70 sets `isOpen = false`, clears pending/snapshot, and cancels the task, but intentionally retains ownership and `isProjecting` until completion. At :81-89 completion clears `isProjecting`, but `onChange` is suppressed for a closed or obsolete generation.
- Trigger: Open Library, suspend a projection worker that does not promptly cooperate with cancellation, invalidate sources, then deliver terminal `.partialFailure`. The invalidation branch no longer asks for loading, but the obsolete worker still does. The discarded worker later finishes without notifying the owner; the already-rendered loading label can persist.
- Impact: A real terminal source failure is shown as loading rather than unavailable. Old actions remain revoked; this is a presentation defect, not action revival.
- Likely root cause: UI loading uses worker ownership rather than whether the worker belongs to an open, publishable projection.
- Recommended bounded repair: use `(projection.isOpen && projection.isProjecting)` for this UI loading term. Preserve task ownership, cancellation, generation rejection, and source invalidation guards.
- Regression expectation: gated/noncooperative old work, source invalidation, `.partialFailure`, immediate unavailable before releasing old work, unavailable after discarded completion, and rejection of stale actions. No replacement scan, callback change, or new classifier.
- Confidence: High, directly supported by both controllers. No runtime execution by reviewer.

This finding supersedes the reviewer's earlier preliminary statement that no blocking source issue had been found. Main independently identified the same gap and announced a red regression followed by a predicate-only repair, after the ongoing full run finishes. That repair is not yet reviewed or credited. Do not issue bounded PASS until Main announces re-freeze and the actual revised source/test are inspected.

## Findings established on the previous frozen snapshot

| Check | Evidence | Result and confidence |
| --- | --- | --- |
| Initial state and shared-state delivery | AppLibraryOwnerController.swift:25,195-200; AppGridUIState.swift:39-43 | Owner starts `.loading`; active owners remember every shared state, even without source invalidation. `.loading` and `.refreshing` are busy. High. |
| Loading/unavailable/empty distinction, excluding the race above | AppLibraryOwnerController.swift:241-261; AppLibraryView.swift:676-682 | With nil catalog and no obsolete worker, busy means loading; terminal state with nil projection means unavailable. A committed zero-record catalog plus completed projection means empty; filtered zero results from a nonempty catalog mean noResults. A failure alone does not fabricate an empty committed catalog. High. |
| Late-mount seed before attach | AppDelegate.swift:2216-2234,2295 | Sets catalogProvider, then synchronously seeds from the existing refreshController.state before attach. No assembly seeds `.ready`, allowing neutral nil-catalog unavailable rather than a phantom scan. Reads state only; no new scan. High. |
| Actual final refresh callback composition | AppDelegate.swift:771-780,1299-1345 | Startup uses installFinalCatalogRuntimeCallbacks before begin. Both wrappers call the prior consumer. Busy early return is inside the inner consumer, so the outer Library fanout still receives busy state. No subsequent refreshController.onStateChange overwrite was found in AppDelegate. High. |
| Existing source-action revocation | AppLibraryOwnerController.swift:184-221 | State feedback never clears invalidatedSourceRevision or resets actionGeneration. Only a strictly newer committed revision releases invalidation; old requests still fail generation/revision/snapshot checks. High. |
| Closed Library work boundary | AppLibraryOwnerController.swift:195-200,208,241-253,255-256 | Receiving refresh state while closed only remembers it: render returns immediately and refreshProjection requires open state. No new classification or icon requests from the added state delivery. High. |
| Late completion after teardown | AppLibraryOwnerController.swift:68-74,195-204,297-309; AppLibraryPreferencesCoordinator.swift:28-43,104-107; AppLibraryProjectionController.swift:63-91; AppDelegate.swift:3397-3407,3450-3466; AppCatalogAssembly.swift:631-639 | Owner state/commit entry points reject inactive owners; preference load checks isActive after await; projection completion is generation/open-gated. AppDelegate clears the owner and assembly removes callbacks/closes data source. Existing load work need not be immediately cancelled to suppress stale UI publication. High for source-level stale-publication protection; no process-lifetime or physical claim. |
| No added scan/I/O/frame/Core behavior in the identified maintenance | AppDelegate.swift:2230-2233; AppLibraryOwnerController.swift:195-200,257-261 | Added behavior is in-memory state transfer and view rendering. Existing lazy preference inspection and existing icon/view work are not claimed to be zero I/O globally. No new scanner, metadata I/O, frame hook, pager/Core parameter, schema, or workspace mutation is introduced by these identified changes. High locally; no clean-base whole-tree attestation. |

## Startup and first-scan order

1. AppDelegate.swift:475 installs content assembly before Library mounting at :600.
2. Content installation composes the final refresh callbacks at :771, assigns the shared assembly at :778, then calls begin at :780.
3. AppGridRefreshController.swift:31 starts `.loading`; begin at :59-71 may leave that state unchanged. setState at :158-161 suppresses same-value callbacks. Therefore a Library mounted later must seed current state rather than rely on an initial event replay.
4. AppDelegate.swift:2233 performs that seed synchronously before owner.attach at :2295. If refresh has already completed, the same read seeds its terminal state. Neutral assembly absence uses `.ready` with no catalog and renders unavailable.
5. On a real outcome, AppGridRefreshController.swift:138-155 receives a successful snapshot as pending before the terminal state fanout. The inner production consumer applies at idle (AppDelegate.swift:1305-1311,1350-1358); assembly commits via searchPresentation (AppCatalogAssembly.swift:565-568), which invokes onPresentationUpdate after provider commit (AppGridSearchPresentationController.swift:90-97). AppDelegate.swift:1338-1345 routes that update to :1265-1296 and owner.catalogDidCommit.
6. The outer refresh fanout then delivers terminal state to the owner at AppDelegate.swift:1320-1323. If gesture state delays commit, nil served catalog remains unavailable at terminal state until the existing idle commit starts a projection. After successful empty projection completion the view is empty. Shared refresh state does not erase existing committed data merely because a routine refresh fails.

The prior defect description is from the human/Main handoff and stage summary, not a reconstructed clean candidate diff: nil-catalog entry and retry previously showed unavailable. The current nil-catalog busy term and initial seed address that defect, but do not address the newly confirmed closed-worker race by themselves.

## Test source and evidence limits

- Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift:260-289 contains testBootstrapLoadingFailureRetryAndFirstEmptyCommitUseActualFinalFanout. It calls the actual final production composition helper at :266 and checks initial loading, terminal unavailable, loading retry, first committed empty snapshot, and rejection of an absent action.
- The test invokes onStateChange directly; that does not update refreshController.state. Its first empty commit uses provider.applyPending plus owner.catalogDidCommit directly at :281-284. Thus it covers production **state fanout**, not end-to-end scanner execution or the entire production commit transaction. The transaction is independently traced above.
- A real retry from `.partialFailure` uses `.refreshing` (AppGridRefreshController.swift:78-89); the new bootstrap test uses `.loading`. The adjacent existing production-composition test at :221-257 exercises `.refreshing` with source invalidation and retained consumer delivery. The owner handles both through isBusy. Late terminal seeding and neutral fallback are verified from source, without a dedicated executed reviewer test.
- The newly requested gated-work race regression remains pending Main's repair/re-freeze announcement. The existing tests cannot establish that race is fixed.

| Evidence owner | Reported check | Credit |
| --- | --- | --- |
| Main / prior candidate | 2587 tests, 0 failures; stage summary:3,11 | Historical baseline only; not current repair verification. |
| Main / regression red | 1 XCTest, 2 failures (initial loading and retry); human handoff and stage summary:14 | Main-reported reproduction, not independently rerun. |
| Main / initial repair | Focused 35 tests, 0 failures; stage summary:14 | Main-reported green before the newly discovered race repair. |
| Main / full run | In progress or finishing at latest handoff | No final count credited. |
| Reviewer | 0 tests; 0 builds; 0 GUI/app/process operations | Source review only; never test PASS. |
| Native/physical | Desktop locked, per Main | No GUI, VoiceOver, restart, durability, or performance acceptance credited. |

## Snapshot and delivery

The following hashes were identical across two bounded reads before Main announced further repair work:

```text
ae4b17842336f85754338be7d58cf68e4f9d786b3836928cf59708c7395ba851  Sources/PagingPrototypeApp/AppLibraryOwnerController.swift
6adb2cc1dd979aee30c48919b7928bb113da3f9a5bae2620314498d83825e662  Sources/PagingPrototypeApp/AppDelegate.swift
82f6e12d6427142bdab69c86366f9b655366514a98eceab0955c83b740fb79f5  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
0b3baba5237d99e06a7ca81f6ba3b406d6f80ee9036f3cff106cd678855c3c34  Sources/PagingPrototypeApp/AppLibraryView.swift
0ea791453aa1c6c6907071c83dc940cfef8e6ff78e4f78451262ac120a4a2309  Sources/PagingPrototypeApp/AppLibraryProjectionController.swift
59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0  Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift
a8af3004f57e77d969f106672a5b170c718f321b5be7b52e5249466ae043411e  Sources/AppGridUI/AppGridRefreshController.swift
a1bd0c8149e891304c21a2a1b1a0c81c34d6cb7048a182b96ab6b3eea2670486  Sources/AppGridUI/AppGridUIState.swift
f7f30087ea71d539aafc0394b9c5ce49c6c3de25303ee15b132d5ae83ea780b3  Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift
```

The tree contains extensive prior dirty/untracked work. These hashes identify the reviewed snapshot, not the exact maintenance delta from candidate 2587. No assertion is made that unrelated dirty Core or other project changes were introduced by this maintenance. The approved stage summary changed while Main worked; it remains Main-owned.

Next action: on Main's explicit re-freeze, inspect the predicate-only repair and gated-work test, refresh relevant file/line/hash references, and reconsider bounded source PASS. Broader Library and goal-wide native/physical gates remain open.
