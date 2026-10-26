## Human rejection — 2026-10-19

The human reports icons too small and crowded in the center. The128pt width-only policy below is REJECTED as a visual direction, irrespective of green tests. Main withdraws that bounded production/test delta using verified before copies and develops a spacious/main-icon-size revision. No actual native user aesthetic acceptance was ever obtained. Historical selected/implemented paragraphs remain as evidence, not current design authority. See Workflow/stage-summaries/2026-10-19-main-grid-spacious-icons.md.

# Screen-relative main-grid proportions

Date: 2026-10-19
Status: IMPLEMENTATION_SELECTED — bounded visual tuning under the human request; native aesthetic acceptance pending

## Problem and outcome
The human requests a modest change to the launcher app icons' size, arrangement and position relative to the screen, informed by iOS. Existing Swift 6/AppKit/SwiftPM launcher geometry grows horizontal cell widths without bound while explicit glyph preferences remain32–64pt and row height is88pt. The result can be horizontally sparse and vertically crowded rather than visually balanced. Improve scanability and visual grouping without disturbing the accepted pager and organization model.

## Reference and attribution boundary
Public Apple sources inspected:
- [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout): adapt to available space, safe areas, window/device variation and text, retaining consistency.
- [iPhone Home Screen customization](https://support.apple.com/guide/iphone/customize-apps-and-widgets-on-the-home-screen-iph385473442/ios): selectable larger icon presentation; Apple's large option also hides names. Do not silently adopt that coupled behavior here.
- [iPad Home Screen customization](https://support.apple.com/guide/ipad/customize-apps-and-widgets-on-the-home-screen-ipad1b2665da/26/ipados/26): larger-display reference, not an implementation algorithm.
These sources do not establish a universal numeric SpringBoard grid-to-screen formula. All numeric desktop candidates below are independently selected tuning values, not measured or claimed Apple constants. No Apple/reference code, icon assets or private implementation was obtained. A public image fetch timed out; no pixel-ratio measurement is claimed. The comparison is an independently authored schematic, not an actual product screenshot.

## Current measurements
Unflipped logical points, full ordinary page, labels visible/default11pt; bounds exclude any external titlebar. Current columns fill width minus48pt. Top96pt/bottom24pt. These are direct formula evaluations, not native observations.

| Viewport / columns x rows | Current cell W x H | Horizontal / vertical center pitch | Fitted app / folder glyph (48pt preferred) |
| --- | --- | --- | --- |
|1000 x700 /5 x7|190.40 x82.86|190.40 /82.86|48 /42.86|
|1470 x900 /5 x7|271.60 x88|287.60 /104|48 /48|
|1000 x700 /6 x5|145.33 x88|161.33 /104|48 /48|

The seven-row700pt viewport already has zero row spacing. Enlarging glyphs alone cannot repair this height constraint. Folder glyphs may be smaller because their count caption consumes additional height. A64pt preference is currently a fitting ceiling, not a guarantee of64pt rendered size. Do not mislabel settings as physically guaranteed glyph size.

## Recommended first bounded revision
1. Retain the current explicit32–64pt preference and live settings. Do not overwrite saved48/54/etc values or secretly multiply by screen size. Use icon size relative to column pitch, rather than physical screen diagonal or raw Retina pixels, to judge balance.
2. Bound main-grid cell width to a first-pass128pt candidate. Continue current effective inter-cell spacing and center the occupied row. Existing short-window fit can shrink further; never force128pt into an insufficient viewport. This yields max horizontal pitch144pt with16pt spacing. A more conservative144pt width is included in the schematic for comparison; it changes the current1000pt6-column case only slightly, so128pt is the recommended starting point.
3. Preserve existing vertical envelope, occupied-row search centering, partial-row centering, logical3…8rows/columns/default5 x7 and canonical saved order. Do not invent automatic density or left-aligned partial-page semantics in a visual tuning change.
4. Keep folder panel geometry, inner paging, materials and source-origin motion behavior independent. Reuse actual new main-grid cell/glyph frames for hit tests, drag targets and folder motion source conversion; do not apply a purely visual scale detached from interaction geometry.
5. Retain the small-window readability guard and always-accessible settings. More spacing is not possible at every chosen dense capacity; display the established protection instead of changing capacity or shrinking text to illegibility.
6. Keep glyphs and labels distinct and grouped. Caption-stack and vertical-pitch redesign is a separate follow-up if the first preview still looks unbalanced; do not broadly change shared folder content geometry just to compensate for outer horizontal stretching.

## Scope and non-goals
Main-grid placement tuning only; no storage/schema, app order, capacity defaults, new preference mode, launch/search semantics, page physics/frame pump, folder layout/material/gesture, wallpaper/system preference, signing/install/publication or source-reference access. No costly effects, per-frame scans, icon resampling or layout-triggered icon requests. Existing user settings remain authoritative.

## Proposed acceptance before delivery
- Numeric tests: three rows above, max128pt cells, nonzero bounds origins, finite/nonnegative frames, narrow windows, all3…8row/column combinations, ordinary/search/partial/empty pages.
- Rendering, readability, hit testing, drag/drop and source-origin motion all use the same geometry. Preserve stable generation/binding identity and no new icon requests when layout changes.
- No saved preference/order changes on resize; independent FolderLayoutPolicy byte/source unchanged.
- Focused plus full suite, Debug/actualRelease builds, package checks, exact new hash/source manifest and isolated native comparison. Static arithmetic and schematic are not test/native/performance PASS.
- Native wide, normal and compact windows with a controlled fixture; inspect label truncation, first/last-row/page-dot/search separation, actual click activation, drag/drop frame mapping and folder open/close source location. Human aesthetic acceptance and physical paging evidence remain separate.

## Maintenance and risk
Keep one pure shared geometry policy rather than separate constants in renderer, drag code and app owner. Width cap shortens long names sooner and narrows click/drop regions, so review discoverability and blank-click behavior. Existing centered partial rows remain by design. If future work changes vertical grouping or makes glyph size automatic, update the explicit preference and folder contracts rather than silently reinterpreting them.

## Current artifacts and next action
`.build/verification/20261019/main-grid-proportions/proportion-comparison.png` shows current versus selected128pt main-grid cells at the SAME48pt glyph preference in two desktop viewports. It is a geometry schematic, not an actual running app. Computed comparison JSON is next to it. Independent Boyle arithmetic audit confirmed the baseline and recommended128pt. The earlier conservative144pt design candidate has been superseded; no144pt implementation was delivered.

## Main selection before implementation — 2026-10-19

Main selects the128pt cell-width ceiling as a modest implementation of the human's requested main-page arrangement adjustment, using routine-decision autonomy. This does not claim the human chose a numeric Apple formula. Only AppGridGeometry.frame limits the existing fitted width with min(...,128); area/vertical geometry and all saved icon sizes remain unchanged. Existing row centering therefore uses the actual capped width. This supersedes the discovery-only/no-implementation status above, not its arithmetic or safety boundaries. Main owns code/tests and serial verification; independent review receives the stable two-file delta. No need to add a new setting or ask a minor parameter question.

## Bounded independent source review

James accepted the stable three-file source delta (geometry plus pure geometry and existing page-view tests). No new source defect found. Exact180pt first-cell origin at1000 x700/5 x7 is correct under the selected128pt width. Existing activation and drag geometry are distinct: drag uses full-cell frames, while cell-local glyph activation is narrower. This change does not claim to expand click-to-launch coverage; native testing must verify actual behavior rather than call every full-cell point a launch target. Review is source-only, no tests/builds/UI by the reviewer.
