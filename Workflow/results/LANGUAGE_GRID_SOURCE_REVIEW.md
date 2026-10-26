# Grid and Pager Language — Independent Source Review

Date: 2026-10-14. Verdict: **FINDINGS — one Main integration defect; no additional concrete defect identified in the frozen Task B consumers.** This is a bounded source review, not test, GUI, packaging, VoiceOver or performance acceptance.

## Scope and authority

Reviewed the approved `Docs/INTERFACE_LANGUAGE_SPEC.md`, Task B's frozen `Workflow/results/LANGUAGE_GRID_CONSUMERS.md`, the nine assigned consumer/key files, the two new native consumer suites, and Main's renderer and AppDelegate initialization/presentation/teardown integration. Read the language presentation scheduler and the minimum additional production callees needed to establish the finding below. Architecture is a macOS AppKit launcher, SwiftPM/Swift 5.9, with independent PagingCore, PagingUI, catalog, icon-pipeline and localization targets. Retained view identity and the existing asynchronous icon/token architecture are preserved.

The old workflow is explicitly waived for this assignment. Only this report is writable. No implementation/test files were edited; no build, tests, application launch, process control, unrelated dirty-tree evaluation, external reference implementation, evidence directory or global memory was used. Shell work used RTK after reading its mandatory instructions. No other reviewer or Main integration files were written.

## Finding

### [P2] Pending catalog commit still invokes localization formatting inside the terminal frame

**Primary location:** `Sources/PagingPrototypeApp/AppDelegate.swift:1141` (`refreshAppManagementSettings()`); forwarding into `appManagementView.reload` occurs at `AppDelegate.swift:2258`. Actual formatter sites are `Sources/PagingPrototypeApp/AppManagementSettingsView.swift:101` and `:186`.

**Trigger:** An existing settings singleton and installed Management coordinator, a catalog snapshot pending during settling, and the terminal `advanceFrame` that brings Core to idle. The settings window need not be visible: `refreshAppManagementSettings` checks only that the singleton exists.

**Evidence / actual production route:**

1. `PagingSurface.swift:578` calls `core.tick` synchronously. Its idle state callback enters `handleCoreState`, which invokes `onIdleBoundary` at `:597`.
2. Production wiring at `AppDelegate.swift:596-600` calls `applyPendingAtIdleBoundary`; `:1151` calls `assembly.commitPendingAtIdleBoundary`.
3. `AppCatalogAssembly.swift:565-567` forwards into `searchPresentation.applyPendingAtIdleBoundary`. A pending catalog causes `AppGridSearchPresentationController.swift:91-96` to synchronously invoke `onPresentationUpdate`.
4. Production callback wiring at `AppDelegate.swift:687-693` invokes `applyPresentationUpdate`; its `:1141` synchronously calls `refreshAppManagementSettings`.
5. `AppDelegate.swift:2250-2259` reaches `appManagementView.reload`. That method performs static template reads at `AppManagementSettingsView.swift:89,93`, parameterized `strings.hiddenReferenceCount(...)` at `:101`, and `relabel(strings:)` at `:104`.
6. `relabel` performs further template reads at `:166-185` and a second `hiddenReferenceCount` at `:186`. `LocalizedStrings.swift:78-84` and `:107-108` confirm these are synchronous validated-template rendering operations on the retained snapshot.

The formatting is conditional but deterministically reachable through the shipping idle commit wiring; no timing assumption, GUI observation or measured hitch is needed for that conclusion. It violates the approved prohibition on new formatting/resource lookup/relabeling within advanceFrame's transitive Core callbacks. This finding does **not** allege fresh bundle/file IO on this route, nor establish a performance regression magnitude.

**Likely root cause:** The pager consumers were deferred correctly, but the production idle commit still invokes a settings reload that now includes localization rendering. The new renderer frame suite installs a real renderer plus a dot callback, but does not attach this Main idle/catalog/settings callback chain.

**Recommended solution:** Main should coalesce this settings presentation refresh onto the next main turn, with final-teardown/owner-generation checks, while retaining the synchronous catalog/pager commit semantics. At execution use the current committed records/preferences and respect active editor ownership/drafts. Do not move the catalog commit itself simply to satisfy a formatter counter.

**Affected scope:** Main AppDelegate catalog-to-settings integration, and the settings consumer reached by it. This is not a workerB renderer-forwarding defect. Repair ownership remains with Main.

