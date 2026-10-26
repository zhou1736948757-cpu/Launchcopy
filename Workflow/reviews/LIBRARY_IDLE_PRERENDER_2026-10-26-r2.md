# Independent bounded source follow-up: Library idle pre-render

**Source verdict: PASS — frozen R6.** F1 is closed at the source-review layer. No remaining actionable source finding was identified in the reviewed scope. This does not certify an unfiltered test run, build/package delivery, native behavior, compositor readiness, or physical first-entry/first-return performance.

The earlier [R1 report](LIBRARY_IDLE_PRERENDER_2026-10-26-r1.md) remains unchanged with its R5 **FAIL** and evidence history. This follow-up records the subsequent repair; it does not rewrite that result.

## Scope and evidence

Reviewed R6's **616 inputs / 15 stage deltas** against `source-inputs-r6.json`, `source-delta-r6.json`, the original `source-baseline-r1.json`, and the actual supplied before-texts. Git HEAD was not used. The newly included original before-texts for `IconPipeline.swift` and `IconPipelineCancelTests.swift` match their entries in the original baseline.

The expanded three-path scope is the shared pipeline, its existing cancellation tests, and the new `IconPipelinePermitCancellationTests.swift`. The other R5-to-R6 changes are the gallery, owner, and owner display-preparation tests for appearance handling. Those six paths were inspected directly; unchanged earlier stage paths were carried forward only after hash comparison. The updated specification and stage summary authorize this narrow existing-pipeline correction and detached-card appearance repair.

This reviewer wrote only this English report. No source/test changes, test execution, builds, native operations, profiles, reference repository/evidence, production data, agent dispatch, or legacy workflow updates were performed. All shell commands started with `rtk`.

## F1 closure: cancellation-aware permit ownership

Source: `Sources/AppIconPipeline/IconPipeline.swift:43–86,292–344,364–419,422–460`.

| Boundary | Inspected R6 behavior |
| --- | --- |
| Cancellation before registration | `acquire()` checks task cancellation before taking a free permit and again inside continuation registration. An already-cancelled request returns false without joining the queue. |
| Cancellation while queued | Each waiter has a UUID. The cancellation handler schedules actor-isolated removal; removal resumes only that waiter's continuation with false. No cancelled-ID tombstone collection or retained cancelled queue entry is introduced. Reclamation is asynchronous to the actor, not claimed to occur synchronously inside `handle.cancel()`. |
| Grant racing cancellation | Grant and removal are serialized by the semaphore actor. A removed waiter owns no permit. A granted waiter installs one `defer` release, checks cancellation before calling the body, and releases exactly once on cancellation, success, or a thrown loader error. A late removal cannot resume an already-granted continuation again. |
| Shared consumer survives | Per-consumer cancellation retains the existing task while another consumer remains. The permit waiter is cancelled only when the underlying load task is cancelled; cancelling an idle consumer cannot remove merged live demand. |
| Native load already admitted | A synchronous/non-cooperative loader cannot be forcibly interrupted by this correction. After it returns, cancellation is rechecked before image capping. A cancelled result passes through the existing terminal/loadID guard as a cancellation result rather than being capped or cached. Cancellation after loader admission is a different boundary from cancelling a queued waiter. |
| Replacement, source invalidation and shutdown | The existing `isShutdown`, in-flight `loadID`, consumer-state and queued-delivery guards remain. A late old result cannot remove a new same-key load or publish into its consumers/cache. Shutdown/source invalidation retain their existing ownership revocation. |

The former mechanism that allowed an abandoned queued request to invoke its loader after eventually obtaining a permit is removed. The four real-pipeline regression cases inspect the actual one-permit queue rather than an injected consumer count. The helper still has an independent timeout and UUID-protected completion; its timeout no longer depends on leaving abandoned waiters in the shared loader queue.

No warm-up `purgeAll`, cache reset, or `cancelAll` call was introduced. Cache identity, same-key merging, cache limits, and public pipeline APIs remain unchanged. `waitingLoadCount` is an internal numeric observation seam, with no app identity or inventory output.

## Expanded tests and historical assertion changes

`Tests/AppIconPipelineTests/IconPipelinePermitCancellationTests.swift` contains four bounded synthetic controls using the real pipeline with concurrency one and an explicitly held loader:

1. Cancel a queued optional key, observe queue reclamation, enqueue a live key, then release the blocker; only blocker/live keys reach the loader and the cancelled callback stays silent.
2. Repeat queued cancellation 12 times while native work remains held; each cancelled waiter is reclaimed before the blocker returns, then live demand proceeds.
3. Merge a live consumer into the queued idle key and cancel only idle demand; one shared load and the live generation survive.
4. Shut down with four queued keys and a non-cooperative held loader; queued waiters disappear before decoder release and callbacks remain suppressed.

