# Folder Rename Slice — Independent Source Review

Date: 2026-10-13
Stage: `2026-10-13-folder-rename`
Authority: `Docs/LAUNCHBETTER_FOLDER_RENAME_REPAIR_PLAN.md`
Writable scope: this NEW document only.

Current decision: see **Final scoped source rereview — rename source freeze r1** below. Earlier sections are preserved historical checkpoints.

## Verdict and evidence boundary

**SOURCE FAIL — persistence foundation findings F1–F3 remain open.**
The mounted rename/session and metadata continuity repairs listed below are
observed in current source. This is not a finding that all repairs are absent.
No GUI, physical performance, process restart, termination durability, or full
parity certification is issued.

Review snapshot: 2026-10-13 09:58:20 UTC / 18:58:20 JST. Source changed during
inspection (including live field-editor text and the owner drain API). The latest
AppDelegate/test snapshot below supersedes earlier reads. Main's authoritative source freeze and
current integration results have not been supplied to this reviewer. Hashes
identify the observed source; they do not establish a released candidate.

The prior 1817 tests / 0 failures belongs to the previous slice. The initial
current focused run was reported as 51 tests / 1 failure, limited to a transparent
title button's AXUnknown role. Current source explicitly assigns `.button` at
`Sources/AppGridUI/FolderOverlayView.swift:261`. A rerun is required to close the
runtime assertion; this reviewer did not execute it. Main subsequently reported 9 nil-editor integration failures: button request,
window attachment and readiness gates passed, but focusing the field immediately
committed the seed as a no-op and ended the edit. This runtime failure is not
resolved by test-source coverage. Main removed redundant `editor.selectText(nil)`
after `window.makeFirstResponder(editor)` and is retesting; current source at
`AppDelegate.swift:1399–1403` confirms that removal, not its effectiveness.
Queue 7 and metadata/model 34 were reported green by Main; no final owner,
focused/full suite or source-freeze evidence is claimed here.

No builds, test commands, GUI operations, reference-source/asset inspection,
installation, commits, process stops, role dispatch, or implementation edits were
performed. Main owns test execution and concurrency. Workers were reported closed;
this reviewer created no additional agents. All review shell commands after reading
the RTK instruction used `rtk` (the instruction and initial memory-registry lookup
were read before applying the prefix rule). No relevant memory-registry match was
used as project evidence.

## Findings

### F1 — P1: asynchronous write failure can remain silent after a successful rename

- **Locations:** `Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift:33–36`;
  `Sources/PagingPrototypeApp/AppDelegate.swift:859–867`;
  `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:75–82,293–316`.
- **Trigger/evidence:** the real store's `enqueue` only assigns pending data and
  spawns its persist loop; it does not wait for a disk outcome. The queue reads
  `currentState` once immediately afterward. An initial healthy state can therefore
  be published before a later write/retry failure changes the store to
  `persistenceDegraded`. No subsequent completion/state observation is installed.
  The owner observer only sets `layoutPersistenceState`; source searches found no
  user-visible consumer of that degradation state. The rename remains visibly
  accepted in memory although it may never be saved, even without quitting.
- **Likely root cause:** enqueue acceptance is used as the observation boundary for
  write completion, and owner state is not routed into neutral failure feedback.
- **Recommended solution:** observe the actual store completion/degradation for
  the captured store epoch and route it to explicit neutral owner feedback. Keep
  the accepted in-memory layout and LKG intact; do not log title text. Do not add
  synchronous I/O to the editor or frame path. Main should choose the bounded
  implementation inside the approved plan.
- **Affected scope:** new shared-commit queue wiring for rename, also shared by
  organization/drag commits. The asynchronous store behavior predates this slice;
  this finding concerns relying on its early state sample in the new integration.
- **Regression risks:** delayed error from a replaced store must not affect the
  current store/UI; repeated failures must not flood alerts; recovery must clear
  degradation only after a real successful write.
- **Confidence:** high from source control flow; no fault-injection run performed.
  `WorkspacePersistenceQueueTests.swift:27` always returns `.healthy` in its fake
  store and does not exercise a post-enqueue state transition.

### F2 — P1: accepted-but-rejected data can drain as `nothingPending`

- **Locations:** `Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift:57–59`;
  `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:94,308–313`;
  `Sources/PagingPrototypeApp/AppDelegate.swift:1767–1773`;
  `Tests/PagingUITests/FolderRenameAssemblyTests.swift:232–235`.
- **Trigger/evidence:** an accepted layout can exceed the private payload limit,
  for example after a rename expands an already near-limit encoded layout. The
  persist loop records `.persistenceDegraded(.rejectedOverLimit)` and clears that
  pending layout. Once submissions complete, `flush` sees no pending layout and
  returns `.nothingPending` without consulting this rejection. The new drain
  forwards that result unchanged. The real-journal integration test explicitly
  accepts `.nothingPending` as a completed flush, illustrating why pending-empty
  alone cannot prove accepted-write durability. The same loss of outcome occurs
  after an asynchronous `staleRejected` write, which clears pending and only
  increments a counter.
- **Likely root cause:** queue completion tracks submissions, while the store's
  empty-pending branch discards the outcome of the accepted generation.
