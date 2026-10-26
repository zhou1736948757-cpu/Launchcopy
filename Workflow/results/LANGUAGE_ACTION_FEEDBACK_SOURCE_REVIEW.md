# Language action feedback: independent source review

Date: 2026-10-14. Verdict: **FAIL — three P2 integration defects**.
This is a bounded source review, not full parity, native GUI, VoiceOver, restart,
packaging or physical frame-performance acceptance.

## Scope and evidence boundary

Read `/Users/mac/.codex/RTK.md`, project `AGENTS.md`,
`Docs/INTERFACE_LANGUAGE_SPEC.md`, `Docs/LAUNCHBETTER_PARITY_SPEC.md` and
`Workflow/stage-summaries/2026-10-14-language-action-feedback.md`.
The existing project uses SwiftPM, AppKit, a shared validated launch controller,
catalog/grid/paging modules and immutable localization snapshots. The old Chief
workflow was explicitly waived. No helpers were dispatched; Main + reviewer +
audit remains within the authorized ceiling of three.

Reviewed the actual notice, typed keys, neutral outcome policy, AppDelegate
installation/routing/material/language/hide/teardown hooks, 16 notice tests,
10 application runtime tests and the actual-resource API tests. Adjacent launch,
keyboard, folder, menu and suspension source was read only to trace these hooks.
Main's login authored-failure repair is outside this review; no duplicate work.

Main reported an r1 source freeze and focused-r1 execution of 56 tests with two
failures, followed by focused-r2 **56 executed / zero failures** after test-only
repairs. These are Main-supplied results, not independently executed or log-verified
here. Focused-r3 was still running at the last update. A green focused suite does
not cover the three cases below. No tests, Swift execution, builds, app launches,
process control, commits, source edits, global memory or reference implementation/
asset inspection were performed. The only authored file is this report.

The production files were rehashed and remained unchanged across the review.
Main's test repairs were reread; the current source uses `refreshPresentation()`
and real renderer/cell/menu acquisition, and moves the weak-reference assertion
outside an autoreleasepool with a deferred-main-turn drain. This report identifies
its precise inspected bytes below, without claiming a comparison against Main's
391-entry freeze manifest.

## Findings

### F1 — [P2] Old launch/reveal callbacks survive root or language-domain replacement

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:143–152`, with
`106–123`, `2213–2235`, `2335–2342` and `2540–2542`.

**Evidence / repeat case:** Retain `launch.onLaunchAttempt`, keep the same launch
controller and assembly, and replace the overlay with `installActionFeedback(in:
newRoot)`. Invoke the retained callback with `.failedToLaunch` after replacement.
The identity guards still pass, and `showActionFeedback` resolves the *current*
view and language snapshot, creating a fresh six-second error in the new root.
Independently, reinstall language preferences using a different injected store
while retaining controller/assembly, then replay the old callback: changing
`languageGeneration` and clearing the notice does not invalidate that callback.
Replaying `.launched` can also clear a newer notice and reach the current
activation composition's hide path. The retained menu reveal callback has only
an assembly identity guard, so same-assembly root/domain replacement likewise
does not invalidate its ability to notify the new root.

**Likely root cause:** Controller/assembly identity protects controller replacement
but is not a presentation-root or language-domain generation. Notice teardown
invalidates the old view's jobs, not upstream callbacks that resolve the new view.

**Recommended solution:** Bind callbacks to an explicit owner generation that is
invalidated on root/domain replacement and rebind current callbacks for genuine
new actions. Do not invalidate normal live-language relabeling. Preserve the
shared validation path and genuine success-hide behavior. Production installs
the launch callback before the root overlay (`805` versus root construction at
`576`), so a repair must account for that order rather than capturing a nil view
and disabling all future feedback.

**Test gap:** `ApplicationActionFeedbackRuntimeTests.swift:127–145` clears pending
view work and replaces the *controller*. Despite its name, the obsolete-callback
test does not replace a root or language domain while retaining the controller.
Add the two independent replay cases, plus an old success callback against a
newer error and a genuine new failure that must still display.

**Affected scope / regression risks:** AppDelegate callback binding and lifecycle
tests; overly broad invalidation could silence current actions or break success
hiding. **Confidence: high for source-replay behavior; no asynchronous OS callback
or observed live-device occurrence is claimed.**

### F2 — [P2] Session/sleep suspension hides the launcher without clearing feedback

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:2847–2856`.

