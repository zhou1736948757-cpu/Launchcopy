# Launch Activity Integration Source Review R2

Verdict: **SOURCE-ONLY FAIL — one remaining P2 startup-order scenario in I-02.** I-01 is closed. I-02 is fixed after activity loading, but an accepted Library-OFF action during the initial activity load can still be lost. No P1 finding established. This verdict concerns the exact current sources identified below, not native behavior, performance, packaging or release acceptance.

## Scope and authority

Same independent integration task as R1. Read the repository AGENTS.md, approved `Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md` including its appended privacy failure clarification, stage summary, R1 report, current coordinator/owner repairs, English fallback and three localized help entries, and regression test source. The project remains a SwiftPM/AppKit application with main-actor owners and asynchronous stores/projections. Foundation/domain/store semantics were not re-reviewed; their source hashes are unchanged from the previous reviewed manifest.

Only `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R2.md` was written. No source/test edits, builds, tests, UI, OS actions, formal data access, reference access, Git operations, agent dispatch, or other workflow writes were performed. Main owns all executing verification jobs.

## Repair conclusions

### I-01: CLOSED in source

`LaunchActivityCoordinator.swift:97-105` now queues the privacy-OFF document with `clearing: isClearing`. Both active Clear and queued Clear therefore propagate the outstanding completion marker into the latest OFF snapshot. The original Clear receipt remains unable to settle a superseded revision; only the newest successful receipt at `:187-189` releases `isClearing`. The OFF snapshot keeps the cleared entries empty and revokes earlier observations through generation changes.

A failed newest OFF save leaves clearing/admission blocked and Quit-protected. `retry()` at `:160-163` preserves the same marker and empty OFF document; its successful current receipt finishes Clear. It does not restore the older enabled/history document. An eventual explicit activity ON can work after that success.

The regression `testReviewClearThenPrivacyDisableSettlesBothActiveAndQueuedClear` (`LaunchActivityCoordinatorTests.swift:269-295`) covers active/queued Clear crossed with successful/failed final OFF saves and retry. It checks the final empty OFF document, released clearing state, and successful explicit re-enable request. This is an appropriate source regression for the original defect; this reviewer did not execute it.

### I-02: Loaded-state failure and unrelated-save cases CLOSED in source

`AppLibraryOwnerController.swift:92-100` now performs two distinct operations for Library OFF: immediate Library admission revocation and `activity.setEnabled(false)`. Once activity is loaded, the second operation changes the activity document itself to OFF before awaiting any save. It retains existing history and submits an independent OFF snapshot. Library receipt reconciliation may accurately restore the acknowledged Library-ON state, but cannot change the OFF activity document. Neither unrelated Library saves nor Library re-enable call `activity.setEnabled(true)`.

If the activity OFF save fails, the in-memory OFF decision still prevents admission, and the failure remains under existing retry/Quit protection. A successful OFF receipt makes that decision durable. Only the explicit activity-settings ON callback (`owner :104-108`) requests activity re-opt-in. The existing durable-enabled admission requirement remains in place for an OFF receipt followed by ON.

The latest `testReviewFailedLibraryDisableNeverAutomaticallyResumesRecording` (`LaunchActivityCoordinatorTests.swift:297-331`) loops over failed/unavailable/protected Library receipts, verifies no fresh observation and no resumption after an unrelated successful Library save, then explicitly invokes activity OFF/ON and checks resumed admission. It intentionally awaits both initial loads before requesting OFF. That precondition leaves the startup-order scenario below uncovered.

### Privacy copy and composition

The appended specification and English fallback/English/Simplified Chinese/Japanese help consistently explain that Library OFF also switches recording OFF, retains history, and requires explicit recording ON to resume. The 24-key enumeration is unchanged; no schema/status key was added. Existing scroll/nested-layout repairs, launch observer, projection timestamp wiring, action identity/lifecycle checks, profile isolation and Quit integration match the earlier reviewed versions. No additional layout finding was identified; longer help still uses the existing wrapping/vertical scrolling composition. No native fit or accessibility result is asserted.

