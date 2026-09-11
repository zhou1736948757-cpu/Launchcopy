# Review T-1F-B-tests-actor-r1 — LayoutStoreActorTests 交付审核

- Reviewer: independent (read-only; no implementation files touched)
- Deliverable: `Tests/AppGridUITests/LayoutStoreActorTests.swift` (12 tests, 473 lines)
- Reference: `Sources/AppGridUI/LayoutStore/LayoutStore.swift`, `LayoutStoreActor.swift`, `LayoutStoreCodec.swift`, `LayoutStoreIO.swift`, `LayoutDomain/PersistentWorkspaceLayout.swift`
- Verdict: **PASS**

## 1. Matrix coverage (13/13)

| # | Matrix item | Test |
|---|---|---|
| 1 | 首启 | `testFirstLaunchEmptyDirectoryReturnsFirstLaunch` |
| 2 | save-load-restart 往返 | `testSaveLoadRestartRoundTripPreservesLayoutAndGeneration` |
| 3 | 原子替换 | `testAtomicReplaceLeavesNoTempFilesAndDecodesAsLoaded` |
| 4 | 中断写只读保护 | `testInterruptedWriteTriggersReadOnlyProtectionAndPreservesEvidence` |
| 5 | 主槽坏+备槽有效 | `testPrimaryCorruptBackupValidLoadsFromBackup` |
| 6 | 双槽损坏 | `testBothSlotsCorruptTriggersReadOnlyProtection` |
| 7 | 写失败 degrade+recover+LKG | `testWriteFailureDegradesThenRecoversAndKeepsLKG` |
| 8 | coalescing latest-wins | `testCoalescingLatestWinsPersistsHighestGeneration` |
| 9 | flush barrier 幂等 | `testFlushBarrierWaitsAndIsIdempotent` |
| 10 | reset 归档+清空+持久化 | `testResetArchivesClearsAndPersistsDefaultLayout` |
| 11 | 未知未来版本绝不覆盖 | `testUnknownFutureVersionNeverOverwritten` |
| 12 | 多实例 last-writer-wins+stale | `testMultiInstanceLastWriterWinsAndStaleRejection` |
| 13 | 全部 temp roots | structural: `makeTempStoreDirectory()` (temporaryDirectory+UUID per test) + `tearDown` cleanup |

## 2. Test quality — real behavior, matches FIXED semantics

Each test manually traced against `LayoutStoreActor.swift` (post-repair):

- **Test 4 (interrupted write)** exercises the `hasLoaded=true` fix: after `load()` → `.readOnlyProtection(.bothSlotsCorrupt)` (source: `(.corrupt, .absent)` → quarantine + `setReadOnly`), `enqueue` is a no-op and `currentState()` stays readOnlyProtection — a re-run of `ensureLoaded` would have re-classified state and broken the assertion. Evidence quarantine verified: 1 `.corrupt-*` file, bytes unchanged, temp cleaned.
- **Test 7 (write failure)** exercises the labeled-`break drain` fix: with `FaultInjectingIO` failing, `flush()` returns `.failed` (not `.timedOut` — the pre-fix symptom of `isPersisting` never resetting), state `.persistenceDegraded(.writeFailed)` (retryCount pattern-matched loosely), LKG preserved (`maxPersistedLayoutGeneration == 1`); after `failWrites = false`, `flush()` returns `.persisted` and state `.healthy`, disk gen 2. Matches fixed `flush()`/`runPersistLoop()` semantics exactly.
- Test 9 asserts `.nothingPending` after enqueue+flush — real implementation semantics (loop drains pending before barrier check), with `maxPersistedLayoutGeneration == 1` proving the write landed; not a tautology.
- Test 12 verifies real flock behavior: second actor on same dir → `.lastWriterWins`; same-generation enqueue → `.staleRejected` (count 1); higher generation lands (wg 2, slot B via rotation).
- Test 11: schemaVersion 99 → codec `.unknownFutureVersion(99)` (codec: `envelope.schemaVersion > schemaVersion`), enqueue no-op, slot bytes byte-identical.
- All APIs used by tests verified against sources: `LayoutStoreCodec.encode(_:writeGeneration:)`/`decode`/`DecodedLayout`, `LayoutStoreIOError.writeFailed`, `LayoutStoreIO` 10-method protocol, `FileManagerLayoutStoreIO`, `PersistentAppReference.bundleID`, `FolderID(uuid:)`, `LayoutGeneration(_:)`, `PersistentWorkspaceLayout(generation:topLevelOrder:folders:)`, `PersistentFolderRecord(id:title:members:)`.

## 3. Privacy

Only neutral fake data: `fixture.alpha` / `fixture.beta` bundle IDs, `"Group 1"`, fixed UUID `00000000-0000-0000-0000-0000000000A1`. No real app names/bundle IDs/paths in test names, fixtures, or output. Debug prints emit only result enums and neutral `lastPathComponent` names.

## 4. Scope (mtimes)

- `Tests/AppGridUITests/LayoutStoreActorTests.swift` 2026-08-31 08:31:58 — **predates** repair window 08:39:16→08:43:34 ✓
- `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` 08:42:54 — inside repair window (repair wave's change, not this task) ✓
- `Sources/AppGridUI/LayoutStore/LayoutStore.swift` 01:55:32 — untouched ✓
- `Workflow/results/T-1F-B-tests-actor.md` 08:22:05 — predates repair window ✓
- Repo has no git history (fully untracked); mtimes are the authoritative scope evidence. No source file modified by this task.

## 5. Verification runs (serial, project root)

1. `swift build -c debug` → exit 0 ✓
2. `swift test` → **885 tests, 0 failures** (13.3s); `--filter LayoutStoreActorTests` → **12/12, 0 failures** ✓
3. `swift build -c release` → exit 0 ✓

## Findings

- **MINOR**: leftover debug `print("DBG4…")` (×5) / `print("DBG7…")` (×4) in tests 4 and 7 pollute test output. Neutral content only; no correctness or privacy impact. Recommend removal in a future cleanup, not required for acceptance.
- **MINOR (runtime artifact)**: `Workflow/results/T-1F-B-tests-actor.md` still `Status: in progress` — the Worker exhausted context before updating it. Not a deliverable defect; Main should close the result file.

## Verdict

**PASS** — all 13 matrix items covered; assertions exercise real post-repair behavior (both regression tests would fail against the pre-repair source); privacy-clean; scope clean; all three verification commands green (885/0, actor 12/12).
