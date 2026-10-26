# Independent bounded source review: Library idle pre-render

**Source verdict: FAIL — R5, one P2 finding remains.** No P0/P1 source issue identified. This is a source verdict, not native, performance, full-test, or delivery acceptance.

## Authority and review basis

Reviewed the actual 12-path stage patch against the supplied actual before-texts in `.build/verification/20261026/library-idle-prerender/baseline-files/`, checked against `source-baseline-r1.json`. Git HEAD was not used as a baseline; inherited dirty changes are outside this review. The project is an AppKit macOS application built with Swift Package Manager, with MainActor presentation owners and an existing asynchronous shared icon pipeline.

Read `Docs/LIBRARY_IDLE_PRERENDER_2026-10-26.md` and `Workflow/stage-summaries/2026-10-26-library-idle-prerender.md`. Reviewed all 12 patch paths, including the complete new helper and tests, and relevant unchanged view, navigation, icon-key, loader, cache, and pipeline code. Only this report was written. No source/test changes, tests, builds, native operations, profiling, reference checkout/evidence, or real application/profile data access was performed by this reviewer. All shell commands began with `rtk`. No agents were dispatched and no legacy workflow state was changed.

## F1 — [P2] Bound the underlying loader work after prefetch timeout/cancellation

**Location:** `Sources/PagingPrototypeApp/LibraryIdleDisplayWarmup.swift:68–86,117–172`; supporting unchanged code in `Sources/AppIconPipeline/IconPipeline.swift:43–75,283–293,387–403` and `Sources/AppIconPipeline/IconLoading.swift:31–36`.

**Trigger and effect:** A prefetch that has not completed within 200 ms is cancelled and the helper immediately proceeds to the next control. This serializes consumers, but does not serialize or bound abandoned underlying loads across timeout/retry cycles. With occupied pipeline permits or a loader that does not finish within the timeout, cancelled optional requests remain in the permit queue. When a permit becomes available, they still call the loader. A real first-entry icon request can therefore sit behind abandoned idle work, despite navigation itself never awaiting the warmer.

**Evidence and likely cause:** `requestIcon` schedules a 0.2-second timeout; `finishIcon` cancels the consumer handle and resumes the helper continuation. `IconPipeline.cancelConsumer` cancels the task and removes its in-flight entry, but `AsyncSemaphore.acquire` stores a nonthrowing continuation with no cancellation removal. `withPermit` unconditionally invokes its body after acquisition, and `performLoad` has no cancellation check before `loader.load` or image capping. The production `SystemIconLoader.load` wraps synchronous public NSWorkspace calls without a cancellation check. Thus cancelling a task waiting for a permit does not prevent that task from subsequently performing its now-unowned load. Removing the in-flight entry also means a subsequent request for the same key cannot merge into that abandoned load.

**Boundedness:** A single pass has at most 56 icon controls, but repeated input/revision/environment cancellation can start replacement passes while earlier pipeline tasks still retain permits or queued continuations. The owner's one preparation-task slot and the helper's one pending-consumer slot do not cover those tasks. This is a new use of an inherited pipeline limitation, not a claim that the pipeline itself was changed in this patch.

**Recommended solution:** Ensure a cancelled queued optional request cannot invoke the loader when it eventually acquires a permit, and prevent repeated timed-out prefetches from accumulating unowned work. Stopping further icon prefetch after a timeout is a useful local safeguard; cancellation-aware permit/loader admission or another explicitly bounded existing-pipeline seam is needed for queued requests. Keep real navigation independent of this cleanup. Main should choose the narrow repair and own its tests.

**Suggested deterministic verification:** Set the real pipeline's concurrency to one; hold a synthetic first load; queue a warm-up key; time out/cancel it; enqueue a live key; release the held load. Assert that the abandoned warm-up key never reaches the loader and that the live key proceeds without executing abandoned warm-up loads. Repeat owner cancellation/retry while the permit is occupied and check bounded outstanding work. The helper's injected `IdleWarmupRequests.active/peakActive` only counts consumers, so its passing assertions would not establish this property.

**Affected scope / regression risk:** Optional prefetch cancellation and shared icon-loader scheduling. Preserve normal same-key merging, successful cache reuse, suppressed/late callbacks, cancellation of one consumer without cancelling another, and shutdown behavior. No action, editor, AX, persisted-data, or physics change is recommended.

**Confidence:** High for the source-level cancellation/queue mechanism. The frequency, duration, and contribution to a physical hitch have not been measured; no CPU/GPU causal claim is made.

## Resolved source issues and revision changes

