# Committed icon source invalidation results

Date: 2026-10-20. Status: bounded maintenance complete; full parity incomplete.

## Changes and scope
- IconPipeline: affected identity cache variants, owned load cancellation and queued-delivery revocation. Accepted cache/finish deliveries register under the existing lock and need a live receipt at MainActor admission; callbacks execute outside the lock. Retire load ownership before cancelling tasks outside the lock, preserving reentrant cancellation-handler safety. Existing loadID guard rejects non-cooperative old successes.
- IconURLResolver/assembly: atomic current mapping and delta; shared servedSnapshot synchronization before refresh/root-search rendering and before direct commit returns. Revision fast gate avoids duplicate/query-only work; same URL/revision/name changes do not force icon reload.
- Tests: six generated-memory pipeline methods plus six injected-scanner/source integration methods. No real app icons/files; source tests use synthetic URL identifiers. No public key/schema/default/physics/organization/visual or reference-source change.

## Exact verification
Final frozen 547 inputs; focused 105/0, full 3348/0, Debug/Release package/diff passed. Package verifies365keys×3languages. Candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/icon-source-rc-20261020-r2/LaunchcopyUITest.app`, executable SHA `49d8989965316d71909f138127c9dd32cc3a077aeafec5d36da606ff87c2020d`. Unsigned/uninstalled/unlaunched; optional entry timing probesOFF. Runtime fd395b00 left untouched, process-only recheck receipt separates it from this build. No live native icon/performance/physical gate claimed.

Prior r1 runner passed105/3348 tests plus builds/package at da1a4e4d; its weaker old-result scheduling assumptions prompted independent test-source P2. Current internal read-only processed-result count is protected by the finish lock; observing it implies that ownership decision released the lock. Old-before-replacement and old-after-replacement tests now positively require processing before proceeding. Getter has no identity/clock/public telemetry/policy role, per-load only.

Mutation evidence: disable source invalidation on the pre-liveness-refinement snapshot →2tests/10failures. Remove only loadID comparison on latest observed-decision source →1test/4assertion failures,0unexpected. Both restore exact original source bytes via finally/hash assertion. These are deliberate mutations, NOT original-baseline execution or current implementation failures. Failed/development attempts retained; no zero-test PASS. Initial snapshot script missing import was repaired before snapshot review; no source rollback or fabricated receipt. Existing unrelated weak-variable compiler warning remains.

## Independent review
Schrodinger r1 bounded production PASS plus P2 test ordering gap; r2 bounded source/test-source PASS closes that gap at final hashes. Reviewer ran no tests; Main owns all execution receipts. Hooke owned only integration-test file and closed; reviewer closed after durable result. At most3agents includingMain; all SwiftPM jobs serialized. Prior reports/packets retained.

## Honest limits and next work
Actual AppDelegate search wiring was inspected, but integration test supplies a mirrored synchronization callback; no independent runtime callback-installation/native acceptance. Same-path content updates, NSWorkspace caching, cross-process freshness and broader cancellation APIs/queued-permit behavior are not redesigned or certified. Existing tests use memory/owned temporary fixtures only; no formal data/manual app move/runtime restart/sign/install/Git mutation/OS setting/private screenshot occurred. No measured performance improvement or first-hitch root cause claimed; user defers that hitch, CPU explanation unverified.

This closes the concrete winning-source-URL cache/in-flight/queued-delivery contract, not all icon freshness or product parity. Separate remaining architecture findings include Core reentrancy, mixed anchor ordering, coherent diagnostics and shared JSON helper coupling, along with actual physical/device/native gates. Do not equate this green packet with those requirements.
