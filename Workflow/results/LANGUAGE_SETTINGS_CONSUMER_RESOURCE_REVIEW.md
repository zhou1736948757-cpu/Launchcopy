# Language Settings Consumers and Resources — Independent Source Review

Date: 2026-10-14.

Verdict: **bounded SOURCE_CLEAR for the fingerprinted source snapshots below**.
No actionable implementation defect was established in the assigned resource/API
and three-consumer scope. **RUNTIME_CRASH_UNRESOLVED** remains a separate required
gate; this source verdict cannot close it, certify a repair, or certify a suite PASS.

## Authority, scope and evidence boundary

Reviewed the approved `Docs/INTERFACE_LANGUAGE_SPEC.md`, project `AGENTS.md`,
`/Users/mac/.codex/RTK.md`, current language runtime stage summary, worker key
request and resource/consumer handoffs. The explicit assignment waives Chief/chef
routing and retains Main plus at most two helpers. This reviewer dispatches nobody
and writes only this report. The project is a SwiftPM macOS 14 AppKit application;
localization is a Foundation-only target injected into retained native views.

Primary scope: 71 new SettingsTextKey cases, settingsText/hiddenReferenceCount,
the full 97-key en/zh-Hans/ja source tables and shared validation/fallback path,
AppearanceSettingsView, AppManagementSettingsView, AppSourcesSettingsView, and
the authored tests relevant to those contracts. Read all 17 new consumer test
methods and all 13 new settings-resource test methods as source only. Also read
the existing resource validation/bundle/snapshot tests and helper, and the existing
AppSourcesSettingsTests following Main's crash report. Packaging manifest/probe
and selected packaging script sections were inspected only to bound the resource
locator claim; no packaging command or compiled app was inspected or executed.

AppDelegate, window-controller integration and aggregate readiness/release retry
remain the separate runtime-owner reviewer's scope. This report does not duplicate
that review or certify remaining activation, folder, pager, alert or GUI coverage.
Reference applications, their source, assets and evidence were not read.

No Swift invocation, build, XCTest execution, app/GUI launch, process control,
commit, installation or implementation edit was performed. After the initial
bootstrap read of RTK.md, shell calls used RTK; the initial discovery reads before
that rule was loaded were unprefixed. The unrelated dirty tree was neither reset
nor staged. Only this Markdown file is a reviewer-authored project change.

## Source baseline and Main-reported runtime incident

All ten fingerprints in LANGUAGE_SETTINGS_RESOURCE_CATALOG matched actual bytes.
The consumer test and normalized key-request fingerprints also matched their
handoff. The original three consumer handoff fingerprints are superseded:
Main removed redundant default LocalizedStrings property initialization and assigns
strings in the designated initializer. In-memory reconstruction of just that
property declaration reproduced each original consumer hash and size exactly.

Main then reported: first focused compilation completed, but execution crashed
when starting existing
`AppSourcesSettingsTests.testActualAddControlCanonicalDraftAndNoSaveUntilApply`,
with stderr `freed pointer was not the last allocation`; the exact isolated
existing async test also reproduced signal 6. These are explicitly Main-reported
observations, not independently obtained logs, and no final suite PASS is assumed.

Main's single-file Sources B experiment replaces override convenience init
with two designated initializers and shared buildContent. This reviewer reread the
whole current file. Reversing only that initializer extraction **in memory**
reproduced pre-experiment SHA-256
`e425cc2365dc93d8179643748d8718440c99b2c36b8696689e09926db5c01618`.
Thus the reviewed Task, relabel, state and callback bodies are unchanged between
these two snapshots. The reviewed B snapshot is identified below; Appearance and
Management still use convenience initializers. Main's B test and reverse causal
check were pending at the latest supplied checkpoint. No allocator/ABI/compiler
root cause or effective repair follows from the source equivalence alone.

Final fingerprint recheck observed Sources restored to the exact already-reviewed
A hash `e425cc2365dc93d8179643748d8718440c99b2c36b8696689e09926db5c01618`;
its convenience/designated initialization block was reread. All other fifteen
primary fingerprints remained unchanged. This observed reversal is source-state
evidence only: no B or reverse-test outcome was supplied or inferred. The source
verdict covers both identified A/B snapshots; runtime acceptance remains open.