The source was **not continuously frozen for this review**. Main explicitly announced R2, R3, R4, then R5; each revision was rehashed and its changes inspected. This report targets R5 only.

- R1 to R2: the owner added `activitySectionsEnabled` to the display key and synchronized the detached shell's activity flag before layout; helper-test numeric constants were partially qualified. The activity flag changes the gallery height by 34 points in `AppLibraryView.layout`. The key and synchronized layout now cover that mode in source; the activity-disabled integrated candidate alone cannot verify production activity-enabled behavior.
- R2 to R3: the remaining invalid-rectangle constants were explicitly qualified as `CGFloat`; no product logic changed.
- R3 to R4: the owner now explicitly requests initial detached-root layout; the geometry helper validates raw `bounds.size.width/height` so CGRect normalization cannot admit negative sizes; safe-area subtraction is conditional on a supplied host search header. Owner tests add actual gallery/button geometry and native button-subview diagnostics without weakening the existing preview expectation.

- R4 to R5: the helper now permits a bounded decorative descendant tree for native button/caption roots (at most 16 descendants, depth at most four), while rejecting material views, scroll containers, text editors, editable/selectable fields and other interactive controls. The real laid-out Library-button regression and traversal-limit/interactive-child negative cases were added; the original material/editor negative case remains intact. This addresses R4's observed rejection of real framework-backed buttons in source; it does not resolve F1.

R4's conditional safe-area logic restores the prior standalone preview contract. The real application composition already supplies `layout(searchFrame:)`; no production search-header regression is inferred from the former standalone test failure. Initial detached layout is now requested before pool geometry or display readiness can be computed. These are inspected repairs; their runtime validation remains Main's responsibility.

## Review coverage and remaining risks

| Area | Source assessment and limits |
| --- | --- |
| Lifecycle and callback ownership | Owner and gallery generations are rechecked across suspensions. The warmer retires the pending UUID before cancellation callbacks and resumes each continuation once. Registration-time delivery, missing delivery, late timeout, old-generation callbacks, and task cancellation are handled independently. F1 concerns the underlying pipeline queue, not double-resuming the helper continuation. |
| Input and cold fallback | Scroll begins, including a zero-delta begin, revoke optional work. Entry synchronously takes an available shell or constructs the ordinary fallback; it never awaits prefetch. A retained completed pool remains inert until a fresh live projection matches complete entries and language. The existing terminal-input/readiness retry path remains. |
| Actions, focus, editor, host and AX | Prepared cards remain detached, blocked, and AX-hidden. The helper neither installs controls in a window nor changes their callbacks, target/action, key/handle, image, or editor. Live action bindings still come from the normal projection and owner validation. No new launcher-opening, app-launching, preference-writing, or inventory-logging path was found. |
| Content/environment acceptance | Content preparation keys include revision, management, committed Library preferences and language; pool consumption checks complete entries and language. Display keys additionally cover frame, scale, appearance name, transparency, contrast and activity mode. The current key is rechecked before readiness publication. |
| Work/allocation bounds | The gallery selects at most eight first-viewport cards; at most 64 supplied controls are visited, with bounded validation of each decorative subtree. The explicit scratch allocation is at most 256 by 256 RGBA pixels (256 KiB) and is released per control. Native calls are MainActor and separated by cancellable suspensions. This bounds the application's explicit allocation/call count, not AppKit internals, synchronous draw duration, or the abandoned loader queue in F1. |
| Geometry and return/header behavior | Prepared card/button frames are established before display. R4 restores the standalone safe-area distinction. Grid search remains outside the translated roots; return/reset/header ownership code is otherwise inherited. The new layer helper only creates missing backings, disables implicit actions, and counts actual missing roots. Most grid chrome already has backing; no broad first-return benefit is established by that count. |

**Appearance inheritance caveat:** Pool cards have no superview until consumption. Assigning `prepared.appearance = host.effectiveAppearance` on the detached shell does not itself propagate that appearance to those separately detached cards. The current app normally inherits one application appearance, but a differing host/window appearance can make the recorded appearance key more specific than the actual card drawing environment. If differing host appearance is supported, Main should explicitly scope/apply the captured drawing appearance to the detached controls, restore inheritance at live mounting, and cover the differing-appearance case. This is a conditional coverage risk, not an observed current production failure.

