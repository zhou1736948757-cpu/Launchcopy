# App Library native validation protocol

Date: 2026-10-15. Status: NOT EXECUTED for the category-focus candidate.
This protocol complements, not replaces, the full parity ledger.

## Safety / exact target
Use only /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-category-focus-rc-20261015-r1/LaunchcopyUITest.app after package verification. The unsigned dedicated test metadata selects candidate-local gui data and an ordinary non-topmost window. No installation or formal profile. Operate only through supported desktop APIs, after the Mac is unlocked and current application/window identity is observed. Do not bypass permissions or run scripts through other applications. Do not close another application; normal Quit only this test instance.

Info-only synthetic apps are for categories/details/navigation and expected launch-failure handling, not proof of successful NSWorkspace startup. A successful-launch test needs the previously approved independently authored self-exiting executable fixture with a fresh marker, separately installed in this candidate-local test source; never infer it from an Info.plist or opened dialog.

## Procedure and evidence
Before every action sequence, obtain the current AX state and derive fresh indices. Capture screenshots only when needed to verify visual structure, control overlap, or focus; do not guess unseen coordinates. Record candidate executable hash and current profile separately from all observations. No app names, IDs, wallpaper paths, queries or raw personal data in telemetry.

| Gate | Actual steps | Passing observation / boundary |
| --- | --- | --- |
| Default off / enable | First fresh profile launch; inspect grid and settings Library tab. Enable and await acknowledged save, then enter. | No entry before enabled. Same resident window owns Library; no negative pager page or new launcher. |
| Independent search | Save a nonempty main-grid query and selection, enter Library, change its query, use original and displayed alias names. | Correct visible matches; main-grid query is not overwritten by Library query. |
| Categories / details | Inspect All plus categories, counts, explicit Details and declared/unknown fields. | Counts match visible query; unknown metadata labeled; row arrow navigation alone does not open details. |
| Composition | Use real Chinese and Japanese input methods on Library search. While candidates/marked text exist, press Return, Down and Escape; commit/cancel, continue typing. | Candidate interaction does not launch/select/back prematurely. Escape respects composition before details/query/Back. Synthetic setMarkedText is not this gate. |
| Wide/compact category focus | Focus wide category list; shrink below compact threshold, inspect focus; focus compact picker, expand. Also resize with search composition and results focused. | Category focus moves to the visible counterpart. Search composition/result focus remains unchanged. No hidden grid receives keys. |
| Native Tab | Traverse Tab/Shift-Tab through search, category, results, Details and detail controls at both widths; close details and reacquire the key window. | Every focus target is visible and available; Escape/Return priorities remain correct. Full Keyboard Access policy must be recorded, not changed silently. |
| Accessibility actions | Inspect actual roles/labels/children/actions; invoke only exposed actions for Back, Details, Open/Reveal, filters and management. Separately check enabled/loading/hidden states. | Same validated request path, no stale/hidden action. Ordinary performClick or identifiers are not AX-action proof. |
| VoiceOver | With explicit authority for the non-sensitive setting, test actual VoiceOver navigation and announced labels/destinations. Otherwise leave pending. | Readable localized controls, no hidden subtree navigation. AX tree alone is not VoiceOver PASS. |
| Manual category / Automatic | Select an override; Save; await successful receipt; check category/filter membership. Restore Automatic. | Only explicit Save commits; successful receipt reflects actual saved category; no grid reorder/catalog rescan. |
| Protected writes | Inject only a prearranged candidate-local failure, test retry/default Cancel Quit protection and accepted write drain. | Failed draft not advertised as saved; no competing warning during Quit. Cancel retains test instance/data. Actor tests are not failure-dialog or disk durability proof. |
| Hide / alias / folder reuse | Use existing safe actions in Library, verify visible exclusion/original-name query/dormant layout, then restore through management. | Shared validated identity/lifecycle semantics and unchanged saved arrangement; no uninstall or new folder feature. |
| Back / changed content | Return with saved main query and selected app; repeat after candidate-local catalog removal/reorder or hidden anchor. | Current valid revision/page/slot, nearest fallback when missing, intended main responder, no automatic folder reopen. |
| Source refresh / failure | Add/remove owned synthetic test bundles and await watchers; exercise safe configured-source replacement failure. | Correct Library loading/error/empty state, old actions revoked; latest shared commit shown without manual query/resize. |
| Hide / reopen | Normal resident hide from supported action, then reopen test instance. | Grid mode, no stale Library query/details or unwanted folder reopen. |
| Locale | Apply each approved language in safe state; inspect controls and retained draft/query. | en/zh-Hans/ja labels, safe deferred update; app names/order are not translated. |
| Normal Quit / restart | After category, alias and enable changes acknowledged, normal Quit own instance and verify its process ended; directly reopen exact candidate. | Fresh process restores saved values. Same-process reload, receipts and synthetic disk reads do not count as real restart. |
| Appearance | Inspect top search/notch clearance, no top page-number label, cell transparency, current wallpaper token and visible rendering. | Distinguish ready/visible compositing from pending ImageIO open. Metadata classification is not a wallpaper fix. |
| Performance / lifecycle | Matched real catalog, viewport, display refresh/build/frame source; compare paging/input/startup, then hide/resize/screen-change/teardown. | Physical 60Hz regression gate and separate 120Hz evidence. >25ms causality stays unresolved unless causally established; screenshots/test counts cannot pass it. |

## Current status
The supported desktop check this turn returned Mac locked. No row is credited PASS by this protocol. Existing source/tests/package evidence and previous candidate-specific native observations remain separately documented. If a test cannot be performed, record the precise missing state/authority; do not reduce the full objective.
