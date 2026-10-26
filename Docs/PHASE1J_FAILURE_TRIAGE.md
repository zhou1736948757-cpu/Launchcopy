# Phase 1J — Failure Triage (J1 → J2)

- **Date**: 2026-09-11
- **Gate 0**: APPROVED
- **Isolated reproduction**: `Workflow/artifacts/T-1J-TRIAGE/isolated-seven.log` — 7 cases / 12 assertions failed
- **After repair (neighbor)**: 36 related tests / 0 failures (`neighbor-regression.log`)

## Final classification and disposition

| # | Test | Class | Disposition |
|---|---|---|---|
| 1 | `AppLaunchControllerTests.testClickHitPathReachesCell` | Stale fixture geometry + headless hitTest | Click icon center (not cell mid / wrong bounds convert); mount offscreen window for AppKit hit chain |
| 2 | `Bug10PreviewHostTests.testMoveOutBarAndPreviewShareOverlayCoordinateSystem` | Stale fixture vs row-band contract | Member frames Y separated from top-level landing Y; pointer leaves member band before expecting topLevelTarget |
| 3 | `Bug11RowBoundaryIndicatorTests.testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor` | Stale fixture vs row-band contract | Same separation; added `testFolderMemberInsideRowBandStaysInsertionEvenWhenArmed` |
| 4 | `Bug9CellHitRoutingTests.testHitTestAtBackgroundReturnsCell` | Stale expectation vs accepted icon±4 | Renamed/rewrote → `…MissesCell`; keep icon + ±4 positive coverage |
| 5 | `Bug9CellHitRoutingTests.testHitTestAtNameLabelReturnsCell` | Stale expectation vs accepted icon±4 | Renamed/rewrote → `…MissesCell` |
| 6 | `DragCommitIntegrationTests.testTwoMemberFolderMoveOutShowsRemainingAppProxyThenDissolves` | Stale landing Y vs row-band | Landing Y chosen outside member row band but inside a top-level row |
| 7 | `T1FD1FixUITests.testPreviewShowsSourceCellIconAndName` | Stale `===` vs durable snapshot | Assert non-nil durable preview icon (snapshot/copy), not NSImage identity |

## Product code

**No production DropIntent / hitTest contract changes** in this Track A pass. Accepted contracts preserved:

- icon (±4pt) launch hit target
- folder-member row-band priority over move-out

## User decisions recorded

- Gate 0 defaults approved
- Keep row-band priority; fix fixtures (not panel-outside override)
- Integration landing Y moved outside member band

## 2026-09-16 postscript — hit-region contract history correction

The "icon (±4pt) launch hit target preserved" record above describes the Track-A state at
2026-09-11. It was **not** continuously preserved: the Phase 1J B1 click-routing work in
commit `bddb0fa` widened `AppGridCellView.acceptsLaunchHit(at:)` to whole-cell
`bounds.contains` (Reviewer r1 FAIL, finding M1, `Workflow/reviews/T-1J-LM-r1.md`). Per user
decision `Workflow/decisions/D-1J-HIT-REGION-REVERT.md` the icon±4pt contract was restored
on 2026-09-16 (`T-1J-LM-HITREVERT`): the unified `acceptsLaunchHit` structure is retained,
the body again tests `iconFrame.insetBy(dx: -4, dy: -4)` (folder cells: `folderSymbolView`
frame), and dispositions 4–5 are now literally true — `Bug9CellHitRoutingTests` contains
`testHitTestAtNameLabelMissesCell` / `testHitTestAtCellPaddingMissesCell` asserting the
miss, plus `testHitTestAtIconCenterReturnsCell` covering icon + ±4 positively.
