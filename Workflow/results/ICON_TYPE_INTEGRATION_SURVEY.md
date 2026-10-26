# Icon and Typography Integration Survey

Date: 2026-10-13
Repository: /Users/mac/Projects/Launch_Copy/PagingPrototype
Status: READ-ONLY SOURCE SURVEY; interface recommendation only, no implementation approval.

## Scope and evidence boundary

This survey covers ordinary and search item grids, top-level folder cells, open-folder member cells, renderer reuse, runtime icon loading, pointer/drop geometry, and drag visuals. Evidence is the current working tree, including other contributors' uncommitted changes, rather than HEAD or an executable candidate. All source references below are repository-relative paths with one-based lines. No Swift command, test, build, app, UI operation, or external research was run.

The approved appearance-first boundary is explicit in Docs/LAUNCHBETTER_PARITY_SPEC.md:58-60 and 73-75. Docs/GRID_APPEARANCE_AND_CAPACITY_PROPOSAL.md:3-5,15-35 remains a proposed capacity contract, not authorization for rows/columns. Its icon/type-only requirement is at 47-50. This report does not approve numeric control ranges or implement either branch. Main subsequently prepared Docs/ICON_AND_TYPOGRAPHY_SPEC.md; it is still PROPOSED_IMPLEMENTATION_CONTRACT (lines 3-6), with 32-64 pt preferred icons, 9-16 pt captions, and automatic fitting awaiting confirmation (25-37,116-120). No feature code should precede that approval.

The user waived the formal chef workflow for this survey. Main performed the survey alone (zero additional agents, within Main +2); no workflow state, events, stage summary, source, test, or spec was written. The only output is this file. The existing tree is substantially dirty; no reset, stash, checkout, cleanup, commit, process stop, or regeneration was performed. The excluded LaunchBetter tree, BuhoReverseNotes, and reverse evidence/assets were not opened. Filenames surfaced by repository enumeration are not evidence used by this survey.

## Findings and recommendation

1. One shared AppGridCellView renders ordinary apps, search apps, top-level folder symbols/titles/counts, open-folder members, and the remaining-member move-out proxy. Actual display size is fixed at **48 pt**, with an **11 pt system name font**. Constructor iconPointSize is a separate request-key input; changing it alone does not resize a displayed icon.
2. The existing caption-visibility propagation is the best integration pattern: application owner -> renderer -> live AND pooled pages -> cells, plus the separately owned folder overlay. Ordinary/search share the renderer; folders do not share its page layout.
3. Drop geometry is based on whole cells. Ordinary/search activation uses icon-frame +4 pt, whereas the folder overlay accepts whole member cells for left click/drag and icon-frame +4 pt for context menus. Preserve these existing distinctions; unifying them would be an additional input contract.
4. DragUIVisuals duplicates icon/name layout and fonts. Styling only real cells leaves the drag preview inconsistent. A drawing-only move-out proxy also has its own creation/reattachment and async fallback paths.
5. There is no source-supported globally safe enlargement range. Folder cells compress below 88 pt even at the largest panel size, and can already overlap captions or overflow. Capacity preservation does not prove visual fit.

Recommended minimum: introduce a two-scalar, non-capacity item-appearance value, centralize its item-content layout, and use the existing visibility propagation without page/content reload. Keep request size/scale/cache identity unchanged initially. Queue appearance application until input and retained folder visuals are free. Define viewport fit and font bounds in a bounded approved implementation contract before exposing controls.

## Exact current defaults

