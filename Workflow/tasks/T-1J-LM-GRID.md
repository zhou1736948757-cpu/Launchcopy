# T-1J-LM-GRID — Stable Grid Geometry

Status: READY
Owner: Worker

## Objective

Implement the approved AppGridUI geometry helper and stable ordinary/search row placement.

## Dependencies

- `D-1J-LAYOUT-MOTION`

## Scope

Keep five columns, 35-item capacity, 48pt icons, 88pt cells, preferred 16pt spacing, horizontal partial-row centering, and existing chrome reservations. Ordinary pages use a centered seven-row envelope; committed search pages center occupied rows. Add explicit page layout mode and deterministic pure geometry tests.

## Expected / Allowed Write Scope

- `Sources/AppGridUI/AppGridPageView.swift`
- `Sources/AppGridUI/AppGridGeometry.swift`
- `Tests/AppGridUITests/AppGridPageViewTests.swift`
- `Tests/AppGridUITests/AppGridGeometryTests.swift`
- `Workflow/results/T-1J-LM-GRID.md`

## Acceptance Criteria

- Covers 0/1/5/6/34/35 items, ordinary/search mode, partial ordinary pages, three viewport classes, and nonzero origins.
- No negative dimensions, label/icon overlap, capacity change, hit-padding change, or paging/drag policy change.
- Existing cell frames remain the source consumed by focus, hit testing, and drag geometry.

## Required Verification

- Run focused `AppGridUITests` filters with nonzero executed count.
- Record changed files, test counts, evidence, deviations, risks, and Reviewer focus in the result.

## Prohibitions

Do not edit executable-target files, Folder motion files, `Package.swift`, workflow decisions/stage summaries, or forbidden source trees. No commit/push.