**Evidence / repeat case:** Produce a real failed launch, then call the installed
`launcherDidHideHandler()` before six seconds elapse. After deferred work drains,
the notice still retains its reason/deadline, unlike
`prepareTransientCancellationForHide()` at `2825–2826`. Test this both after
presentation and before the first queued presentation: the pending presentation
can still apply while the ancestor window is hidden. Showing the launcher again
within the original deadline exposes the old error without a new failed action.

This is a genuine production route: `ActivationComposition.swift:299–321` sends
sleep/session resignation directly to suspension without `onPrepareHide`;
`LauncherWindowController.swift:271–277` orders the window out and invokes
`onLauncherDidHide`. The AppDelegate handler explicitly covers that bypass but
omits notice clearing. Hiding a window does not detach its notice view.

**Likely root cause:** Cleanup was added only to the normal preparation hook,
not the callback shared by actual order-out/suspension paths.

**Recommended solution:** Clear transient action feedback in the actual-hide
handler as well. Keep the resident services alive and preserve accepted language
preferences. Do not tear down the whole launcher to clear a message.

**Test gap:** `ApplicationActionFeedbackRuntimeTests.swift:176–182` exercises
normal preparation only. Add actual-hide handler cases for queued and displayed
feedback, followed by a reopen without a new error and a fresh genuine failure.

**Affected scope / regression risks:** AppDelegate hide cleanup; clearing must
remain idempotent with normal hide preparation and permit later errors.
**Confidence: high; inferred from the complete suspension call chain, not GUI
execution.**

