# Diagnostic snapshots — independent bounded review r1

Date: 2026-10-20

Verdict: **PASS — bounded source and test-source review.** No concrete blockers found in the frozen change against `Docs/DIAGNOSTIC_SNAPSHOT_OWNERSHIP_SPEC.md`.

## Scope and evidence boundary

Reviewed the six frozen inputs under `.build/verification/20261020/diagnostic-snapshots/review-inputs/`, their manifest, the three supplied production baselines, and inverse-proof JSON. Independently recomputed SHA-256 hashes: every frozen input and its current working-source counterpart matched the manifest, including immediately before writing this report. Inspected the existing Swift package boundaries and relevant configuration, event value, repository callback, and test-helper source for confinement and test reasoning.

This is an independent review of Main's Session/four-test work and the completed worker's Catalog/Bridge/five-test work. No agents were dispatched; the legacy Chef path was bypassed as requested. The sole authored file is this report. No SwiftPM, tests, builds, TSan, UI, Git operations, process signals, reference access, or formal-data changes were performed. Main's preliminary existing 38/0 and new 9/0 results are supplied context, not independently executed or certified here. Main retains serial suite/build/package/TSan verification and closure ownership.

## Findings and rationale

### TelemetrySession confinement and compatibility

- `TelemetrySession.swift:46-81`: all **11** mutable legacy getters synchronize through the private serial queue: `fileURL`, `isActive`, `recordedEventCount`, `writeFailureCount`, `degradedToMemory`, `fileCapacityReached`, `interruptionCount`, `staleRejectionCount`, `layoutCount`, `teardownCallbackCount`, and `cellReuseCount`. `stateSnapshot` returns the complete private `status` value at one queue admission. Separate scalar calls retain no multi-read atomicity promise.
- Lines 20-32 and 85-108: the snapshot contains only URL/scalar/flag values, with file-private setters; it neither exposes mutable session backing storage nor includes `memoryEvents`, file handles, or file contents. `configuration` is a private immutable `TelemetryConfiguration` value conforming to Sendable; `runID` is immutable. All post-initialization access to mutable `status`, `handle`, and `memoryEvents` is queue-confined, including deinitialization. These facts support the class's `@unchecked Sendable` rather than merely suppressing warnings. The existing event/configuration value definitions introduce no callback or mutable reference escape into this boundary.
- Lines 113-185 and 198-274: lifecycle, registration, log-description and private recording helpers use backing `status` directly inside queue work. Private helper call paths introduce no synchronized public-getter call, nested `queue.sync`, user callback, or new queue-cycle/deadlock path. Record still has one serial admission; it does not fetch a snapshot or copy the event buffer on each frame.
- Baseline comparison preserves begin/record/end guards and idempotence, unconditional registration while disabled/inactive, all stamps and optional explicit `cellReuseCount` precedence, JSON encoding/newline policy, filename generation, file close behavior, exact log strings, capacity threshold, and 10,000-event memory bound. Default OFF/configuration and event schema source also match the baseline manifest. Existing lifecycle behavior is preserved rather than expanded by this review.

### Catalog ownership and Bridge capture

- `AppCatalogAssembly.swift:78-85,109-121,204-216`: one immutable `CatalogRefreshTimings` pair is read and replaced under the existing NSLock. Both legacy scalar projections obtain that lock through `refreshTimings`. The writer uses the private backing value directly, so it does not recursively acquire the lock. Initial timings remain nil/nil.
- Pair publication remains after the same close/configuration-generation guard and within the same critical section as snapshot publication. `replaceRoots`, invalidation, close, root admission, cancellation checks and clocks are unchanged. Invalidation/close retain historical timings while hiding/rejecting obsolete snapshots/results. Failed accepted scans can update timings while retaining the previous snapshot, matching the old behavior.
- `PagingTelemetryBridge.swift:153-159`: one `refreshTimings` capture supplies both event durations. Revision assignment and event schema are unchanged. This provides coherence for the latest accepted timing pair only; it provides **no per-revision attribution, causality, or freshness guarantee** for a historical served revision.

### Nine new tests: logical validity and test-owned synchronization

