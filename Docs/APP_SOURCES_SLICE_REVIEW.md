# Application Sources Slice — Independent Source Review

Date: 2026-10-13 (JST).
Verdict: **FAIL — scoped source review**, with three outstanding findings.
This is not a GUI, physical input, global performance, Release, packaging, or overall migration PASS.

## Authority, scope, and evidence

Reviewed the approved `Docs/APP_SOURCES_AND_WATCHING_SPEC.md`, local `AGENTS.md`, RTK instructions, and the installed `write-swift` skill at `/Users/mac/skills/skills/skills/write-swift/SKILL.md`.
The stale catalog skill path was resolved by filename inventory. Applied its suspension/reentrancy, cancellation, synchronization, and resource-lifetime guidance within the existing Swift package architecture; no toolchain migration or code changes.

The product uses MainActor AppKit settings/composition, an actor admission service, a utility-queue scanner/repository, a MainActor refresh/presentation controller, and a utility FSEvents adapter.
Reviewed actual consumers and supporting code, not only foundation models.
Only this report was written. All implementation and tests were read-only.
No Swift command, compilation, test execution, GUI operation, commit, installation, process modification, or reference/Buho/LaunchBetter source/asset access was performed.
Project shell reads were routed through RTK.

Main reported focused-r3 **88 tests / 0 failures**, completed 20:53:27.807 JST, including a 0.516-second native recursive temporary-root smoke.
Main subsequently reported full-r1 **2016 tests / 1 failure**, completed 20:54:34 JST: the legacy three-tab assertion in AppearancePreferencesTests.
Main repaired that assertion to four tabs with the actual Sources view assertion and added a new query regression after those results.
Main then reported full-r2 **2017 tests / 0 failures**, completed 20:58:02.086 JST (30.557 seconds), comprising 89 Sources cases plus baseline 1928, after the query/tab repairs. Debug/Release packaging for unique candidate app-sources-rc-20261013-r1 was underway, not complete evidence at this review cutoff.
These are Main-supplied execution results, not executions independently observed here. The new query regression is included in the supplied full-r2 result.
The earlier 1928/0 baseline is not the current feature acceptance gate.
The r1 integration test import repair and r2 Foundation URL fixture correction do not establish production failures; they are not findings below.

Sending an early finding through `send_message_to_thread` was rejected because Main is this session's native ancestor. No native collaboration messaging tool is exposed here.
Findings were therefore surfaced in progress commentary, this authorized report, and the final return. No claim is made that a tool message was delivered.

## Outstanding findings

### F1 — P1: A replaced fixed profile root bypasses the runtime boundary

**Locations:** `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:114-115`; `Sources/PagingPrototypeApp/AppSourcesCoordinator.swift:111-124`.
Supporting consumers: `Sources/PagingPrototypeApp/AppDelegate.swift:1779-1794`; `Sources/MacAppCatalog/CatalogScanner.swift:98-105`; `Sources/PagingPrototypeApp/AppSourceWatcher.swift:291-294`.

**Finding / evidence:** Both scan and watch assembly initialize their accepted inputs with all fixed roots and validate only custom inputs. In a configured isolated profile the synthetic Applications directory is a fixed root. Profile resolution protects it at startup, but subsequent scans bypass admission for that root. The scanner independently resolves every root's symlinks just before enumeration. A directory changed into an external symlink after successful startup, or while temporarily absent before recovery, is therefore scanned outside the profile. The watch refresh path similarly supplies that substituted fixed path to its filesystem probe/native setup without applying the profile boundary.

**Deterministic reproduction for Main:** Use only temporary synthetic directories: configure a candidate/profile, initialize the Sources owner, then replace the profile Applications directory with a symlink to a separate temporary Outside directory containing a synthetic app. Request the actual owner's refresh and watcher restart. The current consumer includes that fixed path without calling admission; scanner root resolution reaches Outside. Do not use real production roots for the regression.

**Likely root cause:** The production fixed-baseline trust shortcut is also applied to mutable test-profile roots. Startup canonicality is being treated as a permanent property.

