# Renderer handoff repair checkpoint — 2026-10-15

## Current status
Bounded source repair, serial automated verification, independent source review and initial native AX/visual repair check are complete. The full independent reference-experience goal remains ACTIVE/incomplete. This is not whole-product, VoiceOver, physical performance or distribution acceptance.

## Root cause and change
At startup the default five-page NeutralPageRenderer attached its own children directly to retained hosts. The real AppGridRenderer later adopted those hosts without retiring neutral content. Correct current two-page host/grid/dot labels coexisted with an abandoned five-page child label. This is ownership cleanup, not page-count arithmetic.

Only `Sources/PagingUI/PageHostView.swift` production code changed relative to the identifier candidate: on nil-to-non-nil renderer adoption, call the existing neutral renderer's clearForReuse. It only retires its own children, never all host children; does not call host reuse or bump incoming binding generation; does not clear the shared custom renderer or run on repeated custom assignment. No general custom-to-custom replacement guarantee is added. Added three real host/assembly regressions in `Tests/PagingUITests/PageHostRendererHandoffTests.swift`.

Exactly one presentational PagingUI source intentionally changed; the remaining 17 prior PagingCore/UI sources match. All PagingCore, physics, input/driver, timing/animation and current parameter code remain unchanged. The prior identifier slice's 18-unchanged statement is historical, not this repair's result.

## Evidence
- RED: 2 XCTest / 6 assertion failures; real assembly RED: 1 / 2; retained in evidence.
- Main focused: 63 / 0; full XCTest: 2633 / 0, 50.830 s. Debug and Release/package completed successfully.
- Strict packaged localization: 281 required keys in three languages; positive exit 0; missing identifier key and invalid identifier signature negative probes exit 1.
- All 446 frozen input hashes reverified after native run; no mismatch. Dirty preexisting work preserved; diff check passed.
- Independent bounded SOURCE PASS: `Workflow/results/RENDERER_HANDOFF_SOURCE_REVIEW.md`. Reviewer executed zero tests; Main owns run evidence.

## Candidate
Unsigned, uninstalled isolated entry:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/renderer-handoff-rc-20261015-r1/LaunchcopyUITest.app`
Executable SHA-256: `1d9d1caada6a77ab14aad364a09f59a2a92a7071ce7d2ea534885897d95dd51f`.

## Supported native observations
Opened only own isolated candidate, ordinary non-topmost window with 40 generated Info-only fixtures. Initial full AX tree has no obsolete Page 1 of 5 / Page 2 of 5 neutral labels; current navigation correctly says page 1 of 2 and exposes two dots. Inspected screenshot has no visible decorative page number at top. Fixtures are not executable application-launch evidence.

Native forward/back dot navigation was NOT accepted in this run: both dots stayed disabled even after supported Raise, search click and title-bar click. Source requires a visible key window and active application, but actual failed prerequisite was not instrumented; do not assert a cause, relax safety guards or change OS preferences. Tab alone left focus unchanged and does not establish a Tab defect. Wallpaper remained loading/black here, so prior candidate's eventual ready observation is not evidence of recovery for this one.

Own exact PID 47505 was verified. After first menu Quit, immediately querying native state yielded a new window and exact PID 48937; preserve this tool/relaunch observation rather than claiming same-process survival or persistence acceptance. Repeated normal menu Quit without another native query; exact executable process check returned exit 1/no PID. No kills or unrelated app changes.

Evidence: `.build/verification/20261015/renderer-handoff/` (red/focused/full/build/package logs, source manifest, packaged resource results, native-results.json, before/intermediate/final exact process records). Native images/AX were inline observations, not saved image artifacts.

## Next work and boundaries
Identifier search remains implemented and natively checked in its prior exact candidate; this repair does not rerun all of that matrix. Use the latest candidate for any subsequent regression. Real IME/Tab/VoiceOver/Japanese visual matrix, broader Library/lifecycle acceptance and matched physical performance remain distinct. Capacity/rows/columns and other unapproved branches remain pending; no silent feature expansion. No installation, signing, publication, commit, reset, cleanup, reference-source/resource reads or formal-data mutation. Long-tail >25ms remains unresolved; 120Hz gate unchanged.
