# T-1E-folderlab-keep-ungrouped-repair — Reviewer r1

- Reviewer: independent (chef-worker-reviewer-workflow)
- Date: 2026-08-30
- Scope: verify the "keep last groupSize apps ungrouped" repair
- Verdict: **PASS**

## Verification performed (independent, not trusting Worker self-report)

1. Read task packet, Worker result, and all three touched files.
2. Re-derived the grouping math from `Sources/AppGridUI/FolderLabFixture.swift` `makeGroups`.
3. Ran the full suite and both builds myself.
4. Checked frozen-tree mtimes and the working-tree change set.

## Findings

### BLOCKER
None.

### MAJOR
None.

### MINOR
- **M1 — Integration-test edits are outside the nominal write scope (documented deviation).**
  `Tests/PagingUITests/FolderIntegrationTests.swift` is not in the packet's write scope
  (only `FolderLabFixture.swift` + `FolderLabFixtureTests.swift`). The Worker changed two
  tests there. This is justified: the packet itself says "Existing tests updated to the new
  rule (any that assumed all apps grouped)", and these two tests assumed all apps grouped and
  would otherwise fail the 0-failures acceptance. The edits are minimal and correct:
  - `testFolderLabWiringGeneratesFolderSnapshot` (L94): 6 apps @ 2/组 → `folderCount` 3→2.
    Re-derived: groupableCount = 6−2 = 4 → Group 1 (idx 0–1), Group 2 (idx 2–3), trailing
    idx 4–5 ungrouped → 2 folder entries. Correct.
  - `testFolderLabFlagWiringProducesNonEmptySnapshot` (L158): fixture 4→40 apps. Re-derived:
    groupableCount = 40−35 = 5 → 1 group (non-empty). Correct.
  No other test in the suite assumed all-apps-grouped (verified by grep: the only other
  groupSize-2 consumer, `testFolderCellMemberCountWiredFromServedSnapshot`, reads
  `entries.first` with `expectedCount >= 2` and still passes under the new rule).

### QUESTION
None.

## Acceptance-criterion results

1. **Grouping rule matches packet** — PASS.
   `makeGroups` groups only the first `max(0, count − groupSize)` apps (stable catalog order,
   `groupSize` per group, neutral `Group N` titles, fresh `FolderID` per group), leaving the
   trailing `groupSize` apps ungrouped. Deterministic, session-only, no I/O, no persistence.
   Default off (`defaultEnabled = false`; `enabled == false` → `nil`). Defensive behavior kept:
   `groupSize <= 0` → `nil`; empty catalog → empty snapshot. (FolderLabFixture.swift L51–69.)

2. **New tests assert correct math** — PASS.
   - 140 apps @ 35 → 3 groups (105 grouped) + 35 ungrouped = 38 top-level entries → 2 pages
     at itemsPerPage 35 (paging exercisable). Test asserts 3 groups, 35 members each, titles
     Group 1–3, indices 0–104 grouped, 105–139 ungrouped. Correct.
   - 35 apps → 0 groups, all ungrouped (empty snapshot). Correct.
   - 70 apps → 1 group + 35 ungrouped. Correct.
   - 20 apps (< 35) → 0 groups, all ungrouped. Correct.
   - `testEnabledGroupsByStableOrder` updated: 5 apps @ 2 → 2 groups, trailing 2 ungrouped.
     Correct.
   The 2 integration-test adjustments are minimal and consistent with the new rule.

3. **Full suite + builds** — PASS (run by me).
   - `swift test`: **Executed 762 tests, 0 failures (0 unexpected), exit 0** (baseline 758 + 4
     new = 762, matches Worker report).
   - `swift build -c debug`: exit 0.
   - `swift build -c release`: exit 0.

4. **Frozen trees untouched** — PASS.
   mtimes of Sources/PagingCore, Sources/AppCatalogCore, Sources/MacAppCatalog,
   Sources/AppIconPipeline, Sources/PagingTelemetry, Sources/PagingUI, Package.swift,
   Sources/PagingPrototypeApp/AppLaunchController.swift all predate this repair (17:15).
   AppDelegate.swift (17:12:49) and AppCatalogAssembly.swift (17:12:46) also predate this
   repair (touched by the earlier enable/membercount repairs, not this one). Only the 3
   expected files changed (FolderLabFixture.swift 17:15:27, FolderLabFixtureTests.swift
   17:15:33, FolderIntegrationTests.swift 17:16:30). Note: repo has no tracked git history
   (all files untracked), so frozen-tree verification used mtime + content reads.

5. **No git ops / privacy / params** — PASS.
   No git operations performed by Worker (no tracked history to mutate). No telemetry/schema
   change (only AppGridUI fixture + tests touched). Folder titles remain neutral `Group N`;
   no raw app names/bundle IDs/paths/URLs/folder membership in telemetry/logs. Timer
   tolerance / paging params / frame source unchanged (no such files touched).

## Conclusion

The repair correctly implements the "leave the last groupSize apps ungrouped" rule, the new
tests assert the right math, the two integration-test adjustments are minimal and justified,
the full suite (762 tests) and both builds pass, and all frozen trees are untouched. The only
finding is a MINOR documented deviation (integration-test edits outside nominal write scope)
that the packet itself anticipated and that is correct.

VERDICT: PASS
