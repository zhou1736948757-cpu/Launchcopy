# Source reappearance contract audit

Date: 2026-10-15
Stage: `Workflow/stage-summaries/2026-10-15-source-reappearance-native.md`
Disposition: bounded static mapping complete; one concrete likely status regression identified; native outcome remains Main-owned and unverified here.

## Scope and execution boundary

Read-only inspection of the approved application-source contract, current watcher/coordinator/admission/catalog composition, relevant action validation, and existing source tests. The product is a native macOS Swift/AppKit application using a public recursive FSEvents adapter, off-Main admission/scanning, and catalog/search presentation committed at the existing idle boundary. Discovery inputs and canonical workspace organization have separate ownership.

The scenario is an already admitted root that was usable when its FSEvents session became active, then disappears and returns at its original path. This is distinct from a missing root at watcher startup and from a saved-source preference removal/readdition.

Only this report was written. No source/configuration/preferences/stage-summary edits; no other agents; no reference directories, reference applications, raw images/assets, or TCC database access. Main exclusively owns fixture movement, same-inode restoration, interruption rollback, candidate lifecycle, and native observations. The supplied current-455 freeze and `889d...` candidate were left untouched; their identity/manifest was not independently reverified by this audit.

**Executions: 0 tests, 0 builds, 0 Swift invocations, 0 native watches, 0 UI interactions, 0 app launches/stops/restarts, 0 fixture moves or rollback operations.** Read-only shell inspection occurred, with every shell entry prefixed by RTK; no subprocess commands were launched by an inspection script. No test counts or runtime PASS are asserted.

## Contract authority and limits

- `Docs/APP_SOURCES_AND_WATCHING_SPEC.md:27-32` requires default-on automatic refresh for admitted roots, neutral/debounced invalidations, available manual refresh, and visible unavailable/degraded coverage. It prohibits timer/frame polling.
- The same approved contract at `:43-49` retains existing snapshots until a new refresh can commit and preserves existing gesture/search/drag/folder cancellation and idle semantics. At `:68-73` it explicitly includes missing/unreadable/reappearing folders, preserved latent layout/metadata/query and launch validation, and prohibits turning source disappearance into layout deletion.
- `Docs/APP_SOURCES_GUI_VALIDATION_PLAN.md:48-52` documents the operational fallback: missing/unreadable roots retain references and show degraded coverage; reappearance is not guaranteed; Refresh Now retries admission and watcher setup without a broad parent monitor or polling.
- `Sources/PagingPrototypeApp/AppSourceWatcher.swift:57-59` explicitly calls the adapter's returned status **startup coverage** and documents missing/unreadable startup roots as best-effort, with manual replacement retry. This implementation comment does not establish live status updates. It also does not cancel the product contract's requirement to expose degraded coverage.
- The current stage explicitly disallows promoting full-root automatic reappearance into an unconditional promise. Automatic disappearance invalidation is intended by the active-root WatchRoot configuration; same-directory return must be classified from actual native observation. Failure to return automatically, by itself, is not an approved-contract regression if the documented honest degraded/manual recovery path works.

No fixed recovery deadline is specified. The adapter's 0.5-second latency is coalescing configuration, not a product recovery SLA. This audit makes no external claim about FSEvents behavior after a particular native rename.

## Exact current control flow

| Phase | Current source behavior | Consequence for this stage |
| --- | --- | --- |
| Usable startup | `AppSourceWatcher.swift:80-95` probes all supplied roots on utility, starts the stream, and returns active/degraded. `:152-158` uses recursive directory events, SinceNow, 0.5-second latency, and WatchRoot. | Establish that the native session is already active before moving the root. A startup-only missing-root test is not this case. |
| Native change | `AppSourceWatcher.swift:333-338` deliberately ignores event paths/flags/IDs and emits only a neutral change. `:133-140` gates delivery; the mailbox coalesces callbacks. | The callback requests a rescan; it does not identify a disappeared app/root, mutate layout, or publish a new coverage status. There is no RootChanged-specific recovery branch. |
| Consumer invalidation | `AppSourcesCoordinator.swift:135-140` requests debounced refresh and, when no watch update is pending, resolves the watch set again. `AppDelegate.swift:2092-2094` routes this to the existing assembly refresh controller. | Disappearance should travel through the ordinary async refresh/idle-commit path. Keeping the old served snapshot while a refresh is pending is allowed. |
| Missing fixed root | `AppSourceRootAdmission.swift:150-156` returns alreadyCovered for an unchanged canonical fixed-root reference before metadata/readability probing. The profile resolver at `:253-261` accepts that result; ordinary production fixed roots are retained directly at `:263`. | A plain missing fixed root can remain in the resolved watch set with zero excluded references. Profile canonical-substitution protection does not imply missing-directory liveness detection. |
| Missing custom root | The admitter classifies missing/unreadable metadata at `AppSourceRootAdmission.swift:159-178`; resolver `:264-268` excludes rejected custom roots. Coordinator `:115-127` replaces changed sets and exposes exclusion as degraded. | Custom-source disappearance can update coverage and remove that root from the watch set. Once excluded, its return has no dedicated parent watch or polling guarantee. Saved preferences remain intact. |
| Catalog result | `AppCatalogAssembly.swift:111-136` re-resolves scan inputs and gates results. `Sources/MacAppCatalog/CatalogScanner.swift:136-144` counts an unreadable/missing directory and returns from that traversal; `:117-125` still constructs a noncancelled snapshot. | A missing fixed root can produce a valid empty/reduced catalog, with neutral failure counts, while the separate watch status remains active. A scan failure count is not itself a coverage-status update. |
| Return | The existing stream may emit another neutral change, but no root-specific reattachment/recovery mechanism is implemented. `AppSourcesCoordinator.swift:89-92` makes Refresh Now force watcher replacement and immediate catalog refresh. | Record automatic return if actually observed. Otherwise use the documented manual recovery path after Main restores the exact root. Manual refresh must use committed references, not settings drafts. |

