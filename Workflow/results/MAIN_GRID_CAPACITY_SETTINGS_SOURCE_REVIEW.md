# Main Grid Capacity Settings and Localization — Independent Source Review

Date: 2026-10-17
Verdict: **SOURCE PASS — bounded settings/localization scope**
Findings: **No actionable P0/P1/P2/P3 source defects found in the reviewed scope.**
Freeze: 2026-10-17T03:19:33.908541+00:00 (12:19:33 JST).

## Authority, ownership and limits

Reviewed the approved `Docs/MAIN_GRID_CAPACITY_SPEC.md`, particularly lines 13–16, 24–30, 45, 64–70 and the superseding human approval at 86–90; repository `AGENTS.md`; RTK instructions; current stage summary and plan; and `Workflow/results/MAIN_GRID_CAPACITY_SETTINGS_WORKER.md`. This is an established SwiftPM/AppKit macOS launcher with a typed, immutable localization snapshot. Explicit human authority waives Chief and caps concurrency at three including Main. This reviewer dispatched no agents.

Only this report is owned or written by this reviewer. No production/test edits, builds, tests, package/probe execution, UI actions, process inspection/control, reference-code access, or workflow-state edits were performed. Verification here consists of source reading, read-only status/baseline comparison, existing-log inspection and SHA-256 calculation. This verdict does not certify other reviewers' foundation/coordinator/owner scopes, native behavior, performance, or full feature/parity acceptance.

The two new implementation files and two new test files were read in full. Existing files were reviewed only for the specific additions and contracts listed below. Full-file hashes identify those bounded inputs; they do not imply a full audit of the pre-existing files.

## Findings and source evidence

No current source finding warrants a repair in this scope. The following checks explain the bounded verdict:

| Contract | Concrete source evidence | Assessment |
| --- | --- | --- |
| Valid, explicit grid draft | `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift:109–133,166–211,233–269`; tests `MainGridCapacitySettingsViewTests.swift:58–78,201–240` | Six retained menu items per dimension use validated 3…8 tags. All 36 pairs derive 9…64 items/page. Edits/defaults do not submit. Missing/foreign/tampered menu selections and inconsistent count/draft presentations are rejected rather than clamped. |
| Admission is not Saved | View `:179–201`, especially status set before the Boolean callback at 194–200; `:136–164`; tests `:80–122` | A true callback establishes Saving only. A nil receipt cannot establish Saved/Applied; pending writes take precedence. Only explicit `.saved` with no pending writes selects applied/queued/unavailable presentation feedback. Synchronous status publication is not overwritten after admission. Actual disk provenance and generation ownership remain the owner/coordinator review's responsibility. |
| Dirty draft survives receipts and language | View `:136–164,214–231,277–286`; tests `:124–144,185–199,242–305` | Status updates do not assign the draft or reset either popup. Failures remain retryable unless storage protection requires reopen. Relabel only changes retained text/AX presentation, retaining menu/control/constraint identities and callbacks. Defaults feedback and receipt feedback use separate channels. |
| Protected/unavailable/recovery behavior | View `:101–103,110–133,149–156,166–180,204–205,271–274`; tests `:40–56,146–183,242–261` | Unconfigured, protected-format and unavailable loads disable both selectors and write-related actions, including direct handlers. Corrupt load allows explicit Apply with a recovery warning; defaults/relabel do not repair storage. Protected/recovery-required save results lock editing; successful save clears a corrupt-load warning. Envelope decoding and fresh write-time checks are outside this review. |
| Scoped Defaults | View `:204–211`; localized `draftDefaults` and `loadCorrupt` wording | Defaults loads only 5 columns × 7 rows into this draft and requires Apply. The view has no cross-store reset call. |
| Close/cancel semantics | `ActivationSettingsWindowController.swift:326–335,360–364,398–400`; tests `MainGridCapacitySettingsViewTests.swift:307–343` | Both hide and window-close reach the retained view's explicit discard callback; neither calls its Apply. Under the approved contract, closing intentionally cancels unaccepted UI edits. Receipt/language refresh must retain a dirty draft; close/discard intentionally replaces it with the owner-provided committed baseline. Retention/draining of already accepted writes across close/Quit is a separate owner gate, not proven by the fake discard closure in this view test. |
| Retained native tab and existing contracts | Controller `:178–183,208–230,273–281,586–618`; `AppearancePreferencesTests.swift:378–388`; `LanguageRuntimeIntegrationTests.swift:71–87` | Grid is appended at index 6 after the six original sections; retained view initialization, tab label relabel, and view relabel are wired. The existing appearance test requires exactly seven tabs and preserves its previous index/identity assertions; the exact language contract is now activation/appearance/management/sources/language/library/grid. No broad rewrite of these tests is needed for this slice. |
| Typed localization registration | `MainGridCapacityTextKey.swift:1–47`; `LocalizedStrings.swift:79–81`; `LocalizationResources.swift:93,105–118,133,147–155` | Exactly 19 namespaced keys, including the small-window notice, have terminal English fallbacks, selected/English snapshot rendering, required-key registration, and empty placeholder signatures. No rendering-time resource access or printf formatting is added. |
| Three resource appendices | `Sources/LauncherLocalization/Resources/{en,zh-Hans,ja}.lproj/Localizable.strings:316–335` | All 19 keys have nonempty corresponding English, Simplified Chinese and Japanese wording. Saved/queued, applied, failed, protected, recovery and small-window messages preserve their distinct meanings. Existing deterministic integer display is used for count. Source byte sizes are 21,092 / 19,970 / 26,701, all below the existing 65,536-byte table limit. |
| Schema/probe/tests | `Sources/LocalizationResourceProbe/main.swift:20–26,41–44`; `LocalizationResourceValidationTests.swift:49–70,74–86`; `MainGridCapacityLocalizedStringsTests.swift:6–80` | Probe adds the typed family while retaining strict package resource validation. Schema coverage/count and no-collision checks include the family. Authored localization tests cover exact keys, real translations, selected/English/terminal fallback, unexpected placeholder rejection and no extra resource reads after snapshot creation. Probe source inspection is not a packaged-probe execution. |

