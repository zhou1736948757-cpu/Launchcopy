# Interface Language Contract — Advisory Review

Date: 2026-10-14. Disposition: actionable contract clarifications; advisory only.
This review neither approves the user's contract nor establishes implementation,
runtime, localization parity, persistence, or performance acceptance.

## Boundary and inspected baseline

Reviewed the current proposal, Main's corrected owner/resource survey, and bounded
current-source excerpts for package assembly, settings lifecycle, scalar stores,
profile isolation, presentation readiness, Quit handling, catalog ordering and
pager accessibility. Chef workflow is waived for this assignment. Main and Zeno
retain their separate scopes. Only this report is written.

No reference-product/assets/evidence reads, Swift runs, tests, builds, native GUI,
app launches, process stops, installs, commits or source/test/package edits were
performed. Shell commands were prefixed with `rtk`. Historical test counts and
performance classifications in the input documents were not independently verified.
No external documentation lookup was needed for these source/contract findings.

Input fingerprints at final read, before writing this report:

- `Docs/INTERFACE_LANGUAGE_PROPOSAL.md`: 172 lines;
  SHA-256 `daa48741663ded71cfcb7917202bb91305c8e8c4002ad1051060418d91c73c51`.
- `Workflow/results/LANGUAGE_OWNER_RESOURCE_SURVEY.md`: 64 lines;
  SHA-256 `d2eff15441905126a7e723fe4d58bb4886016381495ab8dff64f2ff22f558f97`.

All locations below are relative to the PagingPrototype root. Line numbers refer
to these reads; Main may revise the documents concurrently.

## Actionable findings

### 1. [P2] Define the zero-IO budget around mandatory fresh store inspection

**Proposal:** lines 111-116 versus 140-144.
**Source:** `Sources/PagingPrototypeApp/AppearancePreferences.swift:137-151`
loads persisted state even for an unchanged draft; its store reads UserDefaults
at lines 77-94 and writes at 97-104. **Survey:** lines 26-29.

The latest budget correctly limits no-op to healthy matching payloads, unchanged
effective language and no stale pending state. This resolves the earlier blanket
no-op claim for repairs. However, establishing freshness/health still requires a
current-store inspection; “zero ... IO work” does not define whether that read is
permitted. A cached UserDefaults API read does not establish zero physical IO.

**Recommended clarification:** permit one bounded current-store inspection;
require zero persistence writes and zero relabel work for the true no-op branch.
Give explicit repair its own write budget. Test load/save/relabel counts separately
rather than treating an unchanged enum as proof that no store work occurred.

### 2. [P2] Clarify reopen refresh and failed-Apply handling after the effective-language fix

**Proposal:** lines 22-23, 30-44, 97-104, 114-116 and 140-142.
**Source:** `AppearancePreferences.swift:148-151` invokes presentation only when
the preference value changes; `AppDelegate.swift:1913-1921` also treats equality
as an appearance presentation shortcut. These are appearance precedents.

Main's latest lines 38-39 and 140-142 correctly require effective-language
comparison and account for stale pending state. The prior Follow System equality
finding is addressed in the current contract; it must not be reported as still
missing. Remaining detail: reopening with a dirty language draft does not specify
whether refresh resolves the accepted preference or the unsaved draft, and it is
unclear whether a failed Apply may refresh Follow System independently.

**Recommended clarification:** reopen refresh should resolve the accepted
preference without accepting or replacing any unsaved draft. Specify failed-Apply
refresh behavior consistently with “failed save never changes ... displayed
language.” Add changed-OS/equal-Apply, dirty-reopen, failed-save and stale-pending
cases. User confirmation of the refresh behavior remains required.

### 3. [P1] Neutral resources omit actual PagingUI consumers and their frame path

**Proposal:** lines 9-10, 72-76, 88 and 134-144.
**Source:** `Sources/PagingUI/PageHostView.swift:65-69` creates a hardcoded English
page accessibility label; `Sources/PagingUI/PagingSurface.swift:905-923` creates
the corresponding value. `Package.swift:20-23` gives PagingUI only PagingCore.
`PagingSurface.swift:530-549` advances Core; its Core handlers at 554-584 update
accessibility, including formatting text before the equality guard at 920-921.

Naming only AppGridUI and PagingPrototypeApp as consumers leaves genuine shipping
accessibility outside the resource integration plan. Simply injecting a formatter
into the existing update method also risks placing localization lookup/formatting
on callbacks reached during frame advancement. Page-dot localization alone does
not cover these labels.

**Recommended clarification:** include PagingUI's retained and reused host/surface
accessibility as consumers of neutral presentation values, without making
PagingCore depend on localization or reversing target dependencies. Define the
frame budget as no added localization/resource/relabel work on the frame stack,
or explicitly specify the necessary deferred/prepared-string seam if the absolute
no-formatting requirement is retained. Verify real host/surface labels after reuse
and language change, and count lookup/formatting through transitive Core callbacks.
No new source filename or target dependency is asserted as already implemented.

### 4. [P2] Chinese resolution needs an executable expected-results table

