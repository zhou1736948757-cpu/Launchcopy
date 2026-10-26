# Icon/type Grid consumers: preliminary source review

Status: PRELIMINARY_SOURCE_FINDINGS; final acceptance withheld. 2026-10-13.
Only this report was written. No source/test edits, Swift invocation, application,
preferences, reference-product files or assets were changed by this reviewer.

## Scope and stable inputs

Reviewed the four Grid consumer sources and two new test files listed below against
the latest approved `Docs/ICON_AND_TYPOGRAPHY_SPEC.md`, including its display-only
48pt request-key amendment and compressed-default fitting exception. Consulted
`Workflow/results/ICON_TYPE_INTEGRATION_SURVEY.md` as independent prior discovery,
not current implementation or runtime proof. Read only the relevant existing
TestSupport and IconPipeline callback seams to establish fixture and actor semantics.
Owner/preferences/renderer and DragUIVisuals implementation remain outside this review.
Existing dirty work was preserved; no additional agents were dispatched.

All four production files and GridItemAppearanceTests matched the initial hashes on
repeat inspection. Main changed GridAppearanceConsumersTests during review; its
layout-fixture adjustment was reread and the revised hash is recorded separately.

## Actionable findings

1. **P2: proxy fallback completion can mutate a frozen exit visual.**
   `Sources/AppGridUI/FolderOverlayView.swift:723-728` discards delivered generation
   and tests only proxy object identity and collapsed state. Create an uncached
   remaining-member proxy, call `setVisualOnly(true)`, then deliver its fallback
   result: `setVisualOnly` keeps the proxy and collapsed state, so the image write
   remains permitted. The ordinary member path correctly rejects visual-only
   results at line 861. This is an inherited fallback-path defect, not an extra
   request caused by the new appearance setter. Root cause: incomplete lifecycle
   gate. Recommended repair: reject frozen/torn-down completions, check the request
   generation and current proxy binding, and retain same-key completion across
   display-only updates. Add a delayed proxy completion test covering freeze,
   clear/replacement, resume and teardown. Affected scope: existing proxy callback
   and bounded consumer tests. Regression risk: accidentally suppressing valid
   live proxy icons or introducing size-specific requests. Confidence: high from
   source; no runtime reproduction claimed.

2. **Frozen appearance behavior needs an explicit ownership reconciliation.**
   `Sources/AppGridUI/FolderOverlayView.swift:108-125` propagates appearance and
   visibility even while visual-only. Revised
   `Tests/AppGridUITests/GridAppearanceConsumersTests.swift:439-445` explicitly
   expects the frozen member's policy to change. Subsequent layout can therefore
   change its frames/fonts, and visibility changes hide captions immediately.
   The approved contract requires obsolete exit visuals to remain stable and be
   cancelled before appearance application. Main should establish an owner test
   proving cancellation/exclusion before fan-out, and document this setter's
   precondition; alternatively guard frozen updates and reassert current policy
   after resume. Do not treat the current consumer test as proof of exit stability.
   This is an integration gate, not a finding about unreviewed owner code.

## Source checks without new defects identified

- Fitting 100x88 defaults resolve exactly to icon `(26,28,48,48)`, name
  `(2,0,96,14)` and count `(2,14,96,12)`; count font remains 10pt.
  Geometry bounds/caption reservation and the approved compressed exception are
  localized to `GridItemAppearance.swift:30-58`. Nonfinite input components are
  sanitized; negative dimensions collapse to zero. Tiny captions compress and
  empty icons reject padded hits (`AppGridCellView.swift:268-275`).
- Hidden captions preserve full bound accessibility name/help; font assignment is
  conditional on point-size change (`AppGridCellView.swift:184-186,278-289`).
  Equal/invalid appearance setters return without content or binding work.
- Page live/new/retained/reused cells receive policy at
  `AppGridPageView.swift:50-58,245-264`; folder members/proxy creation/reattachment
  receive it at `FolderOverlayView.swift:108-125,163-176,691-694,807-825`.
  These paths do not render/rebind or issue icon requests on appearance changes.
  Existing requests retain 48pt default keys and unchanged seven-field tokens;
  page/member callbacks retain generation and teardown gates.