- **Recommended solution:** preserve/query the terminal outcome of the accepted
  generation (or an equivalent receipt) and distinguish an empty successful drain
  from rejected or failed accepted work. Keep `.rejectedOverLimit` and
  `.staleRejected` explicit through the foundation API. Add Main-owned coverage
  using the real store behavior, rather than only a fake returning `.failed`.
- **Affected scope:** accepted-write drain foundation and its real-journal consumer.
  This is a dependency-contract defect exposed by the new API; no termination
  policy change is authorized by this recommendation.
- **Regression risks:** do not report an obsolete rejection after a newer accepted
  generation actually persists; no-op/empty queues must remain valid; preserve
  privacy and LKG data.
- **Confidence:** high from explicit branches; no payload-limit run performed.

### F3 — P2: the drain's bounded wait does not bound the complete store flush

- **Locations:** `Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift:42–59`;
  `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:85–96,352–380`.
- **Trigger/evidence:** after exhausted background write retries, the store keeps
  pending data with `isPersisting == false`. A drain's `flush` therefore bypasses
  the timed in-flight loop and directly awaits `persistOnce`, whose slot reads,
  write, replace and directory fsync have no deadline. An injected stalled I/O
  operation can hold this foundation API indefinitely. `enqueueWait` bounds only
  the queue polling portion; the queue comment's assertion that store flush has
  its own bounded barrier does not hold for this final write attempt.
- **Likely root cause:** the store timeout covers its existing persist loop but
  not a new attempt initiated by flush. Queue relies on that narrower contract.
- **Recommended solution:** provide an explicit end-to-end bound while preserving
  ownership of unfinished accepted work. A timeout must return without awaiting a
  permanently suspended losing child, and must not discard or race the actual
  writer. Validate stalled final-flush I/O separately from stalled enqueue.
- **Affected scope:** new drain API's bound and existing store dependency. This is
  not a claim that a production filesystem stall was observed, or that Quit is
  wired. Current queue tests stall enqueue, not the final real-store flush.
- **Regression risks:** no main-runloop blocking, orphan writes or concurrent
  journal rotation; late results must remain epoch scoped.
- **Confidence:** high for the missing bound; runtime incidence unmeasured.

## Repairs observed in source

| Area | Observed source and bounded conclusion |
| --- | --- |
| Title interaction and host | `FolderOverlayView.swift:174–179,254–264,445–505,704–719,894–896`: target/action title control with explicit AX role, real panel-local editor frame, descendant hit routing, mounted-editor replacement refusal and layout updates. Does not prove physical discoverability or GUI appearance. |
| Invalidation order | `FolderOverlayView.swift:299–310,367,395,414,477–486,620–623`: owner invalidation before unmount/panel hiding for refresh, clear, visual exit, teardown and move-out collapse. Reentrancy guard prevents remount during invalidation; drawing-only exit/proxy interactions are inert. |
| Fresh session and owned field editor | `AppDelegate.swift:1370–1403` creates a fresh editor seeded from the canonical folder, captures folder ID, catalog revision and full layout snapshot plus token. `FolderTitleEditor.swift:78–82` reads that control's `currentEditor()?.string` before fallback to its value; it does not read a window-global editor. |
| Stale and duplicate callbacks | `AppDelegate.swift:1387–1397,1407–1423,1433–1445`: both editor and keyboard callbacks are per-edit token closures; captured token and exact current layout/revision are revalidated. Context/callbacks are invalidated before unmount, then keyboard callbacks are cleared. `FolderTitleEditor.swift:78–98` has an idempotent finish gate and callback dismissal. |
| Normalization and shared commit | `FolderTitleEditor.swift:81`, `LayoutMutation.swift:251–265`, `AppDelegate.swift:1416–1423,799–867`: existing trim/blank-original-fallback/64-grapheme policy, real rename mutation, single shared commit only on `.success`. Cancel/reject/no-op does not submit a rename write. |
| Hidden/missing references | `AppDelegate.swift:1737–1754` derives from canonical persisted layout, retaining folder records and references. `LayoutMutation.swift:263–265` replaces only the title, without rebuilding members from visible overlay cells. Preservation is observed in source; the owner fixture currently has four installed, unhidden records, so owner-level latent/hidden coverage is not established by that fixture. |
| Read-only/bootstrap | `AppDelegate.swift:1892–1896,1371–1378` rejects edit start while restoration/teardown/protection is active and rechecks after surface cancellation. Mutation commit revalidates readiness. Tests are source evidence, not a current executed pass. |
| Input ownership | `AppDelegate.swift:1900–1906` rejects active drag sessions and `.tracking`/`.interrupted` before starting edit; settling is cancelled before revalidation. `DragUISessionCoordinator.swift:180` includes pending blank and click-only presses. Title-edit drag/start gates reject new pointer arbitration. Physical-device ownership acceptance remains unverified. |
| Close/search/hide/screen/teardown | `AppDelegate.swift:1035,1066,2057,2175,2181,2226`: explicit close/switch/hide/screen/teardown finish before relevant view cleanup. Command-F uses `KeyboardFocusController.swift:389–393,305–308` to close through the owner before search responder transfer. Direct `AppSearchController.activateSearch()` is not independently instrumented as an owner cancellation seam; this review does not generalize the Command-F guarantee to arbitrary external invocations. |
| Metadata two-key continuity | `AppManagementPreferences.swift:30–41,73–110`: hidden OR across preferred and normalized-path keys, alias preferred-key then path fallback, explicit unhide/reset-alias clears both, explicit alias replaces legacy path alias, no automatic migration or unrelated-key deletion. Same-path identity enrichment is covered; arbitrary path moves of legacy path-only keys are not promised. |
| Real UI alias retrieval | `AppManagementSettingsView.swift:104–105` and `AppDelegate.swift:1955` use `preferences.alias(for:)`, so settings field and real alias sheet receive the legacy fallback in source. This is code-only acceptance, not exercised UI acceptance. |
| Queue order/epoch/privacy | `WorkspacePersistenceQueue.swift:19–39`: submissions capture their store, serialize predecessors within the active epoch, reject stale queued writes/feedback and remove pending entries. New epochs do not wait for old store tasks. No title/log output or frame-path persistence was introduced in the reviewed editor/overlay/queue paths. This does not prove in-flight cancellation or ordering when a caller reuses the same store under a different epoch. |

