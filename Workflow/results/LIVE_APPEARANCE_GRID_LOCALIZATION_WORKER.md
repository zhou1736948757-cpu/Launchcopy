# Live Appearance and Grid Localization Worker

Date: 2026-10-17
Status: Implementation handed off; verification pending with Main. No source-review or runtime verdict is asserted.

## Scope and authority

Implemented the localization-only slice of the human-approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md`. Main owns integration and serialized verification; the UI worker owns UI adoption. This worker made no changes to UI, persistence, presentation ownership, package configuration, historical text keys, or workflow state. Existing unrelated work was retained.

## Exact public API

Module: `LauncherLocalization`

```swift
public enum LiveAppearanceTextKey: String, CaseIterable, Sendable
public var englishFallback: String { get } // LiveAppearanceTextKey member
public func liveAppearanceText(_ key: LiveAppearanceTextKey) -> String // LocalizedStrings member
```

The 13 cases, in declared order, are `help`, `gridHelp`, `saving`, `saved`, `saveFailed`, `retry`, `recover`, `defaults`, `defaultsApplied`, `queued`, `unavailable`, `protected`, and `recoveryRequired`. Raw values use `liveAppearance.<case>`.

`LocalizedStrings.liveAppearanceText(_:)` follows `mainGridCapacityText(_:)`: selected validated snapshot, then validated English snapshot, then the key's English fallback. Rendering does not request resources. All new keys are registered in `ResourceKey.all`, `name`, and the empty placeholder signature, and therefore in `LocalizedStrings.requiredResourceKeys` and strict resource validation. The packaged-resource probe iterates all new cases after its existing main-grid loop.

## Adoption semantics for Main and the UI worker

- Use `.help` and `.gridHelp` in the live UI instead of the historical draft/Apply help. The new copy describes live effect, automatic save, no discard on close, unsafe-interaction deferral, and additional closed-folder/App Library gating for main-grid reflow. Folder layout remains independent.
- `.saving`, `.saved`, and `.saveFailed` belong to each relevant domain's current save result. `.saved` says only that changes were saved; it does not claim they were displayed, fsynced, or crash-durable. `.queued` independently describes pending presentation and does not assert save completion. Do not let an older receipt select current success copy.
- `.defaults` labels the scoped Restore Appearance Defaults action. `.defaultsApplied`, despite its requested case name, reports that Appearance defaults and the 5-column/7-row main-grid default were requested. It explicitly describes separate save outcomes and possible partial failure. Display each domain's actual status alongside it. It makes no aggregate save-success or already-presented claim and preserves other settings and app arrangement.
- `.retry` is Retry Saving, and `.saveFailed` retains the latest intention and names that action. `.recover` is a distinct explicit recovery action; `.recoveryRequired` names it and describes replacing damaged settings. Main must wire it only to supported explicit recovery, never use it to authorize replacing future/ambiguous formats.
- `.unavailable` and `.protected` describe paused automatic saving and preservation of stored data. Programmatic load, relabel, reopen, and resize must not invoke writes. These strings do not implement those guards.
- Historical `mainGridCapacity.*` and existing Appearance keys and fallback strings were left unchanged to preserve legacy consumers and tests. Live UI consumers must select the new scoped keys wherever old copy describes Apply or discard-on-close.

## Changed files (complete worker write list)

1. `Sources/LauncherLocalization/LiveAppearanceTextKey.swift` — new typed keys and English fallbacks.
2. `Sources/LauncherLocalization/LocalizationResources.swift` — required-resource registration and static signatures.
3. `Sources/LauncherLocalization/LocalizedStrings.swift` — public snapshot accessor.
4. `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` — 13 appended English values.
5. `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` — 13 appended Simplified Chinese values.
6. `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` — 13 appended Japanese values.
7. `Sources/LocalizationResourceProbe/main.swift` — iteration through all new typed keys.
8. `Tests/LauncherLocalizationTests/LiveAppearanceLocalizedStringsTests.swift` — new, unexecuted test cases.
9. `Workflow/results/LIVE_APPEARANCE_GRID_LOCALIZATION_WORKER.md` — this handoff.

## Authored tests (not executed)

The new test file covers exact 13-key order and required registration; nonempty/non-key text matching shipped resources; three distinct translations per key; English fallback parity; absence of legacy Apply/draft/discard instructions; live/autosave/no-discard help; save/presentation separation; separate scoped defaults outcomes; distinct retry and recovery labels; no-autowrite protective copy; selected-language omissions with strict diagnostics; absent-resource fallback; unexpected placeholder rejection in all three languages; and snapshot rendering without further resource-provider reads.

## Main integration follow-up outside this worker's write scope

`Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift`, method `testRequiredKeyContractAndEveryShippedTableHaveExactCoverage`, currently constructs `allKeys` ending with `MainGridCapacityTextKey.allCases.map(\.rawValue)` and hard-codes the corresponding count expression. Both expressions must include `LiveAppearanceTextKey.allCases` in the same final position as production registration. This is an expected additive contract update, not a change to legacy key values. Without that integration edit, its required-key/table equality assertions omit the new family. The file is outside the assigned write allowlist, so it was read but not modified. This is a source-observed integration dependency, not an executed failure.

Main should adopt the scoped keys in the live UI, update that existing coverage assertion, freeze the shared sources, then execute the focused/full localization tests and packaged-resource probe in its serialized verification sequence. Compile, packaged bundle coverage, and English/Chinese/Japanese native layout and scrolling remain unverified here.

## Evidence boundary

Only repository instructions/specification/source reads and the listed file edits were performed. All shell calls were prefixed with `rtk`. No builds, test runs, probe execution, UI/OS manipulation, app/process management, reference-source access, formal-data changes, Git operations, signing, installation, or publication were performed. No runtime acceptance, source PASS, performance, durability, or user physical-experience claim is made.