## Dirty baseline and bounded change attribution

The original `.build/verification/20261017/main-grid-capacity/source-before.json` contains 467 entries (SHA-256 `af130f9a2ec5243f5cd90a8d04cfddb4a401507185b291eafdf1f984dc842b68`). Git's broad dirty/untracked state is not treated as this feature's diff.

Independently compared the latest integrated manifest and delta: 482 inputs, 16 changed plus 15 added, consistent with the 467-entry original inventory. This report covers four of those added files and ten of those changed files. The rest belong to other review scopes.

As a read-only attribution check, removed the bounded new hunks in memory and hashed the reconstructed prior content. Nine of ten existing scoped files exactly recover their original baseline hash: controller, typed strings entry point, resource registration, all three resource appendices, probe, schema test, and language identifier contract. No disk content was changed by this comparison. The same reconstruction did not recover the exact original `AppearancePreferencesTests.swift` hash after removing the new comment/identity assertion and restoring count 6; the baseline contains hashes rather than this file's original bytes. Accordingly, exact byte-level attribution of all pre-existing appearance-test text is not claimed. Its present lines 378–388 were reviewed directly for the authorized tab count/identity contract; this provenance limit is not evidence of a functional defect.

The worker's original “authored/unexecuted” wording describes its handoff time. Main's later corrections and execution evidence below supersede that execution snapshot without rewriting it.

## Existing execution evidence inspected; reviewer ran none

Logs are under `.build/verification/20261017/main-grid-capacity/`.

- **R2:** `integrated-focused-r2.log:2855–2921,3005–3008` records 72 tests and 36 assertion failures, all 36 in the single new all-pairs AX test. Actual NSTextField AX values included the full “Items per page: N” text. Main corrected that test's expectation only; current test lines 71–73 agree with the observed full value. This correction does not establish a VoiceOver/native accessibility PASS and does not change production behavior.
- **R3:** `integrated-focused-r3.log:6–18` reports the two redundant `String? as? String` test casts; current test lines 33 and 72–73 omit them. Lines 94–126 record localization 5/0 and settings 14/0. Lines 71–73 and 210–213 record three failures in the optional-Library integration fixture and 75 tests total. Main reports correction through the existing visible-capture seam; no independent source audit of that owner test is claimed here.
- **R4:** `integrated-focused-r4.log:65–108,192–195` records localization 5/0, settings 14/0 and 75/0 overall. This is Main's executed log, read by this reviewer.
- **Latest R5:** `integrated-focused-r5.log:71–83,84–114,198–201` records localization **5/0**, settings **14/0**, and **76/0**, XCTest time **1.262 s** (selected-suite wall total 1.268 s), completed at 12:18:13 JST. Its separate trailing Swift Testing “0 tests” line is not used as evidence; the nonzero XCTest execution is explicit.
- Main reports full-suite job 9492 is live with no source changes during it. This report makes **no full-suite outcome claim**, and no Debug/Release/package/native success claim. The two old-contract tests and complete schema suite are source-reviewed here, not independently rerun or assumed to be included in the R5 filter.

R5 log freeze: 23,897 bytes, SHA-256 `78fbde018403f52f0bad97e6fadfdd472e53c74e68d381c45262a010033dd45e`.

## Remaining gates and integration handoff

