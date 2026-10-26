# Gesture takeover callback ownership results

Date: 2026-10-20. Status: bounded implementation/review/serial verification COMPLETE. Full parity remains incomplete.

## Changed scope and correctness
Only Sources/PagingCore/PagingCore.swift and new Tests/PagingCoreTests/TakeoverReentrancyTests.swift differ from the stage baseline. The caller now needs Boolean continuation ownership. The helper detaches/stales/counts the old context in the same order, then rechecks terminal state, original token/session, absence of a later context and expected state after each outward callback. Losing ownership stops old notifications/session creation. No fresh session is synthesized for a detached nested began; cancel→valid fresh idle began retains its accepted session. Interrupted-state navigation eligibility remains unchanged/rejected; rejected requests do not revoke normal takeover.

No new stored state/epoch/timer/async work/per-frame work/public API. All physics, parameters, spring/target/boundary/glide code, environment setters and adapters are untouched. Two edited regions inverted in memory reconstruct exact full baseline Core hash; production-invariants.json proves every other baseline input unchanged (547 total baseline inputs). This is code-equivalence/ownership evidence, not measured handfeel/latency.

## Execution evidence
- Initial existing Core/direct 86/0; new 9 methods/0. Static source loops span36seed/boundary scenarios, not36XCTest executions.
- Exact old Core selected3methods execute140assertion failures. No baseline instrumentation or API shim. Same ordinary takeover trace/offset control passes1/0 old and1/0 restored current. finally restores exact current bytes; complete logs/json retained.
- Final frozen 548 inputs: focused 235/0, full 3357/0; Debug, Release isolated package, diff exit0. Packaged365keys×3languages checked. Current candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/takeover-rc-20261020-r1/LaunchcopyUITest.app`, executable SHA `2094facf411332fe676f7b9814dacb2a15aad6b4d560f11e241f3a4dd94d9a77`; unsigned/uninstalled/unlaunched, entry timing probesOFF. Fail/development outputs are not current implementation failures or zero-testPASS.

## Independent review / ownership
Maxwell r1 BOUNDED PASS on exact Core/test/spec inputs, plus immediate session/transition reference assumptions. It independently reconstructed two-region baseline in memory. Reviewer ran no tests/builds; all execution belongs toMain. Bohr owned only pure synchronous9-method test file; events capture fixture weakly, actions disarm before recursion, ticks bounded600. Both agents closed, maximum3includingMain, all SwiftPM work serial. Source-review gate is not a native/whole-product acceptance gate.

## Limits and next work
Only the selected takeover continuation is certified by this packet. Broader environment-setter/commit/other callback reentrancy compositions remain unreviewed/outside scope; existing policy is preserved, not globally proven safe. No physical 120Hz/smoothness/native window/IME/VoiceOver acceptance or first-Library hitch/CPU-root-cause claim. User deferred that hitch; no tuning performed.

No manual runtime/UI restart, formal-data/reference/OS action, process signal, installation/signing/publishing or Git mutation. Existing automated suites may reset owned temporary fixtures; new tests are pure synchronous Core/noIO. Previous fd395b00 runtime remains separate and was process-checked only. Full parity remains active/incomplete, with other source/functional/native/device gates separately tracked.
