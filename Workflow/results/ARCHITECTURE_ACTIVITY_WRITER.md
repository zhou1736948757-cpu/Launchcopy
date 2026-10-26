# Accepted activity writer lifetime correction

Status: **SOURCE_STABLE**. Date: 2026-10-20. Scope: accepted audit F1 only.

## Changed files

- `Sources/PagingPrototypeApp/LaunchActivityCoordinator.swift`
- `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift`
- `Workflow/results/ARCHITECTURE_ACTIVITY_WRITER.md` (this result)

No other files were authored. Main owns concurrent AppDelegate/window input/Library owner/view/search/focus/layout changes and integration tests; none were reverted or edited by this assignment.

## Selected change and rationale

Recorded the selected F1 correction in this result before implementation. The user explicitly authorized the two disjoint source files; this is a bounded lifetime correction under the existing architecture specification, not a store abstraction or schema change.

At `LaunchActivityCoordinator.swift:201–217`, the actual save task now captures its accepted-write owner strongly rather than weakly. It processes the receipt, clears `activeWrite`, and hands off to the newest pending snapshot before returning. Each queued successor then owns the remaining chain. Once the last receipt settles and no pending snapshot remains, the task-to-owner retention ends. Invalidation still revokes new observation/admission and suppresses callbacks; it does not cancel accepted work.

The production delta is limited to the capture, removal of the weak-self early return, and a lifetime comment. All admission/privacy/clear/recovery decisions, generation checks, snapshot coalescing, one-active/one-pending bookkeeping, receipt handling, callback guards, drain behavior and disk schema are unchanged. A store that never returns an accepted receipt intentionally retains the writer; no new unbounded task queue or polling mechanism was introduced.

## Regression source added (not executed)

`Tests/PagingUITests/LaunchActivityCoordinatorTests.swift:162–253` adds:

1. `testQueuedClearRetainsWriterAfterInvalidationAndExternalOwnerRelease`
2. `testQueuedPrivacyOffRetainsWriterAfterInvalidationAndExternalOwnerRelease`
3. `testQueuedClearAndPrivacyOffCoalesceAfterInvalidationAndExternalOwnerRelease`
4. `testQueuedPrivacyOffReleasesWriterAfterFailedReceipt`

The existing in-memory controlled store now optionally signals a suspended save only after installing its continuation. New regressions load an enabled synthetic document with a fixed injected clock, suspend an older accepted save, supersede an unstarted history snapshot with Clear/OFF, invalidate the coordinator, and drop the test's sole strong external owner reference. They explicitly release each receipt and observe both ordered documents, the two-then-one pending bound, retained clear/privacy state, absent collection/callbacks after invalidation, and eventual deallocation on both successful and failed final receipts.

A test-only probe is captured solely by the coordinator's clock closure; its deinit expectation observes owner release without a production hook. The new cases use continuation-driven XCTest expectations with bounded failure deadlines. They use no sleeps, polling, `drain()`, disk storage, real preferences or native UI. Existing tests and default fake-store behavior are retained.

## Source-only inspection

- Re-read both edited regions and inspected the exact production text delta.
- Reversing the assigned edits reconstructs both exact pre-edit SHA-256 inputs; this checks that unrelated content in the owned files was preserved.
- Checked that the new regression block contains no sleeps or the existing polling helper.
- No builds, compiler/typecheck, tests, UI operations, formal data, Git operations or process signals were run. No runtime/test PASS or independent acceptance is claimed.

| File | Pre-edit SHA-256 | SOURCE_STABLE SHA-256 |
| --- | --- | --- |
| Coordinator | `ad30f9bc438c2b2631ed085f6a8a61cd09103f923873a4558db4923f0b58eb21` | `f7e7bfa1414a97f65922e7a46eae53e37d71e076ad15c62712b322dd96bb2ccf` |
| Coordinator tests | `5ecf780c4fe98a38aa696ed0cb09d935932b4584d79949355fd1c015fd38cb6c` | `d77eaada3dd942d2e29c2aa1ab8336710be670d488145de0752385757e55be61` |

## Main handoff

Source edits are stable and ready for Main's serialized verification after all concurrent source work settles. Run the full `LaunchActivityCoordinatorTests` group, including the four new release-boundary regressions and existing clear/OFF, failure/retry, protected-load and quit-protection cases; then perform Main's planned integration/full-suite/build checks. This result does not close those gates or any Library first-entry/physical UI acceptance gate.

JSON helpers, icons and timing remain deferred and unchanged by this assignment.
