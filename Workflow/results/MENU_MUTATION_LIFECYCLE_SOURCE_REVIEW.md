# Menu Mutation Lifecycle — Independent Bounded Source Review

Date: 2026-10-14
Project: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
Writable ownership: this report only.

## Disposition and evidence boundary

**Menu-command ingress repair: source-consistent. Lifecycle closeout: not approved; one P2 deferred-alias confirmation finding requires Main's disposition.** The finding is in an existing continuation, not a failure of the new retained-menu ingress guard. No other concrete defect was identified in the bounded guard/rebind paths reviewed below.

This is a read-only source review, not an execution PASS. I ran no Swift build, tests, native interaction, application launch, process control, packaging, or commit. I did not access global memories or reference application materials. Main's reported prepatch baseline of four tests and thirteen assertion failures is supplied evidence, not independently reproduced here. Main's ongoing focused run is not assumed to have completed or passed.

Reviewed instructions: repository `AGENTS.md`, `/Users/mac/.codex/RTK.md`, and `Workflow/stage-summaries/2026-10-14-menu-mutation-lifecycle.md`. Reviewed applicable contracts: `Docs/LAUNCHBETTER_APP_MANAGEMENT_SLICE.md`, `Docs/LAUNCHBETTER_FOLDER_ASSIGNMENT_SLICE.md`, and `Docs/INTERFACE_LANGUAGE_SPEC.md`. The user-authorized bounded role and old-workflow waiver govern this review; no additional role was dispatched or workflow state changed.

The project is a macOS 14+ SwiftPM/AppKit launcher. `PagingPrototypeApp` owns application lifecycle, menu factories and persistence coordination; `AppGridUI` owns bound cells/presentation; `PagingUI` and `PagingCore` own surface/state behavior; localization has its own target (`Package.swift:10–33,51–67`). Recommendations preserve those boundaries.

## Finding F1 — P2: Alias confirmation can cross an assembly replacement

**Evidence:** `Sources/PagingPrototypeApp/AppDelegate.swift:2674–2685` captures the management coordinator and catalog revision for an alias sheet. Its confirmation checks coordinator identity, revision equality and hidden metadata, but does not capture/check the originating assembly or compare the current record's canonical URL with the original record. `setAppAlias` at `AppDelegate.swift:2536–2540` resolves the record by ID from whichever assembly is current, then writes through the current coordinator. The enclosing sheet gate at `AppDelegate.swift:2699–2716` checks language generation, window and content-root identity, but has no assembly check.

**Concrete source-derived trigger:** Open an alias editor from a valid current menu and retain its injected completion. Replace `host.assembly` with another assembly serving the same revision and app ID while preserving the window/content root, language realm and management coordinator. Confirm the original editor. All existing completion guards can pass, and `setAppAlias` writes against the replacement assembly's record. A different canonical URL for that same app ID is also not rejected. A guard on replaying the old menu cannot protect a sheet already opened before the replacement.

**Impact:** A delayed command from an obsolete assembly can mutate replacement presentation metadata. This contradicts original-target confirmation in `Docs/LAUNCHBETTER_APP_MANAGEMENT_SLICE.md:38–40` and prevents an unqualified claim that the full alias lifecycle is bound to its origin. This does not establish a foreign preference-store write after coordinator replacement: the existing coordinator identity check correctly rejects that case.

**Likely root cause:** Menu construction now captures assembly identity, but the later alias confirmation starts a separate asynchronous validation boundary that retains only the numeric revision and coordinator identity.

**Recommended solution:** Carry a weak originating assembly and immutable original canonical URL into the alias confirmation and reject before any save/error presentation when assembly identity or canonical target differs. Preserve the existing sheet lease release, duplicate-completion gate, root/language/coordinator guards and fresh future-schema save protection. Add an unshown native-menu regression with the existing injected sheet presenter: open while current, replace with a same-revision assembly, confirm, and assert zero metadata writes and zero follow-up dialogs; include a current-origin confirmation that still works. Recommendation only; no implementation or scope change is authorized by this report.

