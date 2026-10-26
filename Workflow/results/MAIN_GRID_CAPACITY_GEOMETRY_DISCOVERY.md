# Main Grid Capacity / Geometry Discovery

Date: 2026-10-17
Status: BOUNDED_SOURCE_DISCOVERY_COMPLETE; PRODUCT_CONTRACT_PENDING_MAIN/HUMAN_CONFIRMATION.
Scope: capacity, geometry, paging, focus, binding invalidation and drag integration only. Settings/store ownership remains with the other reader. Chief workflow waived; no agents dispatched here.

## Evidence and write boundary

- Read project AGENTS.md and `/Users/mac/.codex/RTK.md`; all shell commands entered through RTK.
- Read current SwiftPM/AppKit source, relevant test source, the existing capacity proposal, approved folder specification and Main's new `Docs/MAIN_GRID_CAPACITY_SPEC.md` DRAFT. The draft now defers capacity while any folder is open, including entrance/exit; this is the recommended integration assumption below, not approval.
- The supplied `.build/verification/20261016/folder-source-origin/source-inputs-r3.json` contains 464 entries. Read-only SHA-256 comparison of its 455 Swift source/test and Package.swift entries found **zero mismatches**. The other nine entries were not hashed/read for this audit. This is a source comparison, not an execution result.
- Only this report was written. No production/test changes, builds, test execution, UI/process actions, OS settings, installs, signing, deletes, reset, commit or new agents. No reference implementation/evidence/assets accessed. No native/performance PASS claimed. Historical test/candidate results are not new evidence.
- Line references below are repository-relative and refer to the observed source. A range denotes the function/body inspected, not a proposed write authorization.

## Direct conclusion for Main

The proposed 3...8 columns and 3...8 rows (9...64 capacity) is arithmetically and structurally feasible through the existing app-owned presentation seams, with no demonstrated need to change paging physics or the neutral provider/render protocols. It is **not** a ready-made capability: renderer columns, ordinary row envelope, keyboard columns, page anchoring and same-revision reload must be coordinated.

Three unresolved facts must remain explicit in the specification:

1. **There is no enforced main-grid minimum viewport or readability floor.** Current geometry compresses cells and icons, potentially to zero. The proposed range cannot be called readable at the smallest supported viewport until that viewport/floor is chosen and verified. An 8-row extension retaining current formulas already reduces default folder glyphs to 32.5pt in a 1000x700pt content region and 7.5pt at 700x500pt. These are formula-derived examples, not rendered measurements.
2. **Anchor relocation is not an instantaneous public paging operation.** Existing APIs can count/clamp or request an animated page transition. A capacity contract promising an atomic immediate jump to a different anchor page needs an explicitly authorized seam or an explicit decision to use existing direct navigation and defer focus until settlement.
3. **Seven live hosts / 448 live slots is not a whole-process resource cap.** Cache and loader concurrency are bounded, but old queued icon consumers and retained renderer pages need measured/reproduced lifecycle evidence before promising a total allocation or per-transaction request bound.

Main has sent the product confirmation asynchronously. Do not implement while it is pending. Remaining product decisions go to Main; this reader does not ask the user.

## Fixed values and actual owners