The changes in `IconPipelineCancelTests.swift:24–35,83–92` are appropriate for the new admission semantics. Immediate cancellation may now prevent the old loader from starting at all. Each test records the old load count (at most one) and still requires **exactly one additional fresh load**, zero cancelled callbacks, correct cancellation accounting, and the existing merge/reload assertions. They no longer require useless cancelled work to run. The controlled started-load replacement/source-identity checks and their terminal-result observation remain in scope of the focused run; the loadID guard was not weakened.

These controls establish the specific queued-cancellation mechanism. They do not promise zero latency for native work already admitted, a hardware frame-time bound, or exhaustive scheduler-race execution.

## Appearance caveat closure

Source: `AppLibraryOwnerController.swift:364–386`, `AppLibraryGalleryView.swift:134–156,201–216`; regression: `LibraryOwnerDisplayPreparationTests.swift:151–165`.

The owner passes the captured destination appearance through the optional gallery display call. Each selected detached first-viewport card receives it before geometry and drawing. Its existing caption/panel/button descendants can therefore inherit the intended appearance despite the card having no gallery parent. At live binding, `card.appearance` is cleared before callbacks are rebound, AX is exposed, controls are enabled, or the card is attached. The shell's existing live-entry clearing also remains. A cancelled or partially prepared pool stays detached and inert; live binding still clears any explicit appearance.

The owner regression asserts explicit destination appearance on nonempty detached cards, enters through normal projection, and asserts nil explicit appearance on nonempty live cards. It uses an explicit Aqua host; it does not by itself test every contrasting app/window appearance combination or establish a visual native-theme acceptance matrix. The source-level inheritance gap from R1 is addressed.

## Verification actually inspected

Main owns all test execution. The retained pre-repair `queued-cancel-before-r1.log:201–209` records **1 test / 2 failures**: a cancelled waiter remained queued and its abandoned key reached the loader. It is retained as RED evidence, not described as a pass.

The completed `focused-r6.log:535–537` records **210 tests / 0 failures / 20.131 test seconds**. The four new real-pipeline cases pass at lines 94–104; the owner appearance control passes at lines 459–460. Main reported 78.987 seconds wall time and unchanged exact R6 source. The reviewer read the completed log and independently checked the current input hashes, but did not execute the run. The focused log SHA-256 is `06df8c377f9103dc26ac7c350c8cef75cb461be33001ffbd0515d1b1f1448a50`.

The unfiltered suite was announced as Main's next serial run; this source verdict does not wait for it and does not report its result. Debug, actual Release, packaging, native no-flash/header/focus/AX checks, profile preservation, and human first-entry/first-return comparison remain Main-owned delivery gates. Earlier compile-only failures and R3/R4 failures retain their historical status in R1 and the stage summary.

## Remaining risks and source boundaries

- An already-running synchronous native icon call still holds its permit until it returns. The repair bounds admitted concurrency and reclaims cancelled queued work; it does not interrupt the OS call or establish its duration.
- The manually allocated, capped bitmap path and bounded native-control subtree admission still require appropriate native validation. The focused actual-button tests cover the integration counterexample; they do not certify compositor/material realization or physical smoothness.
- The first-input fallback, generation checks, inert detached pool, complete-entry/language acceptance, environment/activity key, callback isolation, material/editor exclusions, and header/return ownership remain as reviewed in R1. No new action, editor, host, AX, persistence, physics, threshold, or timer-tolerance change was found in R6.
- Most grid chrome was already layer-backed. Missing-layer counters are not evidence of a CPU/GPU cause or a first-return performance fix.

## Hash receipt and freeze limits

R6 checks at `2026-10-26T03:13:25Z`, `2026-10-26T04:12:07Z`, and final publication checkpoint `2026-10-26T04:14:14.922026+00:00` matched all **616/616** recorded inputs. The original-baseline changed-path set is exactly **15 paths**: **11 existing changed files** with matching actual before-texts and **4 new files** absent from the baseline. The R5-to-R6 manifest change was announced and inspected; no additional manifest-covered source change was detected during this follow-up. These checks establish matches at observation points, not uninterrupted filesystem immutability.

The R1 report remained byte-for-byte unchanged at SHA-256 `7f470af58a8d753969c29ca1539b4797f56456f55bd6b40f423964948a0d201c`.

| Manifest | SHA-256 |
| --- | --- |
| [source-baseline-r1.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-baseline-r1.json) | `f4fd868161bfa496d5a15c9c1ed19ea1d83aa194e8995d42ad90742ea3c860e7` |
| [source-inputs-r5.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r5.json) | `58b3f2b9797b32283ca90127d5f82aa0fba7ecf3a7bf0164ea1389043d29a453` |
| [source-inputs-r6.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-inputs-r6.json) | `3eb3b438ba2bb35034d44df0f6faf534a21c55d834fc27dbf311aedbc0c18793` |
| [source-delta-r6.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261026/library-idle-prerender/source-delta-r6.json) | `1d155104e83d07cffff6b6fd3540ff294e334a7b5a827290e64fd3bbeff8cb89` |

