# Interface Language — Approved Implementation Contract

Status: APPROVED_IMPLEMENTATION_CONTRACT, 2026-10-14. User explicitly selected
Follow System / Simplified Chinese / English / Japanese and safe live updates
with preserved drafts, search and arrangement. Language implementation is authorized;
Library and adjustable capacity are not authorized by this confirmation.

## Problem, users and outcome

Give launcher users a consistent, independently authored interface language in
settings, launcher chrome, menus, empty/error states and accessibility descriptions.
Preserve the current pager architecture and responsiveness. This is an interface
language setting, not a locale override for apps, the OS, catalog ordering, search
matching, keyboard layout or user content. Do not claim complete reference-language
parity: the exact reference language list is not established by this source survey.

## Confirmed user-facing contract

- Add a native Language settings tab with Follow System (default), Simplified
  Chinese, English and Japanese. Show language choices by endonym so a mistaken
  choice is reversible. All three supported languages are approved; any other
  reference languages remain explicitly pending, not silently removed from scope.
- Resolve Follow System from the ordered supported OS preferred languages at
  process startup, and on explicit Apply/reopen refresh. Match en variants to en,
  ja variants to ja, and explicit Simplified Chinese identifiers (zh-Hans,
  zh-CN, zh-SG) to zh-Hans. Bare zh uses the documented Simplified fallback.
  Unsupported explicit Chinese scripts, e.g. zh-Hant, are not advertised as
  translated; continue down the ordered language list, then use English fallback.
  Use parsed language/script/region identifiers, not unrestricted prefix matching.
  Region is not a reason to override an explicitly supplied script.
  Normalize case and underscore separators only for valid BCP-47-style language
  identifiers; reject empty/malformed/unrecognized scripts without guessing.
  The executable expected-results contract is:

  | Input tag/list | Expected supported resolution (three-language option) |
  | --- | --- |
  | en-US, en-GB | en |
  | ja, ja-JP | ja |
  | zh, zh-Hans, zh-CN, zh-SG | zh-Hans |
  | zh-TW, zh-HK, zh-MO, zh-Hant, zh-Hant-CN | unsupported: continue list |
  | zh-Hans-TW, ZH_hans_CN | zh-Hans: explicit Hans wins region |
  | zh-Latn, zh-US, unknown or malformed tag | unsupported: continue list |
  | [zh-Hant, ja, en] | ja |
  | [zh-TW, en] or [] | en |

  All three languages in the table are supported by the confirmed contract.
  Required resource and consumer tests cover en, zh-Hans and ja.
- The selected value is a draft until Apply; closing discards only unsaved draft.
  Restore Defaults selects Follow System in the draft, not an immediate reset.
  Applying a valid preference persists acceptance before changing presentation.
- Update app-owned interface text without restart when safely idle. During paging,
  held pointer/drag, folder transition/title editing, shortcut recording, IME
  composition, native menu tracking, source picker, alias sheet, or Quit dialog,
  keep the displayed language and show saved/queued. Apply the latest accepted
  choice once after all owners release, on a coalesced next-main-turn callback.
  Equal Follow System Apply can still require relabeling if the newly resolved
  effective language changed; selected-preference equality alone is not UI no-op.
  Never force-cancel an edit, close a dialog, or stop recording to translate faster.
- Language relabeling preserves every settings draft, selected tab/control, editor
  content/selection, page, focus identity, folder, query and current error state.
  Reopen refresh resolves only the accepted preference, not an unsaved language
  draft, and does not replace any in-progress draft. A failed Apply does not
  independently refresh Follow System or change displayed language; a later
  explicit reopen/valid Apply may request accepted-language resolution.
  Do not call existing reload(draft:) factories: they reset shortcut recording and
  may overwrite drafts. Failed save never changes accepted/displayed language.
- Native OS-provided panel/system menus may remain in the OS language; app-owned
  prompts/accessibility text use the displayed app language. Do not swizzle
  Foundation/AppKit or mutate AppleLanguages/global system preferences.
- Brand Launchcopy, app names, aliases, bundle IDs, URLs, user folder titles and
  user queries remain verbatim. Future new-folder default naming is a separate
  creation-time label; never translate existing persisted folder names.
- Pending notices and error reasons are rendered in the displayed language. Stable
  operation/error identifiers, not already-translated sentences, should cross
  asynchronous boundaries. Native error details may remain verbatim with a
  translated neutral explanation; do not log user data to explain localization.

## Scope, preservation and non-goals

Cover all app-owned shipping text: activation/login/shortcut readiness, Appearance,
Sources, Management and Language tabs, status/app menus, folder chrome, search
placeholder/no-results, page-dot accessibility, rename/alias/assignment sheets,
launch/Finder failures, accepted-write Quit protection, and resident/window notices.