## Resource/API findings

- LocalizedStrings is a Sendable value snapshot with immutable language and
  selected/English template dictionaries (`LocalizedStrings.swift:5-35`). The
  provider is consumed during construction, never stored. settingsText and
  hiddenReferenceCount read those dictionaries and deterministic integer segments;
  no resource lookup, file IO, locale negotiation, AppKit, task or callback occurs
  in their rendering paths (`:41-55`, `LocalizationResources.swift:219-231`).
  Snapshot construction does perform resource IO; this finding is zero **render**
  IO, not zero initialization IO or a transitive frame-budget certification.
- Required schema is 20 original static keys + four original templates + 71
  settings keys + two hidden-reference templates = 97 unique keys. A read-only
  Python lexical source inventory found exactly 97 entries in each source table,
  no duplicate/missing/extra entries, and six correctly signed template entries.
  All remaining static entries have zero tokens. Source table sizes are en 7079,
  zh-Hans 6550 and ja 9211 bytes, below the 64KiB read ceiling; every value meets
  the source validator's 4096-byte/nonempty/control-character constraints.
  This inventory is not execution of Foundation PropertyListSerialization or the
  Swift validator; their executable validation remains Main's gate.
- ResourceTable validates raw supported tables before fallback: malformed,
  oversized or non-string tables are rejected; individual invalid entries are
  omitted; unknown keys produce only an aggregate issue. ValidatedTemplate rejects
  missing/duplicated/unknown tokens and unmatched braces. Its argument signature
  must match exactly. Percent sequences remain literals rather than printf input
  (`LocalizationResources.swift:127-171`, `:186-231`).
- Fallback is valid selected entry, valid actual English entry, then exhaustive
  key-specific built-in English. Invalid values never become raw resource keys or
  unsafe format strings. English count 1 uses one; 0, negative and other integers
  use other. Chinese/Japanese select invariant other even for 1. English fallback
  separately selects English one/other, preserving Int.min/Int.max. Shipped
  Chinese/Japanese one/other hidden-reference values agree. Existing original API
  behavior and required-key ordering remain source-compatible.
- Diagnostic issue fields contain supported language, a known schema key or nil,
  and a stable issue kind. Unknown keys, values, paths and caught native errors
  are omitted. Rendering and the three views add no logging of app names, aliases
  or folder paths for localization. Displaying those existing user values in
  controls is intentional and does not turn them into templates.
- The .app locator returns only the exact packaged resource bundle, including
  case-normalized APP and nil mainResourceURL paths, before evaluating the lazy
  SwiftPM closure (`LocalizationResources.swift:8-20`). Missing or invalid app
  resources cannot activate development fallback. Explicit language directories
  are lowercased, avoiding OS-language negotiation. This source guard is retained;
  actual compiled-app resource availability with development resources unavailable
  is **not** established here.

The lexical inventory also independently found all 63 requested consumer cases
used by the three views: 21 Appearance, 16 Management and 26 Sources. Every
requested Chinese baseline equals the actual source-table value. Eight additional
tab/window/menu/button keys belong to Main's consumers. English/Japanese are
independently supplied source strings; their native fit and editorial quality are
not inferred from key coverage. No CJK literals remain in the three view sources.

## Relabel preservation and local ownership findings

**Appearance** (`AppearanceSettingsView.swift:214-251`): relabel changes titles,
captions, AX and the retained feedback rendering only. It does not assign draft,
slider/checkbox values, validity, enabled state, callbacks, targets, selectors or
identifiers. The feedback key/color preserves corrupt/future/invalid/save/default/
applied/queued/unavailable meaning. Queued color remains secondaryLabelColor.
Relabel does not query presentationStateProvider or advance accepted feedback;
explicit refreshPresentationStatus retains that responsibility.

**Management** (`AppManagementSettingsView.swift:144-190`): existing popup items
are relabeled in place; there is no remove/add/select or selectionChanged call.
Represented records, canonical selection and persisted display-name inputs remain
intact. Alias and original name remain verbatim with their existing separator;
the localized hidden suffix owns its spacing. The alias field's stringValue and
actual editor are untouched; only placeholder/AX change. Checkbox, readOnly,
callbacks and control enablement are untouched. Hidden count includes all stored
references, including currently absent apps. Typed feedback retains error/success
meaning and visibility; relabel cannot revive dismissed feedback.