**Affected scope / regression risks:** Application alias-sheet continuation and its tests only; avoid changing generic menu consumers, stable IDs, preference formats or alias normalization. Ensure a valid current editor still commits and Cancel/stale completion still releases ownership once.

**Confidence:** High for the source control-flow gap; no runtime reproduction performed. Main should explicitly disposition this pre-existing continuation before claiming complete menu/alias lifecycle acceptance. The new menu-ingress repair itself can be evaluated independently.

## Guard and ordering observations

| Area | Concrete source evidence | Bounded conclusion |
| --- | --- | --- |
| All five app-menu commands | `AppDelegate.swift:2544–2557,2563–2587` | One shared closure captures weak self, origin assembly and management coordinator plus root/language epochs. Launch, reveal, hide, clear-alias and alias-open each guard before application work. An obsolete mutating menu is also read-only at selector dispatch. Launch/reveal retain their read-only exemption but still check origin in their callbacks. |
| Assignment writer realm | `AppDelegate.swift:2548–2557,2589–2616` | Layout-restore generation supplements exact layout equality. Old writer callbacks get no current layout, cannot apply, and cannot present rejection feedback. Organization submenu creation uses that same guard. A same-snapshot replacement store does not make an old assignment current. |
| Consumer validation | `AppContextMenuController.swift:74–86`; `AppFolderAssignmentMenuController.swift:181–220` | Weak-cell/token, revision, canonical URL, hidden/read-only checks and exact layout/reference policy remain in the consumers. The application guards supplement them. An assignment consumer may produce a rejection internally, but an obsolete origin's `onRejected` returns silently. |
| Final assignment commit | `AppDelegate.swift:2623–2663` | Bootstrap, layout protection, quit, teardown, drag/title-edit and surface-state restrictions remain. Binding validation runs both before policy and after surface cancellation, before closing the folder and committing. Cancellation-triggered realm replacement makes the consumer's current/protection providers fail. |
| Startup root ordering | `AppDelegate.swift:382–384,470–472,806–823,890,555–594,108–150` | Preferences precede assembly construction. Menus are initially installed before the root; layout installation advances the writer epoch. Installing feedback after root mounting advances the root epoch and rebinds current factories. A later restore completion binds the current writer. No permanently stale startup factory is apparent. |
| Restore completion ordering | `AppDelegate.swift:2445–2475` | Cancelled/superseded loads return before rebind. An accepted result clears bootstrap state and sets read-only/healthy state; deferred rebind executes on every subsequent return, including existing-session-layout, missing/error and protected-load paths. A loaded layout is installed before deferred rebind. |
| Preference/language replacement | `AppDelegate.swift:2377–2387,2232–2264` | Coordinator/accepted metadata and replacement language owner/strings are installed before rebind. Old captured coordinator or language epoch becomes obsolete. Rebind does not itself save either preference store. |
| Live and pooled consumers | `AppCatalogAssembly.swift:221–227,367–371`; `AppGridPageView.swift:81–86,320–324`; `AppDelegate.swift:1713` | Renderer factory replacement reaches existing and pooled pages without a catalog refresh or binding-generation change. Folder members resolve the current controller through weak self, rather than retaining a displaced menu factory. |
| Ordinary live relabel | `AppDelegate.swift:2333–2357`; `AppContextMenuController.swift:45–60`; `AppFolderAssignmentMenuController.swift:129–143` | Displayed-language relabel does not reinstall menu controllers or increment the realm epoch. Each newly built menu consumes one strings snapshot; retained menu titles/bindings are not reconstructed by this repair. |
| Persistence routing | `AppDelegate.swift:1131–1141`; `WorkspacePersistenceQueue.swift:33–52` | Successful assignment uses the existing commit queue, captures its store/epoch, rejects obsolete work before enqueue and rejects obsolete observation afterward. No new persistence format or alternate writer is introduced by the inspected repair. |

