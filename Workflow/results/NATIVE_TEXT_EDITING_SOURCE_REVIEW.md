# Native text editing — independent bounded source review

Date: 2026-10-15. Verdict: **SOURCE PASS** for the frozen source below. No remaining actionable source findings; 0 blocker / 0 major findings. This is not a test, native GUI, IME, accessibility, performance, packaging, or overall stage acceptance verdict.

## Authority and execution boundary

Reviewed the repository AGENTS.md, `/Users/mac/.codex/RTK.md`, current stage summary `Workflow/stage-summaries/2026-10-15-native-text-editing.md`, workflow configuration/state and applicable plan/brief constraints. The current user dispatch and Chief waiver supersede historical runtime instructions. Domain: SwiftPM tools 5.9, macOS 14 AppKit application, app-owned localization snapshots and existing deferred language owner.

Reviewer executed **0 tests, 0 builds, 0 Swift commands, 0 UI/process-control actions**, and dispatched no agents. All shell invocations used RTK. Only this report was written. Existing dirty work was preserved; no reference implementation, restricted paths, or assets were read. Main owns serial validation and native before/after work.

## Frozen source and exact delta

Baseline: `.build/verification/20261015/renderer-handoff/source-inputs-final.json` — 446 inputs.

Reviewed freeze: `.build/verification/20261015/native-text-editing/source-inputs-final.json` — 448 inputs; SHA-256 `62b28124114ceb29226f801ac9bbd401746cfe06704ce96a1237285f16c683e0`.

Independently recomputed all 448 file hashes: no mismatch. Relative to baseline: **8 modified + 2 new files, 438 unchanged, 0 removed**. All 18 `Sources/PagingCore/` and `Sources/PagingUI/` inputs match baseline. The complete bounded delta is:

- `AppDelegate.swift`: one retained edit-menu controller property; one Edit submenu inserted between existing App and View submenus; installer changes from private to internal with `@MainActor` and updated documentation; one relabel call inside existing `presentLanguage`. In-memory reversal of precisely these edits reproduces the baseline AppDelegate SHA-256. There is no caller, Quit/View action, shortcut, responder/event-handler, input-state, lifecycle-readiness, or physics change hidden in this file.
- New `LauncherEditMenuController.swift`: six standard nil-target commands, two separators, auto-enabling, and seven existing-localization-path labels.
- `MenuTextKey.swift`: seven static cases and English fallback values. Each of the three resource tables adds exactly the corresponding seven entries. Removing these additions in memory reproduces each baseline source/resource hash.
- Localization validation tests: independent 15-key menu vocabulary/required-resource coverage, exact three-language labels, and missing/invalid/static-placeholder fallback checks.
- New `LauncherEditMenuTests.swift`: four bounded tests covering installed production menu structure, localized identity-preserving relabel, deferred language ownership, and native menu key matching with a local spy.
- `MenuMutationLifecycleTests.swift`: initial-readiness setup only, plus deterministic generation invalidation and current-generation assertion in the existing Library stale-sheet test. Reversing just this block in memory reproduces the baseline hash; all original post-writer-replacement callback/no-write/fresh-action assertions remain byte-for-byte unchanged.

| File | Baseline SHA-256 | Reviewed SHA-256 |
|---|---|---|
| `Sources/LauncherLocalization/MenuTextKey.swift` | `85bd52938ebeb465d3e92739e0664ab7c854a7f76765e3b976ccbc49ecef4a63` | `a99860a866087b044a0acc1d77f728d1f6da49cc1de3993cf1099ee185c38d14` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | `5121349f6c840231942acef6fdefde82a0f6576c105e292e5f6b4b7c80e38790` | `abec317decaff46f3d96e258f71f38537390631b5ecfedbdbe24ab342bbd82a0` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | `26d88fecee26f65f77421c352dcb15d31a9dd9f89f55c21165c6c1221ea8bb3b` | `b8aca33f9cff995ca9a264f940008bbf6d2e62c15f76e473c0acc76442c744d4` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | `5755eca0debf13c05fd62d16be00837a16ec25d1da0fae169571a37e8cf15143` | `3ed4f48352e05c7dbb2345772046d5bd27adabc165ad27275d3af4946750bfcc` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `05a5485de9639a33ac5dfe4d0f41de996a8d8f10d5b665d0b3da16e3fe645aee` | `e26c89ef77b6cc7fc1ff914281bc4d3d37a633dc46b0abc2fb6c5c8b12e00136` |
| `Sources/PagingPrototypeApp/LauncherEditMenuController.swift` | `NEW` | `0c11b82eb1d81713e033c0ba6d51a1d9c8d2075f28c308468c99264b1796bc33` |
| `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift` | `a616059fe03ec7269bbf5b2db3f3c859a200eb6a5e5a251237dc9e3507383ae5` | `6823906e38eb232111895287f7dad44ccebd72964115b48b49d1b47e06a66081` |
| `Tests/LauncherLocalizationTests/StatusMenuNoticeLocalizedStringsTests.swift` | `7f1efbc96a1fcf26f1af3e533531b8799788d225aeacacf8e961145169ca7dfe` | `8451b4d949d2a96e8841672e0fe02d15b940ba336a31c684244d95e863b195fe` |
| `Tests/PagingUITests/LauncherEditMenuTests.swift` | `NEW` | `4c7bf63e704f552e6a527e30e9b007e3c1c1fc01fc4563d77e983e565eed3155` |
| `Tests/PagingUITests/MenuMutationLifecycleTests.swift` | `e0b93b384100b7cb1d2fad90a54c322d9ea7e5149b73fa34305a7a47f96a3d58` | `6670f9f83a0e53c5a61071e02e63d9b0c5853196f4645f0107d548ef6df97b90` |

