# T-1J-LM-HITREVERT

## Objective
Repair Reviewer r1 FAIL finding M1 (`Workflow/reviews/T-1J-LM-r1.md`): restore the
user-accepted **icon±4pt launch hit-region contract** inside the committed Phase 1J B1
click-routing work, per user decision `Workflow/decisions/D-1J-HIT-REGION-REVERT.md`.
Keep the unified `acceptsLaunchHit(at:)` shared-contract structure; revert only the
contract body. Realign the asserting tests, reconcile the falsified docs, and close the
two bounded minors (m1, m2).

Baseline reference (do NOT copy verbatim into comments as provenance claims; the semantic
is what matters): `git show 6382bd9:Sources/AppGridUI/AppGridCellView.swift` hitTest used
`frame.contains` gate → `iconFrame.insetBy(dx: -4, dy: -4).contains(local)` where
`iconFrame = isFolderCell ? folderSymbolView.frame : iconView.frame`. point is in the
parent/superview coordinate space.

## Expected / Allowed Write Scope
- `Sources/AppGridUI/AppGridCellView.swift` — `acceptsLaunchHit(at:)` body becomes
  `iconFrame.insetBy(dx: -4, dy: -4).contains(point)` (receiver-local point;
  `iconFrame = isFolderCell ? folderSymbolView.frame : iconView.frame`); keep the
  detached-cell `hitTest` fallback path and the shared-contract doc comment, updating the
  comment to state the real contract (icon/folder-symbol ±4pt, NOT whole-cell).
- `Sources/PagingPrototypeApp/AppDelegate.swift` — m1 only: dedicated consume site or
  explicit comment for `pendingPointerFolderID` at ~`982-988`. No other behavior change.
- `Sources/PagingPrototypeApp/AppLaunchController.swift` — only if the icon±4 contract
  requires adjusting the `handleClick` gate (coordinate conversion correctness); otherwise
  leave the consumer chain untouched.
- `Tests/AppGridUITests/Bug9CellHitRoutingTests.swift` — realign whole-cell assertions to
  icon±4 semantics: name-label / cell-padding / background points must MISS the launch
  target (rename or rewrite per `PHASE1J_FAILURE_TRIAGE.md` disposition intent; keep
  `testHitTestOutsideCellMissesCell` and `testNestedCellDescendantResolvesToOwningCell`
  meaning intact).
- `Tests/PagingUITests/AppLaunchControllerTests.swift` — realign click points that relied
  on whole-cell hits to icon-area points; keep the launch→handleCell validation chain.
- `Tests/PagingUITests/B1ManualDeliveryTests.swift`,
  `Tests/PagingUITests/BlankClickToQuitTests.swift`,
  `Tests/PagingUITests/LauncherIntegrationTests.swift`,
  `Tests/PagingUITests/FolderIntegrationTests.swift`,
  `Tests/PagingUITests/DragCommitIntegrationTests.swift`,
  `Tests/PagingUITests/Bug11RowBoundaryIndicatorTests.swift`,
  `Tests/AppGridUITests/Bug10PreviewHostTests.swift`,
  `Tests/AppGridUITests/T1FD1FixUITests.swift`,
  `Tests/AppGridUITests/FolderOverlayTests.swift`,
  `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift`,
  `Tests/PagingUITests/AppCatalogAssemblyTests.swift`,
  `Tests/PagingUITests/AppContentTestSupport.swift` — **only where they assert or rely on
  whole-cell hit semantics**; leave orthogonal assertions untouched.
- `Docs/PHASE1J_FAILURE_TRIAGE.md`, `Docs/PHASE1J_CHECKPOINT.md` (:126 area),
  `Docs/PHASE1J_REPORT.md` (Track-A table) — reconcile to truth: state icon±4 was
  committed-violated then restored after r1 FAIL; do NOT claim it was never changed.
- `Workflow/results/T-1J-LM-HITREVERT.md` — your Worker result artifact.
- `Workflow/artifacts/T-1J-LM-HITREVERT/` — test logs you produce.

## Acceptance
- `acceptsLaunchHit(at:)` returns true only inside the icon frame (folder: symbol frame)
  padded by 4pt; label/padding/gap clicks do not reach `handleCell` and classify through
  the existing blank path.
- `hitTest` keeps the detached-cell safe path and superview-space conversion; no second
  click path is created; `appGridCellAncestor` / `blankClickResolvesToInteractionZone`
  untouched.
- Fail-before evidence: at least one focused assertion demonstrating whole-cell behavior
  fails on the pre-repair tree, then passes after (capture in result; `git stash`-free
  approaches such as asserting current failing expectation before edit are fine — record
  what you ran).
- Realigned tests assert the icon±4 contract (not silently deleted, skipped, or loosened);
  `…MissesCell`-style coverage exists for label and padding points.
- Docs changes state the restore-after-FAIL history accurately; no doc claims icon±4 was
  continuously preserved.
- m1 consume site/comment present; m2 noted in the result's closeout section.
- Focused filter run `swift test --filter
  'Bug9CellHitRoutingTests|AppLaunchControllerTests|B1ManualDeliveryTests|BlankClickToQuitTests|LauncherIntegrationTests|FolderIntegrationTests|DragCommitIntegrationTests|Bug11RowBoundaryIndicatorTests|Bug10PreviewHostTests|T1FD1FixUITests|FolderOverlayTests|AppGridCellFocusReuseTests|AppCatalogAssemblyTests|FolderMotionTests|FolderOverlayForensicsTests'`
  exits 0 with nonzero executed count; record exact executed/failed numbers in the result.
- `swift build --target PagingPrototypeApp --configuration debug` exits 0.

## Forbidden / boundaries
- No change to `Sources/PagingCore/`, `Sources/PagingUI/` physics, `Timer.tolerance`,
  `Package.swift`, LayoutStore schema, wallpaper/transparency code, telemetry contract.
- No commit/push/tag/reset/clean; no package script run; no signing.
- Do NOT read `BuhoReverseNotes`, `LaunchBetter`, or any `*buho-launchpad-reverse*` path.
- Do not change the product contract beyond this packet; anything needing it → BLOCKED.
- You are not alone in the tree; preserve unrelated edits. `.build/` is shared: serialize
  SwiftPM invocations (run one at a time, wait for each to finish).

## Runtime and concurrency
Single Worker (declared swe-2-max, medium). Main owns dispatch/evidence/state. Independent
GLM-5.2-Max Reviewer r2 follows after your result. Report via
`Workflow/results/T-1J-LM-HITREVERT.md` with: summary, changed files, exact test commands
and real output numbers, fail-before evidence, unresolved questions. If any acceptance
item conflicts with reality, return BLOCKED with evidence — do not self-expand scope.
