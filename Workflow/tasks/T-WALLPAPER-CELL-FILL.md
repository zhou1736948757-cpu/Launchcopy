# T-WALLPAPER-CELL-FILL

## Objective
Continue wallpaper repair: the user reports dark boxes behind apps. Main's live screenshot of the prior candidate now confirms visible blurred wallpaper and individual opaque rounded cell rectangles. Remove idle cell fill while preserving keyboard-focus indication, hit regions, folder identity, layout, and reuse.

## Expected / Allowed Write Scope
- Sources/AppGridUI/AppGridCellView.swift
- Sources/AppGridUI/AppGridCellFocus.swift
- Tests/AppGridUITests/CellBackdropTransparencyTests.swift (new)
- Tests/AppGridUITests/AppGridCellFocusReuseTests.swift (only 3 idle background expectations: transparent instead of controlBackgroundColor; preserve focus/identity/reuse assertions)
- Workflow/results/T-WALLPAPER-CELL-FILL.md
- Workflow/artifacts/T-WALLPAPER-CELL-FILL/ (synthetic test artifacts only)

## Acceptance
- Initial/unfocused cells have no opaque background fill.
- focus true retains visible and accessible focus; focus false restores transparency.
- clearContent/bind/rebind (including folder) do not restore dark fill.
- Synthetic rendered pixel regression fails before and passes after, sampling empty padding away from icon/text. Test at least initial/blur/reuse transitions as practical.
- Input hitTest, frames, drag paths, paging and existing wallpaper host fix untouched.
- Keep changes minimal; no new styling subsystem or background provider edits.
- Targeted tests and independent read-only review before completion. Prior full-suite baseline has 12 failed assertions across 7 cases; do not modify their expectations.

## Runtime and concurrency
Continuation of user-authorized wallpaper repair and sol/high Worker plus independent Luna/max task-scoped override; no permanent model config changes. Main is current runtime orchestrator, Chief not required for this bounded existing UI bug. Single implementation writer; shared SwiftPM serialized; Main handles candidate delivery separately. No LaunchBetter/Buho reads, no package script (kills processes/deletes bundles), no signing/commit/push. You are not alone; preserve other edits.

## Evidence and next action
2026-09-11 Main inspected live candidate: blurred wallpaper visible, each app has dark rounded rectangular fill. Code sets controlBackgroundColor in cell init and setFocused(false). Prior PageHostView repair remains required and is not reverted. Capture test evidence and then relinquish build ownership promptly.
