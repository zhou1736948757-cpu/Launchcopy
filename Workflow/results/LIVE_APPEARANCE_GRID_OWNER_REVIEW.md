# Live Appearance and Main-Grid Owner Review — R1

Date: 2026-10-17

**Bounded verdict: SOURCE FAIL.** Four source-level findings below remain open against the recorded snapshots. This is not a build, test, UI, performance, physical-input, or durable-storage acceptance verdict. Main owns repairs and execution evidence. No source freeze is requested for this initial concurrent review.

## Authority, scope, and evidence boundary

- Read the approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md`, project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, current stage summary, and workflow configuration/state. The stage's appended approval supersedes its earlier pending-confirmation header; historical workflow state is not current verification evidence.
- Existing SwiftPM/AppKit architecture: separate synchronous appearance preference owner, live intent/debounce owner, asynchronous receipt-bearing capacity owner, guarded AppDelegate presentation composition, and background wallpaper rendering. Preserve the existing explicit `AppearanceSettingsCoordinator.apply` command as a valid API; its existence is not a finding.
- Reviewed MAIN-owned files and the four requested test files listed in the hash table. Supporting reads of current local capacity-store, readiness-observer and paging code establish call semantics only. No independent review of UIworker view ownership or localization. No other agents dispatched; Main remains the routing center, maximum three including Main, Chief waived by assignment.
- Only this report was written. No implementation edits, builds, tests, application execution, UI interaction, process management, Git actions, reference-project access, OS changes, or formal-data access. Static source reads and source hashing only.
- `.build/verification/20261017/live-appearance-grid/source-before.json` contains path-to-SHA256 entries, not before text; its directory contains only that manifest at inspection. Accordingly, the actual bounded change comparison is baseline-versus-current hashes plus current source traced against the named change descriptions/new files. A textual before/after diff cannot be reconstructed from this supplied baseline, and no Git substitute was used. All six pre-existing assigned files differ from their baseline hashes; three assigned files are new relative to the manifest. Unrelated dirty changes are not attributed to this stage.
- The two source-hash passes bracketing this review matched for all nine assigned files. Main may continue editing; later source changes require revalidation of affected findings, not a freeze.

## Findings

### F1 — [P2] Reentrant flush cancels the newest save and returns a false success

**Evidence:** `Sources/PagingPrototypeApp/LiveAppearanceSettingsCoordinator.swift:78–90`. `flush()` cancels and clears `cancelScheduled` before checking `isFlushing`, then returns `.saved` when a flush is already active. `retry` returns this result directly at lines100–105.

Deterministic source trace using the existing test store's `onSave` seam:

1. Submit A; begin `flush()` and enter `store.save(A)` with `isFlushing == true`.
2. Inside that callback, submit B. B becomes the newest accepted intent and arms its debounce.
3. Reentrantly call `flush()` (or `retry(B)`). It cancels B's debounce and returns `.saved` without persisting B.
4. The outer A receipt sees a changed generation and exits. B remains `needsSave == true`, state pending, with no scheduled save. Without another edit/end/dismiss/Quit, automatic persistence has been lost. A caller receiving `.saved` can also publish success for B before its receipt.

**Likely root cause:** Treating an already-active flush as equivalent to nothing pending, and destroying queued scheduling before this distinction is established. Generation checks protect state from the old receipt but do not arrange delivery of the newer intent.

**Recommended solution:** Preserve/coalesce a reentrant flush request and service the newest intent after the active persistence call returns. Do not cancel the newer timer or return successful completion for an unpersisted request; if the existing return type cannot represent deferred completion, use a non-success result and keep pending state honest. Avoid an unbounded synchronous retry loop if callbacks continually submit.

**Affected scope / regression risks:** Live owner and retry result semantics. Preserve one bounded pending intention, successful close/Quit drainage, and explicit corruption recovery. Current `testNewIntentDuringSaveCannotBeOverwrittenByOlderReceipt` only submits B during A and then calls a second flush after A returns; it misses the nested flush/cancellation path.

**Proposed Main regression:** Store callback performs `submit(B)` then nested `flush()`/`retry(B)`; assert no premature success for B and that B is eventually persisted without requiring another external interaction. Check queue/scheduling bounds. Confidence: high; source trace, not executed reproduction.

### F2 — [P2] A valid current explicit Apply does not advance the live snapshot

**Evidence:** `LiveAppearanceSettingsCoordinator.swift:22–24` copies `persistence.committed` once. Only `submit` subsequently updates `requested`. `AppDelegate.swift:2312–2315` forwards a non-live-flush persistence command directly to presentation. `AppDelegate.swift:2342` reloads settings from `live.requested`.

Source trace: start at A; call the current `live.persistence.apply(B)` through the preserved explicit command API. The command acknowledges/persists B and presents B, but `live.requested` remains A. Reconfigure/reopen the Appearance view and it reloads A. A later ordinary edit based on that stale snapshot can automatically save A's other fields over the already acknowledged B values. A separate variant leaves an older pending live A scheduled: a later successful explicit B command can then be overwritten by A's old timer.

**Likely root cause:** The new live wrapper and the valid existing command path are two writers of user intent; only one updates the wrapper's generation/requested/debounce state.

**Recommended solution:** Reconcile a successful current explicit command into the live owner, including its generation and pending scheduler, with a clear latest-command ordering rule. Preserve automatic UI `onChange` behavior and the valid explicit command API. Suppress duplicate presentation when the command originated in the live owner's own flush.

**Affected scope / regression risks:** Appearance owner/composition only. Preserve command failure behavior, queued safe presentation, and the separation of requested versus durable state. Do not route programmatic view reload through a save to compensate.

**Proposed Main regression:** Apply B via the current underlying explicit command, reopen/configure, and assert B is shown without writes. Repeat with older debounced A outstanding; old scheduled callbacks must not restore A after B's acknowledgment. Confidence: high on the state divergence; the observed UI uses `onChange`, so this finding concerns the explicitly retained command API and mixed API ordering, not a claim that the healthy live UI invokes that path routinely.

### F3 — [P2] Retained old persistence callback can present into a replacement owner

**Evidence:** `AppDelegate.swift:2312–2315` captures only weak self and checks the *current* live owner's `isFlushing`; it does not validate the originating coordinator/live owner. By contrast, the new `onPreview`, `onChange`, and configured-view closures check owner identity. `LiveAppearanceSettingsCoordinator.invalidate()` clears its own callbacks but does not revoke `AppearanceSettingsCoordinator.applyPreferences`.

Source trace: retain the old `live.persistence`; install a replacement store/owner after the old owner is clean; call the retained old explicit `apply(C)`. Its callback still reaches `self.applyAppearancePreferences(C)` because the replacement is normally not flushing. The current grid can display C even though current requested/durable state belongs to the replacement store. There is no epoch/identity check at this callback boundary. The old command's storage write need not be prohibited to prevent its presentation callback from controlling the new owner.

**Likely root cause:** The pre-existing durable-command presentation callback was not included in the new owner-identity revocation boundary.

**Recommended solution:** Guard the persistence presentation callback with the identity/generation of its originating installed owner, using a capture arrangement that avoids a retain cycle. Keep historical accepted I/O owned; revoke its authority over replacement presentation.

**Affected scope / regression risks:** AppDelegate appearance installation callback. Must not break a current valid explicit Apply or the suppression of stale A receipts during a live flush. Existing old-view callback tests cover view closures only, not the retained base owner.

**Proposed Main regression:** Retain old `live.persistence`, replace the owner, invoke old `apply(C)`, and assert replacement presentation/requested state is unchanged. Invoke the current base owner to ensure the valid command still functions. Confidence: high; source trace, no application execution.

### F4 — [P2] Equal healthy capacity submissions still start disk writes

**Evidence:** `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift:59–75`: the equality fast path applies only when `pendingCount > 0`. Once idle, submitting the already-loaded or successfully persisted current capacity increments generation, clears the receipt, starts an asynchronous store write, and enables Quit protection. The store intentionally performs real atomic replacement even for equal-value retries, so this is not removed downstream.

Concrete trigger: with a healthy saved5×7 grid already selected, scoped Restore Defaults forces that same shape through the owner; repeat after each completion and each action writes again. A plain equal submit after successful drainage has the same effect. This conflicts with the approved equal-values/no-redundant-work acceptance requirement and can turn an unnecessary write failure into a save failure/Quit prompt for an unchanged setting.

**Likely root cause:** Coalescing was implemented for active work but omitted the healthy, fully acknowledged idle case.

**Recommended solution:** Add a healthy-idle equality fast path based on the actual loaded/acknowledged state. Do not skip equal-value retries after failed/indeterminate receipts, supported corruption recovery, or missing-payload explicit creation. No store changes are requested.

**Affected scope / regression risks:** Capacity admission only. Preserve one active+latest queue and post-rename failure retry semantics.

**Proposed Main regression:** Equal submit with healthy loaded state and after a successful receipt causes no extra store call/generation/quit protection. Equal submit after failure still writes, and explicit corrupt recovery still reaches the store. Confidence: high; source trace.

## Bounded positive checks and remaining acceptance gates

- Live submission validates ranges and inspects current payload before admission. Future payloads reject; ordinary corrupt changes reject; delayed save rechecks corruption/future protection. Save failures retain requested values and Quit protection. Normal owner replacement refuses to discard accepted failed live work.
- Close/hide composition flushes rather than restoring the prior committed draft. View callbacks validate owner and current view identity. Quit flushes a still-debounced live intent before its fast path and combines live failure with asynchronous capacity/workspace/Library drainage and existing user decision protection. Final teardown revokes view/presentation callbacks. These are static observations, subject to F1–F3.
- Capacity owns one immutable active write and one replaceable latest queued write. Actual successful intermediate receipts remain tracked; newest failure retains the latest requested shape, keeps Quit protection, and does not claim it durable. Invalidation suppresses callbacks while retaining admitted active/queued I/O. AppDelegate's live dropdown composition queues presentation after admission without waiting for the disk receipt; direct coordinator submissions alone are not the UI admission path.
- Capacity presentation retains folder/Library/editor/gesture gates, the current stable anchor, catalog/query identities, and existing paging operations. No changed physics was identified in the bounded code. The appearance gate's lack of an explicit `isDirectNavigationActive` clause is not reported as a bug: current Core direct navigation is settling and the existing state/pin guard already blocks it.
- Wallpaper background loader retains a worker through its closure, bounds work to one active render plus newest pending input, keeps active true during potentially reentrant completion, and performs render work off the main thread. The controller generation/host checks reject stale results. The existing background worker test asserts burst coalescing; it does not itself measure UI latency, memory, or physical paging performance. No unowned/unowned-self capture was found in this worker.
- Read all requested new/changed tests; none were executed. They cover live burst/debounce, close flush/no rollback, corrupt/future handling, ordinary during-save newer intent, capacity bounded queue/receipt/failure/retry/timeout/invalidation, old view closures, and live Quit integration. Add the specific missing cases above. Main must provide focused and full results on repaired hashes; a test source is not a test PASS.
- UIworker owns controls/layout, six-tab composition, localization presentation, and view-level acceptance. Physical continuous response, all languages/sizes, memory/latency and persistence across restart remain unverified here. No scope questions require a user decision at R1.

## Reviewed SHA256 snapshots

Paths below are repository-relative. New means absent from the supplied baseline manifest, not a Git status assertion.

| File | Baseline SHA256 | Reviewed SHA256 |
| --- | --- | --- |
| `Sources/PagingPrototypeApp/LiveAppearanceSettingsCoordinator.swift` | new | `123e96d5a1064ab566765dae0d6e7b59f6a4cb0056b4576bc8c52982d7c449df` |
| `Sources/PagingPrototypeApp/AppearancePreferences.swift` | `66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13` | `111bec846834304f5d96fbec850d6134da2242407fb7e0c70b666c64b2aa7648` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `9bb359d93351b5d8d5a7ba3505f54d9eb73d8fa3afc606895e850c37407de4e5` | `5c53600893cd2f5d7ca17a575d3c3e509218539c302853a2b835bff31dae3337` |
| `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift` | `34b90c4e0d077489e46a7fd670bb66ae99ce54247c677e9c0711241dd53e502b` | `4ca9bae080ba908ba4d5c08a187505c434ff09b81186c89fc2dfff7216eab6b1` |
| `Sources/PagingPrototypeApp/WallpaperBackdropView.swift` | `4261f9b357a976a2fd18c7b7bdbea65beb41eeaa7de4891f8cb1d53ae9d656f7` | `0d6f3ea0b57ebc867a7ee62213db867ad6f124556521aa4c5e77a1746f227e78` |
| `Tests/PagingUITests/LiveAppearanceCoordinatorTests.swift` | new | `f8801c29261a35f26f354e4ab57fdf2dcd474f5b4889c76d20f24f7dad5c78f8` |
| `Tests/PagingUITests/LiveWallpaperRenderTests.swift` | new | `426f5f1401646bed8a3eb7f8369d0df9674c41adab8c39b3e13aaae0f3e73cb1` |
| `Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift` | `44b01928621febc37a4092fec46a5a360d19dd470fe799ed658dc585b4743ccd` | `5296ec02ac93a4b16f8b6338e1fd221aaa76ee7a0043885800307e78c5b9970a` |
| `Tests/PagingUITests/MainGridCapacityCoordinatorTests.swift` | `29701c026edc41bd4ff080b8ce22d9d82ad9607fb7ad808fe9ed657ad4037219` | `d70843b4dcc5b266fd987f7c97e10b005e4fc947979b5bbcd80c771e3285069a` |

## Next action for Main

Review F1–F4, repair within the approved contract, and attach the focused/full execution results and latest assigned-file hashes. Revalidate this review against the repaired sources; do not relabel R1 or earlier physical evidence as acceptance for a later source snapshot. All coordination/questions for this reviewer belong in this report through Main.

## 2026-10-17 concurrent-source revalidation addendum

The final delivery hash pass observed a concurrent Main edit in `LiveAppearanceSettingsCoordinator.swift`; the other eight assigned files still matched the table. Read the entire updated live owner. Its latest observed SHA256 is `72b11d1c0ad0ec18266814850ba66e19a958e3d966843b9ba966da97c4d2fb30` (supersedes that file's reviewed hash above). The update annotates the scheduler with MainActor, moves its default selection into the initializer, and publishes status on a healthy equal-value submission. These do not repair F1 or F2. F1's corresponding current lines are79–91 and101–106; F2's ownership/state behavior is unchanged. F3/F4 inputs were unchanged at this pass. **Revalidated bounded verdict remains SOURCE FAIL.** No tests or builds were run by this reviewer. Subsequent edits after this observation are outside the recorded snapshot until reviewed.

## R2 — Repair revalidation, 2026-10-17

**Latest bounded verdict: SOURCE PASS. F1–F4 are resolved in the R2 snapshots below.** This supersedes the R1 verdict for these snapshots only; all R1 findings and historical evidence above remain intact. No additional blocking correctness finding was identified in the same assigned owner/composition/render-worker scope. This is not a full-product, UIworker, physical-input, performance, restart-durability, or full-suite acceptance claim.

### Review method and limits

Read the repaired live owner, appearance persistence coordinator, capacity owner, changed AppDelegate appearance installation/configuration/preview guards, Quit/teardown and capacity composition, and the requested test changes. Wallpaper source and its burst test match the already-reviewed R1 hashes. Compared repairs with the exact R1 source traces and named implementation changes; the supplied initial baseline remains hashes only. Two R2 hash passes matched all nine assigned files, including Main's final weak-capture binding and the two newly added regression methods. Main can continue broader tests and unrelated old-contract test adaptation; this report does not freeze the tree.

Only this R2 section was appended. No source changes, builds, tests, UI actions, application execution, process or Git actions, reference-project access, OS changes, or formal-data access were performed by this reviewer. Existing logs were read, not generated here. No new agents or scope requests were needed.

### Finding closure evidence

| R1 finding | R2 source evidence | Disposition |
| --- | --- | --- |
| F1: nested flush cancels the latest debounce / false Saved | `LiveAppearanceSettingsCoordinator.swift:79` now checks `isFlushing` before touching the scheduled cancellation and returns `.encodingFailed` for the nested attempt. B's debounce remains armed; the outer A receipt still cannot clear B because its generation differs. The later B timer flushes B without a second interaction. No retry loop or additional queue was introduced. | Resolved |
| F2: valid explicit command leaves stale live state | `AppearancePreferences.swift:129,150,159` adds a success-only `onAcknowledged` hook, including healthy unchanged commands. The existing changed-only `applyPreferences` callback semantics remain. `LiveAppearanceSettingsCoordinator.swift:114` reconciles an acknowledged command by advancing generation, cancelling an older debounce, updating requested/save state and previewing through its owner. AppDelegate binds this hook and suppresses it while a live flush owns the receipt. | Resolved |
| F3: old retained base callback controls replacement | `AppDelegate.swift:2312–2318` constructs the installed base with a no-op changed-only presentation callback and binds `onAcknowledged` using weak self/coordinator captures, current base identity and current live-to-base identity checks. An old explicit command can complete against its own store but cannot present through the replacement. The captures do not create an owner retain cycle. | Resolved |
| F4: equal healthy idle capacity forces I/O | `MainGridCapacityCoordinator.swift:65–73` restricts the no-write acknowledgment to idle, non-recovery, matching requested/committed values with healthy loaded state and nil/successful prior receipt. It sets `.saved` for feedback without advancing generation or starting work. Failed/indeterminate receipts, missing/corrupt payloads and explicit recovery cannot take this path. `drain` at lines124–125 returns `.nothingPending` when no actual writer generation exists. | Resolved |

The explicit command remains a valid API; closure of F2/F3 does not require healthy live controls to use it. Their actual `onChange` path still admits immediate preview and debounced persistence. Acknowledgment during a live flush is suppressed so an older receipt cannot publish a newer-intent rollback. Reconciliation checks generation again after arbitrary status callbacks before previewing.

The cancellation-aware nested regression at `LiveAppearanceCoordinatorTests.swift:136` is material: its clock records cancelled callback indices, and the regression executes only uncancelled callbacks. It therefore cannot pass by accidentally running the timer the R1 implementation cancelled. The older burst tests deliberately also invoke stale callbacks to verify generation rejection; these are different checks.

Read the new changed-command/reopen and retained-old-command integration tests at `AppearanceDraftCloseIntegrationTests.swift:211,237`, the unchanged-command regression at line225, and the new post-preview corruption test at `LiveAppearanceCoordinatorTests.swift:108`. The unchanged-command case exercises acknowledgment even when the existing changed-only callback does not run; the corruption case asserts no write, retained Quit protection and explicit recovery before successful persistence.

### Retained contract checks

- Continuous preview remains separate from the single200ms common-mode persistence debounce. Failure keeps latest intention and Quit protection. End/close/Quit flush composition and no-rollback close semantics remain in place.
- Corrupt/future payload admission and flush checks remain; no automatic repair or programmatic-default write was introduced. Current explicit supported recovery remains intentional.
- Capacity still has one active immutable write plus one replaceable latest queued write, keeps actual receipt ownership and failed requested intention, and previews the admitted dropdown request through the existing safe transaction before disk acknowledgment when idle.
- Re-read presentation gates, owner-replacement protection, Quit drainage and final teardown. The actor-isolated appearance teardown remains present; identity-gated callbacks and accepted asynchronous capacity I/O ownership remain intact. No capacity relocation or physics change was identified in the reviewed repair.
- Wallpaper active+latest worker and its generation-guarded completion path are byte-identical to R1. UIworker view ownership and other dirty files remain outside this verdict.

### Execution evidence read from Main's existing logs

- `owner-review-red-r1.log`: XCTest reports **4 executed methods /10 assertion failures**, specifically the F1 nested flush, F2 explicit-command/reopen, F3 retained-old-command, and F4 healthy equal-idle cases. This corroborates R1 with actual failing execution supplied by Main.
- `focused-r3.log`: XCTest reports **84 executed tests /0 failures**,6.756 seconds test time (6.768 seconds selected-suite wall time). All four named R1 regression methods explicitly pass in this log. The trailing separate Swift Testing message reporting0 tests does not replace the nonzero XCTest result.
- The latest source adds `testUnchangedExplicitCommandCancelsAnOlderUnsavedLiveIntention` and `testNewCorruptionAfterPreviewRequiresExplicitRecoveryBeforeWrite` after that84-test run; neither method appears in `focused-r3.log`. Their source was reviewed, but this report does not claim their execution or claim that the84-test log corresponds to every latest file hash. Main's broader run and latest-source association remain separate pending evidence at this review boundary.

Log SHA256: `owner-review-red-r1.log` = `4688c0ece3fbd58e97a9ab5c6d7000dbca390e2e30f9ac09288372c749cf58b1`; `focused-r3.log` = `be06f17c10040d00ec6731c9c3977da2312ce4e98305b7d2d69eb61ecf449b18`.

### R2 reviewed SHA256 snapshots

| Repository-relative file | SHA256 |
| --- | --- |
| `Sources/PagingPrototypeApp/LiveAppearanceSettingsCoordinator.swift` | `7a8db7f3a97bd7874a51a817c70614d487d07dbdaf01f8cade4933a584b59bc3` |
| `Sources/PagingPrototypeApp/AppearancePreferences.swift` | `d921d64686133f631782e10670977da5b5dc0da173d20803e8dda5dfb38a0c27` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `c59446474091bcdc8dfc581782a441c8202b522213e93931f0a7b65dcca55543` |
| `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift` | `51caee76a386f6157b93cf9c7a51beb2f0a6d02a33cc2e0ac571feeeeeb2dfbb` |
| `Sources/PagingPrototypeApp/WallpaperBackdropView.swift` | `0d6f3ea0b57ebc867a7ee62213db867ad6f124556521aa4c5e77a1746f227e78` |
| `Tests/PagingUITests/LiveAppearanceCoordinatorTests.swift` | `8d037d8c65820c6f9d8cea3954c42e6f351690fff4d8675fb7ca19666f5e87e8` |
| `Tests/PagingUITests/LiveWallpaperRenderTests.swift` | `426f5f1401646bed8a3eb7f8369d0df9674c41adab8c39b3e13aaae0f3e73cb1` |
| `Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift` | `b93e9b6922c4945cd9877cad105cdba2437e811ab6e96802a55da6023fb7f30b` |
| `Tests/PagingUITests/MainGridCapacityCoordinatorTests.swift` | `1ee544f5bf1554b2eb2db6b558d4132db30c0b96a2054702d5d60e422bf95106` |

### Main handoff

No further repair is required for F1–F4 on these hashes. Complete the broader execution and associate its results with current sources, including the two additional methods. Keep UI review, physical/performance gates and restart acceptance distinct. If subsequent core edits affect the reviewed behavior, revalidate those edits rather than extending this SOURCE PASS to unreviewed snapshots.
