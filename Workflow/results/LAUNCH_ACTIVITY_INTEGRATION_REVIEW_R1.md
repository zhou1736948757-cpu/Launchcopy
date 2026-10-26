# Launch Activity Integration Source Review R1

Verdict: **SOURCE-ONLY FAIL** — two concrete P2 integration findings remain in the inspected r2 sources. No P1 finding established. This is not a native, runtime, performance, packaging, or overall release verdict.

## Authority and scope

Reviewed the repository AGENTS.md, the human-approved `Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md`, and `Workflow/stage-summaries/2026-10-18-library-launch-activity.md`. The project is a SwiftPM macOS AppKit application with shared catalog/launch services, an optional same-window Library, main-actor owners and asynchronous persistence/projection workers. Existing Library receipt semantics and lifecycle protections remain the architectural baseline.

This independent review covers activity admission/coalescing/receipts/clear/Quit, settings composition, the optional common-launch observer, activity sections and actions, and AppDelegate/profile wiring. The foundation reviewer owns pure store/domain semantics; those files were consulted only to establish interface behavior and were not independently re-audited here. The foundation SOURCE PASS reported by Main does not close these integration findings.

No implementation source, tests, settings, formal data, reference material, Git state, workflow state, or other report was modified. No build, test, UI, native application, OS action, Git operation, or additional agent was run. Main retains the serial verification lane. The sole written artifact is this report.

## Findings

### I-01 — [P2] Privacy disable during Clear permanently strands the clearing state

**Location:** `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift:97-103`, `:136-143`, `:164-187`. UI reachability: `AppLibraryOwnerController.swift:99-102,260-267` and `LaunchActivitySettingsView.swift:129-139,157-166`.

**Concrete scenario:** Start with durable activity enabled and retained history. Confirm Clear History, leaving its asynchronous save pending. Before that receipt completes, uncheck recording. This is deliberately allowed by the child view while busy and accepted by the coordinator's immediate-disable branch. Then allow the writes to succeed.

**Evidence and outcome:** Clear sets `isClearing = true` and queues a `clearing: true` snapshot. Disable changes the document to OFF and calls `enqueue(document)` with the default `clearing: false`, advancing the revision. If Clear is active, its receipt is now older than `revision` and skips the only clearing-completion assignment. If Clear is queued behind an older write, the OFF snapshot replaces it outright. The last successful OFF receipt also cannot clear the flag because its own `clearing` field is false. The final state is an empty persisted OFF document, `pendingCount == 0`, `latestSaveResult == .saved`, but `isClearing == true`. `setEnabled(true)` continues to reject; the settings owner disables enable/clear and offers no retry for a successful save. Restart is required to recover normal operation.

**Likely root cause:** The coalesced snapshot carries the cleared data but loses the outstanding clear-operation completion semantics. Clearing completion is tied solely to the newest snapshot's default-false marker.

**Recommended solution:** Preserve the outstanding clear completion through a privacy-disable snapshot, and settle it only from the current durable empty-document receipt. Keep immediate privacy disable available. Do not resolve this by blocking disable, accepting an obsolete receipt, or restoring pre-clear data.

**Affected scope / regression risks:** Clear, coalescing and the tracking checkbox. Cover both active-Clear and queued-Clear followed by disable, including a failed final save and retry. Expected terminal success: OFF and empty, no old token accepted, clearing released, subsequent explicit enable works. These are repair verification requirements for Main, not tests executed by this reviewer. Existing clear-supersession and clear-failure tests do not interleave disable.

**Confidence:** High; a direct main-actor state trace using the existing permitted UI path, independent of store implementation details.

### I-02 — [P2] Failed Library-OFF persistence silently restores activity admission

**Location:** `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:88-95,281-287`. Receipt behavior establishing the scenario: `AppLibraryPreferencesCoordinator.swift:59-76`; admission gate: `LaunchActivityCoordinator.swift:42-45,87-91`.

**Concrete scenario:** Library and tracking are durably ON. The user unchecks the Library control. Its accepted asynchronous preference write returns `.failed` (for example, a write failure in the separate Library directory), while the activity store remains writable. After the failure the user launches an app from the main grid without explicitly enabling Library again.

**Evidence and outcome:** The request immediately sets `pendingLibraryEnabled = false` and stops activity admission. When the failed preference receipt arrives, the preferences coordinator correctly retains the prior committed Library-ON value. However, `preferencesChanged()` unconditionally clears `pendingLibraryEnabled` whenever `pendingCount == 0`, then calls `setLibraryEnabled(true)` from that old committed value. The activity document and its durable opt-in are still ON, and its own save state is healthy, so `isCollecting` becomes true again. A newly prepared main-grid observation records the next accepted launch. Activity sections can also return. Generation invalidation rejects pre-disable tokens but does not prevent these newly admitted requests.

**Likely root cause:** A transient Library pending-edit value doubles as a privacy admission latch. Receipt reconciliation for a failed Library preference edit inadvertently acts as a new privacy enable decision. This differs from the activity coordinator's own OFF path, which preserves stopped admission after a failed activity save.