**Regression coverage requested:** Exercise the actual production pending-catalog idle commit with an already-created settings singleton/coordinator. Count static template calls and parameterized formatting as well as the grid/pager counters. Assert no new template calls on the terminal frame, positive/current-language presentation after draining the queue, preserved drafts and selected controls, and suppressed pending work after teardown/replacement. The existing 100-folder-page renderer route should remain unchanged.

**Regression risks:** Deferred refresh must remain latest-wins and must not retain an obsolete singleton/profile or overwrite an in-progress alias edit. Preserve callbacks, current catalog identity and existing icon/layout behavior. **Confidence:** high in synchronous source reachability; runtime cost unmeasured.

## Renderer hook discovery and repaired scope

Task B's report correctly preserved a missing integration seam: language forwarding was placed in `folderSnapshotProvider.didSet` instead of the actual new/reused render route. Main reports six Japanese AX failures on that route in focused-r1 and corrected the hook.

The current source independently confirms `AppCatalogAssembly.swift:367` injects the retained snapshot after selecting a live/pooled/new page and before `page.render` at `:379`. The unrelated folder provider setter at `:264-269` now only forwards its provider. `AppGridPageView.relabel` at `:137-141` retains the snapshot, forwards to cells and queues page text. Cell relabel at `AppGridCellView.swift:71-74` also queues; neither constructs resources or formats on this renderer call stack. This repaired integration issue is closed as a source finding, not attributed to workerB.

The hook was pending rerun when initially inspected. Main subsequently reported focused-r2 **58 tests / 0 failures**, including the real renderer transitive counter route. No execution log was read by this reviewer; the result is Main-reported, not independently certified. The separate pending-catalog/settings route above remains outside that test.

## Bounded source checks

- **Frame text:** `PagingSurface.swift:207-218,944-996` queues AX and diagnostic rendering outside Core callbacks. The diagnostic `String(format:)` is only in the queued renderer. PageHost (`:63-74`), AppGridPage (`:149-168`), folder-cell count/help (`:81-99`) and dots (`:48-87`) have the same queue boundary. Default lazy constructors retain nil snapshots/English literals instead of constructing LocalizedStrings on a frame route. These source checks establish no fresh localization resource-provider access in the reviewed consumer frame path, with the Main settings formatting exception above.
- **Latest-wins and lifecycle:** callbacks capture text generations and read current binding/page/count/snapshot state when they run. Cell clear invalidates queued folder text; page clear/teardown invalidates page/cell work; retired cell arrays invalidate before removal. Surface teardown invalidates live and pooled host callbacks; dot replacement and final teardown call `teardown()`. A rejected stale callback cannot clear the scheduling flag for newer-generation work. The owner scheduler rechecks readiness before its queued presentation and rejects obsolete owner generations.
- **Retained/reused views:** renderer relabel forwards to both pages and pool (`AppCatalogAssembly.swift:215-218`); render installs the retained snapshot at `:367`. Surface relabel forwards to both live hosts and pool (`PagingSurface.swift:199-204`), and adoption forwards it at `:869`. New cells receive the page/overlay snapshot before binding. Language-only methods do not rebind, request icons, mutate query/catalog revision, page/focus identity, geometry, appearances or user names.
- **Overlay/editor/proxy:** live overlay relabel changes chrome and forwards the snapshot to members and the move-out proxy (`FolderOverlayView.swift:235-243`); proxy construction and reattachment receive it (`:719,:176`). These proxies contain app names, which remain verbatim. Frozen visual-only overlays reject relabeling; member/proxy app cells do not have folder-count presentation to asynchronously change. Title editor relabel only writes placeholder/AX text (`FolderTitleEditor.swift:52-55`), retaining actual field-editor text/selection/fallback/callbacks. Main creates it with the current snapshot before mounting (`AppDelegate.swift:1539-1544`).
- **Main hooks:** accepted language is installed before consumer construction (`AppDelegate.swift:194`), forwarded into surface/assembly/overlay/dots/editor (`:253,:568-570,:758,:2478,:1540`), and `presentLanguage` covers all assigned live consumers (`:2112-2124`). Production dot navigation callbacks call `refreshPageDots`, which queues language readiness and dot text rather than presenting language on the frame stack (`:2485,:2515-2522`). Final teardown invalidates the language owner, dots, surface, renderer and overlay (`:2862-2868,:2883,:2903-2906`).
- **Dot arithmetic:** the nine-dot window uses count clamps, difference-first committed/window calculations, bounded visible tags and difference-first next-window increments (`PageDotsView.swift:134-145,187-189,224,275-277`). Relabeling only changes AX/help; it does not recenter a browsed window, alter tags/actions, selected state or enabled state. Int.max is covered by a real dot instance in the new test source.

