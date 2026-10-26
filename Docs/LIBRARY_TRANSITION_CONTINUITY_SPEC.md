# Library transition continuity repair

Date: 2026-10-20. Stack: Swift 6 / AppKit / Core Animation; existing parent two-pane navigator over the unchanged canonical grid pager.

## Problem and scope
User accepted the local Library focus-border fix, but reports redundant main-page Library entry text, a hitch on Library entry, and flicker returning to the grid. Remove the main-page Library button, retaining swipe entry and the Settings opt-in. Independently diagnose startup and terminal transition work; do not change the accepted paging parameters, grid/folder geometry, app ordering, default opt-in, or persistent data contracts.

## Requirements and architecture
- No redundant Library entry button on main grid, including accessibility/hit testing.
- Preserve original-event stream ownership and shared frame pump; no new timers or snapshot of private wallpaper.
- Transition views must remain at the correct presented positions through commit/cancel/visibility changes; no implicit layer interpolation or intermediate untransformed visible panes.
- Reduce entry preparation work where source evidence establishes repeated unnecessary construction/projection; use bounded retained state only with explicit lifecycle/invalidation rules. Never retain stale actionable catalog targets or leak focus/accessibility ownership.
- Main owns composition/source integration and serial SwiftPM/build/native tests; up to one disjoint read-only investigator initially, then independent bounded review. Max three active agents including Main. Historical Chef machinery bypassed per direct user instruction.

## Acceptance and verification
Add deterministic regression coverage for confirmed causes and keep responder/leading navigation tests green; run serial focused/full tests, Debug/Release and isolated unsigned package. Native checks use only exact owned test candidate/configuration and CUA; no formal data changes or saved private wallpaper. Source risk reductions are not proof of physical smoothness. A real-touchpad completed and canceled transition check remains separately identified. Preserve previous blue-border acceptance and all historical failures. No install/sign/commit/reset/clean/process signals/reference-source access.

## Unresolved
Reported hitch/flicker mechanisms not established yet. Investigate synchronous view/gallery/projection creation, per-frame layout/CA actions, and terminal visibility/restore ordering before changing architecture. Record exact evidence and limitations.

## 2026-10-20 accessibility refinement
Removing the permanent grid button must not make Library gesture-only. Retain an ordinary localized View > App Library menu command (no new shortcut), enabled only when the same lifecycle/admission gates permit entry. No visible grid label, no product default change.
