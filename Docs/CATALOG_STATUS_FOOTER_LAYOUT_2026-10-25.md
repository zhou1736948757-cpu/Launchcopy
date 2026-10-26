# Catalog status outside application content

## Problem and scope
Native inspection of the current integrated preview shows the compact catalog warning over the lower-right application captions. This violates the existing readable-chrome requirement. The previous goal turn delivered folder naming and truthful warning classification; it was progress, not whole-product completion.

Move content-present refreshing/partial-discovery status into the existing grid footer gutter, beside rather than over the page-dot strip. Keep the existing grid, source policy, warning semantics, folder naming and paging parameters unchanged. No new diagnostic collection or private app information.

## Presentation and layout contract
- Loading, empty, no-results and no-content error messages retain the existing central multiline presentation.
- With application content, refreshing/partial-failure uses a 20pt-high, one-line compact status. Use an inline spinner for refreshing and a system caution glyph for partial failure. The complete message remains the accessibility label and tooltip even when narrow widths require visual tail truncation.
- Use only the already-reserved bottom gutter from the existing main-grid geometry. Prefer trailing space beside the entire page-dot frame; use leading space when that is larger. Do not shrink or move page dots or any cell to make room. If neither footer side can hold a caution glyph, use only an existing header gap below search/settings and above the grid; never overlap those controls. Tiny gaps may show the glyph with the full message in accessibility/tooltip rather than clipped text.
- Keep frames finite and inside the host. No overlap with the reserved dot frame or any ordinary-page cell; extremely small/unreadable windows cannot promise readable full warning text.
- Recompute the frame after every admitted capacity or appearance metric commit, after page dots are laid out. An unchanged catalog state, query, locale, page count or host size must not leave stale status geometry; geometry invalidation must not trigger string formatting on the commit stack.
- The view stays passive: no input interception, focus, new action or synthetic input. Library masking and teardown semantics remain authoritative.
- Coalesce presentation/style updates off frame callbacks. No resource loading or string formatting from layout/frame work; typography is independent of app label size.

## Architecture, verification and delivery
Main owns the view, composition, a small pure footer-frame resolver and tests; no implementation agents are needed for this tightly coupled bounded slice. An independent read-only review follows stable source inputs. First reproduce the overlap through the actual installed owner, then test footer geometry, dots/resize/nonzero origins, all three languages, semantic/AX/full-text retention, busy/error controls, nil hit testing and no-content fallback. Preserve all existing tests and layout parameters.

Run focused/full tests, Debug/Release/strict packaging and independent review. Use a unique unsigned sibling in the same isolated profile; preserve the user's latest arrangement/settings and old diagnostic capture, use normal Quit only, and distinguish native presentation from physical gesture acceptance. No reference source/assets, real-app mutations, signing, installation or Git mutation. Update the stage, plan, project memory and delivery index. Broader parity, exact scan-failure categories and intermittent dragging remain unproved.
