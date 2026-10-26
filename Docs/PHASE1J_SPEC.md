# Phase 1J — Release Candidate Validation (SPEC)

- **Status**: Gate 0 **APPROVED** — implementation authorized
- **Date**: 2026-09-11
- **Prompt**: PHASE1J_RELEASE_CANDIDATE_VALIDATION_PROMPT.md
- **Approval**: user confirmed recommended defaults (local Apple Silicon RC; Phase 1I polish deferred)

## 1. Objective

Produce a **local** Release Candidate validation claim (`LOCAL_RC_VALIDATED` or an honest blocked/partial label). Not a public release.

## 2. Non-goals

- New product features / visual expansion beyond preserving wallpaper+cell fixes
- Changing accepted paging physics / 5×7 capacity defaults to silence tests
- Implicit process kill / old-bundle deletion in packaging (1J requires safer packaging)
- Signing, notarization, upload, publish, commit/push/tag without separate authorization
- Re-opening closed `T-WALLPAPER-CELL-FILL` black-box acceptance as pending

## 3. Approved support matrix (Gate 0)

| Axis | Claim (this machine) |
|---|---|
| Arch | Apple Silicon only (`arm64`, Apple M3) |
| Display | Built-in Color LCD 2560×1664 Retina; claim **60 Hz only** (no measured 120 Hz evidence) |
| OS | macOS **26.5.2** (Build 25F84) — record again at J5/J6 |
| Input | Built-in trackpad + keyboard |
| Distribution | **Local unsigned/ad-hoc candidate only** |

Do not claim Intel, 120 Hz, multi-display, or notarized distribution without evidence.

## 4. Track A — Seven failing cases (must clear)

| # | Test |
|---|---|
| 1 | `AppLaunchControllerTests.testClickHitPathReachesCell` |
| 2 | `Bug10PreviewHostTests.testMoveOutBarAndPreviewShareOverlayCoordinateSystem` |
| 3 | `Bug11RowBoundaryIndicatorTests.testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor` |
| 4 | `Bug9CellHitRoutingTests.testHitTestAtBackgroundReturnsCell` |
| 5 | `Bug9CellHitRoutingTests.testHitTestAtNameLabelReturnsCell` |
| 6 | `DragCommitIntegrationTests.testTwoMemberFolderMoveOutShowsRemainingAppProxyThenDissolves` |
| 7 | `T1FD1FixUITests.testPreviewShowsSourceCellIconAndName` |

**Policy**: Classify each as product defect / stale expectation / fixture bug. Icon-only ±4px hit contract is user-accepted for production; tests 4–5 may need contract-aligned assertion updates **with replacement coverage**, not silent deletion. Do not use “legacy fail” as RC PASS excuse.

Recorded baseline: **1528 executed / 12 failed assertions / 7 failed cases** (cell-fill candidate). Fresh reproduction required at J1.

## 5. Track B — Product flow (packaged candidate)

Paging, search, folder, drag, settings, four-finger show, restart/layout restore; wallpaper + transparent cells remain; Reduce Transparency fallback when authorized.

## 6. Track C — Packaging safety

Build into a **new unique staging directory**; failed builds must not destroy prior candidates; no implicit `pkill`/rm of user-running apps unless the packaging fixture explicitly documents a dry-run/safe mode for 1J (prompt: improve packaging safety vs 1H script behavior).

## 7. Task graph

J0 (this approval) → J1 triage → J2-* repairs → J3 packaging → J4 data/privacy → J5 full suite + candidate → J6 GUI matrix → J8 Reviewer. J7 signing only with explicit permission.

## 8. Incomplete Phase 1I

Treat remaining visual polish (full token restyle, EN catalog completeness, icon refinement) as **deferred from LOCAL_RC** unless user requires them in Gate 0. Wallpaper visibility + cell fill acceptance already carried.
