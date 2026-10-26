# Action feedback consumer handoff

Status: source implementation complete; NOT compiled, NOT test-executed, NOT GUI accepted.
Date: 2026-10-14. Role: bounded consumer worker. Main owns integration and serial verification.

## Authority and inspected contract

The user authorized this existing, approved implementation slice and waived the old
Chief workflow. The stage summary specifies the six typed keys, passive overlay,
six-second monotonic deadline, standard accessor and deferred presentation.
`approvedDocs/INTERFACE_LANGUAGE_SPEC.md` is absent in this checkout. The inspected
approved equivalent is `Docs/INTERFACE_LANGUAGE_SPEC.md`, explicitly marked
APPROVED_IMPLEMENTATION_CONTRACT. Also read
`Workflow/stage-summaries/2026-10-14-language-action-feedback.md`, `AGENTS.md`,
`/Users/mac/.codex/RTK.md` and current AppKit/localization/test conventions.
No new specification or architecture branch is introduced.

Only these new files were authored:

- `Sources/PagingPrototypeApp/ActionFeedbackNoticeView.swift`
- `Sources/LauncherLocalization/ActionFeedbackTextKey.swift`
- `Tests/PagingUITests/ActionFeedbackNoticeTests.swift`
- `Workflow/results/LANGUAGE_ACTION_FEEDBACK_CONSUMER.md`

No shared resources, runtime, package, other tests, workflow state or memories were
edited. Existing dirty work was preserved. No helper agents were dispatched by
this bounded worker; the authorized Main + two-worker ceiling was not increased.

## Exact resource requests (Main-owned)

Add all six keys to `ResourceKey` schema/all/name/placeholder switches and expose
`LocalizedStrings.actionFeedbackText(_ key: ActionFeedbackTextKey) -> String`.
Match the existing typed static-text render pattern, falling back to
`key.englishFallback`. Every key has zero placeholders and takes no arguments.
Add these independently authored exact values to the existing en/zh-Hans/ja tables:

| Key | en | zh-Hans | ja |
| --- | --- | --- | --- |
| `actionFeedback.launchFailed` | Could not open the app. Try again. | 无法打开应用，请重试。 | アプリを開けませんでした。もう一度お試しください。 |
| `actionFeedback.launchMissing` | The app could not be found. Refresh the app list and try again. | 找不到应用，请刷新应用列表后重试。 | アプリが見つかりません。アプリ一覧を更新してから、もう一度お試しください。 |
| `actionFeedback.launchUnavailable` | The app is currently unavailable. Refresh the app list and try again. | 应用暂时不可用，请刷新应用列表后重试。 | アプリは現在利用できません。アプリ一覧を更新してから、もう一度お試しください。 |
| `actionFeedback.finderMissing` | The app could not be found. Refresh the app list before showing it in Finder. | 找不到应用，请先刷新应用列表，再尝试在访达中显示。 | アプリが見つかりません。アプリ一覧を更新してから、Finderで表示してください。 |
| `actionFeedback.finderUnavailable` | The app is currently unavailable. Try showing it in Finder again later. | 应用暂时不可用，请稍后再尝试在访达中显示。 | アプリは現在利用できません。しばらくしてから、Finderでの表示をお試しください。 |
| `actionFeedback.feedbackAccessibility` | App action status | 应用操作状态 | アプリの操作状況 |

`ActionFeedbackTextKey` is public String/CaseIterable/Sendable with public
`englishFallback`. The sixth key labels the notice accessibility element; passing
it as a show reason is ignored. Missing resources safely use English after Main
adds the accessor. No translations from reference products/assets are used.

## Integration hooks

- Construct `ActionFeedbackNoticeView(frame:strings:)` with the immutable displayed
  language snapshot. `strings` is optional; `init(frame:)` uses nil and never
  initializes `LocalizedStrings` or loads resources. Initial view is hidden/empty,
  with no scheduled jobs. There is one retained wrapping label and one layer.
- On a validated real failure, call `show(reason:strings:)`. Main selects the
  stable reason and passes the current displayed snapshot. No app names, URLs,
  paths, queries, native error messages or logging arguments enter the view.
  Existing launch validation, launch path and hide-on-success semantics remain
  Main's responsibility.
- Mount the inert root overlay below search and above folder visuals without
  changing grid/core metrics. `hitTest` always returns nil, including descendant
  coverage; the container rejects first responder and its label refuses focus.
  There are no controls, popup, sheet, animation, icon or catalog operations.
- Set `onPresentationApplied` to weakly call Main's layout hook. On that hook,
  reserve `requiredPresentationHeight(forWidth:)` and set the frame. Height is
  cached: a different requested width schedules measurement; the next callback
  supplies the complete height. Do not unconditionally call `layout()` from this
  callback, as explicit layout requests schedule another deferred application.
  Before first show and after clear, required height is zero; initial show delivers
  its measured height in the first application callback.
- Call `relabel(strings:)` only when Main accepts displayed-language changes.
  Call `applyMaterialPolicy(reduceTransparency:increaseContrast:)` from the owner.
  Reduced transparency uses alpha 1 and an opaque layer; normal alpha is 0.7.
  Increased contrast uses a two-point white border. No material policy consults
  NSWorkspace or loads wallpaper. Frame/bounds/layout changes stage deferred sizing.
