# Identifier search UI / owner independent review R2

Date: 2026-10-15.
Verdict: **BOUNDED SOURCE PASS — F1 repaired; no new blocking finding in this review's scope.**
Reviewer executed tests: **0**. Main's retained logs were inspected read-only. This is not full-suite, Debug/Release/package, native UI, restart durability, physical performance or whole-project acceptance. The original `IDENTIFIER_SEARCH_UI_OWNER_REVIEW.md` and its FAIL history are preserved.

## Authority and scope

Applied project AGENTS.md with the human Chief waiver, RTK rules, the approved `Docs/BUNDLE_IDENTIFIER_SEARCH_SPEC.md`, the identifier implementation stage summary and settings worker interface. This follow-up independently traces the actual F1 repair, new regression scaffolding and original settings/alias/input/type/privacy/integration boundaries. Domain/store implementation remains the other reviewer's responsibility; the unrelated dirty-tree diff is not treated as this task's delta.

Only this new R2 report was written. No Swift/build/tests/UI/process/agent actions, reference implementation/assets or global memory access occurred. All R2 shell commands used RTK.

## F1 disposition and repair reasoning

**Original issue:** An identifier policy rejected while an accepted Library writer was pending had no completion event to retry it.

**Actual repair:** `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:225-232` now places `defer { onReadinessChange() }` after `guard isActive`. The existing preference-change callback remains the entry point (:55). Settings/receipt reconciliation, optional close/projection refresh and entry readiness finish before the deferred notification (:230-241).

The repaired chain is:

1. `AppLibraryPreferencesCoordinator.swift:61-78` receives the writer result, decrements pending count, reconciles the real accepted baseline and calls the existing `onChange` for the current active generation. This happens for both successful and failed terminal saves. The repair does not modify writer ordering, receipt bookkeeping, generation checks, invalidation or Quit protection.
2. The active Library owner completes `preferencesChanged`, then notifies its existing readiness consumer.
3. `AppDelegate.swift:2270-2273` reaches `scheduleLanguageReadinessRetry`, which schedules the pending identifier transaction (:2515-2518). Its next-turn attempt is coalesced and checks management epoch, coordinator identity and final teardown (:2642-2652).
4. The normal admission predicate still checks real input/lifecycle owners and both accepted-write counts (:2497-2510, :2631-2637). A failed Library write no longer being in flight permits the independently saved policy to apply; the Library failure still retains its existing Quit protection and error handling.

The notification also occurs on active load/submit changes. These are discrete events; an attempt while pending simply rejects, and the terminal event retries it. There is no new timer, polling, synchronous flush, recursive preference save or per-frame work. Duplicate scheduling through the existing appearance/language bridge is coalesced. Projection updates/rendering do not call `preferencesChanged`, so this repair does not form a self-sustaining callback cycle.

**Disposition:** F1 is resolved at source level. This conclusion follows the actual control flow and is supported, separately, by the retained focused execution evidence below.

## New regression scaffolding: what it proves and what it does not

### Automatic writer-completion retry

`Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift:46-82` uses an actor-backed injected store (:8-24) that suspends an actual accepted Library save on a checked continuation. Its four loop combinations are Library closed/open x save success/failure. It calls the production management-policy API and real installed owner readiness callback.

After queuing the policy, a `DispatchQueue.main.async` continuation marker (:63-67) is enqueued behind the already scheduled policy attempt. The store remains gated until after that marker. Assertions then require pending write count 1, effective policy OFF and pending policy true (:68-70). Thus releasing the writer cannot accidentally make the first policy attempt succeed before the rejection boundary is observed. The test waits for store submission, reads the actor value into a local `let` before the XCTest assertion, releases the actual writer and only observes the effective flag/pending state (:71-78). It never manually flushes, calls the scheduler, replaces the readiness callback or injects a notification to complete the retry. It also checks the Library open/closed state is preserved.

**Bound:** This is an owner event/wakeup regression. There is no app catalog/surface or actual settings checkbox mounted in these four combinations. The open branch deliberately supplies transition/capture fixtures; with no window there is no active Library field editor. Therefore it proves automatic effective-policy application after the accepted-write boundary, not actual displayed result recomputation, settings receipt rendering, or production native Library admission. Those remain covered separately by the existing integration/control tests and stronger native gates.

### Accepted completion after application teardown

`AppLibraryLaunchAndQuitTests.swift:84-112` queues the policy behind another gated accepted save, crosses the ordered marker, waits for a real submission, then calls only the unstarted fixture delegate's `applicationWillTerminate` method (:101-103). It neither asks NSApp to quit nor starts an application process, scanner or formal preference store. It requires pending policy cleared, releases the accepted writer, waits for pending count zero, and checks the policy was not applied, the app no longer owns Library, and a later policy request is rejected (:104-111).

