# App Library bootstrap-state independent review — R2

Date: 2026-10-15
Verdict: **BOUNDED SOURCE PASS** for the re-frozen bootstrap and discarded-projection UI-state maintenance. Confidence: High.
Reviewer executed tests: **0**. This is not full-test, packaged-candidate, native GUI, or physical acceptance.

## Scope and preserved history

Main explicitly announced re-freeze of AppLibraryOwnerController and the added gated-work test. R1 remains unchanged at Workflow/results/APP_LIBRARY_BOOTSTRAP_STATE_REVIEW.md, preserving its confirmed P2 finding and pre-repair hashes. This R2 supersedes only that finding's open status and updates relevant test references. The prior startup/fanout/lifecycle findings remain supported by unchanged source hashes.

The human authorized this separate R2 report. It is the sole write of this re-review; no source/test edits, builds, Swift execution, application/process control, external agents, or prohibited reference/evidence/assets reads were performed. The later human-authorized LayoutStore test-only extension is reviewed separately below. All shell commands used RTK. Existing dirty work was preserved.

## Source findings and resolution

| Finding / check | Source evidence | Assessment |
| --- | --- | --- |
| R1 P2 resolved: obsolete owned worker no longer masks terminal source failure | Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:255-261 | Loading now uses `(projection.isOpen && projection.isProjecting)`. After source invalidation closes the projection, a still-owned cancelled worker cannot contribute UI loading. On `.partialFailure`, sourceRefreshFailed becomes true at :195-199, so the invalidation loading term also clears. With the projection snapshot cleared, AppLibraryView.swift:676-682 displays unavailable immediately. High confidence. |
| Worker ownership and cancellation unchanged | AppLibraryProjectionController.swift:54-91 | Closing still invalidates generation, removes pending/snapshot, and cancels but retains the running task until completion. Completion clears ownership; a closed, obsolete, or cancelled task cannot publish. No new task, callback, ownership shortcut, or cancellation strategy was introduced. High confidence. |
| Old source actions remain revoked | AppLibraryOwnerController.swift:184-221 | State feedback does not clear invalidatedSourceRevision. Only a newer committed catalog releases invalidation. resolve still requires an active open owner, no source invalidation, matching action generation, current projection/catalog revision, current URL, and visible identity. High confidence. |
| Existing bootstrap loading / unavailable / empty contract preserved | AppLibraryOwnerController.swift:25,195-200,241-261; AppGridUIState.swift:39-43; AppLibraryView.swift:676-682 | Nil catalog plus busy shared refresh is loading. Terminal failed nil catalog is unavailable. First committed zero-record catalog becomes empty after its valid projection completes. No committed empty snapshot is fabricated from failure; zero filtered results from a nonempty catalog remain noResults. High confidence. |
| Seed remains before attach, without scan | AppDelegate.swift:2229-2234,2295 | Owner reads current existing refreshController.state after catalogProvider wiring and before attach; absent assembly uses neutral `.ready`. This covers missed initial events and late terminal mounting by source inspection. No scanner call or disk read was added by the seed. High confidence. |
| Before/after first scan fanout unchanged | AppDelegate.swift:475,600,771-780,1299-1345; AppGridRefreshController.swift:31,59-71,138-161 | Final wrappers are installed before begin; Library mounts later and seeds current state. Prior callbacks are composed, busy early return stays inside the inner consumer, and the outer wrapper still delivers all shared states. Successful pending snapshot commit routes through the existing idle/search presentation callback to catalogDidCommit (:1296), then terminal state reaches the owner (:1323). No callback overwrite was introduced. High confidence. |
| Closed Library and teardown remain bounded | AppLibraryOwnerController.swift:195-208,241-256,297-309; AppLibraryPreferencesCoordinator.swift:28-43,104-107; AppDelegate.swift:3397-3407,3450-3466; AppCatalogAssembly.swift:631-639 | Closed state delivery does not start classification; projection refresh requires open state. Inactive owner checks, preference load's post-await active check, projection generation/open rejection, owner clearing, and assembly callback removal prevent late UI publication. High confidence at source level. |
| Exact production repair delta | Byte/hash comparison against R1 owner | Replacing only the new parenthesized predicate with the previous `projection.isProjecting` expression reconstructs the exact R1 SHA-256. AppDelegate, assembly, projection controller, preferences coordinator, view, shared refresh controller, and state enum hashes are unchanged. Therefore this R2 source delta changes UI loading eligibility only; it introduces no I/O, scan, frame/Core change, classifier, schema, or workspace mutation. High confidence within the bounded delta. |

