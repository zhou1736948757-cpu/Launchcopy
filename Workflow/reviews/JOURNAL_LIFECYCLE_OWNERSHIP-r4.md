# Journal lifecycle ownership T1 follow-up r4

Date: 2026-10-20. Scope: read-only inspection of the single added test; no execution.

## Verdict

**Bounded source/test-source PASS. T1 closed; no remaining blocker identified in this follow-up.** Actor/protocol remain identical to r2, including the restored production actor. The spec has only the non-goal wording clarification recorded below; ownership/ordering are unchanged. The previous source PASS and F1 closure stand. r1/r2/r3 are unchanged. This is maintenance review acceptance, not certification of final execution or the whole project.

## T1 closure

`testOldFlushWaiterCrossesResetAndRetriesCurrentEpochFailure` (333-379) keeps the same pre-reset flush across reset completion with a two-second budget. It observes the old final write before reset admission; archive and default-sync gates control reset progress. A successor write is configured to fail once and held before installing a separate current-final gate. Releasing that failure must cause the original flush to start the current epoch's final attempt: no other flush/enqueue is called during this interval, and normal retries are disabled. The test observes that gate, confirms only seed/default have completed, then releases it and requires the original waiter to return generation 3, the exact successor layout, and single-writer accounting.

This is distinguishing coverage: without epoch receipt invalidation, the old failed receipt can return `.failed` when the successor fails, so the current-final gate is never reached. The two-second budget is a deadline, not an ordering mechanism; delayed scheduling can fail the test but cannot make an early old-waiter timeout satisfy the required final-attempt arrival and generation-3 result. Gate cleanup retains the existing asynchronous-defer limitation from r2.

Removing only this added function reconstructs the exact r3 test-file hash. Earlier tests/helpers were not re-audited or changed by this delta. The prior held-successor and writable-failure coverage remains applicable.

## Exact SHA-256 receipts

Root: `/Users/mac/Projects/Launch_Copy/PagingPrototype`. Rechecked immediately before report creation, after the restoration notice.

| Input | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` | `261696725a3117491efe359e8ce6080ef384a0893664db494d92f8d2ac9f7fae` |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift` | `cf04d3df7d6480ad864c9e3fb0ffbe757021b4066e2765743327b4f2f71d8821` |
| `Docs/JOURNAL_LIFECYCLE_OWNERSHIP_SPEC.md` | `e19596a6d5f7fc0df4e732c83cf834531a89d89f800c84d343b53be57aa136b2` |
| `Tests/AppGridUITests/LayoutStoreLifecycleOwnershipTests.swift` | `fcfbad6273412ee5e9146b9b6c95165a2c159b0d26b028072116ff17758f5b96` |

## Spec boundary clarification

The non-goal now excludes manual/runtime reset and formal user-data access while permitting existing automated suites to reset their own temporary fixtures. Reversing only that wording substitution reconstructs the r2 spec hash, confirming no ownership/ordering change. The 12 lifecycle tests remain memory-only; this does not claim that every existing full-suite reset test is memory-only. Updated spec hash is recorded above. The bounded PASS is unchanged.

## Execution boundary

Main reports GREEN 12/0 in `new-tests-r3.log` and distinguishing mutation RED of one test/two failures (gate deadline plus caught error) after removing only the flush epoch receipt-reset block. Main also reports reparsing that same completed RED log after correcting singular `test` handling, preserving the original invalid receipt without rerunning execution. These are Main-provided results, not independently inspected logs or reviewer-run tests. The production actor's restored hash was independently checked above. The final focused/full test-only runner remains Main-owned; no result is inferred here.

Only this r4 report was written. No tests, builds, UI, mutations to source/tests/prior reports, Git changes, signals, installation, signing, artifact launch or formal-data access occurred.