The corresponding production path sets `didRunFinalTeardown` before tearing down Library (`AppDelegate.swift:3517-3524`), clears the pending flag and callbacks and increments the management epoch (:3529-3534). Library teardown detaches the preference callback and invalidates the coordinator (`AppLibraryOwnerController.swift:300-305`). The accepted writer is allowed to finish its bookkeeping before the coordinator's inactive guard (`AppLibraryPreferencesCoordinator.swift:61-67`), with no late presentation publication. Already queued identifier tasks also reject final teardown/old epoch.

**Bound:** The test checks receipt processing through pending-count completion, not physical durability. It has no catalog, late projection or mounted settings window. It covers post-teardown suppression, not every possible approval-to-teardown scheduling interval.

## Original scope retention

| Boundary | Source assessment and remaining limits |
| --- | --- |
| Alias / hide composition | AppDelegate:2829-2850 still derives hide/alias/restore drafts from `coordinator.committed`, retaining a stored-but-pending flag. The policy-only branch at :2598-2605 still bypasses legacy close/cancel handling. No repair code mutates aliases, hidden keys or canonical identity. Separate domain/store review remains authoritative for matching/schema semantics. |
| Typing / editors / menus | Admission still rejects alias field-editor, marked-text, title, Library-editor, gesture/drag, menu/sheet, restore and writer ownership. The repair signals readiness; it neither dismisses editors nor cancels inputs. Existing text/menu observer bridges and their next-turn behavior remain applicable. The new writer tests intentionally have no active editor and do not extend physical-input acceptance. |
| Typed UI and localization | `AppManagementSettingsView.swift:13-14,178-214` keeps Bool/result callbacks and distinct stored/pending/error receipts. Policy refresh changes only the flag/control/feedback; alias draft/editor/menu and legacy feedback are not rebuilt. Corrupt/future guards, missing-callback failure and missing-provider conservative queued state remain. Seven typed keys/fallbacks and en/zh-Hans/ja entries remain aligned (`SettingsTextKey.swift:49-55`, `LocalizedStrings.swift:190-196`, resources :76-82). No native fitting/AX/VoiceOver claim. |
| Same-query generations / selection | The repair does not alter policy capture, main query generation, selection anchoring or immutable Library requests. AppDelegate:2677-2693 uses the existing commit/focus path; :1303 fans out to Library. The 70-app integration cases inspect same-query selected-app page/slot relocation and clearing an identifier-only selection on OFF. Those tests manually flush and serve a different purpose from the new automatic writer test. |
| Folder / Library navigation | No policy-specific close or query clearing was added. Stable folder-overlay, Library independent-query/Back and app-anchor tests remain bounded integration evidence. Selected folder/member, active animations and native transitions are not newly certified. |
| Lifecycle / profile isolation | Management epoch/coordinator identity and final-teardown guards remain; unresolved requested profiles still choose unavailable management storage at AppDelegate:2582. Library projection still captures immutable management/query and rejects obsolete completion on close/generation change. The new repair does not change these ownership mechanisms. |
| Privacy / work budget | The new defer transports no query, identifier, alias or path. No logging, telemetry, network, metadata scan, extra persistence or frame filtering is introduced. Existing UI help uses only the invented `com.example.app` example. Synthetic workload timings remain fixture-only, without allocation or pre-change/physical performance acceptance. |

The original review's **non-blocking Quit risk remains bounded and unresolved**: AppDelegate:2498 uses `!workspaceQuit.isPending`, while `WorkspaceQuitCoordinator.swift:14` excludes `.approved`. The new teardown test does not exercise the approval-to-teardown interval. Final teardown and epoch checks provide suppression once teardown begins; no new runtime failure in the earlier interval is established by this review. This source PASS does not convert that interval into tested acceptance.

## Retained execution evidence inspected, not executed by this reviewer

All paths below are under `.build/verification/20261015/identifier-search/`:

- `library-write-wakeup-compile.log:6-28` preserves the initial actor-property / `await`-inside-XCTest-autoclosure compile failure. This is not the behavioral RED. Current source obtains `let submissions = await store.submissions` before asserting.
- `library-write-wakeup-red.log:12-27` records the actual wakeup regression executing **1 XCTest / 8 assertion failures**, 8.701 seconds: each of the four loop cases times out observing the unapplied flag and retains pending true. This matches the reported F1 failure pattern, independently of the earlier compile error.
- `focused-r4.log:41-54` records both new regression methods passing, along with the existing Library launch/Quit cases. The automatic four-case loop counts as **one XCTest**, not four tests.
- `focused-r4.log:125-128` records **44 XCTest tests / 0 failures**, 1.616 seconds test time (1.621 seconds selected-suite wall time). Breakdown: five Main owner tests, three Library-return tests, seven Library launch/Quit tests, 12 domain tests, 11 settings tests, five store tests and one synthetic workload test. The separate trailing Swift Testing runner's zero-test line (:132) does not negate the nonzero XCTest run, and is not counted as extra evidence.

