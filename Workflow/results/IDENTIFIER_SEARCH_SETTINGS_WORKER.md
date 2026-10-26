# Identifier search settings worker

Date: 2026-10-15.
Status: Implementation and test source ready for Main integration/review; NO_EXECUTION. No worker PASS verdict.

## Authority and baseline

Read the project AGENTS.md, approved Docs/BUNDLE_IDENTIFIER_SEARCH_SPEC.md, and Workflow/stage-summaries/2026-10-15-identifier-search-implementation.md. Chief was human-waived. Applied Main's additional requirement that corrupt metadata disables the new toggle without changing legacy explicit alias/hide repair behavior.

The shared checkout already contains extensive unrelated modified/untracked work. Only the eight paths listed below were written by this worker. Store, coordinator, AppDelegate, domain matching, existing tests, stage/plan/state, references, assets and memory were not edited. Other workers' changes were preserved. No staging or commit was performed.

## Exact changed paths

1. `Sources/PagingPrototypeApp/AppManagementSettingsView.swift`
2. `Sources/LauncherLocalization/SettingsTextKey.swift`
3. `Sources/LauncherLocalization/LocalizedStrings.swift`
4. `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings`
5. `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings`
6. `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings`
7. `Tests/PagingUITests/IdentifierSearchSettingsTests.swift` — new; existing AppManagementSettingsTests.swift untouched.
8. `Workflow/results/IDENTIFIER_SEARCH_SETTINGS_WORKER.md` — this report.

## Interface and integration contract

AppManagementSettingsView exposes the agreed MainActor interface:

```swift
public var onSetSearchByBundleIdentifier: ((Bool) -> AppManagementSaveResult)?
public var identifierSearchPendingProvider: (() -> Bool)?
public func refreshIdentifierSearchState(storedEnabled: Bool, isPending: Bool)
```

- Uses the domain worker's `AppManagementPreferences.searchByBundleIdentifier: Bool`; initial state is the default false value. Reload binds the supplied committed flag. No selected app is required.
- Main should assign the save callback to its specialized `applySearchByBundleIdentifier` route, supply the actual pending provider, and provide the actual load result on initial/reload. This worker does not wire the owner.
- `.saved` accepts the requested stored value only. The provider is sampled **after** the callback to distinguish queued versus applied presentation. Missing provider conservatively displays queued after save; missing callback is failure. Initial/reload without a provider shows no presentation receipt rather than guessing applied.
- Policy refresh updates only the boolean in the local preferences snapshot, checkbox state and separate policy feedback. It never calls reload/relabel/selectionChanged, reconstructs a menu, touches an alias draft/editor, invokes persistence, or clears legacy feedback. Main must supply latest committed storage and pending state as agreed.
- A `.corrupt` or `.futureVersion` load disables and guards the new checkbox. Policy refresh alone cannot remove that protection; a valid explicit reload can. A callback discovering future storage rolls back and disables this toggle. Failed/invalid saves roll back and display the separate failure message. Existing legacy control repair/read-only semantics are unchanged.
- Relabel renders existing typed policy feedback, preserving checkbox value/enabled state and queued/error state without consulting persistence or the pending provider. Menu and editor identities remain intact.

Native control identifiers:

- Checkbox: `management.search-identifiers`
- Example help: `management.search-identifiers.help`
- Policy feedback: `management.search-identifiers.status`

The existing `statusLabel` remains the alias/hide/restore feedback channel. The new policy section uses its own feedback label, compact native helper/status fonts and 6-point internal spacing. The containing stack spacing is reduced from 16 to 12 points to accommodate the section within the existing tab. Actual localized fitting remains a native verification gate.

## Localization and privacy

Seven typed settings keys were added with matching en/zh-Hans/ja resources and safe English fallbacks:

- `managementSearchIdentifiers`
- `managementIdentifierSearchHelp`
- `managementIdentifierSearchApplied`
- `managementIdentifierSearchQueued`
- `managementIdentifierSearchFailed`
- `managementIdentifierSearchFuture`
- `managementIdentifierSearchCorrupt`

The existing ResourceKey registry derives settings schema entries from `SettingsTextKey.allCases`, including their empty placeholder signature. Therefore adding typed cases extends the strict required schema without modifying LocalizationResources.swift or introducing a duplicate registry. Only the independently invented `com.example.app` example appears in help. No real identifiers, raw queries, logs, telemetry or new persistence were introduced.

## Test source delivered, not executed

Eleven XCTest methods in the new IdentifierSearchSettingsTests.swift specify:

1. Default off, empty selection, mounted identifiers and stored-flag reload without saving.
2. Real mounted checkbox actions in both directions without an app selection, with applied receipt.
3. Pending provider sampled after save, pending reload, then explicit applied refresh without another save.
4. Saved callback without provider does not claim applied.
5. Failed/invalid saves roll back both directions, preserve error during three-language relabel, and allow retry.
6. Missing save callback reports failure and rolls back.
7. Corrupt/future disabled controls and direct target/action delivery guard, legacy repair state, protected refresh and valid-reload recovery.
8. Future storage discovered during callback rolls back and disables only the policy control.
9. Mounted checkbox action with synchronous owner receipt preserves alias draft, selected menu identity and separate legacy error.
10. Policy refresh and three-language relabel preserve actual field-editor identity, text/selection, menu identities, legacy error, and queued/applied policy state.
11. Required settings schema, strict resources and missing-resource safe English fallback for all new keys.

The tests mount real NSButton controls in real **unshown** NSWindow instances and deliver `performClick` actions; the disabled guard also delivers the configured target/action directly. They do not substitute a test-only control or relabel implementation. The resource assertions are test source only, not an executed resource validation result.

## Evidence and remaining gates

Source-only inspection confirmed the newly written call sites/resources and that the domain worker's named boolean is now present. No compiler/typecheck was run. No Swift command, test, build, native UI action, process control, agent dispatch, reference/asset access, global/project memory edit, or commit was performed. Main must freeze/integrate and execute the focused tests and existing management/localization regressions, strict packaged resources, full checks/builds, and independent review.

No native, layout, accessibility/VoiceOver, persistence/restart or physical performance PASS is claimed. In particular, exact multilingual layout with simultaneous legacy and policy feedback, field-editor behavior in the mounted tests, and real keyboard/VoiceOver behavior still need execution/acceptance by Main.

Command-policy deviation: the initial read of `/Users/mac/.codex/RTK.md` used direct `cat`; every subsequent repository shell invocation was prefixed with `rtk`. Source writes used the patch tool.