## Test-source coverage and remaining gates

`Tests/PagingUITests/FolderRenameAssemblyTests.swift` contains 10 owner tests using
an actual unshown NSWindow and mounted FolderTitleEditor, real button action,
production owner callbacks and synthetic catalog. The live-editor test at
124–132 reads only the field editor, guarding against stale seed text. Enter,
Escape, focus-loss callback, fresh sessions, retained old token callback,
close/switch, protection, catalog change, resize/screen/overlay teardown, no-op,
Unicode and one-enqueue assertions are present.

The focus-loss test at 134–144 explicitly calls `controlTextDidEndEditing`;
it does not cause and verify an actual AppKit responder transfer. The test named
`testChangedCatalogOrLayoutRejectsCapturedRename` at 197–207 changes the catalog
revision only. These distinctions do not negate its owner wiring coverage.

The tenth test at 224–242 installs a real temporary LayoutStoreActor, drains
immediately after owner rename without a preliminary enqueue wait, then creates
a fresh store and checks journal-loaded title, membership and top-level order.
It is an in-process private-journal test, not process restart or Quit acceptance.
Main must supply its actual execution evidence.

The 7 queue tests cover suspended enqueue, same-epoch ordering, stale queued
submission, enqueue timeout, stale drain, and explicit fake flush results.
They do not close F1–F3 or establish the old-in-flight/same-store-epoch case.
Overlay host tests inspect actual selectors/hit routing/AX role and cancellation
before removal. Metadata tests are broader pure-function/codec coverage; settings
and sheet fallback correctness above is assessed from their actual consumers.

Required follow-up: Main routes F1–F3 for bounded repair/dependency decisions,
supplies a stable source freeze and current focused/full suite evidence, and
requests source rereview. Reviewer does not implement or approve architecture.
Current source PASS is withheld until the findings are resolved in observed code,
and the reported immediate finish-on-focus integration blocker is closed against
the actual owner fixture. The selectText removal is a repair attempt, not a pass.

## Explicitly deferred termination policy and acceptance

`AppDelegate.swift:1764–1773` is a foundation API only. There is no production
`applicationShouldTerminate` drain/reply barrier; `applicationWillTerminate`
still performs teardown. Accepted work can be abandoned by actual process exit;
resident hide is a different lifecycle. This is the approved plan's outstanding
Quit follow-up, not falsely classified here as an already repaired or newly wired
termination flow.

The proposed Cancel Quit / Quit Anyway failure dialog, Cancel default, awaits the
specific user decision. This review neither approves nor wires it. Any future
Quit durability claim requires the approved policy, actual termination wiring,
queue/in-flight failure evidence and matching candidate acceptance.

GUI title editing, accessibility behavior on the real candidate, physical input,
matched physical performance, restart acceptance and full parity remain separate
open gates. Existing baseline results and source inspection do not close them.

## Source fingerprint

Core hashes were captured at 09:55:06 UTC. AppDelegate and the owner test were
reread and rehashed at 09:58:20 UTC after Main's lifecycle update. Other hash rows
retain their earlier snapshot identity; no authoritative whole-tree freeze is claimed.
The full repository is a dirty integration tree; HEAD/baseline alone is insufficient
identity. Hash changes require new source inspection, not silent reuse of this verdict.

