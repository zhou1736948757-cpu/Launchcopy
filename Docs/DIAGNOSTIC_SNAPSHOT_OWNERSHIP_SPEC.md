# Coherent diagnostic state snapshots

Date: 2026-10-20. Bounded correctness follow-up to the approved whole-code review. Not renewed hitch profiling.

## Problem and outcome
Catalog timing writers use NSLock while legacy public getters read unguarded. TelemetrySession writes through a private serial queue but exposes unsynchronized mutable-state getters. Prevent read/write races and coherent-pair drift while preserving existing diagnostics/defaults/privacy.

## Scope / design
- Keep the two owners separate: CatalogRepositoryDataSource uses its existing NSLock; TelemetrySession uses its existing private serial queue. No generic synchronization/store framework.
- Add value CatalogRefreshTimings (scanDurationMS, refreshDurationMS); one lock-protected refreshTimings read and atomic pair publication under existing generation/close checks. Legacy duration getters remain source-compatible, synchronized scalar projections. Bridge reads the pair once, not separate fields.
- Add a value TelemetrySessionSnapshot containing only existing mutable scalar/flag/fileURL state, not memory events or file contents. All legacy getters synchronize. Keep one private queue-owned state value; queue-internal methods read/write backing fields directly, never recursively call public synchronized getters. Existing immutable runID/configuration remain immutable. If Sendable conformance is added, justify it from complete private queue confinement, not as warning suppression.
- Preserve JSONL schema/stamps/filenames/defaultOFF/capacity/memory bounds and exact logPathDescription strings. No new measurement, telemetry field, probe, output trigger, timing clock or asynchronous writer. Register methods retain existing disabled/inactive behavior; begin/record/end retain their own existing guards.
- Snapshot is a single owner's current state at one linearization point. Separate scalar getter calls are not an atomic multi-read. Latest catalog timings are NOT newly attributed to a historical served revision; no per-revision receipt/history redesign. Do not claim causality or freshness beyond this contract.
- No per-frame memory-array copy or extra nested queue synchronization: recording uses existing one serial admission and direct private state. Current production callers mostly read individual totals at end-of-run; keep that API.

## Verification and acceptance
Owned temporary fixtures only; injected scanner/source tests and concurrent snapshot/counter reads. Check coherent counter inequalities (same-owner ordered registration prefixes), unique increment receipts, exact final counts, startup/disabled/capacity/degraded/end flags, log/JSONL compatibility and no queue recursion/deadlock. Catalog tests must distinguish atomic pair reads from separately read scalar values; preserve root/configuration stale-result fences.
Run focused/full tests, Debug/Release unsigned isolated package and diff serially on frozen inputs. Attempt targeted ThreadSanitizer in a separate scratch directory if supported, record exact execution or platform limits without substituting it for semantic tests. Independent bounded review before final closure. No deterministic old-RED claim is required for the source-established read/write race; don't fabricate a racy reproduction. No native/physical/performance/first-hitch improvement claim.

## Ownership and boundaries
Main owns TelemetrySession.swift and new Tests/PagingTelemetryTests/TelemetrySnapshotTests.swift; worker owns only AppCatalogAssembly.swift timing section, PagingTelemetryBridge.swift pair read, and new Tests/PagingUITests/CatalogTimingSnapshotTests.swift. No concurrent SwiftPM; maximum3agents includingMain. Later independent read-only reviewer owns a report. Preserve all dirty changes and earlier icon/Core repairs. No Core/physics/default/schema/visual/reference/formal-data/OS/UI/process-signal/install/sign/Git mutation. Existing automated suites may use owned temporary fixtures. Runtime fd395b00 untouched; latest2094facf package unlaunched. Full parity remains incomplete; prior goal turn was concrete takeover repair progress.