**Proposal:** lines 22-29 and 127-128. No current resolver is established by the
survey or manifest; this is an underspecified proposed behavior.

The listed mappings distinguish bare `zh`, explicit Hans, and explicit Hant, but
do not resolve region-only Traditional identifiers such as `zh-TW`, `zh-HK` or
`zh-MO`, other regions, or other explicit Chinese scripts. “Parsed identifiers”
does not decide whether region inference is permitted when no script is supplied.
Different implementations can satisfy the prose yet choose different languages.

**Recommended clarification:** record expected results for those identifiers,
`zh-Hans-TW`, `zh-Hant-CN`, case/separator normalization, malformed tags, and ordered
lists such as `[zh-Hant, ja, en]`. Preserve the stated explicit-script precedence.
Recommend skipping region-only Traditional identifiers unless a Simplified
fallback is explicitly approved; do not present that recommendation as an accepted
product decision. Make the selected two- versus three-language scope determine
both resolver support and table coverage rather than hardcoding three into the
alternative's acceptance criteria (lines 18-21, 79 and 134).

### 5. [P2] Existing appearance load results cannot distinguish healthy defaults from missing bytes

**Proposal:** lines 111 and 114-116. **Survey:** lines 26-29.
**Source:** `AppearancePreferences.swift:77-80` reports missing data as
`.loaded(.default)`; coordinator lines 142-144 regard matching loaded defaults as
healthy. `AppSourcesStore.swift:49-53` also collapses missing into loaded defaults.

The proposal permits explicit missing-payload repair even when the draft equals
the accepted default. Copying those load-result semantics loses the distinction
needed to implement that branch. This is a limitation of the suggested precedent,
not a demand to change the existing appearance/source stores.

**Recommended clarification:** preserve missing/healthy/corrupt/future/oversized
origin in the new language store's result or inspection metadata. Specify when
explicit Apply writes a missing default payload; a startup load must still avoid
writes. Test deletion after load, equal Apply, and byte preservation on refusal.

### 6. [P2] Store unavailability must not silently become a successful persistent acceptance

**Proposal:** lines 32, 108-123 and 132-133.
**Source:** `AppDelegate.swift:1855-1865` falls back to an in-memory appearance
store if suite creation fails; `AppearancePreferences.swift:108-116` reports that
in-memory save as saved. `UITestProfile.swift:35-38,89-97` establishes hashed suite
names, not preference files physically beneath the candidate directory.

“Match existing scalar stores” could inherit a fallback that displays success
without any persistent language payload. The existing durability disclaimer
correctly excludes disk-flush guarantees, but does not distinguish unavailable
storage from an acknowledged UserDefaults write. Calling the hashed suite
“candidate-local” must describe isolation identity, not promise physical file
placement within the candidate.

**Recommended clarification:** define unavailable persistent storage explicitly;
recommend retaining the draft and reporting save failure rather than accepting a
language change as saved. Any session-only mode needs explicit user-visible
semantics. Keep profile namespace isolation separate from filesystem placement,
and prove persistence only by the specified fresh-process exact-profile gate.

### 7. [P2] Safe-boundary acceptance needs all app-owned sheets and owner-release notifications

**Proposal:** lines 33-40, 51-54, 100-104 and 138-139.
**Source:** `ActivationSettingsWindowController.swift:716-725` presents settings
failure sheets/modal alerts; `AppDelegate.swift:2209-2216,2241-2252` presents
assignment and management failure sheets, beyond the named alias/Quit dialogs.
`AppDelegate.swift:1931-1940` does not check attached sheets; its additional
readiness hook is explicitly test-only at lines 66-67.

The proposal names selected dialogs, while its general “all owners release” and
“every actual ... modal owner” gates need the remaining app-owned alerts too. A
predicate alone also cannot guarantee pending language flushes after the final
owner releases. Reusing existing error alerts without typed retained reasons
would leave stale sentences after deferred application.

**Recommended clarification:** include any app-owned attached sheet/modal alert,
and assign acquisition/release plus retry notification seams for each actual
owner. Test overlapping owners, final-owner release with no further input,
reacquisition before the queued callback, repeated/latest-wins requests and
teardown. Natural close/tab-switch cancellation remains existing user behavior;
do not add cancellation solely to force translation. Preserve the existing
error operation/reason and render it after safe relabeling.

## Confirmed claims and remaining acceptance boundaries

- Main's corrected settings references are accurate: factory lines 165-171 call
  `reload`; reload lines 242-246 stop recording and replace the draft. Direct
  relabel-only hooks are therefore a real requirement, not a current capability.
- `Package.swift:1-82` has no localization target, defaultLocalization or resource
  rule. `Scripts/package-app.sh:74-80,89-90,121-123` confirms executable/icon
  assembly and the current `zh-Hans` development region. Lines 143-144 record only
  the executable hash. The proposal correctly requires resource-aware packaging.
- The new target name/resource hierarchy and generated accessor are proposed.
  There is no inspected generated localization accessor to certify its lookup
  path. Do not promote an assumed bundle basename/location into a verified fact.
  Main must inspect the accessor for the eventual build and prove packaged
  per-language lookup with development fallback unavailable. Explicit app
  overrides must win even when OS language differs; absence/invalidity must have
  the specified safe outcome without raw keys or crash. Decide the English
  fallback/defaultLocalization relationship and the existing app development
  region deliberately; changing metadata alone does not implement app overrides.
