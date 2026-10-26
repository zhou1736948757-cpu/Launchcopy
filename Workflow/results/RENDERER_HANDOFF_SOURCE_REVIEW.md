# Renderer handoff source review — 2026-10-15

**Verdict: bounded SOURCE PASS.** No actionable correctness findings in the neutral-to-custom startup handoff repair. Confidence is high for the source-level ownership and generation conclusions below. This is not native accessibility, VoiceOver, performance, or full-product acceptance.

**Reviewer-executed tests: 0.** The reviewer ran no Swift command, build, test, application, UI operation, process-control action, or agent dispatch. Main retains serial verification and native acceptance ownership. The sole reviewer-authored file is this report.

## Authority, architecture, and baseline

Read `/Users/mac/.codex/RTK.md`, repository `AGENTS.md`, relevant `Workflow/PLAN.md` and `Workflow/MAIN_BRIEF.md` context, and `Workflow/stage-summaries/2026-10-15-renderer-handoff-accessibility.md`. The human's explicit bounded review packet and Chief waiver govern this review; older freeze and workflow instructions do not expand the assignment or authorize other writes.

This is a Swift Package/macOS AppKit application. `PagingCore` owns paging state/physics; `PagingUI.PageHostView` delegates presentation through `PagingPageRendering`. Each host privately owns a `NeutralPageRenderer`, while the application shares `AppGridRenderer` across hosts and that renderer manages distinct real page views. The repair respects those boundaries.

Independent judgment: the change is a small cleanup of abandoned presentation content within the approved UI bug scope. It does not introduce an ownership architecture, public protocol, page-count policy, or physics change and does not require a new feature specification.

The worktree contains substantial pre-existing changes. Git HEAD is not this slice's baseline: its PageHostView diff also contains earlier localization work. Against `.build/verification/20261015/identifier-search/source-inputs-final.json`, the reviewer independently verified:

- Of the prior 18 PagingCore/PagingUI source files, **17 still match and exactly one intentionally differs: `Sources/PagingUI/PageHostView.swift`**.
- Removing only the five-line conditional/comment/call insertion at current lines 38–42 reproduces that file's prior SHA-256 exactly.
- All other source/test files listed in that prior manifest match; the only new Swift source/test file is `Tests/PagingUITests/PageHostRendererHandoffTests.swift`.

Thus the previous slice's “18 unchanged” statement is historical. This slice intentionally changes one presentational PagingUI file; Core, input, driver, timing, animation, protocol, and remaining UI source are unchanged relative to that manifest.

## Source reasoning and safety checks

| Check | Independent source evidence and conclusion |
| --- | --- |
| Actual startup seam | `Sources/PagingPrototypeApp/AppDelegate.swift:433–434` creates the surface with the default five-page count; `installContentAssembly` assigns the provider and renderer at lines 752–753. `Sources/PagingUI/PagingSurface.swift:92–99` assigns that renderer to existing hosts and refreshes their content. This reaches the repaired setter without requiring host reuse. |
| Root cause | `Sources/PagingUI/NeutralPageRenderer.swift:48–74` attaches its own page label and tiles directly to the host. Before the new setter branch, custom rendering bypassed neutral rendering without retiring these children. `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:336–364` only creates/mounts its own real page views, and returns early for placeholder content. Correct current labels/counts can therefore coexist with an abandoned neutral label. |
| Single content owner after adoption | `Sources/PagingUI/PageHostView.swift:38–42` retires neutral content only on nil-to-non-nil adoption. `NeutralPageRenderer.swift:80–93` removes only recorded `itemViews`, clears their arrays, and blanks/hides its own `pageLabel`. The retained hidden, empty label is not a second active renderer; physical removal of that reusable label is not required by this bounded repair. |
| No arbitrary child removal | Cleanup uses the neutral renderer's private references, never enumerates/removes all host subviews, and does not touch real grid pages or unrelated children. The sentinel assertion at `Tests/PagingUITests/PageHostRendererHandoffTests.swift:34–43` directly protects this distinction. |
| No host reuse or binding invalidation | The setter calls `neutralRenderer.clearForReuse()`, not `PageHostView.clearForReuse()`. Host generation increment, page reset, pending-language invalidation, and custom cleanup remain in the existing host reuse path at `PageHostView.swift:142–153`. No host generation changes on adoption. |
| Shared custom renderer preserved | The new branch never invokes the incoming or outgoing custom renderer. Target binding and generation forwarding still occur at `PageHostView.swift:115–129`. `AppGridRenderer`'s shared pages/pool and retirement policy at `AppCatalogAssembly.swift:318–325, 388–425` are untouched. |
| No recurring frame cleanup | Non-nil-to-non-nil reassignment skips the branch, including reassignment of the same renderer. Existing hosts' normal render/layout methods gain no cleanup call. Assignment for a newly created/adopted host at `PagingSurface.swift:868–880` remains a lifecycle event. Initial custom adoption may initialize the lazy neutral renderer once; this source review makes no measured performance claim. |
| Neutral laboratory preserved | Nil-to-nil assignment does not trigger cleanup. Neutral render/layout and laboratory appearance remain unchanged (`PageHostView.swift:130–136, 160–164, 186–195`; `NeutralPageRenderer.swift:48–76`). A later neutral render can restore its reusable label through the existing render method. This does not certify arbitrary custom-renderer swapping. |