These are evidence boundaries, not findings against the bounded source verdict:

1. **Native tab width/layout:** the existing settings window is fixed at 500 × 560 pt (`ActivationSettingsWindowController.swift:457–467`). Seven tabs, long Japanese labels, content/footer wrapping, scrolling, status visibility and keyboard access need inspection in all three languages. Unshown view tests do not prove fit or accessibility. Do not mark this gate passed from source or test count.
2. **Owner integration:** only the store result enums/protocol, coordinator admission/status interface, `AppearancePresentationState`, and `AppDelegate.swift:4607–4660` settings API connection were consulted to understand callback semantics. This is not a duplicate full audit of persistence, asynchronous owner identity, recovery authorization, lifecycle replacement, layout boundaries, Quit or restart. Main must preserve the view contract: reload at explicit open/discard/load readiness; background receipts use updateStatus; relabel does not configure/reload the grid draft; real accepted writes outlive the disposable UI draft.
3. **Accepted-write failure/close:** the settings test proves controller routing using a fake owner callback. It does not prove an accepted failing write remains protected/retryable across real close/reopen/Quit; that remains with the coordinator/owner review and native gates.
4. **Readability/presentation:** this review approves the typed notice and translations only. Actual grid suppression, ability to reach settings, independent folders/Library, endpoints and resizing remain owner/readability/native acceptance work.
5. Complete serialized full tests, explicit builds, packaged localization verification and candidate/native acceptance under Main's existing plan. Unexecuted native gates alone do not block this bounded SOURCE PASS.

## Frozen bounded inputs

Every hash below was re-read from disk and independently matched against `source-inputs-integrated-r1.json` at the freeze time. All 14 also match this review's earlier captured hashes; no bounded-input drift was observed. Any later change to a reviewed hunk requires a bounded re-review, rather than silently extending this verdict.

Integrated manifest: `.build/verification/20261017/main-grid-capacity/source-inputs-integrated-r1.json`, **482 entries**, SHA-256 `0f7d4fad77d9a36679530a454ab6b7ab99610e47192268a90c0a88b35ff40a34`.

Delta: `.build/verification/20261017/main-grid-capacity/input-delta-r1.json`, SHA-256 `1210f69f4321e6ebbbcb293f89661f8ceeef2ca84e9961780e0e08855b31d766`.

| Input (repository-relative) | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift` | `91b484b12c8db3274b4dc60e9cf07c4834b56fcfae443b2957eb7606ef9df8fd` |
| `Sources/LauncherLocalization/MainGridCapacityTextKey.swift` | `5f0694995579f9c01abec475633c06c6f3816da1dd86fb6c38bc1d643dc970c1` |
| `Tests/PagingUITests/MainGridCapacitySettingsViewTests.swift` | `0ce8666095b545b966b5ecdd13cee933200313bad90623586f0e3b340217b21e` |
| `Tests/LauncherLocalizationTests/MainGridCapacityLocalizedStringsTests.swift` | `13fa6411e9b3c4b4d8fe3e62bbcc4239e93ceedfc042642f33fb498fae1e6f8b` |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `c64edd0fb3c6e272769737878e16c05e77884038e89cbbbcefa53decc501dd58` |
| `Sources/LauncherLocalization/LocalizedStrings.swift` | `616fe7807a5f411374e331e04aa8fde6613fa8c134bf9d8ce9fc6c8109baa230` |
| `Sources/LauncherLocalization/LocalizationResources.swift` | `3ee4d81cf1a85394fcb04bec40fc1fb5fd97aa348f57121b26ff68541096fbbe` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | `5b097bdc6ed4d594865f71e16814d4c493ae69526b63aaf6052b7671fb77e80d` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | `4c94fdc47d77f4e4d82c6bbe146da2e54a0d6920f9a05f227b030ad22b41085e` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | `7fdfd3edaaec08f1fe94c9989316961521298650372a06bc272446f2865a1286` |
| `Sources/LocalizationResourceProbe/main.swift` | `595de832fe0c01f2d75c9448d1321cbde2706666f23f71646dba375d4536ce62` |
| `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift` | `6d623f70d8686bf5c43285daa6a6f1171e62406308aa36815a82d3b271787abe` |
| `Tests/PagingUITests/AppearancePreferencesTests.swift` | `c82e09a642de2ddbd987eb9805ec078a1e890ec91250733b117ffba05fdfccff` |
| `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` | `8005e08d6514f411d0d1c28fb80b4f7a10b9a39057a3c40bf7011fc726f46fb0` |

This review writes only `Workflow/results/MAIN_GRID_CAPACITY_SETTINGS_SOURCE_REVIEW.md`. No implementation repair is requested by this source verdict.

