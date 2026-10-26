# Takeover Reentrancy — Independent Bounded Review r1

Date: 2026-10-20

**Verdict: BOUNDED PASS — production source and test-source review only.**

No concrete blocking finding in the selected settling-to-began takeover continuation. This verdict applies only to the input hashes below. It does not certify test execution, build success, general engine reentrancy, or native acceptance.

## Scope and authority

Reviewed `Docs/TAKEOVER_REENTRANCY_SPEC.md`, the byte-frozen old Core, the current Core, and the newly present `Tests/PagingCoreTests/TakeoverReentrancyTests.swift`. Read the package structure and immediate session/transition implementations to check synchronous callback and reference-identity assumptions. This is a Foundation-only Swift state machine with synchronous outward observers and single-thread ownership.

The explicit task supersedes the historical Chief/Chef routing for this review. No agents were dispatched. Main and the test worker retain their separate ownership. The reviewer wrote only this report; no production/test files, workflow state, or other dirty files were changed. No SwiftPM, test runner, build, UI, process signal, reference/formal-data operation, or Git operation was performed. Shell commands used the RTK prefix.

## Reviewed SHA-256 inputs

| File | SHA-256 |
| --- | --- |
| `Docs/TAKEOVER_REENTRANCY_SPEC.md` | `765ca678b90bd504d441887b8a6da7b68ca7a4d1ff8b75e89b22fc838a769f62` |
| `.build/verification/20261020/takeover-reentrancy/PagingCore.baseline.swift` | `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369` |
| `Sources/PagingCore/PagingCore.swift` | `43c8de5f14861f4f3e766a0aee00a37236f37c7b20c091b37ad7e06f2df230a6` |
| `Tests/PagingCoreTests/TakeoverReentrancyTests.swift` | `0b1697ab8290b39f404a2784a1e1d72f48da6f5fd0fbedd8a6460659d1c8f00f` |
| `Sources/PagingCore/TransitionContext.swift` | `2a9e3e66ca0a1a07ac02d2453eda8d1e923a1240154b5b0892a37b48e9f0f88b` |
| `Sources/PagingCore/GestureSession.swift` | `0bc9989472b8cb4c7cd2b4645d45541795065d851244f1cc723f8e2931af442c` |

The specification, baseline, current Core, and test-file snapshot had identical hashes at the initial and closing input checks before Main's temporary old-Core swap. Main subsequently reported the test worker closed before integration and supplied `.build/verification/20261020/takeover-reentrancy/review-inputs/` plus `review-inputs.json`. Independently hashed frozen Core, test, and specification files exactly match both that manifest and the already reviewed bytes above. No working Core was read during the announced swap. After Main explicitly confirmed finally-based exact-byte restoration and completion of the current normal control, the reviewer rehashed the working Core, tests, and specification: all three exactly match the frozen packet and the hashes above. Any later input change requires review of the new bytes.

## Production-source findings

No blockers found.

1. **The edit boundary is respected.** The baseline/current diff contains only the settling-began caller (`PagingCore.swift:461`) and the private interruption helper (`:602-627`). A read-only Python byte comparison replaced those two current regions with their baseline equivalents in memory. The reconstructed bytes exactly equaled the baseline and produced SHA-256 `fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369`. No source was temporarily restored or written. All other bytes of this Core file, including physics, parameters, environment setters, request eligibility, and completion handling, are unchanged relative to the supplied baseline. This comparison does not independently establish the baseline identity of other production files.

2. **Terminal and later-owner checks cover all three selected outward boundaries.** The helper captures the original transition token and session reference before detaching/staling/counting the old transition. It checks `!isTearingDown`, unchanged token, no active transition, identical session reference, and the expected state after stale rejection (`:618`), after interruption (`:624`), and after publishing interrupted (`:626`). A failed check returns false and the caller returns before session creation or tracking publication. Teardown therefore suppresses the remaining old notifications/session; cancellation leaves its resulting state intact. The existing stale/interruption counters retain their pre-callback order.

3. **Accepted later navigation survives even when its final state resembles the old state.** A request accepted from a settling stale/interruption observer increments the token through the existing `requestPage`/`beginSettle` path. Both token mismatch and any installed active context revoke the old continuation. Token mismatch still protects a later request that synchronously finishes before returning. The old helper does not restore a cached transition, target, session, or environment.

4. **Detached nested began is rejected, without inventing a newer owner.** During stale/interruption observers the state remains settling while the old context is detached. The helper's nil-active-transition branch now returns false before any stale count, interruption count, notification, session allocation, or state write. A rejected nested began therefore leaves the outer owner eligible to continue. Requests during interrupted remain rejected by the unchanged `canRequestPage` guard (`:214-219`); invalid requests that make no change also do not revoke the outer takeover.

5. **Cancel followed by a valid idle began preserves the new session.** At all three boundaries, cancel reaches idle, and the subsequent began creates a distinct session and tracking state. The captured session reference (including nil for a direct-navigation seed) cannot match that new session. The expected-state check also fails. The old caller consequently returns false without replacing the accepted session. Reference capture retains the original object for the duration of the check.

