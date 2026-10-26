# Icon/type full-suite LayoutStore failure triage

Date: 2026-10-13. Scope: bounded read-only triage; Main owns all repairs.
Repository root for every source path below: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

## Result and evidence boundary

High-confidence test-observation race; the reported result does not establish a production coalescer bug.
Only this report was written. No Swift invocation, tests, build, application run, production data,
reference code, source edits, fixture edits, Git reset/stash/commit, or owner-review duplication.
The dirty tree was retained. Pointer fallback/held ownership/menu zero-frame repairs remain Main's work.

Existing evidence, inspected without rerunning:
- `.build/verification/20261013/icon-type/full-r1.log:3644–3646`: late-final-failure test fails at
  `Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift:282`, actual `.persisted(writeGeneration: 2)`,
  expected `.nothingPending`; test duration 0.090 seconds.
- Same log `:4911–4913`: 2157 tests, 5 assertion failures. Overall full-suite status remains FAIL.
- `.build/verification/20261013/icon-type/focused-r6.log:258–260`: 108 tests, 0 failures.
  Focused PASS does not override full-suite FAIL; no new verification verdict is claimed.

## Exact synchronization gap

| Source path and lines | Finding |
| --- | --- |
| `Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift:171–172,246–271` | Failed test uses shared timeout/successor helper; layout 2 final write is suspended and configured to fail; layouts 3 then 4 enqueue while ownership remains retained. |
| Same file `:273–282` | Gate release is followed by journal-generation-4 polling, then flush; nothing proves actor bookkeeping/receipt retirement has completed before that flush. |
| Same file `:395–399` | Opening the gate resumes continuations; it does not await the resumed writer's completion. |
| Same file `:421–425,457–466` | `latestLayoutGeneration()` sees bytes published by `replaceFile`, BEFORE directory sync and actor completion. |
| Same file `:468–472` | Even `completedLayoutGenerations` / zero active I/O writes mark only fake-I/O completion, not store-actor drain completion. |
| Same file `:363–373` | Polling sleeps only while the predicate is false; an I/O predicate becoming true creates no actor completion guarantee. |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:426–432` | Store still awaits replace/sync before returning a successful persistence outcome. |
| Same file `:335–341,362–365` | Pending clearing, durable generation, healthy state, receipt result, and writer ownership release happen afterward on the store actor. |
| Same file `:96–116,123–128` | Flush may capture the still-active final receipt and return the latest persisted generation after drain; entry after receipt retirement returns nothingPending. |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift:55–60,104–105` | Flush is a bounded durability barrier; persisted and nothingPending describe different entry/receipt histories. Idempotence does not require identical enum values across those histories. |
| `Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md:88–89` | Contract requires latest-wins ordering and bounded in-flight draining. |

Legal failing interleaving: old final layout 2 fails; revision mismatch preserves layout 4;
retained loop starts layout 4; fake replace publishes generation 4; test sees it and enters flush
while `activeFlushAttempt` still exists; sync and actor bookkeeping finish; receipt waiter returns
`.persisted(writeGeneration: 2)`. Entry after the same drain returns `.nothingPending`.
This is receipt participation, not evidence that flush rewrote layout 4 or discarded it.
`LayoutStoreActor.swift:321–334,344–349` preserves newer pending revisions on late failure;
`:337` clears pending only for the successfully persisted revision. Ownership is held at `:309–314`.

## Deterministic recommendation for Main

For this failing branch, retain the journal-generation-4 observation, then passively await
`store.currentState() == .healthy` BEFORE the first post-release flush. Keep line 282's exact
`.nothingPending` assertion and ALL existing assertions at `:283–288` unchanged.
Why this barrier is valid here: degraded state is already asserted at `:260–262`; forced final
failure leaves it degraded (`LayoutStoreActor.swift:344–349`); only successful successor bookkeeping
sets healthy (`:337–341`). With no later enqueue, the same actor turn then retires the receipt and
writer (`:362–365`) without an intervening await. A state read observing healthy therefore follows
that complete drain. Waiting is bounded by the existing test helper and cannot trigger recovery.
It also strengthens the test's automatic-recovery requirement rather than accepting a second result.

Do NOT apply healthy-only waiting indiscriminately to the shared success branch: successful layout 2
can already set healthy before layout 4 completes. For a common passive barrier across both branches,
Main would need an actor-side observation acknowledging the expected durable generation AND idle
writer/no pending/no active receipt, published after `:362–365`; an I/O marker alone cannot supply it.
That is a future owner decision, not a change authorized or performed by this triage.
Do not replace the assertion with a blanket persisted-or-nothingPending acceptance, add arbitrary
sleep/yield delays, or call flush to drive recovery before checking that recovery happened autonomously.

## Confidence and unknowns

High confidence in the synchronization gap and the failure-branch passive barrier from current source.
No runtime schedule was traced, so this specific execution's interleaving is inferred, not reproduced.
The targeted failure log reports only line 282; state/write-count/generation/serialization assertions
in the same helper have no logged failures. This is supportive evidence, not a subsystem audit.
The user supplied that icon/type did not change production LayoutStore; the actor is already dirty,
and this triage does not attribute that pre-existing diff to any owner or establish historical provenance.
Main must implement/review the bounded repair and rerun relevant/full verification before closure.