**Recommended solution:** Revalidate fixed synthetic roots off Main before each actual scan and watch replacement; reject a changed canonical identity or escape while retaining the configured fixed reference. The baseline must remain configured even when currently unusable. Do not broaden to a parent to watch recovery. Keep the final canonical boundary check close to actual IO; a separate validation still has ordinary filesystem race limits.

**Affected scope / regression risks:** Assembly admission and watch consumer, with a focused profile composition regression. Preserve ordinary production baseline behavior and missing/reappearing-folder behavior; ensure the fixed-root `alreadyCovered` result cannot bypass profile canonicality.

**Confidence:** High for the source trace; no filesystem reproduction was executed by this reviewer.
Existing `AppSourcesProfileAssemblyTests.swift:37-61` rejects a tampered *custom preference*, which does not exercise replacement of the fixed root after startup.

### F2 — P2: Queued refresh can restart scanning after teardown

**Locations:** `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:598-604`; `Sources/AppGridUI/AppGridRefreshController.swift:78-99`.
Supporting code: `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:151-153` and `Sources/AppGridUI/AppGridRefreshController.swift:138-143`.

**Finding / evidence:** Assembly teardown cancels only scheduled debounce and increments the data-source generation. The refresh controller retains its in-flight Task and `refreshQueuedAgain`. Completing an obsolete scan returns a cancelled outcome, but the controller still calls its own `refreshNow()` when the follow-up flag is set. That call bypasses the torn-down assembly's wrapper, reads the newly incremented generation, and can start a fresh scan, cache it, and stage provider state after teardown. Clearing presentation/state callbacks prevents outward notifications, not this IO or internal mutation.

**Deterministic reproduction for Main:** Hold scan A; call refresh again so the controller sets its follow-up flag; teardown the assembly; complete A. Assert no second scanner invocation, no new cache/pending presentation, and no callback. Also cover a debounce delivery already converted into a MainActor Task at teardown.

**Likely root cause:** Generation invalidation cancels old requests but is not a permanent stopped lifecycle. The controller does not own an explicit teardown gate.

**Recommended solution:** Add an inert refresh lifecycle owned by the controller (or an equivalent composition-wide closed gate); clear queued follow-up/debounce and reject refresh/late outcome application after shutdown. Task cancellation alone is cooperative and does not replace these checks. Main owns any implementation and contract adjustment.

**Affected scope / regression risks:** Existing refresh controller and assembly teardown wiring. Keep ordinary source switching/latest-wins follow-up and resident hide behavior intact; hide must not permanently close a resident scanner.

**Confidence:** High from the explicit branch trace. Current integration tests use teardown in cleanup but do not assert this follow-up race.

### F3 — P2: A current-generation event during asynchronous setup is consumed and lost

**Locations:** `Sources/PagingPrototypeApp/AppSourceWatcher.swift:78-110`, `124-125`, `215-228`.

**Finding / evidence:** The delivery gate becomes active before setup suspends. A newly started stream can signal its generation while Main has not resumed to assign `self.session`. If Main delivery runs first, `takePendingGeneration()` clears the dirty mailbox, then `deliverChange` returns because `session == nil`. Successful setup subsequently installs the session with no pending invalidation to replay. Main delivery and the suspended setup continuation have no explicit ordering guarantee. The utility queue serializes native work but does not synchronize that installation with Main's event delivery.

**Deterministic reproduction for Main:** Use the injected backend/utility/Main delivery seams. Hold setup completion after start, signal its current-generation callback, run the Main mailbox while setup is still suspended, then finish successful setup. Assert one invalidation is delivered after installation; also verify failed, superseded, cancelled, and stopped setup deliver none. Do not use sleeps or production filesystem inputs.

**Likely root cause:** The mailbox treats a delivery as consumed before the consumer session is ready.

**Recommended solution:** Retain a single dirty event across the setup-to-installed transition and deliver only after successful current-generation installation, or issue a bounded catch-up invalidation on successful replacement. Preserve the one pending Main-delivery bound and all stop/failure generation gates.

**Affected scope / regression risks:** Watcher startup/delivery readiness and its seam tests. Avoid enabling callbacks from failed startup, duplicating event storms, or retaining the watcher in queued delivery.

