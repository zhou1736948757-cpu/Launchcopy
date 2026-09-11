# T-1F-B-codec-folder-duplicate-repair — Results

Status: PASS

## Plan
- Read the 3 in-scope files (LayoutStoreCodec.swift, LayoutStore.swift, LayoutStoreCodecTests.swift).
- Fix `validateStructure` in LayoutStoreCodec.swift: top-level folder entries keep UUID validity check but stop inserting into `seenFolderIDs`; folders loop keeps uniqueness ownership.
- Optional hardening: top-level folder entries must exist in `envelope.folders` (dangling reference → false).
- Append 1-2 regression tests to LayoutStoreCodecTests.swift: folder-containing layout round-trip decode = .loaded; dangling top-level folder → .corrupt.
- Verify serially: `swift build -c debug`, `swift test`, `swift build -c release`; update this file with results and Status: PASS.

## Summary
Fixed the real defect in `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` `validateStructure` (~:205-233): `seenFolderIDs` was shared between the top-level entry loop and the folder-records loop, so any layout containing a folder decoded as `.corrupt` (the legitimate top-level-folder + folder-record pairing failed the second insert).

Changes (write scope only, 2 files):
- `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` (validateStructure only): top-level folder entries keep the `UUID(uuidString:)` validity check but no longer insert into `seenFolderIDs`; folder uniqueness is owned exclusively by the folders loop. Hardening implemented: top-level folder entries must exist in `envelope.folders` records (`recordFolderIDs.contains(folderID)`), so a dangling top-level folder reference → false → `.corrupt`. Folders loop unchanged (UUID check + `seenFolderIDs.insert(record.id)` uniqueness + member dedup + global ref uniqueness). Header comment untouched (semantics unchanged per packet item 4).
- `Tests/AppGridUITests/LayoutStoreCodecTests.swift` (appended 2 regression tests):
  - `testRoundTripFolderContainingLayoutIsValid`: legitimate layout with top-level folder entry + paired folder record (2 members) round-trips encode → decode = `.valid`, layout and writeGeneration preserved. Fails on the old shared-set implementation.
  - `testTopLevelFolderWithoutRecordIsCorrupt`: hand-built envelope with valid-UUID top-level folder entry and no folder record → `.corrupt` (dangling reference hardening).

No other files touched; no git operations; all fixtures use neutral fake data ("com.example.appN" / "Group 1").

## Test count
873 total (871 baseline + 2 new), 0 failures, 0 unexpected.

## Verification outputs
1. swift build -c debug: exit 0 — "Build complete! (21.78s)"
2. swift test: exit 0 — "Executed 873 tests, with 0 failures (0 unexpected) in 19.944 (20.071) seconds"; "Test Suite 'All tests' passed"
3. swift build -c release: exit 0 — "Build complete! (52.73s)"
