# Adaptive Folder Layout — Bounded Design Specification

Status: APPROVED_IMPLEMENTATION_CONTRACT, 2026-10-15. User explicitly selected the recommended adaptive desktop folder policy (5x3 maximum, smaller grids as space requires); outer grid and paging physics remain unchanged.

## Problem and intended outcome

Launchcopy users need a folder that reads as a focused, comfortably spaced group within the launcher, not a second screen of35 compressed apps. The current native counterexample shows35 names but no visible member glyphs in an approximately700x500pt window with labelsOn, including48/11 defaults. Restoring1000x700pt restores glyphs. The goal is proportional panel sizing, useful icon/caption geometry and inner pagination instead of sacrificing icon visibility to a fixed35-member page.

## User direction, references and independent design

The user requested a reasonable folder-to-screen ratio and reasonable visible-app arrangement, with Apple's phone folders as inspiration. Apple documents multiple app pages in a folder; its HIG promotes adaptable layouts, grouping, sufficient content space and respect for safe areas. These sources do not prescribe this desktop application's percentages, grid counts or dimensions. The following values are our design proposal, not measurements of iOS or copied implementation/resources.

- Apple iPhone guide, accessed2026-10-15: https://support.apple.com/en-ie/guide/iphone/iph822ece7dd/27/ios/27
- Apple HIG Layout, accessed2026-10-15: https://developer.apple.com/design/human-interface-guidelines/layout

Borrow the principles of a centered focused group, regular icon placement, visible names and paging for excess members. Preserve our own AppKit implementation and current material/lifecycle infrastructure. No LaunchBetter/Buho source, binary evidence or assets are needed or permitted for this slice. No Apple artwork is copied into the product.

## Scope / explicitly unchanged

Change only the open-folder panel layout and its inner-page geometry/capacity, plus the wiring that must agree with it. Keep outer5 columns/7 rows/35 slots, accepted paging physics, Timer0ms, app catalog/search, canonical folder identity and ordered membership, safe mutations, persistence schemas, appearance preference ranges/defaults, activation and Library semantics unchanged. This is not approval of adjustable outer row/column controls, nested folders, uninstall, history, extra gestures, a new blur engine or distribution.

On approval, this is an explicit folder-only exception to the capacity/geometry exclusions in ICON_AND_TYPOGRAPHY_SPEC.md. That prior spec remains authoritative for outer/search grids and appearance persistence. Do not silently rewrite its historical contract.

## Approved user-visible policy

- Prefer a maximum of5 columns by3 rows (15 members/page) in regular desktop space.
- Adapt through4x3 and3x3 when available width does not support comfortable cells. If height still cannot fit3 usable rows, reduce rows before shrinking glyphs; page size is columns times rows. Very small surfaces may need fewer than3 columns/rows, but never zero capacity when an actionable cell can fit.
- Excess members remain in the same folder in their existing order, on additional inner pages.15/page is a visible page capacity, not a total membership limit. A35-member folder has3 pages at15/page and4 pages at9/page, with no membership rewrite.
- Geometry depends on usable viewport and accepted appearance settings, not on how many items happen to occupy the current page. Keep panel size and slot locations stable across full and partial pages; fill rows from the leading top corner, without spreading a short final row.
- Do not shrink the whole folder as an image or retain a crowded35-cell page. Do not make labels disappear automatically to fit; preserve the user's labels setting.

Not selected; would require a different confirmation: always3x3 for a phone-like fixed page count. This is simpler and more consistent across displays, but uses desktop width less effectively. Main recommends the bounded adaptive desktop policy above.

## Proportions, spacing and readability

- The reference rectangle is the launcher's usable content region on its current display, not the primary display's raw pixels. Full-screen uses safe content bounds; ordinary isolated test windows use their own usable bounds. Account for the camera housing, title/toolbar/search chrome, system safe areas and external display changes. Never size a small test window from the full physical screen.
- Center the panel within that region, preserving clear exterior margins. Start visual calibration around60% usable width and65% usable height, with a preliminary900x620pt maximum. Percentages are soft targets: allow content minimums to expand the panel within safe bounds, or reduce capacity when the content does not fit. A fixed percentage may not override readability. On very large displays the maximum avoids an unnecessarily stretched panel.
- Reserve separate non-overlapping title/editor, grid and footer regions. Keep existing title editing, internal page controls and dismissal behavior. Do not reintroduce the removed top-of-launcher page number.
- Use a consistent cell footprint on every inner page. Derive minimum usable height from the requested icon, measured caption line height, focus outline and deliberate gaps, not merely from an intersection/containment check. Defaults remain48pt icon/11pt caption; accepted64/16 must also produce visible useful icons by reducing capacity rather than starving icon space.
- Proposed useful icon lower bound is32pt in supported layouts; honor larger preferred sizes when safe space permits. Do not count a1pt/nonempty rectangle as successful icon rendering. Minimum target geometry must also remain usable with labelsOff and not request more apps simply to fill the freed space in this first version.
- Truncate unusually long visible names within their own cell, preserving the full accessible name. No neighboring caption, title/footer, focus ring or hit-target overlap. Gaps must remain gaps for launch hit-testing.
- Preserve current material, Reduce Motion, Reduce Transparency and contrast behavior; no expensive continuously animated blur. Title placement remains the current panel header for this slice, not a new phone-style title editing interaction.
- If even one useful cell plus essential chrome cannot fit, do not produce invisible actionable apps. Use an explicit non-destructive insufficient-space state with an accessible Close action; restore the same folder/anchor when sufficient space returns. No automatic window takeover/full-screen promotion. Any new text must use existing localization discipline.

