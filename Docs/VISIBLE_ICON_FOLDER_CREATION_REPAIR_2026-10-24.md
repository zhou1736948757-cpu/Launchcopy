# Visible-icon folder creation repair
Date: 2026-10-24. Scope: bounded defect repair on the independently implemented Launchcopy grid; no reference-source reads.

## Problem and outcome
User reports dropping one app over another does not create a folder in the integrated preview and asks whether dissolution exists. The current classifier tests a small central third of the whole cell rather than its displayed icon. Captions, cell aspect ratio and icon sizing can separate the two. Existing mutation/commit/persistence logic already supports grouping; do not add a second implementation.

## Contract
Use the actual current app icon rectangle, converted into the same drag-host coordinate system, as the app-on-app grouping target. Keep the whole cell frame for ordering, row bands, page boundaries and move-out detection. Exclude caption/padding from grouping when an explicit icon target is supplied; allow insertion there as before. Add optional geometry metadata only: absent targets preserve legacy pure fixture geometry; explicitly empty/invalid targets do not create phantom folders. Preserve target metadata through page annotations and identity/logical-index mapping. Existing into-folder behavior, folder-internal reorder, drag-start threshold, all paging physics, search/title guards, generation/token gates and exactly-once persistence remain unchanged. Grouping feedback must use the icon target when present, not an unrelated full-cell box.

## Dissolution boundary
Audit existing member-to-main and automatic singleton/empty-folder dissolution, including persistence and stale-generation refusal. Do not silently invent a destructive or new dissolve-all command; distinguish it from automatic dissolution in the report.

## Verification and delivery
First reproduce visible-icon misses using current runtime geometry; then add pure classifier, metadata propagation and real-cell pointer/commit regression tests. Cover label/gaps, empty/invalid targets, existing fallback, reorder and automatic dissolution. Run targeted and full suites with existing deadlines/assertions, Debug/Release and exact-input package verification. Independent readonly review of final actual diff. Main serially owns tests/package/native operations; one disjoint readonly audit checks dissolution. Preserve the running integrated profile and old fixture data, no real app launch, app deletion or arbitrary arrangement changes in native automation. New candidate handover only after automated gate passes; preserve preview preferences/arrangement without formal imports. Native physical drag acceptance remains separate from synthetic pointer tests; do not claim real-user success without it. No installation/signing/Git cleanup or forced process stop.

## Current evidence and next action
Existing implementation: DropZoneGeometry.hitZone uses min(inset cell width,height)/3; AppGridPageView.dragItemFrames exports only cell.bounds. Main adds a failing existing-API regression before production changes. Historical quit timeout remains unresolved but original unchanged source currently passes3633/0 and four isolated invocations; do not attribute new failures to it without evidence.