## Remaining finding

### I-02-R2 — [P2] Initial activity load can overwrite an accepted Library-OFF decision

**Locations:** `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:76-82,88-100,286-292,332-335`; `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift:17,62-80,95-107`; `Sources/PagingPrototypeApp/AppLibrarySettingsView.swift:164-165`.

**Concrete scenario:** Previously saved Library and activity preferences are both ON. At startup the Library preference load completes, while the separate activity store load is still awaiting its result. The user opens settings and unchecks the parent Library control in this interval. Let the Library-OFF save fail and then finish the activity load with the previously saved enabled document. No activity ON action occurs.

**Evidence / state trace:**

1. Owner attachment loads preferences before awaiting activity. The preferences coordinator sets its `isLoaded` and calls the owner on change before the activity load completes. `renderSettings` supplies only `preferences.isLoaded` to the parent control, whose availability uses that flag. The owner Library callback checks transition readiness and Library pending count, not activity readiness. The production transition gate also has no activity-load condition. Thus the parent Library-OFF request can be accepted in this interval; the activity child's waiting/disabled state does not disable its parent control.
2. The new OFF callback correctly sets `activity.libraryEnabled = false`. However, `activity.document` is still its default OFF document. `activity.setEnabled(false)` misses the `!value && document.enabled` branch, then returns false because `canWrite` requires `isLoaded`. No OFF snapshot or deferred OFF decision is retained. The caller discards this return value.
3. A failed Library receipt restores the acknowledged Library-ON permission through `preferencesChanged`. Independently, the activity load unconditionally assigns the stored ON document to both `document` and `persistedDocument`. It checks active ownership but does not reconcile the earlier accepted OFF decision. Whether the failure receipt or activity load finishes first, the terminal state has Library permission ON, activity document/durable preference ON, and a healthy/missing latest activity save result. New observations are admitted without explicit recording ON.
4. Even with a successful Library-OFF receipt, the delayed activity load leaves the recording preference ON. Later enabling only Library then resumes recording, contrary to the explicit re-opt-in clarification and help. This variant needs no preference-save failure.

**Impact:** An accepted privacy stop can be undone by startup I/O completion, or by a later Library-only enable. No pre-disable token replay is necessary: newly prepared launch observations can record. This is the same stop/no-automatic-resume contract as I-02, not a proposal for broader collection policy.

**Likely root cause:** The repair relies on activity already being loaded so `setEnabled(false)` can create an OFF snapshot. Owner/UI readiness does not establish that precondition, and initial load assignment does not preserve an OFF decision accepted during the await.

**Recommended solution:** Sequence initial activity readiness with availability/acceptance of the Library toggle, or otherwise reconcile an accepted Library-OFF decision before publishing a late loaded ON document. Keep truthful persistence receipts and preserve history. No new schema/status is required; do not silently acknowledge a privacy OFF that will be overwritten by load.

**Affected scope / regression risks:** Owner startup/settings wiring and activity initial-load reconciliation. Main can cover this with a controllable suspended activity load and a completed Library preference load: accept Library OFF before releasing the activity load, then finish failed/unavailable/protected Library receipts and the old ON load in both orders. Check no fresh admission and no unrelated-save resumption. Also cover successful Library OFF followed by Library-only ON: recording must remain OFF until explicit activity ON. Verify the retained history and OFF receipt/error handling rather than clearing data. These are review recommendations, not jobs or source edits performed here.

**Confidence:** High from direct main-actor/async state analysis and existing control-readiness conditions. No runtime reproduction was executed by this reviewer. It requires the initial asynchronous activity load to overlap an otherwise allowed settings action; the code imposes no ordering that rules it out.

## External verification evidence and limits