**Sources, reviewed B** (`AppSourcesSettingsView.swift:225-272`): relabel updates
static/AX text, the placeholder item, optional native panel prompt, retained watch
status and typed feedback. Other item titles/represented root strings, selection,
fixed paths, automatic draft, readOnly/busy, Task handle, generation and callbacks
are untouched. There is no syncControls/reload/cancel/updateEnabled/admit/apply/
refresh call. Async admission/apply results are typed, rendered using self.strings
at completion rather than a captured translated sentence. Equal watch state can
therefore relabel without fabricating a watcher or catalog change.

Sources exposes actual local ownership as openPanel != nil || busy (`:29-32`).
Acquisition notification follows real sheet registration or Task registration;
release follows controls/status updates. The last-reported Boolean prevents
duplicate notifications. Picker-to-admission handoff sets busy again before
notifying, so no false aggregate release is published between those operations.
Native cancellation without admission releases; explicit cancellation advances
the generation, cancels/drops the Task and panel, clears busy, updates controls,
then notifies. Late callbacks reject stale generation/cancelled work. Relabel
neither releases ownership nor emits an ownership callback. These are local source
facts; actual native callback ordering and Main's final-owner retry are runtime
gates, not certified behavior.

## Crash-focused Task/lifetime/actor review

The existing failing test (`AppSourcesSettingsTests.swift:11-21`) creates an
unmounted view with init(frame:), installs immediate async admission/apply closures,
waits by Task.yield, then performs Apply. It does not present an NSOpenPanel,
install an ownership callback, use a held continuation, or perform a language
relabel after construction. Consequently the newly added real-sheet release path
and callback consumer are not exercised by that test. A crash observed at test
start does not identify which source statement failed without Main's stack/logs.

The view and both test classes are @MainActor. Ordinary Task closures are created
inside actor-isolated view methods; no detached Task, manual executor transfer,
unsafe pointer, Unmanaged, unowned capture or manual deallocation is present.
Admission/apply closures are captured as local values before launch. self remains
weak across await and is promoted before any post-await native control access;
generation and cancellation are checked before mutation (`Sources B:188-223`).
Clearing the stored Task handle from its executing closure is visible, but this
alone does not establish an invalid memory lifetime or explain the allocator
message. Do not prescribe moving that assignment as a root fix without evidence.

The callback property types are plain async closures, not explicitly @MainActor
function types. Source-local view mutation after await is actor-owned; callback
executor/captured-state behavior must still be assessed against the actual compiler
and runtime evidence. There is no basis here for claiming a Swift concurrency
runtime or ABI defect, or for silently changing that callback contract.

Sources has no deinit cancellation; its explicit cancelPendingOperations API is
the caller's lifecycle boundary. Dropping a view reference alone does not prove
an async service operation was cancelled. This is an existing integration
dependency, not evidence of use-after-free in the reported test, which holds its
view while settling. Caller teardown belongs to the separate owner review.

Reviewed B initializers assign strings once, call super.init once and buildContent
once. buildContent contains the former designated initializer's same native
control/constraint/action setup, relabel and default reload. The injected path
adds no default localization lookup. The default path still constructs one Chinese
snapshot. Appearance/Management convenience initializers each delegate once to
their assigned-string designated initializer; no source double initialization was
found. Similar syntax alone does not prove their runtime safety after a reproduced
Sources crash. Their exact async/mounted regressions remain necessary.

## Authored coverage: 17 new consumer tests, source only

All methods in LanguageSettingsConsumersTests.swift were inspected. The source
uses real views/native controls, mostly mounted in unshown windows, rather than
parallel test-only relabel implementations. Assertions retain identity/callback/
draft behavior and compare actual values with injected snapshots; independent
Chinese and distinct-language assertions supplement those comparisons.

