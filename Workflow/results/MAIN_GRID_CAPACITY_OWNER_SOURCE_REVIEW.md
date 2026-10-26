# Main Grid Capacity — Independent Owner/Input Source Review R1

Date: 2026-10-17
Verdict: **SOURCE FAIL — two P2 owner integration defects.**
Scope: approved main-grid 3…8 rows/columns, default 5×7; Main-owned capacity composition and narrow input guards only. This is not a foundation/store/settings review or whole-feature acceptance.

## Authority, baseline and execution boundary

Read RTK.md, repository AGENTS.md, approved `Docs/MAIN_GRID_CAPACITY_SPEC.md`, current stage summary, configuration/state/brief, and foundation review including its superseding R2 SOURCE PASS. The human waived Chief and limited active agents to three including Main. This reviewer dispatched no agents and owns only this report. Every shell invocation used RTK. No implementation/test edits, builds, test execution, UI, process actions, reference-code access or formal-data access were performed.

The original input manifest has 467 entries. Independently verified reconstructed `AppDelegate.before.txt` SHA-256 against its original AppDelegate entry and used a direct before/current comparison to identify this task's additions. Keyboard/search review is limited to the explicitly assigned capacity/input hunks; the larger dirty Git diff includes earlier folder/direct-navigation/search work and is not treated as newly implemented capacity work.

Independently verified **all 482 frozen input hashes against current files: zero mismatches**. Independently recomputed the baseline delta: 16 modified, 15 new, zero removed; this agrees with Main's `input-delta-r1.json`. Whole-input hash verification is not a source review of every file. AppDelegate includes Main's latest visible-selection validation at lines 4704–4712; this review uses that current hash, not the earlier dispatch bytes.

Main retains sole execution ownership. Read the terminal summaries of existing R3/R4/R5 logs: R3 75 methods / 3 failed assertions; R4 75 / 0; R5 **76 / 0**, 1.262 s test duration (1.268 s outer summary). R5 log hash is recorded below. The R3 Library failures and repaired `captureGrid` fixture are preserved as fixture history, not attributed as an unresolved production defect. Earlier R1 optional-ID compilation failure/explicit enum mapping repair and R2 numeric-versus-full-text AX expectation failure are Main-reported history, not reviewer executions. No prior run is relabeled as execution of a later source hunk. Main reports a separate full-suite job in progress; this review does not wait on, execute or certify that job. Full/native/new-candidate/build/physical acceptance remains open regardless of the focused green result.

## F1 — P2: readability masking cancels the capacity transaction's own anchor navigation

**Primary location:** `Sources/PagingPrototypeApp/AppDelegate.swift:4765–4767`; transaction ordering at `:4730–4739`.

**Concrete trigger and evidence:** Use default appearance/visible labels, a 700×600 pt content viewport, more than 64 visible entries, an ordinary grid on committed page 1, and Reduce Motion disabled. At default 5×7, ordinary cell height is 480/7 = 68.57 pt and fitted folder glyph side is 28.57 pt; the search-envelope probes also fit. The existing main-grid guard therefore admits this viewport. Accept 8×8. Its ordinary cell height becomes 60 pt and fitted folder glyph side 20 pt, so the guard must protect the main grid. These numbers are direct source derivations from `AppGridGeometry` and `GridItemContentGeometry`, not executed/native measurements.

For a valid visible selection at old index 50, relocation correctly chooses new page 0, slot 50. With no selection, old page-leading index 35 likewise anchors new page 0. Reconfiguration reloads the provider and changes page count from 3 to 2, leaving committed page 1 legal. The owner calls `surface.requestPage(0)` using the existing spring and then calls `refreshMainGridReadability()`. Because readability changes true→false, that function immediately calls `surface.cancel()`.

The existing primitives make the resulting loss concrete: `PagingSurface.requestPage` forwards the direct request; with Reduce Motion disabled it remains settling. `PagingCore.cancel()` restores `visualOffset` to the still-committed page 1 and emits cancelled/idle. The production idle callback runs `reconcileSettledCrossPage`; the pending selected target on page 0 mismatches actual page 1, so it replaces index 50 with the first entry of new page 1 (index 64). With deferred focus, the wrong committed page still remains 1. Enlarging the window later does not retain or replay the original relocation. This violates the approved anchor and small-window preservation contracts even though capacity persistence and masking themselves succeed.

**Likely root cause:** The readability transition treats every active pager transition as unrelated old input, including the owner-created relocation requested immediately before the check. It discards the pending anchor/focus transaction after already clearing `pendingMainGridCapacity`.

**Recommended solution:** Coordinate the mask transition and owner relocation so protection revokes user input without cancelling/forgetting this transaction's stable target. Resolve existing input before issuing owner navigation, or retain/replay the target through protection with explicit ownership. Continue using the existing direct-page primitive; do not modify Core/physics, toggle Reduce Motion or forge catalog revisions. Main owns the repair choice.

**Affected scope / regression risks:** Apply or startup into a protected viewport when the stable target moves to another still-legal page; selected and deferred anchors, later resize/unmask, pending settlement. Existing integration `Fixture` hardcodes `reduceMotion: true` at line 40, so its synchronous navigation does not exercise this path. The small-viewport test starts from page 0 after the capacity apply. Add an owner regression with an actual nonzero-page relocation, ordinary animated navigation and true→false readability; verify correct final page/selected identity after the approved protection/unmask behavior, plus the no-selection case.

**Confidence:** High from production ordering and the existing cancellation/settlement primitives. Source-derived defect; no claim of an executed failing test or native reproduction.

## F2 — P2: main-grid readability guard disables the independent open-folder menus

**Primary location:** `Sources/PagingPrototypeApp/AppDelegate.swift:3099–3102`.

**Concrete trigger and evidence:** Apply 8×8 in a sufficiently large viewport, open a folder, then resize to a 700×600 pt content viewport. The main-grid ordinary glyph becomes 20 pt and `mainGridIsReadable` becomes false. The independent folder policy can still present members at this size (its bounded 4-column / 3-row default-appearance fit is available). Capacity presentation correctly waits while the folder stays open; that is not the defect.

`refreshFolderOverlay()` supplies folder member menus through the same `appContextMenuController` at line 1824. The new shared `isCurrent` predicate unconditionally requires `mainGridIsReadable`. `AppContextMenuController.menu(for:)` still admits these visible, current folder cells; its read-only provider now reports true, disabling alias/clear-alias/hide. Open and Reveal remain enabled by that controller's existing special case, but their callbacks both recheck the same false `isCurrent` and silently do nothing (`:3119–3121`, `:3135–3137`). Organization lookup also returns no submenu through `isCurrentAssignment`. Thus readable folder input is partly disabled by an unrelated hidden outer grid.