Do not localize diagnostic CLI/profile/self-drive fixtures as product features.
Do not rename accessibility identifiers or stable preference/schema/operation IDs.
No catalog rescan/reordering, layout migration, name-visibility/size change, new
Library/capacity/gesture/deletion feature, translated reference resources, network,
telemetry expansion, or toolchain migration. Library strings are added with that
separately approved slice; no missing feature is certified from placeholder text.

## Architecture and resource decisions

Introduce a Foundation-only LauncherLocalization target with typed keys and an
immutable resolved language/string provider. AppGridUI, PagingUI and PagingPrototypeApp
consume it or injected neutral presentation strings; PagingCore, catalog identity
and icon pipelines remain independent of localization. Main owns Package.swift
and packaging integration. Do not introduce a second window or renderer.

Use independently authored .strings tables (and .stringsdict where counts need
language-specific plural forms), en/zh-Hans/ja .lproj resources. The SwiftPM
manifest declares English defaultLocalization and processes the target resources;
app development-region metadata is aligned deliberately with that fallback, not
used as a substitute for app-selected language. Typed
format APIs guard argument kind/count/order; dynamic app/path/name strings are
arguments, never format strings. Missing keys fall back deterministically to the
English table and a safe key-specific value, never raw keys or forced unwraps.
Use the selected language for plural/format interpretation, not accidentally the
OS language when a manual override is active. Test English one/other and invariant
Chinese/Japanese forms explicitly before choosing a resource-format adapter.
All shipped supported tables must have identical required-key coverage and valid
placeholder signatures before release. No new resource lookup, formatting, IO or relabeling occurs on advanceFrame or
its transitive Core state/committed-page callbacks. Existing PagingUI host/surface
accessibility formatting must be handled explicitly: retain the displayed-language
snapshot and coalesce updated accessibility text outside the frame stack at the
next main turn, with lifecycle/generation checks. Do not create all-page string
arrays on every frame. Test actual retained/reused hosts and surface values,
not just page-dot labels, and count transitive lookup/format invocations.

Resources must ship in the candidate app, not only in .build. Current packaging
copies the executable and icon but no SwiftPM resource bundle; implementation
must explicitly copy and verify the known localization bundle into the location
used by the generated resource accessor. Do not use an unrestricted .build glob
or silently rely on the accessor's development-path fallback. Record executable
AND resource fingerprints; a binary-only hash cannot identify translations.

The owner installs the selected language before constructing AppKit controls,
and maintains separate accepted/displayed/pending state. Keep views alive and
provide explicit relabel-only methods, including retained/pooled/proxy views.
Do not reconstruct the settings singleton or lose callbacks/drafts. Menu builders
use immutable displayed-language snapshots; tracked menus finish before change.
Track acquisition/release and final-release retry for ALL app-owned modal alerts
and attached sheets, not only named alias/Quit sheets: settings failure, management
failure, assignment alert, source picker, launch failure and any later Library
sheet are owners. Include actual field-editor marked text, shortcut recording and
native menu tracking. Overlapping owners postpone until the final release; recheck
new ownership before the queued callback. Do not repurpose a test-only readiness
hook as the production owner tracking system.
Equal semantic status does not imply unchanged presentation: language-generation
changes rerender statuses/labels even when catalog or watch state is equal. Keep
existing operation generations, success-banner expiry and represented-object/menu
action identities unchanged; do not fabricate a catalog/status change to refresh
text. Check the fixed-size settings window and compact status views for expansion,
wrapping and reachable actions in the selected supported languages.
Dynamic status/error updates retain typed state and render against the current
displayed snapshot. Frozen visual-only exits retain their original text until
removed. Teardown drops pending presentation without discarding accepted prefs.

## Preference contract and durability boundary

Use a dedicated schema1 language payload and validated enum IDs, separate from
Appearance schema2 and workspace layout. Match existing scalar preference stores:
a dedicated production UserDefaults suite and candidate-local hashed .language
suite. Namespace isolation does not promise physical UserDefaults files inside the
candidate directory. Persistent suite unavailability reports a save failure and
retains the draft; no silent in-memory store may report persistent acceptance.
Any session-only fallback would need a separately visible/approved contract.
Missing data defaults to Follow System without automatic write. Corrupt
known payload is recoverable only on explicit Apply. Future schema or oversized
uninspectable data is byte-protected and read-only; do not replace it with defaults.
Set a conservative 16KiB payload limit before decoding. Equal Apply must inspect
fresh payload state: healthy same values are no-op; explicit late corrupt/missing/
different payload repair is allowed; fresh future data is refused. Preserve
missing/healthy/corrupt/future/oversized/unavailable inspection origin explicitly
in the new language store. Missing must not collapse into healthy loaded-defaults:
startup creates no bytes, but explicit Apply of defaults after a missing/deleted
payload writes the new default payload. Do not modify existing scalar stores to
meet this new language-specific contract.

