# Architecture optimization — independent source review r1

Date: 2026-10-20. **Verdict: CHANGES_REQUESTED — one P2 reuse/reset finding remains in the stable r2 packet.** The other reviewed changes receive the bounded source assessment below. This is not a build, runtime, native accessibility, performance or physical acceptance verdict.

## Inputs and review identity

Reviewed all 17 changed source/test files in `.build/verification/20261020/architecture-review/review-inputs-r2.json` (10 production files, seven test files). Packet SHA-256: `5d1991d82fe0dda91519a7443198b491a514f2591769b03e65de9abfb53c1f31`. Every current file matched its packet hash at inspection and immediately before report creation. The original 16-file r1 packet remained unchanged; r2 adds only LeadingLibraryPreviewTests. The r1 source-delta before/after entries were checked against baseline-inputs and review-inputs-r1. Pre-existing dirty work is not attributed to this wave by comparing with Git HEAD.

Authority/context: `Docs/ARCHITECTURE_MAINTAINABILITY_OPTIMIZATION_SPEC.md`, including the selected four UI/extraction changes and additional codec/activity correctness selections; stage summary; `human-priority-feedback.json`; `window-extraction.json`; worker result `Workflow/results/ARCHITECTURE_ACTIVITY_WRITER.md`. The worker result is a scope/evidence claim independently checked against source, not a substitute for review.

Methods: source/test-source reading, imports and focused consumer tracing, SHA-256 checks and in-memory inverse transformations. Only this Markdown was authored. No implementation edits, test execution, build/typecheck, UI operation, process signals, Git mutation, formal preference access or reverse-reference evidence access. AppLibraryGalleryView, AppLibraryProjectionController and existing AppDelegate composition/lifecycle consumers were read narrowly where necessary. No exhaustive repository audit is claimed.

## Finding

### R1. [P2] Reset does not remove transient blocking/failure presentation before the view is cached

**Exact evidence:** `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:310-335` now resets/detaches the outgoing view and caches that same instance. Reentry consumes it at `:160-175`, restoring bounds/layer/activity state without reapplying app-action blocking. `Sources/PagingPrototypeApp/AppLibraryView.swift:232-261` clears the snapshot/query/selection and stored category-save result, but does not reset `appActionsBlocked` or refresh the already-created category-save failure label. `:801-805` persists blocking to the view/gallery and disables Back; `:789-798` also uses it when enabling detail controls. The composition root sends blocking updates only to the current `owner.view` (`Sources/PagingPrototypeApp/AppDelegate.swift:3354-3365`), while lifecycle hiding closes the Library independently of the ordinary Back readiness gate (`:3814-3819,3839-3845`).

**Trigger / impact:** Open Library, start work that calls `setAppActionsBlocked(true)`, then lifecycle-hide it before that work settles. The cached shell retains the flag; completion while `owner.view == nil` misses the shell. When readiness permits a later entry, the same view can still have blocked gallery/detail actions and a disabled Back button. Discarding the view previously discarded that state; caching makes the incomplete reset observable across sessions.

The same reset boundary also leaves stale failure presentation: `reset` sets `categorySaveResult = nil` at `AppLibraryView.swift:235` but does not invoke `renderCategorySaveStatus` (`:782-786`). A failed category-save label already built at `:705-707` remains in the reused details hierarchy; reopening details uses `:626-631,737-765`, which does not clear that label. Reentry's `setActivitySectionsEnabled` returns early if unchanged (`:551-555`), so incidental relabeling cannot be the reset mechanism. A prior session's save error can therefore reappear in the next one.

**Cause / confidence:** Session-scoped interaction/presentation state outlives the old session through the new shell cache. High-confidence conditional source paths; neither sequence was executed by this reviewer. Existing preparation tests cover snapshot/query/action-generation cleanup but not these retained states. Main's reported focused passing groups do not establish these missing scenarios.

