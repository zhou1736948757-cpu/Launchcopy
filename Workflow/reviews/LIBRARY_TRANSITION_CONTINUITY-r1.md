# Library transition continuity — independent source review r1

Date: 2026-10-20
Verdict: **FINDINGS — one P2 callback-reentrancy defect; SOURCE_ACCEPT withheld for the combined slice.**
Review mode: bounded source inspection only. No implementation edits, build, test execution, UI interaction, process signals, Git mutations, preference changes, screenshots, or reference-product source access.

## Scope and evidence identity

Reviewed the Swift/AppKit composition root, optional same-window Library owner, search restoration, parent navigator, presentation helper, and specified regression tests against:

- `Docs/LIBRARY_TRANSITION_CONTINUITY_SPEC.md`
- `Workflow/stage-summaries/2026-10-20-library-transition-continuity.md`
- `.build/verification/20261020/library-transition/main-review-inputs-r1.json`

All eight Main inputs matched the packet SHA-256 values at initial inspection and the final pre-report check. The repository has substantial pre-existing work; HEAD is not treated as the stage baseline.

The user subsequently declared the worker source stable and explicitly expanded this review to `AppLibraryView.swift`, `AppLibraryGalleryView.swift`, and `LibraryTransitionGalleryWorkTests.swift`, then added the corrected `LibraryResponderIsolationTests.swift`. The two test-only corrections were inspected after the initial worker read. Final supplementary hashes are recorded below; findings do not apply automatically to subsequent repairs.

The retained `red.log` was read: four XCTest cases failed with seven assertions. Its trailing Swift Testing zero-test message does not invalidate the preceding XCTest failures. Later focused-run results were supplied by Main in conversation, not independently executed or certified by this reviewer.

## Finding R1 — [P2] Closing exposes entry admission before a synchronous callback, then destroys the current view

**Location:** `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:255–275`, especially `restoreGrid(context)` at line 272 and `view?.removeFromSuperview(); view = nil` at lines 273–274. Admission: lines 134–143; replacement view assignment: lines 149–156.

**Evidence / source-level counterexample:**

1. Begin with a loaded, enabled, mounted owner, no pending writes, an idle grid, and ordinary transition admission. Enter a committed Library session.
2. A synchronous `restoreGrid` consumer calls `owner.enter()` while servicing `owner.back()`. This is a callback-seam counterexample, not a test executed here.
3. `close` has already set `isOpen = false` and cleared `isPreviewing` at lines 259–260. There is no closing flag in `canPreviewEntry`; if the ordinary lifecycle checks remain satisfied, the nested entry is admitted.
4. Nested entry overwrites `self.view`, creates a new session and return context, mounts its new Library view, and hides the grid.
5. The old close resumes at line 273, reads the new `self.view`, removes it, clears the property, and reveals the grid. It never removes the old outgoing view, whose property reference was overwritten.

**Impact:** the owner can end with `isOpen == true` and `view == nil`, a newly opened projection/session without its presentation, and the old reset Library view still mounted. Grid visibility and navigator semantic ownership can disagree. The new restore-before-detach ordering specifically leaves the old subtree mounted across this callback.

**Production reachability boundary:** tracing the current `AppDelegate.restoreGridAfterLibrary` path did **not** establish an existing automatic nested `enter()` call. The inspected chain is query restoration → optional pending catalog/search commit → surface/layout/focus/readiness updates; `catalogDidCommit` refreshes projection only when open, and readiness work is scheduled. The View-menu action also checks parent transition admission. Thus this finding establishes unsafe synchronous callback behavior, not a reproduced user-event failure or proof that this causes the reported hitch/flicker.

**Likely root cause:** `isOpen` represents both semantic action revocation and lifecycle admission, while cleanup continues through external synchronous callbacks using a mutable owner property. Incrementing `sessionGeneration` before callbacks does not protect the post-callback cleanup because that generation is never checked there.

**Recommended bounded repair:** reject entry throughout close/responder/reset/restore cleanup with an explicit closing admission guard; capture the outgoing view identity before callbacks and detach only that identity. Recheck lifecycle/session ownership before applying callback-following effects, including after a callback tears down the owner. Preserve restore-before-reveal ordering and early action revocation rather than leaving `isOpen` true to block entry. No architecture overhaul is needed.

**Required regression evidence:** exercise a synchronous `restoreGrid` callback attempting entry and verify rejection, old-view detachment, consistent closed/view/grid state, and successful entry after close returns. Also exercise teardown from the callback and retain existing responder-release/nonowned-responder assertions.

**Affected scope / regression risks:** owner close/admission only; cover Back/Escape, swipe return, preview cancellation, hide and teardown. A guard must not suppress legitimate final presentation/readiness notification or the next entry. Confidence: high in the source-level state corruption; current production-event reachability unproven.

## Main slice checks with no additional findings

