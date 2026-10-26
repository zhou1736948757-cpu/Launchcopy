# Journal lifecycle ownership independent review r1

Date: 2026-10-20. Review type: bounded, read-only source inspection.

## Verdict

**FAIL against the full written ordering contract: one P2 finding (F1).** The ownership changes themselves pass the bounded suspension/interleaving inspection described below. F1 is inherited from the frozen baseline, not introduced by this patch; it remains relevant to the specification's explicit monotonic journal-generation requirement. This is not a blanket implementation, test, runtime, or product acceptance verdict.

## Findings

### F1 — P2: Protected startup loses a validated sibling's write-generation high water before reset

**Evidence / affected source:** `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:282-294` reads both slots but returns on future-version/over-limit protection before any valid sibling contributes to `lastPersistedGeneration`. The counter is initialized to zero at line 68 and updated for startup only in the subsequent valid-load cases at lines 300-318. Reset archives both slots at lines 183-191, then writes its default at line 204. `persistOnce` computes its next generation from the now-empty journal and that zero counter at line 501.

**Concrete trace (no external file change or competing process required):**

1. Inject startup slot A containing an unknown future version and slot B containing a valid v1 layout with `writeGeneration = 900`.
2. `loadInitialState` reads both slots. It correctly classifies startup as read-only, but returns before retaining the validated generation 900. `load()` remains the immutable protected startup result.
3. An explicit reset successfully archives both slots. No journal slot remains to supply the validated high water.
4. The default write uses `max(0, 0) + 1`, returns `.reset(writeGeneration: 1)`, and places generation 1 in the journal after generation 900 was archived. Swapping A/B, or using an over-limit sibling instead of a future version, reaches the same issue.

**Impact / contract:** The reset receipt describes the actual new write, but the journal counter regresses across an explicit reset. This violates the ordering contract's monotonic-generation requirement. The trace uses a validated current-schema sibling; it does not rely on interpreting a future schema's generation or changing read-only classification. The same gap exists in the frozen baseline, so this is a remaining contract gap rather than a new concurrency regression.

**Likely root cause:** Startup classification and successful-load publication are also the only place that seeds the validated generation high water; protected classifications bypass that bookkeeping before reset removes the evidence from active slots.

**Recommended solution:** Retain the maximum generation of validated current-schema slots before the protection early returns, while preserving the startup classification and file-protection policy. An equivalent owned reset-side capture before archive is possible. Add injected-memory-I/O regressions for both slot orientations, asserting no writes before explicit reset, immutable startup receipt, preservation of archived bytes, and reset generation 901 followed by increasing successor generations. Include the analogous over-limit combination.

**Regression risks:** Do not admit normal writes while read-only, trust unknown-schema fields, or change startup load selection. Do not read formal user data to verify the fix.

**Confidence:** High, based on a direct deterministic source trace. Not executed, per reviewer scope.

## Bounded ownership inspection

- **Shared initialization:** `ensureLoaded` (247-257) publishes a retained task before suspension. Concurrent first load/enqueue/flush/reset calls join the same classification; `hasLoaded` is finalized inside that task. The initializer's later reference cleanup cannot admit a second initialization after completion. Reset no longer changes the startup `loadResult`.
- **FIFO barriers and task references:** Reset admission (147-164) advances the epoch, clears pre-reset pending intent, captures the predecessor and ordinary writer, and publishes its own task before yielding. R2 waits for R1 and the captured writer; it cannot form a dependency back to R2. A superseded reset does not clear the newer reset's task reference. The latest reset's defer releases the barrier and starts a pending successor without an intervening await.
- **Suspended writer versus archive/cleanup:** Each reset waits for the full prior writer task, including replace and directory-sync suspension, before touching slots or temp files. The ordinary writer clears its references without an await at exit, before a reset can start a successor. No stale cleanup can erase a newly launched writer reference under these ownership paths.
- **Post-admission enqueue:** Enqueue retains/coalesces successors while a reset exists, including while startup state is protected. It does not launch a writer through the barrier. A later reset intentionally supersedes earlier pending intent. The last reset automatically drains the retained successor when writable; archive failure while protected retains it in memory without writing.
- **Exact reset receipts / stale publication:** Every reset returns its own `persistOnce` result and generation even when superseded. Successful old writes update the monotonic in-memory counter before their epoch guard. Revoked ordinary writers cannot publish health/rejection state, retry failed I/O, clear a new pending revision, or drain successors. Superseded reset state publication and drain restart are similarly guarded.
- **Failures:** Archive/default failures return `.failed`. Protected archive failure does not lift read-only state; writable failure publishes degradation/terminal failure. Retained successors survive and use the existing normal retry/coalescing behavior. A newer successful successor may legitimately supersede failure state. Default persistence remains the existing single attempt.
- **Flush:** Epoch changes drop old final-attempt receipts. While reset is queued/running, flush only polls; it cannot launch a competing writer or treat the default receipt as durability of a still-pending successor. After initialization, its unchanged deadline bounds the polling wait, and cancellation ends only that caller's wait. Owned I/O is neither cancelled nor awaited on the cancellation path. The deadline begins after `ensureLoaded`, as in the frozen baseline; this review does not claim bounded startup initialization or synchronous-I/O preemption.

