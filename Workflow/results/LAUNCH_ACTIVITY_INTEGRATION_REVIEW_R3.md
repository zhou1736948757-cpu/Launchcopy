# Launch Activity Integration Source Review R3

Verdict: **SOURCE-ONLY PASS for the exact r4 inputs below.** I-01, I-02 and its I-02-R2 startup-order variant are closed in this bounded integration review. No remaining concrete P1/P2 finding identified within the assigned scope. This is not a native, performance, package, release or human-acceptance verdict.

## Scope and execution boundary

Same independent integration review task as R1/R2, now limited to the coordinator initial-load/OFF/drain repair, its new regression source, and the prior clear/receipt/explicit-resume lifecycle. The repository remains a SwiftPM macOS AppKit application with main-actor integration owners and asynchronous persistence. Applied the previously read AGENTS.md and approved proposal including the privacy failure clarification; their hashes remain unchanged. Read the latest stage summary, current coordinator and tests, and rechecked owner OFF/ON wiring and AppDelegate Quit integration.

All 500 current inputs were compared with the r4 freeze. Only the coordinator and its test file changed from the r3 freeze reviewed in R2; the other 498 inputs, including foundation/domain/store, settings layout, localization, launch observation, activity projections, actions and profile routing, are unchanged. Foundation semantics were not re-audited.

This reviewer ran no build, test, UI, application, OS action, formal/reference data access, Git operation or agent. Main retains the verification lane. Only `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R3.md` was written. Earlier reports and RED evidence remain intact.

## Repair findings and closure evidence

### I-02-R2 initial-load privacy stop: CLOSED

- `LaunchActivityCoordinator.swift:108-118` accepts OFF while active and not loaded independently of the default in-memory OFF value. It retains `pendingPrivacyDisable`, increments generation, keeps the document OFF and returns acceptance. Repeated OFF requests retain the intent. ON still cannot pass `canWrite` before load.
- At `:68-93`, a supported loaded document is retained separately as the original persisted baseline. Pending OFF is merged into the working document before pruning and before `isLoaded` or any notification is published. These main-actor steps contain no suspension between assignment and merge. Thus listeners and new observations cannot see an enabled loaded document after the accepted OFF decision.
- Only a real difference from a supported existing document enqueues a snapshot. Existing history/salt are retained subject to the already-approved clock pruning; loading an existing ON document produces an OFF snapshot. An already-OFF supported document with no pruning needs no write. A missing document remains default OFF without creating a file or directory.
- Initial corrupt/unavailable/future/ambiguous/oversized results are not overwritten. For an accepted pending stop, `:77-86` publishes recovery-required/unavailable/protected failure bookkeeping rather than claiming a successful OFF receipt. The document stays OFF and unsupported load states cannot collect or write. Explicit corrupt recovery remains the existing separate operation.
- Library receipt completion can still truthfully restore the acknowledged Library-ON permission, but cannot restore the independently retained activity preference. This holds whether that receipt arrives before or after activity load: the pending OFF is merged when load completes, or the merged OFF is already present when the receipt arrives. Successful Library OFF followed by Library-only ON likewise leaves recording OFF. Only the explicit activity ON callback can request re-opt-in.

### Pending privacy decision and Quit: CLOSED

`requiresQuitProtection` (`:29-31`) now includes the pending pre-load OFF decision even when `pendingCount == 0`. AppDelegate's existing fast-termination guard reads this property and its accepted-owner drain calls activity `drain`; no extra Quit path was introduced.

`drain` (`:219-232`) waits for both the pending privacy decision and queued/active writes using the existing ContinuousClock deadline and cancellation/ownership checks. A zero deadline times out while the load decision is unresolved; it cannot return false `nothingPending`. Once load completes, a changed supported document moves directly into accepted-write ownership in the same main-actor turn. Successful save returns the actual receipt revision; failed save remains protected for retry/Quit. A missing/already-OFF unchanged document legitimately has nothing to save. Protected/recovery results return read-only, and unavailable returns failure. Teardown still invalidates ownership and observations; it does not turn recording on or publish a stale loaded document.

### Previous closures remain valid

- **I-01:** OFF continues to enqueue `clearing: isClearing` (`:120-128`). Active/queued Clear cannot lose its completion marker through coalescing. Only the newest successful marked receipt (`:210-212`) releases clearing. Failure retains the barrier; retry (`:183-186`) keeps the empty OFF snapshot and marker. Old observation generations remain revoked.
- **Loaded I-02:** The unchanged owner Library-OFF callback still immediately revokes Library admission and independently submits activity OFF. Failed Library receipts and unrelated saves only update Library permission; they do not enable the activity document. Retained history is not erased by OFF.
- **Explicit ON:** Activity ON remains a distinct action through the existing settings callback. It requires loaded/writable state, Library permission and no unfinished Clear. Initial/re-enabled admission retains the durable-enabled-document requirement. The new pending flag is consumed during load and does not strand later explicit enablement.
- Existing profile fail-closed routing, injected-test isolation, safe section publication/action identities, one-shot pre-executor observation, bounded coalescing and scroll/nested layout match the prior reviewed inputs. No new collection path, store/schema, monitor, or frame-path I/O was introduced by this repair.

