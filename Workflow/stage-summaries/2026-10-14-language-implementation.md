# Interface Language — Implementation

Status: IN_PROGRESS, 2026-10-14. Approved source of truth:
`Docs/INTERFACE_LANGUAGE_SPEC.md`. User selected all three languages plus Follow
System, safe-boundary updates, and preserved drafts/query/arrangement.

## Baseline and scope

Latest folder/icon candidate2163/0 and341 source fingerprints; GUI/restart/
VoiceOver/physical gates remain pending. No reference code/resources, commits,
installation/signing/publishing/app/process control. Dirty tree and old artifacts
preserved. Library/capacity contracts remain unconfirmed. The user's reply removes
the language-contract blocker; get_goal still reports blocked (tool cannot resume),
so do not invent an active status or call complete. Work resumes on explicit user
instruction and counts as concrete progress, not a new no-progress recurrence.

## First implementation wave and ownership

Deliver real shared localization resources/resolver, strict isolated scalar store,
coordinator/presentation transaction and native Language controls/tests. Runtime
wiring and all existing shipping consumers remain required follow-up work, not
certified by this foundation. Main owns Package.swift, candidate resource packaging,
LanguageSettingsCoordinator/LanguagePresentationController/LanguageSettingsView,
and serialized Swift execution. Worker1 owns new LauncherLocalization source/
resources/tests; Worker2 owns new LanguagePreferences source/store/tests only.
Main+2 concurrent, disjoint writes, no helper Swift or native app commands.

## Acceptance and maintenance

Foundation must resolve strict tags/fallback, format counts in selected language,
protect future/oversized/unavailable/missing-origin preferences, preserve draft
and queued-latest state, and reject teardown/reentrant callbacks. Verify actual
packaged resource paths rather than development fallback. Focused tests/full suite,
Debug/Release, independent bounded review and source/resource fingerprints required.
No full-language GUI/restart/physical or full parity PASS from foundation tests.

## Main foundation source checkpoint

Main added neutral resource dependencies/defaultLocalization=en, independent
hashed language profile namespace, a preference/presentation coordinator, counted
interaction leases and a latest-wins next-turn language presentation controller.
Native LanguageSettingsView has stable choice/action IDs, endonyms, typed feedback,
draft-only defaults and relabel-only updates without data reload. New mounted-
control/coordinator/presentation/profile tests are written but NOT run yet.

Known-bundle candidate copying/resource hashes and a Foundation-only explicit
packaged-resource smoke are added. Generated accessor/resource layout remains
unverified until the first build; no future candidate success inferred. Main
requested packaged-app locator guard from resource worker to prohibit accidental
absolute development fallback when a packaged resource bundle is missing.

AppDelegate and existing settings/controller/grid/pager/menu/error consumers are
not wired yet. This wave is real implementation foundation, not complete language
support or a user-testable candidate promotion. Workers still writing, Main waits
for source freeze before serialized Swift execution.

## Scalar worker result / bounded review dispatch

Russell published LanguagePreferences.swift and19 new XCTest methods. API matches
Main's integration: six distinct load origins, schema1 exact shape,16KiB decode
ceiling, fresh future/oversized protection, explicit missing/corrupt repair,
UserDefaults acknowledgement only, and a dedicated unavailable store. Main read
source/report; worker closed. No tests/build were run by the worker.

Kierkegaard independently reviews only stable owner/store/native-control/profile
foundation and related tests while resource worker finishes. Main+resource worker+
reviewer remain within3. Resource mutability explicitly excluded from this review.
No AppDelegate/consumer/GUI verdict inferred. Main-only Swift still awaits freeze.

## Foundation structural budget

Controller schedules at most one outstanding next-turn presentation callback,
uses counted token owners (no polling timer), rechecks readiness, coalesces newest
request and cancels pending work on teardown. Coordinator's true healthy equal
Apply performs one fresh store inspection and zero writes; explicit repair invokes
the store's separately counted protective inspection/write. Native relabeling only
updates captions/AX/feedback and never reloads draft/data. Real frame/cost and
input-owner budgets must be verified once production runtime wiring exists; they
are not established by an unwired foundation or historical physical traces.

