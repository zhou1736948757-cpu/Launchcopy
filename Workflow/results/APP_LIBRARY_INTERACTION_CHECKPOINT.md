# App Library interaction — final verified code checkpoint

Date: 2026-10-15.
Full objective: implement desired LaunchBetter UI/functions on Launchcopy through independent code, preserving performance and organization. Goal ACTIVE/incomplete.

## Baseline / scope
Prior bootstrap checkpoint: 2589/0,440 inputs, unsigned isolated executable27bcafb6... .
Current supported desktop entry returned Mac locked. This turn did not open any application or work around desktop/authentication controls.

Main reviewed existing category draft/receipt and Back behavior; no additional defect inferred there. The sidecar audited actual mounted IME/keyboard/accessibility source, found three evidence gaps rather than a proven input defect. Reports remain unchanged history.

## Delivered changes
- Added Tests/PagingUITests/AppLibraryGridReturnIntegrationTests.swift. Actual AppDelegate final catalog callback composition, capture/prepare/restore and mounted fields are used; owner closures are not overridden. Query/field editor restoration and anchor relocation against a new catalog/current page are verified.
- Added two AppLibraryViewTests for category-focus transfer and preserved search composition/results focus.
- Changed only AppLibraryView.layout: capture prior category responder ownership before visibility changes, then remap displaced category focus to its visible counterpart.

The original hypothesis of a retained hidden responder was corrected by additional observed evidence: AppKit moved focus to NSWindow during hiding. Post-hide identity checks therefore failed. Pre-hide capture resolves this mounted-window defect. No search/query/category/action/store mutation, extra scan/IO/task/frame work, or Core/UI physics/default change.

## Test and repair history
| Evidence | Exact result |
| --- | --- |
| New return harness initial compilation | Failed: nested Fixture lacked explicit MainActor; no tests credited |
| Corrected actual-return regressions | 2/0,0.561s |
| Intermediate full suite before focus repair | 2591/0,52.107s; not final patch acceptance |
| Category focus red | 1 XCTest/4 failed assertions, both directions |
| Ineffective post-hide repair | 35/4; composition/results guard passed |
| Mechanism observation | Actual pre-controls and post-NSWindow responder confirmed |
| Final focused repair | 35/0,2.019s |
| Final full suite | **2593 XCTest/0 failures**,45.680s |
| Final Debug/Release/package | Succeeded |
| Packaged localization | 3 languages/274keys and signatures; positive plus two expected negative failures passed |
| Source/executable verification | 441 hashes match;18 PagingCore/PagingUI unchanged; exact executable hash verified |
| git diff --check | Passed |

Tests overlap and must not be summed. Separate Swift Testing runner executed zero tests and is not included in the XCTest count.
Evidence: /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/

## Independent review
APP_LIBRARY_INPUT_ACCESSIBILITY_AUDIT.md: bounded audit, no confirmed source defect initially, E1 real IME chain/E2 focus and native Tab/E3 AX-actions evidence gaps.
APP_LIBRARY_CATEGORY_FOCUS_REVIEW.md: initial correct mechanism review with execution pending.
APP_LIBRARY_CATEGORY_FOCUS_REVIEW_R2.md: independent final **ACCEPT** for bounded category-focus repair after reading Main-owned execution logs and checking source/test hashes.
Reviewer executed zero tests/builds/UI actions. Only category-focus portion is resolved at mounted AppKit/XCTest layer. Real input-method behavior, native Tab, AX actions and VoiceOver remain pending. All agents/jobs closed/completed.

## Exact deliverable
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-category-focus-rc-20261015-r1/LaunchcopyUITest.app
Executable SHA-256:
afa1df6cf2cf58deab1520422a14087a14ac315639cbac057093cbc07a884e9a

Unsigned, uninstalled, not notarized, never started this turn. Dedicated metadata selects candidate-local gui data and an ordinary non-topmost window. Forty independently generated Info-only fixtures are ready; they cannot prove successful app launch. Older candidates and formal data preserved. No commit/sign/install/publish, reference source/assets reads or unrelated process shutdown.

## Remaining full-goal gates
Follow APP_LIBRARY_NATIVE_VALIDATION_PROTOCOL.md after manual unlock: actual default-off/enable/categories/search/details/IME/Tab/AX/manual/Automatic/hide/alias/Back/source refresh/normalQuit and same-candidate restart, then appearance/current wallpaper and matched physical performance/lifecycle.
The protocol credits no native PASS. Prior candidate-specific GUI observations do not certify this executable.
Capacity/anchor, optional bundle-ID, usage consent/suggestions/recent, extra gestures and destructive actions remain separate explicit decisions. Wallpaper source-open cause, >25ms causality, matched60Hz migration regression,120Hz and distribution gates remain incomplete.
This turn is PROGRESS: regression evidence, an actual repaired defect and independently reviewed current candidate. Do not mark full goal complete or blocked while meaningful authorized progress exists.
