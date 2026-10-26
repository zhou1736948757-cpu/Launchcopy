# Launch and Finder feedback / residual language audit

Status: implementation in progress. Previous goal turn: concrete progress2366/0,
213-key package, menu/status/modal integration, repaired independent findings.
Approved source:INTERFACE_LANGUAGE_SPEC + PARITY_SPEC. Full objective remains active.

## Plan and disjoint ownership

Main immediate critical work: production launch/Finder outcome routing, shared typed resources,
root lifecycle integration and serial code/package verification. Worker A: independently authored
inert ActionFeedbackNoticeView + ActionFeedbackTextKey + focused consumer tests/report.
Worker B: residual shipping-text and whole-parity evidence audit (Markdown only). Main+2 max3.
Old Chief workflow waived; preserve dirty files, no reference code/assets/evidence trees.

Feedback contract within approved nonfatal/localized error scope: no native error popup,
no new launch path, no changed launch validation/hide-on-success/keyboard/menu binding semantics.
Typed keys launchFailed/launchMissing/launchUnavailable/finderMissing/finderUnavailable/feedbackAccessibility.
Main API LocalizedStrings.actionFeedbackText(_:); enum String/CaseIterable/Sendable with
public englishFallback. Main owns resources/schema. No app names/paths/queries in notice/logs.

View APIs: init(frame:strings: optional immutable snapshot), show(reason:ActionFeedbackTextKey,
strings:LocalizedStrings), relabel(strings:), clear(), teardown(), applyMaterialPolicy(...),
onPresentationApplied + requiredPresentationHeight(forWidth:). Show latest reason for6seconds
monotonic time; new real error resets deadline, locale/material/resize does NOT. Expired/cleared
notice must never revive on relabel. Clock/scheduler deterministic injection for tests. Rendering,
AX, sizing and timer expiry handling coalesce outside frame stack; constructors no resource IO.
HitTest=nil, no first responder, no icon/catalog work. Main mounts inert root overlay below search,
above folder visuals on actual failure; no layout/core metric change. Hide/replace/teardown drops
obsolete work. Snapshot strings only; future source audit does not manufacture full acceptance.

Finder boundary: existing public activateFileViewerSelecting returnsVoid, so successful dispatch
means REQUESTED, not proved Finder presentation. Detect missing/stale/hidden canonical records;
never claim observed OS failure/success from synthetic tests or an invented bool.

No Swift/app execution by helpers. Main serial tests after freeze. No app launch/install/sign/
publish/process stop/commit/clean; RTK shell prefix mandatory. Global memory never edited.
New code/resource/fingerprints not reused frompreviouscandidate; physical>25ms unresolved,
120Hz and exact native GUI/restart/VoiceOver/performance gates remain. Library/capacity need
confirmation; optional destructive/gesture/usage details not certified from absent code.

## Residual audit L1 approved-scope repair

Audit identified production SMAppService adapter's authored English failure sentences, not
native error details. Main preserves existing failure(message:) for literal native/injected
compatibility, adds operationFailed(enabling:Bool) semantic state and2localized status keys.
Actual catch routes through shared pure statusAfterFailedOperation seam; registration/status
truthfulness/transaction/rollback behavior unchanged. Tests never register real login items.
This explicitly implements already-approved stable error reason contract; no new language decision.

## Final code checkpoint

62focused/2403full0fail; DebugRelease/current391inputs;221keys/signatures actual3language
bundle and2negativefixtures. Independent bounded ActionF1-F3/LoginL1+C1 repairs clear.
Fourhelpers closed. Latest ordinary exacthash isolated manualkit prepared NOTlaunched.
Fresh CUAinventory shows originalLaunchcopy running, distincttestapp notrunning; askeduser
manualstartDesktop2 without policy bypass. Wholegoal/native/physical/restart notcomplete.
Fullrecord:Workflow/results/LANGUAGE_ACTION_FEEDBACK_CODE_CHECKPOINT.md.
