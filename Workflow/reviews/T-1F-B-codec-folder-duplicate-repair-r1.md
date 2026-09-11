# T-1F-B-codec-folder-duplicate-repair — Review r1

**Verdict: PASS**

## Fix-correctness confirmation

`Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` `validateStructure` (:205-238):
- (a) Top-level folder entries keep `UUID(uuidString:)` validity check (:220) and no longer insert into `seenFolderIDs` — the top-level loop (:214-225) never touches `seenFolderIDs`; only the folders loop does (:229). ✓
- (b) Folders loop remains sole owner of folder-ID uniqueness: `seenFolderIDs.insert(record.id).inserted` (:229), plus member dedup and global ref uniqueness (:230-235). ✓
- (c) Hardening implemented: `recordFolderIDs = Set(envelope.folders.map(\.id))` (:212) + `guard recordFolderIDs.contains(folderID)` (:221) → dangling top-level folder → false → `.corrupt`. ✓
- (d) Changes localized to `validateStructure`; header comment (:8) untouched (semantics unchanged, packet item 4). No git baseline exists (repo has no tracked files), so "nothing else changed" rests on mtime evidence + content review.

Edge case checked: duplicate top-level folder entries with a matching record are no longer rejected by `validateStructure` itself, but are caught by `WorkspaceLayoutValidator` (`WorkspaceInvariants.swift:94`) at both encode (`assertValid`) and decode (:142) — uniqueness model is sound end-to-end. Existing `testDuplicateTopLevelFolderEntriesAreCorrupt` still passes (now via the dangling check).

## Regression tests (`Tests/AppGridUITests/LayoutStoreCodecTests.swift`)

- `testRoundTripFolderContainingLayoutIsValid` (:95-110): folder layout (top-level folder entry + paired 2-member record) round-trips to `.valid`, layout + writeGeneration preserved. Would fail on old shared-`seenFolderIDs` code. **Passed.**
- `testTopLevelFolderWithoutRecordIsCorrupt` (:197-202): hand-built envelope, valid-UUID top-level folder entry, no record → `.corrupt`. **Passed.**
- Both use neutral fake data ("com.example.appN" / "Group 1" / synthetic UUIDs). Only additions to the file (task markers at :93, :195).

## Scope compliance

- Only the 2 write-scope files modified: `LayoutStoreCodec.swift` (08:14:54) and `LayoutStoreCodecTests.swift` (08:15:01) — the only Sources/Tests files inside the repair window (task packet 08:12:54 → result 08:17:31); next-newest is `EdgePagingScheduler.swift` 05:15:14 (3h before).
- Frozen trees (PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift): zero files newer than the task packet; Package.swift 08-28 20:42, AppLaunchController.swift 08-28 21:46. Untouched. ✓

## Verification outputs (run serially from project root)

1. `swift build -c debug` → **exit 0** — "Build complete! (3.48s)" (incremental; Worker's 21.78s was cold).
2. `swift test` → run 1: "Executed 873 tests, with 5 failures (0 unexpected)" (exit 1); run 2: "Executed 873 tests, with 0 failures (0 unexpected) in 39.866 (40.292) seconds", "Test Suite 'All tests' passed" (exit 0). Both new regression tests passed in both runs. 873 = 871 baseline + 2 new; not a 0-executed run.
3. `swift build -c release` → **exit 0** — "Build complete! (0.45s)" (incremental).

## MINOR notes

1. Run 1's 5 failures were all in one test, `PagingUITests.RunLoopFrameDriverTests.testStartIsIdempotentAndPumpCompletesSettleThenTeardownStops` (real-runloop timing test, outside write scope). It passes in isolation (1/1) and the full suite passes on re-run (873/0) — load-sensitive flake, not a regression. Worker's "0 failures" claim is reproducible on re-run.
2. No byte-level baseline diff possible (no git history); scope verified via mtimes + content review.
3. Packet's "顶层 folder 条目的唯一性由 folders 循环独占保证" holds only with the domain validator's duplicate-entry check; confirmed present.