| Surface / concern | Current definition | Source |
| --- | --- | --- |
| App and folder-symbol display | 48 x 48 pt; proportional image scaling and centered image alignment | Sources/AppGridUI/AppGridCellView.swift:24,82-89,261-270 |
| Name / top-level folder title | systemFont(ofSize: 11), no explicit weight; labelColor; centered; tail truncation; one line | Sources/AppGridUI/AppGridCellView.swift:93-98 |
| Top-level folder count | systemFont(ofSize: 10), secondaryLabelColor; centered; tail truncation; one line; text is N items | Sources/AppGridUI/AppGridCellView.swift:100-106,136-148 |
| Name frame | x=2, y=0, width=max(cellWidth-4,0), height=14 pt | Sources/AppGridUI/AppGridCellView.swift:269 |
| Count frame | x=2, y=14, same width, height=12 pt; present only for folder cells with labels enabled | Sources/AppGridUI/AppGridCellView.swift:172-175,270 |
| Icon / symbol frame | x=(cellWidth-48)/2, y=cellHeight-48-12; both views use identical frame | Sources/AppGridUI/AppGridCellView.swift:264-268 |
| Label visibility | true; hides names AND top-level folder counts, not folder overlay title/footer; does not reclaim layout space | Sources/AppGridUI/AppGridCellView.swift:29-34,172-175; Sources/AppGridUI/FolderOverlayView.swift:107-113 |
| Ordinary grid | 5 columns, 7 layout rows, 88 pt cell height; preferred 16 pt spacing; side 24, top 96, bottom 24 pt insets | Sources/AppGridUI/AppGridGeometry.swift:12-25; Sources/AppGridUI/AppGridPageView.swift:32-34,313-318 |
| Search grid | same columns/cell height/insets; rows=max(1,ceil(current-page cell count/5)); each partial row centered horizontally and occupied rows centered vertically | Sources/AppGridUI/AppGridGeometry.swift:22,28-40 |
| Page capacity | default 35 entries; one folder occupies one top-level slot; search pagination remains same provider/surface capacity | Sources/AppGridUI/AppGridUIPageContentProvider.swift:72-78,101-106,360-384; Sources/PagingUI/PagingSurface.swift:39,199; Sources/PagingPrototypeApp/AppDelegate.swift:216 |
| Folder member capacity | default 35; production FolderOpenState uses surface.itemsPerPage; overlay copies that value | Sources/AppGridUI/FolderOpenState.swift:22-35; Sources/PagingPrototypeApp/AppDelegate.swift:712,730-731 |
| Folder grid | 5 columns; spacing 16; nominal cell height 88; panel inset 24, title height 40, footer height 44 | Sources/AppGridUI/FolderOverlayView.swift:231-236,918-938 |
| Folder panel | centered; width=min(max(viewWidth*0.7,200),900), height=min(max(viewHeight*0.8,200),700) | Sources/AppGridUI/FolderOverlayView.swift:900-907 |
| Folder heading / edit button | system 22 pt semibold, labelColor, centered, tail truncation; edit button copies font; editor copies button font | Sources/AppGridUI/FolderOverlayView.swift:253-262; Sources/PagingPrototypeApp/AppDelegate.swift:1502-1504 |
| Folder footer | system 12 pt, secondaryLabelColor; material contrast policy can change color; page text frame height 20 | Sources/AppGridUI/FolderOverlayView.swift:269-272,309,941-943 |
| Hidden outer-page text | system 20 pt semibold, white alpha 0.9; always hidden at initialization; accessibility/page diagnostics retained | Sources/AppGridUI/AppGridPageView.swift:129-135,157-159 |
| Icon request defaults | pointSize=48, displayScale=2, appearance=.system; renderer/page/overlay clamp size to >=8 and scale to >=1 | Sources/PagingPrototypeApp/AppCatalogAssembly.swift:307-310,470,484; Sources/AppGridUI/AppGridPageView.swift:119-122; Sources/AppGridUI/FolderOverlayView.swift:238-241; Sources/AppIconPipeline/IconKey.swift:25-30 |
| Drag preview | fixed 96 x 88 pt; icon 48 pt; name system 11 pt, same 14 pt frame, one line/tail truncation | Sources/AppGridUI/DragUI/DragUIVisuals.swift:352-359,388-415 |
| Preview pointer offset | nonflipped host: y=pointer.y+24; flipped: y=pointer.y-88-12 | Sources/AppGridUI/DragUI/DragUIVisuals.swift:352-359 |

System font means AppKit's system font API; this survey does not assert an installed family name or pixel-rendered font metrics. Folder navigation buttons have no explicit font override in the inspected initializer. Heading/footer, search-field chrome, page dots, and settings typography are not item-label customization targets.

