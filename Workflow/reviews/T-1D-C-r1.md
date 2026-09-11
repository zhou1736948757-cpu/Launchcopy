# Review: T-1D-C — PagingUI narrow same-revision reload seam

- **Reviewer**: independent (read-only)
- **Date**: 2026-08-30
- **Verdict**: **PASS**
- **Review revision**: r1

## Scope reviewed

- `Sources/PagingUI/PagingSurface.swift` (MODIFIED — narrow seam `reloadCurrentPresentation()` + `applySameRevisionReload()` + `pendingSameRevisionReload` state; `endInteraction()`/`teardown()` wiring)
- `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift` (NEW, 14 tests)
- `Workflow/results/T-1D-C.md` (Worker result)

Read-only contract types inspected: `PagingPageContentProviding`/`PagingPageContent`/`PagePresentationID` (via usage), `ItemBindingToken` (7-field confirmation), `PagingCore` (hash-only, frozen), `TestSupport.swift` (gesture helpers used by the new tests).

## Verification executed (independent, re-run — not trusting Worker summary)

| Command | Exit | Result |
|---|---|---|
| `swift test --filter PagingSurfaceSearchReload` | 0 | **14/14 passed**, 0 failures (executed_tests=14 > 0) |
| `swift test` (full) | 0 | **620/620 passed**, 0 failures |
| `swift build -c debug` | 0 | Build complete |
| `swift build -c release` | 0 | Build complete |
| `shasum -a 256 Sources/PagingCore/*.swift` vs `Docs/PHASE1C_BASELINE_MANIFEST.sha256` | — | **All 6 hashes match** (see below) |
| `shasum -a 256 AppLaunchController.swift Package.swift ItemBindingToken.swift` vs manifest | — | **All 3 match** (frozen) |
| conflict-marker scan on both changed files | — | none (`<<<<<<<`/`=======`/`>>>>>>>`) |
| `git status` / `git log` | — | branch `main` has **no commits** (all untracked) → no commit/push/tag |

`exit_code == 0` and `executed_tests > 0` on the reload suite → **valid test execution** (not `INVALID_TEST_EXECUTION`). Worker's claimed counts (14 targeted, 620 full) are **confirmed** by independent re-run.

### PagingCore-unchanged confirmation

| File | Baseline (manifest) | Current | Match |
|---|---|---|---|
| `Sources/PagingCore/GestureSession.swift` | `0bc99894…` | `0bc9989472b8cb4c7cd2b4645d45541795065d851244f1cc723f8e2931af442c` | ✅ |
| `Sources/PagingCore/PageTargetPolicy.swift` | `530b7f23…` | `530b7f2332c7ae1749beb2b9b3d202b313b9f2d4e0058975382c9d94804aa0fa` | ✅ |
| `Sources/PagingCore/PagingCore.swift` | `2b4c029b…` | `2b4c029b6baadd752713c620e04bc2defe2204e09454315ecdb609beaec66b52` | ✅ |
| `Sources/PagingCore/PagingParameters.swift` | `fa2a107b…` | `fa2a107bb41490f787b1000a342a0e61e11e1d221de222d677597c375827179b` | ✅ |
| `Sources/PagingCore/PagingState.swift` | `f7e4ffa3…` | `f7e4ffa33c7db5f262a46e25713064550f4e4271fd4edb5b38575d02b1457fcd` | ✅ |
| `Sources/PagingCore/TransitionContext.swift` | `268c4a46…` | `268c4a46967c6f60cbbf2b6e7e1a8fb02ea15e5fd342bc3640792356928c35a4` | ✅ |

`Sources/PagingUI/PagingSurface.swift` current hash `1c2b4d56…` differs from the Phase-1C baseline `f9a66477…` — **expected**, this task modifies it. `AppLaunchController.swift` (`bc596a4e…`), `Package.swift` (`c214f04f…`), `ItemBindingToken.swift` (`e795e826…`) all match the manifest → frozen trees untouched.

## Acceptance criteria — per-criterion result