The race is resolved before the obsolete worker finishes: waiting for its completion is no longer necessary to render terminal error. Suppression of the obsolete completion callback remains correct because it cannot change the already-terminal presentation.

## Regression source review

Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift:22-30 introduces BootstrapProjectionGate. Its checked continuation deliberately does not observe cancellation, so close can cancel the projection while the worker remains owned. finish resumes it exactly once and clears the continuation.

The added testDiscardedSourceProjectionCannotMaskCompletedSourceFailure at :301-329 injects this worker, opens Library against revision 1, waits for the worker-start condition, invalidates sources, and delivers `.partialFailure`. It asserts both `isProjecting == true` and `isOpen == false` before asserting unavailable (:318-322). This distinguishes owned obsolete work from publishable UI work and would expose the old predicate. It then releases the gate (:323), waits for ownership to finish (:324), and checks unavailable again plus action rejection (:325-327). Gate completion occurs after ordinary assertions, so an assertion failure does not skip release through a thrown assertion.

Coverage limits are explicit: this race test delivers the owner state directly rather than the final AppDelegate fanout; the separate bootstrap test still calls the actual final helper at :276. The gate returns nil, so this test does not independently exercise rejection of a nonnil obsolete result. Its rejected request is constructed after invalidation using the current action generation (:326); it proves source/snapshot rejection, not rejection of a captured pre-invalidation generation by itself. The existing source-change test at :117-141 captures a request before invalidation and verifies it remains rejected through a newer commit. Production generation/open/cancellation guards were independently checked and are unchanged. These limits do not invalidate the reproduced loading race or the predicate-only repair.

The original bootstrap regression now resides at :270-299 and still checks initial loading, terminal unavailable, loading retry, first committed empty result, and absent-action rejection. As documented in R1, direct onStateChange invocation does not update controller.state, and its manual provider/owner commit is not a scanner or full production commit test. The real retry emits `.refreshing`; the adjacent final-composition test at :231-267 covers that state with retained consumer delivery. Both states are busy in production.

## Evidence ownership and outstanding gates

| Owner | Evidence available at review | Credit |
| --- | --- | --- |
| Reviewer | Source inspection and frozen hash comparison; tests 0, builds 0 | Bounded source PASS only. |
| Main | Prior candidate 2587 tests / 0 failures | Historical baseline only. |
| Main | Original bootstrap red 1 test / 2 failures; then focused 35 / 0 | Reported pre-race-repair gates, not reviewer executions or latest repair green. |
| Main | Discarded-worker red 1 test / 2 failures | Human/Main-reported reproduction; not independently rerun. |
| Main | Full R1 run: 2588 tests with one LayoutStoreTerminalOutcome timing failure, expected nothingPending but received persisted generation 3 | Not full green. The later bounded source check below confirms both receipt shapes are permitted by the existing contract in this scheduling window; no production store/Core repair is credited or authorized. |
| Main | Corrected authoritative focused R2 count: 47 XCTest / 0 failures, including 11 terminal outcome tests, before receipt-assertion adaptation | Main-reported only; corrected authoritative counts supersede the withdrawn figures. |
| Main | Current focused R4 Owner + Terminal rerun; full rerun pending | No result/count supplied at this checkpoint. An intermediate wrong-site edit produced an undefined finalWriteFails compiler error and was corrected before the reviewed re-freeze; it is not a green test run. |
| Native / physical | Desktop locked per handoff | No GUI, VoiceOver, restart, durability, performance, or packaged runtime acceptance. |

No blocking source finding remains in the assigned re-frozen maintenance. Main must keep the outstanding test/build/package and native/physical gates separate; this verdict neither closes the full Library task nor the broader parity goal.