**Confidence:** Medium-high for a permitted scheduling interleaving; occurrence frequency with native FSEvents was not measured.
Current successful-watch tests emit after `await replaceRoots`; the fake emits during start only on failure (`AppSourceWatcherTests.swift:357-360`). The native smoke does not establish this ordering guarantee.

## Closed finding: latest uncommitted query after a source switch

Initial inspection found that discarding pending search could leave a newer query text with older served results indefinitely when the replacement scan did not succeed.
Main repaired this during review.
Current `AppCatalogAssembly.swift:563-568` discards obsolete pending search and restages `currentQuery` against the served base when it differs from `provider.activeQuery`.
`AppSourcesCatalogIntegrationTests.swift:201-224` now stages Alpha, changes to uncommitted Beta, replaces sources, and commits Beta without requiring a new successful catalog.
**PASS at source-review scope for this edge.** The new regression is included in Main's reported full-r2 result; this reviewer did not execute it.
The existing same-active-query discard contract remains intact.

## Other scoped checks

| Concern | Source-review result | Evidence and limitations |
| --- | --- | --- |
| Selected root/home/network/bundle policy | PASS for admission logic; F1 remains at the fixed-profile consumer | Root admission validates lexical and canonical boundaries before metadata, rejects unknown/nonlocal volumes, checks read/search permission, and conservatively lowercases broad home/volume comparisons: RootAdmission.swift:114-164,174-195. Bundle components reject at 180-181. Tests include explicit case and bundle cases. |
| Native panel package policy | PASS | AppSourcesSettingsView.swift:140-143 selects directories, disables alias resolution, and does not treat packages as directories. Runtime panel behavior not exercised here. |
| Failed/future persistence must not apply | PASS for current service contract | Coordinator.swift:63-78 validates, checks transaction/cancellation, saves, then mutates runtime; failure/future returns precede runtime changes. Store.swift:49-74 does not repair on load and rechecks newer schema on explicit save. Corrupt/oversized payload handling preserves bytes as specified. UserDefaults durable-disk failure is not independently simulated. |
| Stale async draft/apply completion | PASS for mutation gating | SettingsView.swift:102-105,154-183 checks operation generation and cancellation after await; hide/reload cancels the panel and operation. Coordinator.swift:57-67 prevents an old validated transaction from saving after supersession/teardown. A rejected stale admission may return invalidRoot rather than superseded, but does not save or mutate. |
| Source-generation watch callbacks | PASS for installed generations, subject to F3 readiness | Coordinator.swift:120-140 captures source generation and checks active/toggle/teardown; watcher checks generation after setup before cancellation cleanup, so stale failure does not clear a newer gate: Watcher.swift:94-108. |
| Old scan/cache outcome and late Main return | PASS for catalog content publication | Assembly.swift:123-131,145-176 guards both before repository work and at cache write under lock. currentSnapshot at 103-106 hides cache from a different source generation. If sources change after cache write but before Main applies the successful outcome, refresh controller reads currentSnapshot again (RefreshController.swift:140-141), so old cache cannot become pending. Neutral outcome/state is not generation-tagged and can briefly describe the old request; this review does not certify status timing. |
| Served content/layout/metadata preserved on removal | PASS for inspected state paths | replaceScanRoots discards pending discovery/folders/search only, retains served snapshot, expected layout, management preferences, icons and renderer. Provider discard methods at 133-178 do not erase saved layout/metadata. IntegrationTests.swift:226-293 checks removal/readdition, hidden refs, alias, folder references, active query and app files. currentSnapshot deliberately becomes nil for the new configuration generation; the provider's served snapshot is the retained display authority. |
| Main avoids filesystem waiting in watcher/admission | PASS for static queue/actor separation | Admission actor owns probes (RootAdmission.swift:103-114). Watcher setup uses utility.perform (78-93); cleanup queues stop/invalidate/release (271-283). No semaphore/queue.sync/lock held over await in these paths. Short lock acquisition is present: no literal wait-free algorithm or GUI latency claim is made. |
| CF context / native lifecycle | PASS for inspected ownership trace | Watcher.swift:302-317 holds a temporary context retain, supplies CF retain/release hooks, releases temporary ownership on success/failure; session close detaches handle under lock and queues one ordered stop-if-started/invalidate/release at 271-286. Weak callback consumer avoids watcher retention. Runtime leak tooling not run. |
| Event privacy and delivery storm bound | PASS for installed-session mailbox | Native callback uses only nonzero event count and a neutral callback (321-325), with no copied/logged path, flag, ID, app identity, or icon work. Gate holds at most one Main-delivery slot across generations (175-229); coordinator uses existing debounced refresh route. This does not prove a global utility-job/native-resource bound under arbitrarily repeated overlapping replacements. |
| Profile persistence namespace | PASS | UITestProfile.swift:33-38,89-97 supplies candidate/profile hash namespace; AppDelegate.swift:1777-1787 rejects unconfigured profile and uses sourcesSuiteName. F1 limits continuing filesystem isolation after startup. |
| Native four-tab/hide wiring | PASS at source scope | ActivationSettingsWindowController.swift:234-238 cancels Sources operations on hide; Sources tab uses the actual view at 506-509. Controls/future/error messages exist in the native view. No geometry, accessibility navigation, screenshot, or physical input acceptance was performed. |

