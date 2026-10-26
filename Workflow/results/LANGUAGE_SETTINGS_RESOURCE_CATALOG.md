# Settings Resource Catalog

Status: SOURCE_FROZEN_PENDING_MAIN_VERIFICATION, 2026-10-14.
No PASS is asserted. This supersedes the provisional four-tab catalog.

## Delivered scope and public API

Implemented under the approved `docs/INTERFACE_LANGUAGE_SPEC.md` and Main's
explicit settings-resource assignment, including the four later Main keys.
Ownership was limited to `Sources/LauncherLocalization/**`,
`Tests/LauncherLocalizationTests/**`, and this report. No consumer, group
consumer registry, package manifest, owner/store, or workflow state was edited.
No other agent was invoked or messaged; coordination used the shared key request.

```swift
public enum SettingsTextKey: String, CaseIterable, Sendable
public func settingsText(_ key: SettingsTextKey) -> String
public func hiddenReferenceCount(_ count: Int) -> String
```

The methods belong to `LocalizedStrings`. Settings keys are separate from
`LocalizedTextKey`. There are 71 settings static keys: four top tabs, four
additional Main keys, 21 Appearance keys, 16 Management keys, 26 Sources keys.
There are two new named-integer templates. The required resource contract is now
97 keys: the original 20 static keys and four templates, then 71 settings keys,
then `hiddenReferenceCountOne` and `hiddenReferenceCountOther`.
The original 24 keys retain their values, API, semantics and required-key order.

## Main integration vocabulary

| Case | English | Simplified Chinese | Japanese |
| --- | --- | --- | --- |
| `activationTabTitle` | Activation | 激活 | 起動操作 |
| `appearanceTabTitle` | Appearance | 外观 | 外観 |
| `managementTabTitle` | Apps | 应用管理 | アプリ管理 |
| `sourcesTabTitle` | Sources | 应用来源 | アプリの検索場所 |
| `settingsWindowTitle` | Settings | 设置 | 設定 |
| `viewMenuTitle` | View | 视图 | 表示 |
| `toggleLauncherTitle` | Show/Hide Launcher | 显示/隐藏启动器 | ランチャーを表示／非表示 |
| `settingsButtonAccessibility` | Settings | 设置 | 設定 |

Main requested the exact settings window values. The current project menu/button
source supplied the other Chinese baselines. English Apps/Sources are deliberately
concise for the existing 500-point settings window; actual fit is unverified.
Existing shared search, quit and language keys remain in `LocalizedTextKey`.

## Exact consumer vocabulary

All 63 cases in `Workflow/results/LANGUAGE_SETTINGS_KEY_REQUESTS.md` are included
in publication order. Chinese messages retain the exact published baseline.
English and Japanese were independently authored. The request fingerprint used
for this handoff is SHA-256 `0208f1bb63d52a2a46eaf291828b9ce47eeaf5879de78cbc59686f463abe88cc`.

### AppearanceSettingsView — 21 cases

- `appearanceShowLabels`
- `appearanceBlurAccessibility`
- `appearanceIconAccessibility`
- `appearanceFontAccessibility`
- `appearanceApply`
- `appearanceRestoreDefaults`
- `appearanceBlurCaption`
- `appearanceHelp`
- `appearanceIconCaption`
- `appearanceFontCaption`
- `appearanceLoadFuture`
- `appearanceLoadCorrupt`
- `appearanceInvalidDraft`
- `appearanceUnavailable`
- `appearanceSaveFuture`
- `appearanceInvalidPreferences`
- `appearanceSaveFailed`
- `appearanceDraftDefaults`
- `appearanceApplied`
- `appearanceQueued`
- `appearancePresentationUnavailable`

### AppManagementSettingsView — 16 cases

- `managementHideSelected`
- `managementSaveAlias`
- `managementClearAlias`
- `managementRestoreAll`
- `managementAppAccessibility`
- `managementAliasPlaceholder`
- `managementAliasAccessibility`
- `managementHelp`
- `managementSelectApp`
- `managementHiddenSuffix`
- `managementLoadFuture`
- `managementLoadCorrupt`
- `managementSaved`
- `managementInvalidAlias`
- `managementSaveFuture`
- `managementSaveFailed`

### AppSourcesSettingsView — 26 cases

- `sourcesAutomatic`
- `sourcesAdd`
- `sourcesRemove`
- `sourcesApply`
- `sourcesRefresh`
- `sourcesRootAccessibility`
- `sourcesFixedCaption`
- `sourcesExtraCaption`
- `sourcesHelp`
- `sourcesLoadFuture`
- `sourcesLoadCorrupt`
- `sourcesWatchActive`
- `sourcesWatchDisabled`
- `sourcesWatchUnavailable`
- `sourcesWatchDegraded`
- `sourcesSelectRoot`
- `sourcesRemovedDraft`
- `sourcesPanelPrompt`
- `sourcesAddedDraft`
- `sourcesAlreadyCovered`
- `sourcesRejected`
- `sourcesSaved`
- `sourcesSaveFuture`
- `sourcesInvalidRoot`
- `sourcesSaveFailed`
- `sourcesSuperseded`

`managementHiddenSuffix` contains its separator: English ` (hidden)`,
Chinese `（已隐藏）`, Japanese `（非表示）`. Append it to a verbatim app/alias
title. Neither user text nor app names are interpreted as formatting templates.