Exact cell minima, safe margin and breakpoint constants are engineering calibration within the approved policy, to be documented and tested before integration. Changing the maximum5x3 policy or introducing a different scrolling/interaction model needs renewed confirmation. Do not present preliminary percentages as a physically accepted result.

## Architecture / single geometry contract

Use one pure, deterministic AppGridUI folder layout resolver, returning panel/chrome/cell regions, columns, rows and capacity from usable bounds and applied appearance. Integrate it with existing FolderOverlayView, FolderOpenState and KeyboardFocusController. All consumers must agree on one applied snapshot; do not infer folder columns/capacity from the outer pager or repeat local breakpoint calculations.

Current source coupling to replace only after approval:
- FolderOverlayView has5 static columns and mutable membersPerPage; layout compresses35 members into remaining vertical space.
- AppDelegate.installFolderWiring constructs FolderOpenState from surface.itemsPerPage and copies its capacity into the overlay.
- KeyboardFocusController constructs FolderInnerNavigator with outer columns and folder capacity.
- FolderOpenState currently exposes immutable membersPerPage. Introduce a deliberate folder-only reconfiguration transaction rather than changing only drawing or partially updating membersPerPage.

Resolve/repage at a safe boundary, outside per-frame offset work. Repeated identical geometry is a no-op. Native resize/display change may require safe cancellation of an existing visual transition/held operation; follow existing lifecycle policy, clear obsolete inert exit visuals and generation-gate completions. Appearance changes still defer while drag, held pointer, text composition/title editing or other existing input owner is active. No forced title-editor unmount or draft/selection loss just to apply sizing.

## Stable identities, paging, keyboard and mutation safety

- Keep canonical app order/IDs. On capacity change preserve the focused member's stable identity and compute its new page/slot. With no focused member, preserve the previous page's leading member identity; if gone, clamp deterministically to a surviving neighbor/first page. This is transient presentation anchoring, not a new persisted page schema.
- Reconcile renderer, inner open state, page indicator, keyboard row/column navigation and drag/drop indexing together. Preserve accepted typewriter navigation semantics using the actual applied folder columns/capacity; never use outer5 columns in a3-column folder.
- A drag source/destination must not change page-index meaning mid-drag. Existing safe deferral/cancellation must finish before a new snapshot is committed. Keep move-out proxy geometry/icon identity correct and callbacks epoch-gated.
- Preserve Escape/title-edit/close focus restoration, click-outside close, app launch, canonical destination choices, rename/hide and safe save/Quit behavior. Reflow alone performs no layout store write and does not reorder/dissolve folders.
- Accessible membership/name uniqueness holds per visible page with hidden captions too; off-page cells do not remain interactive/accessible. Explicitly separate AX-tree checks from spoken VoiceOver acceptance.

## Performance and maintenance

Reuse current cells, asynchronous icon pipeline/cache, bounded page residency and binding generations. No per-frame layout solving, scanning, decoding, persistence or wallpaper requests. Repage only when the resolved snapshot actually changes. Prefer a small tested value policy over a second UI/grid stack. Keep current animation timings/physics unless a separately approved task changes them. Physical smoothness/energy/120Hz remain separate gates and may not be claimed from XCTest.

## Verification and delivery