| Concern | Exact source / function | Observed behavior |
|---|---|---|
| Initial capacity | `Sources/PagingPrototypeApp/AppDelegate.swift:458`; `Sources/PagingUI/PagingSurface.swift:227-235` | App constructs Surface with `options.itemsPerPage ?? 35`; Surface initializer clamps to at least one. CLI capacity is already independent of renderer shape; it is not proof of adjustable rows/columns. |
| Surface capacity mutation | `Sources/PagingUI/PagingSurface.swift:41-45` | `itemsPerPage.didSet` only invokes `relayoutPages()` when changed and positive. It does not reject assignment of a nonpositive stored value, synchronize provider count, migrate anchor/focus, or force retained-host content reload. Owner must validate before assignment. |
| Provider default/count | `Sources/AppGridUI/AppGridUIPageContentProvider.swift:84-88,111-115` | Mutable instance capacity defaults to 35; `servedPageCount` derives from current presentation entry count divided by this instance value. Zero is unsafe. |
| Actual render columns | `Sources/AppGridUI/AppGridPageView.swift:33-35,367-379` | Five columns, spacing16; `layout()` creates AppGridGeometry using the fixed columns. No configurable ordinary row property exists. |
| Ordinary/search rows | `Sources/AppGridUI/AppGridGeometry.swift:12-26,29-42` | Default columns5; ordinary always reserves seven rows, including partial pages. Search reserves ceil(actual item count / columns), at least one. Last partial row is centered horizontally. |
| Keyboard columns | `Sources/PagingPrototypeApp/AppDelegate.swift:829`; `Sources/PagingPrototypeApp/KeyboardFocusController.swift:79,100-120` | Owner creates keyboard with5. Controller stores immutable columns and installs one navigator with them. Runtime shape needs a narrow reconfiguration method, not replacement of the responder/editor/controller. |
| Renderer owner | `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:209,230-247,383-428` | `AppGridRenderer` owns per-page AppGridPageViews, live map and retained pool. Surface owns PageHostViews, not app grid shape. Render must inject one applied configuration into new/reused pages and update retained pages coherently. |
| Refresh/search capacity copies | `Sources/AppGridUI/AppGridRefreshController.swift:25,126-133`; `Sources/AppGridUI/AppGridSearchPresentationController.swift:24,90-102`; `Sources/PagingPrototypeApp/AppDelegate.swift:778-781,855` | Provider, refresh controller, search presentation and Surface hold separate values today. Owner must update all from one applied snapshot. |
| Dots geometry | `Sources/PagingPrototypeApp/AppDelegate.swift:3323-3345`, `refreshPageDots()` / `layoutPageDots()` | Count uses provider; bottom gutter independently constructs ordinary geometry with35 and index34. Must derive from applied outer shape, not leave this constant. |
| Neutral diagnostic path | `Sources/PagingUI/NeutralPageRenderer.swift:21-26`; `Sources/PagingUI/PagingPageContent.swift:133-153` | Neutral renderer has its own fixed5 columns and different tile metrics. Keep product controls scoped to real app-grid assembly unless explicitly changing this frozen diagnostic path. |

`Package.swift:1-79` establishes macOS14+, Swift tools5.9, neutral PagingUI depending on PagingCore/localization, AppGridUI consuming catalog/icon/UI seams, and the app target acting as composition root. No new package dependency is needed for this bounded feature.

## Presentation transaction and admission

Actual startup wiring is `AppDelegate.swift:773-781,825-855`. The production idle chain is:

- `AppDelegate.installCatalogPresentationCallbacks`, `:1385-1412`, installs the Surface idle callback and catalog/search result callbacks.
- `AppDelegate.applyPendingAtIdleBoundary`, `:1417-1425`, cancels drag for catalog refresh, calls `AppCatalogAssembly.commitPendingAtIdleBoundary`, reconciles cross-page keyboard focus and refreshes dots/status. Its deferred appearance scheduling moves presentation work off the terminal frame stack.
- `AppCatalogAssembly.commitPendingAtIdleBoundary`, `AppCatalogAssembly.swift:612-614`, stages folder composition then asks search presentation to commit catalog/query together.
- `AppGridSearchPresentationController.applyPendingAtIdleBoundary`, `:90-102`, first applies provider pending data, then restores current query and commits its filtered presentation before notifying the app owner.
- `AppDelegate.applyPresentationUpdate`, `:1332-1363`, cancels drag, selects same-revision reload versus new-revision refresh, reconciles count, lays out, rebuilds focus layout and refreshes dots. **It does not apply `update.outcome` as an anchor-page relocation.** Comments mentioning anchor remapping are not proof that the displayed page follows that result.

Existing appearance admission is useful but insufficient for capacity: `AppDelegate.appearancePresentationIsReady`, `:2345-2355`, excludes teardown/reentrancy/restore/Quit/title rename/held drag/folder motion/inner trackpad/move-out collapse and pinned/nonterminal outer paging. It allows a stationary open folder, and does not itself check all text composition, alias editing, attached sheets or Library transitions. Do not broaden existing scalar appearance behavior accidentally. Add capacity-specific admission reflecting Main's draft, including **any open folder**, text/IME/modal ownership and no gesture/settle. `canCommitWorkspaceLayout`, `:3126-3130`, is persistence/lifecycle admission and is not a capacity-safe idle gate.