## Test-source review and execution boundary

Read all nine GridLanguageConsumersTests and all nine PagerLanguageConsumersTests, plus the relevant Main runtime fixtures. They instantiate actual AppKit consumers and check retained identities, binding/focus/geometry, counts, real page/cell/host reuse, query preservation, teardown, frozen exits, native target/action and actual field-editor selection. The renderer frame test uses AppGridRenderer and traverses 100 folder pages in both directions, capturing views before/after each frame and requiring queued formatting afterward. It is stronger than a synthetic label-only test.

The frame counter sum is disjoint: unique object-identity dictionaries hold each host/page/cell once; surface/dots counters are separate. Counters count parameterized executions, including English fallback, and diagnostic rendering. They do **not** count static grid/settings template reads or resource-provider access. Consequently these tests alone do not establish the complete transitive lookup/IO contract, especially the production route in the finding. No additional Task B source regression was inferred solely from missing coverage.

Main's reported evidence, not log-verified by this reviewer:

- Focused-r1: 58 tests / 19 assertion failures; Main attributes 12 to incomplete schema fixtures, six to its missing renderer hook, and one to a Main integration AX expectation. No separate source defect is inferred from the unidentified AX failure.
- Focused-r2: 58 tests / 0 failures after Main fixture/hook corrections.
- Full-r1: 2318 tests / 249 assertion failures; Main attributes most to legacy synchronous text expectations (including 207 repeated view-budget assertions), old Chinese/default-dot expectations, and one recording-control locator. Main reports retaining assertions/budgets while adding queue drains, explicit Chinese dot injection and a stable action locator. Legacy-focused rerun is in progress; no result is assumed.

No test/build/app/process command was run by this reviewer. No GUI, VoiceOver, resource packaging, restart, 120Hz or performance PASS is claimed. Pending catalog/settings frame coverage and Main's remaining serial verification remain open.

## Source fingerprints at report completion

These SHA-256 values identify the bounded reviewed source snapshot; they do not freeze Main's concurrent work or represent candidate/runtime fingerprints.

