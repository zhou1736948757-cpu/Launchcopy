# Identifier search — native validation plan

Date: 2026-10-15. Status: NOT EXECUTED for this candidate.
Approved contract: Docs/BUNDLE_IDENTIFIER_SEARCH_SPEC.md.
Target: /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/identifier-search-rc-20261015-r1/LaunchcopyUITest.app, only after package/hash verification.

## Safety and identity
Supported desktop controls only, manual unlock if needed; no authentication workaround or Terminal/Finder launch-script substitution. Dedicated metadata selects ordinary non-topmost test window and isolated gui profile. Never install over formal app, use formal inventory/preferences, or close unrelated instances. Confirm actual candidate process identity, current AX tree and visible window before actions. Native tests still share the user's input; honor Desktop2/no-disruption boundary. Normal Quit only own test instance.

Forty new independently authored Info-only test bundles will use display names Policy Demo01..40, identifiers com.launchcopy.fixture.identifier.demo01..40 and three declared categories. They are for filtering/navigation and expected launch-failure handling, not successful application startup. No copied assets/source or actual user-app metadata.

## Exact observations
1. Fresh default: original/alias names match; an identifier-only fragment com.launchcopy.fixture.identifier has no results; checkbox is OFF in management settings without selecting any app.
2. Enable: native checkbox action acknowledges stored value, then reports either queued or applied accurately. While Library editor/alias/IME/menu/sheet/gesture owns presentation, retain old results and report queued; finish that interaction explicitly. Do not treat a merely stored checkbox as effective filtering.
3. Same unchanged main query gains expected visible synthetic apps when applied. Original display labels/order and canonical action identities remain; no ID captions substituted.
4. Hide one fixture and give another an alias using existing safe actions. ID match must not resurrect hidden app; alias and original-name searches remain valid. Restore hidden state afterward; no uninstall.
5. Enable optional Library via its existing setting. Enter, type its independent identifier-only query, finish editing (Tab to visible results if needed), and confirm same effective policy/category counts. Main query must remain intact.
6. Toggle OFF while that query remains, finish interaction, and verify ID-only results disappear without clearing the query or retaining an invalid selected action. Name/alias queries still match.
7. Use enough matching records for multiple pages; verify selected surviving app follows its current page/slot across mode changes; unmatched selection clears. Back from Library restores current valid main-grid context.
8. With a folder open, mode-only change must not request folder close, replace overlay/member selection, cancel drag/IME or modify arrangement. Physical held-input check is a distinct user-device gate, not inferred from synthetic wheel/tests.
9. Test en/zh-Hans/ja settings labels/helper/queued/applied/failure and checkbox keyboard/AX actions; inspect actual frames/screenshot for clipping/overlap. Unshown mounted-control tests are not this check. VoiceOver remains separate.
10. Normal Quit own instance after acknowledged preference. Confirm process ended; directly reopen SAME candidate. Verify mode, hidden/alias choices and matching survive fresh process. This proves only the observed normal restart, not power-loss/fsync or crash durability.
11. If safe candidate-local failure/future/corrupt fixtures are deliberately prepared, checkbox must roll back or stay protected with accurate status. Do not corrupt formal settings. Unit/store gates remain distinct from actual error UI.
12. Source-refresh and mode-change late completions may not restore stale actions. Repeat supported query/watch/Back/normalhide behavior as needed without scanning private app roots.
13. Compare matched physical paging/input/startup workload before/after this slice on actual display/build/frame source. Controlled1000fixture timing data is current synthetic work only; no pre-migrationAB/allocation/physical regression PASS. Keep >25ms and120Hz limits explicit.

## Evidence record
Record exact executable hash, whether ordinary/direct startup occurred, each actual AX/action/result, screenshots where needed, receipt phase and real process restart. Do not log real search text/app names/IDs/paths, actual wallpaper source or usage history. All example identifiers above are synthetic fixtures. Build/test results are recorded separately.
No gate is credited by this written plan. If locked or denied, preserve error and stop UI work; existing capacity proposal is still independent/unapproved.
