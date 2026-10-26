# Language status and notice source review

Date: 2026-10-14 (Asia/Tokyo).
Verdict: **FAIL — bounded source defects remain; no execution verdict.**
Reviewer writable scope: this report only. No implementation, resource, test,
workflow-state or memory edits; no builds, test execution, apps, process control,
reference-tree access, agents or commits.

## Contract and evidence boundary

Read `/Users/mac/.codex/RTK.md`, project `AGENTS.md`, the approved
`Docs/INTERFACE_LANGUAGE_SPEC.md`, and
`Workflow/stage-summaries/2026-10-14-language-status-menus.md`.
Shell inspection after reading RTK used `rtk` prefixes. Main owns the later
freeze/build/test/resource pipeline. Its unfinished integration tests/resources
are not reported as failures, and earlier execution summaries are not adopted
as evidence for these changes.

Reviewed the frozen status view/key/new status tests, Main's status mounting,
served-state routing and callbacks, material/reset paths, notice builders/keys,
alias/assignment/management sheet presentation, retained workspace notice and
Quit protection. Read only the local production dependencies needed to trace
those paths. The menu reviewer independently owns the menu audit.

AppDelegate changed during this read-only review: the initial Quit source had
no lease; a later read contained a `.quit` lease and completion gate. This is
recorded below without erasing the initial observation. Findings cite the
source read with that repair present. This report is not a certification of a
globally frozen tree or any subsequent edits.

## Initial findings

### F1 — [P2] Clearing a committed no-results search leaves the mounted notice stale

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:759-761` and
`:775-777`.

**Evidence / trigger:** Ordinary idle search input and Escape/blank-click clear
run through `AppSearchController.commitIfIdle()` (`:129-148`, `:175-180`,
`:236-247`) and the production `pendingCommitter`. A query-only commit invokes
`onSearchResultCommitted`, not `onPresentationUpdate`
(`AppGridSearchPresentationController.swift:90-102`). The installed callback
only calls `reloadCurrentPresentation()`; it never schedules catalog status.
Searching to zero pages can incidentally schedule status through Core's
cancelled/idle callbacks. Clearing that query restores positive pages while
Core remains idle: `PagingCore.swift:338-390` emits no state transition in the
positive-count idle branch. `PagingSurface.swift:751-759` only calls the page
navigation callback, installed to refresh page dots at `AppDelegate.swift:2643`.
Page-dot refresh does not schedule catalog status (`:2673-2681`). Consequently
the provider is ready again while the mounted overlay can continue showing
“No applications match the search” until an unrelated refresh, paging idle
boundary or language change occurs.

**Likely root cause:** Status scheduling was added to catalog/general idle
commit routes, but omitted from the independent query-only production callback.

**Recommended solution:** Schedule the existing coalesced status refresh after
every committed search-result presentation. Preserve served-query precedence
and keep formatting outside the synchronous callback.

**Affected scope / regression risks:** Search input, clear/Escape and blank-click
exit. A repair must not consult the pending query or force catalog/revision work.
Main should exercise the real installed query-only route, including zero-to-
positive pages, after freeze. Confidence: high; source trace, not executed.

### F2 — [P2] The production compact refreshing chip clips even one line of text

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:143-149`;
`Sources/AppGridUI/AppGridStatusView.swift:154-168`.

**Evidence / trigger:** With served content and `.refreshing`, Main gives the
status view a height of 56. The view subtracts two 8-point insets, leaving 40;
the busy spinner consumes 20 plus a 10-point gap, leaving **10 points** for
the text label. Its font is 15 points (`AppGridStatusView.swift:35`). The layout
then caps the measured label height at 10, so the actual shipped refreshing
label is vertically clipped even when its width is sufficient for one line.
Narrower widths require wrapping and are worse. The new view tests check
containment but do not supply Main's actual compact mounted frame.

