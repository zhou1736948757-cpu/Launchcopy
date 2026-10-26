# Folder Search Responder: Independent Source Review

Date: 2026-10-17
Verdict: **PASS — bounded source review only.** No blocking finding in the specified owner-method change or four added tests and two helpers. This is not native candidate acceptance.

## Scope and contract

Reviewed `AppDelegate.swift:1447–1481` against `AppDelegate.before.txt`, and the four added methods at `AppDelegateBoundedRegressionTests.swift:425–532` plus helpers at `954–973` against its adjacent before-copy. Read the stage summary and only supporting search, keyboard, title-completion, wiring, and fixture code. This is the existing Swift/AppKit composition-root responder contract; no architecture change is needed. Chief waiver and reviewer-only write scope apply.

- **Ownership:** The handoff requires the owner's current search field to belong to the owner's actual window and that window's current responder to be that field or its current editor. Search-active flags or retained query alone cannot steal focus from another responder. The existing keyboard view accepts/becomes first responder unconditionally; the patch uses native negotiation rather than forwarding Escape globally.
- **Refusal:** A false `makeFirstResponder` result exits before title completion, transition cancellation, folder-state opening, or overlay mounting. No explicit query clearing, generation update, forced unmarking, or selected-member assignment was added. This is not a transaction-wide rollback: existing pointer keyboard bookkeeping precedes the owner call.
- **Reentrancy:** After native callbacks, the captured window, search, keyboard, assembly, and folder-state identities must still match the owner. A second snapshot lookup obtains the current entry and rejects removal. These checks protect the captured owners; they are not a general lock against every possible mutation or recursive callback.
- **Missing context:** Missing/mismatched window, missing search/keyboard, or an unrelated responder skips negotiation and retains the previous opening path. The new checks are deliberately conditional, not a universal no-window/no-keyboard opening prohibition. Window loss/replacement during an attempted handoff is rejected by the post-callback identity guard.
- **Search/keyboard semantics:** Existing query and generation remain intact; pointer opening retains deferred member selection. Once the keyboard owns input, its existing Escape priority closes the folder, arrows use existing inner navigation, and Command-F closes then activates search. Title completion and search's folder-priority key-window restoration remain in their existing paths. No capacity, physics, store, or global keyboard policy changed.

## Added-test assessment

1. Clears a previously nonempty native field editor, opens through the installed renderer callback, verifies actual keyboard ownership and deferred selection, then delivers one Escape to the actual responder and checks closed state and unmounted overlay. It does not bypass the defect by calling the keyboard directly while another responder owns input.
2. Exercises nonempty query handoff and checks field text, query, generation, and deferred selection.
3. Installs an actual NSWindow-provided custom field editor that refuses resignation; checks unopened/unmounted state and retained editor/text. Refusal is released for cleanup.
4. Executes an actual resignation callback that clears `owner.window`; verifies the callback ran and opening was rejected, then restores the fixture. Despite its name, it tests loss to nil, not assignment to a different non-nil window. The identity guard also covers replacement by inspection.

Helpers are private, main-actor isolated, use the native field-editor delegate seam, and clear the injected callback before invoking it. The additions are relevant behavioral regressions. They do not exercise every identity guard, unrelated/missing-window branch, same-owner data mutation, or real marked-text composition.

## Frozen evidence and hashes

Both before-copy SHA-256 values match their entries in `source-before.json`. Baseline and freeze each contain 466 keys: 464 unchanged, exactly the two existing reviewed inputs modified, no manifest keys added or removed. A read-only hash pass found all 466 current inputs matched the freeze; both reviewed files were checked again immediately before writing this report. This establishes manifest-input identity, not a general repository cleanliness claim.

| Input | SHA-256 |
| --- | --- |
| AppDelegate before | `82f4a00a4561069a1ca16f7b62f29037f600de55b06b85af55d457ea0730a918` |
| AppDelegate reviewed | `70ab9a284887c7ffcceba40ec8492d83308789854cd7bb051216ad96bd085a30` |
| Bounded tests before | `97ba2b8d2711c2cbae64325fcf8f311ed04f473097e394168ce633d2946fc195` |
| Bounded tests reviewed | `cbda5c4188137d81fb2232e6ea6ba9428b0ae9fabbaf29e747d42dcffb83182c` |
| source-inputs-r1.json | `4de5fdf73c56d69e3fb7b4ae8945e3d5fe90866b044ed59b95c715e110386af5` |

Read existing `red-r2.log`: one executed test, three assertion failures involving responder ownership, first-Escape closure, and overlay removal. Read existing `focused-r2.log`: 92 executed tests, zero failures, 3.683 seconds test time; all four added cases recorded as passed. These are Main's persisted executions, not reviewer reruns. Main subsequently reports full 2818/0 (53.538s) and Debug success (0.33s); those later results were not independently inspected here.

## Evidence limits and next gate

No reviewer tests, builds, UI/process actions, reference-app inspection, OS changes, installs, signing, deletions, resets, commits, or new agents. Only this report was written; the stage summary was read, not changed. Initial instruction/workspace/memory lookup commands inadvertently lacked RTK; all subsequent shell calls used RTK.

The prior 929e native counterexample is supplied context, not new reviewer observation. Release/package remain Main-owned and pending in the latest handoff; the unchanged 929e test app is not evidence for the repaired candidate. Main must complete packaging and the exact candidate's original native sequence/control. Real IME/composition remains **unknown**. Prior user folder acceptance remains context; capacity remains pending and outside this review.