`applyAppearancePreferences` / `flushPendingAppearanceIfReady` / `schedulePendingAppearancePresentation`, `AppDelegate.swift:2327-2387`, provide the established accepted/queued/latest-wins and deferred-main-turn pattern. Capacity needs its own applied snapshot/reentrancy guard and a fresh admission check at drain time; no per-frame rebind or I/O. Catalog/query must commit in a defined order relative to capacity so an anchor is captured against the sequence/capacity that actually produced the visible page. Reusing the generic idle function blindly would cancel a held drag; capacity should wait for its release.

## Geometry and smallest-viewport facts

`AppGridGeometry.swift:13-26` uses logical points, side24/top96/bottom24, preferred cell height88 and gap16. For a prospective ordinary shape C by R retaining those formulas:

- usable width W-48; usable height H-120 (both clamped nonnegative);
- cell height h = min(88, max(H-120,0)/R);
- gap s = min(16, max((H-120-R*h)/(R-1),0));
- cell width w = max((W-48-(C-1)*s)/C,0).

This is an algebraic extension for assessment: current ordinary source still hardcodes R=7. Current `frame(for:)` does not reject index >= C*rowCount when itemCount exceeds that envelope; simply setting Surface64 would put extra rows outside the seven-row geometry. A validated shape/capacity agreement is necessary.

`GridItemContentGeometry.init`, `Sources/AppGridUI/GridItemAppearance.swift:28-66`, reserves a measured name line (14pt at11pt font), folder count line up to12pt, top inset12pt and visible-caption gap2pt; it then clamps icon side to available width/height. Main-grid folder cells require more vertical budget than app cells. `AppGridCellView.acceptsLaunchHit` / `layout`, `AppGridCellView.swift:339-349`, use fitted content; containment alone is not readable or useful interaction.

For8 rows, default48/11 and visible labels, when h >=26:

| Content region | h / s | App icon upper bound | Folder icon upper bound |
|---|---:|---:|---:|
|1000x700pt|72.5 /0|44.5pt|32.5pt|
|700x500pt|47.5 /0|19.5pt|7.5pt|
|H=824pt, sufficient width|88 /0|48pt preferred fits|48pt preferred fits|

These values follow exact current cell math extended to8 rows; they are **not** native snapshots. For default folder48/11, preserving the preferred icon requires h>=88, so the zero-gap lower content-height threshold for8 rows is824pt. Full16pt vertical gaps need936pt. At zero gap, preserving48pt horizontally needs W>=48+8*48=432pt, but this is only glyph containment and allows severely truncated labels; it is not a recommended supported width.

Even unlimited height does not preserve a64pt folder glyph under an88pt cap: required height is64 + measuredNameLine +12 count +12 top +2 gap =90 + measuredNameLine. Thus a larger minimum window alone cannot promise full64/16 outer folder glyphs under the existing envelope. Main's draft explicitly permits fitted size reduction; it must not imply the folder-specific preferred-size guarantee applies to the outer grid.

No `minSize`/`contentMinSize` gate was found in inspected `AppDelegate.swift` or `LauncherWindowController.swift`. `AppDelegate.initialWindowConfiguration`, `:1970-1981`, caps initial isolated window frame at1000x700 and permits smaller visible-screen dimensions; this is not a content minimum. Production is screen-covering. Surface `relayoutPages`, `PagingSurface.swift:840-841`, clamps host dimensions to64 internally; that is not a readability minimum. **Actual smallest supported content viewport remains unspecified and not measured.** Required before claiming safe range: name the supported content bounds and acceptable fitted-icon/text/hit floor, then inspect all endpoint/default shapes at that viewport. Do not silently reduce configured capacity or seize window sizing.

## Anchor, focus and binding invalidation

