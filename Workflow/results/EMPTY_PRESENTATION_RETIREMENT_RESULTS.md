# Empty Presentation Retirement — Final Results

Date: 2026-10-17
Status: BOUNDED_MAINTENANCE_VERIFIED; full parity objective remains active/incomplete.

## Defect and narrow repair
When presentation becomes empty, the previous zero-range Surface cleanup detached hosts without invoking their existing reuse invalidation. Retained host/page/cell bindings survived, and a controlled late icon completion installed an image into a retired cell. The sole production change is in `Sources/PagingUI/PagingSurface.swift`: remove each host from its parent, then invoke existing `clearForReuse()`. Detach precedes clearing because renderer retirement uses host attachment. Normal nonempty layout, Core, physics, cache bounds and public signatures are unchanged.

The new `Tests/PagingUITests/EmptyPresentationRetirementTests.swift` covers four zero/restore cycles with four pages (one generated item each), retained host/page/cell invalidation and pooled-page reuse; a held generated-icon completion; and neutral-renderer cleanup. This is not a dense 245-item workload, an RSS benchmark, global native-work cancellation or pending-request bound.

## Evidence, including failed attempts
- Actual RED: 3 methods / 74 assertion failures, including one incorrect new neutral-subview expectation. This count is not 74 distinct defects. Late retired-cell image installation is independently recorded.
- Focused r1: 23 tests / 1 failure, the neutral expectation only. Corrected test permits the intended empty hidden page label; no production workaround.
- Focused r2: 29 tests / 0 failures, 0.216s.
- Full XCTest: 2821 tests / 0 failures, 63.720s. The separate Swift Testing zero-test footer is not the XCTest count.
- Debug product: PASS, 0.30s. Actual Release: PASS, 3.54s. Package/native-entry validation and packaged localization (290 keys/signatures × 3 languages): PASS.
- Hubble independent bounded source review: PASS, no actionable findings. Reviewer ran no tests/builds/UI; Main owns execution evidence. Reviewer verified two changed input hashes and nine consulted support hashes, not the full dirty tree.
- Main rechecked all 467 manifest inputs after native smoke: 465 baseline inputs unchanged, one existing production input changed, one test added. Candidate and isolated layout/Library payload hashes unchanged.

## Exact native handover
Own prior 6886de43 test instance/PID63225 was normally Quit through its observed menu; exact executable absence was checked before launch. New unsigned, uninstalled candidate:

`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/empty-presentation-retirement-rc-20261017-r1/LaunchcopyUITest.app`

Executable SHA-256: `aac66f40f03422533372b9ccf31b421f7f15743d791204cbe3d613369905ff75`. Current exact process: PID71120.

CUA observed no-match search, no-results state, clear, original grid restored. An earlier combined folder open/ESC response was truncated; it is not standalone success evidence. Fresh screenshot/glyph click then independently showed folder page1/3 with15 members; one Escape removed folder controls without closing the launcher. Final state: ordinary non-topmost2000×1400px main window, empty query, folder closed. Test instance retained. These observations do not expose internal host counts; the integration tests/source supply that evidence.

Only generated Info-only fixtures and this candidate's own layout/Library payloads were used. No formal data, OS preferences, cache/lock copying, saved personal screenshot files, reference source/assets, installation/signing, process kill or Git commit/reset/clean occurred.

## Remaining boundaries and next action
Wallpaper remains loading/black: NOT_FIXED, cause unresolved. Long-tail hitches, current matched physical performance/120Hz, real IME and spoken VoiceOver are not certified by this stage. Prior user folder-experience acceptance remains scoped to the earlier handed-over build. Main-grid capacity question remains unanswered and proposed specification unapproved; no capacity implementation. Continue on a concrete authorized maintenance issue or actual product decision, without repeating closed gates or fabricating feature approval.

Evidence: `.build/verification/20261017/empty-presentation-retirement/`; final structured receipt `native-handover-r1.json`. Packaging-time `candidate-r1.json` still truthfully records its earlier not-launched snapshot; the native receipt supersedes that status. Independent review: `Workflow/results/EMPTY_PRESENTATION_RETIREMENT_SOURCE_REVIEW.md`.