## Required next evidence

Main should triage/repair F1-F3 after its serial run, add the scoped deterministic regressions, then rerun nonzero focused/full tests and Debug/Release gates.
A later reviewer should recheck the final hashes and repaired traces.
No failed slice is closed by the supplied 2017/0 run: F1-F3's missing interleavings were not asserted by those cases.
GUI source controls, resident behavior, sustained native install/remove watching, latency/resource measurements, physical AB, and candidate/hash/source-manifest delivery remain separate acceptance gates.

## Reviewed snapshot hashes

Hashes record the source/test snapshot; they are not packaged executable hashes or proof of test execution.
Main changes during review were reread (root case/bundle policy and the query repair).
Later production edits invalidate the affected verdict and require a new review section.

```text
03274c8f25b46d08beb60d36046b3b9e663a2aa3a61b67606f2e6e3949503173  Docs/APP_SOURCES_AND_WATCHING_SPEC.md
c458f6105d4d1c47ae016eb61d6278f579ed0500ebef9bdddd90023a7e43054a  Sources/PagingPrototypeApp/AppSourcesCoordinator.swift
75d71eb49e8fbca86fa19757686c29ceb0743bffc598af1932047b9d2ef2784c  Sources/PagingPrototypeApp/AppSourcesSettingsView.swift
45a439ae8d07162db04c082393d6651e1d469c4316282f07c48e4826fb7791e5  Sources/PagingPrototypeApp/AppSourcesPreferences.swift
c6653d7692eb9e145be7787269914b494d65a4eebd50dcbc914e59fd089e8a81  Sources/PagingPrototypeApp/AppSourcesStore.swift
da72335d3848055c71b08b26e8b3cabbe2a5ca2933430531e5a695fa01e95322  Sources/PagingPrototypeApp/AppSourceRootAdmission.swift
eb902b452cf5b747e240e09cdeb182cc7aae8d6fc536fca43c6707124400c14f  Sources/PagingPrototypeApp/AppSourceWatcher.swift
2bee42e3db820537dc3428422127abc5a3c73c80670df9d981efece9c6d94e02  Sources/PagingPrototypeApp/AppDelegate.swift
db2b7b3e1245ead33dd2a00ae38c76bb4e1b8d0551921a5f03f481e1be049293  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
2140b8488035f4ecd5560e1ef329d697fbcb30a50fa3559f9d9f9d4c759acb79  Sources/PagingPrototypeApp/UITestProfile.swift
f84694b14a2d9b72e370b7ad9673b587c5597f6f1285abc99335991a262b06d1  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
a8af3004f57e77d969f106672a5b170c718f321b5be7b52e5249466ae043411e  Sources/AppGridUI/AppGridRefreshController.swift
361beac3483c812c227ca3bed4dc27c90ee5124550f2a6736217569082377e47  Sources/AppGridUI/AppGridSearchPresentationController.swift
a008c21fec5c078ebf677b209e32fef2dd46ed7bc15164c1ec452974ce2a6c3f  Sources/AppGridUI/AppGridUIPageContentProvider.swift
52e3e40b1c38b976f3bb04362c3d44e137fcba0ef7f28bef48e76ea6dde77c69  Sources/MacAppCatalog/CatalogScanner.swift
b0f159417ca27002fef857910a2bb2029528e44f2655062ab851acb8d7f39b0d  Sources/MacAppCatalog/CatalogRepository.swift
b26a5a4f84cab7dda66d2bd45b1af225d2ec7d9c4a44795eb499ea0ef4662967  Tests/PagingUITests/AppSourcesCoordinatorTests.swift
9a78c160e51496055e898bc541e7500fd0638c2ec954bf188722432e0498c9bc  Tests/PagingUITests/AppSourcesSettingsTests.swift
bb99e5924765a2bac1abfb77484e2491fb8f05b2dd3149e43cb62de1a40a5d56  Tests/PagingUITests/AppSourcesProfileAssemblyTests.swift
1b53ef9f9211fb602d7e2710ee207a888ba759ead4f6848e7f389af9d2d81791  Tests/PagingUITests/AppSourcesCatalogIntegrationTests.swift
d390b4a2651e3e47dce377979d2279607074362b8774041fbe9e549c304e5ff2  Tests/PagingUITests/AppSourcesPreferencesTests.swift
5265100558dd31c78f449d39648ef45a5babf24714ed65e98612403dc2eac737  Tests/PagingUITests/AppSourcesStoreTests.swift
a9843bd2683eb73f31ac72e6b95c1e218f93c1ab6085fa7eac7b5eb3c7f83f05  Tests/PagingUITests/AppSourceRootAdmissionTests.swift
ad9c7f876aab245061f4056798600441be67994fcf8ce43bbf7a54a8a26e7ff4  Tests/PagingUITests/AppSourceWatcherTests.swift
a570cdf027080d902b5445d25c258175fc11199d5100b9441e6a3ae55517efea  Tests/PagingUITests/AppSourcesNativeWatchSmokeTests.swift
```