Ordinary geometry reserves seven layout rows even for a short page; partial rows are still centered horizontally. Search uses the number of items on each rendered page, not the total result count. Search results flatten folder members and hide folder entries; clearing the query restores the top-level app/folder composition (Sources/AppGridUI/AppGridUIPageContentProvider.swift:182-201). Layout mode is selected through the renderer's provider closure (Sources/PagingPrototypeApp/AppCatalogAssembly.swift:484-487).

LaunchcopyVisualTokens currently supplies chrome/material tokens, not item icon/font metrics (Sources/PagingPrototypeApp/LaunchcopyVisualTokens.swift:33-59). Changing that file alone does not change cell or preview typography.

## Renderer ownership, pooling, and cell reuse

- AppRuntimeFactory creates AppCatalogAssembly using defaults (Sources/PagingPrototypeApp/AppCatalogAssembly.swift:412-423). Assembly owns the provider, shared icon pipeline, and AppGridRenderer (478-494).
- AppGridRenderer owns pages keyed by page index, weak host references, and a page pool (294-310). Render retires a reused host's previous page, sweeps detached hosts, then takes an existing page, pooled page, or new AppGridPageView (315-359). Retirement clears the page before pooling (398-403).
- Ordinary and search use these same instances. Every render reasserts folder callbacks, context menus, caption policy, and layout mode before rendering. A new appearance value must be reasserted here too (346-356), rather than only during construction.
- AppGridPageView creates a new cell array only when the count changes; otherwise it clears/reuses the existing cells and reasserts policy/callbacks (Sources/AppGridUI/AppGridPageView.swift:234-253). The equivalent folder-member paths are Sources/AppGridUI/FolderOverlayView.swift:792-808.
- App and folder binding synchronously clear previous content, set full text/tooltips/accessibility, and then request icons only for apps. Folder cells use a neutral SF Symbol folder, not an icon collage (Sources/AppGridUI/AppGridCellView.swift:120-169; Sources/AppGridUI/AppGridPageView.swift:167-189).
- clearContent resets identity/text/image/folder state/focus; it leaves font and visibility policy in place. A future style must behave as owner policy, surviving clear/rebind, while default instances reproduce existing metrics (Sources/AppGridUI/AppGridCellView.swift:156-169).
- Focus is drawn on the cell layer (3 pt accent border and selectedControlColor background), independent of label dimensions (Sources/AppGridUI/AppGridCellFocus.swift:21-32). An appearance-only setter should preserve identity and focus, not call clearContent.

Existing working propagation seams:
- renderer live + pool update: Sources/PagingPrototypeApp/AppCatalogAssembly.swift:219-226;
- page -> existing cells: Sources/AppGridUI/AppGridPageView.swift:49-55;
- overlay -> members + remaining-member proxy: Sources/AppGridUI/FolderOverlayView.swift:107-113;
- creation and reattachment of proxy: Sources/AppGridUI/FolderOverlayView.swift:152-162,673-707;
- application startup/current setting fan-out: Sources/PagingPrototypeApp/AppDelegate.swift:600,1463,1841-1849,1882-1890.

## Icon pipeline and stale-result boundaries

IconKey is identity + pointSize + displayScale + appearance; catalog revision is deliberately absent. Defaults imply a nominal 96-pixel request dimension, but **not a guaranteed 96 x 96 delivered bitmap** (Sources/AppIconPipeline/IconKey.swift:16-30). SystemIconLoader resolves identity to URL and asks NSWorkspace for the runtime app icon; it does not use pointSize/displayScale to rasterize it (Sources/AppIconPipeline/IconLoading.swift:31-36). Renderer and overlay use scale 2 in the production paths inspected; there is no automatic backing-scale tracking in their immutable size/scale properties.

Pipeline merges same-key requests, uses bounded memory-only LRU cache, and delivers on MainActor (Sources/AppIconPipeline/IconPipeline.swift:217-260,385-390). Default limits: 256 keys, estimated 64 MiB, four concurrent loads (Sources/AppIconPipeline/IconCache.swift:9-20). Images larger than the nominal 256-pixel cap are reduced before cache insertion; allocation/context failure returns the original image, so the cap is not unconditional (Sources/AppIconPipeline/IconPipeline.swift:342-354,423-463). Cost estimates use the largest representation, not request-key pixelSize (404-417).

