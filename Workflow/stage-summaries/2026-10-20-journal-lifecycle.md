# Journal lifecycle ownership — 2026-10-20

## Objective and baseline
Repair concrete P1 actor reentrancy findings from ARCHITECTURE_DOMAIN_AUDIT, not the user-deferred Library hitch. Existing dirty baseline preserved; executable/runtime remains library-header-rc fd395b00 with scoped128/0 evidence. New source changes do not match that running artifact. Exact maintenance spec: Docs/JOURNAL_LIFECYCLE_OWNERSHIP_SPEC.md. Baseline hashes under .build/verification/20261020/journal-lifecycle/.

## Decisions and ownership
Main owns actor/protocol implementation and serial integration; disjoint worker owns new deterministic lifecycle tests only. Later independent read-only review after freeze. Max3 including Main; no parallel SwiftPM or native action. No on-disk reset/formal data/UI/reference access. First-entry hitch USER_DEFERRED_NONBLOCKING, not fixed or proven CPU-caused.

## Verification / review
Not yet run. Need frozen baseline RED, new focused/full/Debug/Release and independent review. Native acceptance not needed for injected persistence ownership, no physical/performance claim.

## Risks / next action
Current reset bypasses writer; initialize checks only hasLoaded after await. Implement admitted reset epoch, FIFO receipts, deferred successor drain and shared initialization. Validate failure/flush boundaries before delivery. Full product parity remains incomplete.

## Implementation checkpoint
Actor now publishes shared initialization before suspension, queues exact FIFO reset tasks behind actual predecessor/writer receipts, fences ordinary drains by epoch, retains/coalesces post-reset successors, and keeps flush deadline/caller cancellation independent of owned I/O. Added neutral random suffix to reset archive names after confirming existing second-resolution names collide under same-second resets with real FileManager semantics. Two production paths changed, no UI/runtime action. Existing focused codec/actor/terminal suite:64tests/0failures, log .build/verification/20261020/journal-lifecycle/existing-focused.log. This is provisional pre-new-tests evidence, not final delivery. Disjoint worker and read-only reviewer active (3includingMain).

## Independent r1 / additional protected-startup boundary
Lorentz returned bounded source FAIL with one P2: baseline future-version/over-limit early classification discarded a validated peer generation; reset could archive generation900 then write1. Main now retains only validated-v1 sibling high water before protection early returns, without changing immutable startup classification or permitting writes. Worker requested regression with both slot orientations/exact archived bytes; source follow-up pending. Original r1 retained unchanged.

## Test worker recovery / ownership transfer
The assigned test worker produced no file or checkpoint through bounded continuation, a120s wait, and an interrupt requesting immediate preservation followed by60s wait. Main closed that same worker before taking over its still-absent test file; no replacement worker or duplicate writes. Main now owns deterministic tests and integration. This is a worker interruption, not Reviewer failure or a test PASS. Read-only reviewer retained for source follow-up.

## Deterministic RED → first GREEN
Main authored404line memory-only lifecycle packet (9XCTest methods, looped write/replace/sync and protected-slot variants). Internal actor-only observation exposes admission revision/initialization waiters; no runtime reader or public API. First GREEN9/0. Three selected tests run against frozen old actor with only matching observational counters (no decision/await/I/O changes): exit1,3executed/17assertion failures including duplicate initialization,2active writes/archive/temp touching stalled writer, and protected-peer generation900→1. A timed observation failure is preserved as one unexpected failure in that intentional RED. Baseline swapping runner finally restored exact current bytes and asserted hash equality. RED only establishes the exercised old paths; current GREEN covers all gated stages separately. Receipts baseline-red.json/log and new-tests-first.log. Frozen full verification now running serially; reviewer notified to avoid temporary RED snapshot and inspect restored source/tests.

## Frozen focused verification
545source/test/script/manifest inputs frozen and rechecked unchanged. Final focused LayoutStore/WorkspacePersistence/WorkspaceQuit packet103tests/0failures, not merely the9newcases. Full suite/build/package still running serially. Main retained original native test process28936 at library-header fd395b00 (read-only exact executable path check); no app replacement, formal data, UI operation, process signal, install/sign or Git mutation.

## Source review r2 and integration progress
Lorentz bounded SOURCE PASS: F1 closed, actor/protocol/spec exact hashes in r2. Test source audited; two non-blocking but material coverage gaps identified (obsolete flush receipt/post-default held successor; writable reset failure with successor accepted before failure). Main prepared two additional deterministic cases and will apply only after frozen r1 verification ends. No further production change planned. Current r1 full3333/0, focused103/0, Debug passed; Release/package still running. No new-runtime or physical claim.

## Test follow-up r3
Production SOURCE PASS still applies unchanged. Reviewer confirms writable archive/default failures now prove accepted-successor autonomous drain. Post-default held-successor gate is covered, but original old-epoch flush waiter currently times out before reset completes; this cannot discriminate removal of epoch receipt invalidation. Main will add one original waiter crossing reset completion with2s budget and current-epoch final-attempt gate, plus a one-block mutation RED check. This is test evidence refinement, NOT a newly discovered production failure. Current frozen final-r2 (11cases) must finish before any test edit; no edits to actor/protocol/spec or package planned.

## Boundary wording clarification
Earlier shorthand “no on-disk reset” means no manual/runtime/user-data reset. Existing automated actor/full suites may exercise reset on their own temporary test directories; new lifecycle tests are memory-only. Spec non-goal wording clarified explicitly (no ownership/ordering change). Test-only source unchanged during final-r3 runner. Mutation did execute1test/2failures as expected; runner's first regex missed singular “test”, so exact completed log was reparsed and invalid parser receipt preserved. Exact current actor restored and hash verified before final runner; no mutation reexecution or false zero-test PASS.

## Independent final review r4
Lorentz bounded source/test-source PASS, F1 and T1 closed at exact current actor/protocol/test/spec hashes. It confirms no ordering relies on deadline timing; the original waiter alone must reach current-final gate after reset and return successor generation3. Main-owned mutation log demonstrates absence of that gate when only epoch receipt invalidation is removed. Source/spec boundary clarification verified mechanically. Reports r1–r4 retained. Read-only reviewer now closed; test worker previously closed, no active subagents. Final focused/full runner still live; no native action or whole-product completion inferred.

## Final stage closeout
Complete bounded repair: focused 106/0/full 3336/0/diff0,545 unchanged frozen inputs, final 12 lifecycle methods. r1Debug/Release/package365keys×3 remains production-input-identical after tests-only follow-ups; candidate a35442f3 unsigned/uninstalled/unlaunched. Independent r4 source/test-sourcePASS, all agents closed; no worker acceptance invented. Runtime boundary freshly process-checked, priorfd395b00 not replaced, no native UI action. Source resetP1 + protectedpeerF1 closed for written scope; next executable work is separately specified Core reentrancy/icon-source/diagnostic ownership or actual remaining parity gates, not deferredhitch profiling. Full goal remains active/incomplete.
