# Clickable Page Dots — Implementation Specification

Status: APPROVED INTERACTION / MAIN IMPLEMENTATION DESIGN,2026-10-13.
Authority: user confirmation recorded in LAUNCHBETTER_DIRECT_PAGE_NAVIGATION_PROPOSAL.
Sources code gates closed (2023/0, scoped review PASS); GUI is still unverified.
This extends the approved parity plan, not its scope or the physical paging policy.

## Outcome and contracts

Native bottom dots show COMMITTED ordinary/search pages, hide for0/1 page and
request nonadjacent targets without synthetic gestures or chained adjacent turns.
Only idle/ordinary settling accepts; tracking, release wait, momentum/glide,
folder, title editing, held drag/click session and inactive/hidden lifecycle ignore.
Ignored/no-op requests have no focus, pin, token or responder effects. Idle same
clamped page and already-active direct target are no-ops. A request to the current
committed page during a different settle replaces it and returns naturally.

Core owns continuous visualOffset; the current renderer synchronously mirrors it.
New Core requestPage/canRequestPage reuse beginSettle/spring/token unchanged.
SettleReason gains directNavigation; TransitionContext retains independent direct
provenance across Reduce Motion restart. Surface presents requestPage/canRequestPage,
isDirectNavigationActive, presentedOffset and cancelDirectNavigation. It pins only
accepted requests and uses existing frame driver. Never cancel physical ownership.

Pointer focus clearing happens BEFORE forwarding (RM can synchronously commit).
Clear pending keyboard cross-page target as well as highlight/current/deferred.
Direction/activation during direct settling are consumed, not seeded/activated;
first subsequent direction seeds final committed page. Search query/responder
remain intact. No parallel app launch, source, icon, frame or focus state machine.

Hide/resign/resize/content replacement/search staging/screen changes cancel only
active direct navigation before stale callbacks; teardown retains existing rules.
Height-only resize also invalidates direct ownership. RM restarts retain ownership
until immediate landing or cancellation. Ordinary physical lifecycle stays intact.
Count changes/replacements notify a discrete Surface callback, not offset ticks.
Owner refreshes dots after committed presentation/search/idle and lifecycle.

## UI and bounded performance

Independent AppKit PageDotsView with at most9 page buttons plus2 window controls.
Controls preserve absolute page IDs; shifting the dot window never navigates.
Count/committed selection changes center the viewport only when required, not on
animation offsets. Labels expose page/count/current. Disabled strip remains chrome
for hit testing so blank dismissal/drag cannot swallow a button or strip gap.
Use parent bounds/constraints and current materials, not screen-specific geometry.

Defaults,5x7, spring/tolerance/thresholds and Timer remain unchanged. No new per-frame
IO/synchronous icon loading; preserve existing async icon pipeline and bounded host
reuse. Existing renderer may bind/request asynchronous icons when live range changes;
measure this separately rather than claim zero such requests or a physical PASS.
A long jump can take longer under existing spring tolerance; no fixed completion
wall-clock promise. No new timers, broad preloading, per-offset dot rebuilding.

## Acceptance and delivery

Core: empty/one/clamp/last/nonadjacent/no-op, latest-wins continuity, stale completions,
tracking/glide zero effects, RM restart/provenance, cancellation/teardown.
Surface: pin, pending finish unaffected, driver lifecycle, 100-page reuse/high-water
bounds, height resize and same-count/revision replacement cancellation.
Actual NSButton->owner->Surface->Core tests, folder/title/drag/lifecycle gating,
keyboard pending target/deferred behavior and search count preservation.
Independent review plus nonzero focused/full tests, Debug/Release, candidate/hash
and source fingerprint. GUI/full-screen physical AB/120Hz are separate gates.
No install/launch/commit/sign/publish, original reference code/assets or cleanup.

## Ownership and maintenance

Main: Core/TransitionContext/Surface/AppDelegate/input-cancellation wiring and tests.
Worker UI: only new PageDotsView.swift and PageDotsViewTests.swift.
Worker focus: KeyboardFocusController.swift and new PointerPageFocusTests.swift.
Main-only Swift executions after files freeze; up to3 agents including Main.
Preserve historical dirty tree, user decisions and source-phase evidence.
Weak observers and synchronous token ownership; no generations interchanged.
Review ambiguities as actual findings; whole parity remains incomplete.

## AXPress primary reference

The Bool reports that an accessibility action was triggered, not its asynchronous
navigation outcome. Page buttons dispatch one native action when enabled and
report handling; selected state stays committed until the owner publishes it.
[Apple accessibilityPerformPress](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilityperformpress()).
Native VoiceOver/runtime acceptance remains unexecuted.