- `AppSourcesStore.swift:51-53,64-74` supports the bounded-decode and oversized
  write-protection precedent. That protection is not supplied merely by returning
  corrupt on load; the save guard matters.
- `WorkspaceQuitCoordinator.swift:16-37,52-55` protects the termination reply;
  `AppDelegate.swift:2546-2568` drains layout writes. It does not flush scalar
  language preferences. Proposal lines 118-123 correctly keep that distinction.
- `AppCatalogCore.swift:109-114,252-257` retains an independent ordering locale.
  Interface language must not be passed into catalog/search or mutate user names.
- Supported languages, safe live refresh and any stronger durability behavior
  remain user decisions. Mounted controls, packaged-resource smoke, focused/full
  tests, fresh-process persistence, exact-candidate GUI/VoiceOver and physical
  performance gates remain unexecuted here. This report neither closes those gates
  nor changes the broader parity goal.

## Handoff

Main should cover the PagingUI/frame seam in finding 3 and clarify the remaining
store/refresh/fallback/owner details in findings 1-2 and 4-7 before implementation.
The latest effective-language/no-stale-pending correction and selected-language
plural interpretation requirements (proposal lines 84-86) are recognized; they
remain proposed, unexecuted acceptance requirements. This is a
bounded recommendation for Main/user consideration, not implementation or contract
authorization. Changed file: only `Workflow/results/LANGUAGE_CONTRACT_ADVISORY_REVIEW.md`.

## Advisory closure reread — 2026-10-14

This appendix supersedes the earlier open-finding disposition for the revised
proposal. Only `Docs/INTERFACE_LANGUAGE_PROPOSAL.md` was reread; no source,
survey, reference evidence, tests, builds or runtime were revisited. The inspected
proposal has 230 lines, SHA-256 `d04739ce1d2647207a6262a748605514a9cbb09ee6b3c58cbf6d3d81261351ef`.

| Earlier finding | Current proposal locations | Advisory disposition |
| --- | --- | --- |
| 1. Fresh inspection versus zero IO | 155-162, 186-191 | Addressed in contract text: bounded inspection, zero writes/relabel for true no-op, separate repair budget; no physical-zero-IO claim. |
| 2. Follow System, reopen and failed Apply | 56-66, 186-191 | Addressed in contract text: effective-language comparison, accepted-only reopen, draft preservation and no independent failed-Apply refresh. |
| 3. PagingUI consumers and frame path | 94-98, 112-118 | Addressed in contract text: PagingUI included; next-main-turn AX updates with lifecycle/generation checks and transitive invocation counts. |
| 4. Chinese tag resolution and chosen language set | 30-47, 100-111, 180 | Tag ambiguity addressed with explicit results and script precedence. One chosen-set wording inconsistency remains below. |
| 5. Missing origin and explicit default write | 152-162 | Addressed in contract text: distinct inspection origins, no startup write, explicit missing/default repair; existing stores unchanged. |
| 6. Unavailable persistent suite | 145-151, 164-169 | Addressed in contract text: failed save retains draft, no silent persistent-success memory fallback; isolation and disk durability distinguished. |
| 7. All modal/input owners and final release | 51-58, 132-141, 184-185 | Addressed in contract text: all sheets/alerts, marked text, recording and tracked menus; final-release retry and ownership recheck. |

### Remaining narrow documentation concern

Proposal lines 45-47 correctly require resource coverage/tests to follow the
user-chosen supported set, but verification line 180 still unconditionally says
“three supported languages”; resource line 101 also lists all three without a
condition. With the two-language alternative retained at lines 18-21, replace the
line-180 wording with “every approved supported language” and qualify the resource
list as the three-language option. This is the remaining consistency detail from
finding 4, not a proposal to expand or reduce the product goal. The integration
summary at lines 225-230 should not imply this detail has already been reconciled.

No additional substantive contract concern was identified in this short reread.
Six findings are addressed in the revised text; finding 4 is substantially
addressed with the narrow chosen-set correction remaining. “Addressed” describes
proposal wording only, not tested behavior or a source-review PASS.

Supported languages and live safe-boundary behavior still await user confirmation
(lines 215-216). The generated accessor/bundle location, selected-language plural
adapter, consumer hooks, owner tracking, persistence and all implementation,
packaging, GUI/VoiceOver/restart/performance gates remain future verification
obligations. This appendix grants no user/code approval, authorizes no
implementation and claims no runtime or reference parity. Only this report was
appended; the proposal and other agents' files were preserved.

## Parent Main correction after advisory close (2026-10-14)

Main corrected the two remaining chosen-language-set phrases: resources now include
ja only when the three-language option is approved, and mounted-control verification
covers every approved supported language. This is Main's documentation correction,
not a new independent reviewer verdict. Earlier review/fingerprints remain historical;
no implementation or runtime gate is closed by these corrections.