## First review finding / real red reproduction and repair

Owner/store reviewer found P2: a valid positive future schema beyondInt decoded
as corrupt and explicit Apply could replace protected bytes. Source freeze then
Main ran one actual regression method:21 assertion failures, including write,
coordinator presentation and mutable controls (01:49:59.737JST). Original log
future-header-red.log retained. Main adds truthful protected-unrepresentable
load/save origin, coordinator refusal, read-only typed native feedback and a20th
localized key in all three resource tables. Existing small malformed-header repair
semantics remain unchanged. Header numeric range classification is conservative;
no fabricated/clamped version number displayed. Focused/full/rereview pending.

## First build / resource path evidence

Corrected focused-r1:72/0 at01:51:03.946JST0.159s. This selector covered the initial
resolver/string/owner/store/native/profile classes, but omitted two new resource
validator/locator classes; it is not complete foundation coverage. Worker authored
multiple test files, all now frozen/closed. Full focused selector will include the
LauncherLocalizationTests module, not only two class names.

Generated SwiftPM accessor actually uses Bundle.main.bundleURL/<bundle> followed
by an absolute build-path fallback. Our packaged-app locator deliberately bypasses
it for .app and selects Contents/Resources/<knownbundle>; pure locator tests must
prove fallback closure stays uncalled. Built resource bundle is flat and SwiftPM
normalizes zh-Hans to zh-hans.lproj. Main normalizes filesystem lookup/checks and
fixtures accordingly (language preference IDs remain zh-Hans), avoiding accidental
case-insensitive-filesystem dependence. One new weak fixture warning adjusted via
explicit assignment, retaining its lifetime assertion; no Swift language migration.

## Expanded focused gate / explicit golden-key correction

Focused-r2 ran85methods with5 assertions failing, all from the strict golden
19-key list not including Main's newly required future-protected20th key; old log
retained. Main updates that explicit list to include the new key, preserving exact
order/key-set comparisons for all three tables (not replacing them with a tautology).
No failing runtime assertions were weakened. R3 and full-suite gates pending.

## Numeric parser boundary follow-up

Focused-r3 passed85/0. A separate Foundation-only numeric probe demonstrated that
JSONSerialization refuses1e1000 and400-digit positive integers; the first repair
could still classify those future headers as corrupt. Main adds a bounded root-
header lexical preflight for otherwise unrepresentable numeric tokens, with
escaped-string/nesting and BOM encoding handling; no general number conversion
or clamped fake schema. Regression expands to both cases. Original probes/red/
focused logs remain historical. Re-review/focused/full pending on revised bytes.

## Resource packaging review / strict-schema remediation

Noether identified P2: the first Foundation script only checked equal key sets/
Bundle lookup, so all three tables could omit the same key or have bad signatures.
Main replaces the package gate with a developer-only Foundation probe target using
LocalizedStrings.validateResources and the exact same24-key/placeholder schema.
The probe injects the actual packaged .app and a fatal development-fallback closure,
never launches the candidate or accesses preferences, and is not shipped in it.
The old standalone lookup script remains supplementary, not an acceptance gate.
Resource/source review update, focused/full/build/package verification pending.

## Header ambiguity protection

Main also validates duplicate root-version ambiguity: known/large versions cannot
hide protected bytes behind another decoder's key choice. Bounded lexical preflight
runs before header selection; the schema1 path rejects a newer root version found
by JSONSerialization. Added escaped-root-key/nested-string fixtures, with strict
unchanged-byte/write assertions. Header tests do not cover arbitrary malformed
JSON semantics beyond this conservative read-only predicate; source review remains
bounded and upcoming focused/full runs must certify the new input snapshot.

## R5 failures and encoding/duplicate-header correction

Focused-r5 ran86methods/12assertfailures: preflight Double rounding mislabeled
representableInt.max as unknown; one duplicatefutureheader was overwritten. Main
changes preflight to return exact representable future origins via Int(token), and
only uses Double overflow classification when Int conversion cannot represent it.
All root positivefutureinteger tokens now protect regardless decoder duplicate-key
choice. Existing strict Int.max assertions retained.