### Read-only, structural work and ownership

- Management future-schema protection remains separate from layout protection (`AppDelegate.swift:2563–2567,2598–2603`). The management coordinator freshly checks the store before saving (`AppManagementStore.swift:89–98`); valid layout-only assignments do not depend on management schema health.
- Rebinding is called from feedback installation, language/preference installation and accepted restore completion (`AppDelegate.swift:118,2264,2387,2458`). Ordinary frame callbacks and ordinary language relabel do not call it. Rebind updates callback wiring; formatting still happens on menu request, and existing store loading remains in the asynchronous restore task. No additional frame-path formatting, I/O, rescan, preference/layout migration or per-frame factory recreation was identified. This is structural reasoning, not measured performance evidence.
- New guard closures strongly retain only scalar expectations/shared guard closures and weak origin references. Assignment ownership remains in the application; the parent organization callback captures assignments weakly, renderer callbacks capture menus weakly, and page/folder callbacks capture their owners weakly (`AppDelegate.swift:2549–2557,2613–2619,1713`; `AppGridPageView.swift:320–324`). No new ownership cycle was identified. This is not an allocation/deallocation measurement.
- Root invalidation here is explicitly tied to feedback-generation lifecycle. The existing sheet completion additionally verifies actual window/content-root identity. Source conclusions for menu ingress assume production root replacement uses the reviewed feedback teardown/install seam; arbitrary direct property changes without that seam are not established as supported lifecycle behavior.

## Regression evidence and remaining gaps

`Tests/PagingUITests/MenuMutationLifecycleTests.swift:39–65,73–85` constructs unshown native menus/windows, synthetic records, an in-memory management store and an injected presenter. Actual selectors are replayed via `NSApp.sendAction`, with the original target explicitly retained; they are not direct mutation-model substitutes. The fixture does not install a production layout store, scan a machine catalog or order a visible window.

The four test functions at `MenuMutationLifecycleTests.swift:89–143` cover retained hide/clear-alias after root and language replacement, alias-open after root replacement, old versus fresh hide after management-store replacement, and silent assignment rejection after root replacement. They do **not** cover F1's already-open alias completion, assignment writer replacement with an identical layout, assembly replacement at unchanged revision, or successful fresh mutating menus after root/language replacement.

Complementary source evidence exists, but is not execution proof:

- `FolderAssignmentAssemblyTests.swift:81–82,113–151` deliberately installs menus before the layout store and exercises successful post-restore assignment, including a member move-out.
- `FolderAssignmentAssemblyTests.swift:188–198,299–329` checks protected bootstrap, shared commit protection and queued-write replacement routing; it does not replay a retained assignment menu across a same-layout healthy writer replacement.
- `AppFolderAssignmentMenuTests.swift:458–532` checks stale layout equality and read-only revalidation; `532–552` checks independent management/layout protection. `AppContextMenuActionTests.swift:240–249` checks read-only revalidation for actual selectors.
- `ApplicationActionFeedbackRuntimeTests.swift:267–301` replays old launch items across root/realm changes and proves a fresh launch remains live in its test assertions. That does not substitute for fresh hide/alias/assignment success assertions.

Before broader lifecycle acceptance, Main should resolve F1 and retain focused nonzero execution evidence. Adding the same-layout writer replacement and fresh mutation cases would directly protect the new epoch/rebind decisions. These are verification recommendations, not claims that the existing focused run failed.

## Reviewed snapshot and delivery

Two read-only SHA-256 checks during this review agreed for these core inputs:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `0d811b6e43ef754ceef8c1c15b0948ac9111a56de58f5200f443d6d5a7c78a71` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `e773b9a19769878ef7dcb27058a9363139084df52b4892aa291e02480a315abd` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `29f3f477e6ee0d7e1826de7ef156f0a88d84e9ab573d7a6416dd03efa00f555f` |
| `Tests/PagingUITests/MenuMutationLifecycleTests.swift` | `ed7a8ec96315a93040d26ac0b4a1f37dc4d5e1a16ac59d8681dbc4d94dbec098` |

