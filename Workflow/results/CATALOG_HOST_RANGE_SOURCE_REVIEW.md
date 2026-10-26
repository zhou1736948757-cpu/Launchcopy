# Catalog Host Range Source Review

Date: 2026-10-15 (Asia/Tokyo)
Verdict: **BOUNDED PASS — source review only**
Blocking findings in the authorized addition: **None**.

## Authority, scope and evidence boundary

Independent reviewer of the added explanatory comment and `relayoutPagesIfRangeChanged()` call in `PagingSurface.applyPresentation`, immediately after the existing `refreshLiveHostContent(revision:)`, plus the new `CatalogHostRangeCommitTests.swift` file. The helper itself is pre-existing, not a newly implemented helper. Other dirty-tree changes, including `onPageNavigationChange`, are baseline context and are not approved by this verdict.

Read the project AGENTS.md and requested stage summary. The explicit user/agent waiver supersedes formal Chief workflow for this bounded review. No agents, goal operations, Swift commands, tests, builds, application interaction, process control or implementation edits were performed. All shell commands were RTK-prefixed. Only this report was written. No outside reference implementation/assets or reference evidence was read.

Independent evidence consists of source inspection, the scoped working-tree diff, and SHA-256 measurements. Supporting project source was inspected only to trace the changed call and test fixtures. No execution logs or `.build` evidence were read. The R4 source manifest is a known historical source baseline, not current-input verification; this review does not compare the huge dirty tree against R4 or attribute its other changes to this repair.

Main's reported native empty-result contradiction and `range-red-r2.log` result (3 tests, 6 assertion failures) are supplied context, not independently reproduced evidence. The reported `initialrange-red.log` was a compile error and is not counted as reproduction. This report certifies neither compilation nor green tests nor native source-watch acceptance.

## Source assessment

- **Missing hosts / page count:** Core's `setPageCount` positive-count idle branch clamps the offset and only emits an offset event when the value changes. At idle offset zero, 0-to-1 and 1-to-3 page growth need not emit offset/state events. The new call compares desired keys with actual live keys and mounts missing hosts immediately, without needing a viewport change. Shrink removes out-of-range hosts through the existing reuse path; an empty desired range is handled by the existing helper.
- **Binding / same range:** The existing refresh runs first and sets `renderedRevision` to the effective pass revision. When range keys are unchanged, the helper does not call layout, so the addition causes no second content binding. With ordinary growth/shrink at unchanged offset, layout renders only newly missing hosts; retained hosts skip the revision-drift re-render branch because the refresh already established the revision baseline. Existing callback-driven layout that may occur inside `core.setPageCount` is baseline behavior, not a newly guaranteed single-bind path.
- **Pinned revision:** No pin/latest-wins policy is changed. Busy-state refresh continues to cache the newest revision. Deferred application still clears the pin at the idle/cancelled boundary before `applyPresentation`; new hosts use `effectiveRevisionForPass()`. The addition does not bypass the existing busy-state gate or mint catalog revisions. This conclusion concerns the ordinary supported commit sequence, not arbitrary mutation from observation callbacks.
- **Events:** The addition neither sets Core state/offset nor synthesizes a Core commit. Necessary host-range changes legitimately invoke the existing layout/page-prepare hooks. Same-range commits add no layout/page-prepare notification. Existing presentation/navigation notifications remain baseline code.
- **Reentrancy:** The helper and layout have entry teardown guards; the shown production layout/page-prepare observers only record telemetry. Ordinary callbacks do not cause the new same-revision refresh to recursively apply a revision already adopted. No new pin or pending-snapshot state is introduced. Conditional mutation from inside layout callbacks has a baseline limitation described below; this is not a blanket reentrancy certification.
- **Teardown:** A surface already torn down is rejected at `applyPresentation`, refresh and helper entry. If the existing host refresh synchronously tears down the surface, the added helper rejects further layout. No deferred work, timer or new lifecycle owner is added. Teardown during the layout pass itself has the baseline callback limitation below.
- **Comment accuracy:** The explanation correctly identifies the absent-event case and the reason to reconcile after the refresh. Its no-double-bind statement applies to the added post-refresh reconciliation; it should not be read as a universal claim about pre-existing synchronous callbacks in `setPageCount`.

## Meaningfulness of the new tests