Owner reviewer identified BOM-less UTF16/32 source gap. Main recognizes documented
zero-byte prefix shapes with UTF32 beforeUTF16 and adds full BOM/no-BOM future +
healthy-schema matrix, plus nested-key decoy and escaped-key fixtures. The planned
matrix uses real alternate encodings (does not add BOMs to the no-BOM cases).
R6/re-review/full gates pending; all earlier failures/logs retained.

## Healthy UTF32LE/BOM boundary normalization

R6 ran88methods/1failure: healthyUTF32LE+BOM payload was classified corrupt.
Diagnostic fixture context was briefly malformed (compile-only failure, no test
gate), corrected without weakening expectations; diagnostic-r2 identified encoding
2617245952/BOMtrue at02:08:47.101JST. Main normalizes recognized UTF8/16/32 input to
bounded UTF8 once for both header and body inspection, preserving original stored
bytes. This avoids Foundation reader disagreement on the UTF32LE BOM while retaining
healthy equal-save byte/no-write behavior. R7/full/source rereview pending.

## Integral notation repair / first full and package history

Prior full-r1 passed2236/0 at02:11:38.134JST38.440s; Debug/Release r1 and shared-
schema packaged24-key probe passed (25.45s app+1.08s probe release). This is a
historical input snapshot, not certification of later store changes. r1candidate
retained, not promoted or installed. Both negative resource fixtures rejected:
same required key omitted inall3 and invalid placeholder signatures inall3.

Reviewer correctly retained P2 integraldecimal/exponent duplicate-header gap.
Main reproduced one method6assertfailures at02:14:00.645JST; originalred log retained.
Root-token inspection now uses the same JSONDecoder Int semantics for2.0/2e0,
not float rounding or plain Int-only syntax. Both duplicate orders tested; source
fingerprint-r2 captured362inputs. R8/full-r2/uniquer2build/rereview pending.

## Final test/source review gate for foundation

Focused-r8:88/0 at02:15:46.166JST0.513s; full-r2:2236/0 at02:16:30.627JST43.298s.
Independent owner/store and resource/package bounded SOURCE_REVIEW_CLEAR, original
findings and failed logs preserved. All helpers closed. This covers foundation
source/controller/detachednativecontrols/strictstore/resources only; actual shipping
view/owner/input integration is still incomplete. Debug/Release r2 currentlybuilding;
no current candidate hash/packaging PASS assumed until process completes.

Next required approved wave (no new language confirmation needed): install language
store/resolution before UI creation; add Language tab to existing settings; connect
AppDelegate readiness plus real pointer/IME/recording/menu/modal acquisition/release;
translate/relabel remaining shipping groups and typedasyncnotices; cover same-state,
pooled/frozen views and pager AX next-turn seams. Keep all other drafts/query/
arrangement and protocol IDs. Then actual exact-candidate GUI/VoiceOver/restart/
matchedphysicalAB gates; no newlanguageuseracceptance yet. Library/capacity approvals
remain independent; no feature removed from the full parity objective.

## Foundation code closeout (not full language support)

Status FOUNDATION_CODE_VALIDATED_RUNTIME_INTEGRATION_PENDING. R2 Debug/Release
success17.36s app+0.23sprobe; candidate/exe SHA
 d0c980b3cf0a3cdc3bb2eaa149167f0147f75629bf992cb8a45ae200592a2bdf.
362 postbuild fingerprints matched; resource manifest verified; strict packaged
24-key/3-language positive gate and both negative fixture gates passed. Independent
source findings cleared within stated scopes, oldFAILs retained. Code checkpoint
LANGUAGE_FOUNDATION_CODE_CHECKPOINT.md records all remaining wiring/acceptance.
No app launch/install/commit/process stop; all helpers/jobs done. Full goal remains
incomplete; tool goal status lastblocked is not manually rewritten. Explicit user
language approval enabled this genuine implementation progress, not a blocked wait.
