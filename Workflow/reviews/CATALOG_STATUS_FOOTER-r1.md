# Catalog status footer — independent review r1

Date: 2026-10-25
Verdict: **FAIL — one P2 integration finding (bounded source review).**

No independent test, build, packaging, performance, or native/UI execution was performed. This review used source inspection, existing Main-owned logs, and read-only manifest/digest comparisons. The only authored file is this report. No application process operations, UI interaction, app drag/reorder, Git operations, agent dispatch, candidate changes, or user-profile access/mutation occurred.

## Scope and frozen identity

Specification: `Docs/CATALOG_STATUS_FOOTER_LAYOUT_2026-10-25.md`.
Stage: `Workflow/stage-summaries/2026-10-25-catalog-status-footer.md`.

- Frozen manifest: `.build/verification/20261025/catalog-status-footer/source-inputs-r1.json`, **610 entries**, SHA-256 `62d6091bd96cb679177846803e2ddce62940a1ec7e8eb4854f415036cdc7c389`.
- Delta manifest: `source-delta-r1.json`, **six paths**, SHA-256 `c5e29b6272d23716a5153794e971533a244566153c8102ab2ca09c33939516ad`.
- Inherited manifest: `inherited-source-baseline.json`, **607 entries**, SHA-256 `4caa50b09f62e834c8a8c51e7fd6a8b792873207778204a22c69961a3118a4dc`.
- Manifest comparison yields exactly three changed existing files, three additions, 604 unchanged entries, and no removals. The derived six-path delta matches the supplied delta.
- Independently compared current bytes for **607 non-asset source/script inputs**, including all six delta files: zero mismatches. The three localization `.strings` assets were deliberately not opened or hashed; their recorded digests match the inherited manifest. This is not an independent byte verification of all 610 inputs.
- No LaunchBetter, BuhoReverseNotes, raw-reference, or asset content was read.

Reviewed delta:

1. `Sources/AppGridUI/AppGridStatusView.swift`
2. `Sources/PagingPrototypeApp/AppDelegate.swift`
3. `Sources/PagingPrototypeApp/CatalogStatusLayout.swift`
4. `Tests/AppGridUITests/CompactCatalogStatusTests.swift`
5. `Tests/PagingUITests/CatalogStatusLayoutTests.swift`
6. `Tests/PagingUITests/LanguageStatusNoticeRuntimeTests.swift`

Supporting reads were limited to the layout, renderer, lifecycle, localization API, and relevant existing tests needed to trace these changes. The inherited manifest identifies hashes, not historical file bodies; this review does not attribute every existing line in the two production files to this slice.

