# Application Sources and Recursive Watching — Code-Validated Slice

Contract: Docs/APP_SOURCES_AND_WATCHING_SPEC.md, explicitly approved 2026-10-13.
Previous current full checkpoint: material 1928/0; it is NOT sources validation.

## Ownership and concurrency

Main: native settings draft/control consumer, async transactional coordinator,
AppDelegate composition/profile namespace, narrow mutable catalog-root generation
and off-Main per-scan admission. Boyle: independent preferences/store + tests
(published, closed). Cicero: root admission/probe tests. Tesla: native recursive
FSEvents adapter + injected lifecycle/storm tests. At most Main + two workers.
All Swift execution is Main-only. Source review follows implementation; historical
workflow routing is not required. No source borrowing, install/launch/commit/reset.

## Design implementation notes

Canonical custom roots stay in saved preferences when temporarily unavailable.
Every actual refresh re-admits them off Main; a changed symlink/canonical path,
network/unknown locality or unavailable source is excluded, never silently adopted.
An old generation cannot cache/publish a new snapshot after a source transaction.
Existing served presentation/query/layout remains until a successful idle commit.
Source changes discard only pending catalog/folder/search results, not organization.
Manual refresh rechecks watcher availability. Sources without watch coverage are
explicitly degraded, not certified as automatic reappearance coverage. No broad
parent monitoring, permission changes, frame IO or periodic scans.

## Initial gates (historical)

Implementation IN_PROGRESS; no source/full/GUI PASS recorded yet.
Native app access last failed because Mac was locked; Terminal launch remained
policy-denied earlier. Do not route around either failure. Prepared prior runner
is available, but no new sources candidate has been launched or installed.

## Initial execution history (retain failures)

focused-r1: source compile succeeded; test compile failed on integration fake's
internal ScanTask initializer. Fixed test-only @testable import MacAppCatalog.
focused-r2:87 tests,2 assertions failed in a single root-admission fixture. Runtime
Foundation probe established URL(string:absoluteFileURL,relativeTo:base) discards
the base (baseURL=nil); the test had mislabeled it a relative reference. Corrected
fixture and added explicit absolute-URL behavior regression; no admission weakening.
All other tests, including actual native recursive temporary-root smoke, passed.
Source review/full rerun/build pending; do not promote this failed selected run.

full-r1:2016 tests/1 assertion; legacy appearance window expected3tabs, now4.
Updated its expectation and checked the mounted Sources consumer. Main also found
and repaired a pending-query edge: after root switch, re-stage a newer uncommitted
query against the retained served snapshot so failed fresh scans cannot lose input.
Added exact no-fresh-catalog regression; existing active-query pending-discard
contract retained. Rerun/source review/build still pending.

## Review boundary repair wave

Independent review FAIL F1 fixed-profile-root substitution, F2 queued scan after
teardown, F3 first event before asynchronous watcher installation. r1 candidate
fa095956feae415ea9d963e6f63c21e746881f50fab80722b531ba8579811696 and
2017/0 are retained, NOT promoted to source-reviewed acceptance.
Main repairs F1 with shared per-scan/per-watch root-set admission and exact
canonical fixed-profile identity; F2 with permanent data-source closed lifecycle.
Tesla repairs only watcher/readiness tests and new Sendable-function warnings.
Hilbert retains review report and will re-review after source/test stability.
No Swift execution during repairs; no reference source or GUI action.
User confirmed clickable page-dot contract for next slice; do not start before
this repair/review/full/build closeout. Full goal remains active/incomplete.

## Final code-only closeout

- Independent bounded source review r2: PASS for repaired F1-F3, with historical
  FAIL preserved in Docs/APP_SOURCES_SLICE_REVIEW.md. No GUI/performance verdict.
- focused-r6:112/0 at21:09:22.745 JST (includes17 appearance regressions).
- full-r3:2023/0 at21:10:56.996 JST,26.771s;95 Sources cases +1928 baseline.
  Native recursive temporary-root installation invalidation passed,0 skips;
  this is not sustained real-product install/remove GUI acceptance.
- Debug-r2 and Release/package-r2 pass. New watcher Sendable-function conversion
  warnings repaired; existing diagBackend capture warning remains. No zero-warning
  claim. Existing test weak-var warning retained.
-328 source/test/script/resource/package hashes verified post-build; source-files-r2
  and source-check-r2 bind the exact delivery to test/build evidence.
- Unique candidate .build/candidates/app-sources-rc-20261013-r2/LaunchcopyUITest.app.
  Bundle com.launchcopy.test.sources; executableSHA256
  bf4e5a661eec0dd1a4e43e2a045b7250c740d4ed00f1c40b5d5b4c80a62e407f.
  Linker-ad-hoc only, no distribution signing/notarization/installation/launch.
- Manual runner .build/verification/20261013/app-sources/launch-ui-test-r2.command.
 40 metadata-only synthetic bundles:37 Baseline +3 nested Extras. Synthetic profile
  fixed root is Baseline, allowing the sibling Extras root to be selected safely.
  Runner does not reset preferences/layout or stop processes; do not run without
  --ui-test-profile gui. Fixture is not real application launch validation.

GUI/restart/sustained watcher/performance are UNTESTED, not blocked code gates.
Native access last failed on a locked Mac; prior Terminal policy denial stands.
Follow Docs/APP_SOURCES_GUI_VALIDATION_PLAN.md after manual isolated launch/unlock.
All prior failed selected/full runs and r1 candidate retained. No cleanup/commit.

## Next explicitly approved slice

Clickable page dots: user confirmed the specific gesture/drag/title exclusion,
latest-wins ordinary-settle interruption, deferred focus and unchanged physics
contract on2026-10-13. Proposal status updated to APPROVED_CONTRACT. Goodall is
surveying only existing transition/surface/owner interfaces; no page-dot code or
physical PASS claimed. Complete parity goal remains active and incomplete.

Next-slice survey complete: Workflow/results/PAGE_DOT_INTEGRATION_SURVEY.md,144
lines, no implementation. Core/Surface lack public nonadjacent target entry;
focus, lifecycle cancellation and bounded real-renderer reuse need neutral
extensions. Both reviewer and survey helper closed; no active subagents retained.
