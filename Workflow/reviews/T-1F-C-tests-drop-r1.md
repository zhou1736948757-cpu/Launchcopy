# T-1F-C-tests-drop — Review r1

Verdict: **PASS**

## 1. Matrix coverage — PASS
- consume accept: top-level (DragDropTests.swift:54) + folder scope (:65), consumed=true asserted.
- consume reject: invalidToken / tokenConsumed / staleLayout / staleCatalog / sourceMissing / targetMissing (3 sub-cases: insertion OOB, createFolder unknown, intoFolder unknown) / .invalid → .targetMissing (:82–166).
- zones: insertion first/middle/last exact geometry (:170), app-center 1/3 strip (:183), folder-cell from itemFrames+topLevelFrames (:195), moveOutArmed gating (:204).
- classify: createFolder vs own-center, insertion, folder-source invalid (cell+center), member move-out topLevelTarget, intoFolder (app+member source), unarmed inner insertion (:218–320).
- engine M1/M2/M3 (target-then-source, min-index, "Group 1")/M4 (into + cross-folder atomic dissolve)/M5 (dissolve/delete/keep)/folder-internal reorder — all assert new layout + generation +1 (:324–478).
- engine rejections: invalidTarget/duplicateReference/nestedFolder/folderDoesNotExist/memberNotFound/topLevelEntryNotFound, original layout unchanged (:485–578).

## 2. Test quality — PASS (semantics verified against source)
- All zone geometry matches DropZoneBuilder exactly (margin 8, 80×80 frames at x=0/100/200, containerWidth 400, strip=80/3; DropIntent.swift:79–152).
- All classifier expectations match DropZoneClassifier branches (DropIntent.swift:159–209); all engine expectations match LayoutMutation (LayoutMutation.swift:68–314).
- Finding ① CONFIRMED: DropResolver.swift:41 guard targetStillValid precedes :42 intent != .invalid, and targetStillValid(.invalid) returns false (:77–78) → .invalidDropTarget unreachable; test asserts .targetMissing with comment. Correct.
- Finding ② CONFIRMED: DragMutationEngine.swift:17 always passes layout.generation as expectedGeneration → staleGeneration structurally unreachable at engine entry; documented in test comment. Correct.
- No tautologies; rejection-reason equality via assertRejected helper.

## 3. Privacy — PASS
Only fixture.* bundle IDs, "app1"–"app4", "Group 1/2", neutral zero-padded UUIDs. No real app names/bundle IDs/paths.

## 4. Scope — PASS
Only new Tests/AppGridUITests/DragDropTests.swift (08:56:58) + Workflow/results/T-1F-C-tests-drop.md (08:57:38) from this worker. All Sources/AppGridUI/DragSession/* predate window (latest 05:15:14). DragSessionControllerTests.swift (08:50:37) is the sibling T-1F-C-tests-session worker's deliverable (its result: 21 tests, baseline 886+21=907 — explains 907 baseline vs stale 837 in task packet). LayoutStore source edits belong to earlier T-1F-B repair tasks.

## 5. Executed count — PASS
- `swift build -c debug` → Build complete, exit 0.
- `swift test` → **Executed 946 tests, with 0 failures (0 unexpected)**, exit 0 (907+39=946 ✓). Filtered DragDropTests: 39/39, 0 failures.
- `swift build -c release` → Build complete, exit 0.

## Minor (non-blocking)
Worker result per-section counts mislabel classify 10 (actual 11) and engine-reject 7 (actual 6); total 39 correct.