- Provider `topLevelAnchorCandidate` / `topLevelPageIndex`, `AppGridUIPageContentProvider.swift:343-361`, locate a page-leading stable app/folder and map identity to page. Capture using **old** capacity before assignment; passing new capacity with old page chooses another entry. `applyPending`, `:230-235`, returns nil without pending data and is not a capacity-only reflow API. Forcing a canonical layout commit would unnecessarily affect generations/query state.
- `AppGridFocusLayout.position(of:)`, `AppGridFocusLayout.swift:98-101`, already maps identity under a new capacity. But `migrate(identity:)`, `:127-131`, returns unchanged for same or older catalog revision. Ordinary `KeyboardFocusController.applyLayout`, `:242-250`, cannot relocate a selected same-revision capacity change. Use a narrow explicit owner/controller reconfiguration path that relocates stable identity and replaces navigator while retaining deferred selection. Do not forge CatalogRevision or weaken old-revision protection globally.
- `AppGridFocusNavigator.move`, `AppGridFocusNavigator.swift:30-108`, implements accepted typewriter rows/columns and page crossings from configured columns/valid slots. Keep those semantics. Controller `handleArrow`, `KeyboardFocusController.swift:500-528`, seeds deferred focus and tracks cross-page settle target; configuration commit must clear/replace stale pending target and old visual identity coherently.
- `PagingSurface.refreshPresentation`, `:698-706`, does nothing at idle for the same served revision. `itemsPerPage.didSet` only relayouts, and retained content rerenders in `relayoutPages`, `:889-903`, only when revision changes. Capacity needs `reloadCurrentPresentation`, `:741-763`, even if count and catalog revision are unchanged. Its generation bump and forced render invalidate old slot bindings.
- Actual app-page token generation is `AppGridPageView.render`, `:202-237`, which bumps its own `surfaceGeneration` and rebuilds seven-field tokens. `clearForReuse` / `teardown`, `:244-274`, also invalidate. `requestIcon`, `:327-345`, rejects wrong delivered page generation and mismatched cell token. `AppGridCellView.applyIconIfValid`, `:263-268`, checks token equality. A geometry-only setter does not revoke old bindings; same-product shapes (for example3x8 versus4x6) must still receive the new columns/rows and coherent generation policy.
- `AppLibraryGridReturnPolicy.resolve`, `Sources/PagingPrototypeApp/AppLibraryGridReturnContext.swift:13-27`, already relocates a saved selected identity under the current focus layout. `AppDelegate.restoreGridAfterLibrary` / `restorePendingLibraryGridFocus`, `:2514-2541`, use existing direct navigation and defer selection until committed page matches. Decide whether capacity waits while Library is open (smallest integration) or reconfigures the hidden grid; preserve Library state either way.

The page relocation limitation is concrete: `PagingCore.setPageCount`, `PagingCore.swift:338-389`, only clamps the current page. `PagingSurface.requestPage`, `PagingSurface.swift:304-315`, forwards existing direct navigation; `PagingCore.requestPage`, `PagingCore.swift:214-240`, settles with the established spring. It rejects cancelled state. Current public API has no immediate arbitrary anchor-page rebase. Do not toggle Reduce Motion, synthesize physics changes, rebuild Surface or mutate private offsets to emulate an atomic jump. Main must resolve this transaction/UX detail before implementation if immediate anchoring is required.

## Drag and independent folder boundaries

`AppDelegate.makeDragGeometry`, `:1256-1297`, obtains frames from the committed rendered page, annotates top-level frames with **outer committedPage and outer itemsPerPage**, and maps identities to canonical indices. Folder member frames use independent member indices; move-out top-level frames retain outer annotations even when geometry.page is innerPage.

- `DragLogicalIndexMap.topLevel` / `members`, `Sources/AppGridUI/DragSession/DragLogicalIndexMapper.swift:35-70`, preserve hidden/latent canonical references through identity mapping.
- `DropIntentClassifier` insertion conversion, `Sources/AppGridUI/DragSession/DropIntent.swift:250-279`, prefers logicalIndex then annotated page*capacity. `DragUIVisuals.localInsertionIndex`, `Sources/AppGridUI/DragUI/DragUIVisuals.swift:259-268`, mirrors it. No fixed5/35 engine rewrite is needed.
- `DragTransaction`, `Sources/AppGridUI/DragSession/DragTransaction.swift:42-61`, captures canonical layout and catalog generations, **not presentation shape**. `DropResolver.consume`, `DropResolver.swift:28-38`, cannot detect a capacity-only change through those unchanged generations. Preserve held-pointer deferral; revoke residual pre-commit pointer/click/menu ownership at the app boundary rather than adding a new field to this frozen protocol.
- `DragUISessionCoordinator.cancel`, `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:469-480`, is the existing cancellation outlet. `AppDelegate.windowDidResize`, `:3658-3664`, already cancels drag before folder reflow. Retain this behavior and all edge-turn/move-out physics. No canonical write is warranted for repagination.
- `FolderLayoutPolicy.resolve`, `Sources/AppGridUI/FolderLayoutPolicy.swift:26-52`, independently searches at most5 columns/3 rows with readable-size budgeting. `AppDelegate.refreshFolderLayoutIfReady`, `:1811-1858`, owns its applied snapshot/input deferral. Keep this whole path independent. Under the draft's any-folder-open capacity gate, outer changes wait until close/exit completes; later open/close derives source frames live through `AppGridRenderer.liveFolderFrame` / `liveFolderIconFrame`, `AppCatalogAssembly.swift:302-330`.