Page requests use surfaceGeneration and a seven-field token containing iconKey. Reuse/render advances the generation; completion first checks generation/teardown, then exact token equality (Sources/AppGridUI/AppGridPageView.swift:151-178,193-219,266-292; Sources/AppGridUI/AppGridCellView.swift:177-184). The folder overlay has analogous generation/token guards, and suppresses results while retained as a drawing-only exit visual (Sources/AppGridUI/FolderOverlayView.swift:820-869).

Important distinction:
- Display-only icon/font changes can leave IconKey/token unchanged. Old same-key results still represent the same app and can validly populate its currently styled image view.
- Changing request size/scale requires a request refresh with new key/token/generation and correct pooled-page behavior. Merely changing a scalar, or rebinding a single cell without reissuing the owner request, can reject the old result and leave it blank.
- Current page/member request sites discard handles; reuse invalidates callbacks rather than cancelling obsolete consumers. Rapid new-size key changes would add work even with the four-loader limit. No global cancelAll-for-key should be used to cancel just one view's consumer.
- The remaining-member proxy fallback writes directly to proxy.iconView.image after checking proxy identity and collapsed state, and ignores delivered generation/key (Sources/AppGridUI/FolderOverlayView.swift:705-715). This is compatible with an unchanged display-only key; adaptive size requests would need an explicit stale-style gate. Member completion can also update this proxy directly (857-860).
- Keeping the current key avoids size-variant cache proliferation and extra loads. It does not prove fidelity for arbitrarily large display sizes; quality remains a bounded GUI acceptance requirement.

## Hit geometry and drag behavior

### Activation / context menus

Top-level ordinary/search cells route only an icon/symbol frame padded 4 pt to the cell, with an additional parent-space cell-frame gate in attached hitTest (Sources/AppGridUI/AppGridCellView.swift:234-258). A default isolated padded square is 56 x 56 pt; attached views can clip its effective reach at cell bounds. AppLaunchController checks the same acceptsLaunchHit contract (Sources/PagingPrototypeApp/AppLaunchController.swift:110-127). Cell context menus use that predicate too (Sources/AppGridUI/AppGridCellView.swift:216-221).

Open-folder routing is materially different: overlay hitTest returns the overlay except for title editor/button and paging controls (Sources/AppGridUI/FolderOverlayView.swift:728-743). Its handleClick and mouseDown choose any member whose whole cell frame contains the point (542-590). Context menu lookup chooses the member by whole cell and then delegates to the icon-only cell menu (528-535). Therefore do not infer that folder label clicks are blank just from the shared cell's hitTest.

Resizing the actual icon preserves the +4 padding rule but changes absolute activation area on ordinary/search pages. Keeping a detached 48 pt hit square while changing the image frame would create visual/input disagreement. Enlargements must avoid captions, neighboring targets, and clipping; a cell-wide activation region is not an appearance-only shortcut.

### Drop / drag

Whole cell bounds are exported into host coordinates for top-level and folder drag frames (Sources/AppGridUI/AppGridPageView.swift:90-110; Sources/AppGridUI/FolderOverlayView.swift:200-210). AppDelegate injects current page/capacity and hidden-reference logical mapping (Sources/PagingPrototypeApp/AppDelegate.swift:1009-1049). Do not change those frames or index metadata for item styling.

DropZoneGeometry uses whole rectangles and an inset margin; its center square is one-third of the shorter inset side (Sources/AppGridUI/DragSession/DropIntent.swift:47-70). Default drop margin is 8 pt; drag threshold 6 pt, edge width 40 pt, dwell 500 ms, hysteresis 10 pt, move-out arm 24 pt, minimum edge interval 400 ms, preview scale parameter 1.0 (Sources/AppGridUI/DragSession/DragParameters.swift:55-65). Icon growth can make the unchanged drop center visually surprising, but changing drop zones/thresholds is outside this proposal.

Production active search blocks drag initiation while retaining click arbitration: Sources/PagingPrototypeApp/AppDelegate.swift:848-854; Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:260-269. Use isSessionActive, not merely controller.state == idle, because search click-only presses and pending blank presses count as active (180-194).

