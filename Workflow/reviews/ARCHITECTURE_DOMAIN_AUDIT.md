# Architecture domain audit — PagingCore / PagingUI / AppGridUI

Date: 2026-10-20. Mode: read-only source audit; the sole authored artifact is this report. Authority: the current bounded user assignment and `Docs/ARCHITECTURE_MAINTAINABILITY_OPTIMIZATION_SPEC.md`; historical Chef dispatch machinery is bypassed. No agents were spawned.

## Evidence and coverage limits

| Production target | Inventory coverage | Source lines |
| --- | ---: | ---: |
| PagingCore | 6 / 6 Swift files | 1,313 |
| PagingUI | 13 / 13 Swift files | 3,323 |
| AppGridUI | 58 / 58 Swift files | 10,174 |
| Assigned total | 77 / 77 Swift files | 14,810 |

All 77 files were enumerated and checked for imports, size and baseline SHA-256 correspondence. Their paths and line counts match `source-inventory.json`. The supplied whole-project inventory contains 217 files / 45,785 lines; **this report does not deeply audit those 217 files**. All assigned source hashes and `Package.swift` matched the supplied baseline at the checks before report creation. Main may independently change app/UI files outside this slice.

Baseline inputs: `.build/verification/20261020/architecture-review/baseline-inputs.json` (SHA-256 `f3b820047c242bb3845527ec1d9c871cad7061e0c0c3c11d594dee1f8380270c`); inventory SHA-256 `d5ab3e49908827c9b3f576b5946c06a3ce5bcf070f67f265e59e23e72a273b6c`.

Deep inspection followed specific paths: Core gesture/settle/environment/callback ownership; Surface versus FolderPaging input and frame ownership; workspace mutation/projection/reference resolution; drag transaction/resolver/index conversion; journal load/enqueue/flush/reset/codec/IO; provider composition and anchor remapping; shared grid geometry/capacity/readability. Supporting source bodies were also read for refresh/search policy, library domain values, diagnostics and selected view binding/lifecycle methods. The appendix distinguishes these from inventory-only files. Deep inspection is path-based, not proof of every branch.

No test, build, UI session, runtime profiling, process signal, Git mutation, formal preference access, installation or reverse-reference evidence access occurred. Test files were read only. No physical/performance acceptance is claimed. The reported first Library swipe hitch and requested search blue-frame removal remain Main's app/UI work; `AppLibraryView`, its owner, Main-owned focus and main-search UI implementations were not opened or changed for this audit. The five findings below are source deductions, not observed incidents on the running application.

## Module and ownership assessment

- **Dependency direction is coherent at the declared-target level.** `Package.swift:19,25-28,52-55` keeps PagingCore independent; PagingUI depends on Core and localization; AppGridUI depends on catalog domain, icon pipeline, PagingUI and localization. Assigned production imports do not reach the executable, scanner or telemetry target. No target-cycle or undeclared cross-module import was found in this static inventory. This is not a build result.
- **Existing seams are worth preserving.** Core owns committed page, continuous offset and transition qualification (`PagingCore.swift:43-83`). Surface owns host residency and revision pinning (`PagingSurface.swift:123-175,692-790,835-951`). FolderPagingController treats the owner-supplied discrete page as authoritative and defers outward callbacks until Core work returns (`FolderPagingController.swift:47-60,74-101,229-284`). PersistentWorkspaceLayout is durable authority; VisibleWorkspaceProjection resolves currently available records without deleting latent references (`VisibleWorkspaceProjection.swift:72-141`). DragTransaction captures layout/catalog generations, DropResolver validates them, and LayoutMutation returns a new value (`DragTransaction.swift:42-62`, `DropResolver.swift:28-45`, `LayoutMutation.swift:69-84`). The two page authorities are scoped; their existence alone is not duplicated mutable truth.
- **Geometry has real reuse already.** MainGridLayoutMetrics feeds both AppGridPageView and readability checks; GridItemContentGeometry feeds cells and preview-related consumers (`MainGridLayoutMetrics.swift:5-37`, `AppGridPageView.swift:377-391`, `MainGridReadability.swift:17-46`, `AppGridCellView.swift:353-365`). FolderLayoutPolicy has a different adaptive capacity/chrome contract. Do not merge folder, main-grid and neutral-fixture layouts merely because each computes rows.
- **Logical purity is stronger than package isolation.** LayoutDomain, DragSession and AppLibraryDomain largely use value types/Foundation, but reside in the AppGridUI target, which transitively brings AppKit/presentation dependencies. This is a future extraction seam, not grounds for an immediate new target. The store already offers injected IO and a bounded flush receipt; a generic preferences/store framework would obscure its journal and quit semantics.