## Actual resource envelope and limits of the bound

`PagingParameters.swift:120-124` sets livePageRadius1 and prewarmDistance1.5. `PagingSurface.pageRadius` / `currentRange`, `PagingSurface.swift:808-817`, gives radius ceil(2.5)=3: **at most7 attached live hosts** (fewer at ends). One fully populated content pass therefore serves at most245 slots at35/page versus448 at64/page, a64/35 ≈1.83 multiplier. Provider `content`, `AppGridUIPageContentProvider.swift:369-401`, slices at most capacity entries and performs synchronous in-memory mapping. Main-grid folder cells issue no app icon request; app cells issue one per rendered slot (`AppGridPageView.swift:229-236`). Thus a single full seven-page render pass requests at most448 app-icon consumers, not448 simultaneous loader executions.

`AppCatalogAssembly.init`, `AppCatalogAssembly.swift:535-554`, uses default IconCacheLimits unless injected. `Sources/AppIconPipeline/IconCache.swift:17,64-79` defines count256, estimated cost64MiB and loader concurrency4. `IconPipeline.performLoad`, `IconPipeline.swift:342-355`, gates the loader and caps images before cache insertion. These limits **do not cap view-retained images, whole-process RSS, queued unique keys or old consumers**. `IconPipeline.request`, `:237-248`, creates/merges pending tasks without a global queued-key cap; page `requestIcon`, `AppGridPageView.swift:327-329`, discards the cancellation handle and relies on generation rejection. Several rapid reconfigurations can leave older work queued until completion. Do not claim four pending tasks or448 lifetime requests.

Resource caveat for Main, not an authorized repair: `PagingSurface.relayoutPages` zero-count branch, `:843-854`, removes live hosts without the ordinary `clearForReuse` path. `AppGridRenderer.sweepRetiredHosts`, `AppCatalogAssembly.swift:458-465`, skips an entry when its weak host has disappeared; it retires only a resolved host whose superview is nil. Consequently this source does **not establish a fixed lifetime bound on `pages`/retained cells across repeated empty/restored presentations**. Inspecting this lifecycle is required before asserting total retained pages<=7. No leak/native timing was executed or certified here; keep any resulting repair separately bounded and authorized by Main.

`reloadCurrentPresentation` can reconcile count/new hosts and then force-refresh all live hosts (`PagingSurface.swift:755-763`), so newly prepared pages may bind again during one transaction. The448 figure is a **single complete render-pass** bound, not a certified capacity-transaction request budget. Instrument exact request/render deltas in owner tests before specifying that budget; do not solve it by changing prewarm radius, cache size, loader concurrency or frame source without separate approval.

## Minimal coherent implementation plan after confirmation

1. Define one validated outer shape value (C,R,capacity) and one app-owned applied configuration/generation. Preserve5x7 default. Add a narrow configurable ordinary row/column geometry input in AppGridUI, retain search occupied-row centering, propagate through renderer new/live/pool pages. Do not touch folder policy or Package.swift.
2. Use capacity-specific latest-wins admission: no open folder/motion, held pointer, drag, text/IME/modal, restore/Quit or outer gesture/settle/pin. Drain on a deferred main turn, rechecking admission and current owner. Keep scalar appearance queue behavior unchanged.
3. Capture old visible-sequence identity and optional selection with old capacity; resolve pending catalog/query in a defined order; synchronize provider/refresh/search/Surface capacity plus renderer shape; force same-revision reload. Guard synchronous callbacks/reentrancy so observers cannot consume half-updated fields.
4. Resolve the anchor-page transition decision explicitly. Using existing requestPage preserves frozen physics but has a settle interval and needs pending focus/interrupt handling; an immediate rebase needs a narrowly approved interface change. Reconfigure keyboard navigator and selected identity without manufacturing deferred focus. Update dots count/gutter/accessibility from the same applied snapshot.
5. Keep current query/editor, canonical order, layout generation/persistence and folder state unchanged by capacity alone. Re-resolve live folder glyph geometry only on subsequent folder interaction. Handle Library through the agreed wait-or-hidden-update policy.
6. Add focused pure geometry/anchor tests and owner tests at the existing seams; Main performs serialized execution, independent review and exact-candidate native checks. Broaden no engine/store architecture and do not replace frozen public structs merely to add layout state.