DragUIVisuals copies/snapshots the source icon/name and uses an independent mini-cell implementation (Sources/AppGridUI/DragUI/DragUIVisuals.swift:89-118,346-415). Its preview has no appearance policy and its name text is currently set regardless of source caption visibility; this is an existing consistency risk, not fixed by the visibility setters. Folder sources have iconView hidden/empty and a separate folderSymbolView, so the preview capture can fall back to snapshotting the entire cell rather than the symbol alone. Preserve this behavior in the survey; a dedicated source-image seam would need bounded follow-up.

Move-out reuses durable snapshots and switches visual host / elevates preview (Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:221-234). Remaining-member proxy uses shared AppGridCellView but must receive appearance at creation and reattachment; it is drawing-only and must stay excluded from real drop geometry and menus.

## Fit constraints and concrete risks

These are arithmetic deductions from source, not observed app failures:

- An 88 pt cell places a 48 pt icon at y=28...76. Its name occupies y=0...14 and a folder count y=14...26. Keeping the 12 pt top gap and count frame gives only 2 pt between the folder count and visible icon. The padded hit region reaches down to y=24, already intersecting the count frame's upper 2 pt.
- With unchanged name/count frames and icon side S, visible vertical separation requires S <= H-26 for an app name, or S <= H-38 for a folder count. Preventing padded hit overlap with an app label requires S <= H-30. Horizontal containment of a padded square requires S+8 <= cellWidth. These are geometric bounds, not font readability guarantees.
- Folder grid area height is panelHeight-132. Its row pitch is min(104, areaHeight/rows), but cellHeight=max(pitch-16,56), and placement then steps by cellHeight+16 (Sources/AppGridUI/FolderOverlayView.swift:922-938). At panelHeight=700 and 35 members, cellHeight is about 65.14 pt; default icon bottom is about 5.14 pt, overlapping the 14 pt name frame. At overlayHeight=600, panelHeight=480, areaHeight=348; seven rows step by 72 pt, so total extent is 504 pt and exceeds the area by 156 pt. The 56 pt floor defeats the comment's universal-fit claim.
- Ordinary grid spacing clamps to zero, but cell height stays 88. Below 616 pt available grid height, seven rows exceed the area. Folder min width 200 yields member width (200-48-64)/5=17.6 pt, smaller than the default icon. These existing limits rule out an unconditional enlargement promise on every viewport.
- Enlarging the font alone inside the fixed 14 pt name frame can clip ascenders/descenders or localized glyphs. Increasing the frame must respect icon/count separation; do not silently increase cell heights, rows, gaps, page capacity, or panel size to make it fit.
- Larger/variable request keys increase cache variants without making SystemIconLoader honor those dimensions. Arbitrary values need finite/bounded validation before IconKey creation; existing constructor lower clamps are not a supported range contract.
- Folder configure is idempotent on entry/page/motion/catalog revision (Sources/AppGridUI/FolderOverlayView.swift:381-395). Calling it with unchanged content does not refresh appearance-dependent icon requests. A dedicated setter is safer than relying on configure, which can also invalidate the title editor.
- A retained exit overlay must remain pixel-stable and inert. Apply style after its transition/resume boundary, not while a close visual is frozen. Similar care applies to move-out snapshots and title editing.
- Appearance persistence currently has schema 1, required Codable fields, corrupt fallback, and future-version write protection (Sources/PagingPrototypeApp/AppearancePreferences.swift:4-16,45-80). Adding required fields with synthesized decoding would make existing payloads corrupt. Define explicit missing-field defaults/migration and preserve future-version protection.
- Settings currently expose only labels/blur, with draft/apply controls (Sources/PagingPrototypeApp/AppearanceSettingsView.swift:8-10,84-85). The coordinator reports save success and immediately calls its apply closure (Sources/PagingPrototypeApp/AppearancePreferences.swift:113-124); deferred display application needs distinct saved/queued/applied state, not an assertion that saved means visually applied.
- Page-dot layout independently reads the fixed ordinary grid's bottom gutter (Sources/PagingPrototypeApp/AppDelegate.swift:2266-2275). Cell-only styling need not touch it; changing grid row geometry would enlarge scope.

## Reconciliation with Main's proposed bounded specification

