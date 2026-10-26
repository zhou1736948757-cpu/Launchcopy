# Compact Grid Source Review

Date: 2026-10-14

Verdict: **PASS — bounded independent source review only.**

## Scope and evidence boundary

Reviewed the current frozen delta in `Sources/AppGridUI/AppGridGeometry.swift` and the complete new, untracked `Tests/PagingUITests/CompactGridGeometryTests.swift`. Read project `AGENTS.md`, the compact-grid stage summary, and only immediate geometry consumers needed to assess ordinary/search layout, item content/hits, shared drag frames, and page dots. The user explicitly waived the managed Chief workflow and authorized this review with Main plus this reviewer; no additional agents were invoked.

Compared geometry against its Git HEAD version. That comparison shows only the replacement of the fixed nonnegative cell height with a row-budget clamp, its relocation after row calculation, and an explanatory comment. The new test file is untracked and therefore was read in full rather than assumed to appear in the ordinary Git diff. HEAD is a source comparison reference, not independently established as the exact native R3 candidate bytes.

No Swift execution, tests, builds, application launches, GUI inspection, process control, goals, or other-agent operations were performed. Main reports an exact-R3-old-bytes regression with 7 tests / 234 assertion failures and a restored-fixed-source focused run of 59 tests / 0 failures. These are attributed handoff statements, not this reviewers independent execution evidence; the verdict rests on source inspection.

## Findings

**No actionable regression identified in the authorized delta.** No implementation changes are requested by this review.

### Row budget and preservation of established geometry

At `AppGridGeometry.swift:16-26`, columns remain clamped to at least one; ordinary layout still reserves seven rows independently of item count; search still uses at least one row and the existing ceiling of count/columns. Consequently division uses a positive row count. With the existing finite, nonnegative page bounds/insets and ordinary capacity of at most 35 items, effective height is now `min(max(preferredHeight, 0), safeHeight / rows)`. The subsequent existing spacing calculation consumes the effective height, so rows plus gaps fit the vertical budget, subject to floating-point rounding.

If the budget already accommodates the preferred cells, the same preferred height and the same spacing formula remain in effect. Defaults preserve 88pt cells from a 736pt total page height upward, reduce spacing between 736pt and 832pt, and retain 16pt spacing from 832pt upward. When seven rows cannot fit, only height shrinks and spacing falls to approximately zero. No capacity, index order, identity, inset, or paging-state logic changes.

`AppGridGeometry.swift:29-41` is unchanged: full rows retain their horizontal geometry; a partial last row remains horizontally centered; placement remains left-to-right and top-to-bottom in unflipped coordinates; ordinary partial pages retain the established seven-row vertical reservation. Nonzero bounds origins continue to translate frames through `area.minX/minY`. The existing guard returns no frame when the area has no positive width or height. The new clamp makes the stored cell height zero for a zero height budget.

### Ordinary/search rendering and hits

`AppGridPageView.swift:365-381` assigns the geometry-produced frame to every rendered cell. `AppCatalogAssembly.swift:374-380,508-510` supplies the existing committed-query layout mode and host bounds. There is no second fixed-88pt layout in this immediate render path.

`GridItemAppearance.swift:28-59` already derives icon and caption frames from cell-local bounds, fitting icons and caption boxes to the supplied height. `AppGridCellView.swift:290-332` uses that content geometry for both app icons and folder symbols; launch hits retain the existing icon-plus-4pt rule and reject empty icons. `AppGridPageView.swift:110-112` uses actual cell frames for drop target lookup. Thus smaller cells propagate into content and hit geometry instead of leaving an independent oversized icon layout. Extremely short cells may have an empty icon and no launch target under the existing content policy; this review does not certify legibility or usefulness at arbitrary near-zero heights.

### Shared drag geometry

`AppGridPageView.swift:118-133` converts actual `cell.bounds` into the requested host coordinates while retaining binding-based app/folder identity. `AppDelegate.swift:1193-1233` obtains those frames for top-level drag geometry and folder move-out top-level targets, with the existing page annotations and index mapping. `AppCatalogAssembly.swift:300-312` similarly anchors live folders from actual cell bounds. The delta introduces no independently computed drag height or changed item ordering/page indexing. Runtime drag arbitration remains outside this source-only verdict.

