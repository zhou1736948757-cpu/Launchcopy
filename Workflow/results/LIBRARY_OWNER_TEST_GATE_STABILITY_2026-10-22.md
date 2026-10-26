# Library owner test gate stability — 2026-10-22

Status: bounded test-harness repair based on source-level synchronization proof. Runtime verification and independent review remain with Main. This is not a test PASS.

## Authorized scope and evidence boundary

Changed only:

- `Tests/PagingUITests/LibraryOwnerCardPreparationTests.swift`
- This new evidence note, `Workflow/results/LIBRARY_OWNER_TEST_GATE_STABILITY_2026-10-22.md`

Read the test and, as necessary, `AppLibraryOwnerController.swift`, `AppLibraryProjectionController.swift`, and `AppLibraryPreferencesCoordinator.swift`, plus applicable instructions. No production changes, Swift invocation, test execution, build, package operation, UI operation, Git operation, subagent dispatch, or reference/private-data inspection was used for this investigation.

Main's handoff reports FullR1 passing this class and FullR2 / isolated whole-class execution timing out at "fresh normal snapshot" after three seconds, followed by InvalidTransition failed(deinit). Those runs were not independently inspected or reproduced here. No attribution of the deinit diagnostic is established.

## Source-level synchronization argument

Relevant production paths:

- Owner `attach`, lines 108–115: an independently scheduled startup task awaits preference loading and then calls `preferencesChanged()`.
- Preference coordinator `loadIfNeeded`, lines 28–44: concurrent callers await the same load task. Completion of one caller does not establish completion of the owner's startup task or its later callback.
- Owner `preferencesChanged`, lines 550–555: if a session has opened, the later callback refreshes its projection.
- Owner `enter`, lines 175–197: opens the session, cancels preparation, and requests a normal projection.
- Projection controller `update`, lines 62–68: advances generation, replaces pending input, and clears the snapshot.
- Projection controller `startNextIfNeeded`, lines 81–100: holds one worker slot until completion, rejects outdated/canceled results, and then starts the latest pending request.

A permitted schedule is sufficient to demonstrate the old helper's liveness defect:

1. The test's `await preferences.loadIfNeeded()` returns while the owner's startup task has not finished its post-load callback.
2. In the early-entry test, readiness changes and preview entry occur without suspension. Normal generation G1 starts; the test gate queues its continuation.
3. The late startup callback runs while G1 is held. It requests G2; the projection controller keeps G1 running and stores G2 as replaceable pending input.
4. The old helper observes one recorded gate request and resumes G1 exactly once.
5. G1 completes with a real snapshot. Production correctly rejects it because its generation is obsolete, then starts G2.
6. G2 reaches the gate and suspends. The old helper now only polls snapshot state; nobody resumes G2 until deferred teardown calls `releaseAll()`. Waiting longer cannot resolve this state.

The same flaw applies when a canceled previous-session worker must complete before a reopened session's latest worker can begin. Historical request totals can also exceed a later helper call's exact count because startup refreshes are legitimate. Neither production behavior implies a production regression.

The source establishes a concrete harness deadlock schedule. It does not identify the exact executor schedule of Main's recorded failed runs.

## Registration-order hypothesis

`requests.append(request)` precedes continuation insertion in the source, but the gate and test helper are MainActor-isolated and continuation registration occurs synchronously in `withCheckedContinuation`. There is no demonstrated actor-interleaving point between those operations. This investigation does not claim that textual ordering proves a registration race.

The helper now checks the actual pending queue before its first delivery, making its readiness requirement explicit without altering gate registration or cancellation behavior.

## Exact test-file delta

Two hunks, nine net added lines:

1. Add the read-only gate property `hasPendingRequests`, backed by `!pending.isEmpty`.
2. In `deliverSession`:
   - Treat `requestCount` as a cumulative lower bound (`>=`), and require a queued continuation.
   - Retain the first `XCTAssertTrue(f.gate.finishNext())`.
   - While waiting for a fresh, idle normal snapshot, keep resuming the next FIFO continuation whenever the completion condition is false. A rejected result may start the next worker only after returning to the controller.

The helper cannot interleave with a controller's synchronous completion / next-worker transition on MainActor. It succeeds only with the current catalog revision and `!isProjecting`; it does not publish a snapshot itself.

Unchanged guarantees:

- Gate delivery still returns real projections for canceled requests, exercising production generation/cancellation checks.
- No task-cancellation shortcut, request dropping, newest-only delivery, or direct snapshot mutation was added.
- All test method bodies are byte-identical, including early entry's no-suspension boundary, stale action/card identity assertions, preview restrictions, and cancellation/preparation assertions.
- Idle preparation must still leave the normal-session request list empty.
- The existing three-second deadlines, existing yields, and existing observation windows are unchanged. No timeout increase, sleep, skip, or new timing window was added.

## Static verification

An in-memory pre-edit snapshot was compared with the resulting test source. The only delta is the two hunks above. All test method bodies compare byte-for-byte equal.

Test source SHA-256:

- Before: `12a70c381fc92d14319c0dfc6d820dedb210a7b45ed62eb736789c1bf5180f78`
- After: `ead3114185e9bdfa7585f41e714c2aa6ece7ce898a47e02f352031a534d619ba`

All three inspected production sources had identical hashes before and after this repair:

| File | SHA-256 |
| --- | --- |
| AppLibraryOwnerController.swift | `b9bb22d8a81645a8e4815e3f2a85e0619bd22447a1e23559d2659c472f420d7f` |
| AppLibraryProjectionController.swift | `e0ea5dcdc8f4fa17f0e7f3b135fcf4143b3c72b54b8b7ecb350a07d6b696d34a` |
| AppLibraryPreferencesCoordinator.swift | `59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0` |

These are local inspection-baseline hashes, not a comparison against frozen565 or any Git reference. No compilation or runtime acceptance is implied.

## Main-owned next verification

Main should compile and rerun the early-entry test and entire class using its existing verification process, preserving the three-second deadline. Independent review should check the FIFO drive and unchanged assertion bodies. Full-suite / UI verification remains solely Main-owned.

This helper services work that becomes pending before a fresh idle snapshot is observed. It is not a barrier against every future owner callback. If a timeout or deinit diagnostic remains, the needed evidence is the actual request arrival/completion sequence, snapshot and isProjecting transitions, and generation/cancellation context from Main's run; this source inspection cannot establish the cause of an unseen trace.