The shared tree contains substantial earlier dirty work. Those hashes identify the reviewed files; they do not certify the entire worktree as frozen or attribute its historical changes to this stage. Changed source requires a bounded follow-up review. Only this report was created by this reviewer. Runtime, full-suite, candidate, GUI/restart and physical-performance acceptance remain Main/user gates.

## Follow-up R1 — 2026-10-14

This appended section supersedes the earlier open-F1 disposition for the snapshot below. Earlier findings and evidence remain historical; earlier AppDelegate/test line references must not be applied to the new snapshot without checking their locations.

**Bounded disposition: source review PASS with one nonblocking P3 test-fixture ownership finding. F1 is closed at the source level. No postpatch execution, full-suite, candidate, GUI/restart or performance PASS is asserted.** Only this report was modified. No tests/builds, application or process controls, source edits, global memories, reference materials or commit operations were performed. Main's newly authorized isolated app reopening is outside this reviewer's delegation; the older stage summary's app prohibition is superseded only for Main by that direct authorization.

### F1 closure

`AppDelegate.swift:2674–2688` now acquires the originating assembly before creating the editor and captures it weakly in the continuation. Confirmation must unwrap that assembly, match `self.assembly` identity and management-coordinator identity, match the served revision, resolve the original record ID in that assembly, match its original canonical URL, and reject both provider-hidden and current-metadata-hidden records. Every failed check returns before `setAppAlias` or error presentation. This closes both reviewed triggers: a different same-revision assembly with the same record, and a moved canonical URL in the original same-revision assembly.

The sheet wrapper still checks the actual window/content root and language epoch, claims completion once and releases the original modal lease in a defer (`AppDelegate.swift:2702–2719`; `LauncherNoticePresentation.swift:58–65`). The extra weak assembly capture does not create a production ownership cycle. The final alias save remains synchronous on the existing application path with fresh future-schema protection (`AppManagementStore.swift:89–98`); no asynchronous suspension is introduced between target validation and saving. No generic token/revision/canonical/read-only consumer or folder policy was edited: both menu-consumer hashes remain identical to the original review.

### Supplied reproduction log inspected

I read `.build/verification/20261014/menu-mutation-lifecycle/alias-baseline-r1.log`, rather than executing its test command. Its XCTest run at 15:28:51–15:28:52 records **7 executed tests, 4 assertion failures, 0 unexpected failures**. The failures are the two write-count and two preference-equality assertions in `testOpenedAliasConfirmationRejectsReplacementAssemblyOrCanonicalURL` (`MenuMutationLifecycleTests.swift:187–188`), covering the two loop branches. The other six cases passed in that pre-F1-patch run. The trailing Swift Testing line reports zero tests and is not used as acceptance evidence. This verifies the contents of Main's reproduction artifact, not its linkage to an independently captured prepatch binary or any postpatch result.

### All new tests reviewed