| File | SHA-256 |
| --- | --- |
| Sources/AppGridUI/FolderOverlayView.swift | 498c646a4be1009070d29cf29d5e91d95b7c9d61624b12009563973bdb92019b |
| Sources/PagingPrototypeApp/FolderTitleEditor.swift | 1a049d8e8d34bb6e688a6a2c046e9b02ea95f6b58fe221e81e890496e0e76484 |
| Sources/PagingPrototypeApp/AppDelegate.swift | a78a82d3c737b90274d33ae7d285aea70f3ceee63a88c9bd34a572b923f0e5f9 |
| Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift | 9ae98a0fce6ccbd418f27a2f62c092a2b2d1102c2bafc85618e8269b2536ebcf |
| Sources/AppGridUI/AppManagementPreferences.swift | 9a479f644cfb3ae5e40c6918adbf2d37c5ee1b7fce88c20f14ec0cbe3030c826 |
| Sources/PagingPrototypeApp/AppManagementSettingsView.swift | 1dc0d2b38d36c6a6e47371bb09c597bd3503159bb9fa664ce22e7a00c33a94c6 |
| Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift | aabd5df437afc4dc685321eb2c1d0df9f7b9d5bdbf7688da25e541a51a2e1cbc |
| Sources/AppGridUI/LayoutStore/LayoutStore.swift | 92aafeabfd33b760c2e7c5af2df1ecf3c3e9f53bff128433502677cde4bb16ea |
| Tests/PagingUITests/FolderRenameAssemblyTests.swift | a848cbcb4980feaab1f91241a0a9d870edee101213c06a953681eca05967c61a |
| Tests/PagingUITests/WorkspacePersistenceQueueTests.swift | a0818746c6c6dc491510f20678845929ae376263e194b9ebc952bf1a3927ce0f |
| Tests/AppGridUITests/FolderTitleEditingHostTests.swift | cb221bfb8aec5e3b85a946bf7cb3fcbbcc70f0b5715013da610fb7de16043ced |


## Interim risk inspection — 2026-10-13 19:13:43 JST

**Checkpoint only; not a final rereview or a new frozen-source verdict.**
Main is actively implementing repairs and termination tests. The earlier findings
and snapshots above are historical review evidence and are not silently replaced.
Main reports rename integration 61/0, fixing the 9 nil-editor failures by removing
the redundant selection call without a DI override. Main also reports a current
focused 27/0. These are supplied execution results; this reviewer ran no tests.

### Approval correction and current scope

The latest direct user instruction approves actual Quit waiting plus bounded
flush, with failure options **Cancel Quit (default)** and **Quit Anyway**. This
supersedes the earlier section's "awaiting approval" status. Approval does not
prove implementation or acceptance: at this inspection snapshot the AppDelegate
still had no `applicationShouldTerminate` barrier. Main is implementing it now.
No final termination-wiring conclusion is issued before the requested freeze.

F1–F3 repair mechanisms are now visible in changing source: the queue observes
post-enqueue flush outcomes rather than early healthy state, retains an outer
FlushOperation after caller timeout, and the actor retains terminal rejections
and claims a single writer before spawning. Main owns the persistent neutral
failure notice. These observations are not closure of F1–F3; final dependency,
concurrency, lifecycle and test evidence is still required.

### R4 — P1: status-item pre-Quit makes Cancel Quit unrecoverable

- **Exact snapshot locations:** `Sources/PagingPrototypeApp/StatusItemController.swift:325–330`;
  `Sources/PagingPrototypeApp/AppDelegate.swift:2151–2156`;
  `Sources/PagingPrototypeApp/LauncherWindowController.swift:138–141,280–286`;
  `Sources/PagingPrototypeApp/LauncherPresentationCoordinator.swift:51–61,80–91,96–100`.
- **Evidence/trigger:** the actual status-item action calls `onCommand(.quit)`
  before `terminateApp()`. Its production owner callback immediately calls
  `launcher.quit()`. That irrevocably sets `.terminating` and orders the launcher
  window out before NSApplication asks its delegate whether termination should
  proceed. A later negative reply/Cancel Quit leaves a living process whose Show
  and Toggle commands return `.none` in `.terminating`. There is no cancellation
  transition back to the prior presentation state in this coordinator.
- **Root cause:** a process-termination request commits irreversible presentation
  state before the newly approved cancellable persistence decision.
- **Recommended action:** route the status-item request into the same cancellable
  NSApplication termination entry as Cmd-Q, and defer launcher quit/teardown until
  termination is actually accepted. Avoid restoring by guessing an old animation
  state. Main should verify failure -> Cancel Quit -> usable Show/Toggle/edit ->
  retry Quit through the real status-item callback, not only a direct delegate test.
- **Related seam:** `ActivationComposition.swift:159–172` calls `launcher.quit`,
  `launcher.terminate`, unregisters activation services and sets `didRequestQuit`
  before `onRequestTerminate`. No production caller of `handleQuit()` was found
  in this snapshot (only integration-test callers). If Main wires it as a new
  pre-delegate Quit entry, it has the same problem plus service/window teardown.
  `handleApplicationWillTerminate` is an accepted-exit cleanup path and should not
  be conflated with this preflight problem.
- **Affected scope:** termination request routing and Cancel Quit recoverability.
  This is a concrete integration risk in the source Main is modifying, not a
  claim that a completed new barrier was tested and failed.
- **Regression risks/confidence:** preserve hide behavior and exactly-once final
  teardown; high confidence in the irreversible current source path, no GUI run.

### R5 — P1: an in-flight old flush receipt can approve a newer batch

- **Exact snapshot locations:** `Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift:15–23,73–99,111–119`;
  `Sources/PagingPrototypeApp/AppDelegate.swift:886–891,1820–1826`.
