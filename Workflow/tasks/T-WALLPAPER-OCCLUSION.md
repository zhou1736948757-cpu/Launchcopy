# T-WALLPAPER-OCCLUSION

## Objective
Fix the black launcher backdrop without changing paging physics, input, reuse, or wallpaper decoding. Test the intervening PageHostView fill as the primary hypothesis before patching.

## Expected / Allowed Write Scope
- Sources/PagingUI/PageHostView.swift
- Tests/PagingUITests/PageHostBackdropTests.swift (new)
- Workflow/results/T-WALLPAPER-OCCLUSION.md
- Workflow/artifacts/T-WALLPAPER-OCCLUSION/ (test logs and synthetic images only)

## Acceptance
1. Reproduce occlusion using a synthetic saturated backdrop under the real page host; show fail-before/pass-after, preferably rendered pixels rather than only property assertions.
2. Small coherent fix: transparent presentation host; preserve neutral laboratory chrome where needed and preserve renderer/reuse contracts. No wallpaper provider or window architecture rewrite without evidence.
3. Check resize/reuse/custom renderer and neutral rendering. Keep input handling unchanged.
4. Run targeted tests; save commands, counts, logs, limits. Never read real wallpaper paths/pixels for the synthetic test.
5. No Package.swift/PagingCore/AppDelegate/packaging changes, process termination, publishing, signing, or LaunchBetter/Buho access.
6. Independent Reviewer required before completion; user physical acceptance remains separate.

## Runtime decision and concurrency
User said "你直接修复吧" after Main proposed sol/high Worker and independent Luna/max review. Use that task-scoped override only; do not change config.json. Main is the current conversation; Chief is not needed for this bounded existing-contract repair. One Worker owns the tightly coupled host/test patch; Reviewer follows stable evidence. Shared SwiftPM runs serialized. Main concurrently inspects non-overlapping delivery/safety paths.

## Baseline
Live recheck supersedes previous-turn no-commit assumption: HEAD is 6382bd9 (Initial public import of Launchcopy), main tracks origin/main. Before source stored in Workflow/artifacts/T-WALLPAPER-OCCLUSION/PageHostView.before.swift. Preserve all unrelated changes. Read handoff Workflow/results/2026-09-11-wallpaper-backdrop-bug-handoff.md but do not accept its hypothesis as proof.