**Likely root cause:** A main-grid-only admission condition was added to a shared menu owner without preserving the folder consumer's separate presentation ownership.

**Recommended solution:** Validate the action's actual originating presentation. Preserve readability/epoch rejection for hidden or obsolete outer-grid bindings, while allowing live, readable current folder-member bindings under their existing revision/membership/lifecycle checks. Do not globally bypass the guard merely because any folder is open: retained hidden outer-grid menus must still reject. Main owns this narrow integration repair.

**Affected scope / regression risks:** Folder member context-menu launch/reveal and management/organization during a protected main grid. Test a readable folder with an unreadable outer grid, ordinary current folder actions, and retained hidden main-grid actions. Preserve stale menu epoch/rebind protection and independent folder transitions/layout; no broader menu redesign is requested.

**Confidence:** High from the shared provider and action callback chain. Source-derived defect; no executed/native claim.

## Other bounded review conclusions

- **Latest visible-selection hunk:** Current revision, committed page, entry identity and its old page/slot must all match before selection reaches relocation. An off-page, stale-revision or mismatched-slot identity becomes nil, preserving the visible page-leading anchor and deferred focus. The new off-page regression uses the actual owner transaction. It does not address F1's later cancellation of an otherwise valid target.
- **Capacity fan-out and stale bindings:** The main-actor synchronous transaction changes provider/refresh/search/renderer/Surface copies, reloads same-revision content, rebuilds keyboard navigation and reinstalls epoch-capturing menus. Read the actual Surface reload, renderer and page binding primitives: reload revokes generations/rebinds retained cells and page shrink retires surplus content. No concrete second fan-out/icon bug is established. The foundation R2 metrics-only hazard is addressed by an explicit reload, not by assuming shape setters alone revoke bindings. Callbacks inside existing Surface/Core primitives are synchronous; correctness still depends on their concrete behavior, as F1 demonstrates.
- **Gating/wakeups:** Readiness includes the existing language lifecycle gate plus capacity guards: actual gesture/settle/pin/direct navigation, held pointer/drag, folder/open/entrance/retained exit, Library ownership, title/alias/search editor, marked text, settings recording/source dialog, native modal, restore and Quit. The additional test check only restricts readiness. Existing drag `isSessionActive` includes raw pointer ownership and click-only presses. Deferred retries resolve the current pending value and coordinator identity. Read the shared idle, folder close/transition completion, drag release, native text/menu/sheet notifications, modal release, Library readiness and Quit phase retry chains; no polling loop or added per-frame capacity rebind was found. This is source reasoning, not native wakeup acceptance.
- **Query and fixtures:** Capacity code neither updates/clears the query nor increments search generation. It relocates against current visible entries. The first integration test checks query generation without creating a nonempty query; it does not by itself prove nonempty editor selection/IME preservation. The repaired Library fixture injects only the existing ephemeral capture seam because it owns no shown window, preserving production `canTransition` and capacity readiness. Its synthetic store is explicitly isolated; it is not restart/storage/native evidence.
- **Quit/ownership:** Capacity is included in admission, always drained even after another owner's failure, and checked by current coordinator identity before the reply result. Settings Apply is denied while Quit is pending. Replacement refuses to discard an owner with pending/failed accepted writes; stale callbacks check coordinator identity and teardown; teardown invalidates presentation/cancels loading without cancelling accepted writes. The capacity-only failure/cancel/retry fixture exercises the actual owner method with injected replies. No additional concrete owner-drain bug was found. Timeout, delayed writes across owners, native Quit/restart and failure dialogs still need their execution evidence.
- **Protection:** Surface hiding masks the grid hierarchy; top-level keyboard/activation/search-transfer/page-dot guards and window scroll suppression protect normal input. Scroll continuations remain suppressed until a fresh sequence; folder and Library routes precede the outer scroll guard. Settings chrome remains outside the hidden grid. Native AX enumeration, focus restoration, retained actions and actual chrome/safe-area geometry are separate acceptance gates, not source PASS claims. F2 is a concrete independence regression within these hooks.

## Remaining acceptance gates, not extra code findings

Main must retain and repair F1/F2, obtain a superseding bounded source review of changed inputs, and run suitable current-source regressions under its serial execution ownership. Preserve the current source/test hashes and existing failed logs. This reviewer does not authorize global Core/physics changes.

Full current-source nonzero suite, Debug/Release, package/localization verification, candidate hashes and isolated native default/endpoints/protected viewport/Library/folder/restart/Quit verification remain required by the approved specification. Match native evidence to the repaired source/candidate; do not infer full/native PASS from 76 focused methods, this source review, old candidates or the separately running job. Physical trackpad/IME/VoiceOver, memory/energy/120 Hz and previous performance claims retain their distinct evidence boundaries.

## Frozen inputs

