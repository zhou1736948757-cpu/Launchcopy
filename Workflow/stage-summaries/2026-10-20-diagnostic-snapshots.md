# Coherent diagnostic snapshots — 2026-10-20

## Objective / baseline
Repair source-established unsynchronized public reads in catalog timing and telemetry session state. This does not reopen the user-deferred first Library hitch, add probes or establish CPU causality. Prior takeover stage548inputs/235focused/3357full/0/builds/package/r1boundedPASS;2094facf package unlaunched, fd395b00 runtime untouched. Baseline hashes/3source copies under .build/verification/20261020/diagnostic-snapshots/.

## Spec / ownership
Docs/DIAGNOSTIC_SNAPSHOT_OWNERSHIP_SPEC.md. Main Session+newSessiontests; disjoint worker Catalog timing+Bridge+newtimingtests; later independent read-only review. Max3includingMain, serial tests. Preserve existing NSLock vs serialqueue ownership; no generic framework. Avoid nested queue.sync from insidequeue and avoid copying memory buffers on frame records. Legacy getter APIs remain, pair/snapshot explicit for atomic reads.

## Evidence / limits
No new validation yet. Need focused/full/concurrent/ownedfixture/optionalTSan/builds/package/diff and boundedreview. Latest timing snapshots do not solve historical-revision attribution. No native/performance/OS/reference/formal-data action. No Core/physics/visual/default/event-schema change.

## Next action
Implement queue-owned Session status and lock-owned Catalog pair, verify exact stamp/log compatibility and concurrent reads, then freeze for final serial validation. Whole parity remains active/incomplete.

## Implementation / first validation
Main Session has one private queue-owned11field status value plus synchronized legacy projections/current snapshot; internal queue work reads backing state directly. Sendable justified by immutable configuration/runID and full private queue confinement, not warning suppression. Worker Poincare changed only Catalog timing pair/Bridge/new5tests thenclosed. Exact inverse proofs reconstruct original Session lifecycle/stamp/log bytes and whole Assembly/Bridge other bytes, including icon/scan generation/clock policy. Existing Session/extension/privacy38/0; new4Session+5Catalog methods9/0. Frozen review packet6inputs. No new probe/event/schema/default/UI/Core/native action; latest-vs-historical timing attribution remains unchanged.

## Independent review / sanitizer execution
Linnaeus bounded source/test-source PASS on exact6frozeninputs, independently reconstructs all3production baselines in memory. Verifies all11legacy getters/backing confinement, no nested queue.sync, legitimate Sendable, unchangedlog/stamp/default/capacity semantics, valid prefix inequalities/unique receipts and old/new pair membership. No execution/native/performance certification. Reviewer closed; worker previouslyclosed, no activeagents. Targeted ThreadSanitizer is live in separate scratch with2compilerjobs; normal runner prepared but not run concurrently. Exact sanitizer result/triage required before final normal verification.

## Sanitizer gate passed
ThreadSanitizer separate-scratch run:9tests/0failures/exit0, no reportedrace;550frozeninputs unchanged. Read-only otool linkage confirms libclang_rt.tsan runtime in the actual test bundle; no customTSAN_OPTIONS present. Receipts tsan-result.json, tsan-command.json, tsan-inputs.json, tsan-linkage.json/log; no runtime-option/suppression modification. This validates exercised target paths, not universal race freedom or performance. Normal focused/full/Debug/Releasepackage/diff now runs serially after sanitizer completion. No source/test edits after freeze; no extra probes, current app untouched.

## Final closeout
Frozen550inputs focused85/0/full3366/0/Debug/Releasepackage/diff, plus linked-runtime ThreadSanitizer9/0/no race reports on sameinputs. Independent source/test-sourcePASSr1, inverse3file proofs, allagentsclosed/alljobs terminal. NewcandidateSHA2f534bff0c9082035eb6d741af94821298e5d2fa87d21e35599acdbcbe7cc4ba unsigned/uninstalled/unlaunched; oldfd395b00 runtime onlyprocesschecked, not replaced. No new probes/default/schema/physics/visual changes. Latest-vs-historical timing attribution remains unchanged; no universal race/native/performance/CPU-causality claim. This bounded diagnostic P2 closed; remaining architecture/functional/native/device gates remain open.