## Source findings and rationale

### Standard native edit contract

`LauncherEditMenuController.swift:12-44` registers `undo:`/Command-Z, `redo:`/Shift-Command-Z, `cut:`/Command-X, `copy:`/Command-C, `paste:`/Command-V, and `selectAll:`/Command-A. Every production command has a nil target; `autoenablesItems` is explicitly true. No forced enabled state, custom action implementation, chosen text editor, key interception, global monitor, clipboard I/O, or copied text exists in the new controller. Command availability and execution remain with AppKit's current responder and validation path. This safely supplies the missing menu registration contract identified by the installed-menu RED.

`AppDelegate.swift:1914-1947` preserves App/Quit and View/Toggle behavior and ordering around the new Edit submenu: terminate selector/Command-Q remain, and View retains its toggle selector and Control-Command-F. The installer is main-actor isolated consistently with AppKit lifecycle integration; widening visibility is a narrow test seam.

### Deferred language semantics and ownership

`AppDelegate.swift:2535-2560` adds only `editMenuController?.relabel(strings:)` to the existing presentation transaction. It does not issue a second language request or alter ownership/readiness. Existing `LanguagePresentationController` requires no interaction owners and readiness before presentation; existing `LanguageRuntimeObservers` handles menu tracking with counted leases. Relabel updates titles on existing objects, including submenu and top-level item, without rebuilding the menu, changing selectors/targets, acquiring focus, mutating user text, or bypassing composition guards. AppDelegate retains the controller; there is no new closure/retain cycle.

### Localization and invalid-resource contract

Seven keys (`menu.edit`, `menu.undo`, `menu.redo`, `menu.cut`, `menu.copy`, `menu.paste`, `menu.selectAll`) have matching English, Simplified Chinese, and Japanese resources. Existing `ResourceKey.all` includes every `MenuTextKey` with an empty placeholder signature. Existing strict validation therefore includes all additions without a permissive special case. `LocalizedStrings.menuText` retains selected validated resource → validated English resource → static English safety fallback behavior; nil snapshots use the same static fallback. Missing/invalid resources cannot turn these labels into raw keys or interpolate user data.

The changed tests check each key's missing entry, invalid/empty/control/oversized value and unexpected placeholder; they also check valid neighboring labels remain unchanged and invalid/missing English fallback remains safe. Whole-table failure and exact shipped table coverage remain tested in source. This review did not execute packaged-resource probes.

### Meaningfulness and limits of the four menu tests

- `LauncherEditMenuTests.swift:9-33` calls the actual installer, verifies all six selectors/keys/modifiers/nil targets, auto-enabling, and App/View preservation. Main's original installed-menu RED demonstrates this test fails on the missing production contract.
- `:35-53` verifies all seven labels in three languages and retained command-item identity/nil targets across relabel.
- `:55-85` drives the existing language owner with a marked-text lease, proving in test design that titles remain old while owned and update after release on the same menu objects. This synthetic lease is not real IME acceptance.
- `:87-103` honestly tests **menu key matching only**: it asserts the production paste target is nil, installs an explicit local spy on an unshown controller, performs a synthetic NSMenu Command-V key equivalent, verifies one delivery, then restores nil with `defer`. It does not access clipboard content or depend on global key-window/NSApp.nextResponder state. It does not establish native field-editor responder routing. That remains Main's separate native-after gate.