The supplied integrated manifest fingerprints the entire 482-input set; the hashes below make the bounded owner/test and relevant dependency boundary explicit. Dependencies are inspected existing primitives, not newly approved implementations. Any changed relevant source/test input requires an explicit superseding review.

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `a44817297fe7d54b94ed082795623d334d50d43a56d3774db027f5284d0c9cc6` |
| `Sources/PagingPrototypeApp/KeyboardFocusController.swift` | `14cbac965f3d19f1ee7ec17f93e975223fe57d869f72bc9c8996c20fe9f568c0` |
| `Sources/PagingPrototypeApp/AppSearchController.swift` | `a6dae4788fed360881071ca87bf59f26c499456aa59277dc617b9fe39f54cc6c` |
| `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift` | `944c79c380dbd44fb1680c220bcdec0a76f7f1efe8a8bc0edfcfd8d16ecc0ff4` |
| `Sources/PagingUI/PagingSurface.swift` | `0197dce825a7c381373b0dc25e1df818f904e5398458aa5789749f322d416409` |
| `Sources/PagingCore/PagingCore.swift` | `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `3647b449bc573f607ab369f3864c0f00a0f9ebf4afaee7c0d3c7f081ca7ea862` |
| `Sources/AppGridUI/AppGridPageView.swift` | `d33b150ac68a19c9ddac42ea7214a746ccd329adeb9c1f092b698bcf51a61037` |
| `Sources/AppGridUI/AppGridCellView.swift` | `eb38dce836c0214fd6a29ccf4f8fa4c1946e1cd5cc8ac61104c24b9d5339195a` |
| `Sources/AppGridUI/MainGridCapacity.swift` | `96d6912ad8693398331ec3dddd247fa2bbdbaf580afb7df79674a9a209016d09` |
| `Sources/AppGridUI/MainGridReadability.swift` | `c695948502be5e1acf811ab0f2bd2668e2a2fbb66ae48843e807241138e73726` |
| `Sources/AppGridUI/AppGridGeometry.swift` | `463ab9ef172a7fdcb6058954ba055d6f820a0ed6b0b216df068b1454839bf01d` |
| `Sources/AppGridUI/GridItemAppearance.swift` | `75f831d583be163d98f3dc306bdd34d1bf04a7da17b4b51ec3ac368674aeb8d4` |
| `Sources/AppGridUI/FolderLayoutPolicy.swift` | `ef7504675386db2041a411265129486130eb26b06985e7d699718bfd4a79093d` |
| `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` | `b0a4afcda45e90d3f0975866c035d7deed8d3885001c3624b86ae2f5f5ddc193` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `f957e866759f24584d5c31b02dbec9cf445eeb69a4cc8fcf24c6ad88a16d0070` |
| `Sources/PagingPrototypeApp/LanguagePresentationController.swift` | `dda8a9477968803458a2b22de91a79cb5d1d61279eb8959be1497d8583894ca1` |
| `Sources/PagingPrototypeApp/LanguageRuntimeObservers.swift` | `c4b71b0bd6a748c369a5bee350854305f1b6b2763c2e7d7e7d78962a16b1d0b1` |
| `Sources/PagingPrototypeApp/WorkspaceQuitCoordinator.swift` | `2f70b22650cd05257fb9f2087bb213240c6dd043b55a2581cfe2c1b9cf4054f7` |
| `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift` | `34b90c4e0d077489e46a7fd670bb66ae99ce54247c677e9c0711241dd53e502b` |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `c64edd0fb3c6e272769737878e16c05e77884038e89cbbbcefa53decc501dd58` |
| `Docs/MAIN_GRID_CAPACITY_SPEC.md` | `e2b93a44dc5ef0be2296e05d03512f17ef7121d63705810058a0c7fb07e05ebe` |
| `AGENTS.md` | `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc` |
| `Workflow/stage-summaries/2026-10-17-main-grid-capacity.md` | `189acdbc58b76c78a57667e1fff2f00a9e292704b87b971b975d2a7c5a0d23f0` |
| `Workflow/results/MAIN_GRID_CAPACITY_FOUNDATION_SOURCE_REVIEW.md` | `152113d22ab878717ddd49da8ce473a04458288c5e7d728d1745434cf762143c` |
| `.build/verification/20261017/main-grid-capacity/source-before.json` | `af130f9a2ec5243f5cd90a8d04cfddb4a401507185b291eafdf1f984dc842b68` |
| `.build/verification/20261017/main-grid-capacity/AppDelegate.before.txt` | `70ab9a284887c7ffcceba40ec8492d83308789854cd7bb051216ad96bd085a30` |
| `.build/verification/20261017/main-grid-capacity/source-inputs-integrated-r1.json` | `0f7d4fad77d9a36679530a454ab6b7ab99610e47192268a90c0a88b35ff40a34` |
| `.build/verification/20261017/main-grid-capacity/input-delta-r1.json` | `1210f69f4321e6ebbbcb293f89661f8ceeef2ca84e9961780e0e08855b31d766` |
| `.build/verification/20261017/main-grid-capacity/integrated-focused-r5.log` | `78fbde018403f52f0bad97e6fadfdd472e53c74e68d381c45262a010033dd45e` |

## Change disclosure and next action

Reviewer wrote only `Workflow/results/MAIN_GRID_CAPACITY_OWNER_SOURCE_REVIEW.md`. No other project files were written. Main should route the two concrete P2 findings through the human-waived-Chief workflow, preserve this R1 verdict, and append an explicit repair review with fresh hashes. Focused/full results remain execution gates independent of this source FAIL.


---

## R1 evidence addendum — resource fixture and completed execution, 2026-10-17

**Source verdict unchanged: SOURCE FAIL, F1 and F2 remain open.** This is an evidence/fixture update, not a repair review or a new production PASS. The complete original R1 text and manifest above are preserved byte-for-byte. Its pre-append report SHA-256 was `71fd0f270b73e45cf06eae68f9d7c5eeb7c913c84eaf4642e562a64932d0ffd8`.

### Current source and new test boundary

Rechecked all 482 entries against `source-inputs-integrated-r1.json`: **481 unchanged; only `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift` differs**. All frozen production inputs, including AppDelegate's visible-selection validation, remain unchanged. The original 482-entry freeze is still the input set for full R1; it is not silently rewritten to cover this later test.

Reviewed the latest integration test source. `Fixture.init(itemCount: Int = 80)` at line 37 preserves the default 80-record case; record creation uses this count at line 59. The new `testMaximumCapacityLiveSlotEnvelopeAndTransactionRequestCensus` at lines 309–329 requests 640 synthetic records, navigates to old page 8, and applies 8×8 through the real owner path with the existing in-memory store. It expects relocation to page 4, 10 pages overall, seven renderer page instances and 448 cells, each with the committed 64-item shape. The request counter must increase; the test prints the actual delta and elapsed time instead of asserting a one-pass request count or a performance threshold.

These are bounded fixture counters: `pageView(forPage:)` returns the renderer's page map. The test labels the seven renderer instances `hosts` in output; it does not independently assert Surface host attachment or enumerate native views. Elapsed time wraps `f.apply`, including the synthetic persistence receipt/drain, scheduling and owner presentation, so it is not an isolated synchronous transaction cost or a physical frame-time measurement. It retains `reduceMotion: true`; it neither covers nor closes F1. It does not exercise folder context-menu provenance or close F2. No additional concrete production defect is raised from this new fixture.

### Execution evidence read, not executed by Reviewer

Read terminal summaries in Main's existing logs:

- `full-r1.log`: **2893 tests / 0 failures**, 71.355 s test duration (71.611 s outer summary), terminal All tests passed. This execution belongs to the original 482-entry freeze, before the resource test was added. It supersedes R1's earlier in-progress full-suite status for that input set only.
- `owner-resource-r1.log`: **13 integration methods / 0 failures**, 1.076 s test duration (1.079 s outer summary), terminal Selected tests passed. The census line reports `hosts=7 slots=448 icon-requests-delta=576 transaction=0.108191667 seconds`. This includes the new resource test and is separate from the earlier full run. The observed request delta 576 is greater than retained slots 448; no 448-request limit is inferred.

Both are saved Main execution evidence. This reviewer ran **zero tests/builds/UI/process actions**. There is no RSS, whole-process memory, global queue, lifetime request, physical gesture, native AX, frame-hitch, energy or 120 Hz claim. Main states a final full suite will run after reviews; that later result remains pending and must be associated with its own current test/source freeze. A green full suite does not erase either concrete source finding.

### Latest evidence hashes

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `a44817297fe7d54b94ed082795623d334d50d43a56d3774db027f5284d0c9cc6` |
| `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift` | `bdad35aef767093d176b145281936b555d229d6918250b781a4dc50951645b2f` |
| `.build/verification/20261017/main-grid-capacity/source-inputs-integrated-r1.json` | `0f7d4fad77d9a36679530a454ab6b7ab99610e47192268a90c0a88b35ff40a34` |
| `.build/verification/20261017/main-grid-capacity/full-r1.log` | `be5d0b1f994d23c82b08fa7c8a2ac485c431922932f114e630b43619b1eba1cc` |
| `.build/verification/20261017/main-grid-capacity/owner-resource-r1.log` | `825a161d5191c5dbe4fbcf6c8c8470ace35894ae0ca8bef3bb78c96588f76032` |

Changed by Reviewer: appended only this addendum to `Workflow/results/MAIN_GRID_CAPACITY_OWNER_SOURCE_REVIEW.md`. Main retains implementation, execution and routing ownership. Repair F1/F2 and obtain an explicit superseding review before treating the owner integration as SOURCE PASS.


---

## R2 — F1/F2 repair and menu-origin review, 2026-10-17

**Current verdict: SOURCE FAIL — F1 and F2 are closed at the hashes below; one remaining P2 finding F3 in the new owner origin predicate.** R1 FAIL and the resource evidence addendum remain preserved exactly. This section supersedes the current finding disposition only. It does not convert earlier execution into evidence for later changes, and does not issue whole-feature/native/physical acceptance.

### Scope, baseline and unchanged inputs

The human explicitly extended this read-only review to the optional `bindingIsAvailable` hooks in `AppContextMenuController` and `AppFolderAssignmentMenuController`, the owner's origin predicate, the new F1/F2/search regressions, and the small synthetic fixture mount correction in `FolderAssignmentAssemblyTests`. Reviewer still owns only this report and ran zero tests/builds/UI/process actions. All shell calls used RTK; no agents were created.

Independently verified all three `*.owner-r1-before.txt` copies against their original integrated-R1 source-manifest entries. Compared those copies directly with current production; the reviewed production delta is exactly the repair ordering, optional menu hooks and owner predicate. Rechecked the 482-entry integrated-R1 manifest: **477 entries unchanged, three changed production files and two changed test files**, listed below. In particular Core, Surface, keyboard/search production, domain/store/coordinator and geometry remain unchanged. The pre-R2 report SHA-256 was `d2348e67ff4ef1cc4eb283acea08429fbb3ae8d5536fdb56d2dde84c4018601f`.

### F1 closed — mask before the owner creates navigation

`AppDelegate.swift:4733–4735` now refreshes readability immediately after capacity copies and same-revision content reload, before `reconfigureGrid` and `requestPage`. A true→false transition can revoke old input at this point, while the stable relocation is still captured locally and the keyboard's new pending target has not yet been installed. The owner then installs that target and issues the existing direct-page request. The former second readability call after `requestPage` is removed. Subsequent refreshes with an already false mask do not cancel the new spring. The independent `isApplyingMainGridCapacity` guard remains set across this sequence; no Core/physics or Reduce Motion production changes were made.

The new `testProtectionDoesNotCancelAnimatedCapacityAnchorOrLoseSelection` now at integration-test lines 352–377 runs both deferred and selected cases, starts at real page 1 in a readable 700×600 pt viewport, disables Reduce Motion for the capacity relocation, settles the actual spring while masked, and checks page 0/identity retention again after unmask. It uses the actual owner path rather than replacing readiness or navigation. This addresses R1's concrete cancellation chain.

### F2 closed — validate the actual cell's presentation

The shared owner epoch predicate no longer requires global main-grid readability. Main installs a cell-specific hook on both menu owners. `AppContextMenuController` calls it at menu creation and again before action dispatch; `AppFolderAssignmentMenuController` calls it at creation, action dispatch, and inside its existing `validate` closure's `isCurrent` path, preserving checks during synchronous owner mutation/cancellation callbacks. Nil leaves standalone consumers' previous behavior intact. Existing token/revision/URL/hidden/layout/store and owner-epoch validation remains in place.

The folder branch of `mainGridMenuBindingIsAvailable` checks actual overlay ancestry, open state, non-visual-only/noncollapsed state, no entrance/retained exit, matching current folder identity and membership. Thus a readable current folder can remain live while the outer grid is masked, without a global any-folder bypass for outer cells. Closing/removing the overlay or its membership rejects the retained cell. The outer branch rejects masked main input and all outer cells while a folder is open. These conditions close the exact F2 failure; its remaining current-page omission is separately F3 below.

`testReadableFolderMenuRemainsLiveWhileRetainedProtectedOuterMenuRejects`, now lines 379–413, uses actual rendered cells, the production menu provider, a retained outer menu and a live folder member menu, plus only the existing file-existence/reveal platform seams. It checks protected outer Reveal rejection, live folder Reveal, and rejection after folder close. No OS window is ordered and no real app/file action is executed by the fixture seam.

### F3 — P2: new main-origin validation still admits an attached off-page cell

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:4802–4803`.

