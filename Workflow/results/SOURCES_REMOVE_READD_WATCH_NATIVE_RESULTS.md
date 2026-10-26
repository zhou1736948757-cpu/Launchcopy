# Sources removal, restoration and nested watcher: native results

Date: 2026-10-19 (Asia/Tokyo)
Status: bounded native packet passed; full migration and some acceptance gates remain open.

## Exact scope and build

No application source changed and no closed test/build suite was rerun. All 516 source/package inputs still match the prior frozen Sources build. Its executable SHA-256 is `b88e09688a7af10d71bf9f360c42933d90839336f8ef2f5ae8c8cf571e60956b`; previous automated evidence remains Python12/0, focused114/0, full3138/0 and Debug/Release/package/resource checks. That evidence is not a new physical performance result.

Native actions used only the fixed `sources-v1` entry and candidate-local synthetic apps under `.build/candidates/sources-native-fixture-rc-20261019-r1/UITestProfiles/gui`. Main owns all actual CUA observations. Helper worker Herschel wrote only a fixed artifact helper and notes, did syntax checking only, and was closed. Main inspected the whole helper and verified its Darwin exclusive-rename flag against the local SDK before execution. Independent evidence/helper consistency review is recorded separately; it is not an independent native replay.

## Removal and re-addition

1. Normal Finder Open started Source PID88705 after normally quitting only our visual demo. The saved test setup had four owned metadata-only apps, Extras enabled and automatic refresh OFF.
2. An actual pointer drag merged Extra One with Baseline One into Group1. Its saved canonical folder has ID `A265FFCC-9F65-4408-BD99-0BA67C20322C`, ordered members base.one then extra.one. Native management saved `Owned Sources Alias` and hidden ON for Extra Two. Closing Settings showed only Group1 and Baseline Two.
3. Native Remove Extras → Apply reported saved/applied. The visible projection flattened to Baseline One and Baseline Two, but all four application metadata files and the exact canonical layout journal remained unchanged. Management still showed one hidden reference while its app was absent.
4. Re-adding the SAME Extras through NSOpenPanel → Apply restored Group1 with two members. Actually opening it showed Baseline One and Extra One. Management restored the same alias, hidden-checkbox1 and hidden-popup entry for Extra Two; that app remained excluded from the main grid.
5. Before/remove/re-add snapshots are equal: the624-byte journal SHA is `e772131a031ca06eaa6aa6674ef5cb1c1ee8d9890461d2c3f1b8dba7ae6ae370`; folder ID, title, membership, order and four metadata files are retained. Source removal did not delete files or mutate latent organization.

## OFF / manual / ON and nested events

- With saved automaticOFF and a unique query showing no matches, Main exclusively created the owned metadata-only `Source Event Added.app` under Extras/Nested. The bounded observation still showed no matching app. This is a finite observation, not a guarantee about all future callbacks.
- Explicit native Refresh Now discovered that app while retaining the query.
- Native automaticON → Apply reported active/saved. Main established a visible baseline and waited5seconds before changing the fixture, avoiding immediate ON/setup changes as the claimed later event.
- The validated owned app was atomically parked outside Applications but inside its own profile. After3seconds, without manual refresh or preference changes, the same query showed no matches.
- After that independent absence observation and a further3seconds, Main atomically restored the SAME owned bundle. After3seconds the same query showed the app again. A fresh full AX tree confirmed one result and no stale no-result text. No UI refresh/pref action occurred between these two fixture events.
- The event is restored, not deleted; the empty own parking directory is intentionally retained. The helper allows no path overrides, overwrites, arbitrary moves or deletion. Original four app metadata and exact canonical journal stayed unchanged through the event sequence.

## Actual restart and final desktop state

Source PID88705 normally quit and exact absence was verified. The same Finder entry started PID93630: Group1/two members, Baseline Two and the event app appeared, while Extra Two stayed hidden. Native Sources showed automaticON/active; Management showed one hidden reference and the saved alias/hidden entry. PID93630 also normally quit; exact absence was verified.

The human's UNCHANGED large-icon demo was restored through Finder, now PID94664, ordinary window, empty query/folder closed. Its249 seeded files and executable `dc4ed86fbc2912b4c86d27a19e2125e1fa0ca80c462f936a6016431e49e5eaee` are unchanged. Sources fixtures never entered that profile. Its neutral wallpaper diagnostic is ready; this does not repair or explain the previously sampled source-open wait. No personal wallpaper pixels/files were retained in artifacts; CUA inspection was inline only.

## Evidence and honest residuals

Artifacts: `.build/verification/20261019/sources-remove-readd-watch-native/` contains before/remove/re-add/watch/final snapshots, timed owned create/park/restore receipts, OFF observation, `watch-native-r1.json`, `native-results-r1.json` and `closeout-r1.json`. These deliberately exclude raw personal paths/images/preferences. The seeded bundles have no executable: this is catalog/source behavior, not real-application-launch evidence.

Manual Refresh with a deliberately conflicting UNSAVED Sources draft has not yet been contrasted natively; existing unit coverage is not relabeled as that GUI gate. Real trackpad/motion performance,120Hz/multidisplay, real IME/spoken VoiceOver, human main-grid aesthetics, wallpaper causality and full experience parity remain separate. No source patch, reference access, formal data mutation, signing/install/publication, OS/security change, process signal or deletion occurred. Full goal stays active/incomplete; this turn is concrete progress, not a blocked audit.

### Timing precision clarification
The OFF receipt's `seconds_since_create` measures when the receipt was written, not a captured timestamp of the preceding native AX observation. The actual observation followed an explicit5-second wait; no exact discovery/non-discovery latency is claimed. The event command timestamps establish operation order only.