**Recommended solution:** Keep the accepted Library-OFF privacy stop latched through failure/reconciliation until a subsequent explicit authorized enable. Continue showing the truthful Library persistence failure and committed receipt state; do not change the existing Library store schema or fabricate a successful OFF receipt.

**Affected scope / regression risks:** Library settings-to-activity integration. Verify accepted OFF followed by failed, unavailable, or protected receipts never admits fresh observations, including after unrelated preference callbacks. Successful OFF must retain data without admission; a later explicit enable must still work and old tokens must remain revoked. Existing tests cover generic Library receipt reconciliation and direct activity OFF, but not this combined failure path.

**Confidence:** High for the state transition and resumed recording; classified P2 because it requires a Library save failure. The approved contract promises immediate stop on Library disable, not automatic resumption from a failed save.

## Other inspected integration boundaries

These observations are bounded source findings, not exhaustive guarantees:

| Boundary | Source assessment |
| --- | --- |
| Default OFF / initialization | No finding. Coordinator construction initializes memory only; a missing load does not enqueue a write. `AppDelegate.init` does not install the activity store. Owner attachment performs the lazy loads. |
| Receipt-aware initial enable | No finding. `isCollecting` requires both in-memory enable and a durable enabled document; the initial pending opt-in cannot admit observations. Failed activity saves stop admission and remain Quit-protected. |
| One-shot pre-executor observation | No finding. The common controller validates served revision, hidden state, URL and existence before preparing the observer; only an executor acceptance invokes completion. The closure is one-shot and rechecks owner generation, active state and admission. Failure and rejection do not count. |
| Common launch routes | No alternate execution path added. Library direct requests use `handleApp`; cell/keyboard/folder/context routes retain the existing controller pipeline. The neutral launch outcome and telemetry remain separate from history persistence. |
| Clear and old-data resurrection | Apart from I-01's completion-state defect, serial active-plus-latest writes and clear's generation increment prevent an older queued document or prepared observation from becoming the final post-clear success. Failed clear remains blocked and Quit-protected rather than claiming durable erasure. No crash or forced-quit durability claim is made. |
| Coalescing / teardown | One active task plus one latest pending immutable document. Hiding does not cancel accepted writes. Invalidation revokes observations and suppresses UI callbacks while accepted writes retain ownership. |
| Sections and identities | Activity filtering receives the existing catalog/management/query projection and preserves catalog revision/count meaning. The view reuses details/actions. Owner resolution checks open state, action generation, current catalog revision, canonical URL, hidden state and current projected membership. Close/source invalidation reject stale requests. |
| Projection expiry / injected clock | Current owner passes `activity.projectionDate` as `activityNow`; the projection worker uses the immutable request timestamp. Pruning occurs on load/update and filtering occurs off the frame path. This is no claim of periodic physical erasure or continuous idle-time refresh. |
| Clear confirmation | AppDelegate uses an explicit Cancel/confirm sheet, captured activity generation, current owner/activity identity and lifecycle checks. Cancel performs no clear. Recovery likewise remains explicit. |
| Profile / metadata fail closed | Unresolved requested profiles return nil instead of formal activity storage. Existing injected Library-only installation leaves activity nil; injecting both uses the supplied activity store. `UITestProfile.resolve` validates the added LaunchActivity directory. Startup metadata validation precedes delegate construction; invalid metadata/profile resolution rejects startup. No formal store was opened by this review. |
| Quit | Activity pending writes/failures participate in the existing bounded Quit drain. AppDelegate checks the captured activity-owner identity after drain. Cancel remains the existing default. Source inspection does not certify a native Quit/reopen cycle. |

## Scroll container and nested settings layout

The current `AppLibrarySettingsView` uses one vertical scroll container with a flipped document; its width matches the clip view, its leading anchor is now constrained, and its height may exceed the viewport. The outer stack contributes 24pt on each side, and the activity child's stack contributes another 24pt on each side: available child-control width is clip width minus 96pt. Wrapping help/status labels preserve required vertical resistance and allow horizontal compression; hidden retry/recovery controls detach from the vertical stack. No fixed child height was introduced.

The original new checkbox retained native horizontal compression resistance despite wrapping. Main's diagnostic log `scroll-geometry-r2.log` recorded a 361/356pt clip/document inside a 340pt root and the four unchanged 317pt margin assertions failing. A leading-anchor-only repair did not solve that minimum-width pressure. The current child explicitly sets the checkbox's horizontal compression resistance to `.defaultLow` and retains native wrapping/word wrapping; the full privacy copy and font size remain intact. Source inspection supports that repair. No additional concrete P1/P2 layout finding was identified in the current version.

Main reports `focused-r2` completed 147 methods / 0 failures in 10.916s, retaining the original small-pane assertions and adding diagnostic context only. This is **Main-provided verification**, not a test run by this reviewer. Earlier focused/scroll failures remain historical evidence. Native scrolling, keyboard reachability, accessibility and visual fit still belong to Main's native acceptance lane; this report does not claim those gates passed.