**Evidence and concrete trigger:** The new outer branch accepts any nonhidden cell descended from the Surface when the grid is readable and no folder is open. It does not check the cell token's page against `surface.core.committedPage` or resolve the originating cell to that current page. Surface deliberately keeps adjacent pages attached for prewarming; their views are translated outside the viewport, not marked hidden. `isHiddenOrHasHiddenAncestor` therefore does not distinguish them from the displayed page.

With the existing 80-entry/default-capacity fixture, retain a menu for a current page-0 cell, then request page 1 using the existing Reduce Motion path. All three pages remain within the live radius, so the page-0 host and cell remain attached with the same token. Ordinary page navigation does not increment `mainGridLayoutEpoch`, and an unchanged live range does not rebind that old cell. Invoking the retained menu afterward passes the new hook: readable, no folder, still a Surface descendant. The general menu controller checks equality to the retained token/revision/URL but never compares that token's page to the committed page, so Reveal/Launch and permitted mutations still dispatch from the now off-page origin. The assignment hook has the same gap because it shares this predicate.

This falls short of the stated current-visible-main origin contract and retained-old-input protection. It is not a claim that an off-page cell can be clicked through native hit testing, nor a new requirement to change the pager's prewarm policy. It is the same retained-action boundary that the new hooks are intended to enforce.

**Likely root cause:** Conflating attached-to-Surface and not explicitly hidden with currently presented page ownership.

