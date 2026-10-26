# Interface Language — Runtime and Settings Consumer Integration

Status: IN_PROGRESS, 2026-10-14. Approved contract INTERFACE_LANGUAGE_SPEC.
Baseline2236/0,362fingerprints/r2 foundation candidate retained. Previous goal turn
made implementation/test/resource evidence progress. Goal tool freshly reports
ACTIVE; prior blocked-history remains historical. No need to reconfirm languages.

## Wave ownership / boundaries

Main owns AppDelegate startup, language settings tab/controller integration,
readiness/real interaction release hooks, search/chrome and runtime integration
tests. Resource worker owns new settings vocabulary/translations/templates and
module coverage tests. Consumer worker owns only Appearance/Management/Sources
views and new relabel-preservation tests. Three total, disjoint writes; only Main
runs Swift after source publication/freeze. Chief workflow is waived by user.

No referenceLaunchBetter/Buho/evidence/assets reads, app/nativeGUI launch/process
stop/install/commit/sign/publish. Preserve dirty tree/history/candidates. Existing
Library/capacity proposals unconfirmed; language approval does not approve them.
English source/docs and independently authored Chinese/English/Japanese product
copy; no app name/alias/folder/query/suite/selector/key-code rewriting.

## Required integration and evidence

Startup uses profile-specific language store before constructing views. Language
Apply acknowledges accepted preference first and requests a safe next-turn update;
real input/editor/menu/sheet owners postpone it without cancelling drafts. Preserve
all old readiness callbacks and coalesce release retries even with no new input.
Settings relabeling retains selected record/root/tab/alias/appearance/source drafts,
operation generations and typed semantic notices. No icon/catalog/layout writes
from text-only changes; no resource lookup/formatting in frame callbacks.

Translate all shipping groups incrementally; this wave does not silently certify
unhandled activation/pager/folder/menu/alert consumers. Record exact coverage gaps
before closeout. Source review/focused/full/build/resource hashes/unique candidate
remain required; GUI/VoiceOver/real restart/physicalAB separate, never inferred.

## Published source / runtime integration checkpoint

Erdos resource vocabulary71static settingskeys+counttemplates is frozen; required
schema97keys, all3resources and strictcoverage/signature tests expanded. Gauss
published3real consumer views+17native preservation tests, all63requestedkeys,
typed retained feedback/watch/load states and sources busy/panel release hooks.
Both closed. Main passes resolved snapshot into view/controller construction and
removes redundant default snapshots before explicit initialization.

Actual startup/profile-safe store, Language settings tab and read-only/apply/
latest-presentation chain are wired. Real process-local menu leases and text/sheet/
window release events, existing Core/pin/helddrag/title/folder/Quit guards, recording
and source panel/busy hooks postpone language with no edit cancellation. Namespace
retry epochs reject stale replacements. Search/main/status/menu/chrome text consumes
snapshot; ordinary locale relabel never invokes data reload. Actual close resets
only unaccepted language draft; accepted queued language is shown truthfully.

Remaining activation/service/shortcut/folder/pager/AX/app-action/alert copy remains
explicitly incomplete. No whole-interface PASS. First compile/focused gate pending;
MainonlySwift, no application/nativeGUI/control/install/commit actions.

## Initial focused process crash / bounded constructor isolation

First focused run compiled but terminated at an existing asyncSources test with
'freed pointer was not the last allocation'; no final suite PASS. Isolated exact
same test reproduces signal6 (source-crash-repro.log). Main tests one minimal
hypothesis: an actor-isolated override-convenience NSView initializer ABI path.
AppSources now exposes two designated initializers sharing buildContent, preserving
resource/draft/operation/target semantics. Exact before-bytes saved, no unrelated
code reverted. Source constructor A/B and reverse check pending, no root cause
or successful repair presumed from an unexecuted hypothesis.

## Constructor hypothesis refuted

Designated-initializer B still reproduces the same signal6/freed-pointer abort in
an isolated test after21.23sbuild. No constructor causality claimed. Restored exact
saved pre-experiment AppSources bytes, preserving all unrelated code. Need actual
crash stack/root isolation; no rerun-green acceptance or weakened tests.

## Concrete crash precursor / bounds repair

LLDB exact test run reports an AppKit NSMenu.itemAtIndex assertion before the
secondary 'freed pointer' abort. Source trace: AppSources constructor calls relabel
before reload populates rootsPopup; relabel calls item(at:0) while count0. Optional
chaining guards nil returned values, not this Objective-C index precondition.
Main adds an explicit count>0 guard, preserving exact restored constructor bytes
otherwise. Existing async reproduction rerun pending; no Swift runtime/toolchain
root claim. Generic official Swift allocator issues were researched but did not
prove this local cause or justify a compiler migration. Actual trace is stronger.

## First crash clearance / owner review repairs

With only the empty-menu bounds guard, the exact previously aborting async test
passes1/0 at12:11:03.765JST0.090s; original signal6/LLDB assertion and refuted
constructor logs retained. Broad focused/full and further constructor regressions
still required; generic Swift allocator release notes were not local causality.