| Method start line | Source coverage |
| ---: | --- |
| 76 | Injected initial language on all three real views before presentation |
| 93 | Appearance mounted text/AX, draft/values, object/constraint identity, callbacks |
| 144 | Queued status until explicit refresh; unavailable/default feedback |
| 183 | Appearance corrupt/future readOnly and all save failures/unavailable callback |
| 230 | Invalid native draft preserved; relabel cannot reset/save it |
| 253 | Canonical selected record and original/alias search inputs unchanged |
| 278 | Management menu identity/represented records, unsaved Unicode alias, text/AX |
| 336 | Actual field editor first responder, selection and marked text preserved |
| 377 | Management readOnly/corrupt and every save outcome without extra callbacks |
| 425 | Hidden references 0/1/3 including absent apps in the real count control |
| 448 | Sources paths/menu identity/selection/draft and all four watch states |
| 512 | Sources readOnly/corrupt/removed and dismissed draft feedback |
| 556 | Held admission, retained busy/ownership, current-language completion once |
| 598 | Held Apply, all five outcomes, draft/selection/item/callback preservation |
| 650 | Rejected/already-covered admission feedback without new work |
| 672 | Real panel builder's prompt/configuration; construction does not present it |
| 698 | Explicit admission cancellation rejects late callback and releases once |

The 13 new resource tests cover actual selected entries, exact 63 Chinese messages,
tabs/Main keys, suffix/verbatim Unicode, counts and integer bounds, individual
English fallback, required static signatures, invalid values, exact named count
signatures, fallback plural grammar, invariant selection, absent/invalid safety
values and literal escapes. Existing modified tests add a golden 97-key contract,
three-table equality, immutable-provider requests/release, privacy redaction and
synthetic packaged layout/development-accessor traps. None was executed by this
reviewer; Main's crash precludes assuming completion or success of this coverage.

## Static coverage gaps and required handoff

1. Resolve the reproduced runtime crash with Main-owned exact-source evidence.
   Record A/B source and test/build identities, exits and reverse causal evidence.
   A green retry is not a root fix. Do not weaken existing assertions or alter
   tests simply to avoid init(frame:). No runtime PASS exists in this report.
2. Run nonzero focused tests for the 17 consumer methods, 13 resource methods and
   affected existing async Sources/Appearance/Management regressions on the final
   frozen implementation. Reviewed B is an experiment, not an approved runtime repair.
3. New source tests construct but never display the real picker: actual open/cancel/
   accept, continuous picker-to-admission ownership, stale panel completion and
   queued-language retry remain uncovered dynamically. Late-cancellation coverage
   is admission-specific, not a held Apply or real attached-sheet teardown test.
4. Real IME/VoiceOver/native menu tracking, first-responder behavior under native
   relayout, long English/Japanese action fit and reachable wrapping in the fixed
   window remain unverified. Object/constraint identity assertions do not prove fit.
5. Lexical source parsing is not Foundation parsing or compiled validation. Main
   must validate all actual 97-key tables/signatures and exact packaged resources
   with development fallback unavailable, preserving executable AND resource
   fingerprints. Prior 24-key packaging evidence cannot establish this 97-key wave.
   The shared-schema probe validates all required keys dynamically, but its render
   loop explicitly enumerates only original text keys/templates; new render API
   behavior is covered by authored module tests, not inferred from that probe loop.
6. Provider instrumentation is source coverage for render IO only. It does not
   measure catalog/icon/wallpaper/layout requests, control layout cost or transitive
   frame formatting/relabel budgets. Main's integrated structural/performance gates
   remain separate, as do existing >25ms causality and unsupported120Hz limitations.
7. These three views do not establish all-interface text or modal ownership parity.
   Remaining activation/folder/pager/alerts and overall GUI acceptance are explicitly
   outside this verdict. Main's separate owner reviewer covers runtime assembly.

The bounded tracked git diff --check returned exit 0, but primary reviewed files
are untracked; it is not a full-content whitespace check, compilation or runtime
evidence. The lexical inventory and SHA-256 comparisons were read-only static
inspection, not substitute tests. Refresh source fingerprints after Main settles
the initializer experiment; preserve historical consumer handoff hashes explicitly.

## Reviewed primary fingerprints

