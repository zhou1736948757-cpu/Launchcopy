# T-1E-folderlab-keep-ungrouped-repair

- Status: OPEN
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback)

## Evidence (user real-GUI)

User: "还有就是你记得要留点APP用来翻页用。" — with --folder-lab, all 140 catalog apps are grouped (140/35 = Group 1-4), so the top level has ZERO ungrouped app entries; the user cannot test top-level paging (no app entries to page across). Top level must keep some apps ungrouped so paging remains exercisable.

## Root cause

Sources/AppGridUI/FolderLabFixture.swift makeGroups(from:configuration:generation:) groups the FIRST N apps per group (default groupSize 35) with no cap on group count and no ungrouped reserve → with 140 apps, 4 groups consume everything, ungrouped = 0.

## Fix (Worker)

Change the lab grouping rule so the LAST `groupSize` (35) apps are always left ungrouped:

- makeGroups groups only the first `max(0, count - groupSize)` apps (stable catalog order, groupSize per group, neutral titles "Group N", fresh FolderID per group), leaving the trailing `groupSize` apps ungrouped.
- Deterministic, session-only, no I/O, no persistence. Default off (enabled only via --folder-lab).
- Keep existing defensive behavior (groupSize <= 0 → nil).

## Tests (Worker)

Update/extend Tests/AppGridUITests/FolderLabFixtureTests.swift:

- 140 apps → 3 groups (105 grouped) + 35 ungrouped apps (top-level = 3 folders + 35 apps = 38 entries → 2 pages at itemsPerPage 35, paging exercisable).
- count == groupSize (35) → 0 groups, all 35 ungrouped.
- count == 2*groupSize (70) → 1 group + 35 ungrouped.
- count < groupSize → 0 groups, all ungrouped.
- Existing tests updated to the new rule (any that assumed all apps grouped).

## Write scope

- Sources/AppGridUI/FolderLabFixture.swift
- Tests/AppGridUITests/FolderLabFixtureTests.swift

## Forbidden

- All frozen trees (Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift)
- AppDelegate.swift, AppCatalogAssembly.swift (wiring already correct — generator is invoked; only the grouping rule changes)
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Acceptance

- swift test: executed > 0, 0 failures, exit 0 (baseline 758 → expect +N new/updated)
- swift build -c debug: exit 0; swift build -c release: exit 0
- Frozen trees untouched (mtime check)
- Result file: Workflow/results/T-1E-folderlab-keep-ungrouped-repair.md