## Repair rereview r2 — 2026-10-13, 21:10 JST

**Final verdict: PASS — bounded independent source review of F1-F3.**
This supersedes the outstanding-finding status in r1 for the repaired hashes below; the original FAIL history, original line references, and original hashes above remain unchanged.
No outstanding actionable finding remains in this bounded rereview.
This is not a GUI, physical input, global performance, Release/package, full-parity, or whole-migration PASS.

### Final repair traces and regression scope

| Finding | Verdict | Final source evidence | Reviewed regression evidence |
| --- | --- | --- | --- |
| F1: fixed-profile root substitution | CLOSED / PASS | `AppSourceRootAdmission.swift:146-156` checks exact canonical identity before the fixed-root alreadyCovered shortcut. Shared `AppSourceRootSetResolver` at `249-270` revalidates every fixed root only when a synthetic profile boundary exists, using requiresExactCanonicalPath=true. Ordinary production fixed inputs retain their baseline at 263. Custom roots retain canonical-equality admission at 264-268. Actual scanner consumer uses this resolver at `AppCatalogAssembly.swift:118-123`; actual watch consumer uses it at `AppSourcesCoordinator.swift:111-127`, with generation/cancellation checks and visible degradation even when all roots are excluded. | `AppSourceRootAdmissionTests.swift:65-75` rejects an identity substitution still inside the profile before target metadata. `AppSourcesProfileAssemblyTests.swift:98-138` uses the actual owner, real temporary synthetic apps, fixed-root replacement to a separate temporary Outside directory, empty scan/watch inputs, retained preferences/configured reference, and restoration. `AppSourcesCatalogIntegrationTests.swift:152-159` explicitly checks fixed/custom order and exact flag true/false. |
| F2: refresh after teardown | CLOSED / PASS | Data source checks closed/cancelled before admission at `AppCatalogAssembly.swift:113-115`, checks cancellation/current generation before repository refresh at 123-126, and rejects cancelled or closed cache writes at 130,176-181. readSnapshot rejects closure at 107; replaceRoots cannot reopen at 146; isCurrent rejects closure at 173. New idempotent permanent `close()` at 160-163 is called by actual assembly teardown at 608-614. Existing `invalidateRequests()` at 153-156 remains a generation-only invalidation, preserving cancellation/recovery semantics. A controller follow-up or already-converted debounce task may still enter the controller, but its closed data-source result is cancelled with succeeded=false, so the controller's receive branch cannot stage a new snapshot. | `AppSourcesCatalogIntegrationTests.swift:204-224` holds a scan, queues a follow-up, tears down, then completes the old scan successfully and checks no extra scan/cache/pending state/callback. `226-244` exercises direct controller entry after teardown and proves replacement cannot reopen the data source. Existing `67-113` continues to verify reusable invalidation and subsequent successful recovery. |
| F3: consumed early watcher event | CLOSED / PASS | `AppSourceWatcher.swift:133-139` retains current-generation pre-install delivery in one MainActor boolean. Successful current noncancelled setup installs the session at 114 and replays/reset that bit at 115-117. Generation check precedes cancellation/failure cleanup at 99-111; stop clears readiness dirt at 123-129. Old setup cannot clear a newer generation's bit, and failed/cancelled/stopped setup cannot replay it. One mailbox plus one boolean keeps the existing bound; no native path/identity/event payload is retained. | `AppSourceWatcherTests.swift:100-132` forces two consumed pre-install batches including 10,000 events, for active and degraded startup, then checks one replay and ordinary post-install delivery. `135-170` forces failure/cancel/stop, verifies cleanup order and no replay through retry. Strengthened supersession test at `251-280` covers stale successful/create-failed/start-failed setup without erasing a newer startup invalidation. |