- **Evidence/trigger:** completed-success cache reuse correctly checks
  `submissionID == latestSubmission[epoch]`. In contrast, `existing.result == nil`
  reuses an old in-flight operation regardless of submission ID. The drain returns
  that operation's result after it completes without verifying which submission
  it covered. One concrete interleaving: batch A flush times out at the caller
  while its retained operation is unfinished; batch B is accepted and enqueued;
  the new B observer/drain joins A; A returns its successful receipt. B's observer
  compares only its captured B against current latest B, so accepts A's success
  as B's result and hides the failure notice. An explicit Quit drain can likewise
  receive a pre-B receipt. A store outcome computed before B enqueue is not proof
  of B durability; actor serialization alone cannot repair the outer receipt's
  incorrect attribution.
- **Root cause:** sharing an unfinished writer and certifying the joining batch
  are treated as the same operation. The batch loop validates an observer's
  captured ID but not the FlushOperation's ID.
- **Recommended action:** join the retained old operation to avoid concurrent
  writers, then re-evaluate the accepted batch and start/join a flush covering
  that batch before returning success or publishing a success notice. Respect
  the caller's deadline throughout. Main should test suspended A flush + A
  caller timeout + B enqueue + A success + B failure, asserting no B success or
  notice clearing until a B-covered receipt. Include the explicit Quit drain
  consumer as well as automatic observers.
- **Affected scope:** latest-batch outcome observation, successful flush caching
  and termination durability. This is a queue attribution defect, not proof that
  B is always absent from a particular real actor flush (it can be included).
- **Regression risks/confidence:** preserve writer ownership after timeout and
  prevent parallel flushes; do not continually restart the deadline on new
  submissions. High confidence in the missing submission check; unexecuted.

### R6 — P2: new submissions can lose observation while `currentState` is awaited

- **Exact snapshot locations:** `Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift:48–51,106–109,125–130`.
- **Evidence/trigger:** an observer publishes A's flush outcome, then awaits
  `store.currentState()` with its observer entry still present. A reentrant store
  permits B's enqueue to complete during that suspension. B calls
  `scheduleObservation`, which returns because `observers[epoch]` is non-nil.
  When A's state await finishes, its latest-batch check suppresses the old state
  but it unconditionally returns and removes the observer. B now has no observer
  or scheduled flush; a failed B write can have no outcome notice until another
  submission or manual drain happens. Source behavior is independent of whether
  the eventual A/B disk writes themselves are serialized correctly.
- **Root cause:** deduplication has no pending-work handoff/recheck after the last
  suspension point. The existing `continue` checks only the earlier drain wait.
- **Recommended action:** recheck the latest submission after awaited state
  observation and continue/schedule the new batch before releasing ownership.
  Add a controlled currentState suspension test with B enqueue completing before
  A resumes, then prove B failure is observed once and cannot be lost.
- **Affected scope:** automatic persistence error feedback and observer dedup.
- **Regression risks/confidence:** no duplicate notices or unbounded polling;
  stale epochs must still exit. High confidence from the explicit await/guard/
  unconditional-return ordering, no test execution by this reviewer.

### Remaining checkpoint boundaries

All above are requests for Main's bounded repair/test decisions. Reviewer has
not edited implementation or tests. Main owns termination implementation;
worker actor ownership remains unchanged. No new roles, builds, tests, GUI
operations, installs, commits or process stops were performed. Only this report
was appended, using an `rtk`-prefixed write. Wait for Main's final source freeze
and matching results before final rereview; none of these interim observations
certify GUI, performance, process restart or full parity.

### Interim input fingerprints

SHA-256 captured at 2026-10-13 10:13:43 UTC. These are a changing-tree checkpoint,
not a source freeze. Earlier location references remain tied to earlier snapshots.

| File | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppDelegate.swift | 34c3794afbf48f165167b3fea8006b605953b58b04ef44a770356dcb8db42ea8 |
| Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift | 75c474e235b5d85400031cb56a5a9901bdab0403661b185c5499b0328d353ee7 |
| Sources/PagingPrototypeApp/StatusItemController.swift | f0357c8ed8230c434a5db7d94ff96db68dc187d55c75f8a5664ed1f9ce6ccf5d |
| Sources/PagingPrototypeApp/LauncherWindowController.swift | 21da1f1f5a56cc75ee0bb43caaeedbeb56cd559725ea3739aa891f2ca1e28321 |
| Sources/PagingPrototypeApp/LauncherPresentationCoordinator.swift | 933b95cefddecfd064ff3da5ea1a3560f1a09b234ce1824b809acbb7e528c7e0 |
| Sources/PagingPrototypeApp/ActivationComposition.swift | 75e02c448a5648d2fdd8ab2ff6599ee92b1c8845562452a436adcae519289a98 |
| Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift | d2f0df24d959bafe68f96299814837f860c8ea424018872ae76057c4afdfa8e3 |


## Final scoped source rereview — rename source freeze r1

**Current rename verdict: SOURCE FAIL.** R5 remains open on the post-timeout
completion path (P1); R7 identifies an actionable pending-sheet/hide lifecycle
gap (P2). This decision supersedes the earlier snapshot's open-finding list and
its no-termination-wiring statement. It does not deny the observed repairs or
the successful test/build evidence below.