| New case and actual lines | What the test establishes through its assertions | Limits |
| --- | --- | --- |
| `testOpenedAliasConfirmationRejectsReplacementAssemblyOrCanonicalURL`, `MenuMutationLifecycleTests.swift:159–192` | Opens the actual native alias menu, retains the injected sheet continuation, then varies only assembly identity or canonical URL while preserving revision 7. Asserts zero writes, unchanged preferences, no second sheet and released modal ownership after confirmation. The assembly branch preserves the original record/URL, so it isolates assembly identity rather than conflating both guards. | Postpatch execution is not inspected. It does not separately exercise newly hidden, removed, deallocated-origin or management-store replacement after opening a sheet. |
| `testFreshAliasAndClearMenusRemainValidAfterRootOrLanguageReplacement`, `MenuMutationLifecycleTests.swift:194–217` | Runs both root replacement and language-realm replacement; builds a fresh native menu, commits the injected alias confirmation once, repeats that completion to assert no second save, builds a fresh clear-alias menu and checks the second write, cleared alias and released ownership. | An unshown native-window fixture proves assertion intent, not real sheet tracking or GUI usability. This case does not demonstrate fresh hide/assignment after both root/realm replacements. |
| `testOldAssignmentCannotCrossIdenticalLayoutWriterReplacementButFreshMenuCan`, `MenuMutationLifecycleTests.swift:224–261` | Installs and completes the original store restore, retains the original selector target and copies `onApply`, replaces the store with an exactly equal layout, waits for the new restore, and confirms equality before replay. Both old-selector rejection and direct copied-callback cancellation are checked, including zero dialogs/layout changes/writes to either store. A newly built menu must move the app and enqueue exactly the resulting layout only to the replacement store. | The copied callback deliberately receives a permissive binding validator; rejection therefore exercises the captured writer epoch. The memory store proves routing/enqueue assertions, not disk durability or fresh-process restart. |

The added actor store is in memory (`MenuMutationLifecycleTests.swift:26–37`). The restore wait is bounded and fails explicitly if bootstrap does not finish (`219–222`). The enqueue wait is also bounded, with final exact-array assertions detecting a missing/extra enqueue (`250–260`). No real store, scan, visible window ordering, synthetic OS input or process-control dependency was added.

The original four cases remain present at `MenuMutationLifecycleTests.swift:103–157`; their old-menu origin/refusal checks have not been weakened. The identical-layout test specifically exercises the existing-session-layout early return followed by deferred current-factory rebinding (`AppDelegate.swift:2455–2464`). The existing assignment/read-only checks remain at `AppDelegate.swift:2598–2607,2623–2662`. The reviewed change introduces no preference/layout migration, frame-path formatting/I/O/rebind, or alternate persistence path.

### F2 — P3, nonblocking: Injected sheet presenters retain their fixtures

**Evidence:** The injected presenter closures at `MenuMutationLifecycleTests.swift:163–167` and `199–203` reference `f.sheets` and therefore strongly capture `f`. The fixture strongly owns `host` (`42`), and `host` retains `applicationSheetPresenter` (`AppDelegate.swift:80–82`). `Fixture.teardown` (`MenuMutationLifecycleTests.swift:97–100`) tears down views/assembly and detaches the window but does not reset that presenter. The cycle `Fixture -> AppDelegate -> presenter closure -> Fixture` consequently survives the explicit teardown. This affects both loop iterations in both new alias tests.

**Impact / likely root cause:** The new injected presenters replaced the fixture's original weak capture (`79`) with strong captures for counters. These tests can leave their fixtures, stores and unshown native objects retained across later suite cases. The explicit teardown makes the immediate mutation assertions meaningful, but it does not demonstrate release/isolation of the complete fixture. No corresponding production cycle was identified.

**Recommended solution / affected scope:** Capture `f` weakly in the two injected presenters, or reset the presenter to an inert closure in fixture teardown after the test's required completion delivery. Preserve the counters, retained completion and actual-selector assertions. This is test-harness cleanup only; no production redesign or new testing infrastructure is necessary.

**Regression risk / confidence:** Low cleanup risk provided confirmation remains available until the assertions finish; high confidence from the explicit strong-reference path. This does not reopen F1 or block the bounded production source disposition, but should be cleaned up before treating repeated/full-suite execution as fixture-lifetime evidence.

### Follow-up snapshot and remaining gates

