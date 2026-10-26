# Library category gallery and responder isolation

Date: 2026-10-19. Status: implementation authorized by the user's supplied visual reference and defect report.

## Problem and outcome
The current desktop sidebar/table Library does not match the requested visual character. A blue native search focus decoration reportedly survives a swipe back to the first application page. Independently implement a category gallery inspired by the supplied iOS screenshot, preserving Launchcopy's performance-oriented presentation and existing functionality. This is not a pixel-identical clone or reuse of Apple/reference source/assets.

## Scope and behavior
- Default Library overview: centered rounded search, spacious responsive category cards with translucent native material, large application icons and a small overflow cluster; category captions below. Show only populated categories, never a long list of zero-count rows.
- Large icons open their current application through existing immutable owner-validated requests. Card/overflow enters the existing category result browser. Keep details, manual categories, alias, hide, reveal, folder assignment and safe removal accessible in result/details flows. Search retains its existing independent query and filtering semantics.
- Overview is derived from the current already-filtered snapshot, not a new scanner/store. Empty/loading/unavailable states remain explicit. Existing optional recent/frequent controls remain opt-in; do not invent suggestions, recently-added data, usage collection or ranking.
- Responsive desktop proportions, not a stretched phone screenshot. Narrow windows reduce columns; preserve readable icons and native keyboard/accessibility operation. Category/search/detail changes remain semantic transactions, not paging-frame work.
- Returning/tearing down must end only the Library-owned field editor/responder before removing its view. Do not remove keyboard focus indication globally or disable keyboard accessibility. Preview never steals responder ownership. Do not discard marked text merely to begin a forbidden transition.

## Architecture and performance
Keep AppLibraryOwnerController as action/lifecycle authority and AppLibraryView as rendering coordinator. Add bounded category-gallery rendering components and a pure geometry helper as appropriate. Reuse IconPipeline, visible-only requests, cancellation on hide/removal/rebind, generation/identity checks and no synchronous icon/file work. Native translucent material has a solid reduced-transparency fallback. No extra frame pump, per-frame catalog projection, repeated blur capture, physics changes, app-page index/storage migration or new dependencies.

## Acceptance and verification
- Regressions mount a real unshown NSWindow and exercise close/swipe-return/reset focus ownership, non-Library responder preservation and preview cancellation.
- Geometry/grouping tests cover empty/sparse/multiple categories and narrow/large windows. Mounted gallery controls test category drilldown, direct action admission, search/list/details continuity and stale-action cancellation.
- Main serializes focused/full SwiftPM suites, Debug/Release and isolated unsigned packaging. Independent bounded review before native verification.
- Native isolated candidate: category gallery appearance, search and category navigation, details/back/Escape; physical swipe/focus-residual requires observed or user confirmation, never inferred from value tests.
- Preserve all existing dirty work and formal data. No commit/reset/clean/sign/install/publish, process signals, forbidden reference-source access or saved private desktop pixels.

## Delivery and maintenance
Document changed files, exact tests/build/artifact hash, review findings and native limits in a visible stage summary; prepend current checkpoints without rewriting history. Previous user physical confirmation only established entering/returning the prior candidate, not follow-finger quality or absence of this newly reported blue artifact.

## 2026-10-19 correction — reported physical blue remnant persists
User reports the wide blue frame still remains after a completed real swipe in559c133c r2. Close-time responder cleanup is insufficient and is not a compositor fix. Add a narrowly scoped LibrarySearchField: replace only this control/cell's default external focus ring with a visible local in-bounds focus stroke drawn as part of the search control, so its drawing shares the moving Library subtree's transform, clip and lifetime. Retain native NSSearchField editing, field editor, IME, keyboard/AX identity, Return/Escape and clear button; keep all other controls' native focus rings. Focus indication must update on native editing, responder, key-window and hidden/removal changes without a timer or per-frame redraw. No parent gesture/physics/layout or query/context changes.
Apple documents focusRingType.none only with an alternative local focus indication: https://developer.apple.com/documentation/appkit/nsview/focusringtype and https://developer.apple.com/documentation/appkit/nscell/focusringtype . This supports the replacement API, not a proved causal diagnosis of this user's pixels. Test local bounds/style/admission and mounted native editing/IME/teardown, then build/package/native inspect; completed physical swipe remains a user gate until confirmed.

### Native-renderer refinement
The first local prototype forced draw-based rendering, but native inspection found the search glyph visibly clipped and the active focus frame loose around the native bezel. Keep NSSearchField's default rendering/updateLayer behavior. Implement the same local focus indication as a noninteractive, accessibility-hidden child view with an in-bounds layer border, fitted to the native intrinsic bezel height. No draw/updateLayer override or shared editor mutation. This supersedes the draw-method implementation detail above, not the local-containment/visible-keyboard-focus acceptance contract.

## 2026-10-20 approved header refinement
Remove top-level overview Back (visual, keyboard and AX target). Parent swipe and existing Escape precedence remain available; drilldown/list/detail Back remains. Overview search stays centered; compact overview uses one search row rather than reserving an empty Back row. No card/paging/persistence changes. User defers remaining first-entry hitch as non-blocking; high CPU remains a hypothesis, not a cause established by this task.