| Stage patch path | Verified actual before SHA-256 | Inspected R6 SHA-256 |
| --- | --- | --- |
| [Sources/AppIconPipeline/IconPipeline.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppIconPipeline/IconPipeline.swift) | `b119be2397fb120d1472414d1ab0062c85813884f6994232d471b033d66d2c85` | `85ccf7e257c9f130c2c6b0d521ba7497c4715cead7241b3da837c86cafa7b73a` |
| [Sources/PagingPrototypeApp/AppDelegate.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppDelegate.swift) | `64566e3568ec6198bb139c2903fb3d527dab183a5936e1cd250eebe9d936379e` | `33d2423de73e8eb5d5d16e41715c1604bc168e15c807196e79e94a44de9c6998` |
| [Sources/PagingPrototypeApp/AppLibraryGalleryView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryGalleryView.swift) | `ad1ead232ea8f7740000012b49750a199b16853fad450aa698630e01dc6ba98c` | `ab8d5ce3f3412c2017dc7bd7fd20b47ff55572373133bd753887e54400c18524` |
| [Sources/PagingPrototypeApp/AppLibraryOwnerController.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryOwnerController.swift) | `fe1608d37429cc608c72d6225723e0451d77f6b8c645f2b1627764563bff2eb0` | `c97323f0acb223a14a405ac8dfd3aec6e30327170f0c8c22ed5043398722838f` |
| [Sources/PagingPrototypeApp/LeadingLibraryNavigator.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LeadingLibraryNavigator.swift) | `90c4b8dce67598b640e894bb3c1f4d4684573ffe51b0b1c3c5efb58bd409e023` | `5bf626b972040b8f92ef1a3becdd7eea649b94189736adf321826b0a722407ca` |
| [Sources/PagingPrototypeApp/LeadingLibraryPresentation.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LeadingLibraryPresentation.swift) | `881e03a3be6acc9a5b7a47f3639dfbfc140afaac5c01b6a48698f1ce88b722c7` | `fe509c75cb4216894b750c57022c42ba84658aa95eb75d84fd24a4918eb4a6fa` |
| [Sources/PagingPrototypeApp/LibraryEntryProfile.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LibraryEntryProfile.swift) | `5b11b5d8d7a517dd7caaf7ea4150456b5286f92b5ab53cfda004bc02dbb50821` | `ffca98e62222676ba50536b5363d5da44b048e7965981510a1de16a6d7b81577` |
| [Sources/PagingPrototypeApp/LibraryIdleDisplayWarmup.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LibraryIdleDisplayWarmup.swift) | New file | `0c21c34232b7f268bc37a5cfa31d7f0add89b9510b7956a9524c76490adc1e97` |
| [Tests/AppIconPipelineTests/IconPipelineCancelTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/AppIconPipelineTests/IconPipelineCancelTests.swift) | `e99892c4eb7f192e3d3ea03438731c3a1c18301e9902281b9543e87aada5669b` | `65173a3fa6187972c1174df3b416ab90ce4445a607cafe709091099c2200fef4` |
| [Tests/AppIconPipelineTests/IconPipelinePermitCancellationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/AppIconPipelineTests/IconPipelinePermitCancellationTests.swift) | New file | `ef282db3ad512269fd2b3990fa87da6f5514ce7afeee17c073356bc5acbac61f` |
| [Tests/PagingUITests/LeadingLibraryPresentationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LeadingLibraryPresentationTests.swift) | `d105075cf530f073e2d21893209973d43e66018125a0c315446c77db21cbd21c` | `d86997c0dca76c477a40e072d42e73c2ed6a3d840bd79816d8bfb27c4c07bf0a` |
| [Tests/PagingUITests/LibraryEntryProfileTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryEntryProfileTests.swift) | `13c6477d1dfc885f26e345e4bd93c1d2ad032260d1329f4ff69145cee0f47915` | `a5d081b726f50402e0f8a742aa8c34a4501630afbbc18d08331b7c2377c8605e` |
| [Tests/PagingUITests/LibraryGalleryPreparationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryGalleryPreparationTests.swift) | `0b632f03dbe9fc83e0388deb2b250b28fb95d11b75327a0e6b34caaf6d81f066` | `a28653fc6e75b378c545331cf157dd1a1b470ce4451e3f61c97a307d7d3bd358` |
| [Tests/PagingUITests/LibraryIdleDisplayWarmupTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryIdleDisplayWarmupTests.swift) | New file | `7007913682de60c7a540977a5e16d502b2043365ddc0ae0c4ed71782e6e46685` |
| [Tests/PagingUITests/LibraryOwnerDisplayPreparationTests.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/LibraryOwnerDisplayPreparationTests.swift) | New file | `3c039d31bd32b9c1062babbfdc00ba89a05462da2142139b0d002e868d7e58fe` |