- No new tasks, IO, scanning or application-preference dependency were introduced
  in these setters. Geometry is synchronous, returns value frames and queries
  system font metrics without mutating views; it is not Foundation-only arithmetic.
  Views inherit NSView actor isolation; pipeline completion is explicitly
  `@MainActor @Sendable` (`Sources/AppIconPipeline/IconPipeline.swift:222,387`).
  Sendable geometry values do not authorize off-main view access. Strict-concurrency
  build acceptance awaits Main's actual build evidence.
- Appearance paths leave outer page/folder cell placement, capacity, drop frames,
  folder whole-cell activation and ordinary icon-plus-4 hit routing unchanged.
  The survey's pre-existing folder outer-row overflow remains outside this slice;
  inner content fitting does not establish universal outer viewport fit.

## Evidence and remaining gates

Read Main's `.build/verification/20261013/icon-type/focused-r1.log`: 83 executed,
7 assertion failures (6 layout-cleanliness assertions in one Grid consumer case,
1 preview weak-source assertion outside this scope). GridItemAppearanceTests:
10 executed/0 failures; owner and preferences suites: each 8 executed/0 failures.
These are initial-candidate results, not a passing current integrated candidate.

Main's revised consumer fixture drains page/overlay/child layout and asserts clean
children before applying equal/invalid policies; post-setter assertions remain.
This preserves the intended product assertion. Read `fixture-r2.log`: 2 executed/0
failures, including the Grid equal/invalid case and the separate preview case.
The Grid fixture issue is resolved without production changes. Also read
`focused-r3.log`: 85 XCTest cases executed/0 failures; the separate Swift Testing
0-test footer does not negate that XCTest execution. Both new Grid suites passed.
This broader run does not establish the missing frozen-proxy fallback gate or
resolve the explicit frozen-setter ownership contract. Final acceptance remains
withheld pending Main remediation/evidence and the remaining delivery gates.

New geometry tests cover finite tiny/compact/preference extremes but contain no
NaN/infinity/negative-bounds cases. Add those focused cases before claiming that
edge coverage. Current font checks verify point sizes, not assignment counts;
the conditional assignment budget is source-supported, not instrumented runtime
proof. Main must return exact-candidate nonzero focused/full tests, Debug/Release
and diff-check evidence after publication freeze. Owner/renderer and drag review,
real GUI/VoiceOver/restart and physical performance gates remain separate.

## Reviewed SHA-256 fingerprints

| Input | SHA-256 |
| --- | --- |
| Sources/AppGridUI/GridItemAppearance.swift | `75f831d583be163d98f3dc306bdd34d1bf04a7da17b4b51ec3ac368674aeb8d4` |
| Sources/AppGridUI/AppGridCellView.swift | `48a9c4aa4a3155523dc9d1ccc613043ef724d05917c52aa567c7e3182593b670` |
| Sources/AppGridUI/AppGridPageView.swift | `b0061ca9910fdc944b44cefaa1dfcb612b85113365eb8593a39fb6fe03c034cf` |
| Sources/AppGridUI/FolderOverlayView.swift | `22949d1641570bf96f256d6f53a45031001df8aa65af7910326427d4e5c8f903` |
| Tests/AppGridUITests/GridItemAppearanceTests.swift | `9c8ffbb2723c901c238932a88bddd72285582c14b18f00761029f7402fe3f612` |
| Tests/AppGridUITests/GridAppearanceConsumersTests.swift (initial) | `2daa56599cc5a01e30756d2f90e1b01f5b630855fecd61c90e7ee5663e9356b8` |
| Tests/AppGridUITests/GridAppearanceConsumersTests.swift (Main fixture revision) | `354d47c822e78eee36b7e0c9cc0ea3bc023860db83b99a2770c722d7f8d33f7e` |
| Docs/ICON_AND_TYPOGRAPHY_SPEC.md | `707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da` |
| Workflow/results/ICON_TYPE_INTEGRATION_SURVEY.md | `0bf196706c868aa8be822dd736812ccfd79cc05800de793c09d4c20911bee54b` |

Any production change requires a new bounded review of the affected bytes.

## Main follow-up — repair review pending

