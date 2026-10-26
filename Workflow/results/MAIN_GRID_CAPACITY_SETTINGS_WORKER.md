# Main Grid Capacity Settings and Localization Worker

Date: 2026-10-17
Status: IMPLEMENTED_SOURCE_ONLY — ready for Main integration and serialized verification; no feature PASS.

## Authority and boundaries

Read `/Users/mac/.codex/RTK.md`, repository `AGENTS.md`, the current `Docs/MAIN_GRID_CAPACITY_SPEC.md` including its dated human approvals, and `Workflow/stage-summaries/2026-10-17-main-grid-capacity.md`. The dated approval authorizes main-grid-only 3…8 dimensions, default 5×7, scoped Apply/Defaults, safe deferral, independent folders, and small-window protection. Chief was explicitly waived. Main owns integration and all executions; no agents were dispatched.

All shell commands used the `rtk` prefix. No test execution, Swift compilation/build, packaging, app launch, UI operation, process inspection/control, external/reference code access, commit, reset, clean, or revert was performed. Broad existing dirty state was preserved. The only verification executed here was an owned-path `git diff --check` whitespace check, which returned exit 0; this is not compilation or test evidence.

## Stable integration API

```swift
@MainActor
final class MainGridCapacitySettingsView: NSView {
    init(frame: NSRect, strings: LocalizedStrings)
    let columnsPopup: NSPopUpButton
    let rowsPopup: NSPopUpButton
    let countLabel: NSTextField
    let applyButton: NSButton
    let defaultsButton: NSButton
    private(set) var draft: MainGridCapacity
    var onApply: ((MainGridCapacity) -> Bool)?
    var onDiscardDraft: (() -> Void)?
    func reload(capacity: MainGridCapacity, loadResult: MainGridCapacityLoadResult)
    func updateStatus(pendingCount: Int, saveResult: MainGridCapacitySaveResult?,
                      presentation: AppearancePresentationState)
    func relabel(strings: LocalizedStrings)
}
```

The controller exposes retained internal `let mainGridCapacityView: MainGridCapacitySettingsView`. The new tab identifier is `"grid"`; it is appended after Library, so all six previous tab indices and view identities are preserved. Controller construction/relabel/discard are wired. Both `hideSettings()` and `windowShouldClose(_:)` reach `mainGridCapacityView.onDiscardDraft` through the existing hide path.

Main installs guarded `onApply` and `onDiscardDraft` closures. Use `reload` only at open/discard, then supply current receipt/presentation through `updateStatus`; background receipt callbacks must not call `reload`. Main remains responsible for current owner identity, load readiness, Quit admission, coordinator submission, corrupt-recovery authorization, and truthful presentation state. The view does not manufacture generation/receipt ownership.

`onApply == true` means admission only and renders `.saving`. The view sets this before calling the closure so a synchronous real receipt cannot be overwritten afterward. Only an explicit `.saved` receipt with zero pending writes renders `.savedQueued`, `.applied`, or `.presentationUnavailable`. Nonzero pending writes always render `.saving`, even if another receipt is supplied. A nil receipt never becomes Saved/Applied. Rejected/missing callbacks display unavailable and retain the draft.

## Localization API and exact cases

```swift
public func mainGridCapacityText(_ key: MainGridCapacityTextKey) -> String
```

`public enum MainGridCapacityTextKey: String, CaseIterable, Sendable` uses the `mainGridCapacity.` resource namespace and these 19 cases:

- `title` — tab title; standardized to Main's requested API.
- `columns`, `rows`, `itemsPerPage`, `apply`, `restoreDefaults`, `help`.
- `loadCorrupt`, `loadProtected`, `unavailable`, `invalidDraft`, `draftDefaults`.
- `saving`, `savedQueued`, `applied`, `presentationUnavailable`, `saveFailed`, `recoveryRequired`.
- `insufficientSpace` — Main's small-window protective notice; standardized to Main's requested API.

No `tabTitle` or `smallWindowNotice` alias remains. Main should use `strings.mainGridCapacityText(.title)` and `strings.mainGridCapacityText(.insufficientSpace)`.

