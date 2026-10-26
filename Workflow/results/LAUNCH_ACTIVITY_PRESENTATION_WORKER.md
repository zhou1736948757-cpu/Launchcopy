# Launch Activity Presentation Worker

Date: 2026-10-18
Status: IMPLEMENTED_FOR_MAIN_INTEGRATION — not built, tested, launched or independently reviewed.

## Authority and scope

Read `AGENTS.md`, the approval and implementation clarification in `Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md`, and `Workflow/stage-summaries/2026-10-18-library-launch-activity.md`. Implemented only the assigned presentation/localization slice. The approved proposal remains the contract. Existing dirty work was preserved; no changes were made to composition, projection, Library view/owner, coordinator, launch pipeline, domain/store, package configuration or existing tests outside the allowlist.

## Changed paths

All paths below are relative to the PagingPrototype repository root.

1. `Sources/LauncherLocalization/LaunchActivityTextKey.swift` — new public static key family and English fallbacks.
2. `Sources/LauncherLocalization/LocalizationResources.swift` — register activity keys in the enum, ordered required-key list, raw names and empty placeholder signatures.
3. `Sources/LauncherLocalization/LocalizedStrings.swift` — add `launchActivityText(_:)` using the existing validated snapshot/English/fallback chain.
4. `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` — add 24 English entries.
5. `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` — add 24 Simplified Chinese entries.
6. `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` — add 24 Japanese entries.
7. `Sources/LocalizationResourceProbe/main.swift` — iterate every activity key for nonempty, non-key text after the existing key-family loops.
8. `Sources/PagingPrototypeApp/LaunchActivitySettingsView.swift` — new standalone AppKit child view.
9. `Tests/LauncherLocalizationTests/LaunchActivityLocalizedStringsTests.swift` — new localization contract tests.
10. `Tests/PagingUITests/LaunchActivitySettingsViewTests.swift` — new presentation/state/callback/layout tests.
11. `Workflow/results/LAUNCH_ACTIVITY_PRESENTATION_WORKER.md` — this handoff.

## Public localization interface

`public enum LaunchActivityTextKey: String, CaseIterable, Sendable` has exactly these ordered cases, with raw values `launchActivity.<case>`:

`title`, `enabled`, `privacyHelp`, `recent`, `frequent`, `emptyRecent`, `emptyFrequent`, `off`, `saving`, `saved`, `saveFailed`, `unavailable`, `protected`, `recoveryRequired`, `recover`, `clear`, `clearTitle`, `clearMessage`, `clearConfirm`, `cancel`, `cleared`, `retry`, `waiting`, `libraryDisabled`.

`englishFallback: String` is public. `LocalizedStrings.launchActivityText(_ key: LaunchActivityTextKey) -> String` reads its immutable snapshot; it adds no resource access while rendering and accepts no dynamic formatting arguments. Required-key registration appends this family after `LiveAppearanceTextKey`.

The three languages explain default OFF, only Launchcopy-originated requests accepted by the launch executor, application identities and request times/counts, local rolling 30-day UTC retention, no monitoring or upload, and acceptance not establishing actual opening/use. Disabling recording or Library stops recording and hides both sections without erasing retained data. The separate clear-confirmation text explicitly describes irreversible removal of this feature's records, preserves categories/aliases/hidden apps/arrangement/other settings, and does not enable recording. Save failure copy separates history persistence from app launch outcome. Japanese Recent is `最近の起動` so all three translations are distinct for every key.

## Main-facing presentation interface

`@MainActor final class LaunchActivitySettingsView: NSView` is internal to the app module and exposes:

```swift
init(frame: NSRect, strings: LocalizedStrings)
func relabel(strings: LocalizedStrings)
func applyState(_ state: State)

struct State: Equatable {
    var enabled: Bool
    var canEnable: Bool
    var isBusy: Bool
    var canClear: Bool
    var status: LaunchActivityTextKey
    var canRetry: Bool
    var canRecover: Bool
}

var onSetEnabled: ((Bool) -> Void)?
var onClear: (() -> Void)?
var onRetry: (() -> Void)?
var onRecover: (() -> Void)?
```

`State` retains its synthesized memberwise initializer with the exact field order above. The `enabledCheckbox`, `clearButton`, `retryButton`, `recoverButton`, `statusLabel` and `helpLabel` are internal test seams. `strings` is readable with a private setter.

