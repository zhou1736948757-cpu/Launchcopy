# Phase 1J — Validation Results

- **Date**: 2026-09-11
- **Support matrix**: macOS 26.5.2 (25F84), arm64 Apple M3, built-in Color LCD 2560×1664; local unsigned only

## Automated

| Gate | Result | Evidence |
|---|---|---|
| Isolated seven failures (before) | FAIL 7 cases / 12 asserts | `Workflow/artifacts/T-1J-TRIAGE/isolated-seven.log` |
| Neighbor regression after repair | PASS 36 / 0 | `Workflow/artifacts/T-1J-TRIAGE/neighbor-regression.log` |
| Full XCTest suite | PASS **1530 / 0 failures** | `Workflow/artifacts/T-1J-FULL/full-suite.log` |
| Swift Testing runner | 0 tests (accounted; not a silent skip of XCTest) | same log footer |
| Packaging smoke | PASS (reject unsafe name, assemble, refuse overwrite, pkill gated) | `Workflow/artifacts/T-1J-FULL/package-smoke.log` |
| Release candidate package | PASS (unsigned local) | `Workflow/artifacts/T-1J-FULL/rc-package.log`; `.build/candidates/phase1j-rc-20260911/` |

## Carried visual acceptances

| Item | Status |
|---|---|
| Wallpaper occlusion repair | KEEP in tree |
| Cell dark-box (`T-WALLPAPER-CELL-FILL`) | **PASS_USER_REPORTED** 2026-09-11 — not re-opened |

## Manual / distribution

| Gate | Status |
|---|---|
| Exact candidate launch + identity | PASS |
| Wallpaper + idle cell transparency | PASS (`T-1J-GUI/01-initial-grid.png`; cell-fill acceptance carried) |
| Settings singleton / 四指 Ready / login off | PASS |
| Hide ≠ quit residence | PASS |
| Search input | PASS; filter visual PENDING |
| Folder / paging / drag / four-finger / restart | PENDING / NOT_RUN |
| Bottom black band on screenshot | **RETRACTED** — was Dock, not in-app bar (user 2026-09-12) |
| Signing / notarization / publication | NOT_RUN / not authorized |

## Honest label

**RC_IMPLEMENTED_MANUAL_PENDING** — automation clear; packaged GUI partially probed; not `LOCAL_RC_VALIDATED`.