| Criterion | Result | Evidence |
|---|---|---|
| `pendingSameRevisionReload` state independent of `pendingLatestSnapshot` | ✅ | `PagingSurface.swift:123` — separate `public private(set) var pendingSameRevisionReload = false`; never written by `refreshPresentation`/`applyPresentation`; `pendingLatestSnapshot` untouched by the reload seam |
| `reloadCurrentPresentation()`: idle/cancelled → apply immediately | ✅ | `PagingSurface.swift:646–655` — `guard !isTearingDown, provider != nil, provider.servedRevision != nil`; `case .idle, .cancelled: applySameRevisionReload()`. `testIdleReloadAppliesImmediately` passes |
| tracking/settling/interrupted → only set pending (latest-wins, idempotent) | ✅ | `default: pendingSameRevisionReload = true` (idempotent bool, no accumulation). `testTrackingReloadOnlyPending`, `testSettlingReloadOnlyPending`, `testMultiplePendingReloadAppliesLatestOnce` pass |
| `applySameRevisionReload()`: `surfaceGeneration &+= 1` (field-7 gating) | ✅ | `PagingSurface.swift:661` — bump before re-render → in-flight bindings invalidated (ADR-007 §2.6). `testReloadBumpsGenerationRejectingOldIconCallback` passes |
| legal `core.setPageCount` if `provider.servedPageCount` differs | ✅ | `PagingSurface.swift:662–663` — only when `newPageCount != core.pageCount`; no shrink-then-restore |
| explicit `relayoutPages()` (shrink with unchanged offset) | ✅ | `PagingSurface.swift:664` — inside the pageCount-change branch; covers the case where Core does not fire `onVisualOffsetChange` on shrink. `testReloadUpdatesPageCountOne` (which exposed the gap) passes |
| `refreshLiveHostContent(effectiveRevisionForPass())` at same servedRevision — never mints/forges CatalogRevision | ✅ | `PagingSurface.swift:666` — passes `effectiveRevisionForPass()` (= `servedRevision` in idle, pin nil); `servedRevision` never written by the seam. `testReloadKeepsServedRevisionUnchanged` passes |
| `endInteraction()`: catalog revision applies first and supersedes same-revision reload (ADR-007 §2.4) | ✅ | `PagingSurface.swift:586–602` — idle/cancelled: if `pendingLatestSnapshot` → `applyPresentation` + clear `pendingSameRevisionReload`; else if `pendingSameRevisionReload` → `applySameRevisionReload` + clear. `testNewCatalogRevisionOutranksOldSameRevisionReload`, `testOldSameRevisionReloadDoesNotOverrideNewCatalogRevision` pass |
| `teardown()` clears `pendingSameRevisionReload` → zero writeback | ✅ | `PagingSurface.swift:289` — `pendingSameRevisionReload = false`; `reloadCurrentPresentation` guards `!isTearingDown`. `testReloadAfterTeardownZeroWriteback` passes |
| pageCount shrink / 0 / 1 / multi | ✅ | `testReloadUpdatesPageCountShrink/Zero/One/Multi` pass |
| host/view upper bound unchanged | ✅ | `testReloadKeepsHostViewUpperBound` passes (bound = 2·radius+1 = 7) |
| old icon out-of-order callback zero-write | ✅ | `testReloadBumpsGenerationRejectingOldIconCallback` passes (staleRejected == 1) |
| teardown zero-callback | ✅ | `testReloadAfterTeardownZeroWriteback` passes |

## Constraints verified

- **PagingCore frozen** — all 6 hashes match baseline; no Core seam added; no `committedPage`/`visualOffset`/transition-token mutation, no forced page 0, no shrink-then-restore.
- **No CatalogRevision forged** — seam never writes `servedRevision`; `refreshLiveHostContent` re-renders at `effectiveRevisionForPass()` (same servedRevision in idle).
- **Seven-field `ItemBindingToken` intact** — `ItemBindingToken.swift` hash matches manifest; 7 fields confirmed (catalogRevision / pageIdentity / itemSlot / appID / reuseGeneration / iconKey / surfaceGeneration). No 8th field added.
- **Privacy** — no query/result app names in the implementation or tests (test titles are synthetic `r<rev>-p<page>-<slot>`); no `print`/`NSLog`/`os_log`/`signpost`/`write`/JSONL in `PagingSurface.swift` (grep hits are all comments); no `PagingTelemetry` schema change (telemetry files untouched).
- **Diagnostics status** — `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED` not present in either changed file → unchanged as required.
- **No git commit/push/tag** — branch `main` has zero commits; all files untracked.
- **No forbidden-source reads** — BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse not read.