Repeated read-only SHA-256 checks agreed throughout this follow-up:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `8a41dadea70cdef4eee75ff8d0c1c6f13d902126bc5daa325908f8cc2b0b97e9` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `e773b9a19769878ef7dcb27058a9363139084df52b4892aa291e02480a315abd` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `29f3f477e6ee0d7e1826de7ef156f0a88d84e9ab573d7a6416dd03efa00f555f` |
| `Tests/PagingUITests/MenuMutationLifecycleTests.swift` | `1a8b5f21044e611262a59c9ab40e2686ea8d452378c3805b910a507efa0573c4` |
| `.build/verification/20261014/menu-mutation-lifecycle/alias-baseline-r1.log` | `f51facdce727c3f605f1c3bbabe1241d7b10ccc2bad3ae79fd3058c987fe06e0` |

Main retains postpatch focused/nonzero test execution and serial broader verification ownership. GUI/app reopening, candidate identity, persistence restart and physical acceptance remain separate Main/user gates. Any further source/test edits invalidate only the corresponding snapshot conclusions and require proportionate follow-up; this source review does not request or perform app control.

## Final Follow-up R2 — 2026-10-14

**Final bounded source disposition: PASS. F1 and F2 are fixed in the reviewed snapshot; no unresolved actionable finding remains in this assigned source-review scope.** This supersedes R1's nonblocking F2 finding without rewriting its historical evidence. Only this report was appended; no test/build execution, source edits, application/process control or other file writes were performed.

- **F1 remains closed:** `AppDelegate.swift:2674–2688` retains the weak original assembly, coordinator identity, revision, original canonical URL and both provider/current-preference hidden-state checks before any alias save or error presentation. The root/language/window and single-completion protections remain at `AppDelegate.swift:2702–2719`. Its production hash is unchanged from R1.
- **F2 is closed:** Both injected presenters now use `[weak f]` and `guard let f` before counting sheets or retaining the native completion (`MenuMutationLifecycleTests.swift:163–168,200–205`). The stored presenter no longer strongly owns the fixture; the formerly reported `Fixture -> host -> presenter -> Fixture` cycle is broken. The temporary strong reference inside each invocation ends when it returns. Existing test-local fixture ownership preserves the synchronous presenter, counter and confirmation assertions; this repair does not weaken the original-target, duplicate-completion or fresh-menu checks (`159–219`). This is a source ownership conclusion, not an instrumented deallocation result.
- **Writer/rebind regression remains intact:** The same-layout store replacement test still retains the old target and copied `onApply`, asserts silent cancellation and zero old/new-store writes, then requires one successful fresh-menu enqueue to the replacement store only (`MenuMutationLifecycleTests.swift:226–263`). Bootstrap waits remain bounded (`221–224`), and the enqueue result is asserted after the bounded wait.
- **Production ownership and structural budget:** No production cycle or new per-frame I/O, formatting, menu recreation or rebind was identified in the reviewed repair. The production files below are byte-identical to R1; only the test presenters' capture/guard changes affect this follow-up. Existing origin checks, lifecycle-only rebind seams, separate read-only policies, consumer validation and captured-store persistence conclusions therefore remain applicable. No preference/layout migration was introduced.

Main reports that the prior focused run executed **69 tests / 0 failures** and the full run **2410 tests / 0 failures**, and that final tests are being rerun after fixture cleanup. These counts are explicitly Main-supplied evidence; this follow-up did not inspect their logs or execute those suites. They are not presented as final-snapshot execution acceptance. Final focused/full verification, candidate identity, GUI/restart and physical gates remain Main/user responsibilities.

Two read-only hash checks agreed for the final reviewed inputs:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `8a41dadea70cdef4eee75ff8d0c1c6f13d902126bc5daa325908f8cc2b0b97e9` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `e773b9a19769878ef7dcb27058a9363139084df52b4892aa291e02480a315abd` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `29f3f477e6ee0d7e1826de7ef156f0a88d84e9ab573d7a6416dd03efa00f555f` |
| `Tests/PagingUITests/MenuMutationLifecycleTests.swift` | `69d42020dc2f7ac06fe3c3bc2f33c68b295ccc723556de058346d425a00beef1` |

This PASS applies to the bounded source review and these hashes. It does not certify the entire shared tree or substitute for final execution evidence.