| File | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/AppGridCellView.swift` | `3fe5fbae3eeaa64e4c63c51329f5f0096b896cc44bfba0b6fbc505913fa46fa6` |
| `Sources/AppGridUI/AppGridPageView.swift` | `331514e9da1b1a3af7b1c4ec5d44fcdec97ce030201c386c72d93e63e5a60c00` |
| `Sources/AppGridUI/AppGridUIPageContentProvider.swift` | `8344e01e5cb28f032c51097a7fcfda1b0868b36978b2490b5e0d3436989d8628` |
| `Sources/AppGridUI/FolderOverlayView.swift` | `76b4d198a4ebea9d54893f9f4a3672813179543585996d91ada1394bdc0f09dd` |
| `Sources/PagingUI/PageHostView.swift` | `e896713c1e4aae7cddb5fc9724f304d0b2d0c6ecc8a1defbba0eb869353e97ad` |
| `Sources/PagingUI/PagingSurface.swift` | `ff9a4278fbf17e2e35426ae8d8afc0271cd3c69b30d4378fe908c0f8bffd8c44` |
| `Sources/PagingPrototypeApp/PageDotsView.swift` | `38fb8a75c75d1796c133ba44bc9d68a8e743f08dc586263d8f9b4573dee9f0db` |
| `Sources/PagingPrototypeApp/FolderTitleEditor.swift` | `4470a7f27afcb6f3466b00fbf10898a01bbe40480570c43d7e3e232009511f03` |
| `Sources/LauncherLocalization/GridTextKey.swift` | `9edaf2ea3b6972cf8338807a41413d0909f14fa64bc43371f43bf1de326c1e9c` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `82f6e12d6427142bdab69c86366f9b655366514a98eceab0955c83b740fb79f5` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `271fed7a595313d08a72725062de38b759d7172f80be8490bab0bbf58b182f3f` |
| `Sources/PagingPrototypeApp/AppManagementSettingsView.swift` | `7800615c38952b3463febc8464846cef5692e2be27243337c2bfc5dc7fb325c1` |
| `Sources/AppGridUI/AppGridSearchPresentationController.swift` | `361beac3483c812c227ca3bed4dc27c90ee5124550f2a6736217569082377e47` |
| `Tests/AppGridUITests/GridLanguageConsumersTests.swift` | `47f57da8380bfe6ffe3130b5b228d5abb2177f3cbf65df5678c07746817a9c30` |
| `Tests/PagingUITests/PagerLanguageConsumersTests.swift` | `3a92321483fa48631fe7161ec060cf9f2c12658789cd6bbb620bedef449790b8` |
| `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` | `3b1b871f9d094d7561702cfb136ce52ed4173105d0f4ac153a8ae4bec35e0b9d` |


## P2 repair re-review — 2026-10-14 (append-only)

**Superseding bounded disposition:** The original terminal-frame formatting P2 is **repaired in the current source**. **One new P2 caused by the repair remains**, described below. The initial FINDINGS and its fingerprints above remain historical and unchanged. No overall acceptance or performance PASS is granted.

Only the original pending-catalog/settings route, its queue/lifecycle/ownership implementation, the draft-preserving refresh, and the three new runtime fixtures were re-reviewed. Additional reads were limited to the alias action's actual coordinator/preference callees and existing alias action tests needed to validate the new finding. No source/test edits, builds, tests, app launches, process control, unrelated dirty-tree review, evidence-directory access or memory access were performed. This report is the sole changed file.

### Original P2: source repair confirmed

- `AppDelegate.swift:1129,2264-2269` now stages a pending refresh and schedules it, rather than calling a settings reload on the catalog commit stack. `:2274-2295` performs the settings/template work inside `DispatchQueue.main.async`. The synchronous catalog commit remains at `:1157-1163`.
- The queued callback captures the language epoch and a weak Management coordinator, verifies epoch/final teardown/coordinator identity, and fetches the current records and committed preferences at execution (`:2277-2294`). Multiple requests coalesce behind the pending/scheduled flags. A callback rejected by an obsolete epoch cannot reset a newer epoch's scheduling flag.
- The current target is `configuredLanguageSettingsController ?? ActivationSettingsWindowController.shared` (`:2266,:2284`). This matches the actual configured runtime owner and makes the direct native-controller fixture meaningful without populating a test global singleton. The target is selected at execution, not strongly retained by the pending callback.
- The callback retains pending work when production language readiness, native menu ownership or an actual alias field editor blocks it (`:2288-2290`). `scheduleLanguageReadinessRetry` retries Management presentation before checking whether any locale is pending (`:2109-2112`). Production menu-end, sheet-end and text-end notifications feed this route via `LanguageRuntimeObservers.swift:22-34`; existing explicit settings/source/recording readiness hooks remain connected. The read-only `hasInteractionOwners` accessor does not release ownership (`LanguagePresentationController.swift:51-52`).
- Language teardown increments the epoch and clears both pending/scheduled Management state (`AppDelegate.swift:2145-2153`); final teardown sets its terminal guard before invoking it. No new concrete obsolete-queue or owner-release defect was identified within this bounded route.
- Shipping setup calls `installCatalogPresentationCallbacks` at `AppDelegate.swift:588`. The helper at `:1135-1153` installs the same assembly presentation, surface idle and search-presentation callbacks; `LanguageRuntimeIntegrationTests.swift:415` invokes that shipping helper. The fixture does not copy those three callbacks. Existing scan-completion/search-result callbacks remain in shipping setup.
- All actual Management `strings.settingsText` and `strings.hiddenReferenceCount` calls now pass through the corresponding cumulative wrappers (`AppManagementSettingsView.swift:81-91`); reload, relabel and feedback use those wrappers. The static and parameterized counters are disjoint. There is no such wrapper invocation in the new queue's synchronous staging/readiness checks.

### [P2-R1] Draft restoration revives the field text after a successful Clear Alias

**Primary location:** `Sources/PagingPrototypeApp/AppManagementSettingsView.swift:101`, with the successful action at `:151-153` and the shared refresh caller at `Sources/PagingPrototypeApp/AppDelegate.swift:2292`.

**Trigger:** Select an app with a persisted nonempty alias (for example, `Pinned`), click the real Clear Alias control, allow the accepted save and deferred refresh to finish, and keep the same app selected. This does not require a catalog race, marked text or a failed save.

**Evidence / shipping action route:**

1. `AppManagementSettingsView.clearAlias` invokes `onSetAlias(selected, nil)` and shows its result; it never clears the field (`:151-153`).
2. Production wiring at `AppDelegate.swift:2308-2309` forwards to `setAppAlias`; `:2320-2324` derives cleared preferences and calls the actual coordinator. `AppManagementPreferences.swift:88-99` removes the alias for nil input.
3. On `.saved`, `AppManagementStore.swift:93-99` updates committed preferences and invokes `applyPreferences` when changed. The production closure at `AppDelegate.swift:2168-2169` calls `applyAppManagementPreferences`, which queues the same settings refresh at `:2185` (and can coalesce an earlier request).
4. The queued callback calls `refreshCatalog` for both catalog commits and accepted Management preference changes (`AppDelegate.swift:2292-2294`). Its `AppManagementSettingsView.swift:98-101` snapshots the still-nonempty field, reloads the now-cleared committed preferences, then unconditionally restores the old field for the same selected AppID.

After the queue drains, the popup/catalog reflects the cleared preference but the editable alias field still shows `Pinned`. Clicking Save Alias subsequently reads that field (`:147-149`) and restores the alias the user just explicitly removed. Persistence initially clears correctly; this finding is a stale UI/intent regression and possible unintended re-save, not a claim that Clear failed to write.

**Likely root cause:** The new catalog-only draft preservation function is also used for successful alias mutation refreshes, without distinguishing unfinished edits from an explicit successful clear. The old synchronous `configureAppManagementSettings -> reload` refreshed the field from committed preferences; the new generic restoration overrides that value.

**Recommended solution:** Respect an explicitly successful alias mutation before generic draft preservation. For example, on successful Clear, clear the corresponding field/draft (and actual editor if present) so the later catalog refresh preserves the accepted cleared value. Failed/protected clears must retain the original draft. Alternatively distinguish accepted alias mutation refreshes from passive catalog refreshes while keeping both outside the frame stack. Do not remove passive catalog draft preservation or make settings reload synchronous again.

**Affected scope:** Main's Management refresh/action integration and the new `refreshCatalog` preservation policy. **Regression risks:** Preserve unrelated selected-app drafts through catalog changes, failures and owner release; never discard an active edit merely to make the new assertion pass. **Confidence:** high; the full synchronous save-to-deferred-refresh route is established by source. No GUI/test execution was performed by this reviewer.

**Required regression:** Through the real Main callback/coordinator/store route, start with a persisted alias, click Clear successfully, drain the queue, and assert both committed alias nil and editable field empty; subsequent Save must not revive it. Include a failed Clear that retains the draft, and retain the three existing frame/field-editor/teardown cases.

### Added tests and reported execution

The three new native runtime tests exercise the previously missing shipping callback route: terminal-frame pending revision commit with zero Management static/count-template deltas on every frame and positive work after draining; actual alias field-editor ownership/release with native notification-type retry; and namespace/language teardown rejecting queued template work. The current editor fixture selects the actual Management tab before `makeFirstResponder`, then obtains the real editor. It routes the end-editing notification through its injected NotificationCenter; it does not establish a separate GUI acceptance result.

Those tests preserve an unfinished field across passive catalog refreshes. They do not exercise successful Clear Alias followed by the new draft-restoring refresh, so their reported success does not resolve P2-R1.

Main reports repair-r1 **74 / 4 failures**, attributed to `.shared`-only fixture routing; the target-owner fix is independently visible in current source. Main subsequently reports management-frame-repair-r3 **74 / 0 failures**, including the synchronous revision-21/zero-per-frame/positive-after-queue/draft assertions after making the actual Management tab active. Full-r3 is reported running against a 375-file source snapshot. No execution log or that broader snapshot manifest was inspected by this reviewer; no success of the running full suite is assumed. Candidate-r1 is superseded per Main's instruction.

**Next action:** Main repairs P2-R1 and adds the real successful/failed alias action regression. The original terminal-frame P2 need not be reopened unless that repair reintroduces synchronous template work.

### Re-review source fingerprints

These hashes identify the bounded files read at append time; they are not candidate or whole-tree fingerprints.

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `0d1f3061a5bdcf6cec9bd9702b465f9d90f3da249c6c6fa7229628cdb091f1cf` |
| `Sources/PagingPrototypeApp/AppManagementSettingsView.swift` | `b6381957bec50db5e8a39f24d29d1ee7646fc228b877cee2eae3a58de9e963f1` |
| `Sources/PagingPrototypeApp/LanguagePresentationController.swift` | `dda8a9477968803458a2b22de91a79cb5d1d61279eb8959be1497d8583894ca1` |
| `Sources/PagingPrototypeApp/LanguageRuntimeObservers.swift` | `c4b71b0bd6a748c369a5bee350854305f1b6b2763c2e7d7e7d78962a16b1d0b1` |
| `Sources/PagingPrototypeApp/AppManagementStore.swift` | `53bf760fb4bd44d2973de3effba13faec8af570deb69184d5bb62616f5b74222` |
| `Sources/AppGridUI/AppManagementPreferences.swift` | `9a479f644cfb3ae5e40c6918adbf2d37c5ee1b7fce88c20f14ec0cbe3030c826` |
| `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` | `b68fa671a70669f337cf943fc34b710344891c843ce59ac9fc2fed7a37c262d4` |


## P2-R1 repair re-review — 2026-10-14 (append-only)

**Latest bounded disposition:** The original terminal-frame formatting P2 and P2-R1 (revived cleared alias text) are **repaired in the current source**. No further defect was identified in the revised alias save/clear path. **One P2 remains in the directly accompanying queued checkbox rollback change**, below. Earlier FINDINGS and both earlier source snapshots are preserved without alteration.

Re-reviewed only the alias draft/action changes, the accompanying hidden-checkbox rollback, their Main/coordinator queue route, and the two added native runtime tests. Only this report was appended. No source/test files were written, and no build, tests, application/process control, external/reference code, evidence directory, global memory or broad dirty-tree inspection was used.

### P2-R1: source repair confirmed

- `AppManagementSettingsView.swift:98-105` compares the field against the **previous** accepted alias before reloading. Passive refresh restores only a differing draft for the same selected AppID; a field equal to the prior accepted value follows the newly accepted preferences instead.
- Successful Clear explicitly empties the corresponding field before any later queue turn (`:161-165`). A failed/protected clear does not change it. The original sequence persisted alias -> successful Clear -> deferred refresh -> Save no longer restores the removed text.
- Successful Save trims the visible text using the same whitespace/newline normalization as `AppManagementPreferences.settingAlias` (`AppManagementSettingsView.swift:153-159`; `AppManagementPreferences.swift:88-99`). Failed Save leaves the draft intact. The selected-AppID guards avoid updating a different selection if a callback changes selection.
- On the shipping Main callback route, changed preferences are accepted synchronously by `AppManagementCoordinator`; only settings presentation is deferred. Pending catalog/alias requests still coalesce and read latest committed data. No new template call was introduced into the synchronous catalog refresh staging path; the original epoch/teardown/owner checks remain at `AppDelegate.swift:2274-2295`.
- The new success runtime test at `LanguageRuntimeIntegrationTests.swift:498-520` clicks the actual Save/Clear/Save controls through Main's real coordinator, in-memory store and provider route. It asserts normalized text, empty text before/after queue drain, same selection, removal from provider preferences and popup text, and no revival after re-save. The failure test at `:522-531` clicks the actual Clear control with an injected `.failed` callback and verifies draft retention. That failure case covers the view's failure branch; it does not itself exercise a failing persistence store/coordinator.

### [P2-R2] Failure rollback uses pre-refresh preferences after an earlier accepted hide

**Primary location:** `Sources/PagingPrototypeApp/AppManagementSettingsView.swift:151` (rollback); accepted action handling at `:145-151`. Related production queue hold: `Sources/PagingPrototypeApp/AppDelegate.swift:2288-2290`.

**Trigger / deterministic state sequence:** Keep the same app selected, initially unhidden, with Management refresh held by the actual alias field editor. Successfully set Hidden on; before that pending refresh can update the view's `preferences`, request Hidden off and have that second save fail or be protected.

**Evidence:**

1. The successful first request updates real coordinator committed preferences at `AppManagementStore.swift:93-98` and Main/provider preferences through `AppDelegate.swift:2176-2185`. The checkbox remains on, as intended by the new successful branch.
2. The queued presentation is explicitly blocked while `aliasField.currentEditor() != nil` (`AppDelegate.swift:2290`). Thus the view's `preferences`, assigned only by reload (`AppManagementSettingsView.swift:112`), can still say unhidden after the coordinator/provider have accepted hidden.
3. A failing second request leaves the coordinator's accepted hidden value untouched (`AppManagementStore.swift:93-94`). However the new rollback at `AppManagementSettingsView.swift:151` reads the view's stale `preferences` and sets the checkbox off. It now indicates the rejected unhide succeeded, despite the accepted value still being hidden.

The inverse sequence (accepted unhide, failed hide before refresh) has the same stale rollback problem. This is a conditional presentation/state-consistency regression while the deliberately held queue is pending, not an assertion that persistence loses the previously accepted preference. It can last until the editor/owner releases, rather than just a single queue turn.

**Likely root cause:** Keeping the successful checkbox intent visible fixes the first action, but does not advance the view's authoritative rollback baseline. The failure branch still assumes a synchronous callback reload, which the original P2 repair intentionally removed.

**Recommended solution:** Track the last accepted hidden value for the selected app independently of deferred catalog presentation, or read the current coordinator-accepted value for rollback. Advance that baseline after `.saved` and leave it unchanged after a rejected save. Reset/adopt it correctly on selection/catalog refresh. Preserve the alias draft and the deferred formatting/ownership boundary.

**Affected scope:** The directly accompanying Main Management checkbox action change and queued refresh consistency. **Regression risks:** Selected-app identity changes, failed/protected saves, and alias-editor owner holds must not overwrite another app's state or force a settings reload. **Confidence:** high in source state reachability; no live interaction or timing measurement is claimed.

**Required regression:** Using the real Main coordinator with a controllable store, hold the actual alias field editor, accept the first hide/unhide, reject the inverse request, and assert the checkbox matches the still-accepted coordinator/provider value before owner release. Repeat both directions, then release the editor and verify the queued refresh preserves that value and the alias draft. Existing single-failure tests initialize view and accepted state to the same baseline (`AppManagementSettingsTests.swift:128-147`) and do not cover this pending-success sequence.

### Reported execution and remaining boundary

Main reports management-frame-repair-r4 **76 tests / 0 failures** on these latest alias/dirty/checkbox changes. Main reports an immutable `source-files-r4.sha256` 375-file input snapshot and final focused/full suites running serially. Candidate-r3 packaging is planned after completion; candidate-r1/r2 are superseded and preserved. This reviewer did not inspect those logs or the broader manifest, did not run any tests, and does not assume the running suites or planned candidate succeeded. The two new action tests do not cover P2-R2.

**Next action:** Original P2/P2-R1 source repair can remain closed. Main should correct the pending accepted-state rollback in P2-R2 and cover the two-action held-owner sequence without reintroducing synchronous settings/template work.

### Latest bounded source fingerprints

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppManagementSettingsView.swift` | `9c3fe5370313697d95f8867dfe4d84e6106561341db763bfb27035c34978e6fa` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `0d1f3061a5bdcf6cec9bd9702b465f9d90f3da249c6c6fa7229628cdb091f1cf` |
| `Sources/PagingPrototypeApp/AppManagementStore.swift` | `53bf760fb4bd44d2973de3effba13faec8af570deb69184d5bb62616f5b74222` |
| `Sources/AppGridUI/AppManagementPreferences.swift` | `9a479f644cfb3ae5e40c6918adbf2d37c5ee1b7fce88c20f14ec0cbe3030c826` |
| `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` | `76087a618218cf57bb6730c35e63690bb4551e884df668d8eb4dc52393240f41` |