Main confirmed focused-r3 85/0, including two folder-motion boundary tests,
and acknowledged finding 1. Main will make a bounded proxy callback guard repair
with a regression before full verification and return the repaired input hash.
Original findings, fingerprints and initial red evidence above remain historical
evidence. No repaired bytes have been reviewed yet; no GUI acceptance is claimed.

## Bounded repair source inspection — awaiting added regression

Reread `FolderOverlayView.swift:108-127,725-735` and the revised consumer freeze
case at `GridAppearanceConsumersTests.swift:439-452`. Both original findings are
addressed in source: frozen/torn setters restore the old policy without fan-out;
proxy fallback checks current and delivered generation, delivered key, captured
binding, proxy identity, collapsed state and frozen/terminal lifecycle before
writing. Display-only updates still preserve valid existing keys/tokens and do
not issue requests. Resume requires the owner to reassert accepted policy, which
the revised consumer test now does explicitly. No new source defect identified.

Inspected repair hashes:
- FolderOverlayView.swift: `9318cb8cc3d5ebc987c4710f63e9574d2af11518170f498ddecdb859233ca2b5`
- GridAppearanceConsumersTests.swift: `b482a20f6d5a313836d18fe4bd8bdda4e7b3ca2bafba7512d8b80b2016c2c7c3`

The other four scoped inputs still match the original hash table. Main is adding
the delayed frozen-proxy regression; it was not present in this test snapshot.
This source repair inspection does not transfer focused-r3's 85/0 to new bytes.
Final bounded verdict awaits the completed test input and actual rerun evidence.

## Final bounded source verdict — repaired Grid inputs

Verdict: SOURCE_REVIEW_CLEAR for the four specified Grid sources and two new
test files at the hashes below; no remaining blocking defect identified in that
bounded source scope. This supersedes the preliminary disposition, not its
historical evidence. It is not overall implementation/build/GUI acceptance.

Finding 1 is CLOSED: the fallback gate at `FolderOverlayView.swift:725-735` now
rejects frozen, terminal, obsolete-generation/key/binding and replaced targets.
Read the added regression at `GridAppearanceConsumersTests.swift:583-627`; it
exercises frozen, cleared, replaced and torn-down proxies and a fresh completion
after resume. Its existing live-proxy test still checks valid late same-key
completion and no added requests for appearance updates.

Finding 2's consumer portion is CLOSED: both setters reject frozen/torn policy
changes, and the freeze/resume test now expects stable old policy and captions
then explicitly reasserts new appearance after resume. Owner exit cancellation
and safe-boundary application remain Main's separate integration responsibility.

Directly read `focused-r4.log`: 108 XCTest cases/5 assertion failures overall,
while GridAppearanceConsumersTests passed 15/0 and GridItemAppearanceTests passed
10/0, including the new proxy regression. The remaining failures are:
- `Tests/AppGridUITests/AppearanceLabelsTests.swift:248`: its old test still
  expects a caption to unhide during `setVisualOnly(true)`. The bounded source
  repair intentionally rejects that operation. Main should align this existing
  test with the now-explicit frozen contract and assert resumed reapplication.
- `Tests/PagingUITests/IconTypographyOwnerTests.swift:268,270-272`: four failed
  assertions in the new retained-exit integration test. Owner implementation and
  fixture diagnosis are outside this review; Main must resolve them before
  integration acceptance. No assumption of a fixture-only cause is made.

Main's full tests, Debug/Release, exact-candidate delivery and GUI/physical gates
remain open. Nonfinite geometry test coverage and instrumented font assignment
counts retain the limitations recorded above; source sanitization and the
conditional assignment were reviewed, not promoted into runtime measurements.

Final repaired input SHA-256 (checked again after reading the regression/log):

| Input | SHA-256 |
| --- | --- |
| Sources/AppGridUI/GridItemAppearance.swift | `75f831d583be163d98f3dc306bdd34d1bf04a7da17b4b51ec3ac368674aeb8d4` |
| Sources/AppGridUI/AppGridCellView.swift | `48a9c4aa4a3155523dc9d1ccc613043ef724d05917c52aa567c7e3182593b670` |
| Sources/AppGridUI/AppGridPageView.swift | `b0061ca9910fdc944b44cefaa1dfcb612b85113365eb8593a39fb6fe03c034cf` |
| Sources/AppGridUI/FolderOverlayView.swift | `9318cb8cc3d5ebc987c4710f63e9574d2af11518170f498ddecdb859233ca2b5` |
| Tests/AppGridUITests/GridItemAppearanceTests.swift | `9c8ffbb2723c901c238932a88bddd72285582c14b18f00761029f7402fe3f612` |
| Tests/AppGridUITests/GridAppearanceConsumersTests.swift | `93a39c84dd355779f89d6fe87b2814dd8bf6a31f06ea4d7ee272f4a7da8230cf` |