**Native bitmap API caveat:** Apple describes `cacheDisplay(in:to:)` as drawing a view and descendants into a bitmap, and recommends obtaining a compatible representation from `bitmapImageRepForCachingDisplay(in:)`. This helper deliberately supplies a manually allocated, capped `.deviceRGB` representation and adjusts its logical size. Compatibility, scaling, and drawing of actual detached NSButton/NSTextField implementations therefore need Main-owned native validation. The numeric cap tests override `cacheDisplay`, so those assertions do not exercise the actual AppKit implementation. A method returning, or an `idleControlDisplay` count, does not prove useful pixels, retained compositor state, decoded-cache lifetime, blur realization, or physical smoothness. See [Apple's cacheDisplay documentation](https://developer.apple.com/documentation/appkit/nsview/cachedisplay(in:to:)). Root materials/panels and material/editor/scroll descendants are excluded, editable/selectable fields are rejected, and scratch pixels are not retained. R5 permits only bounded decorative descendants beneath an eligible native root.

## Test evidence boundary

The reviewer did not run or wait for tests. Main reported R1 and R2 as compile-only failures with zero executed tests; neither is a test pass. The supplied R3 log was read after it completed: `focused-r3.log:506–508` records **203 tests, 5 failures, 0 unexpected, 68.415 seconds**. The five failed assertions cover the standalone preview height, two invalid-geometry allocation assertions, and two owner tests reporting display readiness with zero icon requests. R4 contained targeted source/test repairs for those failures. Its completed `integration-r4.log:81–83` records **24 tests, 2 failures, 9.373 seconds**. The remaining owner checks showed zero requests and one framework child per native button (`integration-r4.log:67,76`); the blanket leaf-only check was therefore a concrete integration failure, not a root-performance diagnosis. R5 changes that admission check and adds real-button coverage. Main's broader R5 focused run was pending at this review's final hash checkpoint. No R5 pass, full-suite pass, Debug/Release/package success, native pass, or performance acceptance is asserted here.

Main should retain this source FAIL until F1 is addressed or explicitly resolved with bounded-work evidence, then request review of the new frozen revision. Native no-flash, focus/AX behavior, actual bitmap API compatibility, profile preservation, and a human first-entry/first-return comparison remain separate gates.

## Hash and inspected-input receipt

Final R5 comparison checkpoint: `2026-10-26T03:02:48.370180+00:00`. All **615/615** frozen input hashes match; the manifest-to-baseline changed-path set is exactly the supplied **12 paths**. The **nine existing changed files** match their actual before-text hashes; the **three new files** have no baseline file. This does not claim that every one of the 612 baseline entries has a separate before-text copy. No unannounced source mismatch was observed at the recorded checkpoints; the announced R1-to-R5 mutations are explicitly recorded above.

Earlier successful manifest checkpoints were R1 at `2026-10-26T02:44:22Z`, R2 at `02:47:18Z`, R3 at `02:49:15Z` and `02:54:02Z`, R4 at `02:57:17Z` and `02:59:25Z`, and R5 at `03:01:29Z`. Checkpoints establish byte matches when checked, not continuous filesystem immutability between checks.

| Manifest | SHA-256 |
| --- | --- |
| [source-baseline-r1.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-baseline-r1.json) | `f4fd868161bfa496d5a15c9c1ed19ea1d83aa194e8995d42ad90742ea3c860e7` |
| [source-inputs-r1.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r1.json) | `c42537eb2120a38b4d48ac22f3e7132d155c07be0624d80a5ad1be8231a39b3e` |
| [source-inputs-r2.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r2.json) | `75e3c2ec76a31471f6fbdff7e442ae3a845016a68fbae16dddb50ce53c583479` |
| [source-inputs-r3.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r3.json) | `7c9c1650f41a5c61d9936cc1d5d64f0366558d8c8744d804b86a89c47d7c638e` |
| [source-inputs-r4.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r4.json) | `36830c146afc3e4ce8753d6b513d6f1648b575155d43684b33cdd54ab00fa3a9` |
| [source-inputs-r5.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r5.json) | `58b3f2b9797b32283ca90127d5f82aa0fba7ecf3a7bf0164ea1389043d29a453` |
| [source-delta-r5.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-delta-r5.json) | `ebc107e4fb5ec8ac40c156be294767a414b812e09eb8a69fff62d2920271b14b` |

Each after-hash below was checked against the file actually inspected in R5; before-hashes were checked against the supplied actual before-texts.

| Reviewed patch path | Before SHA-256 | Inspected R5 SHA-256 |
| --- | --- | --- |
| [Sources/PagingPrototypeApp/AppDelegate.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppDelegate.swift) | `64566e3568ec6198bb139c2903fb3d527dab183a5936e1cd250eebe9d936379e` | `33d2423de73e8eb5d5d16e41715c1604bc168e15c807196e79e94a44de9c6998` |
| [Sources/PagingPrototypeApp/AppLibraryGalleryView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryGalleryView.swift) | `ad1ead232ea8f7740000012b49750a199b16853fad450aa698630e01dc6ba98c` | `9fbfe3bc7bfcfd1fe3df8d13ca1c3733961fd46ab9c0ede884ceb9b523b0ffdf` |
| [Sources/PagingPrototypeApp/AppLibraryOwnerController.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryOwnerController.swift) | `fe1608d37429cc608c72d6225723e0451d77f6b8c645f2b1627764563bff2eb0` | `1d00ed7229d34247466cdd7ae692b53724242a7167f1d97f2337687a5537eea9` |
| [Sources/PagingPrototypeApp/LeadingLibraryNavigator.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LeadingLibraryNavigator.swift) | `90c4b8dce67598b640e894bb3c1f4d4684573ffe51b0b1c3c5efb58bd409e023` | `5bf626b972040b8f92ef1a3becdd7eea649b94189736adf321826b0a722407ca` |
| [Sources/PagingPrototypeApp/LeadingLibraryPresentation.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LeadingLibraryPresentation.swift) | `881e03a3be6acc9a5b7a47f3639dfbfc140afaac5c01b6a48698f1ce88b722c7` | `fe509c75cb4216894b750c57022c42ba84658aa95eb75d84fd24a4918eb4a6fa` |
| [Sources/PagingPrototypeApp/LibraryEntryProfile.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LibraryEntryProfile.swift) | `5b11b5d8d7a517dd7caaf7ea4150456b5286f92b5ab53cfda004bc02dbb50821` | `ffca98e62222676ba50536b5363d5da44b048e7965981510a1de16a6d7b81577` |
| [Sources/PagingPrototypeApp/LibraryIdleDisplayWarmup.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LibraryIdleDisplayWarmup.swift) | New file | `0c21c34232b7f268bc37a5cfa31d7f0add89b9510b7956a9524c76490adc1e97` |
| [Tests/PagingUITests/LeadingLibraryPresentationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LeadingLibraryPresentationTests.swift) | `d105075cf530f073e2d21893209973d43e66018125a0c315446c77db21cbd21c` | `d86997c0dca76c477a40e072d42e73c2ed6a3d840bd79816d8bfb27c4c07bf0a` |
| [Tests/PagingUITests/LibraryEntryProfileTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryEntryProfileTests.swift) | `13c6477d1dfc885f26e345e4bd93c1d2ad032260d1329f4ff69145cee0f47915` | `a5d081b726f50402e0f8a742aa8c34a4501630afbbc18d08331b7c2377c8605e` |
| [Tests/PagingUITests/LibraryGalleryPreparationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryGalleryPreparationTests.swift) | `0b632f03dbe9fc83e0388deb2b250b28fb95d11b75327a0e6b34caaf6d81f066` | `a28653fc6e75b378c545331cf157dd1a1b470ce4451e3f61c97a307d7d3bd358` |
| [Tests/PagingUITests/LibraryIdleDisplayWarmupTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryIdleDisplayWarmupTests.swift) | New file | `7007913682de60c7a540977a5e16d502b2043365ddc0ae0c4ed71782e6e46685` |
| [Tests/PagingUITests/LibraryOwnerDisplayPreparationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryOwnerDisplayPreparationTests.swift) | New file | `a9ad5397e95008d116afa1ace1ae55440dfbf26fbcbb7db9fd6c5ed219179f3c` |

Supporting source hashes (the inspected relevant sections are outside the stage delta):

| Supporting file | SHA-256 |
| --- | --- |
| [Sources/PagingPrototypeApp/AppLibraryView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryView.swift) | `e90563eb0d4e1a4867d8e17c2d085efe24ea4da9c22deacc6b4623000d10ef6f` |
| [Sources/AppIconPipeline/IconPipeline.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppIconPipeline/IconPipeline.swift) | `b119be2397fb120d1472414d1ab0062c85813884f6994232d471b033d66d2c85` |
| [Sources/AppIconPipeline/IconLoading.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppIconPipeline/IconLoading.swift) | `010e17274db20301d9f0ccf92df4a47175f88845c5ed65c406101e70d25df299` |
| [Sources/AppIconPipeline/IconKey.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppIconPipeline/IconKey.swift) | `2880481030eca674bb27f7d9a86097bc1b2e53618c749df9d5947242dc911687` |
| [Sources/AppIconPipeline/IconCache.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppIconPipeline/IconCache.swift) | `30a198f5fe2f066ea6e09528f7723af32acab8179868f548a1333df42151b92c` |