## Existing relevant tests and evidence still needed

These are **test-source pointers only; zero tests were executed by this reader**.

| Existing source | Coverage to retain / missing capacity evidence |
|---|---|
| `Tests/AppGridUITests/AppGridGeometryTests.swift:6,24,31`; `Tests/PagingUITests/CompactGridGeometryTests.swift:8,33,56,70,93` | Seven-row stability, compact containment, search occupied rows, partial-row centering. Add all36 proposed shapes, count0/1/K-1/K/K+1/large, endpoint/tiny/nonzero-origin bounds, fitted app AND folder glyph/text/hit floors. No readability PASS from containment alone. |
| `Tests/AppGridUITests/AppGridUIPageContentProviderTests.swift:37,117,191,226`; `Tests/AppGridUITests/AppGridUIPageContentProviderApplyCommittedLayoutTests.swift:146` | Global slots, stable anchor remap, nondefault20 page count, clamping. Add old-capacity capture/new-capacity mapping for app/folder/search/hidden/removed anchors without organization writes. |
| `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift:66,86,215,232,250`; `Tests/PagingUITests/KeyboardFocusControllerTests.swift:194,219,248,283,300` | Non5 columns, typewriter wrap, stale identity, settled/interrupted cross-page selection and deferred focus. Add same-revision capacity and equal-product shape changes, exact Return target after repage, first arrow with no selection. |
| `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift:178,229,256,319,370,389,414`; `Tests/PagingUITests/CatalogHostRangeCommitTests.swift:18,50,70` | Deferred reload/latest-wins/new-catalog priority/count shrink/host bound/stale callbacks/teardown/zero-to-nonzero hosts. Add changed capacity with unchanged count/revision, actual render/request deltas, rapid epochs and repeated empty/restored retained renderer census. |
| `Tests/PagingUITests/IconTypographyOwnerTests.swift:99,115,140,154,203,230,250,274,318,335` | Real owner queue/gesture/pin/held pointer/editor/frame-stack/exit/hide teardown coverage for existing scalar preferences. Add stricter capacity-only open-folder/IME/alias/modal/Library gates and release-driven exactly-once drain without altering scalar expectations. |
| `Tests/AppGridUITests/Bug7PageAwareDropTests.swift:97,203,230`; `Tests/PagingUITests/Bug8VisualIndexTests.swift:79,157`; `Tests/PagingUITests/Bug11RowBoundaryIndicatorTests.swift:220,256,372` | Page-aware insertion, folder independence, move-out annotation and row-boundary visual placement. Add9/64 outer capacity,3/8 columns, partial final rows, hidden-reference mapping and retained pre-change pointer/drop rejection. |
| `Tests/PagingUITests/AdaptiveFolderOwnerTests.swift:57,84,146,168,186`; `Tests/PagingUITests/AdaptiveFolderKeyboardTests.swift:95,239,261`; `Tests/PagingUITests/AppLibraryGridReturnIntegrationTests.swift:111` | Preserve folder maximum5x3/fit/independent state/typewriter/title/drag and Library identity return. New tests must use non35 outer capacity while asserting unchanged folder snapshot/membership/query/category. |

Unclosed evidence gates for Main: confirmed numeric/application contract; chosen minimum content viewport and readable fitted-content floor; immediate-versus-settled anchor-page behavior; Library admission decision; exact per-transaction request/retained-page envelope (including empty presentation); focused/full nonzero XCTest, reviewed narrow diff, Debug/Release and frozen candidate, then native supported-size/IME/focus/drag/restart and matched physical/performance checks. Existing frozen Core/UI protocols and physics remain authoritative; there is no permission here to change them or certify native/performance acceptance.