## Prioritized findings (five)

### 1. [P1] Encoding can acknowledge a layout that the same store refuses to reload

**Evidence:** `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift:102-120,125-143,249-257`. Encode checks folder/reference/member counts and domain invariants, then returns the complete checksummed JSON without checking its byte count. Decode rejects every payload above `maxFileBytes` (1 MiB). Reference string lengths are not bounded by `WorkspaceLayoutValidator.validate` (`Sources/AppGridUI/LayoutDomain/WorkspaceInvariants.swift:80-132`). `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:414-432` accepts successful encoding as a successful journal write; `:214-216` puts the store into read-only protection if either slot is over limit on next load.

**Cause / risk:** Write acceptance and read acceptance implement different bounds. A valid layout below the count caps can exceed 1 MiB through long references or their aggregate JSON overhead. Persistence can report success, but a fresh actor cannot restore it and enters protection even if the other slot is valid. This is a concrete contract mismatch; occurrence in the user's data was not assessed.

**Smallest bounded fix:** Encode the complete envelope once, check `data.count <= maxFileBytes`, and throw the existing `.overLimit` before any IO. Preserve the limit, byte format, checksum and existing actor rejection mapping.

**Proposed verification, not run:** Extend `Tests/AppGridUITests/LayoutStoreCodecTests.swift` with a count-valid, byte-oversized layout, accepted near-boundary round trips including the checksum, and assert rejection preserves the previous journal through injected IO. The existing size test at `:206-208` exercises only decode. No schema migration is needed. This is the strongest small immediate candidate.

### 2. [P1] Reset and initialization do not participate in the journal's asynchronous ownership protocol

**Evidence:** `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:137-163` archives/cleans slots and calls `persistOnce` directly without waiting for `writerTask`, claiming `isPersisting`, or fencing the old pending revision. Normal enqueue/flush ownership is explicitly claimed before suspension at `:309-315`; its drain uses revision fencing at `:318-365`. Both paths await IO, including fixed per-slot temp paths at `:402-428`. Initialization checks only `hasLoaded` and sets it after suspension at `:180-205`; another first caller can enter initialization before completion. The public protocol imposes no caller-side serialization precondition (`Sources/AppGridUI/LayoutStore/LayoutStore.swift:96-108`).

**Cause / risk:** Actor isolation serializes individual execution segments, not an entire operation across `await`. A reset can archive/delete a suspended writer's temp file or race the same slot/generation; an older writer can resume and publish state or bytes after reset. Concurrent initial calls can also duplicate cleanup/lock/load work. These are conditional API-level interleavings, not a claim that the current UI always reaches them.

**Smallest bounded fix:** Share one in-flight initialization receipt, then put reset behind the existing writer ownership boundary with an explicit reset epoch/state. Drain or fence the old writer before archive/cleanup, and define how enqueues accepted during reset are retained. Do not merely cancel the Task and assume suspended IO has stopped. Keep the current coalescing/flush outcome behavior.

**Proposed verification, not run:** Reuse the gated-memory-IO pattern in `Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift:134-165`: suspend write/replace, invoke reset, optionally enqueue a successor, release the gate, and assert at most one journal writer, defined final layout, monotonic write generation and no stale state publication. Add concurrent first-load/load-enqueue coverage with a creation/read gate and one initialization result. Existing reset tests first flush or wait for terminal rejection (`LayoutStoreActorTests.swift:327-340`, `LayoutStoreTerminalOutcomeTests.swift:89-107`), so they do not demonstrate overlapping reset safety. This needs a dedicated lifecycle change, not opportunistic cleanup.

