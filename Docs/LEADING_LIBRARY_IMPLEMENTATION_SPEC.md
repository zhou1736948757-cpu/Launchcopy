# Leading Library navigation — implementation contract

Date: 2026-10-19. Status: IMPLEMENTATION APPROVED (product decision recorded in LEADING_LIBRARY_PAGE_PROPOSAL.md). Main owns integration and delivery; implementation and physical acceptance remain separate.

## Outcome / scope
The optional Library (still default OFF) becomes the horizontal pane to the left of the first application page. Retain the accessible entry button. Main application page indices, counts, keyboard navigation, catalog identities, folder membership, persisted ordering and app-only dots remain unchanged. No reference source or assets are imported.

## Architecture and identities
Use a boundary-only parent navigator with explicit locations `library` and `grid`; its presentation engine has exactly two positions (0 Library, 1 grid). These are not app page indices and are never persisted or sent to app-page dots, item bindings or catalog providers. Grid retains canonical indices 0...N-1.

Reuse FolderPagingController in manual-frame mode and existing PagingParameters, rather than inventing physics. Add narrowly scoped supplemental-frame demand and advancement to PagingSurface's existing frame driver. There must be no second Timer, frame driver or telemetry callback replacement. Supplemental work stops on cancellation/teardown and may not tick a dead surface after reentrant callbacks. No per-frame catalog projection, icon requests, classification, persistence or layout storms; rendering is translation only.

## Real-input ownership
Folder routing retains first priority. At an eligible first grid page or committed Library, defer an original zero-delta began until the first directional change. Classify horizontal vs vertical and direction with ScrollInputMapper. Deliver original buffered NSEvents once, to exactly one consumer; no new NSEvent, wheel/key simulation or replay to multiple consumers. Grid-directed sequences go to the existing grid surface; Library vertical sequences remain native list scrolling. Once admitted to parent navigation, swallow its entire tail/momentum even across commit. Only a fresh began or independent wheel can select a new owner. Cancelled/lifecycle-invalid streams remain drained, not handed to the other pane.

## Library presentation transaction
Split preview from commit: preview mounts one lazy Library view/projection without hiding grid, stealing focus or enabling app actions. Commit finalizes hidden-grid mode and focus. Cancel invalidates/removes the preview without changing query, canonical page or selection. Input other than the admitted scroll sequence is blocked while transitioning. Restore all temporary presentation transforms and accessibility ownership on every terminal path.

Button entry retains its captured grid context for Close/Escape. Prepare canonical first page under the committed Library using the existing discrete navigation path; do not expose it until ready. A swipe return commits to first app page (same query, cleared pointer selection), whereas Close/Escape resolves and restores the captured prior page/identity using the existing return policy. Query/detail Escape precedence remains unchanged. No focus migration or storage migration.

## Admission / lifecycle
Reject entry while folder open, drag, rename/title editing, marked text, sheet, quit/restore, source invalidation or accepted preference write is pending. Parent tracking/settling participates in presentation readiness (appearance/capacity/language/navigation); completion retries existing latest-wins consumers. Resize, screen change, hide, key loss, feature disable and teardown cancel the parent transaction to its last semantic location, clear transforms and stop frame demand. Reduce Motion uses the existing engine policy, without spatial translation. App arrows remain app-only. Library default/history opt-ins are not changed.

## Verification and delivery
Add focused tests for shared-pump demand/no new Timer, release wait, cancellation/reentrant teardown; preview lifecycle/action refusal; explicit parent identity and unchanged app indices; zero-delta begin, both directions, vertical forwarding, momentum draining, cancelled/resize/hide transitions; button prior-page return vs swipe first-page return and disabled/open-folder refusal. Run focused and full nonzero suites, Debug, Release, packaging and diff checks serially. Obtain independent bounded source review. Native isolated controls/routes and physical touchpad experience are distinct gates; generated gestures cannot establish physical smoothness. Preserve the previous candidate and formal preferences. No install, signing, commit or process signals.

## Risk / maintenance
Keep navigator app-local and testable via input values and callbacks. Avoid prefix adapters across the provider/index model. Tests must preserve legacy folder/main paging defaults. Existing generated drag non-effect remains unresolved and is not evidence for this feature. Record implementation deviations explicitly here and in the stage summary.

## Diagnostic interpretation
Existing telemetry callbacks remain canonical-grid observations, not parent-presentation telemetry; a grid idle/app page0 observation cannot prove the parent is idle or on Library. Shared frame callbacks are preserved, not relabeled. Parent semantic diagnostics/performance measurements must explicitly distinguish the two domains. No physical smoothness claim follows from component tests or ordinary generated CUA scrolling.

## 2026-10-19 current-source ownership regression follow-up
Current902e83b5 source inspection exposes two untested seams: ordinary `.grid` routing directly calls surface before the Window readability guard, and a non-pager owner transition (button entry/hide) does not revoke a previously selected grid/native scroll destination. Add value-input ownership/delivery decisions to the real path, reproduce failures before fixing, drain all prior tails on semantic owner changes, and preserve native Window/AppKit delivery for ordinary grid/native events (including the original held begin exactly once). A separate grid-input availability predicate must stop deferred grid delivery when presentation becomes unreadable. No product semantics, physics or formal preferences change. New source invalidates current-package matching until rebuilt/frozen; retain old RC and honest RED→GREEN results.

### Window suppression ordering correction
The Window's unreadable-stream suppressor must observe a fresh available began/mayBegin/independent wheel before parent arbitration can hold/consume that event. Retain late native Window gating for ordinary grid input; do not move all unreadability rejection ahead of parent routing (which could strand a held begin). Factor the sequence flag into a testable value gate; use a joint value-input dispatch-order regression for unreadable began→available zero began (held)→grid changed, and preserve old-tail rejection until a fresh boundary. This closes the same protected-input contract, not new gesture semantics.