## Verification limits and handoff

This review executed zero builds/tests/UI jobs and made no native/performance claim. It found the above scenarios through source and state-transition analysis. The passing focused suite does not include the two cited interleavings, so it does not contradict the findings. Main's full-suite, Debug/Release and package work was in progress at handoff and is not certified here.

Repair and independent re-review of I-01/I-02 are required before an integration SOURCE PASS. Recommendations above restore the approved behavior; they do not propose a new feature or change the approval contract. No implementation or repair authorization is asserted by this reviewer.

## Inspected versions and freshness

Readback UTC: `2026-10-17T15:54:34.550373+00:00` (2026-10-18 in Asia/Tokyo). All 500 current inputs matched the r2 manifest at report creation. No claim attaches to subsequent source edits.

- Initial r1 manifest SHA-256: `314f5037f7d1ad94bfb4a547b93449440d1945c3e51f9cbb5c573afbbdd010b6`.
- Initial input delta SHA-256: `3f756b68098abcf48e3cf6fde5552b27ed910358d1002958f21521a3cbee3f6b`.
- Reviewed r2 manifest: `.build/verification/20261018/library-launch-activity/source-integrated-r2.json`, SHA-256 `5f10d4a2ee3694383b6a908fb0cd9ed6b9f8f67bda69fd8fcd4674cffe4698d7`.
- Re-read the reported r1-to-r2 edits: settings document leading anchor, checkbox horizontal compression/wrapping, coordinator clock accessor and owner timestamp handoff, updated launch observer header, added projection test, and existing layout-test diagnostic context. The r1-only review scope is therefore superseded by the exact r2 versions below.

| Inspected file | SHA-256 (r2) |
| --- | --- |
| `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift` | `ec974e61bdcce4b6654743312836d35efce1afd4a0b201837bda500793044822` |
| `Sources/PagingPrototypeApp/LaunchActivitySettingsView.swift` | `0d32ac9e21af6eb4957a4bf935cc3bbebebe7a7b7266eb7d90450f5c920994a0` |
| `Sources/PagingPrototypeApp/AppLibrarySettingsView.swift` | `9c288a6a93b721c53506b3dce71327532073ff3e4fb1d0dc45f09b3d16f6604c` |
| `Sources/PagingPrototypeApp/AppLaunchController.swift` | `e667013c8c0cbdc655ff455ac3238d156654d6572b7bf1cfbdbdfcbdd2c7f855` |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` | `d86270bc7003018b07ecfd644710f22bb027af84e518bd6d2dcb7b401d33cae2` |
| `Sources/PagingPrototypeApp/AppLibraryProjectionController.swift` | `09260096e3b753efd785cdfc57afb62ba460e11ece8d7a29fa632167459e95e9` |
| `Sources/PagingPrototypeApp/AppLibraryView.swift` | `0d44d2e54e92961bc62935378b0d6190ecb2f858820c584c0935c41ba92625c4` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `131baf58c5d79085aa14e891daccb196b693c529c8c477d3a4ecc8008153f71b` |
| `Sources/PagingPrototypeApp/LaunchActivityStoreLocation.swift` | `98ffdc83412be77e316bcf5d129e308ff59eea688c1207dc5e0a8a2deda90b6b` |
| `Sources/PagingPrototypeApp/UITestProfile.swift` | `bea67f46a1af898845c8c8d853468eed18f080b850c076b8a9ac922949226c1a` |
| `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift` | `ac4c53a4f0beb73c07dc3db0c0a972cb5feb8c49f394476f66d98d3802d452f4` |
| `Tests/PagingUITests/LaunchActivityLaunchObservationTests.swift` | `e41f42d21ea71f99361c5e054841d9cfa8e69c1cf9383084baed05c6f5eb8d8e` |
| `Tests/PagingUITests/LaunchActivitySettingsViewTests.swift` | `f217329491306942125c41f972d64b75c1979fb15dced272bfc71a6ae01606c0` |
| `Tests/PagingUITests/AppLibrarySettingsViewTests.swift` | `801de6d5ab1337e5cef4b8e59240366302f1137960ef9504b7dc3e975fcafdfe` |
| `Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift` | `59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0` |
| `Sources/PagingPrototypeApp/AppMain.swift` | `17fbe204c3fa2608ebca4f34a77084aab57f67247856a877e115ffedfcfe1c0c` |
| `Sources/PagingPrototypeApp/AppStartupPlan.swift` | `e97465d4fb81dc44c0ed1a551eb93b6e4843baa018ec5ff08120a07a8aeb92c5` |
| `Sources/PagingPrototypeApp/NativeUITestEntry.swift` | `020b92f9dfb37cfb84553c9b762417261bf0a1a64bf90c4f3c8cd4b8035f9396` |

Consulted foundation domain/store sources only for contracts, not a duplicate foundation verdict. Additional existing owner/profile/startup tests were read for call paths and coverage, not executed. The complete r2 manifest identifies their versions.

Changed files by this reviewer: `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R1.md` only.