## Finding F1 — [P2] Recompute the compact frame when committed grid metrics change

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:301-319`; missing invalidation at `2694-2709` and `4720-4752`.

**Finding and impact.** The compact status frame depends on the committed capacity, item appearance, and current page-dot frame. Both metric-commit paths update the grid and call `layoutPageDots()`, but neither calls `layoutCatalogStatus()` or schedules its layout. A visible, unchanged refreshing/partial-failure status can consequently retain the old gutter frame after cells occupy that space. This violates the specification's exclusion of every ordinary-page cell.

**Evidence and source-derived regression (not executed):**

1. Use a stable, readable 1200×900 host, default main icon size 80 and label size 11, at least 24 visible entries, page 0 with no fractional offset, and a committed visible partial-failure status.
2. Start with **8 columns × 3 rows**, finish initial presentation/layout, then commit **3 columns × 8 rows** through the existing capacity owner. Both shapes have 24 slots, so this case needs no page-count change, anchor navigation, new catalog/query/locale event, or resize.
3. From `MainGridLayoutMetrics.swift:5-20` and `AppGridGeometry.swift:15-26,39-42`, the initial preferred cell height is 114. The initial bottom gutter is 227, giving the status frame **x=832, y=103.5, width=360, height=20** beside the existing 320-point dot strip.
4. After the shape commit, the grid area height is 780 and eight rows have 97.5-point cells with no vertical spacing. The bottom-right actual cell occupies **x=792...1176, y=24...121.5**. The retained status frame intersects that cell.
5. `PagingSurface.swift:41-45,768-791` does not supply a compensating idle transition in this equal-product, unchanged-page-count case. Its navigation notification reaches `refreshPageDots()` (`AppDelegate.swift:3925`), which changes readiness/visibility but does not lay out the status. The new compact style's equality guard also supplies no incidental presentation callback for an unchanged state/style.

**Likely root cause.** The new footer consumer was attached to installation, status presentation, and root resize/search layout, but not to the existing capacity and appearance metric commits. Leaf page layout is not an explicit status-sibling invalidation.

**Recommended solution.** At both admitted metric commits, recompute status geometry after the dot frame is current, or use a shared geometry invalidation helper with the same ordering. Keep string formatting deferred; a geometry update should not require a new semantic state or a catalog refresh. Do not change cells, paging, or dot geometry.

**Required regression.** Mount the real owner/status/dots and a full real page; establish the warning, apply the equal-product 8×3→3×8 change, and lay out the changed page without manually invoking status layout or forcing root resize. Assert status/actual-cell and status/entire-dot-frame nonintersection and host containment after the admitted commit and deferred turns. Exercise an appearance-only change too, for example 48→96-point main icons at 5×5 in the same host with an unchanged warning. Retain the no-format-on-calling-stack, passive hit-test, and Library/teardown assertions. No regression file was edited or executed by this reviewer.

**Affected scope.** Content-present compact statuses across existing capacity/appearance changes. Initial resolver geometry can be correct while this owner transition remains incorrect.

**Regression risks.** The repair must preserve coalescing, the narrow header fallback, Library visual/AX masking, teardown generation fences, central no-content presentation, and unchanged page/cell geometry.

**Confidence.** High in the missing source invalidation and arithmetic counterexample. Native repaint timing and the duration of visible overlap were not independently observed; they are not claimed.

## Other bounded source checks

- **Finite footer geometry and full dot exclusion:** `CatalogStatusLayout.swift:9-46` validates host extents and preferred height, constrains the returned nonempty footer frame to the existing gutter, and uses the whole supplied dot frame with an eight-point side gap. It selects the larger side, prefers trailing on ties, and caps width at 360. The owner passes the existing dot view's complete frame rather than the visible individual dots. No new grid or dot-frame mutation is introduced in this path.
- **Cells, capacities, resize, origins:** the owner uses the same main-grid metrics as `AppGridPageView.layout()` and the last full-capacity row for a conservative ordinary-page boundary. Bounds origins are carried through the resolver. Root layout and window resize/screen-change paths order search, dots, then status. Existing pure tests sample 3×3, 5×5, 8×8 and two origins at three sizes; the mounted-owner regression checks actual cells at the fixture's default capacity. Those are not exhaustive owner transitions across all 3–8 row/column combinations; F1 remains open.
- **Existing narrow header gap:** `CatalogStatusLayout.swift:34-43` only falls back when footer-side width is below 24 and the available gap is at least 16 high. With the owner's ordinary finite control frames, its bottom is above the grid area and its top remains below both search and settings. No controls or cells move. The new narrow test uses supplied synthetic control frames; it is not independent native evidence.
- **Passive status/full text/indicators:** `AppGridStatusView.swift:135-158,171-192` keeps the full rendered message in the label value, parent AX label, and compact tooltip; visual text is one line with tail truncation or hidden when too small. The caution glyph and refreshing spinner are inline, their descendants are not separate AX elements, and hit testing always returns nil with first-responder admission rejected. Tooltip display and VoiceOver behavior were not exercised natively.
- **Central no-content style:** `AppDelegate.swift:303-305,321-326` selects compact style only for content-present refreshing/partial-failure. Other/no-content cases retain central multiline layout; `AppGridStatusView.swift:140-144,194-216` restores regular wrapping and label visibility.
- **Deferred formatting/no new layout IO:** `AppGridStatusView.swift:76-87,122-158` stages state/style, coalesces through the main queue, and formats only in the deferred renderer using a retained `LocalizedStrings` snapshot. Frame/layout work does not construct a localization snapshot or load localization resources. Compact typography uses a fixed 11-point font independent of app-label preferences. The newly frozen coalescing regression checks calling-stack formatting and equal-style updates; this is not proof of native performance.
- **Library/teardown:** the committed semantic-visibility latch is recomposed with Library masking after presentation. Identity checks, owner/view generations, weak captures, and teardown cancellation prevent obsolete callbacks from restoring a removed view. Existing Library visibility tests cover visual/AX masking, return, replacement, and late completions. No new defect was found in those source paths.

## Existing Main evidence inspected

All counts below come from existing logs; none is a reviewer execution:

- `before-r1.log`: one mounted-owner test, three assertion failures: two cell intersections and the former 54-point status exceeding 20.
- `focused-r1.log`: 41 tests, zero failures.
- `focused-r2.log`: compile errors; no valid test execution/pass.
- `focused-r3.log`: 43 tests, zero failures.
- `focused-r4.log`: 48 tests, zero failures, including the coalescing regression added before the freeze.
- `full-r1.log`: the completed XCTest summary read during review reports 3770 tests, zero failures in 72.090 seconds. This supersedes the dispatch-time “in progress” description only as inspected Main log evidence.

Latest Main handoff additionally reports Debug/Release/strict packaging PASS with three locales × 369 keys and the standalone 1107-entry smoke PASS. Those packaging results were not independently executed or audited here. Main reports the unique StatusFooter candidate (digest prefix \`32bdb0c0…\`) packaged but not launched, with the old PID 51878 candidate and current user profile preserved. Native handover remains Main-owned and pending this source conclusion.

These logs do not resolve F1: the new geometry matrix calls the resolver directly, and the mounted owner case does not change capacity or appearance while the warning remains unchanged.

Main retains sole ownership of any repair, refreshed freeze, execution/build/package gates, unique isolated candidate, and native presentation checks while preserving the latest human profile. This review provides no native gesture, physical drag/reorder, performance, release, or whole-product acceptance. Existing source-warning causality and physical dragging remain outside this slice.