1. Lines 18-48 use the actual owner callback wiring and a retained active query. The viewport is established before the empty result, and the test requires a mounted host plus the matching cell text after a new revision. It also checks query/bounds/revision and a repeated idle-boundary call. This meaningfully exercises the reported owner-level regression, rather than accepting only provider status/count.
2. Lines 50-68 bypass owner reconciliation and require a cell/host after a direct zero-page revision commit while observing zero offset events. This isolates the absent-offset-event mechanism. It does not assert zero state events or full mounted-view ancestry.
3. Lines 70-90 check no additional layout for the unchanged range, growth to three live pages, shrink to one, zero offset and zero commit count. This meaningfully covers necessary range work, but layout count alone is not an exact binding-count assertion.

Non-blocking test improvement: record render/bind requests after fixture setup and assert one refresh per retained host plus one render per added host, with page/revision/count identity. Add explicit state-event/host-ancestry assertions if those become acceptance requirements. The current tests are headless presentation tests; automatic filesystem watching and visible native mounting remain Main's separate acceptance gates. Existing seam/search tests provide relevant source-level context for pin, generation and post-teardown behavior, but were not executed by this reviewer.

## Baseline limitation to Main (not an in-scope blocking finding)

The pre-existing `relayoutPages()` loop has no renewed teardown check after `onPagePrepared` (around line 886). If an observation hook synchronously calls `surface.teardown()` while the first host is prepared during a multi-host pass, subsequent loop iterations can mount remaining hosts and the pass can publish `onLayoutPerformed` after teardown. The added reconciliation makes that existing layout routine reachable during a previously silent count commit, but the same weakness exists in pre-existing resize/input/count layout entry points. No shown production telemetry observer performs such a mutation. This is a concrete conditional source trace, **not an executed reproduction**, and no broad baseline repair is requested or authorized here. If Main treats mutating observation hooks as supported, separately scope a callback-lifecycle guard and a focused teardown-during-prepare regression before claiming that stronger guarantee.

## Input identity

The two review inputs were SHA-256 measured before detailed inspection and rechecked unchanged immediately before report creation. Supporting-file hashes below are an end-of-review context snapshot, not a claim that all 405 R4 source inputs match. Stage-summary edits by Main are independent documentation activity.

| File | SHA-256 |
| --- | --- |
| `AGENTS.md` | `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc` |
| `Workflow/stage-summaries/2026-10-15-native-parity-verification.md` | `5f1a551c9aae48aee9e51628a4fc792cbb5535986f28379e92c9350f585e7285` |
| `Sources/PagingUI/PagingSurface.swift` | `966615670bde489514a734779befae082a3e79b692eab28de83e770c04b3e439` |
| `Tests/PagingUITests/CatalogHostRangeCommitTests.swift` | `fc16e7d020d90432dbb94ecf5499665cae1c7ac1f4e2d67c31d926d9a1152808` |
| `Sources/PagingCore/PagingCore.swift` | `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369` |
| `Sources/PagingUI/PageHostView.swift` | `e896713c1e4aae7cddb5fc9724f304d0b2d0c6ecc8a1defbba0eb869353e97ad` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `8d78ea4f207b3d7a6bf23bff8ad7b9795e01bbbf40fb11b3d6567bcabdbf24d3` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `82f6e12d6427142bdab69c86366f9b655366514a98eceab0955c83b740fb79f5` |
| `Sources/AppGridUI/AppGridUIPageContentProvider.swift` | `8344e01e5cb28f032c51097a7fcfda1b0868b36978b2490b5e0d3436989d8628` |
| `Sources/PagingPrototypeApp/PagingTelemetryBridge.swift` | `f58154b182b584397e93edf23fedb06c13d252ecca2c4d19dcffeded0920f80c` |
| `Tests/PagingUITests/TestSupport.swift` | `0fc1111d229233a3b5b38d084bb2e2469ea5c31acde459016df65744b9ba47a1` |

Added comment-and-call block SHA-256 (UTF-8, including original indentation/newlines): `9143c998878502dee211127a52acd0b51ce2eb1a707157742f84b9342bd2fd18`.

## Delivery and remaining gates

Only `Workflow/results/CATALOG_HOST_RANGE_SOURCE_REVIEW.md` was created. Frozen source and new test bytes remain unchanged from initial review measurements. Main owns test execution, build identity, new candidate preparation and native watch verification. Bounded PASS applies only to the reviewed range-reconciliation addition and the usefulness of its regression tests under the evidence limits above; it does not close the full parity stage.