Docs/ICON_AND_TYPOGRAPHY_SPEC.md:124-130 records Main's independent native measurements: 11 pt system text needs a 13 pt line and 16 pt text needs a 19 pt line; a 64 pt icon overlaps the old folder-count frame by 12 pt in an 88 pt cell. Those measurements were not rerun by this survey; the measurement script/log was not opened. They support reserving measured caption height rather than changing font constants alone.

The proposed auto-fit behavior at 30-37 is a possible no-capacity-change solution, subject to user confirmation. It should distinguish preferred side from resolved per-cell side and keep launch hits tied to the resolved frame. However, strict default geometry at 55-56 and universal non-overlap acceptance at 97-99 need reconciliation for the existing compressed-folder default cases documented above. Do not silently repair those cases as part of an appearance setter; define and review any maintenance exception explicitly.

Schema-2 migration at 58-63 is consistent with the persistence risk found here. Icon key refresh/cancellation at 70-75 remains an unresolved design branch: the minimal display-only proposal below avoids new keys/requests; if Main selects adaptive request keys, explicit refresh, consumer cancellation, and proxy gating must be added. This survey is an alternative interface recommendation for review, not a replacement of or approval for Main's proposed spec.

Main's concurrent PageDot hidden-ancestor accessibility repair is unrelated and is outside this file's survey/write ownership.

## Minimal safe interface proposal (not implemented)

Place the neutral item-style value in AppGridUI, which already owns the shared cell, rather than making AppGridUI depend on PagingPrototypeApp preferences. Suggested shape, expressed as interface notation only:

- GridItemAppearance: Equatable, Sendable
  - iconSidePT: Double; default 48.
  - nameFontSizePT: Double; default 11.
- applyItemAppearance(value) on AppGridRenderer, AppGridPageView, FolderOverlayView, and AppGridCellView.
- One internal item-content layout policy shared by real cells and DragUIVisuals; default output exactly reproduces the current icon and name frames.

No rows, columns, itemsPerPage, membersPerPage, cellHeight, grid spacing/insets, page anchors, data identities, or request-scale fields belong in this value. Keep system font regular API selection, alignment, one-line tail truncation, semantic colors, full accessibility text, and the existing showsAppLabels policy. Keep count at 10 pt, folder heading/editor at 22 semibold, and footer at 12; their customization is not needed for a minimal item-name control.

Application owner responsibilities:

1. Load/save fields through existing AppearancePreferences/store/settings ownership, with explicit legacy defaults and future-payload protection. No workspace-layout migration or catalog rescan.
2. Validate finite values and a documented supported viewport/type range before accepting the setting. The survey does not assign a safe numeric slider range. Reject unsupported changes honestly; preserve legacy defaults rather than silently introducing automatic density/capacity changes.
3. Keep the latest pending accepted appearance. Apply on MainActor only at an idle, non-direct-navigation, non-pointer-session, non-title-editing, non-folder-transition boundary. An open stable folder may remain open. The existing surface idle callback is a hook (Sources/PagingPrototypeApp/AppDelegate.swift:570-575), not a complete readiness predicate: additionally inspect drag isSessionActive, title editor, and retained/move-out visuals. Do not reuse canApplyFolderAssignment unchanged because it permits settling (2086-2092), or pageNavigationInputIsFree unchanged because it forbids any open folder (2236-2240).
4. Fan out once to renderer live + pooled pages, live overlay, and drag visuals; set the same value on newly created/reused cells/pages/proxies. Do not replace existing single callbacks; compose readiness notification through the current owner.
5. Update item frames/fonts and needsLayout only. Preserve cell bounds, binding tokens, surface/reuse/catalog/layout generations, query/page/focus, request keys, and icons. Same-key in-flight callbacks remain valid.
6. At next drag start capture/apply the source style (including caption visibility) to the preview; proxy creation and reattachment use the same style. Never restyle an active snapshot mid-drag.
7. Keep visual size separate from request resolution. If a later bounded requirement demands adaptive raster keys or live backing-scale updates, specify a separate owner-driven refresh of key/token/generation and requests across all consumers; do not bolt this into the display-only setter.

The shared content-layout helper may adjust internal label heights for approved font metrics while leaving outer cell geometry intact. Any altered default placement, count typography, folder fit algorithm, or hit-region semantics should be stated explicitly in that follow-up contract, not hidden inside a generic scale transform.