## Regression source and external evidence

Read, but did not execute:

| Regression source | Bounded coverage inspected |
| --- | --- |
| `LaunchActivityCoordinatorTests.swift:347-376` | Suspends activity load after Library preferences are ready; accepts Library OFF, fails the Library receipt, releases the old enabled history document, then verifies OFF/no collection, history retention and one OFF save. This directly addresses I-02-R2 rather than waiting for activity load before the action. |
| `:378-399` | Pre-load accepted OFF and Quit protection; zero-timeout drain; missing/corrupt/unavailable/future/ambiguous/oversized results; no overwrite; missing resolves without pending work, other listed states remain protected/read-only or failed. |
| `:283-309` | Active/queued Clear followed by OFF, successful or failed newest save, retry and subsequent explicit ON. |
| `:311-345` | Loaded activity plus failed/unavailable/protected Library OFF receipts, unrelated successful Library save, and distinct activity OFF/ON before admission resumes. |

Read Main's preserved `review-red-r2.log`: the held-initial-load regression executed once with five assertion failures before the repair (0.980s). It remains historical evidence of R2's actual defect, not a failure attributed to current sources.

Read Main's completed `focused-r5.log`: **151 XCTest methods / 0 failures, 9.078s**. The held-load and protected/missing/timeout methods explicitly passed in that log. This is externally executed evidence from Main; reviewer-executed tests remain zero. XCTest counts, rather than the separate Swift Testing zero-test footer, establish execution.

Main reports full-r3/Debug verification underway and final package construction held for this source verdict. No result is assigned here to those jobs. Native r3 remains unstarted per Main; fixture preparation is not runtime acceptance. This SOURCE PASS does not certify Quit/reopen persistence on a launched candidate, native layout/accessibility, physical performance, or final delivery.

## Exact inspected versions

Readback UTC: `2026-10-17T16:05:52.263153+00:00` (2026-10-18 Asia/Tokyo). All 500 live inputs matched the r4 manifest immediately before report creation.

- Freeze: `.build/verification/20261018/library-launch-activity/source-integrated-r4.json`.
- Manifest SHA-256: `125aee0d8a816f8f1745c9f43ff11e61a345d339f21519b2160bfb27f55e6c7b`.
- Prior r3 manifest SHA-256: `5d1446cdb901108ad32234ac3e41ff34dc7fb226357af065d4b4c2cb940e4c5b`.

| Current source | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift` | `ad30f9bc438c2b2631ed085f6a8a61cd09103f923873a4558db4923f0b58eb21` |
| `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift` | `5ecf780c4fe98a38aa696ed0cb09d935932b4584d79949355fd1c015fd38cb6c` |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` | `e65df164d72c9602adfa6c68fa6f71d25cf896ab15ab2438daa6798024b91c84` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `131baf58c5d79085aa14e891daccb196b693c529c8c477d3a4ecc8008153f71b` |

| Supporting input / evidence | SHA-256 |
| --- | --- |
| `AGENTS.md` | `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc` |
| `Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md` | `73caa71f5f30dcea8d1517bdd681d24092d4eae512f285464b5d9274c6759335` |
| `Workflow/stage-summaries/2026-10-18-library-launch-activity.md` | `f59e1bfef8aee0d2328b2859bdc93925bca09be3c410e99d892c994d627529cc` |
| `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R1.md` | `72def3ae30b7129af25928b8d4035cf2d4818f28f942a724c12cee107dee6ff7` |
| `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R2.md` | `45bd4841e29feed4354754c241ee31156fdd313cdbd943ad99d77ea908a2a6e6` |
| `.build/verification/20261018/library-launch-activity/review-red-r2.log` | `7244d59150354c36ae6310e8672c0b529dfd21269deaff2e2aa84a13233cad24` |
| `.build/verification/20261018/library-launch-activity/focused-r5.log` | `deb96988e9634043c13249cc56390bcc3dac04504a69eb8721a761d57509f189` |

R1 and R2 remain historical SOURCE FAIL reports for their exact older inputs. This R3 closes their cited integration findings only for the current inspected versions. Subsequent source changes are outside this verdict. No further integration source repair is requested by this bounded review; Main retains the remaining automated, candidate/native and human-acceptance gates.

Changed files by this reviewer in this R3 task: `Workflow/results/LAUNCH_ACTIVITY_INTEGRATION_REVIEW_R3.md` only.
