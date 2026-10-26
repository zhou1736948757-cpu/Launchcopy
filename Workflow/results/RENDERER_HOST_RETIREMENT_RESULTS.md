# Renderer Missing-Host Retirement — Results

Date: 2026-10-17
Status: **BOUNDED REPAIR VERIFIED; NEW ISOLATED CANDIDATE RUNNING; NO PHYSICAL/PERFORMANCE CLAIM**

## Why this maintenance occurred

The user accepted the handed-over folder experience and requested continuation. During independent source discovery for still-unconfirmed adjustable main-grid capacity, the geometry reader identified an existing weak-host retirement hole. This repair is independent of that new feature and does not implement capacity controls or alter accepted paging physics.

## Exact defect and repair

`AppGridRenderer.sweepRetiredHosts` previously skipped a page if its weak host had deallocated. The strong live-page dictionary retained that page, its cells and ownership state across later sweeps. Existing detached-but-retained hosts already followed the retirement path; the fix makes a missing weak host follow that same existing `retire` / clear / pool path. Attached hosts are unchanged. Indices are collected before dictionary mutations; repeated sweeps cannot add the same page to the pool twice.

One production method changed in `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`; one new `Tests/PagingUITests/AppGridRendererRetirementTests.swift` adds three tests. No Core/UI protocols, physics, parameters, frame source, cache limits, store, folder or material implementation changed. All465 final input hashes verified:463 prior inputs unchanged, one prior production file changed, one test file added.

## Actual test history

- Actual RED: three test methods /53 failed assertions. Mounted-page negative control passed; weak references actually became nil, so release was reproduced rather than presumed. Sixteen distinct page-index cycles accumulated16live/created page instances instead of reusing one. Raw failure count includes an incorrect new-test assertion that pooled cells should have no allocations; it is not53distinct bugs.
- After the production repair: focused r1 executed33tests/one failure, solely that incorrect cell-allocation expectation. Existing `clearForReuse` intentionally retains cleared cell objects. Main changed only that test assertion to invalid page/presentation identity, cleared binding and retained same-cell allocation, not production behavior.
- Final focused r2: **33tests/0fail,0.433s**; includes the three new tests and existing assembly/host-range/search-reload regressions.
- Full r1: **2812tests/0fail,52.877s**. Count is actual XCTest, not the separate trailing zero-test Swift Testing runner.
- Explicit Debug build passed0.32s; actual Release build16.35s and safe packaging passed. Packaged localization verified290required keys/signatures ×3languages. `git diff --check` passed.

Raw logs/source snapshots: `.build/verification/20261017/renderer-host-retirement/` (`red.log`, `focused-r1.log`, `focused-r2.log`, `full-r1.log`, `debug-r1.log`, `package-r1.log`, `AppCatalogAssembly.before.txt`, `source-before.json`, `source-inputs-r1.json`).

Independent Dalton review: bounded SOURCEPASS/no actionable findings, hashes verified and existing Main logs inspected; reviewer executed no tests/build/UI. Report `Workflow/results/RENDERER_HOST_RETIREMENT_SOURCE_REVIEW.md`. All original discovery readers and reviewer are closed, build/test jobs terminal. Main retained integration and serial execution, max3includingMain during the earlier disjoint discovery pair, thenMain+reviewer2.

## Candidate and native handover

Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/renderer-host-retirement-rc-20261017-r1/LaunchcopyUITest.app`.
Executable SHA-256: `39484896e8fd0ee157077c87502a42232db049af345ddfe2e13c4247904e0f82`.

Unsigned/uninstalled. Own isolated data seeded only from prior own synthetic profile:40 Info-only fake apps,35-member folder and layout/Library payloads. No wallpaper cache, lockfiles, real catalog or formal data copied. Old bdb9a6e3 test normally quit via its observed app menu; exact old executable absence verified before launching new exact path. No query of closed old binding.

Actual new-candidate CUA observations:
- Ordinary non-topmost test window; no-match query displays actual empty results.
- Clearing query restores original35-member folder and five outside apps.
- Clicking the AX caption alone did not open the folder; no success inferred. Clicking actual folder glyph opened page1of3/15members.
- Next button reached page2of3/members16–30; Escape closed only folder, launcher stayed running.
- Final state: original main grid, empty query, folder closed, left running for user. Exact process and source/executable/isolated layout+Library hashes reverified afterward; PID in structured receipt.

Wallpaper diagnostic remained loading in this new run, with black backdrop. This is the previously recorded intermittent issue, not diagnosed or repaired by this change. No cache/permission/signature/system preference workaround was attempted. Captured personal screenshot files were not saved. No install/sign/publish/commit/reset/clean/delete/kill or reference source/assets access.

## Limits and next step

Direct AppKit-host tests prove cleanup/reuse at an existing explicit sweep or subsequent nonplaceholder render, not immediate zero-result cleanup, whole-process RSS limits, queued icon cancellation, elimination of every leak, frame-time improvement or resolution of >25ms hitch causality. Native smoke verifies UI restoration, not allocator census or physical gesture/animation acceptance of this new executable. Earlier human folder acceptance belongs to the prior candidate; unchanged folder source is not a new physical benchmark.

Main-grid range3..8/default5×7 remains PROPOSED_PENDING_USER_CONFIRMATION in `Docs/MAIN_GRID_CAPACITY_SPEC.md`. Source audits documented separate receipt-bearing capacity persistence/Quit participation, seven-host resource envelope, same-revision focus/anchor risks and unresolved minimum readable viewport; none is silently implemented. Await the one sent product decision, then resolve engineering entry gates before capacity implementation. Other reserved product/hardware/OS and privacy boundaries remain. Full migration objective stays ACTIVE and incomplete.
