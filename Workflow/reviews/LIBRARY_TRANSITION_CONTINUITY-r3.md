# Library transition continuity — independent source review r3

Date: 2026-10-20
Verdict: **SOURCE_ACCEPT — bounded source follow-up. R1, R2 and T1 are resolved in the reviewed slice; no new actionable finding in this delta.**

## Frozen inputs and review boundary

Input packet: `.build/verification/20261020/library-transition/review-inputs-r4.json`.
Packet SHA-256: `7422e974174290c2717e931f51686f2f94a13c3bad2ef98577c3c5c5e2f124cb`.

All **13 input hashes matched** at inspection and immediately before report creation. Only these two inputs differ from the r3 packet used for the previous review:

| File | Current SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppLibraryOwnerController.swift | b1e8950820e2e1fe76d063316452cfc7589341d687595cb091ad73d430b8d95f |
| Tests/PagingUITests/LeadingLibraryPreviewTests.swift | dfc4066bcee6d54228711eec0030167e77ef532456106263b0542bcc8025888c |

Inspection was limited to the changed owner notification logic, the added regression cases, and the callback ownership corrections. The other eleven hashes match the previously reviewed packet; their source assessments carry forward without another broad audit. Reversing only the preference-defer/activity-guard changes reconstructs the prior owner hash exactly, confirming that the R1 close/admission repair is unchanged.

The specification and accepted scope remain `Docs/LIBRARY_TRANSITION_CONTINUITY_SPEC.md`. Historical findings remain in `LIBRARY_TRANSITION_CONTINUITY-r1.md` and `LIBRARY_TRANSITION_CONTINUITY-r2.md`; neither report was edited.

Read source and retained evidence only. No tests, builds, UI, process signals, Git mutations, formal preference operations, screenshots, reference-product source access, or implementation edits were performed. This report is the only written file.

## R2 — preference notifications after teardown: resolved

Evidence: `AppLibraryOwnerController.swift:404–429`.

- The deferred notification scope checks current `isActive` before invoking readiness (lines 408–410).
- It checks activity again before presentation notification (line 411), covering synchronous teardown initiated by readiness itself.
- The guard after category/save-failure presentation work (line 425) prevents continuation into preference-driven close once that work invalidates the owner.
- The post-close guard (line 427) prevents subsequent projection/entry presentation work after restoration tears down the owner.
- A still-active owner retains the ordinary readiness and presentation callbacks; the repair does not unconditionally suppress successful preference/save-completion notifications.

For the accepted counterexample, a disabled-preference receipt enters `close(restoring: true)`; restoration tears down the owner; the captured outgoing view is detached by close; the outer post-close guard returns; and its deferred activity check emits neither late notification. If readiness itself tears down the owner, the second deferred check prevents presentation notification. The original unconditional-defer failure paths are closed in source.

## Regression coverage: substantive and aligned with the failure paths

`LeadingLibraryPreviewTests.swift:569–592` starts a committed Library session, submits disabled preferences through the injected store, and waits for teardown from the restoration callback. It checks closed state, nil owner view, outgoing-view detachment, denied entry admission, zero notifications after teardown, and no grid reveal. This exercises the preference-receipt entry point missing from the earlier direct-Back test.

`LeadingLibraryPreviewTests.swift:594–604` starts with a loaded owner and makes readiness synchronously tear it down. The synchronous submit notification exercises the between-callback check without relying on an eventual save completion. It requires entry admission to be revoked and presentation notifications to remain zero.

The retained `notification-red.log` was read. It records **two XCTest cases, two failed assertions** before repair: two late notifications in the disabled-receipt case (line 590), and one unwanted presentation notification in the readiness-teardown case (line 603). These are the precise behaviors guarded by the repair. The trailing zero-test Swift Testing message is separate from the executed XCTest cases.

The prior reentry/next-entry, direct restore-teardown, and restore-before-detach assertions remain present. The new cases use in-memory preferences and unshown fixtures with deferred teardown. Reading the RED log and assessing assertions is source/evidence review; this reviewer did not execute GREEN or independently certify Main's final verification.

## T1 — stored test callbacks retaining their owner: resolved

Evidence: `LeadingLibraryPreviewTests.swift:529–533,553–557,579–583`.

The restore callbacks capture owner weakly, bind it only for the duration of invocation, and explicitly fail if it is unexpectedly absent. They preserve the reentry and teardown assertions without a stored `owner → callback → owner` strong cycle. The readiness callback in the new test also captures owner weakly at line 599; the local owner variable keeps the fixture alive during the asserted synchronous action.

The original ordering test now captures the host value instead of the fixture at lines 512–515, removing that callback's reference back to the fixture that owns the owner. Callback state and existing window/view cleanup remain intact. This is a source ownership assessment, not an allocation/leak-instrumentation result.

## R1 preservation and final acceptance limits

The unchanged close repair at `AppLibraryOwnerController.swift:135–138,256–286` still blocks admission throughout cleanup, detaches the captured outgoing identity, preserves restore-before-reveal order, and stops close-tail effects after teardown. The notification fix does not change paging physics, data contracts, product startup, icon admission, material policy or menu routing. The prior quit-fixture correction also matches its reviewed hash.

**SOURCE_ACCEPT applies only to the frozen source slice and this bounded follow-up.** Main retains ownership of final frozen serial focused/full tests, Debug/Release builds and package verification. Earlier successful runs remain historical evidence. This report does not certify a current GREEN run, launch/UI behavior, physical entry/return smoothness, touchpad completion/cancellation, or whole-application acceptance.