Scope is the existing rename, durability and metadata slice plus the now-approved
cancellable Quit policy. Main requested this review against the frozen rename
manifest. The separately approved isolated test-profile work and underway helper
files are **excluded**; no verdict is issued on them and none is fingerprinted
as a reviewed input here. Reviewer only writes this report.

### Final evidence and identity

- Freeze: `.build/verification/20261013/folder-rename/source-files-r1.sha256`.
  Actual entry count is **304**, not 301. Reviewer independently read and hashed
  those recorded files: **304 matches, zero changed, zero missing**. No test or
  build command was run. Reviewed entries were checked again immediately before
  writing this section. Unrecorded profile-helper files are not part of that check.
- Freeze manifest SHA-256:
  `e8ab65b5e56f1b189ce1858504f71014826bccdd1e8c224ee4d837271862f08a`.
- Read existing Main log `integration-r6.log`: **143 tests / 0 failures**,
  2026-10-13 19:20:24.815 JST. The corrected alias fixture now explicitly selects
  the popup record (`AppManagementSettingsTests.swift:235–236`).
- Read `full-r1.log`: **1883 / 2 failures** is retained historical evidence; Main
  corrected eventual-observer synchronization and an overstrict failed-flush
  retry count. Read `full-r2.log`: **1883 tests / 0 failures**, 19:23:22.887 JST,
  24.263 seconds wall duration. The later Swift Testing zero-test footer does not
  replace the actual 1883-test XCTest run.
- Read `debug-r1.log`: product build complete. Read `release-package-r1.log`:
  Release build complete and candidate assembly complete. Main confirmed success.
  Candidate: `.build/candidates/folder-rename-rc-20261013-r1/Launchcopy.app`.
  Executable SHA-256:
  `5aae0bff4d7096be36bafd3fc04852a2a2e03cbd4445fbe8d05ba9ef8e5428f1`.
  This hash is log/Main evidence, not a reviewer runtime/candidate launch.
- No candidate GUI, physical-input/performance, process Quit/restart or full
  parity acceptance is certified. Existing windowed/catalog-root switches still
  use the production store at `AppDelegate.swift:634–637`; no live candidate was
  launched for this review. The new isolated profile has its own scope and gate.

### Previous finding disposition in observed source

| Finding | Disposition and exact frozen-source evidence |
| --- | --- |
| F1 early healthy sampling / silent failures | Original early-sampling path repaired: queue schedules observation after accepted enqueue and drains first (`WorkspacePersistenceQueue.swift:48–51,119–124`). Owner has one persistent neutral notice and dirty-state retention (`AppDelegate.swift:834,894–919`). No modal-alert flood, title content output or memory rollback. Successful receipt clears notice/dirty flag, which makes the remaining R5 callback attribution defect material. |
| F2 terminal rejection hidden by nothingPending | Source repair observed: actor stores `.staleRejected` / `.rejectedOverLimit` after pending removal (`LayoutStoreActor.swift:350–359`), consults terminal rejection on empty flush (`115–116`) and clears it after actual write success (`336–341`). Eleven real actor/codec tests with isolated gated IO cover terminal outcomes, LKG and recovery. |
| F3 final flush not bounded | Source repair observed: actor owns a writer before spawning (`LayoutStoreActor.swift:309–314`), flush polls a ContinuousClock deadline even for the final attempt (`96–134`), and caller timeout leaves writer owned. Queue separately bounds enqueue and flush, keeps the absolute flush deadline across repeated receipts and never joins an indefinitely suspended losing Task.value (`WorkspacePersistenceQueue.swift:64–108`). This is source evidence for initialized application stores, not a physical I/O latency certification. |
| R4 irreversible pre-Quit | Closed in source for the installed status-item path: `installStatusItem` uses the exact handler (`AppDelegate.swift:2161`); that handler ignores `.quit` presentation mutation (`2178–2187`), letting actual StatusItem.performQuit/terminateApp reach NSApp (`StatusItemController.swift:309–310,325–329`). Only willTerminate does final lifecycle cleanup (`AppDelegate.swift:2337–2341`). Detached owner test uses this same production handler and repeats the same menu path after Cancel (`FolderRenameAssemblyTests.swift:363–387`). |
| R5 stale receipt attribution | Main drain path repaired (`WorkspacePersistenceQueue.swift:101–107`). **Not fully closed:** late completion after automatic observation timeout bypasses that check; finding below. |
| R6 observer lost wakeup after currentState | Closed in source: post-state await now rechecks current epoch/latest batch and continues rather than returning (`WorkspacePersistenceQueue.swift:135–138`). Gated-state enqueue-B/failure test covers the original race (`WorkspacePersistenceQueueTests.swift:210–224`). |

### R5 remaining — P1: late old flush success bypasses the repaired batch check

**Exact locations:** `Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift:125–133`
(particularly 127–128), `Sources/PagingPrototypeApp/AppDelegate.swift:897–899,2239`.

The ordinary drain loop now correctly refuses an old operation's receipt for a
newer submission and conservatively flushes again. The **automatic timeout
completion callback** still compares only `latestSubmission[epoch] == batch`;
it does not compare `operation.submissionID` with that batch, and publishes the
operation's completion directly, bypassing the repaired drain loop.