Main also reports prior focused r3 **37/0**; that earlier result was not independently inspected in R2. Main says full tests/Debug/Release/package checks are running serially. R2 makes no assumption about their results and no GUI claim.

## Source identity and preservation

The following currently read SHA-256 values match the corresponding entries in Main's `source-inputs-final.json` (lines 111,117-118,330). This comparison is limited to these four paths; it is not whole-manifest/candidate verification:

| Path | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `05a5485de9639a33ac5dfe4d0f41de996a8d8f10d5b665d0b3da16e3fe645aee` |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` | `8d29940e4b491182eae4a0919058edf7d5e7ebfab9abfe9f3cb44ba97e07d6af` |
| `Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift` | `59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0` |
| `Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift` | `0198db13b3bc10dddad6aca130298597a6929b1cb9c2418bbc0c16e633a94521` |

Original report SHA-256 at R2 inspection: `017b06e2a0250047d14b15b92034a6d2d017c3b1daa4c060bf2c77b95d6d477d`.

**Final R2 boundary:** F1 source repair accepted in this bounded review; no new blocking source finding. Reviewer executed tests **0**. Only `Workflow/results/IDENTIFIER_SEARCH_UI_OWNER_REVIEW_R2.md` was created; the original FAIL, historical logs and all implementation/test/source-state files remain untouched by this reviewer.

## 2026-10-15 addendum — explicit localization contract update after full r1

**Bounded source disposition:** The inspected localization test-contract correction is appropriate and retains an independent oracle. It does not establish a green full suite. F1's source disposition is unchanged.

Read the current `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift`, `SettingsTextKey.swift` and the shipped-language enum. The explicit `settingsKeys` array now includes exactly the seven approved identifier-search keys between `managementSaveFailed` and `sourcesAutomatic` (:30-33), in the same order as `SettingsTextKey.swift:49-55`. It remains a manually enumerated literal array; it has not been replaced with `SettingsTextKey.allCases` as the expected value.

The test still asserts ordered enum equality (:50), independent static base count **108** (:51, accounting for the seven added literals), no key collisions (:52), exact ordered required-resource-key equality (:53), and exact set equality for every shipped table (:54-56). `InterfaceLanguage.allCases` contains en/zh-Hans/ja, so the loop continues to cover all three shipped tables. Final resource validation and empty-issue assertions remain (:63-64); placeholder, malformed-table, invalid-value and privacy tests remain in the file. No weakening to subset checks, duplicate-tolerant counts, skipped languages or dynamically derived settings expectations was found. This is inspection of the current contract against the approved vocabulary, not a claim that the entire dirty-file diff is this correction.

**Execution evidence:** Independently read bounded portions of `full-r1.log`. Lines 4518-4522 contain the five assertion failures, all in `testRequiredKeyContractAndEveryShippedTableHaveExactCoverage`: enum/list equality, required/list equality, and each of the three table/list set equalities. The recorded lists omit the seven new keys on the expected side. Lines 6043-6045 record **2,630 XCTest tests / 5 failures**, 59.482 seconds test time. This full r1 result supersedes any implication of broad green status from focused r4's 44/0; those focused tests did not include this independent contract test. Main reports focused r5 includes the 11 validation cases alongside the previous 44 and is running, with full-suite rerun to follow. Neither result is inferred here. Reviewer executed tests remain **0**.

**Frozen-input follow-up:** Current inspected test SHA-256 is `a616059fe03ec7269bbf5b2db3f3c859a200eb6a5e5a251237dc9e3507383ae5`. At this inspection, `source-inputs-final.json:290` still records `46b7923b0217231a396654c0881d06546ec5911342f9d5f23fdaba58eb3c0ad0` for that path. Main must refresh/version the frozen-input evidence to include this test correction before claiming final source alignment. The currently rechecked AppDelegate and AppLibraryOwnerController hashes still match the R2 table, and the original FAIL report hash remains unchanged. This is an evidence-version limitation, not a new production owner defect.

Only this R2 report was updated for the addendum. No test/production source, logs, frozen manifest or original review was modified by the reviewer; no full-suite/build/package/native/performance PASS is claimed.