Only `Docs/ICON_TYPE_GRID_SOURCE_REVIEW.md` was written by this reviewer.

## 2026-10-13 contract correction and r5 checkpoint

Reread the repaired Folder guards and both relevant Grid consumer cases. All six
scoped hashes still match the final repaired table. Reread only the legacy label
assertion correction at `Tests/AppGridUITests/AppearanceLabelsTests.swift:244-257`:
it now requires the caption to remain hidden while frozen and additionally checks
that stored `showsAppLabels` remains false. Generation, request statistics and
post-resume accessibility assertions remain. This is a dated correction of an
old expectation that contradicted the approved frozen-exit contract, not removal
of the assertion or weakening of accepted product behavior. Legacy test SHA-256:
`458a6936a18377f1ea79678bc9361cd8fdb6d81b0d14b86b08e7ef867fd4487b`.

Main reports the owner exit fixture lacked a committedPageProvider and therefore
correctly selected synchronous fallback without a source anchor. Main wired the
actual renderer provider and drained root/overlay layout while preserving exit
assertions. That owner diagnosis remains attributed to Main; owner source was not
independently audited in this bounded review.

Read focused-r5.log: compilation stops at IconTypographyOwnerTests.swift:32,
where the provider closure must return Int but weak surface access yields Int?.
This attempt provides no executed-test acceptance evidence. Source review remains
clear for the unchanged scoped inputs; the requested final r5-based closeout is
withheld until Main corrects this fixture type and returns an executed rerun.
Original findings and all r1/r4 failure history above remain preserved.

## 2026-10-13 final repair closeout — focused-r6 evidence

Final bounded repair verdict: SOURCE_REVIEW_CLEAR; both original Grid findings
are CLOSED, with no remaining blocking source finding in the assigned four
consumer sources and two new test files. This supersedes the pending r5 closeout.
All prior findings, hashes, failed attempts and contract corrections remain
historical evidence above. Only this report was changed by the reviewer.

Revalidated `FolderOverlayView.swift:108-127,725-735`: frozen/torn setters preserve
stored policy and captions; proxy fallback enforces lifecycle, generation, key,
binding and current-proxy identity before writing. Reread the frozen consumer
case and delayed proxy regression at `GridAppearanceConsumersTests.swift:439-452,
583-627`. Existing same-key live completion and display-only zero-request
semantics remain intact. The six current hashes still match the final repaired
input table. The legacy contract correction hash is also unchanged.

Directly read `.build/verification/20261013/icon-type/focused-r6.log`: selected
XCTest suite PASSED at 23:43:55.344 JST, 108 executed/0 failures, 14.730 seconds
(14.755 wall seconds). Grid consumer tests: 15/0; geometry tests: 10/0. The delayed
proxy regression (four lifecycle cases plus resume), corrected old frozen-label
test and actual retained-exit owner test all passed. The 0-test Swift Testing
footer is separate from the verified nonzero XCTest suite. Owner success is
observed test evidence, not an expansion of this Grid source audit.

The source manifest has 340 nonempty input entries. Compared all six scoped
files plus the legacy corrected test against it and current working-tree bytes:
all seven match. The other manifest entries were not individually audited here.
Manifest SHA-256: `a328f0e91f6d881b9b0ddef9e3837f7332ace507adacf28c868ec23660a5aec7`.
Focused-r6 log SHA-256: `2aabe43632066efaea8b7e22a6867d3a1b8b21f56edbe46f5a51a0753320a9ea`.

Full-r1, standalone Debug/Release builds, GUI/VoiceOver/restart, raster display
quality and physical performance remain pending/separate acceptance gates.
No overall product acceptance or GUI PASS is claimed. The explicitly noted
nonfinite-test and font-assignment instrumentation limits remain unchanged.