Pasteur found P1 reopen reload/draft/recording loss and P2 stale old-coordinator
routing into a new namespace. Main adds a non-presenting settings preparation seam,
production-only draft-preserving reentry after first configuration and accepted-
language-only refresh; standalone legacy reload default preserved. No business
reload/cancel solelyforlocale reentry. Obsolete language coordinators invalidate
before new persistence/dispatch, accepted bytes retained; epoch guard applies to
coordinator/readiness/discard callbacks. New regression tests/rereview pending.

## Runtime regression sources / initial fixture compile correction

Main authored13 runtime/constructor/native-tab/apply/Core-frame/menu-count/source-
busy/marked-text/namespace/teardown/reentry/draft/search/status tests. None orders
or activates test windows; preparation exercises actual controller graph. Initial
r2 compile rejected a nonexistent shortcut preset in a fixture (0 executed); corrected
to existingcontrolCommandSpace, preservingdraft assertions. R3 execution pending.
Othernew17consumer +resource tests are also pending, no wholeinterface/GUI verdict.

## First broad executed gate / remaining input regressions

R3 focused106/0 at12:19:42.501JST28.347s, including actual runtime13methods and
all17consumer/source-preservation tests. No crash or weakened assertions. Main adds
two more actual graph regressions: held grid cell pointer defers locale with zero
new icon requests/revision/binding changes; recording survives reentry and stops
only on actual close, then releases queued locale. R4/full/reviews pending.

## R4 fixture encapsulation correction

R4 compiled no tests: new fixture teardown attempted setting the deliberately
private-set dragCoordinator. Removed only the illegal nil assignment; retained
actual teardown and all pointer/binding/icon/request assertions. Public/internal
production visibility unchanged. R5 execution pending.

## R5 recording fixture / retained-controller replacement follow-up

R5 ran108methods/3assertfailures, all newRecording test: recordaction correctly
requires enabledshortcut, fixtureleftitOff. Main now clicksactualEnable control,
assertsenabled andrecordbuttonenabled beforepressingRecord; preservestrue recording/
localequeue/reentry assertions, no productionguardremoved.

Reviewer F3: reentry afternamespace install clears oldlanguagebindings but skip-
configuration path left retainedwindowunbound. Main refresh path uses retained
controller getter and configureLanguageSettings only (no otherdraftreload), rebinds
new namespace ifneeded and preserves existinglanguage draft otherwise. Added actual
prepare/reinstall/prepare/controlApply regression with retainedalias and newstore-only
write assertions. R6/full/rereview pending. OriginalFAILs retained.

## Executed runtime focus and bounded source closeout

R6 focused109/0 at12:29:35.948JST34.306s, including16actualruntime graph tests,
17consumer tests,97-key resourcecoverage andexistingselectedregressions. Source owner
F1-F5 closed withinboundedruntime scope; consumer/resource re-review explicitly
corrects missed P1 emptymenu andclearscountguard. Both reviewers closed, allhelpers
done. No physicalGUI/VoiceOver/restart/windowlayout/remainingtranslationPASS inferred.
Source snapshot captured before mandatory full/build/package gate.

## Coverage ledger / diagnosis evidence limitation

LANGUAGE_INTEGRATION_COVERAGE.md enumerates each shipping group as integrated or
notyetconverted, preservingall207inventoryscope andfullgoal. Current97requiredkeys
are notproof of207sitestranslated. Fullcurrenttree gate remains running.

Generic Swift allocator issue context was checked against primary official Swift
release notes (https://forums.swift.org/t/announcing-swift-6-3-1/86080), but no
compiler migration or generic-runtime causality was inferred. LocalAppKit empty-
menu precondition + exactboundsfix regression is the actual useful diagnosis.
LLDBtest diagnostics remain local and refer only to synthetic fixtures/source.

## Full-r1 contract fixture update

Full-r1 executed2282methods/1assertfailure at12:33:13.095JST36.441s. Only old
AppearancePreferences test still required4tabs, contrarytoapproved fifthLanguage
tab. Main updates exactcount5, addsactualLanguageViewidentityatindex4, retaining
allpriorSources/Appearanceidentity andunshownwindow assertions. No runtimefailure
masked.367-inputr2 snapshotcaptured; full-r2/build/resource gates pending.

## Final current-input full-suite gate

Full-r2 passed2282/0 at12:36:41.395JST42.878s.367frozeninputs; source-only reports
boundedclear, runtime109/0 andall old tests executed. Debug/Release unique language-
settings-runtime-r1 candidate now building, no candidate/hash/smoke result presumed.
Allhelpersclosed; no app launched/installed or production preferences touched.
Code coverage remains currentwave only, rest of interface ledger explicitly pending.

## Current wave code closeout

DebugRelease22.60sapp+0.54sprobe passed; runtime candidate language-settings-runtime-
r1 exe SHA0d9df268bf667295f3443e99396dc54b5504468896443f5a6e2e1ce618efdce0.
367postbuild hashes matched; resource manifestverified; strictpackaged3languages/
97keys+signatures andbothnegativegates passed. Allhelpers/jobs complete. Visible
LANGUAGE_RUNTIME_CODE_CHECKPOINT.md andcoverage ledger define completedscope and
remainingtranslations. No wholelanguage/product/GUI/physical/restartPASS, noapp
launch/install/commit/sign/publish/processstop. Fullgoal ACTIVE andincomplete;
previous/current goal turns made substantialimplementation/evidence progress.
