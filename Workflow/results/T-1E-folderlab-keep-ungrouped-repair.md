# T-1E-folderlab-keep-ungrouped-repair — Worker result

- Status: DONE
- Worker: T-1E repair (keep ungrouped)
- Date: 2026-08-30

## What changed

`Sources/AppGridUI/FolderLabFixture.swift` — `makeGroups(from:configuration:generation:)` now leaves the LAST `groupSize` (35) apps ungrouped:

- Groups only the first `max(0, count - groupSize)` apps (stable catalog order, `groupSize` per group, neutral titles `Group N`, fresh `FolderID` per group).
- Trailing `groupSize` apps stay ungrouped → top level always retains ungrouped app entries, so top-level paging stays exercisable.
- Deterministic, session-only, no I/O, no persistence. Default off (enabled only via `--folder-lab`).
- Defensive behavior preserved: `groupSize <= 0` → `nil`; empty catalog → empty snapshot.

## Tests

`Tests/AppGridUITests/FolderLabFixtureTests.swift`:
- Updated `testEnabledGroupsByStableOrder` (5 apps @ 2/组 → 2 groups, trailing 2 ungrouped).
- Added: 140 apps → 3 groups (105 grouped) + 35 ungrouped; count == 35 → 0 groups all ungrouped; count == 70 → 1 group + 35 ungrouped; count < 35 → 0 groups all ungrouped.

## Deviation (documented)

`Tests/PagingUITests/FolderIntegrationTests.swift` had two tests that assumed ALL apps grouped (outside the nominal write scope). They are exactly the "existing tests that assumed all apps grouped" the task says to fix, and they blocked the 0-failures acceptance. Minimal fixes:
- `testFolderLabWiringGeneratesFolderSnapshot`: 6 apps @ 2/组 → expected folderCount 3 → 2 (first 4 grouped, trailing 2 ungrouped).
- `testFolderLabFlagWiringProducesNonEmptySnapshot`: fixture 4 apps → 40 apps (default groupSize 35 → 1 group, non-empty).

No other files touched. No frozen trees touched.

## Verification

- `swift test`: **Executed 762 tests, 0 failures, exit 0** (baseline 758 + 4 new).
- `swift build -c debug`: exit 0.
- `swift build -c release`: exit 0.
- Frozen trees mtime check: unchanged (PagingCore, AppCatalogCore, MacAppCatalog, AppIconPipeline, PagingTelemetry, PagingUI, AppLaunchController.swift, Package.swift, AppDelegate.swift, AppCatalogAssembly.swift).

## Privacy

No app names / bundle IDs / paths / URLs / folder titles in telemetry, JSONL, stdout, signpost, profile, or report. Titles remain neutral `Group N`.