## Verification and handoff

No tests were executed. Existing test source identifies useful future regression seams, not a pass result:
- Tests/AppGridUITests/AppearanceLabelsTests.swift:25-54,61-84,103,151,184,224,257 — defaults, bindings/focus/accessibility, visibility, in-flight requests, overlay/proxy reuse.
- Tests/PagingUITests/AppearanceRendererLabelsTests.swift:21,62,107 — live/pool/new-page propagation and render-time policy reassertion.
- Tests/AppGridUITests/AppGridPageViewTests.swift:110,167,227,334,366,399 — stale/out-of-order/merged results, teardown, partial-result centering.

Before any implementation acceptance: verify exact legacy default frames/fonts and unchanged capacity/order/page/query/focus; verify live/pool/new-cell/member/proxy/preview style consistency; delayed same-key completions; saved/queued/applied and legacy/future persistence behavior; press/drag/editor/close-transition deferral; minimum/full-folder geometry; localized labels and accessibility; icon-only ordinary/search clicks versus folder member whole-cell input; unchanged drop zones and paging physics. GUI readability/hit behavior, real restart persistence, and matched physical frame performance remain unverified. The approved spec's later tests/build/candidate gates are not waived by this source-only survey.

The deliverable is a source map and reviewable interface proposal. It is not feature implementation, capacity approval, a successful runtime check, or a declaration of full parity.

## Key source fingerprints at report creation

SHA-256 values identify the working-tree bytes used for the final handoff; they do not certify an earlier test/build candidate. Other contributors may change these files later.

- `Sources/AppGridUI/AppGridCellView.swift`: `52b7fa063c66fa397f7c1b74af73b921aa3f38c6f9335dec88d284537e439874`
- `Sources/AppGridUI/AppGridPageView.swift`: `e4ad35b405f9a2e750b723496f312545cc43d4facdf5e5bf62d576e0edac46af`
- `Sources/AppGridUI/AppGridGeometry.swift`: `f5831cd12187c9b60d6c7762ea7905cf633def8294198b0fcc82b62049b0a1f3`
- `Sources/AppGridUI/FolderOverlayView.swift`: `c15663ae78b97b256685095aea74a2a08c57df19b22c96d4663a0fde58368c51`
- `Sources/AppGridUI/DragUI/DragUIVisuals.swift`: `e3f74a10910d92e924023fa9d41e69ac2cdb1c3fc86038514f1f867b98c4a5c5`
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`: `020029f817b44021912e26b49f08f4c3e7d8cbee70edf487fbb6d9c7865dceb4`
- `Sources/PagingPrototypeApp/AppearancePreferences.swift`: `198d9f3e604359ab6ccf6b0336485f061613481edb4877115eb32a9b5e1caeca`
- `Sources/PagingPrototypeApp/AppDelegate.swift`: `440dcd426d16b4502288d255bfed39975617d6f223718e38350541ca59c5fd76`
- `Docs/LAUNCHBETTER_PARITY_SPEC.md`: `811227da254051ac7539d2c7cf084a397d4fc89f148140a29ae9e6f0f76a918e`
- `Docs/GRID_APPEARANCE_AND_CAPACITY_PROPOSAL.md`: `61a4056be4671b344fe993626b7d1a3bf0d484e039edbffe05d40b96e2cd4fbe`
- `Docs/ICON_AND_TYPOGRAPHY_SPEC.md`: `128f14db9c5f3746e674e122077516ab9ca3290511f09bc6f98469e14a02e3de`

## 2026-10-14 correction — folder grid arithmetic

The original source reserves title40+top24 and footer44+bottom12, totaling120pt,
NOT132pt. The earlier survey's panelHeight-132 derivations are incorrect by12pt.
At max700pt panel, actualarea580pt yields7-row oldcellheight~66.857pt, not65.14.
The56ptfloor still produces realouter-rowoverflowonshortpanels. Corrected actual
view tests red4methods191assertfailures/alreadyfittingexactPASS, repairfocused49/0
recorded in2026-10-14-folder-viewport-fit stage. This dated correction supersedes
only the arithmetic/deriveddimensions; all historicalbytes archived inprior
verificationcheckpoint-docs remain intact. No oldGUI/performancePASS implied.