UserDefaults acknowledgement is not a guaranteed disk flush or restart proof.
Do not call synchronize or advertise crash-proof durability. Existing accepted
workspace-write Quit protection is unchanged. Explicit fresh-process, exact-profile
restart is required for scalar persistence acceptance. If stronger language-store
flush guarantees are requested, update this contract to a bounded file-backed
store and shared Quit protection BEFORE implementation, not midway by assumption.

## Verification and performance gates

- Pure resolution cases: ordered preferred languages, explicit scripts/regions,
  unknown/malformed identifiers, unsupported zh-Hant, defaults and override.
- Required-key equality and table parsing; typed interpolation/escaped characters,
  zero/one/many plural counts, long text, Unicode/emoji user names, missing keys
  and absent/invalid resources. No raw app data in diagnostic output.
- Store roundtrip, invalid/corrupt/future/oversized/no-op/stale equal-Apply handling;
  production-vs-candidate profile isolation, failures and draft/default behavior.
- Actual mounted controls in every shipping group and every approved supported language:
  titles/placeholders/accessibility/status/menus/alerts agree; stable selectors
  unchanged, preserved drafts/tabs/selection/query/focus. No matching test rewrites
  that merely replace expected Chinese literals without checking real consumers.
- Queued latest-wins with every actual input/modal owner, IME/recording and delayed
  status completions; teardown/hide/reopen and frozen folder/proxy appearance.
- Structural budgets: healthy equal Apply with unchanged effective language and
  no stale pending state permits one bounded fresh-store inspection, but zero
  persistence writes and zero relabel work. Test inspection/write/relabel counts
  separately; do not infer physical zero IO from a cached UserDefaults API read.
  Explicit corrupt/missing/different repair permits one bounded write; preference-only no-op does
  not suppress a newly resolved Follow System language. Text-only Apply zero catalog,
  icon/wallpaper requests or layout writes; no work in frame callback. Locale-
  sensitive catalog order/search unchanged. Lazy views do not become eagerly built.
- Independent bounded source review, nonzero focused/full XCTest, Debug/Release,
  diff-check, fingerprints and unique candidate. Packaging inspection/smoke must
  resolve translation resources with the build-directory fallback unavailable.
- Real exact-candidate GUI, long English/Japanese labels and compact sizes,
  VoiceOver, safe restart and matched real-icon physical AB remain separate gates.
  Preserve >25ms CAUSALITY_UNRESOLVED and unsupported120Hz, no new performance PASS.

## Delivery and maintenance

Keep dirty work/history/old candidates, no commit/install/sign/publish/process
stops. Parallel helpers have disjoint consumer/resource tests; Main integrates
owner/store/settings/package. Work continues under the complete parity ledger,
not a reduced language-only goal. Native testing retains prior entry boundaries.

## Evidence and open decisions

Main's current-source seams are recorded in
`Workflow/results/LANGUAGE_OWNER_RESOURCE_SURVEY.md`; the companion UI inventory
is `Workflow/results/LANGUAGE_UI_SURFACE_SURVEY.md`. These are discovery evidence,
not implemented/verified language parity.

User confirmed the supported language set and live safe-boundary behavior.
Library and adjustable capacity confirmations are independent and still pending.

Official resource references (engineering guidance only):
- [Apple: Localizing package resources](https://developer.apple.com/documentation/xcode/localizing-package-resources)
- [Apple: Bundling resources with a Swift package](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package)
- [Apple: Swift packages resources and localization](https://developer.apple.com/videos/play/wwdc2020/10169/)

## Advisory review integration (2026-10-14)

`Workflow/results/LANGUAGE_CONTRACT_ADVISORY_REVIEW.md` identified seven contract
clarifications. All are addressed in this revised proposal: fresh inspection vs
writes; accepted-only reopen/failed-save semantics; PagingUI/frame accessibility;
explicit language-tag table/two-language alternative; missing-origin preservation;
persistent-store unavailability; all-modal ownership/release notifications. This
is an approved contract after explicit user confirmation, NOT a source implementation PASS.

## Implementation verification adapter (2026-10-14)

A developer-only Foundation LocalizationResourceProbe target shares the typed key/
template schema to inspect the exact packaged app's bundle with the development
fallback closure forbidden. It is not included in the app, performs no AppKit,
preference or process control, and does not launch the candidate. Known bundle
copy/required24-key and signature validation plus resource hashes are packaging
gates. This engineering adapter does not change confirmed product behavior.