## P2-R2 accepted-mirror re-review — 2026-10-14 (append-only)

**Latest bounded disposition: SOURCE CLEAR for the reviewed original P2, P2-R1 and P2-R2 repair paths.** All three findings are repaired in the current source. No additional concrete regression was identified in the specified accepted-mirror/queued-refresh changes. This supersedes the open-finding dispositions above for those paths only; all historical FINDINGS, evidence boundaries and fingerprints remain preserved. It is not whole-project, GUI, packaging, persistence-restart or performance acceptance.

Only the P2-R2 toggle rollback/accepted mirror, accompanying alias mirrors, their existing Main queue/coordinator/preference callees, and the new held-editor test were re-reviewed. No broader Management feature audit was performed. No source/test files were edited and no build, tests, app/process control, unrelated dirty-tree review, evidence directory or global memory was used. This append is the only write.

### Repair source checks

- `AppManagementSettingsView.swift:147-155` captures the requested hidden value before invoking the owner. Only `.saved` advances the local accepted mirror using `preferences.settingHidden`. A rejected result leaves the mirror unchanged and restores its hidden value only if the same app remains selected. Thus success followed by a rejected inverse while catalog presentation is held no longer rolls back to pre-success preferences. `AppManagementPreferences.swift:74-83` applies the existing hide/unhide key semantics; no second persistence path is introduced.
- Successful Save and Clear now also advance the local accepted alias mirror (`AppManagementSettingsView.swift:158-174`). Save derives the visible normalized alias from that mirrored preference; Clear removes the alias and empties the field. Rejected outcomes retain the previous mirror and draft. The same-selected-AppID guards prevent writing another selection's alias field.
- `refreshCatalog` still compares the field against the **prior accepted mirror** before adopting incoming committed preferences (`:98-105`). Actual unfinished text survives passive catalog refresh for the same app, while an already-accepted field follows current committed state. The P2-R1 successful Clear/Save repair is preserved.
- Mirror mutations call only pure preference value helpers. They do not write a store, request icons, rescan a catalog or invoke a settings reload. Main's actual coordinator remains the acceptance authority: `AppManagementStore.swift:93-98` advances committed data only after `.saved`, and rejected saves do not invoke its apply callback.
- Main's original frame repair remains at `AppDelegate.swift:2274-2295`: settings reload/templates execute only on the queued main turn after epoch, teardown, weak-coordinator identity, current owner and actual field-editor checks. Data is read at execution. Readiness retry still covers pending Management presentation even with no pending locale (`:2109-2112`); teardown still invalidates the epoch and clears pending/scheduled flags (`:2145-2153`). The accepted mirror changes do not move any settings/template operation back into the synchronous catalog commit route.