Resolver cancellation checks at `AppSourceRootAdmission.swift:257,265` stop further root iterations when the task is cancelled; both consumers reject cancelled resolution instead of using a partial admitted set.
Permanent closure prevents later refresh entry and publication. This does not claim synchronous cancellation of already-started filesystem work or a literal lock-free/wait-free algorithm.
The fixed-root check is a pre-use canonical admission check, not a filesystem-handle sandbox eliminating every adversarial change between admission and enumeration.

The prior query repair remains present at `AppCatalogAssembly.swift:574-577`: current uncommitted query is restaged against the served base after obsolete pending discovery/search is discarded.
Its no-new-successful-catalog regression now resides at `AppSourcesCatalogIntegrationTests.swift:246-269`.
Source switching still retains served display/layout/management data and uses the existing idle commit; the refresh framework was not broadened for this repair.

Watcher default construction now supplies explicit Sendable closures at `AppSourceWatcher.swift:39-40`.
Utility setup/cleanup, CF context temporary/stream retains, invalidate-while-scheduled then release, and neutral native callback handling remain intact at `81-119,284-299,315-345`.
The new readiness state stays MainActor-owned and adds no per-frame work, filesystem probe, event path storage, or additional queued replay task.

### Review feedback resolved before final verdict

During rereview, the first permanent-gate draft changed invalidateRequests into permanent close while an existing integration test still expected recovery; two older spy assertions still counted custom roots alone.
These were reported immediately to Main from source inspection.
Main separated permanent close from reusable invalidation, added cancellation guards, and changed profile spy assertions to fixed/custom calls with exact flag checks.
The final reread confirms these corrections, including the six-call nested install/removal expectation at `AppSourcesCatalogIntegrationTests.swift:376`.
They are resolved feedback, not outstanding production findings and not a silent revision of r1 history.

### Execution and delivery evidence cutoff

Main reported focused-r5 **112 tests / 6 assertion failures**, attributed to the obsolete lifecycle/call-count expectations; Main reported the new F1-F3 regression cases themselves passed in that run.
After corrections, Main reported focused-r6 **112 tests / 0 failures**, completed **21:09:22.745 JST**, including all F1-F3 regressions.
These remain Main-supplied execution results; this reviewer performed no Swift/build/test execution.

