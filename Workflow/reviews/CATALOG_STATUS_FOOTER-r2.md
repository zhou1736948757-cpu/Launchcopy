# Catalog status footer — independent re-review r2

Date: 2026-10-25  
Verdict: **SOURCE PASS (bounded). F1 is closed. No new actionable findings.**  
Confidence: **High for the source repair and F1 closure.**

No independent test/build/package execution, native UI/process operations, profile access, physical gestures, performance measurement, or full-parity verification was performed. Main owns execution and native handover. Only this r2 report was written; r1's historical FAIL is preserved. No Git mutation, subagents, reference-source reads, or asset reads occurred.

## Scope and frozen identity

Reviewed the updated specification `Docs/CATALOG_STATUS_FOOTER_LAYOUT_2026-10-25.md` and stage `Workflow/stage-summaries/2026-10-25-catalog-status-footer.md`. The new explicit requirement is to recompute status geometry after admitted capacity/appearance metric commits, after page-dot layout, without commit-stack string formatting.

Evidence directory: `.build/verification/20261025/catalog-status-footer/`.

- `source-inputs-r2.json`: 610 entries; SHA-256 `ff8cec80492eaa1790a5ca68813b5459305a146db41fffc6bcedbc71d4c58dca`.
- `source-delta-r2.json`: six before/after records; SHA-256 `0501f361f0b96fc15c599f114ed9f9cb2cef27e96909c4a8bc43ac03a30574f1`. The six paths and their recorded before/after hashes agree with the inherited 607-entry and r2 manifests: three changed existing files, three additions, no removals.
- Current bytes of all 607 non-asset source/script inputs, including the six delta files, match the r2 freeze. The three localization `.strings` assets were not opened or hashed; their recorded digests agree across inherited/r1/r2 manifests. This is not independent byte verification of those assets.
- Only `AppDelegate.swift` and `LanguageStatusNoticeRuntimeTests.swift` changed since r1. The other four delta files are byte-identical.
- Removing the two production layout calls **in memory only** reproduces the exact frozen r1 AppDelegate hash. Removing the new capacity-store fixture, its cleanup, the two regressions and assertion helper likewise reproduces the exact r1 owner-test hash. No other production change is hidden in this repair.
- Preserved r1 report SHA-256: `45c60c0cb9a768a207efedb04400b058564d879a0fe2ba16eb9b09efec69a69d`.

The six reviewed paths are `Sources/AppGridUI/AppGridStatusView.swift`, `Sources/PagingPrototypeApp/AppDelegate.swift`, `Sources/PagingPrototypeApp/CatalogStatusLayout.swift`, `Tests/AppGridUITests/CompactCatalogStatusTests.swift`, `Tests/PagingUITests/CatalogStatusLayoutTests.swift`, and `Tests/PagingUITests/LanguageStatusNoticeRuntimeTests.swift`.

## F1 closure

**Production:** `AppDelegate.swift:2708-2709` and `4751-4752` now call `layoutCatalogStatus()` immediately after `layoutPageDots()` at both admitted metric commits. Owner/renderer capacity or appearance is already committed. The status therefore uses the new cell boundary and current complete dot frame without requiring a resize, catalog/query/locale event, page-count change, or incidental render callback.

The added calls recompute geometry. They do not request semantic status refresh, modify catalog state, or trigger scanning. This directly repairs r1's missing invalidation.

**Actual-owner regressions:** `LanguageStatusNoticeRuntimeTests.swift:289-322` tests equal-product 8 columns × 3 rows → 3 columns × 8 rows with 24 entries. Lines `324-358` test main-icon appearance 48→96 at 5×5. Both establish the warning before the tested change, require a changed status frame, retain root bounds/revision/query generation/formatting counts, and use the mounted owner rather than merely calling the pure resolver. The capacity case also retains page count; the appearance case retains capacity.

The shared helper (`360-379`) lays out only the surface/page, verifies the warning remains visible and compact, checks every actual cell converted into root coordinates, excludes the entire dot frame, and checks containment and height. Neither case resizes the root or manually invokes status layout after the tested commit. Formatting counts are checked immediately and after deferred turns.

These tests preserve F1's trigger. They intentionally inject a warning at the presentation seam and do not establish warning causality or native presentation.

## Regression assessment

- **Geometry/header:** the pure resolver, grid geometry and dot placement are unchanged. The repair supplies current metrics to the existing finite-frame, full-dot exclusion, larger-side selection, nonzero-origin and narrow-header-gap logic. Header fallback stays above the grid and below supplied finite search/settings frames. No cell or control is moved to create space. Existing tests sample 3×3/5×5/8×8, multiple sizes and origins; the new owner tests add rectangular capacity and appearance transitions. This is not exhaustive native coverage of every 3–8 combination.
- **AX/passivity/indicators:** the status view remains byte-identical. Its full localized label/AX/tooltip values, single-line visual truncation, inline caution/spinner, nil hit testing and rejected first-responder admission are unchanged. Geometry recomputation adds no AX/tooltip mutation.
- **No-content presentation:** compact style remains limited to content-present refreshing/partial-failure. Loading, empty, no-results and no-content failure retain the existing central multiline presentation.
- **Formatting/IO:** `AppGridStatusView.swift:84-87` returns for equal style. Genuine style changes still coalesce and render on the deferred queue using the retained language snapshot. The new calls add no localization loading or synchronous text formatting. Formatting-count assertions protect the commit stack and deferred turns; they are not native performance evidence.
- **Library/teardown:** admission guards, committed visibility latch, Library visual/AX mask, identity checks and generation fences are unchanged. Layout does not unhide the status. A deferred style render still passes through owner remasking; teardown/replacement rejects obsolete work. The new fixture invalidates its capacity coordinator during cleanup.

No new actionable defect was found in these bounded paths.

## Existing Main evidence

Inspected logs, not reviewer executions:

- `metric-before-r1.log:13-28`: 2 tests / 6 assertion failures: stale frames and two cell intersections per trigger, matching r1's source counterexamples.
- `focused-r5.log:69-74,125-128`: both new regressions pass; earlier selected run 47/0.
- Final `focused-r7.log` XCTest summary: **72/0, 5.100s**. Main identifies this selection as the previous status/Library/language set plus capacity/metrics.
- `full-r2.log` XCTest summary: **3772/0, 73.191s**. The separate zero-test Swift Testing footer is not a pass gate.

Latest Main handoff reports Debug 0.34s, actual Release 21.75s, strict entry and three 369-key language probes PASS. The initial resource-smoke wrapper supplied .app instead of .bundle; that failure is retained and corrected `standalone-resources-r3.log` reportedly verifies 1107 entries. These artifact checks were not independently executed or audited here.

Main reports the unique unlaunched StatusFooterR2 artifact SHA-256 `be5b968dba5abb79c8eada20586b98950f24e96822b03fd010d8f7838ba199ef`, canonical manifests restored byte/mode exact, stable r2 inputs, and updated pre-native/stage evidence. Native remains LOCKED; no old-app Quit or new launch was attempted. The reviewer did not inspect the profile or operate an application.

**Disposition:** F1 is closed for this frozen source repair. SOURCE PASS supersedes the open finding without rewriting r1's historical FAIL. Native presentation, physical drag/reorder, performance, source-warning causality and whole-product/full-parity acceptance remain outside this verdict. Main retains ownership of artifact gates and native handover.