### F3 — [P2] A subsequently opened folder mounts above a still-active notice

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:159–160`, with
`1702–1706`.

**Evidence / repeat case:** Show a launch failure while no folder is mounted,
then open a folder before the six-second deadline. `showActionFeedback` elevates
the notice only when the error arrives. `refreshFolderOverlay` subsequently uses
plain `host.addSubview(folderOverlay)` and fills the entire root bounds, placing
the folder above that notice. With Reduce Transparency enabled, the folder's
root backdrop is opaque black (`Sources/AppGridUI/FolderOverlayView.swift:333–349`)
and completely covers the notice. Without it, the folder dims the notice beneath
its backdrop. Relabel/material/sizing callbacks only lay out the notice and do
not restore the required stacking. A second real failure elevates it again,
confirming that ordering depends on the most recent mount rather than the active
presentation contract.

**Likely root cause:** Z-order is repaired on error receipt but not on later
folder attachment. The notice's deadline and semantic state remain active while
its pixels are covered.

**Recommended solution:** Preserve the passive notice above folder visuals on
folder attachment, without calling `show` again, renewing the deadline, changing
focus/hit testing or altering grid metrics. Keep the notice below the search
field geometrically.

**Test gap:** The application fixture has no folder overlay. Add a source-backed
mount test that shows an error, opens a real folder, checks sibling ordering in
both material modes, and checks unchanged reason/deadline and nil notice hit test.

**Affected scope / regression risks:** AppDelegate overlay attachment; preserve
folder input capture, drag visuals and frozen exit behavior. **Confidence: high
for hierarchy and opaque-backdrop behavior; exact native pixels remain untested.**

## Clock, ownership and route assessment

| Contract | Source assessment and limits |
| --- | --- |
| Six-second monotonic deadline | `ActionFeedbackNoticeView.swift:48–51, 88–95` uses Dispatch uptime and sets the deadline at receipt. Only a new `show` resets it. |
| Late / duplicate / early timers | `195–239, 276–277` gates each delivery with a ticket, queues timer presentation, rechecks expiry before formatting, and rearms remaining duration after early delivery. Cancelled/duplicate callbacks cannot restore an old reason. No separate timer defect identified. |
| Latest wins / locale / material / resize | Semantic state is staged and one presentation job coalesces it. Relabel, material and sizing do not mutate the deadline. Clear invalidates both jobs; teardown is terminal. `99–243` of the notice tests authors the adversarial timer cases. |
| Deferred formatting / AX / material / measurement | `232–279` applies these in scheduled presentation; layout/height APIs request cached/deferred measurement. Constructor creates retained AppKit objects without constructing resources. Teardown immediately clears presentation under its explicitly outside-frame contract. Notice frame tests cover staged work and an actual `advanceFrame` callback; they do not instrument the entire Main integration stack or prove physical FPS. |
| Pointer / keyboard / folder / context launch | Existing routes converge on `AppLaunchController.handleCell`: AppDelegate `809–824`, `909–910`, `947`, `1249–1260`, `1630–1642`, `2530`; pointer hit testing remains in the shared controller. No additional launch API or validation bypass was found in this slice. New runtime tests invoke genuine `handleCell` with a fake launcher and existing synthetic bundle, not the OS. They do not drive every Main pointer/key/folder/context-launch entry while observing the notice. |
| No binding / success | Neutral policy returns no reason for no binding; routing neither shows nor clears it. Genuine success clears feedback and still calls existing success-hide handling. The fixture verifies notice clearing, not an actual hidden launcher window. F1 concerns stale callbacks, not current successful actions. |
| Finder | Production uses void `activateFileViewerSelecting`; the injectable requester is void and the outcome is `.requested`, with no claim of observed Finder presentation. Current canonical identity/URL, hidden state and file existence are checked before requesting. Genuine menu action still preserves its original binding guards; invalid retained bindings return before downstream callbacks, and direct handler tests are not evidence of feedback from those silent menu rejections. |
| Passive placement / privacy | Notice hit test returns nil, rejects first responder and has one noneditable/nonselectable label. Layout places it below search; error receipt elevates it over currently mounted folders, but F3 breaks later attachment. Typed reasons carry no names, paths, queries or native errors; added census data is neutral outcome data. |
| Actual resource API coverage | `LocalizedStrings.swift:70–71` calls typed render plus key fallback. `LocalizationResources.swift:91,114,127,143` includes all six action keys with zero placeholders. `ActionFeedbackLocalizedStringsTests.swift:5–20` exercises every key in en/zh-Hans/ja through the real accessor and actual bundle-table bytes, plus absent-resource fallback. This exceeds schema-only coverage. Notice translation fixtures differ from some shipping translations; their results alone are not shipping-table evidence. Exact packaged-app loading is a separate gate. |

### Deallocation failure follow-up

No source retain cycle was identified. The view owns clock/scheduler closures;
the fixture closures retain `NoticeTestTime`. That scheduler retains jobs, but
presentation and expiry actions capture the view weakly (`199`, `223`), and its
cancellation closure captures time weakly. Production dispatch work wraps the
same weak-view actions; no strong path back to the view is apparent. Main's
presentation callback captures AppDelegate weakly (`114`). Teardown invalidates
both tickets, cancels and releases both cancellation handles, clears the snapshot
and callback, and empties text/AX state (`118–127`). Temporary strong `self` during
an executing callback ends with that callback and is not a cycle.

The original immediate weak assertion inside synchronous `TestMain.run` cannot
establish a leak. The current test (`245–275`) keeps terminal-state and counter
assertions, exits the autoreleasepool, drains deferred turns, then asserts weak
release. Main reports r2 passing after this repair; AppKit/AX temporary ownership
is a plausible explanation, not a proved retention cause. A stronger countertest
can keep the fake scheduler alive outside that pool, retain its cancelled jobs,
then replay them after release: weak view must remain nil and the external
presentation counter must remain unchanged. No ownership patch is justified by
the immediate weak observation alone.

## Inspected file fingerprints (SHA-256)

```text
c720e57d086df696e8950837bdd1a8a2835cebfa497dcb80472806de9a3d8576  Sources/PagingPrototypeApp/AppDelegate.swift
83f5a44a85a1897dece236b76fe7900a7882b604d7c98dc238144008d28a51cc  Sources/PagingPrototypeApp/ActionFeedbackNoticeView.swift
9355d59757adc5a9666fd4f1da3cd7dd55b1961ae610f0cd92344ae59881ff11  Sources/PagingPrototypeApp/ApplicationActionFeedback.swift
a71bf5332a615f660d880676561f0b9eb9ded726fc8e9b8fec8b487171ee0cb9  Sources/LauncherLocalization/ActionFeedbackTextKey.swift
e0f0d742cbd230db39f61f1d1258aeb46a9dcb3c4a2972e63324f84077923b83  Tests/PagingUITests/ActionFeedbackNoticeTests.swift
34f7bd18d050193db33514846e4891a39904ce732e1b3863ac0ec25338e957d4  Tests/PagingUITests/ApplicationActionFeedbackRuntimeTests.swift
40c84d04013a8a298fd394eac38abb685a6d90358c151e3cfdab9ce11422a34c  Tests/LauncherLocalizationTests/ActionFeedbackLocalizedStringsTests.swift
922d205a5080cc30cae0bc2806a46965ceeb3388dbffcc9692f8b8f9c4d33028  Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings
cf07dcbd2437da03159c5839024999535490d26e8a4bf6ccc0c5df4e0b248824  Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings
ccb028368140698809add12e96e6f5f3c32150de2ecef4152805d6cb1097dff8  Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings
```

Main owns any repair, new freeze and serial regression execution. The three
findings remain open until their specific cases are repaired and reviewed. Native
GUI/VoiceOver, exact packaged resources, safe restart, >25ms causality and 120Hz
gates retain their existing unresolved status.

## Re-review after F1–F3 repairs — 2026-10-14

Current bounded verdict: **FAIL — F2 and F3 are repaired at the source level;
F1's original outcome/reveal replay paths are repaired, but one stale menu-launch
ingress remains unguarded.** This dated section supersedes the original open-item
status for the repaired paths; the original report and fingerprints remain
unchanged as history. Main reported focused-r5 running. No r5 execution result
was available during this review, and no reviewer tests/build/app execution was
performed. The only write remains this report.

### Repair assessment

| Finding | Current source and new regression coverage | Disposition |
| --- | --- | --- |
| F1: stale launch outcome / Finder callback | AppDelegate `73–74, 108–170` increments the root generation on teardown, captures root and language epochs in launch-result callbacks, retains the origin assembly weakly, and rebinds current routes after installing the new root. `2232–2264` also rebinds after replacing the language realm. `2563–2569` gives Finder callbacks both epoch checks. Ordinary `presentLanguage` relabeling does not increment these epochs or rebind routes. The initial launch callback can be installed before the root and is subsequently rebound, avoiding a permanently nil-view capture. Runtime tests `185–218` exercise same-controller root/realm replay, old-success preservation of a newer error, old Finder callback rejection and genuine new launch actions. | These specific replay paths are repaired; remaining menu-launch ingress is detailed below. |
| F2: actual-hide cleanup | AppDelegate `2874–2884` now clears the notice in the actual-hide callback, before other hide cleanup. Runtime test `220–234` invokes that production handler for queued and visible errors, checks cleared state, retained surface/preferences, and a fresh later failure. The suspension-to-handler call chain is unchanged. | Repaired at source level; execution acceptance belongs to Main's new run. |
| F3: subsequent folder mount | AppDelegate `1720–1728` inserts the real folder overlay below the existing notice when both share a host. It does not detach/reinsert the notice, call `show`, renew its deadline or change hit testing. Runtime test `236–263` uses real `installFolderWiring` and `openFolder`, inspects actual sibling ordering under both material policies, and checks the same reason/deadline and nil hit test. | Repaired at source level; exact pixels remain a native GUI gate. |

### F1 remaining case — [P2] Old context-menu launch callback enters the rebound current route

**Current location:** `Sources/PagingPrototypeApp/AppDelegate.swift:2553`, with
`145–150`, `155–170` and `1648–1660`.

**Evidence / repeat case:** Build a menu from the actual retained renderer cell,
retain its `AppContextMenuController` and `management.launch` item (or copy the
controller's `onLaunch` callback), and replace the root or reinstall the language
realm while keeping the same assembly and bound cell. Select the old launch item
through its real target/action. Its cell/token/revision/record guards still pass:
`AppContextMenuController.swift:74–82` checks no presentation-root or realm epoch.
The old `menus.onLaunch` closure has only `[weak self]` and calls the current
`launchMember(id)` without origin or epoch validation. That function uses the
current launch controller; its freshly rebound `onLaunchAttempt` has the *new*
epochs and accepts the outcome. With the fake launcher set to fail, an obsolete
menu action creates/renews the new root's notice. With it set to succeed, it can
clear a newer error and reach genuine success-hide handling. Copying and invoking
the old `onLaunch` callback reproduces the same source path without relying on
native menu-target retention. No OS execution or live occurrence is claimed.

**Likely root cause:** Epoch checks protect the launch *result callback* and the
Finder action callback, while the old menu's launch action can obtain a new result
callback by entering the current launch controller. Rebuilding menus does not
invalidate already retained closures/controllers.

**Recommended solution:** Apply the same origin-assembly/root/language checks to
the menu launch ingress before calling `launchMember`, and keep rebinding current
menus after root/realm installation. Preserve AppContextMenuController's original
binding validation, the shared AppLaunchController API and normal live-language
menu behavior; do not invoke an old result callback or weaken launch validation.

**Test gap:** New test `201–218` retains old `onReveal` and `onLaunchAttempt`, but
never old menu `onLaunch`. Extend the real renderer/cell/menu fixture with old
launch ingress replay after root and realm replacement. Assert zero additional
fake-launcher calls and unchanged new reason/deadline, then assert a freshly built
current launch menu still works. Also exercise the current Finder menu after
rebinding, including its void request seam; existing new realm coverage establishes
old reveal rejection but not fresh Finder dispatch after that replacement.

**Affected scope / regression risks:** The Main-owned menu-launch callback and
bounded lifecycle tests. Guarding only stale ingress must not silence current
context actions, ordinary live relabels or genuine success hiding.
**Confidence: high for the retained-callback source path.**

### Preserved invariants and current fingerprints

The notice, action key enum and neutral outcome policy hashes still match the
first review; no ownership or clock implementation patch was introduced. The
six-second monotonic/ticket/deferred-render analysis remains applicable, as do
nil hit testing, no focus acquisition, neutral feedback data, unchanged shared
launch validation and truthful void Finder `.requested` semantics. The notice
deallocation test and real-resource accessor tests also match the previously
reviewed bytes. The four new runtime cases make meaningful production-seam
assertions; their presence is not proof of execution.

Repeated hashes before and after source inspection agreed:

```text
c4bb595fbcd1db73fc7aa73923b34531c815f5e86fbb33083c076151191afb69  Sources/PagingPrototypeApp/AppDelegate.swift
9b037a7ad3ba1b129dc27c95042ccce7b2cc2182f3faf25ffe752fb0ad353778  Tests/PagingUITests/ApplicationActionFeedbackRuntimeTests.swift
83f5a44a85a1897dece236b76fe7900a7882b604d7c98dc238144008d28a51cc  Sources/PagingPrototypeApp/ActionFeedbackNoticeView.swift
9355d59757adc5a9666fd4f1da3cd7dd55b1961ae610f0cd92344ae59881ff11  Sources/PagingPrototypeApp/ApplicationActionFeedback.swift
a71bf5332a615f660d880676561f0b9eb9ded726fc8e9b8fec8b487171ee0cb9  Sources/LauncherLocalization/ActionFeedbackTextKey.swift
e0f0d742cbd230db39f61f1d1258aeb46a9dcb3c4a2972e63324f84077923b83  Tests/PagingUITests/ActionFeedbackNoticeTests.swift
40c84d04013a8a298fd394eac38abb685a6d90358c151e3cfdab9ce11422a34c  Tests/LauncherLocalizationTests/ActionFeedbackLocalizedStringsTests.swift
```

No new full-parity, GUI, VoiceOver, packaging, restart, causality or FPS acceptance
is asserted. Main owns the remaining ingress repair, new freeze and serial tests.

## Final F1 ingress re-review — 2026-10-14

Current bounded verdict: **PASS for the reviewed source repairs. F1, F2 and F3
have no remaining actionable source finding in this review.** This section
supersedes the preceding open-F1 status and preserves both earlier reviews as
history. Execution acceptance remains pending: Main reported focused-r7 running
with 62 tests expected; an expected count is not an executed/passing result.
The reviewer ran no tests/build/apps and changed only this report.

### F1 closure

`Sources/PagingPrototypeApp/AppDelegate.swift:2553–2560` now snapshots the root
and language epochs for menu creation. The launch ingress captures the origin
assembly weakly and checks both epochs and assembly identity **before** calling
`launchMember`. The previously reported old-menu route can therefore no longer
obtain the rebound current launch-result callback. Finder ingress uses the same
epoch snapshots at `2570–2574`; shared launch-result guards remain at `158–163`.
Root/realm installation still rebinds current factories (`118`, `145–150`, `2264`),
including startup's controller-before-root order. Ordinary live-language relabeling
at `2332–2346` does not invalidate menu/launch generations. Menu binding guards
and the shared launch validation/API path remain intact.

`ApplicationActionFeedbackRuntimeTests.swift:266–300` acquires the menu from the
actual retained renderer cell, keeps old controller/item references, and authors
old-root actual-action plus copied-callback replay against a new error. It asserts
no additional fake-launcher dispatch and no reason/deadline reset. The same test
authors an actual old menu action after realm replacement, asserts no dispatch
and hidden feedback, then delivers a current factory-created menu action and
asserts one dispatch and visible failure feedback. Existing `185–218` tests retain
the old result/success/Finder callback coverage. These are meaningful regression
assertions for the residual route; they were inspected, not executed here.

### F3 fixture correction and preserved constraints

The folder test at `236–263` now supplies its fixture snapshot through
`assembly.folderSnapshotGenerator` (`243–244`) before the idle commit.
`AppCatalogAssembly.swift:477, 551–558` defines and consumes this existing
generator seam for the pending catalog base. The test still constructs real
folder wiring, calls real `openFolder`, inspects actual sibling order in both
material modes and checks deadline/reason/hit testing. No replacement fake page
or fake overlay was introduced. The source repair still inserts the folder below
the retained notice (`AppDelegate.swift:1720–1728`), and actual-hide clearing
remains present (`2879–2882`).

Notice implementation and clock ownership are unchanged (same SHA-256 as both
prior reviews). No new launch path, validation bypass, deadline renewal, Finder
success assertion or user-data logging was found in these repairs. Independent
runtime/resource/package/GUI/restart/VoiceOver and physical-performance gates
retain the previously stated boundaries.

Current hashes, read twice with matching results:

```text
6105330256b8a25fa321b0f85223b12ec8ed7538dd53a9fce46fa37b023353df  Sources/PagingPrototypeApp/AppDelegate.swift
3e3c6f10eb19b19ef458f36706e040f9fc7c9eb7a113ee331ced2f2c2163acc3  Tests/PagingUITests/ApplicationActionFeedbackRuntimeTests.swift
83f5a44a85a1897dece236b76fe7900a7882b604d7c98dc238144008d28a51cc  Sources/PagingPrototypeApp/ActionFeedbackNoticeView.swift
```

Main owns the new freeze and nonzero serial regression result. This source verdict
does not certify full parity, native GUI or FPS acceptance.

## Folder fixture follow-up / bounded review closeout — 2026-10-14

**Source-review verdict remains PASS; runtime execution remains pending.** Main
reported focused-r7 as 62 executed / one failure confined to the folder fixture,
then a fixture-only correction with focused-r8 running. These are Main-supplied
updates, not reviewer-executed or independently log-verified results. No r8 PASS
is asserted. This section corrects the prior fixture assessment without rewriting
the historical record.

The reported r7 cause is supported by actual source:
`Sources/AppGridUI/FolderLabFixture.swift:57–69` uses
`max(0, records.count - groupSize)`. Two records with groupSize two therefore
produce an empty folder snapshot even with grouping enabled. Using that lab
generator did not establish a usable folder for the mount assertion.

The current test at `ApplicationActionFeedbackRuntimeTests.swift:243–246`
constructs one explicit `FolderSnapshot` through `FolderEntryBuilder.make`, with
two distinct members present in its revision-two catalog, and supplies it through
the existing `assembly.folderSnapshotGenerator` seam. The builder normalizes
members without replacing the UI (`FolderDomain.swift:102–110`). Production
`commitPendingAtIdleBoundary` still invokes the generator and commits through the
existing presentation path (`AppCatalogAssembly.swift:551–567`). The test still
uses real `installFolderWiring`, `openFolder`, mounted overlay sibling indices,
both material modes, unchanged notice deadline/reason and nil notice hit testing
(`ApplicationActionFeedbackRuntimeTests.swift:249–263`). No fake overlay/page or
production source workaround was introduced by this correction.

Current fingerprints:

```text
6105330256b8a25fa321b0f85223b12ec8ed7538dd53a9fce46fa37b023353df  Sources/PagingPrototypeApp/AppDelegate.swift
83f5a44a85a1897dece236b76fe7900a7882b604d7c98dc238144008d28a51cc  Sources/PagingPrototypeApp/ActionFeedbackNoticeView.swift
39288370b7f86cbbccc705d4e35e2b1e97278299be9f37e89a7b1086a1ae3277  Tests/PagingUITests/ApplicationActionFeedbackRuntimeTests.swift
```

Production AppDelegate/notice hashes match the final F1 review. No new actionable
source defect was found in this fixture correction. F1–F3 source repairs remain
closed for this bounded review; Main owns the nonzero r8 result and subsequent
acceptance gates. The reviewer wrote only this report and ran no tests, builds,
apps or process-control actions. Full parity, native GUI and FPS remain outside
this verdict.