- `AppDelegate.swift:2154–2181,2632`: attached owner gets `showsEntryButton: false`; the localized View-menu command has both validation and execution-time admission checks, no shortcut, and reuses the existing enabled preference/lifecycle gate. Relabeling updates the menu title at line 3002.
- `AppLibraryOwnerController.swift:264–275`: projection/action revocation and two responder-release passes precede destination restoration. Keeping the outgoing subtree mounted through restoration matches the explicit continuity contract, subject to R1.
- `AppSearchController.swift:145–162`: unchanged empty/nonempty query restoration skips generation/rebind work but still calls the idle commit path; the `pendingCommitter` reaches the shared assembly commit rather than bypassing pending catalog work. A new catalog may legitimately advance the search generation.
- `LeadingLibraryNavigator.swift:148–159,186–209,230–245` and `LeadingLibraryPresentation.swift:7–44`: nested disabled-action transactions cover the specified begin/commit/cancel mutations and layer writes. The helper restores the enclosing transaction state, rejects invalid geometry and clamps reduced-motion opacity. Original-event ownership and the existing supplemental frame pump remain intact.
- The inspected helper/tests support model-layer positions and mutation ordering only. They do not establish native compositor timing or physical smoothness.

## Worker slice assessment

**No additional blocking source finding in the declared worker changes.**

### Result icon admission and queued callbacks

`AppLibraryView.swift:900–907` derives semantic result visibility independently of deferred hidden flags. The sidebar/margin calculation and 600-point side-by-side threshold match `layout()` at lines 334–375. Gallery and narrow-details modes reject result-icon admission even before layout applies visibility; wide details preserve result admission.

Both initial synchronization (lines 912–916) and asynchronous delivery validation (lines 929–937) check this policy. Existing generation, row identity, viewport, mounted visibility and cell reuse/key/generation checks remain present. Mode rejection cancels/clears retained result cells. This is a bounded presentation-work reduction, not snapshot retention, stale action caching, initializer warmup, or changed projection ownership.

### Material cache, visibility and appearance

`AppLibraryGalleryView.swift:128–136` still computes actual window/ancestor/viewport admission. `LibraryCategoryCard` caches effective background/border colors, border width and material-solid policy separately from material activation (lines 156–163,261–284). Switching contrast when already solid need only update border width; a solid-policy-preserving preference change need not rewrite color properties.

Dynamic colors are resolved inside the card's own effective appearance (lines 268–271), so appearance changes can produce different cached colors even when preference booleans are unchanged. `viewDidChangeEffectiveAppearance` reapplies policy (lines 249–252); the existing workspace notification resynchronizes accessibility display policy. The layer guard protects an early appearance callback before the panel layer exists. No stale-color defect was identified in this implementation. Native visibility/appearance event behavior remains outside this source-only verdict.

### Substantive test coverage and fixture lifecycle

The final five `LibraryTransitionGalleryWorkTests` cases preserve meaningful checks:

1. Prime real result admission, switch to gallery before deferred layout, require no new requests and cleared old image, then require gallery requests after layout and stable request counts on repeat synchronization.
2. With selected results, switch to narrow details before visibility layout; require no new requests, cleared image, later hidden result subtree, and renewed requests after widening.
3. Prime the synthetic image cache, prove a cache hit was queued, change to narrow-details intent before yielding, then reject queued image application. `showDetails` does not itself increment presentation generation; the new intent check matters here rather than relying only on stale-generation rejection.
4. Observe layer-property writes across repeated equivalent policy applications and material activation changes.
5. Exercise transparency/contrast effective-policy equivalence, dark appearance resolution, repeated-policy suppression and return to translucent inactive state.

Removing the two `cancellations > 0` assertions is justified by the actual pipeline contract: `IconPipeline.cancelConsumer` counts only a consumer that can transition from pending to cancelled. A load/cache delivery can already mark it delivered before its MainActor UI callback runs. Zero is therefore not proof that view cleanup failed. An unstarted loader task alone would not explain zero, since cancellation bookkeeping occurs synchronously. Request-count admission, explicit image release, resumed work and queued-delivery rejection remain the relevant evidence.

The fixtures use synthetic data and an unshown reported-visibility window, `defer` cleanup, view reset, pipeline shutdown, detachment and window close. Observers capture the view weakly and are removed on destruction; shutdown rejects queued pipeline delivery. No test changes formal preferences or orders/activates a window. The queued-delivery case's bounded cache-prime yield is not physical performance evidence.

The final `LibraryResponderIsolationTests` delta correctly changes the callback-time expectation to a still-mounted outgoing pane while retaining editor release, prior-editor rejection, destination responder acquisition, and the helper's post-close detachment checks. This follows the new ordering contract without discarding the focus assertions.

## Supplementary frozen hashes

| File | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppLibraryView.swift | 7f6fc8a14945b604270ed5b495a9c72014891e4c9cd727c6c051fcc911c95b50 |
| Sources/PagingPrototypeApp/AppLibraryGalleryView.swift | e5f307dee2263bfe3c90945cec28860c7995e3f2637ed0b5b0fe258b95982f92 |
| Tests/PagingUITests/LibraryTransitionGalleryWorkTests.swift | 720c2cfd802d69c7ccf0eea2861b97df12396b0eb7d65a3f948c0d1d5620f2ce |
| Tests/PagingUITests/LibraryResponderIsolationTests.swift | a4c5a2b2457e79f8dee13675e476ae5c9f1f5bae827d50ff91b2b0dc8ee2e081 |

## Handoff and acceptance boundary

Repair R1, preserve this r1 conclusion, and provide a superseding frozen review input for the changed owner and regression coverage. Main retains all serial SwiftPM/build/package verification. This reviewer ran none of those operations and makes no physical performance PASS, native UI acceptance, or whole-app certification claim.
