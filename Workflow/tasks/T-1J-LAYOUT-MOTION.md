# T-1J-LAYOUT-MOTION — Phase 1J Layout and Folder Motion Integration

Status: PLANNING_GATE
Owner: Main orchestration
Approved specification: `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md`

## Objective

Coordinate Chief architecture, bounded Worker implementation, independent Reviewer assessment, and final verification for stable grid geometry and restrained Folder motion.

## Scope

- Stable five-column/seven-row geometry for ordinary pages.
- Explicit search-mode geometry behavior.
- Pointer-only Folder open/close continuity with immediate keyboard behavior and Reduce Motion support.
- Immediate logical close and noninteractive, generation-gated exit visuals.
- Focused and full regression tests, debug/release builds, candidate packaging, and honest GUI evidence.

## Constraints

- Preserve the dirty checkout and all existing user work.
- Main does not edit product code. Chief does not edit product code. Reviewer does not edit implementation.
- Do not read LaunchBetter, Buho sources, or reverse-engineering evidence for this slice.
- Do not alter paging physics, `Timer.tolerance = 0ms`, persistence, hit-region contracts, or accepted wallpaper transparency.
- No commit, push, tag, signing, notarization, or publication.

## Dependencies

1. Chief architecture decision and bounded task packets.
2. Worker implementation using disjoint write scopes.
3. Integration verification with serialized SwiftPM builds.
4. Independent Reviewer verdict. PASS is required for closure.

## Acceptance

- Approved specification acceptance criteria are satisfied or explicitly marked pending with evidence.
- Focused and full tests execute with nonzero counts.
- Debug and Release builds succeed.
- A new candidate is packaged without overwriting an existing artifact and hashes are recorded.
- GUI checks report only what was actually exercised.
- Independent Reviewer returns PASS, or the task remains open with repair packets.