Concrete supported-seam interleaving:

1. Flush operation A remains unfinished beyond the automatic observer's wait.
   Observer A emits timeout, registers a late callback and releases its slot.
2. Submission B is accepted/enqueued while A is retained. Observer B joins A;
   its own bounded wait also expires and registers a callback capturing batch B
   on operation A. B is still the latest submission.
3. A later returns its snapshot success. A's original callback is rejected by
   the latest-batch guard; the B callback passes that guard and publishes A's
   success as B success, without a B-covered flush.
4. Owner success handling clears `workspaceNeedsSave` and the notice. B enqueue
   has completed so pendingCount can be zero; a new Quit can take the clean
   `.terminateNow` branch while B durability is still unknown/failed.

This does not claim every real actor stall takes this path. It is an observable
queue control-flow defect for the retained stalled-flush seam the repair explicitly
supports. The real actor's inner timeout may produce `.timedOut` instead, but that
does not validate the outer queue's arbitrary retained operation completion.

The strengthened scripted A-success/B-failure test at
`WorkspacePersistenceQueueTests.swift:188–208` is valuable and passes. Its explicit
caller uses `flushWait: .zero`, then releases A immediately; it does **not** wait
for the automatic observers' timeout callback registration. Thus its
`results == [.failed]` assertion does not cover this remaining branch. Accepting
`flushes >= 2` is appropriate because failures are intentionally not cached; it is
not evidence that this unexercised callback path is safe.

**Root cause:** timeout callback validates the observer batch but not the retained
receipt's batch, unlike the now-correct direct-drain path.
**Recommended solution:** validate receipt coverage in the late callback too;
when mismatched, arrange a latest-batch drain/observation instead of publishing
success. Simply dropping the callback without scheduling B verification leaves
B without recovery feedback. Preserve single-writer ownership, epoch guards and
bounded waits. Add a gated test that reaches actual automatic timeout registration
for both batches, then releases A success and proves B failure is observed without
any old success clearing the dirty flag/notice.
**Affected scope:** queue observation, dirty-state fast Quit and error feedback.
**Regression risks:** orphaned latest observer, duplicate notices, parallel flushes
or indefinite losing-task await. **Confidence:** high from source; no reviewer
fault-injection execution. Severity P1 reflects the false-clean Quit path.

### R7 — P2: visible-host failure sheet has no Hide lifecycle resolution

**Exact locations:** `Sources/PagingPrototypeApp/AppDelegate.swift:2260–2265,2122–2135,2180–2186,2238`;
`Sources/PagingPrototypeApp/LauncherWindowController.swift:245–267,271–277`;
`Sources/PagingPrototypeApp/WorkspaceQuitCoordinator.swift:31–35,14`.

The presentation split is correct and explicit: a **hidden launcher** uses a
standalone `alert.runModal()`; a **visible launcher** uses `beginSheetModal` on its
window. Cancel is the Return-key/default button (`AppDelegate.swift:2274–2277`),
inspected by a non-displaying factory test (`FolderRenameAssemblyTests.swift:390–395`).

However, visibility is checked only when the failure prompt is created. During
`.awaitingDecision`, status-item Hide still calls launcher.handle(.hide), and other
resident hide/suspend paths can order out the parent. Hide preparation does not
resolve/cancel the pending Quit decision, end the attached sheet or rehost the
failure prompt. The coordinator remains pending until its original sheet callback
runs; another Quit returns `.terminateLater` without issuing a new decision.
The source therefore permits a pending termination decision whose sheet host has
been hidden. Reopening the launcher can be a recovery path; this is distinct from
R4's old irrevocable terminating-state defect.

**Root cause:** the approved cancellable termination lifecycle is absent from
resident hide/suspend handling after sheet attachment.
**Recommended solution:** define a bounded hide policy for the pending decision:
keep its host available, or explicitly Cancel Quit/end the sheet before hide, or
preserve an accessible standalone decision. Apply it at the shared resident hide
boundary, including activation/session paths, rather than only the status menu.
Main should test failure -> pending sheet -> Hide/Suspend -> a reachable decision
or explicit negative reply -> usable resident retry. Avoid approving termination
as a side effect of Hide.
**Affected scope:** actual failure-dialog and resident launcher lifecycle.
**Regression risks:** duplicate dialogs/replies, silently discarding a pending user
choice, activation deadlock. **Confidence:** high in the missing source handling,
medium in exact user-visible AppKit sheet behavior; no GUI was operated. This is
an actionable source lifecycle gap, not a claim of observed GUI disappearance.

### Other scoped acceptance checks

Fresh editor/session tokens, own-control field-editor reading, callback dismissal
before unmount and per-edit keyboard callback clearing remain observed at
`FolderTitleEditor.swift:78–98` and `AppDelegate.swift:1423–1501`. Redundant
`selectText(nil)` is absent. The actual native responder-transfer owner test at
`FolderRenameAssemblyTests.swift:256–265` now complements manual delegate tests.
Store epoch is captured/revalidated (`AppDelegate.swift:1445–1446,1464`) and store
replacement cancels before late callbacks (`1820–1846`); title readiness tracks
protection, restore, drag and Quit state (`1505–1506,1958–1972`). Exact physical
input behavior remains a runtime gate.

