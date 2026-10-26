# Folder member layout refinement

Date: 2026-10-19. Status: implementation contract for the user's explicit request to refine folder layout alongside the main page.

## Problem and intended outcome
The adaptive panel already owns a maximum5×3 inner page. Its standard cell content places the icon at a fixed top inset and the name at the cell bottom. Growing the panel spreads those two pieces apart (for a152pt row,48pt icon and14pt name, the gap is78pt). This is not coherent icon-and-caption grouping. Refine the folder's internal visual hierarchy independently from the main grid, without silently increasing saved size preferences or replacing its accepted paging/input behavior.

## Scope and geometry
Add explicit folder-member content context. Center each icon+caption stack vertically in its actual cell, with6pt minimum top/bottom padding and6pt icon-caption gap when a caption fits. Preserve measured system-font line boxes, one-line truncation, actual preferred size fitting, hidden-label behavior and bounded finite geometry. Empty cells/small heights must never place an icon over text. Folder regular and transient swipe cells must use the same context; previews capture context/actual glyph fit and provide enough caption/padding space. Standard direct callers and main context remain unchanged.

Keep FolderLayoutPolicy's panel proportions, actual grid slot frames, maximum5×3 and narrow-window reduction in this first refinement. These were already accepted; do not inflate a panel merely to claim a layout change. Preserve source-origin glass/motion, title/footer, ordered identities, inner page capacity/anchors, hit/drop regions, outer layout/physics/cache/persistence and explicit base/folder32–64 preferences/default48. The live existing folder-size control remains the way to choose a larger glyph; no forced migration or extra slider in this slice. The current user request supersedes the earlier main-only exclusion only for folder content placement, not its data/input contracts.

## Related move-out finding
Read-only Dewey found the current move-out callback captures source twice: before collapse, then again after collapse/host switch. This violates capture independence; no measured stutter/image-loss claim follows. Separate bounded repair: capture/elevate before collapse, then use a capture-free elevate-only method after host switch. Retain source-independent cached content, current pointer coordinate conversion and cleanup/generation semantics. No per-move snapshot or icon rebind.

## Ownership, performance and verification
Main owns GridItemAppearance.swift, FolderOverlayView.swift, DragUIVisuals.swift and a new bounded folder-content test file plus documentation. Disjoint worker owns AppDelegate.swift move-out callsite, DragUISessionCoordinator.swift helper split and one new coordinator regression test file. No concurrent test/build/UI; Main integrates and freezes inputs before serial verification. At most3agents includingMain; no old Chef workflow required.

Bounded layout remains O(visible slots), at most15 regular folder slots; no added frame I/O, icon requests, blur, classification, new timers or per-move capture. Prove standard/main compatibility, folder normal/max/dense/tiny/nonzero/nonfinite geometries, exact6pt gap/centered stack, labelsOFF, real regular/swipe context parity, captured-folder-preview size/independence and capture-free post-switch elevation. Preserve RED when available, focused nonzero tests, full suite, Debug/actualRelease/package, fresh source hashes and independent review. Native current-candidate folder open/inner pages/close and cross-cell drag will follow in owned isolated fixtures. Stills/generated events do not certify physical performance, intermediate motion or human aesthetic acceptance.

## Delivery and risks
No preference schema/default/capacity change, formal profile mutation, reference code/assets, OS settings, process signals, install/sign/publish or Git operations. Preserve dirty history. Larger glyphs are not automatically inferred from recentering: report explicit rendered size and leave aesthetic judgment to the human. If native review still shows a poor screen-to-folder ratio, record that counterexample before changing the already-accepted panel policy.

## Fractional preview fit clarification
An optional finite nonnegative iconSideLimit in explicit-context geometry allows a captured32.5pt folder glyph to remain32.5pt while centering with its6pt caption gap. Invalid limits fall back to the stored preference; standard geometry ignores the optional limit and default main output is unchanged. Folder previews pass the captured actual side; they do not mutate a saved preference.