### 3. [P1] Future-version protection requires the future document to retain the entire v1 shape

**Evidence:** `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift:84-92,126-136` decodes `WorkspaceLayoutEnvelopeV1` before inspecting `schemaVersion`. Missing/retyped v1 fields produce `.corrupt` before the future-version branch. `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:207-216,228-244` protects recognized future versions but can load a valid alternate slot when the future slot was misclassified corrupt; rotation treats that slot as a replacement target (`:435-442`).

**Cause / risk:** Version dispatch depends on successful decoding of the version-specific payload. A future JSON layout with a readable higher `schemaVersion` and changed required fields is treated as corruption. With a valid alternate v1 slot, a subsequent normal write may replace the future slot; without one, it can be quarantined as corrupt. That contradicts the declared no-downgrade/no-touch future-version contract (`LayoutStore.swift:23-34,96-98`). This is a forward-compatibility case, not evidence that a future-format file currently exists.

**Smallest bounded fix:** After the existing byte cap, decode a minimal version header first. Classify a higher supported integer version as protected before decoding the v1 payload; retain full checksum/structure/invariant validation for version 1 and existing behavior for malformed/older versions.

**Proposed verification, not run:** Test a higher-version JSON missing/retyping v1 fields with A-only, B-only and valid-v1-peer configurations; assert load protection, enqueue/flush no writes and byte-identical originals. Existing fixtures preserve the v1 structure and only change the version (`Tests/AppGridUITests/LayoutStoreActorTests.swift:359-380`, `LayoutStoreJournalRecencyTests.swift:146-152`, `LayoutStoreCodecTests.swift:260-272`). This is a bounded codec compatibility repair, separately reviewed from journal ownership.

### 4. [P2] Callback ownership hardening covers direct navigation but leaves gesture takeover vulnerable

**Evidence:** `Sources/PagingCore/PagingCore.swift:456-464` calls `interruptActiveTransition`, then unconditionally creates a gesture session and publishes tracking. The interrupt helper calls outward `onStaleRejection`, then `onInterruption`, then publishes interrupted with no ownership/teardown recheck (`:602-615`). In contrast, requestPage, cancel and Reduce Motion restart recheck ownership after outward callbacks (`:223-239,393-406,413-432`), and beginSettle uses `ownsTransition` (`:565-599`). Surface forwards the interruption/stale observers synchronously (`Sources/PagingUI/PagingSurface.swift:660-666`).

**Cause / risk:** The callback contract permits synchronous reentrancy, but individual paths enforce it differently. Start a non-immediate settle; have `onStaleRejection` call `teardown`; then feed `.began`. Source control flow continues to `onInterruption`, creates a new session and publishes tracking after teardown. A callback-issued newer request can likewise lose state ownership. This violates the declared terminal teardown/no-residual-callback invariant without requiring threads. No runtime reproduction was run.

**Smallest bounded fix:** Make interruption/takeover return whether the same operation still owns continuation, check after each outward notification and before session creation, and retain the existing direct-navigation behavior. Cover cancellation/newer transitions as well as teardown; one check at the public entry is insufficient. Avoid changing paging physics.

**Proposed verification, not run:** Add sequence tests where stale, interruption and interrupted-state observers respectively tear down, cancel or request a new page during physical takeover; assert no post-teardown callbacks/session, no overwritten newer context and bounded commits. Existing normal takeover (`Tests/PagingCoreTests/DirectPageNavigationTests.swift:82-87`), direct/RM reentrancy (`:89-105,131-174`) and ordinary teardown (`Tests/PagingCoreTests/PagingCoreTests.swift:666-697`) are complementary source coverage, not this sequence. A later shared operation guard may reduce repeated checks; do the targeted repair first.

### 5. [P2] Mixed-entry anchor fallback uses hash order instead of a stable domain ordering contract