The adapter has no continuing status callback: `AppSourceWatching` returns status only from `replaceRoots`. The coordinator does have a UI status callback, but it is driven by its own set resolution and cached backend result. `AppDelegate.swift:2119-2121` and `AppSourcesSettingsView.swift:110-121` display that coordinator status.

## Concrete likely regression: active fixed-root coverage can stay falsely active

**Priority P2; high confidence in the static branch, native manifestation not executed.**

Trigger: an unchanged-canonical-path fixed root was usable at startup and returned `.active`; Main parks it while the session is active; a native invalidation reaches the consumer while the root is still absent and ordinary canonicalization still returns its original path.

Causal chain:

1. The fixed-root admission shortcut above retains the same root with no exclusion. Physical availability is not checked on that path.
2. No preference transaction occurred, so `sourceGeneration` is unchanged.
3. `AppSourcesCoordinator.swift:117-119` sees identical resolved roots, identical source generation, and active status. It does not call `replaceRoots` again.
4. At `:128-129`, it reuses `backendWatchStatus == .active`. The adapter's utility `rootIsUsable` probe is not rerun. `setWatchStatus` at `:95-97` consequently sends no changed value to settings.
5. A catalog scan can simultaneously commit the disappearance. The scan path does not feed root availability into the coordinator's coverage status.

**Answer to the requested status question:** current runtime status does not necessarily update when an active root disappears. For the plain fixed-root path above, it stays active even after a delivered invalidation and settled empty/reduced catalog. For an admitted custom root that revalidation excludes, it can become degraded. An explicit Refresh Now forces replacement and can make the missing fixed root degraded at that later setup.

The approved basis is visible degraded/unavailable coverage (`APP_SOURCES_AND_WATCHING_SPEC.md:29-31`), reinforced by the missing-root GUI criterion (`APP_SOURCES_GUI_VALIDATION_PLAN.md:48-50`). The likely regression is stale/honest coverage reporting, **not** lack of unconditional automatic full-root return. The adapter's startup-only comment explains why its result is stale; it does not prove the product is meeting that visible-status criterion.

Main's discriminating observation: while the root remains parked, allow the specific disappearance refresh to settle and inspect source status before using Refresh Now. A newly empty/reduced catalog combined with continued active source coverage confirms the predicted product mismatch. If no causally attributable invalidation/commit can be established, report that native observation as unresolved rather than declaring this branch reproduced. An unrelated later event must not be credited to the root move.

A bounded repair, only if separately admitted by Main, should reconcile fixed-root availability into visible coverage on the existing event-driven utility path, preserving exact-root scope, coalescing, generations and idle commits. Restarting a native stream on every ordinary event, adding polling/parent watches, or guaranteeing automatic root return is not justified by this finding. No repair is made here.

## Stale actions and preserved organization: exact acceptance boundary

A filesystem disappearance is not a source-preference transaction. `AppDelegate.swift:2087-2091` immediately revokes library source targets when discovery inputs are replaced; ordinary watcher invalidation only requests refresh. Do not require every menu/metadata action to be synchronously revoked at the instant of a rename while the approved old snapshot is still served.

There are two applicable action boundaries:

- **Before a new catalog commits:** the old visual snapshot may remain. Actual launch still checks served revision, current identity/hidden state/URL, and filesystem existence before any public launch call (`AppLaunchController.swift:156-168`). The old path while parked must refuse with a neutral missing-file/stale/unavailable outcome, not invoke a launcher. Finder reveal similarly checks current record/canonical URL/hidden state and file existence before dispatch (`AppDelegate.swift:197-211`). A metadata-only fixture cannot prove a successful real application launch after return.
- **After a newer catalog commits:** the absent identity is unavailable and old revision-bound actions must stay revoked, including retained actions after the same app later returns at a newer revision. Menu selectors recheck full binding, revision, record, canonical URL and hidden state (`AppContextMenuController.swift:74-86`). Library requests check action generation, snapshot/current revision and canonical URL (`AppLibraryOwnerController.swift:214-222`). Source replacement additionally closes its projection and advances its action epoch (`:184-190`). Fresh actions after recovery must derive from the current presentation.

