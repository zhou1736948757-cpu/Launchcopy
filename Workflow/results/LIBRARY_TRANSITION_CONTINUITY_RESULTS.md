# Library transition continuity repair

Date: 2026-10-20. Status: final serial verification and independent follow-up in progress; native/physical repair acceptance pending.

## User scope
Remove the redundant main-grid Library entry, reduce the hitch entering Library, and address flicker returning to the grid. The previous wide external search-focus remnant is separately USER_CONFIRMED_PASS on a7509311; no rollback of that accepted local search-decoration fix.

## Implemented mechanisms
- Main composition attaches no grid Library button. An ordinary localized, validated View-menu command retains non-gesture access, with no new shortcut or default opt-in change.
- Parent frame writes and commit/cancel/visibility reconciliation disable implicit Core Animation actions. Exact frame-driven transforms/Reduce Motion behavior remain; wallpaper and canonical pager are unchanged.
- Restore the destination before revealing it. Identical empty/nonempty grid queries no longer stage a new generation/rebind; pending catalog/search work still commits.
- Results icon requests and queued callbacks check semantic presentation mode, rejecting gallery/narrow-detail work even before deferred layout updates hidden flags.
- Category material writes compare effective colors, border policy and activation state rather than rewriting identical properties on window/layout updates. Appearance and accessibility changes remain supported.
- Independent review found close callback reentry and an outer preference notification-after-teardown path. Both have explicit lifecycle guards and deterministic RED-to-GREEN regressions; test restore closures do not retain their owner.

## Scope boundaries
No PagingCore/PagingUI/physics/grid/folder geometry, catalog storage, order, history opt-in or wallpaper policy changes. No retained stale snapshots, skeleton caching, new timer, or persistent private screenshots. Native tests operate only the owned unsigned/uninstalled candidate and authored fixture data. Source improvements do not establish physical smoothness, compositor causality, frame-time reduction or complete product parity.

## Evidence (historical until final receipt)
Initial four regressions: 4 tests/7 assertions RED. Reentry:2 tests/8 assertions RED then2/0 GREEN. Notification epilogue:2 tests/2 assertions RED then2/0 GREEN. Pre-R2 candidate7947335a (never launched) had535inputs/237focused/3263full/Debug/Release/package green, but is superseded by the final lifecycle repair. Existing quit test corrected a captured-before-startup-refresh stale action request; no product stale-generation gate weakened. Failed attempts and reviews preserved.

Current logs and source manifests: `.build/verification/20261020/library-transition/final-r2/`. Review reports: `Workflow/reviews/LIBRARY_TRANSITION_CONTINUITY-r1.md`, `-r2.md`, with final follow-up pending. Old own41393 normally quit through native application menu and exact absence verified; Cmd-Q alone was ineffective and not counted as exit. No formal app/data/process-signals/sign/install/Git mutations.

## Next executable action
Complete frozen serial focused/full/build/package and independent follow-up; seed only249 hash-verified authored fixture files into a new isolated profile (no old preferences/history/cache), native-open the exact candidate, verify absent grid entry and native View-menu/Library/Back, then hand off real-touchpad completed/canceled entry-return checks. Do not claim the reported hitch/flicker resolved before physical confirmation.

## Final 2026-10-20 delivery and native packet

- Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-continuity-rc-20261020-r2/LaunchcopyUITest.app`; SHA256 `bc701b1c2a476b8a51d8d0d2ed012defff6f4913caf1db868f2cbc46324ded22`; last verified owned PID88692. Unsigned/uninstalled, normal non-topmost window. Earlier7947335a r1 NOT_LAUNCHED and all older packages are historical, not current source.
-535 frozen inputs, 13 changed source/test paths versus a750 baseline; no Core/PagingUI/AppGridUI changes. Focused239/0, full3265/0; Debug, Release, package and diff passed. Existing unrelated warning history not recast as global warning-clean. Packaged localization365keys×3languages retained.
- Independent Descartes r3 BOUNDED SOURCE_ACCEPT; R1/R2/T1 closed, prior findings preserved; all agents closed. Main owns actual verification.
- Native: old41393 normally Quit/exact absence; fresh249hash-verified authored fixtures only, no preferences/history/cache imports. Cold LibraryOFF/historyOFF→own LibraryON/Saved/historyOFF. Main AX and inline screenshot show no redundant entry after feature enable. Localized View-menu entry opens eight populated category cards; search→single synthetic result→native clear returns cards; nativeBack restores prior main query, then main query cleared. First page and wallpaperREADY observed. No formal app launches/removal/data, signals, install/sign/Git mutations or saved private screenshots. All535source/binary/249seed hashes rechecked unchanged.
- One generated horizontal-right scroll caused no observed navigation; INCONCLUSIVE, not a physical test or established app/input cause. Completed/canceled real-touchpad hitch/flicker, frame-time metrics, spokenVoiceOver/liveIME/120Hz remain unaccepted. OrdinaryBack endpoint is not proof of animated return continuity. Source risk reductions are not a measured causal/performance fix.
- Current handoff: owned ordinary main window, page1, empty query, Settings/folder/Libraryclosed; own LibraryON/historyOFF. Request one user real-touchpad entry/return check and do not operate UI during it. Full product parity remains incomplete. Receipts: `.build/verification/20261020/library-transition/final-r2/final-verification.json`, `native-results.json`, `native-fixture.json`, `source-delta.json`.