**Evidence:** `Sources/AppGridUI/AppGridUIPageContentProvider.swift:444-487` delegates app-only remapping to CatalogPlanner, but its mixed app/folder path independently chooses successor/predecessor using `AppID.hashValue` and `FolderID.hashValue`. The relevant comparisons are `:480-486`; fallback selection is `:462-471`. The narrowly inspected catalog seam uses `AppID.anchorOrderLessThan` (`Sources/AppCatalogCore/AppCatalogCore.swift:443-462`). Persistent layout order is explicitly preserved by projection (`Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift:95-135`).

**Cause / risk:** Hash values are not semantic ordering keys and are not stable across process launches; collisions can also compare distinct identities as equal here. Once an anchor disappears in a mixed layout, the reported successor/predecessor and page can vary with hash seed rather than the intended ordering contract. Presence of a folder switches to a different independently maintained policy. Located anchors are unaffected; the audited one-page folder-creation expectation cannot establish multi-page missing-anchor behavior (`Tests/AppGridUITests/AppGridUIPageContentProviderApplyCommittedLayoutTests.swift:68-83`).

**Smallest bounded fix:** Explicitly specify mixed-identity fallback ordering, use the existing domain app ordering where applicable and a controlled stable folder ordering, then replace only the hash comparisons. Do not sort/rewrite the user's stored workspace. FolderID's opaque representation must remain private; do not add logging of IDs or use debug descriptions as keys. If the intended fallback is visual-neighbor order instead, record that semantic choice before implementation.

**Proposed verification, not run:** Add multi-page mixed layouts where app and folder anchors disappear, with relocated surviving entries and fixed folder IDs; assert exact outcomes under the chosen policy. Verify across fresh processes/hash seeds through Main's serialized test workflow. Include unchanged located-anchor and app-only fallback cases. Extract a shared anchor-policy helper only once its consumers genuinely share that contract.

## Immediate candidates and staged work

Only two small candidates are nominated; neither was implemented. Main's active Library cold-entry/search-frame work takes precedence.

1. **Codec byte-limit guard (finding 1):** a single acceptance-boundary repair, with no disk migration, layout change or dependency change. Main should record selection in the spec before coding and run the proposed focused checks.
2. **Optional exact diagnostic run-ID helper:** the same sanitizer appears in `Sources/PagingUI/FrameProfileRecorder.swift:280-287`, `FrameCallbackProfileRecorder.swift:309-316`, and `RunLoopProfileRecorder.swift:211-218`. Move the identical scalar replacement/64-character/default logic into an internal helper, keeping all public wrappers and output filenames unchanged. Preserve Unicode/grapheme behavior, test representative existing outputs, and leave distinct clock domains, buffers, drop accounting and record schemas separate. This is a maintenance reduction with three real consumers, not a performance improvement claim; it is lower priority than correctness work.

| Stage | Bounded scope and prerequisite | Required evidence before advancing |
| --- | --- | --- |
| A | Main triages findings and selects changes in the existing spec; freeze each implementation input independently of app/UI work. | Exact per-file baseline and explicit owner; no acceptance inferred from this report. |
| B | Separate compatibility/size repairs and the Core takeover guard; journal initialization/reset is a distinct lifecycle task with accepted ordering semantics. | Focused codec/sequence/gated-IO tests, no format or physics drift; Main owns all execution. |
| C | Define mixed-entry anchor fallback, then share only that policy. Consider a shared release-wait/input session after comparing Surface and FolderPaging semantics. | Identical event traces for release/momentum/cancel/RM/resize/reentrancy; preserve Surface pinning, folder authoritative-page behavior, and manual/shared frame demand. |
| D | If feature growth warrants it, extract a pure workspace-domain target and narrowly isolate folder swipe presentation from the overlay; one boundary per change. | A written dependency/API map; preserve latent references, distinct generations, privacy and journal receipts. Domain/store separation need not be one change. |

For stage C, the shared mapper is already correct reuse (`ScrollInputMapper.swift:53-107`). The remaining duplicated action consumers are `PagingSurface.swift:497-560` and `FolderPagingController.swift:187-222`; they differ in callback deferral and accepted-ended bookkeeping. Do not mechanically merge their controllers or timers without explicit lifecycle parity tests. Keyboard synthetic-fling behavior is also distinct from direct navigation (`KeyboardPageTurner.swift:66-77`).

