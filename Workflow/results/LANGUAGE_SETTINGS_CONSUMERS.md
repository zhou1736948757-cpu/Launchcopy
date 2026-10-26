# Settings consumer localization handoff

Status: SOURCE_READY_PENDING_MAIN_FREEZE_AND_VERIFICATION, 2026-10-14.
This is a bounded consumer implementation handoff, not a runtime acceptance verdict.

## Authorized scope and changed files

Read `AGENTS.md`, `/Users/mac/.codex/RTK.md` and the approved
`Docs/INTERFACE_LANGUAGE_SPEC.md`. The explicit worker packet waived Chief/chef
workflow and assigned disjoint ownership. Only the following six files were written:

- `Sources/PagingPrototypeApp/AppearanceSettingsView.swift`
- `Sources/PagingPrototypeApp/AppManagementSettingsView.swift`
- `Sources/PagingPrototypeApp/AppSourcesSettingsView.swift`
- New `Tests/PagingUITests/LanguageSettingsConsumersTests.swift`
- New `Workflow/results/LANGUAGE_SETTINGS_KEY_REQUESTS.md`
- New `Workflow/results/LANGUAGE_SETTINGS_CONSUMERS.md` (this report)

The three consumer source files already existed as untracked project files at
entry; they were edited in place, not replaced from Git. Existing tests, unrelated
work and reference application code/assets were not modified. No Activation window,
controller, language owner, resource module, package, process or workflow state was
changed. No commit, install, Swift invocation, build, XCTest, GUI interaction or
app launch was performed. Shell entry commands used RTK. Static API inspection
read the installed AppKit declaration confirming NSMenuItem accessibility support;
it did not inspect a reference application's implementation.

## Public consumer API

All three real views now expose:

```swift
public private(set) var strings = LocalizedStrings(language: .simplifiedChinese)
public func relabel(strings: LocalizedStrings)
public init(frame frameRect: NSRect, strings: LocalizedStrings)
public override convenience init(frame frameRect: NSRect)
```

The existing `init(frame:)` call sites retain the Simplified Chinese default.
The injected initializer configures native text using the supplied displayed
snapshot during initialization, before the view is presented. Main can also call
`relabel(strings:)` on retained or lazily built views before presentation.
All original reload/action/callback signatures and stable identifiers remain.

Sources additionally exposes:

```swift
public var onPresentationOwnershipChange: (() -> Void)?
public var hasPresentationOwnership: Bool { openPanel != nil || busy }
```

Main should observe this optional notification and recheck the computed property
alongside its other owners, including actual window field-editor marked text and
native menu tracking. There is no editable field in Sources; native picker filename
composition is covered by the actual open panel's lifetime. The property does not
simulate readiness or inspect unrelated controls. No existing callback is replaced.
Acquisition notifications follow registering the task or beginning the real sheet;
release follows finishing status/control updates. Cancellation through the existing
explicit cancellation method also releases once. Picker-to-admission handoff retains
aggregate ownership continuously. Language relabeling emits no ownership notification
and never cancels a task, dismisses a panel or advances operationGeneration.

## Resource contract and text coverage

Published the exact 63 ASCII camelCase cases in
`Workflow/results/LANGUAGE_SETTINGS_KEY_REQUESTS.md` before the deeper consumer
implementation: 21 Appearance, 16 Management, 26 Sources. This consumer depends on
exactly these resource-worker APIs:

```swift
strings.settingsText(_ key: SettingsTextKey) -> String
strings.hiddenReferenceCount(_ count: Int) -> String
```

The resource worker's delivered SettingsTextKey contains all 63 cases. Static
inspection found that all 63 are used by these consumers, and all published
Chinese values match the delivered zh-Hans table exactly. The published request fingerprint matched the resource worker's catalog handoff.
The final whitespace check removed one extra blank line at EOF from that request
report; all cases and values are unchanged. The table below records the normalized
request fingerprint; the resource worker's recorded pre-normalization fingerprint
remains `0208f1bb63d52a2a46eaf291828b9ce47eeaf5879de78cbc59686f463abe88cc`. English/Japanese were authored by
that worker; this worker did not edit or duplicate translations.

Appearance covers checkbox, captions, slider AX, help, actions, corrupt/future loads,
invalid controls, unavailable callback, all save outcomes, restored-default draft,
applied, saved/queued and saved/presentation-unavailable feedback. Original Chinese
visible messages, numeric values, queued secondary color and error/success colors
are retained. Feedback stores a typed SettingsTextKey and color. Relabel renders
that same meaning without querying presentationStateProvider; only the existing
explicit refreshPresentationStatus operation advances accepted presentation status.

Management covers picker placeholder/AX, actions, alias placeholder/AX, help,
hidden suffix, complete hidden-reference counts, corrupt/future loads and every
save outcome. Existing items are relabeled in place; represented AppRecords,
selection, records, preferences, checkbox, unsaved alias, field-editor content,
selection and composition are not rewritten. Alias and original-name text remain
verbatim, including their original separator. The hidden suffix includes its
language-specific spacing/punctuation. Canonical selected records retain original
names, identifiers, paths and original-name/alias search behavior.

Sources covers fixed/extra captions, picker placeholder/AX, all actions, help,
automatic-refresh AX, native panel prompt, all four retained watch states,
corrupt/future loads, removed/added draft feedback, admission outcomes and all
five apply outcomes. Fixed/user root strings are not translated. The internal
makeOpenPanel constructor is used by the actual add action and enables checking
its prompt/configuration without presenting native UI. Delayed callbacks retain
operation semantics and render their typed results against self.strings when they
complete, rather than capturing a translated sentence or an old snapshot.