## Tests and existing execution evidence

The new tests exercise actual host children rather than relying on `visibleItemCount`, which intentionally reports zero under a custom renderer even when stale children exist.

- `PageHostRendererHandoffTests.swift:27–49` captures the original label/tile, adopts a custom renderer, checks label retirement and tile detachment, protects an unrelated child, preserves host generation, and verifies target/generation forwarding without custom cleanup.
- Lines 51–71 cover placeholder adoption, deferred current host accessibility text, stale child text removal, same-custom reassignment, and the distinction between adoption and genuine reuse. Genuine reuse still increments generation and clears the custom renderer once.
- Lines 73–106 use the actual `AppCatalogAssembly.AppGridRenderer`, real provider, and production callback installer/idle-commit seam. Forty synthetic records at 35 items/page produce two pages while retaining the initial host. Assertions check both current page labels, a real cell binding generation, and the abandoned neutral label. `Tests/PagingUITests/TestSupport.swift:14–26` confirms this is an unshown surface with manual frame driving; `AppContentTestSupport.swift:72–108` supplies generated icons. This is assembly integration coverage, not a real scanner/native UI run.
- Existing `PageHostBackdropTests.swift:53–99` cover transparency, target binding, resize, and genuine host reuse; lines 101–118 protect neutral laboratory chrome. The new branch leaves those contracts intact.

Read Main's existing logs under `.build/verification/20261015/renderer-handoff/`:

| Log | Observed XCTest evidence |
| --- | --- |
| `red.log` | 2 tests, 6 assertion failures: obsolete neutral label visibility/text and tile retention. These historical test line numbers precede the final test-file layout. |
| `assembly-red.log` | 1 actual-assembly test, 2 assertion failures, both for the obsolete neutral label. Current host/grid two-page labels and binding-generation assertions did not fail. |
| `focused-r1.log` | 63 tests, 0 failures; includes all 3 new handoff tests and all 3 existing backdrop tests. |

These are inspected Main-generated execution records, not reviewer-run results. Their trailing Swift Testing “0 tests” footer is separate from the nonzero XCTest suites and is not counted as a successful test run. The logs support the reproduced mechanism and focused regression result, but do not independently bind a packaged executable to this source snapshot or establish native AX behavior.

## Review snapshot and remaining gates

The eight primary source/test files below had identical hashes at two reads spanning the source review:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingUI/PageHostView.swift` | `65cd891554d66b9c3bd5cac7f1adcfe9e86682053d5298254129b626ba22eb83` |
| `Sources/PagingUI/NeutralPageRenderer.swift` | `56bbf2369bd31b3020b3f6d44d138c46cb82285b723e10683780a556be8cbd78` |
| `Sources/PagingUI/PagingSurface.swift` | `966615670bde489514a734779befae082a3e79b692eab28de83e770c04b3e439` |
| `Sources/PagingUI/PagingPageContent.swift` | `9841126fbc113f3ed8091cb79876e4e22a7352658ad0778f8e14be3965b506b9` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `82f6e12d6427142bdab69c86366f9b655366514a98eceab0955c83b740fb79f5` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `05a5485de9639a33ac5dfe4d0f41de996a8d8f10d5b665d0b3da16e3fe645aee` |
| `Tests/PagingUITests/PageHostRendererHandoffTests.swift` | `3ce053a539962b1d7715e84f256343a3cb89dc5a5253951ba1e11bcaca100e4e` |
| `Tests/PagingUITests/PageHostBackdropTests.swift` | `2580a2c003fa74fa8e9e800c751b4e7d8b06ba7e8271b506acaf2857cfbac550` |

No source revision is requested. Main must separately finish current-source full tests/build/package verification and inspect the supported native candidate for obsolete AX label removal, correct two-page dots, and absence of visible top-page decoration. VoiceOver behavior, physical performance/60 Hz/120 Hz, and broader lifecycle/full parity remain unaccepted by this review. Arbitrary custom-to-custom replacement is outside this startup repair's guarantee.

Execution deviation: the initial read of RTK.md inadvertently used plain `cat`; all subsequent shell invocations were RTK-prefixed. No implementation, tests, other documentation/workflow state, assets, reference paths, or global memory were modified by the reviewer.