For stage D, a typed internal persistence projection should replace private-layout reflection before moving FolderID across a target boundary (`FolderDomain.swift:31-42`, `LayoutStoreCodec.swift:295-307`). Do not broaden serialization/logging access merely to split files. Folder motion currently references the view-nested MotionParams (`FolderMotion.swift:17-18`, `FolderOverlayView.swift:59-82`); move that value contract only alongside a concrete consumer extraction. Keep FolderLayoutPolicy's adaptive frames as the seam, rather than forcing the neutral and main-grid policies into it.

No broad refactor, implementation, benchmark improvement, buildability certification or physical acceptance is authorized or established by these recommendations. Final testing/build/package/independent review belongs to Main on frozen implementation inputs; the physical retest gate remains separate.

## File coverage appendix

Every row below has full inventory/hash/import coverage. `D` identifies the deep contract paths listed above; `S` means supporting body/range inspection without a deep end-to-end ownership trace; `I` means inventory/declaration coverage only. These labels intentionally avoid implying equal review depth across all files. Large supporting views include `FolderOverlayView.swift:59-148,586-692,995-1271,1302-1386`, `AppGridCellView.swift:194-271,286-365`, and `AppGridStatusView.swift:68-159`. DragUIVisuals was inspected at the interface/consumer level; its raster capture/rendering internals are deferred. Focus-related domain files remain inventory/declaration coverage; no blue-frame conclusion is drawn from them.

