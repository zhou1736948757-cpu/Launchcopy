# Folder Interaction Source Review

Date: 2026-10-16
Verdict: FINDINGS — two P2 issues; no P1 identified.
Review mode: independent bounded source review only.

## Scope and evidence boundary

Reviewed the approved `Docs/FOLDER_TRACKPAD_PAGING_SPEC.md`, the current feedback stage summary, the new folder paging controller, folder overlay paging/lifecycle code, AppDelegate integration/window routing/mount ordering, and KeyboardFocusController cancellation. Inspected existing core/mapper contracts and relevant test source only to trace behavior. The full dirty Git tree is not this stage's change set.

The four reviewed production files matched the 463-input freeze at `.build/verification/20261016/folder-interaction/source-inputs.json` when this report was written. Main reports focused 86/0 and full 2786/0 in 59.142s (`.build/folder-feedback-focused-r2.log`, `.build/folder-feedback-full.log`); this reviewer did not execute or independently reproduce those runs. The prior 2748-test adaptive r2 baseline remains historical evidence. The CGEvent phase-encoding failure is resolved per Main and is not a product finding. Main reports release packaging in progress; this report does not certify that package.

No tests, builds, app/UI operations, reference repositories/assets, global memory, commits, process termination, or installation were performed. Only this report was written. No physical trackpad smoothness, native three-finger window drag, or flash-frame acceptance is claimed.

## P2 — Keep the visual page window aligned with the continuous offset

Location: `Sources/AppGridUI/FolderOverlayView.swift:980-986`, with rendering at 1016-1027.

**Finding / trigger:** A folder with at least three pages starts on page 0. Hold one gesture and accumulate a normalized horizontal delta of 1.5 times the grid width. `PagingCore.applyTrackedDelta` (550-560) allows the visual offset to become 1.5: its non-momentum boundary checks clamp against the entire folder's first/last page, not against the adjacent page. The overlay creates only hosts 0 and 1 at the first moving offset, because its fixed range is based on `currentInnerPage`. At offset 1.5, host 1 occupies the left half of the clipped viewport and its right half has no page-2 host, even though that page exists. At offset 2, the viewport has no member host at all. The same problem can arise after interrupted settling plus continued dragging. Smaller offsets beyond the adjacent page can also occur during momentum overshoot.

**Likely root cause:** The bounded host cache is anchored permanently to the committed page while the reused engine permits continuous positions beyond that cache. `renderTrackpadOffset` only translates existing hosts and never refreshes their page identities.

**Recommended solution:** Maintain at most three presentation hosts around the currently visible offset, updating host membership only when the required page range changes, with generation-gated icon results. Preserve the approved unchanged core physics and keep layout/name resolution and rebinding out of routine per-frame offset updates. An equivalent bounded presentation strategy is acceptable if it covers every visible valid page.

**Affected scope / regression risks:** Folder visual presentation only; protect reverse drags, interrupted settling, partial last pages, clipping, AX/input inertness, and no routine per-frame rebinding. Add a source-level regression with at least three pages, offsets above one page, reversal, and a settle takeover; assert that every visible valid-page region has a host and host count remains bounded.

**Confidence:** High from the explicit offset and frame calculations; not a captured GUI observation.

## P2 — Cancel folder paging in the activation key-equivalent path

Location: `Sources/PagingPrototypeApp/KeyboardFocusController.swift:196-200`; compare the new cancellation at 139-142.

**Finding / trigger:** While the inner pager is tracking or settling, `performKeyEquivalent` handles Return/keypad Enter by calling `activateInnerMember()` and returning true. It never reaches the cancellation added exclusively to `keyDown`. The page state still refers to the old committed page, and activation chooses its selected/first member (413-420), while its real cells are hidden and its visual page may already have moved outside the viewport. This leaves the gesture active at the activation callback and can launch an identity from a visually offscreen page. The existing key-equivalent entry point explicitly accepts these keys regardless of modifiers; existing keyboard tests exercise it as a supported route.

**Likely root cause:** The two supported keyboard dispatch entry points do not share the new interruption policy. Selection membership is checked against semantic page state, but the visual state is not restored before this activation path.

**Recommended solution:** Cancel the folder pager before activating from `performKeyEquivalent`, preferably by sharing the activation interruption step with `keyDown`. Keep title-edit ownership and existing shortcut behavior intact.

**Affected scope / regression risks:** Folder keyboard activation only. Add a regression invoking both Return and keypad Enter through `performKeyEquivalent` during tracking and settling; assert pager inactivity and restored committed-page presentation before the activation callback. Cover both normal and Reduce Motion behavior as appropriate.

**Confidence:** High for the supported source-entry behavior. This review does not claim to have observed a physical key event taking this route on a running window.

## Other reviewed boundaries

- Open-folder window routing returns after consuming every scroll event, including rejected input, rather than forwarding it to the outer surface. Overlay scroll handling also never calls `super`.
- Controller core callbacks are deferred until the core operation returns; pending commit is cleared before outward delivery. The Main commit callback's synchronous cancellation and same-page idempotent refresh do not establish a recursive commit loop.
- Moving hosts are clipped by a dedicated viewport and excluded from hit testing and AX children. Real member cells are hidden while those visuals are active. Ordinary offset updates only change host origins.
- Lifecycle paths cover close/visual-only, content replacement, editor mounting, resize/unavailable geometry, focus loss, hide, and teardown. No independent cancellation/reentrancy defect was established beyond the keyboard entry-point omission above.
- Pointer opening sets model opacity before mounting, suppresses implicit model actions, and prepares final overlay geometry before adding it to the host. This establishes source ordering, not the absence of a physical flash.
- The titled-window titlebar/4pt edge bypass precedes launcher blank-click classification and delegates to AppKit. Native resize-edge ownership and actual three-finger behavior still require native observation; no additional source defect is asserted from the 4pt heuristic alone.
- Initial locale is supplied before overlay use; current material policy is applied before configure/mount. Language and appearance readiness exclude active inner paging and retry on inactivity. Accessibility display changes cancel the inner interaction before refreshing policy/content. No additional readiness defect was established.