- `TelemetrySnapshotTests.swift:6-119` covers detached values, disabled registration policy, capacity/end state, explicit/implicit reuse stamps, exact log text, degradation and legacy projections. Scalar-to-snapshot equality checks occur with writers idle. Fixtures use UUID-owned temporary directories and an owned blocker file; helpers register teardown before concurrent work.
- Lines 121-151,192-211: every concurrent iteration performs layout → reuse → stale → interruption → teardown → record in that order. At any one serial-queue snapshot, each later-stage completion has an earlier-stage completion, establishing `layout >= reuse >= stale >= interruption >= teardown`. With `run.begin` completed and no concurrent end, `recordedEventCount - 1 <= teardown` and the stated bounds follow. Layout increment/return is one queue operation, making receipts exactly a permutation of 1...300; final all-five counts and event totals are checked after `concurrentPerform` joins. The observation collector locks both mutable storage and reads; concurrent bodies create local events and do not mutate an unsynchronized test array or test-instance property. Touching legacy getters makes no assertion that those separate reads are one transaction.
- `CatalogTimingSnapshotTests.swift:10-103` covers initial/legacy values, accepted failed-scan history, invalidation/recovery, close retention and rejection of in-flight/future results. Held fake callbacks deliberately return success after invalidation/close, exercising the consumer generation fence.
- Lines 105-149: each round starts from one settled old pair, admits exactly one held publication, collects task-local reader arrays, awaits the writer and the complete task group, and only then starts another round. Therefore each of the 513 samples must be either that round's complete old pair or complete new pair. The assertion needs no relationship between injected scan duration and wall-clock refresh duration, no observed overlap, and no assumption that every round samples both values. It is a valid safety assertion, not proof of deterministic old-code failure.
- Lines 168-250: fake scanner queue/pending/closed/count state is lock-protected; pending callbacks are extracted under the lock and invoked outside it. Admission follows pending installation; timeout cleanup closes late admission, and normal paths release held callbacks before awaiting task completion. Readers use immutable Sendable pair values and local arrays; aggregation and `previous` mutation occur in the parent after joins. No test-owned data race or new lock-reentry path was found by source inspection. This is not a runtime race-detector result.

## Baseline and hash evidence

The unified source differences contain only the snapshot/confinement changes described above. Independently reversed those explicit changes **in memory**, without rewriting any source or baseline. All three reconstructions matched the supplied baseline bytes exactly, corroborating rather than simply trusting the inverse-proof booleans.

| Production baseline / reconstructed SHA-256 | Hash |
| --- | --- |
| TelemetrySession | `7ab77f258272a595054fcecbe1cd5b15ac73a685b58bfbb9c661c02b789452f2` |
| AppCatalogAssembly | `7070bdacc45f5d9f7067e2ae6f5a4afd797327b8dad03a3012d6e43e2879f6b7` |
| PagingTelemetryBridge | `f58154b182b584397e93edf23fedb06c13d252ecca2c4d19dcffeded0920f80c` |

Frozen and current-source SHA-256 values (all equal to `review-inputs.json`):

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingTelemetry/TelemetrySession.swift` | `af7edead95fd695435754b76f387b64df5184e3141f3c7c55a29823d4971c3e8` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `a0afe2c629c48d5d72d6917918b7964069c73d5b3cb69d2cdd2f70926f864d1b` |
| `Sources/PagingPrototypeApp/PagingTelemetryBridge.swift` | `7ea5fd04f515b9e0170f4ba46f3385c225e7b82c8a11273b4431d7e5b9ae690f` |
| `Tests/PagingTelemetryTests/TelemetrySnapshotTests.swift` | `81df0b6158b3acba057f744a4fa1b8dced28055ae7c46e0eefa53db9968e94f1` |
| `Tests/PagingUITests/CatalogTimingSnapshotTests.swift` | `ebf403710747781592a846dd76d1451db37c5f5401154db9ed2907ade4cdf3d9` |
| `Docs/DIAGNOSTIC_SNAPSHOT_OWNERSHIP_SPEC.md` | `e87c5fd01ca8205e629cff7616242bd4abdfaf31c5dde4d1400e325bc4688896` |

| Supporting artifact | SHA-256 |
| --- | --- |
| `review-inputs.json` | `a398afdf9318cf9cb010f6c1def080f6ed109319d03aee074b21579be5b0837c` |
| `baseline-inputs.json` | `dc6cb7fe0046f85770edec40190c6a354fede91aac55e20bbb8526fadfdae894` |
| `session-inverse-proof.json` | `24bd4ccf8abd6ccf2bb16b97aae8b386c5dce3e85ccdbd5e7088e7d66da5d2d5` |
| `catalog-inverse-proof.json` | `227517e90f829306b4fb5a56eedbf6f910cafbf62cdbf853113ac650068ccc83` |

## Acceptance limit

PASS applies only to the reviewed hashes and the stated source/test-source correctness contract. It does not close the full specification's execution gates, certify compilation or TSan, establish native/physical acceptance or full parity, renew hitch profiling, or certify general diagnostic/performance behavior. A changed frozen input requires renewed review of the affected scope.
