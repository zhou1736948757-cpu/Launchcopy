# Journal lifecycle ownership repair

Date: 2026-10-20. Status: selected maintenance scope under the approved whole-code reliability review. No product feature or destructive UI is added.

## Problem and outcome
The workspace journal actor is reentrant across I/O awaits. Concurrent first callers can duplicate initialization, and explicit reset currently archives/cleans/writes outside the normal writer ownership boundary. Protect accepted layouts, preserve journal evidence, and serialize all initialization/reset/writer I/O within this actor.

## Scope and non-goals
Only LayoutStoreActor lifecycle ownership, protocol documentation, and injected-memory-I/O regressions. Preserve v1 bytes, limits, slot rotation, read-only classification, lock-mode policy, retries, latest-wins queue and existing flush results. No new generic queue framework, source identity change, physics/UI/Library optimization, migration, manual/runtime reset or formal data access (existing automated suites may reset their own temporary fixtures) or app restart. The user defers first-entry hitch; CPU causality is unverified and out of scope.

## Ordering contract
- Share one actor-owned initialization task published before its first suspension. Every load/enqueue/flush/reset waits for the same completed classification. load() remains the immutable startup result, including after reset.
- Reset admission (after initialization) is the linearization point. Increment a lifecycle epoch, supersede the pre-reset pending intention, and retain a reset task before yielding. Let already admitted I/O finish; never cancel it or delete its temp file while suspended. A stale normal writer may finish its physical attempt and advance the monotonic write counter, but may not publish state, retry or drain a successor after its epoch is revoked.
- Reset archive names add a neutral random suffix to the existing timestamp, preserving every evidence file even for same-second resets. No raw values are logged.
- Concurrent resets execute FIFO in actor admission order, each with its own default and receipt. Each awaits its predecessor reset and the previously owned writer before archive/cleanup/default write. A later reset supersedes earlier pending intentions but not earlier reset receipts.
- Enqueue during reset is nonblocking after initialization: retain only the latest successor. Do not launch a normal writer while any reset is queued/running. Once the final reset settles, drain that successor automatically when not read-only. Enqueues before a later reset admission are superseded by that later reset, as normal explicit reset intent requires.
- Flush retains its existing bounded deadline, waits across reset without starting another writer, drops an obsolete final-attempt receipt after epoch change, and reports timeout without cancelling owned I/O. A completed reset/default receipt is not a receipt for a still-pending successor.
- Archive/default failure returns failed, never reset-success. Preserve read-only protection on archive failure; publish degraded/terminal failure for writable failures. Retain post-admission successors and existing retry behavior. Only the latest reset epoch may publish state or restart the normal drain.
- Protected startup retains the high water of any validated v1 sibling before early return; never trust future/invalid document generation fields or change the protected classification.
- Flush deadlines still start after initialization, matching the existing API; this change does not promise bounded completion of a suspended initial filesystem call.
- Journal write generations remain monotonic even when a completed old write is subsequently archived. Earlier reset receipts remain exact even if a later reset supersedes their files.

## Acceptance / verification
Deterministic continuation-gated memory I/O, not sleep-only timing: concurrent initialization/load/enqueue; old write/replace/sync versus reset; archive/default gate and coalesced successors; two reset defaults/receipts; flush deadline/cancellation while reset stalls; archive/write failure, future-version protection and monotonic generations. Assert no concurrent journal writes, no archive/temp removal touching suspended writer, immutable startup receipt, exact final decoded layouts and successor progress without a new enqueue/flush trigger. Gates release on test failure. An internal actor-isolated read-only observation exposes reset admission revision and currently initializing callers for deterministic test synchronization; it is not public API, telemetry, or an admission mechanism.
Run new tests RED against the frozen baseline, then focused store/codec suites, full suite and Debug/Release serially. Independent read-only source review checks the frozen delta. No native/paging smoothness acceptance inferred. Package/runtime remain the previous verified candidate unless explicitly replaced later.

## Ownership / maintenance
Main owns production actor/protocol and integration. One test worker owns only a new lifecycle test file; no concurrent SwiftPM jobs. A fresh independent reviewer owns one report after inputs freeze. At most three active agents including Main; no legacy Chef machinery. Keep dirty baseline and exact hash receipts, update stage/plan/project memory and audit disposition. Remaining cross-process races and externally changed future files are not redesigned here.