**Recommended solution:** In the outer branch, validate current committed-page ownership from the actual binding/rendered source in addition to ancestry/readability/no-folder admission. Recheck this at both menu creation and action time through the existing hooks. Preserve folder independence and existing epochs/token/layout checks; do not change Core/physics or hide/remove prewarmed pages. Keep synthetic transaction fixtures explicit about the source they represent rather than adding a production admission bypass.

**Affected scope / regression risks:** Retained general/organization menus on still-live adjacent pages after a normal page turn; both synchronous Reduce Motion and settled animated navigation. Add a targeted owner test retaining page-0 Reveal/assignment, navigating to page 1 with unchanged capacity/revision and retained page-0 bindings, then verifying old-action rejection while a current-page menu still works. Verify returning to a genuinely current valid origin according to the accepted policy, and retain the masked-outer/live-folder/closed-folder regression.

**Confidence:** High from the current predicate and the unchanged Surface live-range/renderer binding primitives. Source-derived finding; Reviewer did not execute a reproduction of F3. No additional finding is inferred from the earlier fixture failures.

### Additional fixture and query review

`FolderAssignmentAssemblyTests.swift:91–93` adds two explanatory comment lines and mounts each synthetic cell under the actual Surface. The helper still uses its existing synthetic binding and transaction machinery. This supplies the newly required ancestry without weakening production gates, removing mutation validation or substituting a ready result. It restores that transaction fixture's intended scope; a directly mounted synthetic cell is not proof of real current-page provenance or F3 coverage.

The latest added query method at integration-test lines 135–154 covers synthetic same-count, filtered and zero-result queries. It asserts field text/current query, search generation, current visible sequence and canonical catalog IDs survive a 3×3 owner apply, with coherent page count and deferred focus. It closes R1's identified nonempty-query fixture gap at that scope. It does not create an actual field editor, text selection or IME composition, so those native gates remain separate.

### Main execution evidence — Reviewer did not run it

Read the saved terminal logs; preserve the red and intermediate failed attempts:

- `owner-review-red-r1.log`: two new methods / eight failed assertions, reproducing F1's page/selection loss and F2's missing live-folder Reveal. These are actual Main failures rather than merely the original source derivation.
- `owner-review-repair-r1.log`: 52 methods / five failures; the 15 owner integration methods passed. All five failures occur at the existing organization fixture's menu unwrap for detached synthetic cells. Source inspection of that helper confirms the missing ancestry. This failed attempt is not relabeled green.
- `integrated-focused-r6.log`: 116 methods / zero failures, 2.560 s test duration (2.570 s outer summary), after the fixture mount correction. It includes the repair/menu/assignment coverage, before the later query method.
- `owner-query-r1.log`: 16 owner integration methods / zero failures, 1.359 s test duration (1.361 s outer summary), including the latest query method. This is separate from R6.

The earlier full R1 2893/0 and resource census remain historical evidence for their earlier input boundaries. These logs support closure of F1/F2 but do not exercise F3. Final current-source full/Debug/Release/package/localization/native verification remains Main-owned and pending; green focused execution alone does not override this remaining SOURCE FAIL. Resource outputs remain synthetic counters/timing, with no one-pass request, global queue/RSS, memory/energy/physical/120 Hz claim.