## Next action for Main

Assess and repair the two bounded findings, add targeted regressions, and regenerate the relevant frozen evidence/package if production changes. Preserve all pre-existing dirty work. Native/human acceptance remains separate from source review and passing automated suites.


## Re-review R2 — 2026-10-16

**Verdict: Both original P2 findings are CLOSED at the source-review layer. No new P1/P2 findings identified within the same bounded scope.** This supersedes the initial open-findings verdict for the r2 source freeze only; the original findings above remain historical evidence.

### Inputs and verification boundary

Re-read the approved specification and stage summary, examined the repaired overlay and keyboard paths and their new regression source, and checked identity against `.build/verification/20261016/folder-interaction/source-inputs-r2.json` (463 inputs). All four scoped production files match that freeze. Comparing the first freeze to r2 shows only two production paths changed: `FolderOverlayView.swift` and `KeyboardFocusController.swift`; the controller and AppDelegate remain byte-identical to the initial reviewed freeze. PagingCore, ScrollInputMapper, PagingSurface, and Package.swift also match both freezes. Therefore the earlier bounded conclusions on scroll ownership, controller callback/cancel reentrancy, same-page behavior, native chrome delegation, transparent mounting, and locale/material readiness remain applicable.

Read the existing Main-produced logs; did not execute tests. `.build/folder-feedback-review-red.log` records the two new regressions failing with five assertion failures. `.build/folder-feedback-focused-r3.log` records 88 XCTest tests / 0 failures, including both regressions. Its separate zero-test Swift Testing footer is not the evidence used for this count. Per Main, the final `Dictionary(uniqueKeysWithValues:)` to `reduce(into:)` safeguard was added after that focused run; it is present in the frozen source reviewed here. Final full-suite verification of that last change and r2 packaging were still in progress per the handoff; this review does not infer their completion.

No tests/builds/UI/app launches were performed. The only write in this re-review is this appended report section. No reference repository/assets/global memory, commits, process termination, or installations were used. Main reports the Mac locked and native checks blocked; no attempt was made to launch another candidate. Candidate r1 is retained but superseded and predates the finding repairs. This is not a product acceptance claim or physical trackpad, native window-drag, or flash-frame acceptance.

### Original P2 1: Visual page-window coverage — CLOSED

Evidence: `Sources/AppGridUI/FolderOverlayView.swift:969-1048`.

- `beginTrackpadPresentation` snapshots the entry, cell frames, and member-name strings once when the moving presentation is first created. The dictionary uses `reduce(into:)`, avoiding a duplicate-key trap; it does not change the canonical member sequence.
- `updateTrackpadPageWindow` clamps only the host-selection position to valid pages and centers its wanted range on `floor(boundedOffset)`. For a position between pages k and k+1, both visible valid pages are present. At offset 1.5, page 2 now has a host; integer offsets and reverse crossings likewise select the needed hosts. First/last-page overscroll retains the edge host while preserving the engine's original offset.
- Far hosts are removed before missing ones are created, keeping the retained window at no more than three hosts. Existing wanted hosts are not rebound. The helper is called on each offset, but binding/icon requests occur only for missing page identities when the required window changes. All retained hosts are then translated to `(page - offset) * cachedWidth`.
- New cells consume cached text and geometry. The `trackpadGridFrame` access is a snapshot/simple geometry accessor, not a policy resolver or name lookup. Frame/name policy work is not repeated in ordinary frame translation. Missing-page creation is confined to page-window changes. Clipping and inert hit-test/AX hosts are preserved.
- Existing generation/viewport/binding checks remain in the asynchronous icon callback. Evicted cells are captured weakly; retained hosts keep their existing cells and requests. Content replacement, layout changes, cancellation, and teardown still invalidate or remove this presentation, and finish clears the added snapshots.

The new `testLongContinuousDragKeepsFartherVisiblePageInsideBoundedWindow` targets the original 1.5-page gap and bounded host count. Broader reversal/takeover behavior was assessed by tracing range selection, translation, and the unchanged engine contracts; this reviewer did not run or observe those interactions.

### Original P2 2: Activation key-equivalent cancellation — CLOSED

Evidence: `Sources/PagingPrototypeApp/KeyboardFocusController.swift:182-203`, compared with 139-142; `FolderOverlayView.swift:956-959`.

`performKeyEquivalent` now uses the same arrow/Return/keypad Enter/Escape cancellation key set as `keyDown`. Cancellation happens synchronously before title-edit/activation dispatch. `cancelTrackpadPaging` restores the committed offset through the controller and removes the moving presentation before `activateInnerMember` chooses a member. Return and keypad Enter therefore no longer bypass that restoration step. Command-F retains its existing close-then-search path.

The new `testKeyEquivalentReturnAndEnterCancelFolderMotionBeforeActivation` checks both activation keys, asserting inactive paging, visible real cells, and a matching current-page identity inside the activation callback. The test exercises tracking; settling cancellation follows the same unchanged synchronous controller cancellation path, assessed here from source rather than claimed as additional test coverage.

### Remaining gates

No additional bounded source repair is requested by this re-review. Main owns completion and evidence for the final full run and r2 package. Physical/native acceptance remains separate and pending; neither the source verdict nor the existing focused log closes those gates.