## Resource, formatting and fallback contract

The actual en/zh-Hans/ja `Localizable.strings` tables supply all new values.
`ResourceKey.all`, key naming and placeholder signatures include both APIs;
static settings values require zero tokens and count templates require exactly
one `{count}` named integer token. Strict validation checks raw tables before
fallback, including missing/extra keys, invalid values and incorrect signatures.
Diagnostic metadata continues to omit unknown resource keys, contents and paths.

Both APIs use the existing immutable validated selected/English snapshots.
The provider is consumed at construction and not retained. Formatting uses
validated named integer segments and deterministic Int conversion, with percent
signs kept literal. Rendering performs no resource IO, OS locale negotiation,
AppKit work or async operations. Build snapshots and relabel consumers outside
frame callbacks; this worker added no frame or consumer integration.

`hiddenReferenceCount` returns the complete sentence, including references to
apps not currently installed. English selects one only for count 1; zero,
negative values and all other counts select other. Chinese/Japanese select the
invariant other form, and their shipped one/other resources are identical.
English fallback independently selects English grammar, even for a
Chinese/Japanese selected language. Count values are not clamped; Int.min and
Int.max are preserved. Chinese baseline: `{count} 个隐藏引用（含暂未安装的应用）`.

Fallback order is valid selected entry, valid actual English entry, exhaustive
key-specific built-in safe English. No raw key or unvalidated format is returned.
The existing case-normalized `.app` locator and lowercased packaged language
directory lookup are unchanged. Missing/invalid app bundles never evaluate or
consult the SwiftPM development accessor.

## Authored verification, execution limits and remaining gates

Added `SettingsLocalizedStringsTests.swift` with 13 tests covering actual selected
resources, 63 exact Chinese consumer baselines, top-tab/Main translations,
suffix spacing and verbatim Unicode/format-like app titles, selected-language
count grammar and integer bounds, per-key English fallback, strict missing/static
token rejection, invalid-value safety, exact count signatures, fallback plural
grammar, invariant resource selection, absent/invalid resources and literal escapes.

Updated the existing explicit golden required-key list intentionally to 97 keys,
including a collision check, exact three-table coverage and two count signatures.
Extended existing immutable-provider instrumentation to exercise every new key
and count, and packaged-bundle tests to exercise the complete settings vocabulary.
Existing resolution tests, test helpers and original API assertions were retained.

Only source inspection, fingerprint collection and path-bounded
`rtk proxy git diff --check` were performed. The diff check returned exit 0;
it is a whitespace check of tracked changes, not compilation or test evidence.
The initial bootstrap read of RTK.md used unprefixed cat; subsequent shell calls
were prefixed with rtk. No Swift, build, XCTest, GUI, app launch, process control,
commit or installation was run. No reference app, evidence or asset content was read.

Main still must run nonzero localization XCTest, compilation, strict actual
resource validation, exact packaged-bundle probe with development fallback
unavailable, and consumer/size/preservation/frame gates. Any packaging probe
expectation fixed at 24 keys must be expanded by its owner to the new 97-key
contract. This worker does not own that probe or the group consumer registry.
This wave does not claim complete shipping UI coverage or 207-site coverage.

## Changed files and frozen fingerprints

The ten source/resource/test files below plus this report comprise all changes
made by this worker. These SHA-256 fingerprints identify the handoff, not a
candidate app or a runtime verification result. Source/resources/tests are frozen
after this publication; new requests require an explicit follow-up revision.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Sources/LauncherLocalization/SettingsTextKey.swift` | 2315 | `b0c68395c0bca8fdae284a9a66442b444c39842a6ce5a57a243ff1c0867ad1fe` |
| `Sources/LauncherLocalization/LocalizedStrings.swift` | 13072 | `de5d3e3de351553f9ab90756685182ca3198445397cd4e64de330a519c334549` |
| `Sources/LauncherLocalization/LocalizationResources.swift` | 9248 | `1706a6ede537406297acf74e39b807bfa03a351f79ebad840cf078604f5ccdc3` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | 7079 | `f455af735a7efbb83542eccfa8d9cb504cc41424878a11fa48c96444b371f701` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | 6550 | `aaedafedbdf00a09570b473cdbb332bd190a4d715ba5e14891e34673fea44f49` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | 9211 | `85d7eaa58d8ba1e3f13920f6eded93d8049e8bc13235b86fb4a4321a5b9f2398` |
| `Tests/LauncherLocalizationTests/SettingsLocalizedStringsTests.swift` | 17110 | `cd705691d005e6086ddfaf3470f7241293dfdeae77d682f7958bc2104e45307d` |
| `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift` | 9186 | `9d59e12a84c29ef4bf2443ff5e46a200037370ea833771ed118258d0c582afae` |
| `Tests/LauncherLocalizationTests/LocalizedStringsTests.swift` | 11203 | `ecf3751ff9dd7a9db2dff49044e45b431385d10054456f38754f111da11a8bc0` |
| `Tests/LauncherLocalizationTests/LocalizationResourceBundleTests.swift` | 8184 | `f06f59060073971a1079311936f375173f95368e14ab628f882835818fac0d87` |