- Call `clear()` on hide, successful action, stale namespace replacement or
  cancellation. It invalidates both obsolete jobs and defers empty/AX-hidden
  presentation. A new real show can supersede that clear without an old callback
  restoring an earlier reason. Detaching from a superview also clears. Hiding an
  ancestor alone is not a lifecycle signal: Main must call clear explicitly.
- Call `teardown()` outside frame callbacks before discarding/replacing the view;
  this terminal hook cancels work, hides/clears AX/text immediately, drops the
  snapshot/callback and rejects future API calls. Timer/queue closures hold the
  view weakly. Main should remove the old overlay after teardown.
- Finder `activateFileViewerSelecting` returns Void: successful dispatch is a
  request only. This view makes no OS success/failure observation. Main may show
  missing/unavailable feedback for its existing canonical-record validation.

## Clock, scheduling and invariants

The test seam is `init(frame:strings:clock:scheduler:)`; nested public aliases are
`Clock`, `Cancellation` and `Scheduler`. All are main-actor functions. Scheduler
accepts elapsed delay and an escaping main-actor action, returns a cancellation
function, and MUST defer execution. Use zero delay for next-turn presentation and
positive delay for expiry, with the same elapsed-time units as the clock.
Default clock reads `DispatchTime.now().uptimeNanoseconds`; default scheduler uses
main-queue DispatchWorkItem callbacks. No wall-clock date participates.

Every show starts its deadline at receipt: now + 6 seconds. Latest real failure
wins, including a repeated same-reason show; it cancels the old expiry. Relabel,
material and resize never reset the deadline. At most one current presentation job
and one current expiry job are retained. Cancellation invalidates the token before
calling the scheduler cancel function. Late, cancelled or duplicate callbacks
cannot overwrite newer state. A timer callback only queues presentation. The
presentation callback rechecks now >= deadline before formatting, so delayed first
render or delayed timer/relabel cannot revive expired feedback. Early timer
delivery rearms the remaining duration, preserving the original deadline.

Public show/relabel/material/layout/height APIs stage semantic state and coalesce
work. Static-text reads/formatting, AX writes, cell sizing, label frames, layer
material application and expiry hiding occur in the deferred application. The
terminal teardown is an explicitly outside-frame owner operation. There is no
resource provider, bundle lookup or resource IO in the view. Internal counters
expose actual text calls, sizing measurements, material applications and complete
presentation applications for structural tests, not physical performance claims.

## Authored verification (execution deferred)

The standalone XCTest file supplies its own `TestMain`, fake monotonic clock,
bounded manual scheduler with cancelled/duplicate replay, absent provider and
lock-protected in-memory resource provider. All AppKit construction occurs in
TestMain; views stay unshown and no NSApplication or NSWindow is requested.
The resources in these tests are consumer fixtures; Main must separately validate
shipping tables, required-key coverage and packaged resources.

Authored gates cover:

- Exact six IDs/fallbacks; all five actual reasons and AX strings in en/zh-Hans/ja;
  missing resources; accessibility-only-key guard; nil/optional initialization.
- Receipt-time six-second boundary, unrelated wall-time changes, latest-wins before
  render, same-reason real-error renewal, late first render, early/duplicate/stale
  timers, unchanged timer/deadline across relabel/material/resize.
- Clear before presentation and after show, clear/new-show race, expired-language
  non-revival, detach, terminal teardown, duplicate callbacks and weak retention.
- No text/AX/sizing/material/callback work during 120 staged frame-stack calls;
  a self-contained real `PagingSurface.advanceFrame` callback test counts 120
  calls with no consumer formatting/measurement or fixture-provider reads until
  the fake next-main-turn scheduler runs. This does not certify other consumers'
  whole-frame IO budgets or physical frame timing.
- Cached deferred height, full text line bounds in all languages, zero/tiny bounds,
  retained one-label identity, all material variants, nil hit-test and focus refusal.

No Swift build, Swift test, native app execution, install, commit, reset, process
stop or reference/evidence inspection was performed. Source-only checks and any
remaining integration prerequisites are recorded below; only Main may run the
serial compiled/test gates after integrating and freezing the shared resources.

## Source-only check record

- Existing repository `rtk git diff --check` returned exit 0; this excludes these
  new untracked files, which are checked separately before handoff.
- Standard shared accessor/schema is an integration dependency, not supplied here.
  The view intentionally calls the specified Main-owned API rather than adding
  a duplicate extension or modifying shared resources.
- RTK-wrapped Python source checks returned exit 0: all four owned files have
  clean trailing whitespace/final newlines; six exact IDs and 18 fixture translations
  match this handoff; required standard public methods are present; the notice
  contains no resource construction/bundle/file/app/modal/log APIs. The standalone
  file contains 16 authored XCTest methods. This is textual validation only.
- Targeted RTK git status identifies exactly the four assigned new files as
  untracked; no staging or commit was performed.
- Compilation, nonzero XCTest execution, exact candidate GUI, VoiceOver, packaging,
  physical timing (>25ms causality/120Hz gates) and restart remain unverified.
- Initial instruction-file read and working-directory query used raw `cat`/`pwd`
  before the RTK rule was applied; every subsequent shell command used RTK.