### R2 frozen source/test/evidence hashes

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `5d5bdebf41e8f3258fbe3f963c580b8e5e03bb4d21495e9ab99dc47b3fafad35` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `58694944275922d2c3d32e6d38debb46853f405714a0d61f746f4320b4f7d518` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `491937d5568f1791d038ca18a5a3e8a8400766ba4fa2257c57a1fb032f50223b` |
| `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift` | `da71c302138fb3ec012d996f6e5c4bb1194bf6d4f4c66a84097a69de86686e3a` |
| `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift` | `615687124539f9fc8f83e7a5ee84f97320d14e9d6462da12d53e2653046e04c1` |
| `Sources/PagingUI/PagingSurface.swift` | `0197dce825a7c381373b0dc25e1df818f904e5398458aa5789749f322d416409` |
| `Sources/PagingCore/PagingCore.swift` | `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `3647b449bc573f607ab369f3864c0f00a0f9ebf4afaee7c0d3c7f081ca7ea862` |
| `.build/verification/20261017/main-grid-capacity/AppDelegate.owner-r1-before.txt` | `a44817297fe7d54b94ed082795623d334d50d43a56d3774db027f5284d0c9cc6` |
| `.build/verification/20261017/main-grid-capacity/AppContextMenuController.owner-r1-before.txt` | `f957e866759f24584d5c31b02dbec9cf445eeb69a4cc8fcf24c6ad88a16d0070` |
| `.build/verification/20261017/main-grid-capacity/AppFolderAssignmentMenuController.owner-r1-before.txt` | `d51e93da472b3412dd24749c85b9436e98a375f33061077a4498baa46b9c5942` |
| `.build/verification/20261017/main-grid-capacity/owner-review-red-r1.log` | `9156da50f400f1c856dbba1fb23599a6e8446f798e72f02a7876b28d39972529` |
| `.build/verification/20261017/main-grid-capacity/owner-review-repair-r1.log` | `46ab5dca9d77fb8cfcfd71cf49f5a18fa96a6ebb71b7079ffabb230d2f884ce8` |
| `.build/verification/20261017/main-grid-capacity/integrated-focused-r6.log` | `4ac2d57fc24bc3f271325dcb23471c4cdf5013439c7e4265873216f31851663c` |
| `.build/verification/20261017/main-grid-capacity/owner-query-r1.log` | `c551b81c13b609962369488567c2808228f2c2b2e2e1acecd36298b998ae80e5` |

R2 change disclosure: appended only this section to `Workflow/results/MAIN_GRID_CAPACITY_OWNER_SOURCE_REVIEW.md`; all previous report bytes preserved. Next action: Main resolves F3 inside the bounded origin-validation scope, preserves these attempts, and returns fresh hashes for a superseding source review. No architecture/Core/physics change is authorized by this recommendation.


### R2 final-freeze acknowledgement — 2026-10-17

**R2 SOURCE FAIL confirmed on the supplied integrated-R2 freeze: F1 closed, F2 closed, F3 P2 open.** All 482 frozen hashes match current files. Independently recomputed the original-467 delta: 19 existing inputs changed, 15 new inputs, zero removed, matching `input-delta-r2.json`. All five repaired production/test hashes listed in R2 above are unchanged. The main-origin predicate still ends with readability/no-open-folder/Surface-ancestry checks at AppDelegate lines 4802–4803 and has no current committed-page check; F3 therefore remains applicable to this exact freeze.

| Freeze artifact | SHA-256 |
| --- | --- |
| `.build/verification/20261017/main-grid-capacity/source-inputs-integrated-r2.json` | `e96c4cb857781a5e706ee34c1635a26cc720df924915f842adb227516a251135` |
| `.build/verification/20261017/main-grid-capacity/input-delta-r2.json` | `a6cb17805d4fc0c810e4c9bd04af1034cc54da3ac6b3970f454e17dbf37a0ecd` |

Main reports final full-suite/Debug/Release-package work is serialized and running, with intended candidate name `main-grid-capacity-rc-20261017-r1`. These are pending Main executions/intended output, not observed completion, build success or a verified candidate hash in this acknowledgement. No new execution is inferred or performed. The saved owner-query 16/0 at 1.359 s remains separately recorded above. Only this report was appended; all preceding bytes preserved.


---

## R3 — F3 repair, existing fixture adaptations and final source freeze, 2026-10-17

**Current verdict: SOURCE PASS for the bounded Main-owned capacity owner/input integration and the two optional menu validation hooks, at the hashes below. F1, F2 and F3 are closed; no remaining actionable production finding in this reviewed scope.** This supersedes the current R1/R2 SOURCE FAIL verdict only. All historical FAIL findings, hashes, red runs, intermediate failures and evidence boundaries remain above unchanged. This is not whole-feature acceptance, a native PASS, or a claim that final full/build/package execution has finished.

### Scope and independent source comparison

The human authorized this review of the actual final F3 guard, two added F3 regressions and the two existing fixture adaptations. Reviewer owns only this report; no production/test edits, tests, builds, UI, process actions, agents or reference-code access. All shell calls used RTK. The pre-append report SHA-256 was `d6b4064d247f2b2fa8d0fe26dcb4b594c6a6b714660c5c79434bc05275dc90be`.

Independently matched **all 482 current inputs** to `source-inputs-integrated-r3.json`, with zero mismatches. Independently recomputed the original-467 baseline delta: **20 modified, 15 new, zero removed**, agreeing with `input-delta-r3.json`. Compared with integrated R2, precisely three input files differ: AppDelegate, MainGridCapacityIntegrationTests and MenuMutationLifecycleTests; the other 479 entries are unchanged. The menu hook implementations, synthetic organization-cell mount, keyboard/search, domain/store/coordinator, geometry and Surface/Core bytes remain those already reviewed. Core is unchanged from the original baseline.

As an independent hunk-isolation check, replacing only the final F3 predicate block in memory with its pre-F3 R2 branch reconstructs AppDelegate hash `5d5bdebf41e8f3258fbe3f963c580b8e5e03bb4d21495e9ab99dc47b3fafad35` exactly. No file was changed for this comparison. F1's repaired mask-before-owned-navigation ordering and F2's independent folder branch/menu hooks therefore remain intact.

### F3 closed — current page/revision without changing the existing cancellation contract

The **final reviewed** outer-origin branch at `AppDelegate.swift:4802–4807` requires a readable main grid, no open folder, a present non-torn-down Surface, actual cell ancestry under that Surface, a binding token whose page equals `core.committedPage`, and token catalog revision equal to the currently served revision. General menu and assignment consumers recheck this same predicate at creation and action time, and assignment's existing post-cancellation validation still calls its `isCurrent` closure with token equality/layout/record/owner checks.

A retained page-0 cell still mounted as a page-1 prewarm neighbor now fails the explicit page comparison, even with an unchanged token, revision and capacity epoch. A live page-1 cell passes. Returning to the same unchanged valid page-0 origin is admitted again by the intended policy. A revision change rejects the old origin independently of whether its view remains mounted. Detached cells, an obsolete Surface, masked outer input and outer cells behind an open folder continue to reject. The folder branch is byte-unchanged from R2 and retains independent live-overlay/folder-membership admission while the outer grid is masked. There is no any-folder bypass for outer cells and no Core/physics/prewarm-visibility change.

The final branch deliberately **does not contain** the intermediate `idle/cancelled`, `no pinned presentation` or `no direct navigation` restrictions. Those extra conditions overrestricted the established current-page assignment contract: a valid action during settlement may enter the owner's existing cancellation and revalidation path. `applyFolderAssignment` still validates before mutation, cancels via the existing Surface primitive, then revalidates binding, revision, layout, hidden state and record URL before its single commit. Preserving that path does not reopen F3: once a different page is committed, the explicit current-page comparison fails. The old cancellation/rebinding regression remains unchanged; no production bypass or weakened assertion was used to make it pass.

### Reviewed tests and fixture adaptations

- `MainGridCapacityIntegrationTests.swift:415–444` retains actual page-0 Reveal menus for both Reduce Motion and animated navigation. It proves the old cell remains a Surface descendant with the identical token after reaching page 1, requires old-action rejection, checks the current-page action and checks valid return-to-origin behavior. This exercises F3's exact retained-prewarm-cell trigger rather than teardown/rebind rejection.
- `:446–462` retains the actual organization submenu before a page turn, invokes its assignment while off-page, and requires unchanged persistent layout plus no workspace-save admission. The general and assignment hooks both use the repaired owner predicate.
- The existing `FolderAssignmentAssemblyTests` adaptation at lines 91–93 only comments and mounts its synthetic transaction cell under the Surface. Its hash remains exactly the R2 value. In particular `testActualMenuRejectsSameRevisionRenderedCellRebindingDuringCancellation` is unchanged; its final passing result is not obtained by removing the token-rebinding assertion.
- `MenuMutationLifecycleTests` changes the fixture's Surface property from `let` to `var` and, on root replacement, builds and mounts a new live Surface with the same assembly/provider before evaluating fresh actions. Old root removal permanently tears down the old Surface; reusing its cells cannot establish a fresh-menu acceptance case. The fixture still retains old menu/target rejection assertions and verifies fresh alias/clear actions. Reversing only this helper/property adaptation in memory reconstructs the integrated-R2 test hash `e70d16ab010e37d225d466f32f9c88dd3d89336df2ef55a662169ad33554e0d2`. No production exception was added.
- Removing only the two new F3 methods in memory reconstructs integration-test hash `da71c302138fb3ec012d996f6e5c4bb1194bf6d4f4c66a84097a69de86686e3a`. The previous F1/F2/query/deferred-selection/resource tests remain unchanged at this boundary.

### Actual saved Main executions and failed attempts

Reviewer read these logs but executed none of them:

1. `full-r2.log`: **2897 tests / one failure**, 74.180 s test duration (74.478 s outer summary). The only failure is the existing fresh-root lifecycle menu unwrap. This remains a failed full run. Main explicitly reports Debug/package were not executed because this serialized sequence stopped at that failure; no old build/candidate is relabeled as the new release.
2. `owner-f3-red-r1.log`: the two new F3 methods have **eight failed assertions** before the production guard; the overall selection is **15 methods / eight failures**, with 13 MenuMutationLifecycle methods passing after the fixture repair. Reveal replay and actual workspace mutation support F3's original source finding. Preserve this red evidence.
3. `integrated-focused-r7.log`: **132 methods / one failure**, 4.110 s test duration (4.119 s outer summary). The intermediate overrestrictive phase/pin/direct-navigation predicate prevents the old cancellation/rebinding fixture from reaching its expected binding change; the 18 capacity methods and 13 lifecycle methods passed. This attempt is preserved, not silently relabeled green. Main removed only those extra production restrictions afterward.
4. `integrated-focused-r8.log`: **132 methods / zero failures**, 3.678 s test duration (3.687 s outer summary), terminal Selected tests passed, on the final predicate with the unchanged old cancellation test. The raw log contains no `warning:` or `error:` markers. This is focused execution evidence supporting the reviewed repairs, not final full/build/native acceptance.

Earlier resource census remains bounded synthetic renderer/request/timing evidence. Different run timings do not establish a fixed latency budget or physical performance, and no 448 lifetime/one-pass request limit, RSS/global queue/whole-process memory, energy, physical input or 120 Hz claim is made.

### R3 frozen hashes

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `24d49f4cfa883f5a90cdb28ac98da920adedf807434e8dfe5c8756f1271db367` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `58694944275922d2c3d32e6d38debb46853f405714a0d61f746f4320b4f7d518` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `491937d5568f1791d038ca18a5a3e8a8400766ba4fa2257c57a1fb032f50223b` |
| `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift` | `2fb5f8d09733baa12f75880eaee3c51ebe001da7fc093643115464c4b02c8fce` |
| `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift` | `615687124539f9fc8f83e7a5ee84f97320d14e9d6462da12d53e2653046e04c1` |
| `Tests/PagingUITests/MenuMutationLifecycleTests.swift` | `2fe815c4932538877442bf769082d15dae578222db8162a017b7bd7e6af30b5b` |
| `Sources/PagingUI/PagingSurface.swift` | `0197dce825a7c381373b0dc25e1df818f904e5398458aa5789749f322d416409` |
| `Sources/PagingCore/PagingCore.swift` | `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369` |
| `Sources/PagingPrototypeApp/KeyboardFocusController.swift` | `14cbac965f3d19f1ee7ec17f93e975223fe57d869f72bc9c8996c20fe9f568c0` |
| `Sources/PagingPrototypeApp/AppSearchController.swift` | `a6dae4788fed360881071ca87bf59f26c499456aa59277dc617b9fe39f54cc6c` |
| `Docs/MAIN_GRID_CAPACITY_SPEC.md` | `e2b93a44dc5ef0be2296e05d03512f17ef7121d63705810058a0c7fb07e05ebe` |
| `.build/verification/20261017/main-grid-capacity/source-inputs-integrated-r3.json` | `dc955fead19129359ce54f1b1f517ad58ee3c7d07722624dcb1e44b548d922e7` |
| `.build/verification/20261017/main-grid-capacity/input-delta-r3.json` | `469090c2dde03bc091058b69c81a00c50037ce1cf572c6482570f9be731b8ea4` |
| `.build/verification/20261017/main-grid-capacity/full-r2.log` | `549911f036ef673c4726043f05bddc0482f556062d23ede00f90ca96daa9d7b1` |
| `.build/verification/20261017/main-grid-capacity/owner-f3-red-r1.log` | `687987f1813be6e8ded295feb6712122732193cdf8102cfc66e493c499babefd` |
| `.build/verification/20261017/main-grid-capacity/integrated-focused-r7.log` | `a63f05b4c2ca03e3bbd8dc088104f102f36b5b42dc261aef4d814aeff256b532` |
| `.build/verification/20261017/main-grid-capacity/integrated-focused-r8.log` | `04a7cfdedf24691d489859cc2072dcaacfbfa7b5fc31e339225fd3fd19bd6f69` |

### Remaining delivery gates and change disclosure

Main reports final full R3 / Debug / actual Release packaging are serialized and running after this freeze. This reviewer neither executes nor infers those results. Main must record their terminal results and nonzero counts, candidate hashes and localization/package checks, then verify the current candidate natively in an isolated profile at default/endpoints/protected viewports, with independent folder/Library, Quit/restart and input/AX evidence. `main-grid-capacity-rc-20261017-r1` remains an intended candidate name here, not a verified binary. User physical/IME/VoiceOver/performance acceptance retains its separate boundary. Source PASS does not establish whole-feature completion or supersede other reviewers' assigned scopes.

This verdict applies only to the frozen reviewed bytes. Material source/test changes require an explicit superseding review; a later green execution does not silently extend this source scope. R3 Reviewer change: appended only this section to `Workflow/results/MAIN_GRID_CAPACITY_OWNER_SOURCE_REVIEW.md`; all earlier report bytes remain unchanged.


---

## R4 — Native idle-offset counterexample and bounded owner repair, 2026-10-17

**Verdict: SOURCE PASS for the new idle-offset normalization hunk and regression test, continuing R3's bounded owner/input/menu source scope. No remaining actionable production finding was identified in this reviewed delta.** F1/F2/F3 remain closed at their retained/current source boundary. R3 is preserved as historical source review; its PASS was not native acceptance and did not establish correct visible origin for this previously untested page-count collapse. The old r1 candidate's native failure remains real and unaccepted. This R4 source verdict does not certify a repaired native candidate.

### Scope, provenance and exact delta

The human explicitly authorized review only of the new owner normalization hunk, new regression test and supplied native/error artifacts, with append-only ownership of this report. All shell calls used RTK. Reviewer ran zero tests/builds/UI/process actions, created no agents and changed no implementation/test files. The pre-R4 report SHA-256 was `deae69ef2a00e784e708c6b29236daa6cb01840fcce8dadd2db12d8acb031ac1`.

Rechecked all 482 integrated-R3 manifest entries: **480 unchanged; precisely AppDelegate and MainGridCapacityIntegrationTests changed**. In-memory removal of the new normalization block reconstructs R3 AppDelegate hash `24d49f4cfa883f5a90cdb28ac98da920adedf807434e8dfe5c8756f1271db367` exactly; removal of only the new final test reconstructs R3 integration-test hash `2fb5f8d09733baa12f75880eaee3c51ebe001da7fc093643115464c4b02c8fce`. No files were edited for those comparisons. Existing masking/navigation ordering, menu-origin hooks and predicates, selection/query handling, both existing fixture adaptations and all other R3 production inputs are unchanged. Surface and Core hashes remain unchanged, including Core against the original baseline. This is an exact-delta review, not certification of arbitrary dirty Git changes.

### Preserved native failure and actual RED evidence

Read `.build/verification/20261017/main-grid-capacity/native-r1-checkpoint.json`. It identifies candidate `main-grid-capacity-rc-20261017-r1/LaunchcopyUITest.app`, executable SHA-256 `2083e8958fcfcc0eef5ab812c1238566d8071d9a0ea39789137e5c9dc4d55da4`, reported native PID 4819, and verdict `FAIL_MAXIMUM_ENDPOINT_VISUAL_OFFSET` with `full_native_acceptance: false`. Main reports two fresh CUA screenshots confirming a partly off-left grid and blank right region after 3×3 page 2 → 8×8 with one resulting page. This reviewer reads the saved checkpoint and attributed report; it does not perform UI or independently inspect/reproduce the screenshots.

The same checkpoint records Chinese settings/default/3×3/dots/folder subcase observations. Those remain attributed partial native evidence, not a whole-feature/native PASS. It explicitly leaves small-window/restart/languages/Library checks not yet run and wallpaper unfixed. No previous candidate is relabeled as the repaired candidate.

Read terminal `native-offset-red-r1.log`: **one new method / two failed assertions**. Committed page is already 0, but `presentedOffset` remains 0.25 and the real converted page frame begins at −300 pt. These executed Main assertions establish the idle visible-origin defect beyond a page-count/committed-page-only check. The red log is retained; this reviewer did not run it.

### Source reasoning and repair disposition

The unchanged `PagingCore.setPageCount` idle/interrupted/cancelled branch at lines 384–389 clamps the committed index but applies the existing soft boundary function to the visual offset. That is insufficient to ensure an integer displayed origin when a multi-page capacity becomes one page. The owner can correctly map its stable anchor to page 0, find that committed page is also 0, and therefore issue no page request. The residual fractional offset then has no later navigation to normalize it. This is an owner integration assumption exposed by native evidence, not authorization to change global Core boundary behavior.

The repair at `AppDelegate.swift:4733–4739` checks `surface.presentedOffset != Double(surface.core.committedPage)` immediately after `reloadCurrentPresentation`. If unequal, it calls the existing `surface.cancel()` at the already admitted idle/cancelled layout boundary. The transaction still holds its reentrancy guard and its locally captured stable relocation. No new owner-created anchor request or keyboard pending target has been installed yet, so this normalization cannot cancel the new transition in the way F1 did. The existing readability protection runs afterward, then keyboard reconfiguration and the existing optional direct-page request.

Read the actual unchanged primitives: `PagingCore.cancel` sets `visualOffset = Double(committedPage)` and fires offset change; `PagingSurface.handleCoreOffset` assigns the container's x origin from the current Core offset and viewport width. Thus normalization repairs both model and real view origin even in the one-page/same-committed-page case where no page request is possible. At an already aligned boundary the new check performs no cancel. If an anchor maps to another page, that independently selected navigation still runs after normalization. The change adds no per-frame work, timer, public pager API, Core/physics modification, production Reduce Motion toggle, catalog revision change or workspace reorder.

### Regression source and saved focused result

`testShrinkingToOnePageNormalizesIdleVisualOffsetAndRealViewOrigin` at integration-test lines 464–478 creates 46 isolated synthetic records, applies 3×3, navigates to old page index 1 (display page 2), disables Reduce Motion only in the fixture, and applies 8×8. It asserts one page and committed page 0, then separately asserts zero presented offset and the actual renderer page's converted frame origin/width in Surface coordinates. It uses the real owner and existing Surface/Core primitives; it does not patch internal offset or replace readiness. This directly covers the reported same-page/no-request failure. The earlier F1 selected/deferred animated tests and F3 retained-page/menu tests remain unchanged, providing separate regression coverage of the surrounding ordering.

Read terminal `integrated-focused-r9.log`: **133 methods / zero failures**, 3.954 s test duration (3.964 s outer summary), Selected tests passed. This is saved Main execution of the broadened focused selection, not reviewer execution or a full/native PASS. The original failing native candidate and red test are not retroactively relabeled green. Native r2 must verify the actual rendered page after the same transition on its own frozen binary.

### R4 frozen input/evidence hashes

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `a0752a9a441a85ce4fb85343fe657292e6170f73b718d360aa4db541e20b2c1d` |
| `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift` | `ef94bff39d6974c8cac03b6959841e22263b229ced1b7d59f040287b6a0b5ff8` |
| `Sources/PagingCore/PagingCore.swift` | `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369` |
| `Sources/PagingUI/PagingSurface.swift` | `0197dce825a7c381373b0dc25e1df818f904e5398458aa5789749f322d416409` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `58694944275922d2c3d32e6d38debb46853f405714a0d61f746f4320b4f7d518` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `491937d5568f1791d038ca18a5a3e8a8400766ba4fa2257c57a1fb032f50223b` |
| `Docs/MAIN_GRID_CAPACITY_SPEC.md` | `e2b93a44dc5ef0be2296e05d03512f17ef7121d63705810058a0c7fb07e05ebe` |
| `.build/verification/20261017/main-grid-capacity/source-inputs-integrated-r3.json` | `dc955fead19129359ce54f1b1f517ad58ee3c7d07722624dcb1e44b548d922e7` |
| `.build/verification/20261017/main-grid-capacity/native-r1-checkpoint.json` | `b7580e4c710c3cd743159c8434399b3dc716d92041cc120c216fb4c5d6c1d441` |
| `.build/verification/20261017/main-grid-capacity/native-offset-red-r1.log` | `66896c5577ac369e13e9c70291dfe4e61367ff85bb95a436d106591384db55aa` |
| `.build/verification/20261017/main-grid-capacity/integrated-focused-r9.log` | `6a1de38c198b1dd9c6c789fc41e501e1997c0c52c0e2989fe745ddeaa3d49b87` |

### Remaining gates and change disclosure

Main must freeze the repaired inputs, run and record the new full suite/build/package sequence, produce and hash the new r2 candidate, and repeat native page-2→one-page geometry/selection checks plus the remaining accepted viewport/default/endpoints/folder/Library/Quit/restart/input/AX matrix. Prior full/build/native subcase evidence cannot substitute for execution of this changed owner/test. No resource/RSS/global queue/physical/120 Hz or wallpaper improvement is inferred from this repair. Old r1 remains not accepted until superseded by explicit new-candidate evidence; whole-feature completion is not asserted.

R4 Reviewer change: appended only this section to `Workflow/results/MAIN_GRID_CAPACITY_OWNER_SOURCE_REVIEW.md`, preserving every prior byte. Any relevant source/test change after these hashes requires an explicit superseding review. Main retains all implementation, test/build, native and process ownership.