**Minimal bounded correction:** Explicitly restore per-session blocking, including gallery and Back, and clear/render category-save failure presentation during reset. Alternatively, supply any deliberately persistent blocking policy's current authoritative value before mounting. Preserve the private snapshot, existing generation fences, single-shell bound and native hierarchy. Add regressions for blocked -> lifecycle hide -> completion while closed -> reentry, and failed category save -> close -> reentry -> show details. Use unchanged activity/language values as well as changed ones so relabeling cannot mask a missing reset. No generic refactor is requested. Re-review the small correction under refreshed hashes before accepting the complete shell-reuse change.

## Bounded acceptance of the remaining changes

### Search outline, input and accessibility

`Sources/PagingPrototypeApp/SearchFieldFocusPolicy.swift:5-10` applies `.none` to the actual field and cell. Its two consumers are `AppSearchFieldView.swift:17-24` and `LibrarySearchField.swift:5-9`. The custom Library decoration/state/drawing logic is removed; ordinary NSSearchField policy is not modified globally. This matches the newly approved design, which explicitly supersedes the old blue-border styling.

The inspected paths retain native editor/selection/IME handling, standard Tab fallback, identifiers/labels and normal editing-ownership callbacks (`AppLibraryView.swift:86-99,176-191,442-462,823-834`). The remaining didUpdate observer synchronizes icon admission and filters foreign-window notifications (`:145-167`); it is not redundant focus decoration. Rewritten `Tests/PagingUITests/LibrarySearchFocusDrawingTests.swift:22-113` exercises policy scope, intrinsic/native rendering, native editor/marked text, sibling composition and ownership notifications in test source. No new source-level focus/input/AX defect was found in this bounded review; displayed no-blue-frame and real native accessibility checks remain separate.

### Shared horizontal layout and icon admission

`Sources/PagingPrototypeApp/LibraryHorizontalLayout.swift:14-28` centralizes the declared margin, compact threshold, sidebar/content width and detail-admission threshold. Actual view layout consumes it at `AppLibraryView.swift:330-378`; pre-layout icon intent and delayed icon completion consume it at `:893-928`. The declared `<420` compact and `>=600` detail semantics are preserved by the formulas, and the visible-window/ancestor/generation checks remain.

`Tests/PagingUITests/LibraryHorizontalLayoutTests.swift:6-33` covers gallery/result modes, details, widths around compact/detail boundaries and formula parity. No additional layout/admission defect was found. This is source/formula review; baseline JSON contains hashes rather than original Library file bodies, so whole-file byte-equivalence or actual rendered-frame parity is not claimed. Mounted visual regressions remain Main's responsibility.

### Deferred preparation, ownership, content freshness and reentry

`Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:230-257` bounds preparation to one detached shell and one token-guarded pending Task; readiness is rechecked after Task.yield. Preparation constructs/layouts native controls without invoking catalogProvider, captureGrid or opening a projection. Empty gallery/result state and window-visibility guards prevent icon admission (`AppLibraryView.swift:900-928`; narrow gallery consumers at `AppLibraryGalleryView.swift:77-104,128-137`). An unmounted AX-hidden shell has no window responder ownership.

Entry consumes the shell, applies current bounds/activity/accessibility/layer state and starts a new projection under a new session (`AppLibraryOwnerController.swift:147-182`). Relabeling covers live and prepared shells (`:532-539`); close revokes session/action generations, closes projection, relinquishes field editors around reset and detaches before retention (`:310-369`). Action resolution requires an active open non-preview session, current generation/catalog/URL/visibility membership (`:453-460`). Projection completion is generation-fenced (`AppLibraryProjectionController.swift:62-99`). Disable/teardown discard preparation (`AppLibraryOwnerController.swift:475-493,556-574`). The source supports bounded empty-shell preparation and stale-action rejection, **subject to R1 for complete reset/reuse**.

`LibraryPresentationPreparationTests.swift:54-164` supplies eight focused source scenarios for idle preparation, reuse, drafts/actions, opt-out, readiness, teardown and current language/bounds/catalog. The earlier cross-file private `view.snapshot` assertion was corrected in the stable packet to supported table/projection observations (`:97-99`), without widening the view's private snapshot. That initial compile-risk observation is resolved at source level.

### Mechanical window-input extraction and E4 projection