| Source path | Lines | Depth |
| --- | ---: | :---: |
| `Sources/AppGridUI/AppGridCellFocus.swift` | 34 | I |
| `Sources/AppGridUI/AppGridCellView.swift` | 378 | S |
| `Sources/AppGridUI/AppGridDataSource.swift` | 48 | S |
| `Sources/AppGridUI/AppGridFocusIdentity.swift` | 77 | I |
| `Sources/AppGridUI/AppGridFocusLayout.swift` | 179 | I |
| `Sources/AppGridUI/AppGridFocusModel.swift` | 56 | I |
| `Sources/AppGridUI/AppGridFocusNavigator.swift` | 110 | I |
| `Sources/AppGridUI/AppGridGeometry.swift` | 44 | D |
| `Sources/AppGridUI/AppGridPageView.swift` | 418 | D |
| `Sources/AppGridUI/AppGridRefreshController.swift` | 163 | S |
| `Sources/AppGridUI/AppGridSearchPresentationController.swift` | 134 | S |
| `Sources/AppGridUI/AppGridStatusView.swift` | 189 | S |
| `Sources/AppGridUI/AppGridUIPageContentProvider.swift` | 501 | D |
| `Sources/AppGridUI/AppGridUIState.swift` | 45 | S |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryCategory.swift` | 51 | S |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryPreferences.swift` | 57 | S |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift` | 62 | S |
| `Sources/AppGridUI/AppLibraryDomain/LaunchActivity.swift` | 160 | S |
| `Sources/AppGridUI/AppManagementPreferences.swift` | 137 | S |
| `Sources/AppGridUI/AppSearchMatcher.swift` | 33 | S |
| `Sources/AppGridUI/AppSearchQuery.swift` | 44 | S |
| `Sources/AppGridUI/AppSearchResultSet.swift` | 66 | S |
| `Sources/AppGridUI/DragSession/DragGeometry.swift` | 142 | D |
| `Sources/AppGridUI/DragSession/DragLogicalIndexMapper.swift` | 85 | D |
| `Sources/AppGridUI/DragSession/DragMutationEngine.swift` | 81 | D |
| `Sources/AppGridUI/DragSession/DragParameters.swift` | 66 | D |
| `Sources/AppGridUI/DragSession/DragSessionController.swift` | 287 | D |
| `Sources/AppGridUI/DragSession/DragSessionEvents.swift` | 78 | D |
| `Sources/AppGridUI/DragSession/DragTransaction.swift` | 70 | D |
| `Sources/AppGridUI/DragSession/DropIntent.swift` | 292 | D |
| `Sources/AppGridUI/DragSession/DropResolver.swift` | 81 | D |
| `Sources/AppGridUI/DragSession/EdgePagingScheduler.swift` | 153 | D |
| `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` | 724 | D |
| `Sources/AppGridUI/DragUI/DragUIVisuals.swift` | 491 | S |
| `Sources/AppGridUI/FolderDomain.swift` | 258 | S |
| `Sources/AppGridUI/FolderKeyboardLogic.swift` | 212 | S |
| `Sources/AppGridUI/FolderLabFixture.swift` | 71 | S |
| `Sources/AppGridUI/FolderLayoutPolicy.swift` | 133 | D |
| `Sources/AppGridUI/FolderMotion.swift` | 126 | S |
| `Sources/AppGridUI/FolderOpenState.swift` | 122 | D |
| `Sources/AppGridUI/FolderOverlayView.swift` | 1407 | S |
| `Sources/AppGridUI/GridItemAppearance.swift` | 101 | D |
| `Sources/AppGridUI/ItemBindingToken.swift` | 54 | D |
| `Sources/AppGridUI/LayoutDomain/LayoutGeneration.swift` | 20 | D |
| `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift` | 319 | D |
| `Sources/AppGridUI/LayoutDomain/PersistentAppReference.swift` | 59 | D |
| `Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift` | 126 | D |
| `Sources/AppGridUI/LayoutDomain/PresentationAnchor.swift` | 40 | D |
| `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift` | 154 | D |
| `Sources/AppGridUI/LayoutDomain/WorkspaceAppReferenceResolver.swift` | 71 | D |
| `Sources/AppGridUI/LayoutDomain/WorkspaceInvariants.swift` | 141 | D |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift` | 143 | D |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` | 464 | D |
| `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` | 309 | D |
| `Sources/AppGridUI/LayoutStore/LayoutStoreIO.swift` | 118 | D |
| `Sources/AppGridUI/MainGridCapacity.swift` | 101 | D |
| `Sources/AppGridUI/MainGridLayoutMetrics.swift` | 39 | D |
| `Sources/AppGridUI/MainGridReadability.swift` | 50 | D |
| `Sources/PagingCore/GestureSession.swift` | 142 | D |
| `Sources/PagingCore/PageTargetPolicy.swift` | 93 | D |
| `Sources/PagingCore/PagingCore.swift` | 754 | D |
| `Sources/PagingCore/PagingParameters.swift` | 191 | D |
| `Sources/PagingCore/PagingState.swift` | 52 | D |
| `Sources/PagingCore/TransitionContext.swift` | 81 | D |
| `Sources/PagingUI/BufferedJSONLWriter.swift` | 117 | S |
| `Sources/PagingUI/DiagnosticMonotonicClock.swift` | 45 | S |
| `Sources/PagingUI/FolderPagingController.swift` | 311 | D |
| `Sources/PagingUI/FrameCallbackProfileRecorder.swift` | 377 | S |
| `Sources/PagingUI/FrameProfileRecorder.swift` | 334 | S |
| `Sources/PagingUI/KeyboardPageTurner.swift` | 79 | S |
| `Sources/PagingUI/NeutralPageRenderer.swift` | 148 | S |
| `Sources/PagingUI/PageHostView.swift` | 204 | D |
| `Sources/PagingUI/PagingFrameDriver.swift` | 175 | D |
| `Sources/PagingUI/PagingPageContent.swift` | 142 | D |
| `Sources/PagingUI/PagingSurface.swift` | 1031 | D |
| `Sources/PagingUI/RunLoopProfileRecorder.swift` | 251 | S |
| `Sources/PagingUI/ScrollInputMapper.swift` | 109 | D |

Remaining deep-review gaps: focus/navigation implementations; complete folder overlay/editor/move-out lifecycle; full preview rendering internals; untraced refresh/search reentrancy; multi-instance IO arbitration under real simultaneous processes. Supporting domain-library inspection does not cover Main-owned Library cold-entry views/services. Scanner/icon/localization/telemetry implementations and executable composition remain with their assigned owners. The only outside-domain implementation body read to substantiate a finding was the CatalogPlanner anchor seam at `AppCatalogCore.swift:423-475`; no catalog-wide audit is claimed.
