# Layout terminal receipt expectation — independent bounded review

Date: 2026-10-15
Verdict: **BOUNDED TEST-SOURCE PASS**. Confidence: High.
Finding: No material weakening of the retained-writer, latest-successor, journal, or memory-IO completion invariants was found. The changed expectation accepts two scheduling-dependent success receipts already allowed by the production flush contract.
Reviewer tests: **0**. Reviewer builds/Swift executions: **0**.

## Authorized boundary

Read-only review of the current corrected assertion in Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift, the existing public flush implementation, and the directly relevant retained-writer/FakeIO ordering. The sole new write is this report. No source/test edits, store/Core repair, Swift commands, builds, application/process control, other agents, or prohibited reference/evidence/assets reads were performed. All shell commands used RTK; existing dirty work was preserved.

This separate add-on does not reopen or change the bootstrap PASS or either bootstrap review report. Main's reported current focused result and full-run status are recorded separately from this source verdict.

## Contract finding, with exact evidence

Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:96-129 permits both observed success shapes:

| Timing at resumed flush | Existing production behavior | Correct expectation |
| --- | --- | --- |
| Retained final writer has finished before flush captures its attempt | No pending layout or terminal rejection; :115-116 returns nothingPending. | nothingPending, backed by the retained independent state/journal/completion assertions. |
| Flush joins the still-owned final writer and retains its attempt receipt | :101,125 captures the attempt; after the writer finishes, :104-113 returns persisted with lastPersistedGeneration, provided no pending layout or terminal rejection remains. | persisted with exactly write generation 2 when finalWriteFails is true, otherwise exactly 3. |

runPersistLoop sets the receipt and clears active writer ownership only after draining the loop (actor :318-365). persistOnce calls replacement, awaits directory sync, and only then returns success (:425-432). Successful bookkeeping updates the actual generation and healthy state (:335-341). There is no basis in these paths for requiring only nothingPending when flush races retained completion.

The generation numbers are write generations, not layout generations: seed consumes write generation 1; if the retained final layout-2 write fails, layout 4 becomes write generation 2. If it succeeds, layout 2 consumes write generation 2 and layout 4 becomes write generation 3. Both cases still require final **layout generation 4**.

## FakeIO ordering explains the specific race

The current file's relevant FakeIO lines are :459-487 (line numbers have shifted from the approximate request): write tracks an active writer, replacement publishes destination bytes at :478 and records replaced layout generation at :479-480, while fsyncDirectory appends completedLayoutGenerations and releases active write accounting at :483-487. latestLayoutGeneration at :436-440 reads the replaced journal bytes, not the actor's completion receipt.

Consequently, observing layout 4 proves replacement occurred, but does not prove fake sync or actor final bookkeeping has finished. The test awaits this marker at :276 **before** calling resumed flush at :282, without another enqueue/flush to trigger recovery. That preserves its autonomous-successor-progress check. The resumed flush may still legitimately join the final writer; accepting its exact persisted receipt corrects the scheduling assumption rather than treating the fake marker as durability.

This conclusion is established from the concrete code paths, not from assuming the full-run failure was a flake.

## Current corrected assertion and retained failure detection

The helper is currently named assertTimeoutAndSuccessor(finalWriteFails:) at test :246. Its only broadened receipt assertion is the switch at :287-297:

- nothingPending is allowed.
- persisted is allowed only if its generation equals finalWriteFails ? 2 : 3 (:294-295).
- Every other result fails (:296), including failed, timedOut, staleRejected, rejectedOverLimit, and readOnly.

All directly relevant checks remain:

| Invariant | Test evidence | Regressions still rejected |
| --- | --- | --- |
| Flush is bounded while the original IO gate is closed | :255-258,266-269 | A blocking/hanging barrier or false immediate successful receipt. |
| Original journal/LKG survives the stalled write | :249-262 | Premature replacement/loss while the write gate remains closed. |
| No new writer is admitted while retained writer is suspended | :270-271 | More than five attempts before release, or more than one active writer. |
| Latest successor progresses autonomously before resumed flush | :264-276 | Lost successor, failure to drain, or dependence on resumed flush to initiate replacement. |
| Final writer completes successfully | :282-298 | Failure/timeout/stale or incorrect-generation receipt; unhealthy final state. |
| No hidden retries/duplicate successor writes | :299 | Any final attempt count other than exactly six. |
| Correct completed layout sequence, including fake sync bookkeeping | :300; FakeIO :483-487 | Missing layout-4 completion, unexpected layout-3 persistence, or duplicated/incorrect completion sequence. Expected [1,4] on final failure; [1,2,4] on final success. |
| Single writer throughout | :301 | maximumActiveJournalWrites other than exactly one. |
| Exact latest validated journal content and write generation | :302-303,347-356 | Final content other than layout 4, invalid/latest journal mismatch, or wrong latest write generation 2/3. |

The nothingPending branch cannot alone satisfy the test: the healthy state, six attempts, exact completed sequence, single-writer maximum, and decoded latest journal still have to pass. The persisted branch likewise cannot accept the old layout-2 receipt, a fabricated future generation, or mere pre-sync replacement. The adjustment broadens the accepted **receipt shape** to match the existing contract; it does not remove these intended completion and persistence checks.

## Corrected location and change isolation

The earlier mistakenly matched method testIdenticalEnqueueDuringTimedOutFinalAttemptStillCoalesces at :175-195 now retains its strict `XCTAssertEqual(resumed, .nothingPending)` at :192, along with exact three attempts, zero stale rejections, and layout 2/write generation 2 checks. finalWriteFails is scoped to the intended helper at :246; the wrong-site switch is absent.

A read-only, in-memory reverse reconstruction moved the current comment/switch back to the earlier wrong site and restored the intended helper's strict assertion. Its SHA-256 exactly matched the previously observed wrong-match snapshot `2f33354475b9088a4402f690211773a13b7e3b6aa084a0004b6d6b8aac3f7197`. This establishes that the correction between those two observed files relocated only that assertion block; no other test cases or supporting IO/assertion helpers changed in that correction. No reconstructed source was written or compiled. Removing the current block in memory yields strict-assertion baseline hash `3d01d67a2d25e00a097b5f8bfc183bb97ce44b31861395bacce3aa3bb7509369`; that is a reconstruction, not a independently archived clean baseline.

The current test and actor hashes match the preceding R2 inspection. The actor is already dirty in the shared tree; this review neither edits it nor claims the entire tree is clean. No production store change is observed between the bounded reads, consistent with Main's explicit no-production-change handoff.

## Evidence ownership and limits

- **Reviewer:** zero tests, zero builds, source inspection and hash checks only. This verdict is bounded test-source PASS, not executed-test PASS.
- **Main:** focused **23 tests / 0 failures after the test correction**, reported in the human handoff; not independently rerun by this reviewer.
- **Main:** full R2 run is still running at the handoff. No full green result is inferred from the focused result or this review.
- **Historical Main reproduction:** full 2588 tests with one receipt-expectation failure, expected nothingPending but received persisted generation 3. The current source explains why that receipt is contract-valid in the joined-writer path; this reviewer did not execute or inspect the authoritative test log.
- Memory IO proves ordering, receipts, and journal decoding within the fixture. It does not establish real fsync behavior, crash/restart recovery, power-loss durability, GUI, VoiceOver, or physical performance acceptance.

## Reviewed identities

```text
95b8b23a7e27c890ab8a9dbed4ef6399b8de940a8ece90c4f304083362c64bbe  Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift
1f6aee06be615ae6f2b06ee5633200e0931c5f2663b1270a258d1e45a4707d5a  Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift
```

No actionable semantic-weakening finding remains within this add-on. Main retains responsibility for the current full-run result and any separately authorized repairs or physical gates.