Independently verified `Sources/PagingPrototypeApp/LauncherWindowInput.swift:5-694` is the exact 690-line block with SHA-256 `d0f4b4ec17f40e272166ef7858a619aa911b5dd195ac6304f3da34525ab07e48`. Reinserting it before current AppDelegate line 4317 and reversing only the one root projection reference recreates the supplied original AppDelegate hash `6bf892473e89d29d5f20b213d2f358331890303f4eae9b636c43bc0820a1111f`. This independent reconstruction substantiates the move beyond the extraction JSON's self-report.

`LauncherWindowInput.swift:696-700` adds a computed internal read-only projection to the unchanged private E4 gate (`:12-17`); `AppDelegate.swift:704` is its sole root consumer. E4/B1 defaults, per-read getenv semantics, sinks and event-routing bytes in the moved block are preserved. The earlier focused-r1.log documents the private-gate compile failure before this correction; source inspection confirms the specific access cause was addressed, not that a new compiler run passed. This is mechanical cohesion/navigation improvement, not a coordinator decomposition or runtime optimization.

### Codec size and future-version contracts

`Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift:116-127` checks the final checksummed encoded Data against the existing cap before handing bytes to IO. `:94-97,133-154` classifies a higher integer schemaVersion through a private minimal header before requiring the v1 envelope. Version 1 still passes checksum/structure/count/domain validation; malformed/older data retains corrupt classification and byte limits still precede version handling. No schema migration or limit change is introduced.

Independently reversing exactly the header addition, decode preflight and final-byte guard reconstructs the original codec SHA-256 `5f1bbf77db68a0a19ab0652e8e79fa7e88ad952fb716b826fc22e21aa40abaad`. Thus existing accepted v1 payload construction/checksum code is unchanged. `Tests/AppGridUITests/LayoutStoreCodecTests.swift:367-389` adds count-valid oversized rejection, a near-cap complete-envelope round trip and shape-independent future protection with current/older/string-version negative cases. `LayoutStoreTerminalOutcomeTests.swift:246-282` adds accepted-journal preservation and future-slot A/B with/without a valid peer, no writes and unchanged bytes. No new source defect was found in this selected codec repair; actual tests are Main-owned evidence.

### Activity accepted-write lifetime and queued handoff

`Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift:197-218` strongly retains the coordinator through the accepted save receipt, state update and queued successor handoff. It clears activeWrite after the receipt, starts at most the latest pending successor, and suppresses callbacks once invalidated (`:237-241`). The finite accepted chain retains its owner until settlement; a store that never returns a receipt continues to retain the writer, which is the stated accepted-work lifetime rather than a silently added timeout/cancellation policy.

Independently removing the three-line lifetime comment and restoring only the old weak capture/guard reconstructs the baseline coordinator hash `ad30f9bc438c2b2631ed085f6a8a61cd09103f923873a4558db4923f0b58eb21`. Admission, privacy, coalescing, receipt/retry decisions, schema and callback policy outside that bounded lifetime correction are unchanged.

`Tests/PagingUITests/LaunchActivityCoordinatorTests.swift:9-49,162-245` installs a save-start notification after its continuation, queues Clear/OFF over an unstarted history snapshot, invalidates/drops the external owner, verifies two-document order and two-then-one pending bounds, rejects new collection/callbacks, then observes release after successful or failed final receipts. The clock-only lifetime probe does not retain the coordinator. Four wrappers cover Clear, OFF, combined Clear/OFF and failed OFF. No new source defect was found in the worker's two-file lifetime slice. This acceptance does not certify all activity/privacy/storage behavior.

### Historical preview assertion updated to the selected reuse contract

`Tests/PagingUITests/LeadingLibraryPreviewTests.swift:523-540` still denies nested entry during the restore callback and verifies closed owner state, nil owner.view, detached outgoing view and grid visibility restoration. Only the final post-close identity expectation now permits the same cleaned shell. Independently replacing line 540 with its former `XCTAssertFalse(owner.view === outgoing)` reconstructs the original test hash `dfc4066bcee6d54228711eec0030167e77ef532456106263b0542bcc8025888c`. The rest of that file, including surrounding lifecycle/editor checks, is unchanged. This is a justified contract update; it does not resolve R1's reset completeness.