Hashes identify source/resource/test bytes, not a compiled candidate. A later edit
requires review of the affected input and a new baseline. Sources A and B were both
read in full. The table records A restored at the final source recheck; reviewed B
is `1dd72f4699631668170e4f57d87f249918c2eb67ff051b7bf0452f3bec746e2b` (14730
bytes). Final A is 14641 bytes. Line citations marked B refer to that identified
experimental version; equivalent post-initializer A locations are six lines earlier.

| File | SHA-256 |
| --- | --- |
| Sources/LauncherLocalization/SettingsTextKey.swift | b0c68395c0bca8fdae284a9a66442b444c39842a6ce5a57a243ff1c0867ad1fe |
| Sources/LauncherLocalization/LocalizedTextKey.swift | 896c7d6b643d4dfa4f2add9cc03e14398b8cc18fae12fee5723ccbb93693d148 |
| Sources/LauncherLocalization/LocalizedStrings.swift | de5d3e3de351553f9ab90756685182ca3198445397cd4e64de330a519c334549 |
| Sources/LauncherLocalization/LocalizationResources.swift | 1706a6ede537406297acf74e39b807bfa03a351f79ebad840cf078604f5ccdc3 |
| Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings | f455af735a7efbb83542eccfa8d9cb504cc41424878a11fa48c96444b371f701 |
| Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings | aaedafedbdf00a09570b473cdbb332bd190a4d715ba5e14891e34673fea44f49 |
| Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings | 85d7eaa58d8ba1e3f13920f6eded93d8049e8bc13235b86fb4a4321a5b9f2398 |
| Sources/PagingPrototypeApp/AppearanceSettingsView.swift | f71805692f7f1bae53fd6cdf0782f87220b84cf85bd6c668a75b535e92b4c76d |
| Sources/PagingPrototypeApp/AppManagementSettingsView.swift | 7800615c38952b3463febc8464846cef5692e2be27243337c2bfc5dc7fb325c1 |
| Sources/PagingPrototypeApp/AppSourcesSettingsView.swift | e425cc2365dc93d8179643748d8718440c99b2c36b8696689e09926db5c01618 |
| Tests/PagingUITests/LanguageSettingsConsumersTests.swift | 7f9c9aac4b3c5d82b2a5e4935977d2185bb95636eaae99ff96da24cffbdc599c |
| Tests/LauncherLocalizationTests/SettingsLocalizedStringsTests.swift | cd705691d005e6086ddfaf3470f7241293dfdeae77d682f7958bc2104e45307d |
| Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift | 9d59e12a84c29ef4bf2443ff5e46a200037370ea833771ed118258d0c582afae |
| Tests/LauncherLocalizationTests/LocalizationResourceBundleTests.swift | f06f59060073971a1079311936f375173f95368e14ab628f882835818fac0d87 |
| Tests/LauncherLocalizationTests/LocalizedStringsTests.swift | ecf3751ff9dd7a9db2dff49044e45b431385d10054456f38754f111da11a8bc0 |
| Tests/LauncherLocalizationTests/LocalizationTestSupport.swift | fdc15e3bc8f1ccf602c7aad3a9dcc0e1e450ddf5f38424aa124609886d14ad4f |


## 2026-10-14 correction — Empty popup index precursor and bounded repair

This append preserves the preceding SOURCE_CLEAR and RUNTIME_CRASH_UNRESOLVED
history. It **supersedes the earlier no-actionable-defect conclusion for the
unfixed Sources A/B snapshots**: the initial review missed an empty-menu index
precondition on the constructor's relabel path. Resource/API and the other two
consumer findings are unchanged by this correction.

Current disposition: **historical P1 finding confirmed; bounds repair SOURCE_CLEAR
at the new fingerprint below; runtime rerun pending**. This is not a final suite
PASS or a claim that every observed abort is resolved.

### Finding R1 — Sources construction indexes an empty native popup

**Evidence and trigger.** Main reports that LLDB on the exact existing async
Sources test identified an NSMenu.itemAtIndex assertion **before** the secondary
allocator abort. This reviewer did not run LLDB or independently inspect its raw
stack; the observed ordering is attributed to Main. Independent current-source
inspection establishes the concrete path:

1. rootsPopup is created without items (`AppSourcesSettingsView.swift:12`).
2. The designated initializer invokes relabel at line 88, then reload at line 89.
   The default convenience initializer delegates to that same initializer.
3. The placeholder is first added by syncControls at line 126, reached through
   reload at line 100. The first relabel therefore runs with zero popup items.
4. The old relabel unconditionally evaluated rootsPopup.item(at: 0) before optional
   chaining to title. The optional result does not guard evaluation of the indexed
   native call or its index precondition. Index 0 is invalid when the count is 0.

**Likely root cause.** The new relabel helper assumed a placeholder already existed,
while constructor ordering intentionally relabels before data reload. This is a
concrete synchronous UI initialization defect, reached before the failing test can
install or run its async admission/apply callbacks. The allocator message alone
had obscured that earlier failure; it was not evidence of an async Task lifetime
or convenience-initializer/ABI defect.

**Affected scope and severity.** P1: default and injected Sources initialization,
including first lazy construction of the settings consumer and the existing/new
constructor tests. The same code existed in reviewed A and the initializer-only B
experiment, so extracting buildContent did not eliminate the empty-popup condition.
Actual shipping crash incidence is not separately established by this source review.

**Confidence.** High for the source trigger and required bounds protection.
Main's LLDB report corroborates the precursor; runtime resolution after the fix
still requires Main's actual rerun evidence.

### Reviewed repair and preservation

Main restored the original A convenience/designated initializer arrangement and
added this narrow protection in relabel (`AppSourcesSettingsView.swift:249-253`):

```swift
if rootsPopup.numberOfItems > 0 {
    rootsPopup.item(at: 0)?.title = strings.settingsText(.sourcesSelectRoot)
}
```

The condition and indexed access are in the same synchronous @MainActor method,
with no await or external action callback between them. At empty construction the
invalid access is skipped, while subsequent button/caption/AX/watch/feedback
updates still execute. The subsequent normal reload inserts the placeholder using
self.strings, so its initial label is still localized. With populated items the
existing item title is updated in place; selection and represented root identities
remain intact. No early method return, popup reconstruction, reload, draft reset,
callback replacement, task cancellation, generation change or new IO was added.

Current Sources bytes: 14858; SHA-256:
`e3ba4daa7127d64387d3c7707d999198fdba32981fcd24342230a1050326291d`.
Read-only in-memory removal of just the two comments and conditional wrapper
reproduced exact restored-A hash
`e425cc2365dc93d8179643748d8718440c99b2c36b8696689e09926db5c01618`.
All other fifteen primary report fingerprints still matched. This independently
bounds the repair to the index protection; historical fingerprint rows above are
retained rather than silently rewritten.

A bounded scan of the other two consumer relabel methods found no analogous indexed
lookup: Management iterates existing itemArray; Appearance has no popup access.
The repaired Sources method likewise iterates itemArray for remaining menu AX.
This observation does not certify unrelated indexed accesses elsewhere in the app.

### Runtime disposition and remaining gates

The convenience-initializer causality hypothesis is refuted according to Main's
checkpoint; the source review now identifies the empty-menu access as the concrete
precursor. No compiler/toolchain migration is proposed or performed, and no Swift
ABI or concurrency-runtime explanation is supported by this finding.

The previous unexplained crash is now **precursor identified / bounds fix reviewed /
actual rerun pending**. Preserve the original RUNTIME_CRASH_UNRESOLVED entry as
history; do not close the runtime gate until Main records results for the repaired
exact source. A retry's color alone does not establish causal repair or a suite PASS.

Existing AppSourcesSettingsTests.testActualAddControlCanonicalDraftAndNoSaveUntilApply
already constructs through the default path before async actions. The new
LanguageSettingsConsumersTests.testInjectedInitialLanguageConfiguresTheRealViewsBeforePresentation
constructs through the injected path for all three supported languages. These are
appropriate existing regression inputs for Main to run with their assertions
unchanged, followed by the assigned focused consumer/resource coverage. They were
reread as source, not executed here. The prior panel/IME/fit/packaging/frame/remaining
shipping-surface coverage gaps remain open.

Only this report was appended by the reviewer. No implementation/test edit, Swift,
build, test execution, GUI/process action or toolchain change was performed.