Each relabel changes only text, accessibility or retained status rendering. It
performs no reload, menu reconstruction, selection change, draft mutation, enabled
state refresh, persistence, root admission, catalog/watcher refresh, icon request,
layout/constraint operation or generation change. Status dismissal clears typed
feedback so changing language cannot resurrect a hidden old message. Existing
explicit reload/action paths keep their original control/data responsibilities.

## Authored native verification (not executed)

Added 17 XCTest methods using the real three views. Most mount them in an unshown
500 by 560 NSWindow; no ordering front, app activation or sheet display is requested.
The panel test constructs the actual NSOpenPanel through the production add-action
constructor without presenting it. Tests cover:

- Injected initial snapshots and three-language real text/AX; independent Chinese
  baseline assertions and distinct real button titles across all three languages.
- Appearance drafts, native slider/value state, callbacks and provider read counts;
  queued state retained until explicit refresh; unavailable/default/invalid feedback;
  load protection, all save failures and no persistence from relabel.
- Management menu/control/constraint identities, canonical selected records,
  original/alias search, hidden-reference counts including absent apps, unsaved alias,
  actual window field-editor first responder, selected range and marked text;
  read-only/corrupt and all save outcomes.
- Sources popup/root identities, fixed paths, selected root, automatic-refresh draft,
  all watch states, dismissed and removed-draft feedback, load protection,
  real panel prompt/configuration and stable mutation/refresh callbacks.
- Held admission and every held apply outcome across language changes, exact
  acquisition/release notifications, unchanged busy/draft/selection and zero extra
  admission/save/refresh calls; completion uses the current displayed snapshot.
- Existing explicit cancellation still drops a late callback and releases once;
  no language-driven cancellation or operation-generation reset is introduced.

No existing test expectation was weakened or rewritten. These tests have not been
compiled or run; Main must first freeze the integrated sources and then execute
nonzero focused native/localization tests and the required broader gates.

## Static evidence and limits

RTK-wrapped source inspection established the following bounded findings:

- 63 requested cases, 63 used consumer cases, no missing resource enum cases.
- All 63 requested Chinese values equal the delivered zh-Hans resource values.
- No remaining CJK string literals in the three owned view sources. Remaining
  literals are neutral empty/numeric/data separators, stable identifiers and the
  existing developer-only unavailable-coder fatal message.
- Relabel paths contain no reload, syncControls, selectionChanged,
  cancelPendingOperations, external action callback, updateEnabled or generation
  increment. Feedback/watch helpers read only retained state and immutable strings.
- Direct file inspection found no trailing whitespace. Final per-file no-index
  whitespace checks covered the untracked full files; no diagnostics remained
  after normalizing the key request report EOF (exit 1 indicates each new-file
  difference against /dev/null). The bounded tracked Git diff check
  returned exit 0, but these files are untracked: that tracked-diff result is not
  compilation, runtime evidence or a meaningful review of their full contents.

These checks are static source observations, not native test execution or performance
measurement. No runtime claim is made for IME, panel release, resource availability,
window expansion or accessibility.

## Actual remaining text gaps and integration gates

No untranslated app-owned message from the three owned view inventories remains
at the source level; their text is routed through the delivered typed APIs. This
does not certify the complete shipping application or the broader interface ledger.
Main owns Activation/controller/owner integration and all other app-owned surfaces;
this worker did not assess or implement their remaining strings.

Native OS-owned file panel controls remain in the OS language by the approved
contract; its app-owned prompt uses the displayed snapshot. Real picker display,
continuous picker-to-admission ownership, release/retry through Main's final-owner
logic and native menu tracking remain runtime gates. The real field-editor tests
are authored but unexecuted; actual IME and VoiceOver still require validation.
Long English/Japanese label reachability in the fixed window, layouts under wrapping,
strict packaged resource validation with development fallback unavailable, and
catalog/icon/layout/frame no-work budgets remain Main's integrated verification
responsibilities. Resource fallback may deliberately use safe English when tables
are unavailable; shipping packaging must be verified before default-Chinese runtime
parity is accepted. Existing performance limitations are unchanged.

## Frozen handoff fingerprints

Fingerprints identify these source artifacts, not a built app or test result.
This report is excluded from its own hash list. Any later source edit requires
Main to refresh the relevant fingerprint and review evidence.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Sources/PagingPrototypeApp/AppearanceSettingsView.swift` | 12429 | `1195ebbf3e0ecd35ab0fe217ca120194281ee2ed3ffb3cd16e82cce9916585ba` |
| `Sources/PagingPrototypeApp/AppManagementSettingsView.swift` | 9925 | `0c180545703b67fcd55c492dddd3dbebf786de0c45704fa1bab4cd2422b5586b` |
| `Sources/PagingPrototypeApp/AppSourcesSettingsView.swift` | 14672 | `04423b6601a5a372b755cc927f8bd873ddba993c589e54dbd0669645bc1d3070` |
| `Tests/PagingUITests/LanguageSettingsConsumersTests.swift` | 39868 | `7f9c9aac4b3c5d82b2a5e4935977d2185bb95636eaae99ff96da24cffbdc599c` |
| `Workflow/results/LANGUAGE_SETTINGS_KEY_REQUESTS.md` | 5793 | `d27f7acf79e5c2894d428428b2578e0a17e260cb21801e1099c6216887b7aa8a` |