Canonical acceptance is the saved layout/reference structure, not a constant number of rendered cells. During absence, presentation can omit apps and visually collapse/omit unavailable folder members. `expectedLayout`, folder identity/title/member ordering, hidden references and aliases must remain latent. After the same root returns and a fresh result commits, those identities must resolve back to the prior organization without resetting layout or readding a source preference. Keep the latest query text throughout disappearance and recovery; an empty search result is not permission to clear it.

For Main's stated baseline, distinguish the 40-app catalog, the discriminating query's filtered count, and Group1's five canonical members. If all 40 apps came solely from the parked root, the settled missing-root catalog should lose those 40 records; the visible filtered count may differ. Group1 may disappear visually, but its five saved member references and ordering must survive and recover. Do not substitute current visible membership for canonical membership evidence.

## Existing tests mapped to this exact claim

These are inspected source assertions only; none was executed by this audit.

| Existing test location | What its assertions cover | Limit for the active-root move/return gate |
| --- | --- | --- |
| `Tests/PagingUITests/AppSourceWatcherTests.swift:12-26`, `:42-59` | Recursive/WatchRoot/SinceNow intent; injected missing/unreadable **startup** returns degraded; an explicit replacement recovers active. | No initially active native root disappearance, live status transition, or automatic return assertion. |
| `Tests/PagingUITests/AppSourceWatcherTests.swift:82-132`, `:173-280` | Bounded callback storms, startup replay, stop/replacement/supersession gates. | Lifecycle correctness does not establish root reappearance coverage. |
| `Tests/PagingUITests/AppSourcesCoordinatorTests.swift:103-115`, `:217-227` | Saved custom root missing at activation stays saved and recovers through manual refresh; cached backend degradation does not restart streams on every invalidation. | No active-to-missing fixed-root availability transition. The fake backend returns a configured status and cannot expose the stale usability-probe path by itself. |
| `Tests/PagingUITests/AppSourcesCatalogIntegrationTests.swift:115-161`, `:164-201`, `:246-339` | Per-scan injected custom-root rejection/recovery; pending-result discard and query preservation; source removal/readdition preserves expected layout, hidden state, alias, folder identity and active query at idle commit. | These explicitly do not instantiate the native watcher. Removal/readdition replaces configured inputs and does not prove native same-inode root return. |
| `Tests/PagingUITests/AppSourcesProfileAssemblyTests.swift:98-138` | Actual owner rejects a fixed-root canonical/symlink substitution, retains configuration, and recovers after explicit refresh. | Different trigger: substitution, fake watcher and manual recovery, rather than a plain temporarily missing root in an already active native stream. |
| `Tests/PagingUITests/AppSourcesNativeWatchSmokeTests.swift:9-26` | Real temporary-root watcher receives installation in a nested folder that already existed before startup. | No root move, disappearance status, return, catalog commit, query or canonical layout assertions. |
| `Tests/PagingUITests/AppLaunchControllerTests.swift:158-223`; `AppContextMenuActionTests.swift:194-215`; `AppLibraryOwnerIntegrationTests.swift:117-141` | Stale revision/missing identity/missing-file launch refusal; retained menu rejection; source-epoch library revocation through failure and newer commit. | Component evidence for action boundaries, not a native root-reappearance execution receipt. |

The specific unproved branch is the active fixed-root disappearance/status transition. If Main admits a regression repair, one causal injected regression should establish usable/active startup, change root usability without changing its canonical reference, deliver a current-session event, and require honest degraded coverage without saved-data mutation; explicit retry after usability returns should recover active. This is a bounded causal criterion, not authorization to add tests or a generic test expansion list.

## Main-owned native decision criteria

1. **Parked root:** distinguish a pending old snapshot from a newly committed disappearance result. Native invalidation should use the existing refresh path and settle at an allowed idle boundary. Once disappearance is established, source coverage must be honestly degraded/unavailable; continued active status is the finding above. Keep preferences, latest query and canonical layout untouched. Launch/reveal must refuse missing targets even if an old visual cell remains temporarily.
2. **Same-root restoration, before manual refresh:** if a fresh automatic result returns the original records and organization, record that narrow native automatic-return observation with query/counters and same-inode evidence. Do not generalize it to all unavailable roots, restart scenarios or future sessions. If no automatic return is observed, retain that limitation and evaluate the documented fallback; do not fail solely on missing automatic return.
3. **Manual fallback:** Refresh Now after restoration must retry the saved root's admission and force watcher setup, then restore catalog/query/latent organization through the ordinary idle commit. With the original usable root and working native backend, coverage should become active. A returned catalog with unrecovered coverage, or a source that only recovers by app restart/reset/readdition, is not proof that the documented manual fallback works. Honest degradation alone is not a substitute for demonstrating recovery in the owned fixture.
4. **Data/action integrity through both paths:** old revision/action packets remain rejected after newer commits, fresh recovered actions bind current data, and no canonical member, title, order, alias or hidden reference is deleted because its source was temporarily absent. Observe any temporary visual collapse separately from saved state.

Main retains all rollback/lifecycle obligations in the stage summary, including restoring the original directory before unrelated work on interruption. This report neither performs nor certifies rollback, candidate exit, hash identity, GUI acceptance, physical performance, VoiceOver or full parity. No production change or broader contract is proposed.