No additional actionable suspension-ownership defect was found in these paths at the recorded hashes.

## Archive collision refinement and production I/O boundary

The initial actor snapshot (`68c81ac2f6ebd4df770ffaf14d5109e93b15e9e8b5088a2748229590a216e0d4`) used a seconds-only archive stamp. It was replaced during this review, and the latest delta was re-read. At current line 182, each reset adds a neutral UUID to the timestamp, with one shared stamp for that reset's A/B archives. Separate same-second reset admissions therefore no longer systematically reuse evidence paths. This concern is resolved in the reviewed source and is not an outstanding finding.

Production `FileManagerLayoutStoreIO.moveFile` delegates to `FileManager.default.moveItem` (`LayoutStoreIO.swift:87-88`), whose destination-existing behavior is failure rather than replacement. A seconds-only second reset could therefore fail archive and never write its own default; silently overwriting evidence would not be acceptable either. The inspected `TerminalMemoryIO.moveFile` (`Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift:529-534`) instead assigns into a dictionary and replaces an existing destination. That helper cannot establish production collision semantics. The worker's new helper should reject existing destinations and assert distinct archive names/retained bytes for multiple resets. No filesystem experiment was performed. UUID uniqueness is a practical source-level safeguard, not a claim of mathematical impossibility of collision.

## Input receipts

Paths are relative to `/Users/mac/Projects/Launch_Copy/PagingPrototype`. SHA-256 values were rechecked together immediately before this report was written; latest actor/spec refinements were included.

| Input | SHA-256 |
| --- | --- |
| `Docs/JOURNAL_LIFECYCLE_OWNERSHIP_SPEC.md` | `c7143560796a44ef37ab87f68faf9fa00f6594c6e1da6c5adc2fd9a865284070` |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` | `594c67176f540880b1326ef8baeaa2ff862464d08f8a0e9626b4550b95b5cad0` |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift` | `cf04d3df7d6480ad864c9e3fb0ffbe757021b4066e2765743327b4f2f71d8821` |
| `.build/verification/20261020/journal-lifecycle/LayoutStoreActor.baseline.swift` | `1f6aee06be615ae6f2b06ee5633200e0931c5f2663b1270a258d1e45a4707d5a` |
| `Sources/AppGridUI/LayoutStore/LayoutStoreIO.swift` | `f9ed0935ed42f76f0b577f262316df7128c218edad8112bea820586c6888d80b` |

## Scope and verification limitations

Only this report was written. Main retains production-source ownership; the test worker retains its new test-file ownership. Historical Chef execution machinery was bypassed as instructed. No agent was dispatched and no message was sent to another chat.

The expected new lifecycle test file was not present in `Tests/AppGridUITests` at the final pre-write inventory. Existing actor, recency and terminal-outcome tests were selectively inspected for relevant expectations/helpers; this is neither a complete test audit nor acceptance of the worker's in-progress tests. Their future appearance or test results cannot retroactively broaden this source verdict.

No SwiftPM, compiler, test runner, UI, installation, signing, process signals, Git mutations, application restart, formal/user data, or prohibited external-app/evidence access was used. Existing unrelated dirty changes were preserved. Source analysis does not establish RED-on-baseline results, deterministic gate correctness, suite/build success, package replacement, native behavior, or independent product acceptance. Those remain Main's integration gates. Any subsequent relevant source/spec change requires checking this report's applicability again.