- Initial presentation is unchecked, noninteractive and `.waiting`; retry/recovery are hidden.
- Main supplies the current admitted/committed checkbox value and status. The view neither invents pending/success/error states nor interprets storage or Library domain state.
- `canEnable` is the owner's permission to change the checkbox. It is deliberately **not** additionally gated by `isBusy`, so Main can allow an immediate privacy disable while a previous write remains pending. Main should restrict enabling while busy if its admission policy requires that.
- Checkbox actions capture the immediate Bool, reconcile to the last supplied baseline, then invoke the closure once synchronously. A synchronous `applyState` from Main remains authoritative because no rendering occurs after callback return. A mixed or disallowed direct action restores the owner baseline without invoking the closure.
- Clear/retry/recover require their supplied permission and `!isBusy`; guards apply to direct target invocations as well as button clicks. Callback delivery alone never changes enablement, status or data. Missing callbacks are no-ops.
- Retry/recover are hidden when their respective flags are false. The vertical stack detaches hidden views. Main may keep either action visible but disabled during busy work by retaining its flag.
- `onClear` and `onRecover` request Main's flow only. Main owns the actual `NSAlert`, cancellation, destructive acceptance and actual receipts. Main can use `.clearTitle`, `.clearMessage`, `.clearConfirm` and `.cancel` for clear confirmation.
- All labels and accessibility names use typed localization. Identifiers use `launchActivity.settings.` with suffixes `section`, `title`, `enabled`, `help`, `status`, `clear`, `retry`, `recover`.
- Native vertical stack, 24-point horizontal/16-point vertical insets, 12-point spacing, wrapping heading/help/status, native checkbox and rounded buttons. No fixed control heights or view height; edge constraints expose content fitting height to Main's composition. Main should allow that fitting height when embedding the child. Relabeling preserves controls, targets, callbacks, owner state and constraints.

## Authored verification coverage

`LaunchActivityLocalizedStringsTests` contains eight test methods for exact exhaustive key order and resource coverage, nonempty/distinct shipped translations, fallback equality, privacy/retention/disable wording, irreversible feature-only clear scope, distinct state/action messages, missing resources/keys, rejection of dynamic placeholders, and immutable resource snapshots.

`LaunchActivitySettingsViewTests` contains eleven test methods for default safety, presentation-only apply/relabel, exact Bool delivery, owner reconciliation, synchronous callback snapshots, busy privacy-disable behavior, guarded direct actions, missing callbacks/mixed state, clear cancellation semantics, retry/recovery transitions, localized accessibility/control identity and vertical wrapping/resizing/hidden-action behavior.

These are authored expectations, not execution evidence. No build, test command, custom test script, UI launch or native interaction was run. Source inspection is the only review performed by this worker. Main remains the sole runner and must obtain compilation, nonzero XCTest, packaged-resource and native UI evidence. No worker PASS is claimed.

## Required Main integration follow-up

The pre-existing `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift`, method `testRequiredKeyContractAndEveryShippedTableHaveExactCoverage`, constructs `allKeys` ending with `LiveAppearanceTextKey.allCases.map(\.rawValue)` and has a matching explicit count expression. Main must append `LaunchActivityTextKey.allCases.map(\.rawValue)` and add `LaunchActivityTextKey.allCases.count` in that count expression. Otherwise its exact required-key/table assertions omit this new family. This is source-observed, not an executed failure. That file is outside this worker's allowlist and was not edited.

Main also owns all `AppLibrarySettingsView` composition, callbacks/state mapping, actual confirmation, projection/view/owner/coordinator integration, validated launch attribution, and all runtime/performance acceptance. In particular, Main must provide `canEnable` according to admission availability, rather than deriving it solely from pending disk work, so disabling can stop admission immediately.

## Main composition follow-up — 2026-10-18

Read Main's current `AppLibrarySettingsView` composition without modifying it. Its 500-point pane applies 24-point horizontal insets, giving the activity child 452 points. The child's own 24-point insets leave 404 points for wrapping text. Its top and bottom are both constrained to its content stack (16-point insets), while heading/help/status have required vertical compression resistance. The stack now explicitly prefers its natural vertical height with `setHuggingPriority(.defaultHigh, for: .vertical)`. No intrinsic-height override, fixed child height, line cap, layout-time resource read, text truncation or font shrink was added; nested content constraints determine fitting height without an intrinsic-size/layout recursion.

**Bounded-height risk:** with approximately 140 points of original Library content in a 500-point viewport, only about 360 points remain. Long Japanese help plus a wrapping recovery/failure status and a visible recovery/retry button may exceed that allowance at the effective 404-point text width. The contract also permits both action flags to be visible, increasing the required height further. Treat the 500-point total as potentially over budget and use a scrolling composition in Main when content exceeds the viewport. Do not clip the privacy text or hide the status/actions to force the height. This is a conservative source-based estimate, not a measured AppKit fitting height; no execution was performed, so no exact fit/overflow is claimed.

The authored layout test includes 340-, 452- and 500-point child widths and asserts a positive content fitting height. All captions, statuses and accessibility expectations in the presentation tests are retrieved by typed keys; there are no fixed English caption expectations. The intentional language-specific assertions in the localization test verify the approved privacy and clear scope semantics.

## Evidence boundaries and remaining gates

No reference source/assets, formal data, OS preferences, installation, signing, commits, process termination, preference writes or launch activity data were accessed or changed. Shell invocations used the required `rtk` prefix. No additional workers or reviewers were dispatched. Independent source review and all runtime gates remain with Main.