The real owner fixture now includes hidden and missing membership preservation
(`FolderRenameAssemblyTests.swift:268–278`), as well as immediate real-temp-journal
drain/fresh load (`237–254`). Rename only changes canonical title; visible projection
does not replace canonical latent membership. Original trim/blank no-op/64-grapheme
policy is preserved. Search Command-F and explicit close/switch/hide/screen/teardown
cancel through the existing owner before relevant responder/view cleanup.

Metadata preferred/path reads, unhide and alias-reset continuity remain correct
in pure source (`AppManagementPreferences.swift:30–41,73–110`), with real settings
and alias-sheet fallback consumers (`AppManagementSettingsView.swift:105`,
`AppDelegate.swift:2021`). This is code/test evidence only. No private title/alias
payload was added to telemetry/report/stdout in the reviewed transaction paths;
I/O remains outside editor and frame callbacks. No performance/full parity pass
follows from this inspection.

Actual NSApp termination wiring is now present (`AppDelegate.swift:2222–2256`)
and uses a token-scoped exactly-once coordinator. Commits are blocked while Quit
is pending; unsuccessful outcomes await explicit choice; Cancel restores idle
readiness; successful/explicit Quit Anyway replies permit final teardown. Four
coordinator tests and owner tests exercise these seams without stopping a process.
These observed repairs supersede this report's earlier "foundation only" state,
while R5 and R7 still prevent a final source PASS for this frozen candidate.

### Frozen reviewed-file fingerprints

All entries below match rename manifest r1. The previously approved isolated
profile implementation is deliberately excluded from this rename verdict.

| File | SHA-256 |
| --- | --- |
| Sources/AppGridUI/FolderOverlayView.swift | 6a028ddf4c3c18528620ef69d2e3e92f80167cc6a148e52ba0684b2dc3fe7604 |
| Sources/PagingPrototypeApp/FolderTitleEditor.swift | 1a049d8e8d34bb6e688a6a2c046e9b02ea95f6b58fe221e81e890496e0e76484 |
| Sources/PagingPrototypeApp/AppDelegate.swift | cc55e1fac1d148623cc43ca07f74ece19aa37a725bd0c0bfe51e1872e9babe45 |
| Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift | b4cad74970c7b23f0b2bfa24cb7e2a359a0ff65013345e795cf40080cc2e476b |
| Sources/PagingPrototypeApp/WorkspaceQuitCoordinator.swift | 2f70b22650cd05257fb9f2087bb213240c6dd043b55a2581cfe2c1b9cf4054f7 |
| Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift | 1f6aee06be615ae6f2b06ee5633200e0931c5f2663b1270a258d1e45a4707d5a |
| Sources/AppGridUI/AppManagementPreferences.swift | 9a479f644cfb3ae5e40c6918adbf2d37c5ee1b7fce88c20f14ec0cbe3030c826 |
| Sources/PagingPrototypeApp/AppManagementSettingsView.swift | 1dc0d2b38d36c6a6e47371bb09c597bd3503159bb9fa664ce22e7a00c33a94c6 |
| Sources/PagingPrototypeApp/StatusItemController.swift | f0357c8ed8230c434a5db7d94ff96db68dc187d55c75f8a5664ed1f9ce6ccf5d |
| Sources/PagingPrototypeApp/LauncherWindowController.swift | 21da1f1f5a56cc75ee0bb43caaeedbeb56cd559725ea3739aa891f2ca1e28321 |
| Sources/PagingPrototypeApp/ActivationComposition.swift | 75e02c448a5648d2fdd8ab2ff6599ee92b1c8845562452a436adcae519289a98 |
| Tests/PagingUITests/FolderRenameAssemblyTests.swift | 5a3fad6b06730a2bf2c46b27c3f8ae0ff069dd42583bdd37c128e99bc8bd2280 |
| Tests/PagingUITests/WorkspacePersistenceQueueTests.swift | 5c0d2a161a4ba5343acd8a2e2e6b3c9d143c6b1ee914bd4ccc924ef4da7c8da2 |
| Tests/PagingUITests/WorkspaceQuitCoordinatorTests.swift | ae212997f03de3c63b1c4aa5088aca70045436a9cf94577303a57e1204374cd3 |
| Tests/AppGridUITests/LayoutStoreTerminalOutcomeTests.swift | 96a11995729ce6fcce955bbb266e8287cd03f4b24c093dd10acfed2787306a76 |
| Tests/AppGridUITests/FolderTitleEditingHostTests.swift | cb221bfb8aec5e3b85a946bf7cb3fcbbcc70f0b5715013da610fb7de16043ced |
| Tests/AppGridUITests/AppManagementPreferencesTests.swift | 1d72dfedd4e30e84df0531e47613d6fdf74abb450074f1ccd81c7209934da01c |
| Tests/PagingUITests/AppManagementSettingsTests.swift | 5c42b3220c7c57578af2feaa7353901bff6cb520cae816f8cb617b9f6e60f319 |

Final report write time (UTC): 2026-10-13T10:31:06.027849+00:00.
