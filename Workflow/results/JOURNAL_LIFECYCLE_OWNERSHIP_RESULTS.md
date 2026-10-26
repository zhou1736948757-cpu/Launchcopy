# Journal lifecycle ownership results

Date: 2026-10-20. Status: bounded maintenance implementation, independent source/test-source review and final serial verification COMPLETE. Full product parity remains incomplete.

## Scope and implementation
Only LayoutStoreActor.swift, LayoutStore.swift documentation and new LayoutStoreLifecycleOwnershipTests.swift differ from the545-input frozen maintenance baseline. Shared initialization prevents duplicate directory/lock/classification work. Reset admission fences old drain epochs, queues exact FIFO reset receipts behind actual owned I/O completion, and retains latest post-admission successor without starting a competing writer. Flush preserves its existing post-initialization deadline/caller cancellation while discarding obsolete epoch receipts. Same-second reset evidence uses neutral unique archive names. Protected startup retains validated-v1 peer generation high water before an explicit reset, without trusting future/invalid fields or lifting protection.

No product default/schema/format/physics/visual/reference change. No on-disk user reset, installation/signing/commit/cleanup/signal or native action. Inspection found no production caller of the reset API; these are concrete API-level interleaving risks, not a claimed observed loss of the user's current arrangement.

## Evidence so far
- First existing actor/codec/terminal packet64/0; new9cases firstGREEN.
- Observationally instrumented frozen old actor: selected3cases execute/17failures (including1timed observation unexpected failure), proving exercised baseline duplicate initialization, archive/temp interference/parallel writes and generation regression. Original semantic baseline/observed-baseline scripts+hashes retained; current actor restored byte-exact in finally.
- Frozen r1: focused103/0, full3333/0, Debug/Release package/diff exit0;365keys×3languages validated. Candidate .build/candidates/journal-lifecycle-rc-20261020-r1/LaunchcopyUITest.app, executable SHA a35442f38fae1513180217b113ad5b437caf1cd06eeb31483e9d725223ae804c. Unsigned/uninstalled/unlaunched.
- Test-only follow-up r2: focused105/0, full3335/0/diff exit0; production inputs and binary exactly identical to r1 build. Source-only reviewer PASS r2 with two coverage refinements. Two more tests cover held successor and accepted successor after writable failure; r3 confirms those but notes old waiter did not cross reset completion.
- Added distinguishing original-waiter-through-reset test:12cases/0 at first run. A bounded final-success gate distinguishes stale failure receipt from current epoch retry. One-block mutation check and final focused/full run pending.

## Review and ownership
Independent Lorentz r1 FAIL P2 protected-peer high-water gap was fixed; original report retained. r2 bounded production SOURCE PASS; r3 carries it forward unchanged and identifies a test evidence gap, not a production defect. Main has added its direct regression; final review requested after mutation restore. The initial disjoint test worker never produced a file/checkpoint through bounded recovery; closed before Main took over the file. At most3agents including Main; all SwiftPM operations serial.

## Runtime and honest limits
New maintenance candidate was not opened or installed. The previously running library-header candidate fd395b00/PID28936 was not replaced; its last exact process-path observation is separate from build receipts. No current native/real filesystem crash-durability/physical smoothness/VoiceOver/IME/hardware acceptance is inferred. Initialization waits retain their existing unbounded-I/O boundary; cross-process writers and external future-file changes are not redesigned. Test teardown releases continuation gates asynchronously; these memory I/O tests do not verify OS replacement/fsync semantics.

User has explicitly deferred the first Library swipe hitch as non-blocking. CPU load remains a hypothesis, not a root cause; no further hitch profiling/tuning occurred. Other architecture findings (Core reentrancy, mixed anchor ordering, icon source incarnation, coherent diagnostics and shared JSON helper ownership) remain separately scoped open work.

## Final closeout
Final frozen 545 inputs: focused 106/0 and full 3336/0/diff0. All 12 new cases GREEN, including original old flush waiter across reset and current-epoch failure recovery. Exact one-block mutation RED1test/2failures; source restored26169672. Initial parser missed singular test, same completed log reparsed without rerun; invalid receipt retained. r4 bounded source/test-source PASS closes F1/T1 at final hashes. Tests-only changes after build; all production/package inputs and a35442f3 binary identical to the passed Debug/Release packaging packet (365 keys × 3 languages). New artifact never launched; priorruntime separate process-only receipt, no UI acceptance. All subagents closed. See final-r3/verification.json and runtime-boundary.json. No remaining mandatory work for this bounded maintenance repair; full parity and other explicitly listed architecture/native/device boundaries remain incomplete.
