# Folder Source Icon Geometry Worker

Date: 2026-10-16
Status: Implementation and test source stable; execution and acceptance pending Main.

## Exact integration APIs

- `public var AppGridCellView.folderMotionSourceFrame: NSRect?` — read-only actual `folderSymbolView.frame`, in cell-local coordinates after layout. No caption or launch-hit padding, no geometry recomputation, no forced layout, no cache.
- `public func AppGridRenderer.liveFolderIconFrame(for folderID: FolderID, convertedTo host: NSView) -> NSRect?` — converts that exact glyph frame with `cell.convert(glyphFrame, to: host)`.
- `liveFolderFrame(for:convertedTo:)` remains unchanged, including its legacy whole-cell/identity-only behavior and existing tests.

The destination can be the overlay itself, any ancestor, or a sibling in the shared view hierarchy. Its bounds do not need to contain the glyph, and its visibility does not gate conversion. Windowless common-root test hierarchies are supported. An unrelated/detached destination has no shared coordinate basis and returns nil; mount the overlay in the shared hierarchy before querying. Conversion remains in AppKit points and preserves fractional coordinates, including flipped destination views and nonzero bounds origins.

## Source validity

The cell getter rejects non-folder/missing identities, cleared/reused cells, hidden glyph/cell/ancestors, zero-alpha glyph/cell, absent image, detached glyph, empty/non-finite/overflowing/out-of-bounds glyph frames. The getter alone intentionally does not require a mounted cell; renderer ownership enforces mounting.

The new resolver reads only `committedPageProvider` and that page's live dictionary entry. It requires the expected mounted page host, a non-torn-down matching page/presentation, a currently mounted cell with matching FolderID, revision, page identity, reuse generation and surface generation, and a glyph intersecting the source cell's visible rect. It rejects retired/detached/hidden/offscreen/cleared/reused sources without retaining stale anchors or selecting an adjacent page. No layout, hit areas, launch behavior, icon pipeline, motion, physics or package changes were made by this worker.

## Files changed by this worker

1. `Sources/AppGridUI/AppGridCellView.swift` — added the read-only local glyph seam.
2. `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` — added the separate glyph resolver.
3. `Tests/AppGridUITests/FolderIconGeometryTests.swift` — new focused cell geometry tests.
4. `Tests/PagingUITests/AppCatalogAssemblyTests.swift` — added four renderer geometry tests and private synthetic fixture helpers; retained existing whole-cell tests.
5. `Workflow/results/FOLDER_SOURCE_ICON_GEOMETRY_WORKER.md` — this report.

Existing changes in the broad shared dirty tree were preserved. No other files were written by this worker.

## Tests added — NOT EXECUTED

`FolderIconGeometryTests`:

- `testSourceIsActualGlyphFrameWithoutCaptionOrHitPadding`
- `testSourceTracksLayoutWithoutMutatingBindingOrLayoutOnRead`
- `testSourceRejectsUnboundNonFolderAndReusedCell`
- `testSourceRejectsHiddenSymbolCellAndAncestor`
- `testSourceRejectsEmptyOutOfBoundsMissingAndDetachedGlyph`
- `testTinyCellWithoutFittedGlyphHasNoSource`

`AppCatalogAssemblyTests`:

- `testRendererConvertsActualFolderGlyphIntoFlippedHostCoordinates`
- `testRendererGlyphSourceUsesOnlyCurrentCommittedPage`
- `testRendererGlyphSourceRejectsHiddenDetachedOffscreenAndClearedSources`
- `testRendererGlyphSourceRejectsNonFolderStaleBindingAndReusedHost`

The conversion test changes the actual symbol frame independently of the app-icon frame and checks flipped coordinates arithmetically. The ownership tests cover duplicate FolderIDs on attached pages, adjacent-only identity rejection, missing committed-page ownership, hidden and detached hierarchy nodes, wholly offscreen glyphs, page clearing, non-folder bindings, stale surface/page bindings and host reuse. No invalid NaN frame was assigned to an AppKit view; non-finite rejection is implemented as guards and remains subject to Main review.

## Verification and handoff

- Source inspection only; scoped `git diff --check` exited 0 with no whitespace diagnostics.
- Zero tests executed. No build, SPM command, UI launch, other-agent dispatch, install, commit, reset, clean or process termination.
- Compilation, XCTest results, runtime/UI behavior and acceptance are unverified. No PASS claim.
- Main can now integrate the exact APIs above and execute focused/full verification serially. All worker-owned source/test writes are complete.