### Page dots

`AppDelegate.swift:2793-2803` computes the dots gutter from the same ordinary geometry, using the last cell bottom. A full compact seven-row grid has last-row `minY = bounds.minY + 24` within rounding, so the dots retain a 24pt gutter, a height of 24pt, and zero bottom inset. The dots upper boundary therefore meets the grid lower boundary without positive-area overlap. Sufficient-height ordinary geometry is unchanged. Search uses no more than seven rows under the existing per-page capacity; its reserved bottom inset is also 24pt, so the ordinary-based dots gutter introduces no new search-cell overlap. Dot count, enabled state, navigation guards, and request routing are untouched. Native pointer behavior is not established here.

## Test-source quality and maintenance

The seven new test methods cover compact full ordinary pages, ordinary partial pages, sufficient-height defaults and the exact 736pt threshold, compact single/multiple search rows, translated origins/custom insets, and zero/empty budgets. `CompactGridGeometryTests.swift:149-160` checks positive frame sizes and all four containment edges with a small tolerance. The ordinary-order checks at lines 21-28 and explicit top/bottom/centering assertions provide behavioral checks beyond repeating the new height expression. The sufficient-height constants at lines 37-44 preserve established geometry; the empty-budget assertions preserve nil-frame behavior.

The tests are proportionate to a single pure geometry correction, deterministic in source, and retain XCTest file/line propagation from the shared assertion helper. The implementation keeps one geometry authority and explains when shrinkage is necessary. No additional abstraction or maintenance rewrite is warranted for this delta. These geometry tests do not independently cover native AppKit layout timing, hit delivery, drag sessions, dot interactions, or visual acceptance; source review of consumers is not execution of those paths.

## Reviewed bytes (SHA-256)

| Input | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/AppGridGeometry.swift` | `9ba66c1c0a03327df75920e5611a126489a56615e71d2dd7bb2a9d249c4e7e44` |
| `Tests/PagingUITests/CompactGridGeometryTests.swift` | `1a3f7129fa0686f810b2cba18e422694bde55b03bf985771dadcaa8cf4b638c1` |
| Git HEAD geometry source bytes | `f5831cd12187c9b60d6c7762ea7905cf633def8294198b0fcc82b62049b0a1f3` |
| `Sources/AppGridUI/AppGridPageView.swift` | `331514e9da1b1a3af7b1c4ec5d44fcdec97ce030201c386c72d93e63e5a60c00` |
| `Sources/AppGridUI/AppGridCellView.swift` | `3fe5fbae3eeaa64e4c63c51329f5f0096b896cc44bfba0b6fbc505913fa46fa6` |
| `Sources/AppGridUI/GridItemAppearance.swift` | `75f831d583be163d98f3dc306bdd34d1bf04a7da17b4b51ec3ac368674aeb8d4` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `82f6e12d6427142bdab69c86366f9b655366514a98eceab0955c83b740fb79f5` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `8d78ea4f207b3d7a6bf23bff8ad7b9795e01bbbf40fb11b3d6567bcabdbf24d3` |
| `Workflow/stage-summaries/2026-10-14-compact-grid-native-repair.md` | `c7091b098d76264826569aa860e378a621d2ff12b5a798495de66879db8f116a` |

The two review-target hashes were checked again after report creation and remained identical.

## Delivery and limits

Only authored file: `Workflow/results/COMPACT_GRID_SOURCE_REVIEW.md`. No implementation, tests, repository state, stage summary, or unrelated dirty-tree files were edited. No external-product or raw-evidence inspection was undertaken.

Command-protocol deviation: the initial workspace-location, RTK-instruction, and narrow memory-registry lookup commands were mistakenly issued without the RTK prefix. They were read-only; the memory lookup returned no relevant result. All subsequent shell commands used the RTK prefix. This is disclosed separately from the source verdict.

This PASS establishes no GUI acceptance, performance acceptance, full behavior parity, or approval of unrelated dirty-tree changes. Main retains integration and native acceptance gates.