- Read Main's preserved `review-red-r1.log`: the two original regression methods executed with seven assertion failures before the repairs. The final Swift Testing zero-test footer is not the XCTest count.
- Read Main's `focused-r3.log`: 149 XCTest methods, zero failures, 9.425s. This establishes Main's executed focused evidence, not a reviewer-run test. The subsequent extension of the I-02 method to three receipt failures is present in the current source; Main reports focused-r4/full-r2/Debug/Release/package verification in progress. This report does not assign those pending jobs a result.
- Main reports prior full-r1 3029/0 and Debug/Release/package candidate r1 complete, with r1 never launched because of the findings. Those prior results do not execute the newly identified suspended-initial-load case and do not certify the current repaired candidate.
- No tests, builds, runtime, native opt-in/off/clear/restart cycles, physical performance or human acceptance were performed by this reviewer. Passing focused tests after awaiting initial loads do not resolve the remaining source scenario.

## Freshness and exact inspected inputs

Review readback UTC: `2026-10-17T16:01:05.066180+00:00` (2026-10-18 Asia/Tokyo). All 500 current source inputs matched `source-integrated-r3.json` immediately before this report was written.

- Current manifest: `.build/verification/20261018/library-launch-activity/source-integrated-r3.json`; SHA-256 `5d1446cdb901108ad32234ac3e41ff34dc7fb226357af065d4b4c2cb940e4c5b`.
- Previous reviewed manifest: `source-integrated-r2.json`; SHA-256 `5f10d4a2ee3694383b6a908fb0cd9ed6b9f8f67bda69fd8fcd4674cffe4698d7`.
- Compared all 500 hashes: six production files and one test file changed; all other 493 inputs, including foundation/domain/store and settings composition, matched the prior review.

| Re-read changed input | SHA-256 |
| --- | --- |
| `Sources/LauncherLocalization/LaunchActivityTextKey.swift` | `395fe96bc9ce2ca47519192c213bd2c5cc3482d18ae1c77367d784618ab6bfbf` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | `d4d7d88a21c56a7728e4db3aa12e68463638edaafdd21b195f6d214e217a1816` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | `dcf242ae1f9c638587967b7b9469a35878c6b236a267b2a93179ae5023e5b1f7` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | `a4eeb0886cfb7f15960153ef2691e99042c358661816a0530f0b796b93e9ba73` |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` | `e65df164d72c9602adfa6c68fa6f71d25cf896ab15ab2438daa6798024b91c84` |
| `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift` | `1660c099b88caf3c8024eff79739a6df8434ca1c15be4684f447cb216bb96040` |
| `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift` | `20d9e74e559720a1938f75d738e4e8efda1eb7a9531cf91c436124d6a8c8586e` |

| Supporting reviewed input | SHA-256 |
| --- | --- |
| `AGENTS.md` | `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc` |
| `Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md` | `73caa71f5f30dcea8d1517bdd681d24092d4eae512f285464b5d9274c6759335` |
| `Workflow/stage-summaries/2026-10-18-library-launch-activity.md` | `97e65642ee9f1ebedfb37899ba41889cd0c51111c667a7ca593177a176c89cbe` |
| `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R1.md` | `72def3ae30b7129af25928b8d4035cf2d4818f28f942a724c12cee107dee6ff7` |
| `.build/verification/20261018/library-launch-activity/review-red-r1.log` | `b3c53441090da2f4ce22c84ee137950e75ee3cda2b4813931d190beb8771c4db` |
| `.build/verification/20261018/library-launch-activity/focused-r3.log` | `b4dd6a4968e83905e998f0a73a85c2e253c1d7eed06fe2c1d0a895ae4687748f` |

This R2 supersedes R1 only for the exact repaired versions and scenario dispositions stated here. R1 remains intact. Any subsequent change to the coordinator/owner/readiness sequencing needs a fresh bounded review; this report makes no stale-source PASS claim.

Next handoff: Main owns repair/verification of I-02-R2 before an integration SOURCE PASS. No new behavior, release gate, or architectural authority is asserted by this reviewer.

Changed files by this reviewer in this R2 task: `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R2.md` only.