## Findings

### F1 — MINOR: Redundant re-render when pageCount changes
- **Location**: `Sources/PagingUI/PagingSurface.swift:662–666` (`applySameRevisionReload`).
- **Observation**: When `provider.servedPageCount != core.pageCount`, the seam calls `core.setPageCount` → explicit `relayoutPages()` (which renders in-range hosts) → then `refreshLiveHostContent(...)` (which re-renders the same in-range hosts again). The second render is idempotent (same content, same `reuseGeneration`) but redundant work on the query-change path.
- **Impact**: Minor efficiency only; no correctness impact. The task spec explicitly requires both the explicit `relayoutPages()` (critical for the shrink case) and the `refreshLiveHostContent` re-render, so this is inherent to the spec, not a deviation.
- **Recommended solution**: Accept as-is (narrow seam, not per-frame); optionally note for a future optimization if profiling shows it matters.
- **Regression risk**: None. **Confidence**: High.

### F2 — QUESTION: `interrupted` state not covered by a dedicated test
- **Location**: `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift`.
- **Observation**: `reloadCurrentPresentation()` routes `tracking`/`settling`/`interrupted` through the same `default:` branch (only-pending). Tests cover `tracking` and `settling` explicitly but not `interrupted`. The task's required test list (§16.3) does not include an interrupted case, so this is not a coverage gap against the packet.
- **Impact**: None — the interrupted path is code-identical to tracking/settling (verified by inspection).
- **Recommended solution**: Optional — add an interrupted-state test for completeness if the Chief wants belt-and-braces.
- **Regression risk**: None. **Confidence**: High.

### F3 — QUESTION: Generation-gating test asserts via the renderer's own counter, not `surface.surfaceGeneration` directly
- **Location**: `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift:389–410` (`GatedRenderer`).
- **Observation**: `testReloadBumpsGenerationRejectingOldIconCallback` verifies stale-rejection through `GatedRenderer`'s own generation counter (bumped on each `render`), not by directly asserting `surface.surfaceGeneration` was bumped. Behaviorally this is a valid proxy (reload → re-render → generation bump → old callback rejected), and the seam does bump `surfaceGeneration` (`PagingSurface.swift:661`), which is the field-7 source consumed by the real `AppGridPageView` renderer.
- **Impact**: None — the required behavior (old icon callback cannot write to the new query's cell) is verified.
- **Recommended solution**: Accept as-is; optionally add a direct `XCTAssertGreaterThan(surface.surfaceGeneration, before)` assertion for explicitness.
- **Regression risk**: None. **Confidence**: High.

## Recommended solution

No blocking or major remediation required. F1 is an accepted spec-inherent efficiency note; F2/F3 are optional test-completeness suggestions. **PASS as-is.**

## Affected scope

Worker C's 2 deliverables — both within its allowed write scope (`Sources/PagingUI/PagingSurface.swift` + new test file). No changes to `PagingCore`, `Package.swift`, `PROVENANCE/`, `Docs/`, `AppGridUI/`, `MacAppCatalog/`, `PagingPrototypeApp/`, or other test dirs (verified by hash against the Phase-1C manifest for the frozen files).

## Regression risks

- Low. Full 620-test suite green; debug + release builds clean; PagingCore and all frozen files hash-identical to baseline; no privacy/telemetry change; no git activity.
- The seam is additive and gated by `!isTearingDown` + provider readiness; busy-state behavior is latest-wins and catalog-revision-superseding, so no stale-overwrite or pending-loss path was found.

## Confidence

High on all acceptance criteria, build/tests, forbidden-tree integrity, privacy, and the PagingCore-unchanged confirmation. The three findings are MINOR/QUESTION and do not affect the verdict.

## Verdict

**PASS** — all task acceptance criteria are met and independently verified (reload suite 14/14; full suite 620/620; debug + release builds exit 0; PagingCore all 6 hashes match baseline; frozen files untouched; no CatalogRevision forged; no query/result-name leakage; no telemetry change; no git activity; 7-field ItemBindingToken intact). Findings F1–F3 are MINOR/QUESTION and non-blocking.