Main identified the 328-entry source/test/script/resource/package manifest as
`.build/verification/20261013/app-sources/source-files-r2.sha256`.
It is a delivery manifest reference, not an independently verified packaged executable identity in this review.
At the cutoff, Main's full-r3 and Debug/Release candidate-r2 work was running serially with no source edits; no completion of those gates is asserted here.
GUI controls/accessibility, sustained real watch behavior, physical AB, latency/leak/backlog measurements, and whole parity remain separate gates.
The explicitly approved clickable page dots belong to the next phase after Sources repair gates; they were not implemented or reviewed here.

Only this existing report was edited in rereview. All source and tests stayed read-only.
The installed write-swift guidance and RTK command routing continued from r1.
The repaired inputs were reread and fingerprinted; later changes require another appended review.

### Final repaired-input SHA-256 manifest

```text
86bb5db04edd0b12ae841cc8f306ce692e901fc0fd0fa9a521d8191318736988  Sources/PagingPrototypeApp/AppSourceRootAdmission.swift
020029f817b44021912e26b49f08f4c3e7d8cbee70edf487fbb6d9c7865dceb4  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
dfbd5972fa725b412ca32ff5e2c3ee0233a9c39709a80c43e2242bc33eccc676  Sources/PagingPrototypeApp/AppSourcesCoordinator.swift
4ecc2f1ab3bbb59cbe0a45f7f0becbff0a2b2b81bf130e3cdd54ec09f88801fb  Sources/PagingPrototypeApp/AppSourceWatcher.swift
eae993686812bdcedcee904eaa1ac571fad24e0c01dedf6eb3d8af342f4b9925  Tests/PagingUITests/AppSourceRootAdmissionTests.swift
3f29fe80079d4101779e1d825d7383501c9a72668f24e72240dec63836d9b710  Tests/PagingUITests/AppSourcesProfileAssemblyTests.swift
a69fe02029af7a146aab71399d23bec2e6f789caf7c6ddced337167ea227b8f7  Tests/PagingUITests/AppSourcesCatalogIntegrationTests.swift
d7426c6082fd59c31f5472cf10d3cbe9c1c0da6b22210b7da1c3147ecf216628  Tests/PagingUITests/AppSourceWatcherTests.swift
```


## Delivery evidence addendum — 2026-10-13, 21:12 JST

Main supplied the following completed gates after the repair-rereview cutoff:

- Full-r3: **2023 tests / 0 failures**, completed **21:10:56.996 JST**, elapsed **26.771 seconds**.
- Debug and Release candidate-r2 build/package gates: **PASS**, as reported by Main.
- Executable SHA-256: `bf4e5a661eec0dd1a4e43e2a045b7250c740d4ed00f1c40b5d5b4c80a62e407f`.
- All **328** fingerprints in `.build/verification/20261013/app-sources/source-files-r2.sha256` checked and matched, as reported by Main.
- New function-conversion warnings are gone; the preexisting `diagBackend` warning remains. No warning-free build claim is made.
- A manual runner was prepared with **40 synthetic metadata bundles** under the new candidate profile. Preparation is not GUI or runtime acceptance.

These are explicitly **Main-reported execution and delivery evidence**. This reviewer did not rerun tests/builds, independently hash the delivered executable, or independently validate the complete 328-entry delivery manifest. The repaired-input hashes in the preceding section are the reviewer's source/test fingerprints; the supplied executable hash is a separate artifact identity.

**Final reviewer verdict remains PASS only for the bounded source review, with F1-F3 closed.** The r1 FAIL and all intermediate evidence cutoffs remain preserved above. The completed Main gates supplement the source verdict without converting it into GUI, physical input, sustained native-watching, global performance, full-parity, or whole-migration acceptance.

Main confirmed **no GUI, installation, or launch occurred**. The next explicitly approved phase is clickable page dots after the Sources repair gates; this review does not implement or certify that phase.

Reviewer ownership of `Docs/APP_SOURCES_SLICE_REVIEW.md` is now **released to Main**. Only this report was changed by the reviewer; implementation, tests, process state, and installed applications were not modified.