The revised local-spy test appropriately repairs the full-suite global-state assumption without pretending to preserve the superseded responder-routing proof. The prior conditional-cast-only version is no longer the reviewed test.

### Library test readiness correction

Original `MenuMutationLifecycleTests.swift:287-290` captured one generation before an asynchronous initial projection became usable, then repeatedly resolved that same request. `AppLibraryOwnerController.resolve` rejects a generation mismatch (`:214-221`); `refreshProjection` increments generation (`:244-255`), including preference/catalog fanout. Once stale, waiting alone cannot make this request current before the two-second deadline.

The reviewed `MenuMutationLifecycleTests.swift:287-299` deliberately calls `catalogDidCommit`, asserts generation changed and the old request is rejected, then rebuilds only the **initial** request from current generation on each await iteration. The deadline remains two seconds, and yield occurs only while resolution is still unavailable. The added assertion requires the finally accepted request to be current. Main's deterministic RED reproduced the same three setup failures while the explicit invalidation assertions passed.

This is an appropriate test setup repair. Critically, `:300-318` still captures the old sheet completion, replaces the writer with an identical-directory writer, invokes that original completion, requires neither writer to have received a write and layout to remain unchanged, then requires a fresh action to write exactly once to the replacement writer. The stale callback is never refreshed or rewritten. Production generation/writer guards are unchanged. The deterministic invalidation proves the setup weakness; it does **not** identify the exact asynchronous callback/schedule responsible for the earlier natural full-suite failure, which was not instrumented.

### Privacy, scope, and performance boundary

The reviewed additions contain static command identifiers/labels and synthetic test data, with no new logging or persistence of user text, selection, clipboard data, keys, or state. No user-content translation was added. No production Library, search/editor/input handler, paging, frame/gesture callback, timer, catalog refresh, or physics source changes belong to this delta. Menu creation occurs at installation and relabeling at the existing safe language presentation. This establishes a bounded source change, not a measured no-regression performance result.

## Existing Main evidence inspected; no reviewer execution

All paths below are under `.build/verification/20261015/native-text-editing/`:

| Evidence | Observed result and limitation |
|---|---|
| `native-before.json` | Exact renderer candidate executable SHA-256 `1d9d1caada6a77ab14aad364a09f59a2a92a7071ce7d2ea534885897d95dd51f`; synthetic native observations record Select All replacement/paste failure and only App/View menus. Recorded normal Quit/exact-process absence. No native-after or real IME proof. |
| `red.log:38-49` | Actual installed-menu regression: 1 test / 1 failure; no paste submenu. Valid RED, not PASS. |
| `focused-r1.log` | Production installer actor-isolation compile error plus actor warning; no XCTest execution. Fixed source now annotates installer `@MainActor`. Never counted as accepted tests. |
| `focused-r2.log` | Test-only identity comparison on AppKit `Any?` failed compilation; no XCTest execution. Subsequent cast correction compiled, then the global-state test design was superseded. Never counted as accepted tests. |
| `focused-r3.log` | Terminal 67 tests / 0 failures on the earlier test revision. Historical evidence only, not final-freeze acceptance. |
| `full-r1.log:4151,4599-4601,6068-6070` | Terminal 2640 tests / 4 failures: one no-key-window guard (no command sent), three Library setup assertions before stale writer replay. Retained failed full run. |
| `repair-focused-r1.log:40-44` | Terminal 12 tests / 0 failures after local-spy menu correction, before final deterministic Library readiness repair. Not final-freeze acceptance. |
| `readiness-red.log:13-22` | Deterministic initial generation invalidation: 1 test / 3 setup failures, matching the failure shape. Explicit invalidation assertions did not fail. No production edits required. |

`focused-r4` was live at Main's final freeze update; active output is deliberately excluded from this verdict. Any later full tests/build/package/native results belong to Main's serial validation and are not presumed by this report.

## Remaining gates and handoff

Source review can pass independently of unresolved execution gates. Main must associate terminal nonzero focused/full test counts and Debug/Release/package-resource validation with the final 448-input freeze. Native after must exercise current field-editor routing and ordinary Command-A/paste in the isolated candidate; menu structure and a local spy cannot substitute for that observation. Real IME, physical keyboard/trackpad, VoiceOver, and measured performance acceptance remain separate. No claim of overall feature/stage completion or exact natural-race causal provenance is made.

Changed by this reviewer: `Workflow/results/NATIVE_TEXT_EDITING_SOURCE_REVIEW.md` only. No source changes, no test/build execution, no process/UI control.