All cases have independently authored EN/zh-Hans/ja resources, English terminal fallback, `ResourceKey` registration, strict required-key/signature validation, and packaged-probe coverage. `itemsPerPage` is a static localized label combined with the validated integer using the existing deterministic integer convention. It introduces no new template or printf signature. Raw resource files remain below the established 64 KiB per-table bound (observed source byte counts: EN 21092, zh-Hans 19970, ja 26701).

## Draft and feedback behavior

- Initial unconfigured view is unavailable/read-only. Missing/loaded capacity enables editing. Protected/unavailable loads disable both popups and both write-related buttons, including direct action handlers.
- Corrupt load explains that explicit Apply replaces only damaged grid settings. Defaults, relabel, receipt refresh, and closing never perform recovery writes. A successful real receipt clears the corrupt-load warning.
- Defaults only replaces the draft with 5 columns/7 rows and prompts for Apply. It never invokes `onApply` or touches appearance/activation/source/Library settings.
- Both popups retain six original menu objects with tags 3…8. Validation rejects unexpected menu count/identity/tag/title, missing selection, invalid dimensions, stale draft/selection mismatch, and tampered count output. Invalid controls are not clamped and do not replace the last valid draft.
- Receipt/presentation updates do not mutate the draft, current selections, or derived count. Saving and error feedback remain separate from draft/defaults feedback and storage warnings.
- Language relabel changes text/AX only, retaining menus, selections, callbacks, view/constraint identities, draft, write availability, and typed feedback. No owner/provider callback is invoked by relabel.
- Save failure retains a retryable draft. A protected save receipt blocks further changes; recovery-required blocks until explicit reopen/reload establishes the recovery context.

## Exact changed files

New:

1. `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift`
2. `Sources/LauncherLocalization/MainGridCapacityTextKey.swift`
3. `Tests/PagingUITests/MainGridCapacitySettingsViewTests.swift`
4. `Tests/LauncherLocalizationTests/MainGridCapacityLocalizedStringsTests.swift`
5. `Workflow/results/MAIN_GRID_CAPACITY_SETTINGS_WORKER.md`

Existing files amended only for this worker's additions/contracts, preserving pre-existing content:

1. `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` — retained view initialization, appended tab, localized relabel, discard callback.
2. `Sources/LauncherLocalization/LocalizedStrings.swift` — typed rendering entry point.
3. `Sources/LauncherLocalization/LocalizationResources.swift` — required-key registration and static signature.
4. `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` — 19 resources appended.
5. `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` — 19 resources appended.
6. `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` — 19 resources appended.
7. `Sources/LocalizationResourceProbe/main.swift` — typed capacity-key usability loop.
8. `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift` — preserve exact coverage/count/schema contract with the additional key family.
9. `Tests/PagingUITests/AppearancePreferencesTests.swift` — exact tab count becomes 7; add new retained-view identity assertion and retain all prior index/identity assertions.
10. `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` — append `"grid"` to the exact existing tab-identifier contract.

The last two changes are the explicitly authorized old-tab-count/contract adjustments, not broader test changes. No edits to AppDelegate, keyboard/search integration, coordinator/domain/store, geometry/renderer/readability, Package.swift, or shared workflow state/plan.

## Authored coverage and remaining gates

Fourteen new AppKit unit methods cover default/all 36 bounded pairs/counts, initial readiness, admission versus receipts, synchronous receipt reentrancy, missing/rejected owner, late receipts/new dirty drafts/retry, protected/unavailable/corrupt loads, scoped defaults, tampered menus/tags/titles/counts, typed errors/protection, relabel retention and controller hide/window-close discard. Five localization methods cover exact 19-key contract, actual translations, missing-resource English fallback, strict unexpected-placeholder rejection, and snapshot-only rendering with no extra resource reads.

These methods are authored but UNEXECUTED. Main must compile, run focused/full tests, run packaged resource validation, independently review the final integration, and verify the real native settings/readability/receipt/Quit/restart flow. This worker has no native, rendering, performance, physical-input, VoiceOver, or feature-acceptance evidence. The separate long-language tab bar and new settings layout still require Main's native visual check at the existing settings-window size.