## Re-frozen identities

```text
afd61fbce040cf5447ebffbeb7e8889e39c8c6cc2678f1ad71d983ac4b70cce2  Sources/PagingPrototypeApp/AppLibraryOwnerController.swift
b86d1c91f630c714052c2167c46ef12df59b9dd29e68f5f8d5b846845fe77ff8  Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift
32c50c6f7cec3cbc0dee6bcc51f3ba63f5fb16210cf7c1d3fea2bf0dcb91164a  Workflow/results/APP_LIBRARY_BOOTSTRAP_STATE_REVIEW.md
```

Other source identities match the R1 report. The current test source has shifted old line numbers by ten due to the gate helper; the R1 historical references are intentionally preserved.
## Separate bounded note: LayoutStore receipt-assertion scheduling correction

Additional human authorization: inspect only the current corrected test assertion and the existing public flush/retained-writer contract; do not repair production storage. Verdict: **BOUNDED TEST-SOURCE PASS**, High confidence. Reviewer tests remain **0**.

The reviewed current site is `assertTimeoutAndSuccessor(finalWriteFails:)`, declared at Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift:246. The corrected switch at :287-297 accepts `.nothingPending`, or `.persisted` with the **exact** write generation `finalWriteFails ? 2 : 3`, and fails for every other outcome. The unrelated identical-enqueue test at :175-195 retains its original strict `.nothingPending` assertion at :192. The intermediate misplaced switch with an out-of-scope finalWriteFails is absent from this reviewed re-freeze; no compile execution was performed by this reviewer.

This is a correction to scheduling assumptions, not a relaxation of the existing storage contract:

- Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:96-129 snapshots activeFlushAttempt. If a retained final writer is still owned when flush joins it, the completed attempt path at :104-113 reports the actual lastPersistedGeneration. If the writer already completed and there is no pending layout or terminal rejection, :115-116 returns `.nothingPending`. Both are success shapes for the same fully drained latest successor.
- TerminalMemoryIO publishes replaced bytes at test :472-481; latestLayoutGeneration reads those bytes at :436-440. The marker therefore precedes fsyncDirectory bookkeeping at :483-487. The real actor calls replace, then awaits directory sync, then returns persistence success at :425-432; runPersistLoop updates lastPersistedGeneration/state and final receipt afterward at :335-365. Observing fake layout generation 4 does not imply the actor's writer/receipt has already finished.
- The generation-4 marker is awaited **before** the resumed flush at test :273-282, with no intervening enqueue/flush to drive recovery. This still proves that the retained writer autonomously advanced the latest successor through replacement. The subsequent flush and exact assertions prove completion under the memory-IO contract; the marker alone is not credited as durability.
- The test still asserts timeout while the gate is closed, unchanged stalled journal/LKG, degraded state, five attempts and one writer before release (:256-271). After release it still requires healthy state, exactly six attempts, completed layout generations `[1,4]` if the final write fails or `[1,2,4]` if it succeeds, and maximum one active writer (:298-301). assertLatest at :302-303 and :347-356 still decodes the journal and requires exactly layout 4 with write generation 2 or 3 respectively. Accepting a persisted receipt for the older final write, an extra write, a lost successor, a failure/timeout/stale outcome, or incomplete fake sync does not satisfy these checks.

No production LayoutStoreActor change was observed during this extension: its SHA-256 remained identical across the initial and corrected-test reads. Main reports no production store/Core edit. This is a local evidence statement, not an attestation of every pre-existing dirty storage change or real filesystem/power-loss durability. Scope remains the receipt assertion in this helper, not a broad store review.

Current corrected identities:

```text
95b8b23a7e27c890ab8a9dbed4ef6399b8de940a8ece90c4f304083362c64bbe  Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift
1f6aee06be615ae6f2b06ee5633200e0931c5f2663b1270a258d1e45a4707d5a  Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift
```

The Library owner/test and initial report identities above remain unchanged. Current R4 focused and subsequent full verification remain Main-owned pending gates; no physical acceptance is inferred.