### Added real-route test inspection

`LanguageRuntimeIntegrationTests.swift:410-417` accepts a store injection while retaining the same shipping `installCatalogPresentationCallbacks` and Main `configureAppManagementSettings` wiring. The new `ControllableManagementStore` at `:534-543` leaves its preferences unchanged when returning a rejected result.

`testAcceptedHiddenBaselineSurvivesRejectedInverseWhileRealAliasEditorHoldsRefresh` at `:545-584` tests accepted hidden/unhidden directions, with `.failed` and `.futureVersion(2)` inverses. It selects the actual Management tab, obtains the actual native alias field editor, clicks the real checkbox through Main's coordinator/store/provider callback route, checks accepted store/provider/checkbox values while the queue remains held, and checks editor/draft preservation. It then releases the native editor, sends the end-editing notification through the injected notification center, drains the queue and checks the final checkbox/draft. This directly covers P2-R2's previously missing pending-success sequence; it does not manually reproduce Main's three catalog callbacks.

The `.futureVersion` case is a controlled store rejection result flowing through the production coordinator and UI failure branch. It is not independent proof of fresh-process persistent future-schema byte protection. Native controls are used unshown; this source inspection is not live GUI acceptance.

### Reported execution and handoff boundary

Main reports management-frame-repair-r5 **77 tests / 0 failures**, including the held-editor accepted/rejected inverse case, and a generated `source-files-r5.sha256` 375-file snapshot. Main reports final focused/full suites running serially. This reviewer did not read execution logs or the broader manifest, did not run tests, and assumes no outcome for the running final suites or candidate packaging. Earlier candidate supersession remains as recorded above.

**Source handoff:** No open finding remains from this bounded review. Main can continue its authorized final verification/packaging pipeline; test, packaged-resource, exact-candidate GUI, restart and performance gates remain owned by Main and are not certified here.

### Accepted-mirror re-review fingerprints

These identify the bounded files read for this append, not the whole-tree/candidate snapshot.

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppManagementSettingsView.swift` | `4cdcf9c7a64324f25e05eac38b717cf233fe80d2641264e68d2445a67cc642d8` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `0d1f3061a5bdcf6cec9bd9702b465f9d90f3da249c6c6fa7229628cdb091f1cf` |
| `Sources/PagingPrototypeApp/AppManagementStore.swift` | `53bf760fb4bd44d2973de3effba13faec8af570deb69184d5bb62616f5b74222` |
| `Sources/AppGridUI/AppManagementPreferences.swift` | `9a479f644cfb3ae5e40c6918adbf2d37c5ee1b7fce88c20f14ec0cbe3030c826` |
| `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` | `f9b6ac9b752554b3066b0e0286954a8df19787e17b2bcae6a825ec1230e93f84` |
