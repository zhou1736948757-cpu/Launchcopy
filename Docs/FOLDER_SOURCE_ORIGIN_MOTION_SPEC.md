# Folder Source-Origin Motion Specification

Status: APPROVED — user selected the recommended glyph-origin open/close contract
Date: 2026-10-16

## Problem and approved baseline
User now accepts the folder frosted appearance and requests that the folder effect originate from the folder's own location. This is a new motion-design request, not a new report that the glass is broken. Preserve the current material, accepted adaptive geometry and paging physics. Existing candidate05c415a0/2794-green remains the baseline; actual native controls passed as bounded observations, not physical gesture/flash/performance acceptance.

## Current-source diagnosis
- AppCatalogAssembly.AppGridRenderer.liveFolderFrame resolves the whole currently committed folder CELL bounds, including padding/captions, not the visible folder glyph.
- FolderMotionGeometry.entryTransform uses source-to-overlay center direction but clamps travel to8pt and initialscale0.96. This is a slight center nudge/zoom, not expansion from the glyph.
- AppDelegate currently applies opacity/transform to the full FolderOverlayView root. The source frame is therefore only a hint; tests encode the old short-travel behavior. No claim that the current implementation already meets a true source-origin animation.

## Recommended visual contract
1. On pointer opening from a visible main-grid folder glyph, begin the folder PANEL at that glyph's actual center and expand/translate to its existing final panel frame. Use the actual glyph frame after layout, not the full cell or a guessed global coordinate.
2. Preserve aspect ratio: uniformly fit the miniature panel within the source glyph's rectangle; do not stretch member icons/text differently along x/y. Fade from transparent while expanding, so miniature unreadable text does not linger. Keep final material/typography/spacing unchanged.
3. On normal pointer close, reverse toward the current valid source glyph. Initial proposal: approximately240ms entrance and200ms exit with a restrained ease-out, no spring bounce/overshoot. These are proposed product motion values, not reverse-engineered parameters or accepted paging changes.
4. Only the panel/material/member presentation moves. Background wallpaper, search and full-window modal outside-hit coverage remain fixed. No full-screen blur/dim, new screenshot, image-copy loop, per-frame layout/icon binding or animation timer.
5. Interrupted opening/closing and reopen start from the current presentation state, not an old model endpoint. Preserve generation gating, inert retained exit visuals and callback/accessibility suppression. Rapid open-close-open must not jump, leave an invisible blocker or revive stale callbacks.
6. Reduce Motion uses the existing short opacity-only/identity-transform equivalent. If the actual source glyph is detached/offscreen/stale/non-finite, opening falls back to opacity-only and closing follows the existing safe synchronous-close fallback rather than flying toward a guessed location. Never retain a stale glyph anchor across committed page/catalog changes.
7. Resize, screen change, hide/teardown and member move-out cancel/reconcile transitions through existing ownership. Source and destination coordinates must share an explicit coordinate system, including backing-scale and flipped-view conversions. The title-editor host identity remains stable; no remount for the effect.
8. Keep keyboard and window behavior, source routing, outer5x7/35 and inner capacities, Timer0ms and all paging parameters unchanged. Motion must not cause pointer launch at an incorrect moving region or leak scrolling to the outer page. Existing policy and interaction gates stay authoritative; ESC/outside-close remains available.

## Bounded architecture / write scope
Pure source-to-panel geometry in AppGridUI with tests for exact transformed source center/size/aspect preservation, reliable source validation and non-finite fallback. A read-only actual glyph geometry seam in AppGridCellView/renderer without changing hit areas. Stable panel-only transition presentation seam preserving current content/editor identity. Owner retains logical lifetime, generation, retained exit and presentation sampling; no new parallel animation owner. Update existing motion/renderer/owner tests to the NEW confirmed design rather than only changing numeric constants to make old tests green. Exact interface names can follow established conventions after confirmation.

## Acceptance and verification
- Native pointer open visibly starts at the clicked folder glyph, across distinct top/center/bottom and left/right positions, and ends at the unchanged correct panel location. Pointer close returns there when valid.
- Pure geometry tests prove fitted mini-panel center/extent and affine mapping, not only translation magnitude. Cover nonzero origins, rectangular glyphs/panels, edge-of-screen anchors, flipped conversions and malformed/missing frames.
- Exercise interruption/reversal, invalid/moved source, retained exit completion/cancellation, Reduce Motion, resize/hide/teardown, title drafts, outside close and scroll ownership. Original raw failed-regression evidence retained.
- Focused/full XCTest, actual Debug/Release/package/localization and independent bounded source review before native handover. Controlled native observations and user physical fluidity/flash acceptance remain separate; no test-only or static claim of animation smoothness.
- Compare actual opening/closing and paging for regressions without relying on UI-automation roundtrip durations as frame timings. No performance guarantee inferred from using Core Animation alone.
- Preserve broad dirty worktree/data/history/old candidates. Unsigned isolated ordinary/non-topmost candidate only, no install/sign/commit/kill/reference-code or resource copying.

## Scope confirmation
Confirm the visual contract: open from clicked glyph into the existing panel, close back toward the glyph, uniform scaling/no stretching, approximately240/200ms, reduced-motion fade fallback. The implementation begins after confirmation; do not silently treat the user's acceptance of material as acceptance of new motion parameters or physical paging.

## Confirmation — 2026-10-16
User explicitly selected the recommended source-icon expansion/retraction,240/200ms, uniform/no-background-motion, Reduce Motion fallback. Implementation authorized. Current glass appearance accepted separately; physical gesture/flash gates remain pending.

## 2026-10-17 — Human acceptance of handed-over source-origin folder experience

The user replied “没问题，继续做吧” after being asked to assess origin expansion/collapse and actual folder-local two-finger navigation. Record no reported issue / accepted folder experience on the handed-over r2 candidate (executable bdb9a6e3; current464 source inputs and candidate identity reverified). This closes that bounded pending human gate, not every hardware/accessibility/performance gate or the whole parity objective. No new timed physical trial,120Hz evidence or wallpaper cause fix is inferred. No implementation/test/build/UI change for this acceptance record. Structured record: `.build/verification/20261017/folder-source-origin-user-acceptance.json`. Continue independently implemented remaining scope, with explicit confirmation before the reserved adjustable main-grid capacity contract.