1. Before edits retain the455-input source baseline; authoritative exact manifest is .build/verification/20261015/appearance-store-unavailable/source-inputs-final.json. Use its actual SHA2561b0e05712f5b14afa0010430792c402d75edeee733b42ed2617ed04ed8b87548. Candidate79002dc4eb582358c64dc7937d932c69b090067deb5001eaf9480bcd44b0e473 and previous2700/0 are baseline evidence, not new executions.
2. Pure layout tests: regular/compact/tiny/ultrawide, safe-area/chrome offsets,1x/2x and display transitions; labelsOn/Off,48/11 and64/16, all supported languages/long names. Assert useful icon size, positive/non-overlapping content and fit, not only contained cells. Include boundary cases immediately above/below each adaptive threshold and insufficient-space recovery.
3. Integration tests for0/1/9/15/16/35/36/70+ members, final partial page, navigation/Return identity, page controls, capacity change anchoring, deleted-anchor fallback, drag/title-input deferral, stale callbacks and teardown. Reflow causes zero canonical writes/scans. Add regressions before repair and retain actual failing output.
4. Main serial focused/full XCTest, Debug/Release and isolated packaging. Independent bounded source review before closeout. Preserve broad dirty tree and all pre-existing artifacts; no install/sign/publish/commit/kill or reference-source access.
5. Native isolated candidate with own35+ Info-only apps: default/max sizes and captionsOn/Off, ordinary1000x700pt and compact700x500pt, full-screen safe layout if appropriate, inner paging/reopen/resize, title edit, focus and drag. Verify all35 identities across pages exactly once and normal test-instance Quit. Record native observations separately from test counts.
6. Human visual acceptance for actual full-screen proportions and spacing; physical gesture/frame smoothness, spoken VoiceOver, real IME and120Hz explicitly remain separate. Dense fake-icon evidence is not real-icon performance acceptance.

## Decision and next action

User confirmed the adaptive folder-only5x3 maximum /4x3 /3x3 proposal, not fixed3x3 or preserved35/page. Implement the shared layout/state transaction, test, review, package and verify natively. The following integration clarifications resolve the independent planning review without enlarging the selected product scope. Full reference-experience goal remains ACTIVE/incomplete; unrelated wallpaper/performance/approval gates are not closed by this design.

## Accepted-policy integration clarifications — 2026-10-15

Independent report-only reviewer Ohm identified five design ambiguities; no code/test/UI actions were performed by that review. Main resolves them as follows within the selected policy:

1. Priority is safe bounds and useful requested-size content, then bounded capacity, then soft panel proportions. First expand the soft-target panel up to its safe/max bounds; reduce columns/rows if requested icon plus caption geometry still cannot fit. Do not shrink64pt to32pt just to preserve15 slots.32pt is the minimum selectable preference, not a fallback for a larger preference. Capacity always budgets the accepted caption line even when labelsOff, so visibility toggles alone do not repage.
2. Native resize during title editing retains the same mounted editor, draft, native selection and composition. Do not call non-idempotent configure just for reflow. Defer the grid snapshot until editing ends; keep essential editor/Close chrome bounded and temporarily suppress unsafe member interaction if the frozen grid no longer fits. Existing explicit close/hide/teardown invalidation still cancels by the established lifecycle policy; this is not automatic save. No new window-size takeover or focus theft.
3. Insufficient space is an explicit unavailable member presentation, not just invisible cells. Gate member pointer/Return/menu/drag/AX activation together; keep accessible Close and transient anchor. A mounted title editor has priority over an insufficient-space placeholder, and remains mounted until user finishes/cancels or an established explicit lifecycle invalidates it.
4. Explicit page-button changes clear member selection; the next direction key seeds the current page. Return without selection resolves only the current visible page's first member, never global0 or a stale prior-page index. Keyboard crossing retains its deliberate destination selection. Resize preserves a real selected identity; otherwise keep the prior visible leading member as anchor without manufacturing selection.
5. Preserve existing drag semantics: edge-turn zones remain at the overlay/launcher boundary; crossing panel boundary after move-out is armed remains move-out, not a newly invented panel-edge turn gesture. Freeze the applied folder snapshot during a held drag and use existing resize cancellation before reflow. Canonical logical member indices remain authoritative; top-level page annotations continue to use outer35/committedPage, not inner capacity. No blanket replacement of itemsPerPage. Add second-page reorder/cross-page/move-out indexing tests.

Initial engineering calibration: exterior inset24pt (bounded for tiny rectangles); soft60%width/65%height, maximum900x620pt;112pt minimum cell width, minimum height max(96pt, preferred icon + measured caption line +22pt);16pt gaps; reserve132pt vertical title/footer/padding chrome and48pt horizontal panel padding. Largest fitting columns up to5 and rows up to3; if no useful slot fits expose unavailable state. Supported regular1000x700 and compact700x500 must display requested-size icons; capacity may reduce further at64/16. These are independent Launchcopy constants, not Apple measurements. Validate exact actual geometry before declaring native success.

## 2026-10-19 explicit folder-content refinement supersession
The user additionally requested folder layout refinement. `FOLDER_MEMBER_LAYOUT_REFINEMENT_SPEC.md` now supersedes the prior instruction that real folder members keep standard cell content placement: real/reused/swipe folder members use explicit centered folderGrid context with6pt padding/gap, preserving measured labels, saved size preferences and actual-fit previews. Standard direct callers and main default geometry remain unchanged. This does NOT change accepted panel ratios/max5×3/inner capacity/data/paging/motion or default48 preference. Current own demo uses an explicitly saved64 test preference, not a new product default. See final results for519inputs/61focused/3147full and native evidence limits.
