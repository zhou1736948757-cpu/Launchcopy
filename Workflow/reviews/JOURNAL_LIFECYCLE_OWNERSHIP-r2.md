# Journal lifecycle ownership independent follow-up r2

Date: 2026-10-20. Scope: source-only follow-up plus read-only audit of the 404-line, nine-test lifecycle file. No tests or builds executed by this reviewer.

## Verdict

**Bounded source PASS. F1 closed; no new implementation blocker found.** The new tests provide useful deterministic regression coverage, with the concrete coverage limitations below. This verdict closes the source-review gate for this maintenance scope; it does not certify outstanding integration runs or the whole project. r1 remains immutable and records the earlier snapshot accurately.

## F1 closure and additional source seam

At `LayoutStoreActor.swift:291-297`, startup now seeds the high water immediately after both reads, before protected early returns. `writeGeneration(of:)` (546-548) returns a generation only for `.valid`; codec decoding reaches `.valid` only after v1, checksum, structure, caps and domain validation. Future/invalid fields are not trusted. For a protected slot plus valid peer generation 900, either orientation retains 900, preserves protected classification and bytes, then a successful explicit reset computes generation 901 at line 515. A subsequent successful successor advances to 902. No extra I/O or suspension is introduced by this fix.

The spec now explicitly limits protected high-water retention to validated v1 peers and confirms that flush timing begins after initialization. The source still awaits `ensureLoaded` before creating the deadline; suspended startup I/O is not newly bounded.

The added internal `lifecycleObservation` getter (82-86) is actor-isolated and read-only, with no setter, await, admission decision, protocol addition or diagnostic consumer in production Sources. The counter (254-265) increments only after the loaded fast-path guard and decrements through defer around the initialization wait. It counts outstanding initialization callers, not I/O operations; it may remain positive briefly after initialization completes until those callers resume. `resetRevision` exposes admission epoch, not completion. Neither value controls persistence policy.

In-memory source fingerprint comparisons confirmed that removing only the observation additions reconstructs the pre-observation F1 actor hash, and removing the five-line F1 addition from that version reconstructs the r1 actor hash. Thus the earlier ownership inspection carries forward without repeating r1. The current actor hash below was checked after Main's explicit baseline-restoration notice and matches the production source inspected before that temporary run.

## Test source audit and concrete gaps

The nine tests observe real initialization/reset admission or gated I/O arrivals before proceeding; polling waits for predicates rather than guessing scheduling from sleeps. Write/replace/sync gates cover the complete ordinary-writer ownership interval. Successor progress is observed in memory before a new flush can trigger recovery. Tests assert independent FIFO reset receipts, monotonic completed generations, protected archive failures, immutable startup receipt, and F1 in both slot orientations for future/over-limit peers. Gate-bearing tests schedule `releaseAll` from defer on throwing exits; gate opening resumes all stored continuations. This cleanup is asynchronous rather than a joined teardown, and direct task-value waits are not independently deadline-wrapped.

The memory I/O rejects an existing archive destination before removing the source (395-402), matching the relevant production `FileManager.moveItem` collision behavior rather than silently overwriting evidence. Active-write accounting spans write through sync. This is a lifecycle model, not verification of OS replacement semantics, fsync durability, real locking or filesystem errors. The timestamp-plus-UUID source fix remains in place. The two-reset test checks distinct retained archives but does not force a single wall-clock second.

Two concrete coverage follow-ups remain; neither establishes an implementation defect:

1. **Flush receipt after reset completion:** lines 124-149 test cancellation/timeout while the reset default is stalled. They do not hold the post-reset successor in I/O after the default completes, nor begin with an obsolete pre-reset final-attempt receipt. Add those interleavings to directly verify that flush neither certifies a pending successor from the default receipt nor reuses an old epoch's rejection.
2. **Writable failure with an already-admitted successor:** lines 152-188 enqueue recovery only after reset failure. The protected failure test admits a successor during reset, but correctly forbids writing. Add a writable archive/default failure with a successor admitted before failure resolves, then assert autonomous successor progress and degraded/terminal state before recovery. This directly exercises the specified retention-and-drain failure contract.

These are bounded coverage limitations, not a blanket acceptance claim for all suspension permutations. Test-source inspection found no additional blocking gate or archive-model defect in the reviewed snapshot. Compilation and assertion success remain execution evidence owned by Main.

## Exact input receipts

Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`. SHA-256; rechecked immediately before report creation.

| Input | SHA-256 |
| --- | --- |
| `Docs/JOURNAL_LIFECYCLE_OWNERSHIP_SPEC.md` | `8fe3fb2b28b7d8e6e78c0b39bba9834fb1f343e721d9820b85422a73834fdad3` |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` | `261696725a3117491efe359e8ce6080ef384a0893664db494d92f8d2ac9f7fae` |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift` | `cf04d3df7d6480ad864c9e3fb0ffbe757021b4066e2765743327b4f2f71d8821` |
| `Tests/AppGridUITests/LayoutStoreLifecycleOwnershipTests.swift` | `59f2f1556161123d4b0f9bedeaa4923d983504143ab05a5062fe19726e6f82d8` |
| `.build/verification/20261020/journal-lifecycle/LayoutStoreActor.baseline.swift` | `1f6aee06be615ae6f2b06ee5633200e0931c5f2663b1270a258d1e45a4707d5a` |
| `Workflow/reviews/JOURNAL_LIFECYCLE_OWNERSHIP-r1.md` | `856c12d590b3dd34fd84eebc15e517e015ab33b42d25f193c21323bc00e726cd` |

## Evidence boundary

Main reports first GREEN for nine tests, expected baseline RED for three cases with 17 failures, and focused GREEN; final full/build/package work was still underway at the latest update. This reviewer did not run tests, inspect their logs, or independently certify those execution results. Expected RED failures describe the old baseline, not the restored actor. The documented observational-only baseline instrumentation must be retained with its before/after hash receipts to distinguish it from semantic baseline changes; its script was not audited here.

Only this r2 report was written. No source/test/r1 changes, SwiftPM/UI execution, Git mutation, signals, installation, signing, formal data or prohibited external-app/evidence access occurred. Any subsequent source/test change requires checking these hash-bound conclusions; final integration evidence remains a separate gate.
