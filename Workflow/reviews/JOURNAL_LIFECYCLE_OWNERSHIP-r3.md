# Journal lifecycle ownership test follow-up r3

Date: 2026-10-20. Read-only source inspection; no execution.

## Bounded verdict

**Production source PASS carried forward from r2; no new implementation blocker. Test follow-up PARTIAL: one P2 coverage gap remains (T1).** Actor/protocol/spec match r2 exactly, so F1 remains closed. Removing only the two inserted tests reconstructs the exact r2 test-file hash; helpers and the previous nine tests are unchanged. r1/r2 are preserved.

## New test review

- `testWritableResetFailuresAutonomouslyDrainAlreadyAdmittedLatestSuccessor` (294-331) closes the writable-failure follow-up in both archive and default-write branches. Each failure is held while layouts 2 then 3 are admitted. A separately held successor proves autonomous admission before another flush/enqueue, permits degraded-state inspection, and then checks completion of only layout 3, generation 2, single-writer accounting and expected archive count. Replacing the write-gate entry while the failing write is suspended is safe on this path because the old call already awaits its captured gate and that gate is explicitly opened at line 311. Gates retain the existing asynchronous defer cleanup limitation documented in r2.
- `testObsoleteFlushReceiptCannotCertifyResetOrStalledSuccessor` (253-292) closes the post-default held-successor portion: default sync is held before installing the successor gate, then the test waits for successor arrival and requires flush timeout while completed writes contain only seed/default. It also correctly starts an old final failure attempt before reset admission. However, its old waiter finishes while reset is still blocked, as detailed below.

## T1 — P2: Old waiter does not cross reset completion

**Trace:** The test closes the archive gate (267-272), then awaits `obsoleteFlush.value` and requires `.timedOut` (273-274). It opens the archive only afterward (276). Consequently this flush cannot observe reset completion. The later flush at 283 is a fresh caller in the new epoch. This tests suppression of old failures while the reset barrier is active, but not invalidation of an obsolete receipt after that barrier settles. The 40 ms timeout could also expire before reset admission under delayed scheduling.

**Why actionable:** Removing the actor's epoch-change receipt reset still satisfies the old-waiter assertions: the closed reset barrier alone forces timeout. The test therefore cannot establish that specific r2 coverage claim. This is a test evidence gap, not evidence of a production bug.

**Recommendation:** Keep the same pre-reset flush alive through reset completion using an adequate bounded budget and explicit gates, and assert a distinguishing result. For example, after reset succeeds, let the already-admitted successor fail once; the old waiter must discard its obsolete failure receipt, admit the current epoch's final attempt, and report that attempt's successful current generation. Hold/observe that final attempt before releasing it so premature `.failed` is detectable. Retain the independent held-successor assertion already added. Confidence: high from source ordering; no mutation test executed.

## Exact SHA-256 receipts

Root: `/Users/mac/Projects/Launch_Copy/PagingPrototype`. Rechecked before this report was created.

| Input | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` | `261696725a3117491efe359e8ce6080ef384a0893664db494d92f8d2ac9f7fae` |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift` | `cf04d3df7d6480ad864c9e3fb0ffbe757021b4066e2765743327b4f2f71d8821` |
| `Docs/JOURNAL_LIFECYCLE_OWNERSHIP_SPEC.md` | `8fe3fb2b28b7d8e6e78c0b39bba9834fb1f343e721d9820b85422a73834fdad3` |
| `Tests/AppGridUITests/LayoutStoreLifecycleOwnershipTests.swift` | `c67ac1093582761ecac656dc427b00c064e907382b233d91a2e5d479fa072d3d` |
| `Workflow/reviews/JOURNAL_LIFECYCLE_OWNERSHIP-r1.md` | `856c12d590b3dd34fd84eebc15e517e015ab33b42d25f193c21323bc00e726cd` |
| `Workflow/reviews/JOURNAL_LIFECYCLE_OWNERSHIP-r2.md` | `078a0becffe7a29cae4b42bb2274ae95e31a2e55eed4e208d611a1e3ccf707ae` |

## Execution boundary

Main reports the prior frozen focused 103/full 3333/Debug/Release package/diff runner completed with zero exits, and reports a production-input-identical, unlaunched Release artifact identified as `a35442f3`. Main was running the new 11-test suite and subsequent full suite (3335 expected); those final outcomes were not supplied or independently inspected for this review. These reports are not reviewer execution or runtime acceptance. No baseline expected failures are attributed to current source.

Only this report was written. No test/build/UI execution, source/test edits, Git mutation, artifact launch, signals, installation, signing or formal-data access occurred. Production review remains bounded to r2 hashes; final execution acceptance belongs to Main.