## Verification and deferred gates

Main reports a focused run of 374 tests: new codec, four activity, eight preparation, ten focus and two horizontal-layout cases passed; the sole failure was the old different-instance preview expectation, now changed in r2. This is **Main-reported execution evidence**, not a reviewer-run result. This report does not assert that a subsequent run after that single test edit completed. Main owns serialized focused/full tests, Debug/Release/package checks and existing routing regressions on the final frozen implementation.

One bounded source finding remains, so do not convert this report to overall PASS until R1 is corrected and re-reviewed. No native/performance/physical claim follows from source or focused tests. Prior bc701 physical first-entry feedback remains FAIL_STILL_PRESENT; return flicker was not confirmed in that reply. New-candidate first/repeat entry, blue-outline and physical smoothness checks remain separate user/native gates.

Journal reset/initialization concurrency and Core gesture callback reentry remain explicit high-priority backlog requiring separate contracts. The production LayoutStoreActor and PagingCore files still match their supplied baselines. Other original audit recommendations are not implementation requirements for this six-change wave. No generic refactor is proposed to finish this review.

## Frozen reviewed file hashes

| File | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` | `0f7d9d5580ccf22c243820c429b3331d8d5d8fbec7aea581e65da98bd4fa5ffd` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `9f1abdd2366beeedfa3979ddc728d7f287aea7358035a4a4afb8a0a33f19e2a5` |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` | `4e6dae8404e84973e4e0bdb59a1416805608946a7e6eddc1c8276a7db4c9edcc` |
| `Sources/PagingPrototypeApp/AppLibraryView.swift` | `a52b8e333037468163be686b7e2ddc495d6323b0232847df3c4c0955f963960c` |
| `Sources/PagingPrototypeApp/AppSearchFieldView.swift` | `f531a7018d72e1b3b2eb0b72c1e94dfd769b930c269a3c551b16f4917ca07f9a` |
| `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift` | `f7e7bfa1414a97f65922e7a46eae53e37d71e076ad15c62712b322dd96bb2ccf` |
| `Sources/PagingPrototypeApp/LauncherWindowInput.swift` | `a9dab681974181b642410c6230d5923503a261332954fa20e7ee113193343e0c` |
| `Sources/PagingPrototypeApp/LibraryHorizontalLayout.swift` | `4e09f4802f7def8cd8ebf2a78a017ea16b97e1f8bcb79e83925ea875b312133f` |
| `Sources/PagingPrototypeApp/LibrarySearchField.swift` | `2d933c75a1d12499aac5831ec2fe0656029795c5501d3c1241597888e8abec97` |
| `Sources/PagingPrototypeApp/SearchFieldFocusPolicy.swift` | `80768b0e82a2ef509b421e4786b3e05f1b2d293f7f4a5ab7bc1f9ede5e4a8e6d` |
| `Tests/AppGridUITests/LayoutStoreCodecTests.swift` | `29bc4dfa16800715a55691b65226ec366e47bdfd412bfcf5b1e48b7f9c2780fb` |
| `Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift` | `d92d92b4acb1326bb63dd7e6b7154c099dab7bc0b6a7701ba3bbc180775d7ccc` |
| `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift` | `d77eaada3dd942d2e29c2aa1ab8336710be670d488145de0752385757e55be61` |
| `Tests/PagingUITests/LeadingLibraryPreviewTests.swift` | `feebc124ecfeaf4dac64323de7d28cd222bb1a46e6d679bc804ccb35cb2d96bd` |
| `Tests/PagingUITests/LibraryHorizontalLayoutTests.swift` | `9c619d3b3bf99ce64fd6f6a32ece2741d6fcaa336b241d8c000f317497085323` |
| `Tests/PagingUITests/LibraryPresentationPreparationTests.swift` | `3d10d2734d24c1f14ce4c68ea7f73ff64c98023d8c7ed947af947acae68a4ed5` |
| `Tests/PagingUITests/LibrarySearchFocusDrawingTests.swift` | `f2d42f5cb94db80e6a251c13de9a5e31ccc11754ba44933b4f5975428e2ab851` |
