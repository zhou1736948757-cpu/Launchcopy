# Appearance close/discard — independent bounded source review

Date: 2026-10-15  
Verdict: **BOUNDED SOURCE PASS**  
Findings: **No actionable P0/P1/P2/P3 defect identified within the reviewed delta.**

## Authority and review boundary

Reviewed the assigned existing-contract bug fix in `/Users/mac/Projects/Launch_Copy/PagingPrototype`. The user authorized the Chief waiver and the Main + one reviewer arrangement (two total, ceiling three). No agent was started or messaged by this reviewer. Sole written artifact: this report. The pre-existing dirty tree was preserved.

Read project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, the current `Workflow/stage-summaries/2026-10-15-appearance-native.md`, workflow configuration/state and plan/brief context. The dated stage and explicit assignment define this bounded review; older workflow handoff/state entries are historical context, not evidence of current runtime acceptance.

This is a Swift Package macOS 14+ AppKit application. AppDelegate composes the retained settings controller, independent appearance persistence/coordinator, and queued runtime presentation. The repair fits those existing ownership boundaries.

No source/test edits, tests, builds, Swift execution, UI interaction, application/process control, installation, commits, reference implementation access, or raw asset access were performed. Review consisted of reading authored source/specifications and existing text/JSON evidence, hashing frozen inputs, and reconstructing prior source in memory. Bootstrap deviation: the initial RTK-instructions read and working-directory/tool lookup were issued without the RTK prefix; every subsequent shell invocation used RTK. No project files were changed by those initial reads.

## Frozen inputs and independently verified delta

Baseline: `.build/verification/20261015/library-status-visibility/source-inputs-final.json` (451 entries). Final: `.build/verification/20261015/appearance-native/source-inputs-final.json` (452 entries). Independently hashed all 452 current files: zero missing files or hash mismatches. No baseline inputs were removed. Only these four entries changed or were added:

| Input | Final SHA-256 |
|---|---|
| `Sources/PagingPrototypeApp/AppearanceSettingsView.swift` | `62be0ce3490f895275502f9df79bd8dd4dc566a5bcca069ace30c35ddf823b78` |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `2cb1e1523a894bf67733aba9f0e9108f844561ac9bd3ce97d53ef775cefafe35` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `a89a1ac50d887c1f9ff93f9eb3c6e80f74d5691a68b11dba54c8f1754e868cb8` |
| `Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift` (new) | `5064ace0b451e85d836729a4c9176c43917fff1c8fad53201372aaf8e82718e3` |

Final manifest file SHA-256: `cc7a6494bf9513bfe2cebc6048946b696f33c00b0ec5a6be29a892b95c139ffd`.

Independently removed the exact three additions in memory (2, 1, and 8 lines respectively), rather than relying solely on Main's `close-delta-proof.json`. Each reconstructed source matched its actual baseline-manifest SHA:

- AppearanceSettingsView: `f71805692f7f1bae53fd6cdf0782f87220b84cf85bd6c668a75b535e92b4c76d`.
- ActivationSettingsWindowController: `117b3a9180fdb1e5c776e6d1320d0a83d2245c8caaa3dc8fc763f06e468be843`.
- AppDelegate: `de331b06d0e955ef77d9860bdbdd97c838422902268cf57dbeda78589ae49ec0`.

Thus all existing Core/UI, resources, package configuration, capacity, physics, and unrelated language/draft implementation are unchanged relative to this stage baseline. This does not certify the larger historical dirty-tree diff against Git HEAD.

## Correctness and ownership evidence

1. **Contract and trigger.** `Docs/ICON_AND_TYPOGRAPHY_SPEC.md:38-45` explicitly requires closing to discard only unsaved appearance draft, Restore Defaults to remain draft-only, and accepted presentation to defer safely. `Docs/INTERFACE_LANGUAGE_SPEC.md:59-66` preserves drafts during relabel/reentry; it does not revoke the appearance close contract. Main's stage records default true/18/48/11, unapplied false/0/64/16, unchanged grid after native close, then incorrectly retained draft on reopen. That native observation belongs to Main; this reviewer did not reproduce it.