**Likely root cause:** The compact host height was chosen without accounting
for the view's vertical spinner/text stack and insets.

**Recommended solution:** Give the chip enough height for its measured text and
busy stack, or use a compact arrangement that reserves at least the measured
line height. Keep grid/layout parameters and Core behavior unchanged.

**Affected scope / regression risks:** Background refresh with nonempty served
content, all languages. Verify the actual mounted compact chip, not only that
child rectangles fit its bounds. Confidence: high; deterministic source geometry.

### F3 — [P2] A replaced sheet host does not invalidate the old success callback

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:2567-2577`;
alias consumer `:2543-2548`.

**Evidence / trigger:** `presentApplicationSheet` guards completion by final
teardown and `languageGeneration` only. It neither retains/checks the original
host identity against the current launcher window nor has a window/sheet
replacement generation. If an alias sheet's old window is replaced while the
language owner, management coordinator and catalog revision remain unchanged,
its delayed first-button completion still passes these guards and calls
`setAppAlias(field.stringValue, for: record)`. The alias-specific guards do not
check the host either. Replacing `window` alone does not increment the captured
language epoch. This violates the requested obsolete-window completion boundary.

**Likely root cause:** The language namespace epoch is being used as the sheet
lifecycle epoch, although window replacement is an independent lifecycle event.

**Recommended solution:** Bind each sheet completion to the actual originating
host/presentation generation, invalidate it on replacement, and still release
its original lease exactly once. A late obsolete response must not apply edits.

**Affected scope / regression risks:** Alias edits and the shared application
sheet helper. Preserve literal field content on valid success; cancellation,
replacement and teardown must release ownership without applying an edit.
Confidence: high for the missing source guard; replacement was not executed.

### F4 — [P2] Settings-failure alerts and the source picker still bypass actual modal leases

**Location:** `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:897-904`;
`Sources/PagingPrototypeApp/AppSourcesSettingsView.swift:157-169`;
Main binding `Sources/PagingPrototypeApp/AppDelegate.swift:2181-2188`.

**Evidence:** Both production presentation paths invoke native presentation
directly. Settings failure acquires no `.modal` token before either
`beginSheetModal` or `runModal`; source selection records `openPanel`/`busy`
but acquires no token before `beginSheetModal`. Main supplies readiness-change
callbacks only, with no acquisition/release callback. The process observers
acquire menu tokens, not modal tokens
(`LanguageRuntimeObservers.swift:17-33`). Thus these actual presentation paths
do not satisfy the approved acquire-before-presentation/release-on-all-outcomes
contract, even after alias/management/assignment and Quit receive leases.

**Likely root cause:** These earlier consumers retained boolean/AppKit readiness
checks rather than joining the instance-token ownership mechanism.

**Recommended solution:** Connect these native presentation paths to the same
actual lease mechanism, covering success, Cancel, replacement and teardown,
and final-release retry. Readiness checks remain useful as additional guards.

**Affected scope / regression risks:** Settings save-failure sheets/nested modal
alerts and the native source picker. Existing attached-sheet, modal-window and
`busy` checks protect ordinary flows; this finding does **not** assert a proved
mid-dialog rerender or lost data. It identifies a concrete source/approved-
contract gap in overlapping and lifecycle ownership. Confidence: high.

## Initial observation and subsequent source correction

**Initial observation Q1:** The first read of
`AppDelegate.swift:2904-2919` showed Quit presenting directly and completing
without a language ownership lease.

**Appended correction, 2026-10-14, later read in this review:**
`AppDelegate.swift:2909-2926` now acquires `.quit` before either presentation,
uses `ApplicationSheetCompletionGate`, and releases/retries in the completion
defer. Q1 is source-corrected and is **not** an active finding. This does not
resolve F4. No execution or cancellation test is claimed.

## Bounded positive source observations

- Status is mounted in the existing production root (`AppDelegate.swift:487`),
  with ready hidden by the view. `hitTest` always returns nil and responder
  acquisition is refused (`AppGridStatusView.swift:145-150`). White text, opaque
  reduced-transparency fill and a high-contrast white border are explicit.
- The status scheduler stages semantics on a weak, generation-checked next-main-
  turn callback. The view separately coalesces text/spinner/AX and invalidates
  queued work on teardown. Reinstall tears down/removes the old status view.
- `displayedCatalogStatus` uses served snapshot, committed `activeQuery` and
  served records. Pending query text does not manufacture no-results; refresh
  and failure are preserved. The startup nonbusy refresh callback commits at
  idle. Source inspection found no catalog/notice string formatting added by
  this status route on `advanceFrame` or its transitive production commit stack.
  This is not a measured zero-lookup/zero-format execution result.
- Equal-state locale relabel stages a new snapshot without changing status,
  query, names or catalog revisions. New status tests check retained native
  control identity, fallback, teardown and deferred rendering. Their synthetic
  `onAnimationFrame` callback test is not proof of all production commit paths.
- Alias/assignment/management use the current immutable snapshot and acquire
  `.modal` before native presentation. Their shared completion gate releases
  once on normal Cancel/success and rejects old language namespaces/final
  teardown; the remaining host-replacement gap is F3.
- Workspace notices retain `LayoutStoreFlushResult`, map the distinct protected,
  stale, over-limit and timeout outcomes to typed keys, and rerender current
  language without resetting visibility in the relabel method. Language-only
  relabel does not advance workspace persistence generations. Native geometry
  and complete visual visibility of long notice text remain unexecuted.
- Alias builder copies the alias verbatim; no translation is applied to draft
  content. Quit's first/default Return button remains Cancel Quit, only the
  second button approves quitting, and the workspace coordinator invalidates
  late decisions on cancellation/replacement. No new source path was found
  that treats the default Cancel response as approval to lose unsaved data.

## Source fingerprints at the later review checkpoint

SHA-256; fingerprints describe inspected source, not a binary/resource candidate.

| Path | SHA-256 |
| --- | --- |
| Sources/AppGridUI/AppGridStatusView.swift | 4724cbdb551a4960190f4d7cf6c7259c499a335603f6f3fe604374be1b2ed884 |
| Sources/LauncherLocalization/CatalogTextKey.swift | 65bffb92fa8340bdc2935cc7a3018531d46139e3c9d63c3ef7ad415c133d485a |
| Tests/AppGridUITests/StatusLanguageConsumersTests.swift | e14701e47e401e6703f1e2cd87ec2e503604c845797c22eb768d945c9ab56141 |
| Sources/PagingPrototypeApp/AppDelegate.swift | cc5679eb08bbe5a7242683b5c1ec580d378ed792c4e94516775440892510aaf7 |
| Sources/PagingPrototypeApp/LauncherNoticePresentation.swift | 92ca545c6c2f5f4f9b14bf793288450bcaac8419f37aaaa5106721a8331362cc |
| Sources/LauncherLocalization/NoticeTextKey.swift | d7767065c113dc2651bb949d443b02ddfffdaddacead92010be0670daa9de4fc |

## Handoff

Main owns repairs, the next freeze and execution gates. Preserve these initial
findings; append a separately evidenced repair review if the source changes.
There is no compile, XCTest, packaging, GUI/VoiceOver, restart or performance
PASS in this report. Only this report was authored by this reviewer.

## Appended latest-source review — Main's r1 freeze, 2026-10-14

Main reported the source/tests frozen, a source-files-r1 fingerprint manifest,
Focused-r1 running and 213 expected resource keys. Those are Main's reported
pipeline facts, not execution evidence collected by this reviewer. No pipeline
was invoked or inspected here. The named manifest was not located by the bounded
project filename search excluding `.build`; no manifest-match claim is made.
The directly inspected source hashes below were unchanged on repeat reads.

**Latest bounded verdict: FAIL; F1-F4 remain active. Q1 remains source-corrected.**
Initial findings and their original line numbers above are preserved. Updated
locations and assessment:

| Finding | Latest source location | Latest assessment |
| --- | --- | --- |
| F1 | AppDelegate.swift:751-753, 767-769 | Still only reloads the surface on query-only success. The new pure policy correctly reads committed `provider.activeQuery`, but does not schedule this missing update. |
| F2 | AppDelegate.swift:136-141; AppGridStatusView.swift:154-168 | Compact height remains 56; busy text capacity remains 10. White/dark material and resize routing do not correct this geometry. |
| F3 | AppDelegate.swift:2559-2569; alias consumer:2535-2540 | The success guard remains teardown plus language epoch; no originating-window identity or replacement generation is checked. |
| F4 | ActivationSettingsWindowController.swift:897-904; AppSourcesSettingsView.swift:157-169 | Both native paths still present without acquiring/releasing modal tokens. Their files match the earlier inspected hashes. |

### What the new source and test context establishes

- `CatalogStatusPresentation` is a pure semantic policy with no strings, IO or
  mutation. Main feeds it served snapshot/visibility, committed query and served
  results (`AppDelegate.swift:108-115`). This supports the pending-query boundary
  and retained refresh/failure precedence already noted positively.
- `LanguageStatusNoticeRuntimeTests.swift` contains 11 authored tests. The
  fixture mounts the actual status view and installs the shared production
  catalog/idle callbacks (`:25-32`). Its terminal-frame case stages a real pending
  catalog and reads render counts during the bounded advanceFrame loop. This
  improves the authored production frame-path coverage; no result is inferred.
- The two search status tests explicitly call Main's general
  `applyPendingAtIdleBoundary()` (`:65-66`, `:75-80`). That method always schedules
  status (`AppDelegate.swift:1250-1257`). The fixture does not construct the
  production AppSearchController or install the separate query-only callback
  from `AppDelegate.swift:751`. Therefore those tests do not exercise or disprove
  F1. This is the reason F1 remains a production source defect despite added
  mounted-root tests, not a separate missing-test finding.
- Status replacement/teardown, retained same-state language presentation,
  literal alias builder content, default Cancel Quit and retained typed workspace
  notice visibility are represented in the new test source. The pure refresh
  policy test does not mount the compact `.refreshing` frame or verify label
  height, so it does not address F2.
- The shared sheet helper actually acquires `.modal` before the injected/native
  presenter and releases once through its gate. The overlap/Cancel/duplicate
  test invokes this same helper with an injected callback that never orders a
  native sheet (`LanguageStatusNoticeRuntimeTests.swift:192-207`). This is valid
  ownership-seam coverage, with native presentation behavior still separate.
- The stale-epoch test replaces the language owner (`:209-220`), which explicitly
  tears down the old owner and empties its leases. It does not replace the sheet
  host while keeping the language epoch unchanged; F3 remains independent.
- Quit now acquires `.quit` and uses a one-shot completion gate before both
  native presentation alternatives (`AppDelegate.swift:2901-2918`). Cancel is
  still the first/default Return button and only the second response approves.
- Root status geometry runs through the deferred status callback and
  `layoutSearchField()` (`AppDelegate.swift:124-128`, `:1749-1752`), including
  `windowDidResize`/screen changes. Page-dot updates do not directly lay out
  status. This supports the frame-path geometry separation; it does not change
  the chip's calculated text capacity.
- The two new typed-resource tests inspect selected tables and safe fallback
  for catalog/menu/notice keys. They were read, not executed. The expected 213
  key/resource package assertion remains Main's gate.

### Latest directly inspected fingerprints

| Path | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppDelegate.swift | 3f21a2fe82cccd599843ef89118417eca1444358aa7d29cb298aa261fdeea8ef |
| Sources/PagingPrototypeApp/CatalogStatusPresentation.swift | cfa01b8e315cb54068b30458a43d493005b40fc6022b88a434a91d709cde9e6c |
| Tests/PagingUITests/LanguageStatusNoticeRuntimeTests.swift | e65bab8324e79da4a1fdde3f35b50e5c818d4d0d21dfc5574d024dbfd1797816 |
| Tests/LauncherLocalizationTests/StatusMenuNoticeLocalizedStringsTests.swift | 7f1efbc96a1fcf26f1af3e533531b8799788d225aeacacf8e961145169ca7dfe |
| Sources/AppGridUI/AppGridStatusView.swift | 4724cbdb551a4960190f4d7cf6c7259c499a335603f6f3fe604374be1b2ed884 |

No additional implementation defects are asserted from the running or
unexecuted test pipeline. The only authored change remains this report.

## Appended F1-F4 repair review — latest r3 source, 2026-10-14

**Latest verdict: SOURCE PASS for the bounded F1-F4 repairs.** No active concrete
finding remains in this repair review. This supersedes the active statuses in
the preceding r1 section; every initial finding and intermediate conclusion is
preserved above. This is not a build, focused/full XCTest, resource-package,
native presentation, GUI, restart or performance PASS.

Main reported focused-r3 running and two earlier compile-repair iterations.
Those reports are not adopted as verified execution results. This reviewer
only inspected the latest local source/test context and authored this append.

### F1 — source-corrected

`AppDelegate.swift:1243-1246` now installs the query-only callback in the shared
production installer: it reloads the surface and calls
`scheduleCatalogStatusRefresh()`. The earlier production-only assignment that
omitted scheduling is gone. The existing deferred scheduler and pure policy
still read committed `provider.activeQuery` and served results, so the repair
does not derive no-results from pending query input or format status text on
the synchronous search/idle/frame stack.

`LanguageStatusNoticeRuntimeTests.swift:225-239` now invokes the assembly's
query-only commit twice, first to no-results and then to a cleared ready
presentation, checks the mounted status becomes hidden, and preserves the
catalog revision. It does not force `host.applyPendingAtIdleBoundary()` for
this repair test. The fixture installs the same shared production callback.
This closes the source-route gap identified in F1; the test was not executed here.

### F2 — source-corrected

`AppGridStatusView.swift:138-143` calculates the required height from the
already-rendered native label at the actual available width, with at least
20 points of text, 16 points of insets and 30 points for a busy spinner/gap.
`AppDelegate.swift:147-157` uses that height for the compact chip. It no longer
allocates a fixed 56-point busy chip with only 10 points of text capacity.

The view's deferred presentation callback invokes `onPresentationApplied`
after committing text, AX and spinner (`AppGridStatusView.swift:117-134`);
Main's weak callback relayouts the current root (`AppDelegate.swift:115`).
Teardown clears the callback and invalidates the view's pending generation
(`AppGridStatusView.swift:91-101`; `AppDelegate.swift:160-167`). Thus same-state
language expansion is remeasured after the new text is actually installed.
The measurement method does not load/format localized strings. No Core or grid
layout parameters were changed by this repair.

`LanguageStatusNoticeRuntimeTests.swift:241-254` checks the actual mounted
busy chip in all three languages, comparing the label's allocated height with
the native cell's measured height and the root's reserved height. This directly
targets the initial clipping arithmetic rather than mere child containment.
Actual rendering and the test result remain Main's gates.

### F3 — source-corrected

`AppDelegate.swift:2576-2591` requires the intended current window at entry,
captures its content root and language epoch, then checks both originating
window identity and unchanged content-root identity before applying completion.
The one-shot gate runs first; the release/retry defer still runs for obsolete
window/root, stale epoch and final-teardown responses. A stale success cannot
reach the alias edit callback, and its original owner is released once.

`LanguageStatusNoticeRuntimeTests.swift:257-269` now replaces only the window,
then invokes the old success callback and checks zero edit callbacks and no
remaining lease. The overlap/Cancel/duplicate and namespace replacement tests
also retain the real shared helper, with injected presenters that do not order
UI. The replacement response is authored coverage, not a native runtime result.

### F4 — source-corrected

Main binds both settings consumers to `acquireApplicationModalLease()`
(`AppDelegate.swift:2191-2192`). That acquisition method captures the actual
language owner and returns an idempotent release closure with final-release
retry (`:91-99`). It does not substitute the additional test readiness hook.

Settings failure now acquires before invoking its presenter and releases once
on completion (`ActivationSettingsWindowController.swift:904-914`). The default
presenter still calls native `beginSheetModal` or `runModal` (`:200-203`); the
injection changes only the platform presentation seam used in unshown tests.

The source picker acquires before its native presenter and stores an idempotent
release closure (`AppSourcesSettingsView.swift:164-184`). Its completion gate
rejects duplicates; the operation-generation guard prevents a cancelled/reloaded
picker from applying a late URL; release executes even when that guard rejects.
`cancelPendingOperations()` advances the generation and explicitly releases
before cancelling/clearing the panel (`:123-129`). `reload` and `hideSettings`
already use that cancellation path. Main's language-owner teardown empties
ownership and disables its queued presentation, so a retained old release does
not revive a torn-down owner. The repair does not translate or overwrite draft
root paths or alias content.

`LanguageStatusNoticeRuntimeTests.swift:271-294` uses the actual source Add
button and settings failure presentation method with injected native presenters.
It stages overlapping leases, a pending language request, duplicate alert
completion, explicit picker cancellation and stale/duplicate picker callbacks.
The pending language stays behind the remaining picker lease and then applies
after release in the authored assertions. No native window/sheet is ordered by
those injected presenters, and no test result is inferred by this review.

### Other bounded checks and latest fingerprints

- `teardownCatalogStatus()` is now inside the existing
  `MainActor.assumeIsolated` teardown block (`AppDelegate.swift:3047-3049`).
  The nested test Fixture is explicitly `@MainActor`, and the repaired query
  calls use `AppSearchQuery(raw:)`. These source changes correspond to the
  reported compiler issues; compilation was not performed here.
- Quit retains the previously corrected `.quit` lease/one-shot completion and
  default Cancel semantics. The inert status hit-testing/material behavior,
  pure committed-query policy, notice typed-outcome rendering and literal alias
  builder remain intact in the inspected repair context.

SHA-256 of directly inspected latest sources (not build/candidate fingerprints):

| Path | SHA-256 |
| --- | --- |
| Sources/AppGridUI/AppGridStatusView.swift | c05af008285a8559bf89ffa70358045d13de53d61b0b1a20e2ff10d39b0cb7c8 |
| Sources/PagingPrototypeApp/AppDelegate.swift | fc5bea4e45eed3c1f7ce7975cfbb1fcc1cb7187daf0748c83a0266ec0330ffa1 |
| Sources/PagingPrototypeApp/CatalogStatusPresentation.swift | cfa01b8e315cb54068b30458a43d493005b40fc6022b88a434a91d709cde9e6c |
| Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift | d91b71081484506b5b3384b985d379a56dc8de73afa71b1d0060ad7481a75b68 |
| Sources/PagingPrototypeApp/AppSourcesSettingsView.swift | 4ebf81cebc1e81337c908ae586cdfb8e2014ede98a1d976d4b10b5ff13b42418 |
| Tests/PagingUITests/LanguageStatusNoticeRuntimeTests.swift | fa3952fc7952b6cc5a706e64461d2c2c1614bf594c767901b8098226f5e70f50 |

Main owns the freeze and remaining execution/integration gates. No implementation,
tests, resources, workflow state or memory were changed by this reviewer; only
this report was appended. No builds/tests/apps/process control/commits occurred.