6. **Ordinary state/event order and displayed offset are preserved.** Without ownership revocation the trace remains stale rejection, interruption, interrupted, then tracking. Observers still see settling at stale/interruption and interrupted at its state callback; there is no early state rewrite. The caller continues to initialize the session from the live `visualOffset` exactly as before (`:462`), with no intervening outward callback after the final ownership check. No new epoch, stored state, asynchronous work, timer, per-frame work, or public API was introduced. The old context is stale before the first observer; the existing completion rejection path prevents its later commit.

## Test-source review

**BOUNDED PASS for the hashed, frozen test-source input; execution verdict withheld.** The file appeared during review and was inspected directly, then matched against the frozen packet. It contains nine public-API XCTest methods with 36 seed/boundary iterations in their source loops; these are static counts, not executed-test counts. The ordinary control is `testOrdinaryTakeoverKeepsExactTraceDisplayedOffsetAndBoundedCommit`.

| Acceptance case | Test-source evidence |
| --- | --- |
| Independent teardown at stale/interruption/interrupted | `:94-131`; both direct-navigation and gesture-release seeds, no later callback/session, late old completion and later entry points rejected |
| Independent cancel at all three boundaries | `:133-163`; exact cancellation suffix and no old continuation after callback return |
| Accepted newer request at settling stale/interruption | `:165-212`; exact context identity, token, target, offset, pending state, old-completion rejection, bounded natural commit, one commit event |
| Interrupted-state request rejection | `:214-246`; unchanged request eligibility, ordinary takeover trace/session/offset, bounded subsequent commit |
| Rejected request does not acquire ownership | `:248-278`; invalid timestamp at both settling callback boundaries leaves the ordinary trace intact |
| Cancel then accepted idle began | `:280-323`; all three boundaries and both seeds, exact fresh session identity/timestamp/offset, continued input and bounded commit to page 2 |
| Detached nested began rejection | `:325-353`; both settling callbacks and seeds, no trace/state/session/token/offset mutation, outer ordinary takeover remains accepted |
| Normal trace/offset control | `:355-391`; exact four-event trace, stale/count/token/session/offset assertions and bounded commit |
| Late old completion across later ownership phases | `:393-428`; retained tracking session, pending later context identity, committed result and single commit |

The fixture records all six event outlets and disarms the selected action before nested calls (`:34-57`), avoiding accidental recursive test actions. Seeds exercise both nil and retained prior sessions (`:66-83`). `finish` bounds synchronous ticking to 600 frames and fails if idle is not reached (`:86-92`); commit assertions prevent an idle-only false positive in commit cases. The source has no AppKit, file, physical-input, or wall-clock dependency.

Static baseline reasoning supports the intended regression split: the old unguarded caller resumes after cancellation/teardown/new-owner callbacks, and the old nil-context helper lets a detached nested began synthesize a session. The normal non-reentrant trace remains a valid old/current control. This reasoning is not a substitute for running the selected RED cases against frozen old bytes and GREEN/control cases against current bytes.

## Evidence limits and handoff to Main

- The reported existing Core/direct 86/0 result is preliminary task context, not an independently executed or audited result from this reviewer, and does not establish execution of the new tests.
- Main reported the new focused suite at 9/0. The reviewer did not execute it. Main's `baseline-comparison.json` records the selected old-Core run as three tests with 140 assertion failures and the old normal control as one test with zero failures. The reviewer also read `current-normal-control.log`, which records the named ordinary control passing as one XCTest with zero failures. These are producer-owned execution records, not independent reviewer runs. Main confirmed finally-based exact restoration; the reviewer independently confirmed the restored working-file hashes as stated above. Main's `inverse-proof.json` agrees with the reviewer's independent in-memory two-region reconstruction.
- Main reports all other production files unchanged. That repository-wide invariant remains Main-owned evidence; this reviewer independently established only the complete Core byte-delta boundary. Final frozen focused/full regressions, isolated unsigned Debug/Release builds, and final input checks remain Main's next gates. This bounded pass is not a claim that those final gates passed.
- Environment-setter compositions and completion/other callback reentrancy outside this selected takeover are explicitly excluded. This review neither requests an engine rewrite nor certifies those paths. Existing environment policy is preserved by the exact two-region delta; arbitrary nested environment-operation safety is not inferred.
- No physical smoothness, 120 Hz behavior, native runtime acceptance, first-Library hitch resolution, or CPU-causality conclusion follows from this report.

**Final handoff:** Source and test-source review is complete with no blocking findings. Exact current-byte restoration is confirmed against the frozen packet. Main may proceed to the planned serial final frozen verification/builds, retaining the remaining acceptance gates. No broader reentrancy or physical certification is granted.

## Main execution acknowledgement

Main confirms exact current-Core restoration and current ordinary control 1/0, with the reviewed source/test/spec hashes unchanged. Main also reports all 547 existing inputs unchanged except Core and an exact two-region inverse, and has started the final runner. These remain Main execution evidence; the accepted bounded source/test-source PASS is unchanged. No final full-suite, build, or native acceptance is claimed.