2. **Close paths converge.** The internal `AppearanceSettingsView.onDiscardDraft` declaration is at lines 13-14. The only added invocation is `ActivationSettingsWindowController.swift:327`, after `orderOut` inside existing `hideSettings()`. The native close delegate (355-358) and explicit Close action (393-395) both call that method. Coordinator hide (115-118), launcher settings toggle (`AppDelegate.swift:3207-3214`), background dismissal (3362-3368), and launcher-hide fallback (3263-3275) converge there too. The coordinator's existing possible duplicate hide invokes an idempotent snapshot reload; this addition introduces no persistent operation.

3. **Lifetime and identity.** `AppDelegate.swift:2140-2147` weakly captures the app, coordinator, and view, then requires all three to exist, final teardown not to have run, and both current coordinator and configured view identities to match. The view therefore does not retain itself or either owner, and a retained obsolete callback cannot reload a replacement view or act for a replaced coordinator. The configured-view reference itself is weak (104). Final teardown sets `didRunFinalTeardown` (3552) before hiding settings (3575), so that teardown path cannot reload appearance controls through this callback. Main-actor isolation matches the existing view/controller/coordinator operations.

4. **Accepted values, queued values, failed saves.** The callback fetches `coordinator.committed` and `coordinator.loadResult` when dismissal occurs, rather than capturing configuration-time values or using the older displayed `appearancePreferences`. `AppearancePreferences.swift:137-151` changes committed state only after successful persistence. Failed Apply therefore closes back to the prior accepted values. Accepted-but-queued values survive close even while displayed geometry remains older; pending presentation is not cleared or flushed by the new callback.

5. **No added I/O or runtime application.** The callback invokes existing view `reload` only. `AppearanceSettingsView.swift:119-146` synchronizes local draft/controls and feedback; its presentation provider reads the app's state property (`AppDelegate.swift:2199-2201`). This path calls neither store load/save nor coordinator Apply nor runtime apply/flush. Existing owner-specific hide/readiness scheduling remains baseline behavior; this finding does not assert that every pre-existing hide callback is globally side-effect-free.

6. **Load protection and feedback.** Passing the current coordinator load result retains existing future-version disabled controls and future/corrupt-load feedback (`AppearanceSettingsView.swift:124-146`). Healthy reload clears unsaved/defaults/failure feedback; queued accepted settings regain queued status through the existing provider. Discard does not invent an applied acknowledgement. Close-specific future/corrupt and owner-deallocation behavior were checked by source reasoning, not independently executed tests.

7. **Other drafts and language stay isolated.** The callback reloads only the appearance view. Existing language discard/readiness callbacks remain in place and order. AppDelegate still enables `preservesInterfaceDraftsOnReopen` (2047); retained reentry still refreshes accepted language without reconfiguring other sections (`ActivationSettingsCoordinator.swift:76-105`). Relabel still updates appearance text/accessibility without reload (`AppearanceSettingsView.swift:236` onward). No activation, alias, source, Library, tab-selection, or language-relabel logic was added or altered by the three source hunks. The new property is internal; no public API or settings capacity contract changes.

## Existing verification evidence — Main only

Read `.build/verification/20261015/appearance-native/close-red.log`: four tests, six assertion failures before the repair. Read `close-focused-r1.log:84-98,210-212`: all six new integration tests pass; the focused run totals 63 tests, zero failures (4.140 seconds). These are **Main's recorded executions**, not reviewer-run tests or independent execution certification.

Reviewed the new test source. It uses actual AppDelegate configuration and an unshown native controller, an injected counting store, and production close/hide methods. It covers close-discard/no extra storage reads or writes, defaults-draft cancellation, accepted queued values versus old presented values, failed save, activation/alias draft isolation, and a retained old-view callback. Tests remain source-level/in-process regression evidence; the close-delegate test name does not establish an end-to-end physical/native UI run.

Reviewer execution counts: **0 tests, 0 builds, 0 UI runs**. No claim is made for a later Main full-suite/build/package result.

## Remaining gate and handoff

This source gate may close for the frozen delta. It does not establish post-fix GUI, process-restart, physical input, VoiceOver, IME, performance, or complete parity acceptance. Main must bind subsequent native close/reopen/defaults/Apply/restart checks to the actual repaired candidate and record their own observations. No required source repair identified within this assignment.
