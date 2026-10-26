# Folder Blur Probe — Source and Measurement Review

Date: 2026-10-16

Verdict: **DISCOVERY ONLY, WITH MEASUREMENT LIMITATIONS. No native, performance, visual, or production acceptance.** The updated r2 source is suitable for a bounded synthetic investigation of capture/filter costs. It does not establish that exterior blur is cheap, visually correct, or ready for integration. Main owns results interpretation and the next design action. The authorized panel-only fallback remains available.

## Scope and evidence

Reviewed the copied `Tests/PagingUITests/AdaptiveFolderOwnerTests.swift`, its `Fixture`, relevant copied test helpers and assembly/owner initialization, `Workflow/stage-summaries/2026-10-16-folder-blur-feasibility.md`, and `Docs/FOLDER_FROSTED_MATERIAL_SPEC.md` (especially lines 6–23). This is an AppKit/SwiftPM macOS 14+ project with an existing provider/renderer, icon pipeline, folder owner and retained native panel material. The probe reuses those components rather than substituting a standalone grid renderer.

Source snapshots of the copied test:

| Revision inspected | SHA-256 | Review status |
| --- | --- | --- |
| r1 | `f2ce583a5715f7a953f872bfb1c210da7c234abd237c9b7931f69f9c2d5e0783` | Original 1024-edge, three-viewport probe; inspected before Main's correction. |
| r2 | `84849a21766c2fcb9c65bcc16ea56676cd41edaa5c51183f6cc10c9f282c58b8` | Updated source in the same experiment directory; inspected after Main's correction. Line references below use this revision. |

The canonical test hash observed was `aa296e6625db38e768ba365ff3d46a4c6d3f03110dd464da005162be31560135`. The inspected r1 versus canonical test diff added only the CoreImage import and experimental test. This review did not independently recertify the complete 463-input copy or candidate binary. Candidate `05c415a0` remains Main's canonical production candidate; this review performed no candidate operation.

Main reports r1 executed one test with three failures, all from counting 40 retained cells as 35 visible cells; it also reports roughly 17–20 ms capture medians at the 1024 limit and a first CI call near 186 ms. These are **Main-provided failed-run observations**, not independently inspected execution evidence or a PASS. Main preserved r1 source/log and started r2. This review neither waited for nor assessed r2 execution results.

## What the instrumentation establishes structurally

- **Direct bounded destination:** lines 67–77 allocate the destination bitmap at the requested pixel limit, set its point size to the host bounds, and call `cacheDisplay` directly. There is no explicit full-Retina capture followed by resizing. r2 tests edges 256/512/1024 across three viewport sizes. This bounds the explicit destination, not AppKit's internal backing stores, intermediate allocations, traversal work, or total memory.
- **Own-content assembly:** the fixture manually supplies synthetic catalog records and generated icons, installs the actual provider/renderer and folder wiring, and creates an unshown app-owned window. The probe then closes the folder, confirms its overlay is detached, replaces the top-level presentation with 35 apps, and inserts its own generated 64×64 background plus a sibling search field. This is stronger than wallpaper-only filtering, while bypassing production startup and real wallpaper/catalog loading.
- **No external capture or pixel persistence in the inspected path:** the probe has no display/window screenshot API, window ordering/activation, OS event injection, real wallpaper read, or captured-image file write. Output is scalar JSON. Assembly scanning is not started by this fixture, the icon loader is injected, and no persistent layout store is installed. Pixel buffers exist in memory, including validation comparisons. This is a source-path finding, not a system-wide I/O audit.
- **Separate timed intervals:** allocation/main-thread capture and the subsequent CI API sequence have distinct timers. `@MainActor` covers both, so this is expressly a synchronous probe, not a demonstration of worker filtering or responsive interaction.
- **Context reuse:** one CIContext is constructed outside all nine cases. r2 records its constructor wall time and labels the shared context and missing GPU/upload coverage explicitly. No arbitrary timing threshold converts successful assertions into performance acceptance.

## Findings and interpretation limits

### F1 — r1 visibility failure is a counting error; r2's correction has a bounded meaning

Evidence: r1 filtered only hidden state. r2 lines 123–128 additionally intersects each converted cell bounds with root bounds and records retained and visible counts separately. Main attributes the extra five cells to retained offscreen next-page content.

The correction addresses that specific false failure without deleting retained cells or changing production behavior. It remains a geometric intersection count, not proof of on-screen rendering: ancestor clipping, opacity, occlusion and actual pixel coverage are not measured. Partial intersection also counts as visible. The fixture's fixed layout is a reasonable bounded use; do not generalize `visible_native_cells` into native window acceptance.

`waitUntil` in copied `AppContentTestSupport.swift:115–126` calls `XCTFail` on timeout. Ignoring its returned Bool therefore does **not** silently pass. However, that failure is nonterminal: the probe can continue measuring and print JSON, just as a failed cell-count assertion can. Main must associate every row with the actual XCTest outcome and label failed-precondition rows diagnostic only. Source confidence: high.

### F2 — r2 fixes false cold labels, but cannot create system-cold measurements

Evidence: r1's 31 samples followed three functional captures, yet sample zero was named `cold`. r2 lines 85–88 rename it `first_after_inclusion_checks`, retain a remaining-sample median, and lines 130–132 separately time the first validation capture for each fixture.

These changes correctly narrow the claims. That first validation is first for this capture helper/fixture, after fixture construction, layout, folder open/close and icon delivery; it is not first process/system rendering. Only the first CI filter across the entire run is first use of the shared context. Constructor timing does not isolate later lazy initialization, compilation, allocation or cache population; the first CI call can contain those costs. Later cases inherit context/process/framework caches.

Viewport order and edge order are fixed. Warm-up, thermal drift, external compile activity and scheduler load can correlate with later/larger cases. The 31 sequential samples are descriptive repeated measurements, not independent cold trials. `p95_all` is the 30th sorted sample, and the current remaining median chooses the lower central value of 30 samples rather than their average. These details matter if values are compared closely. Confidence: high for source ordering; runtime bias magnitude unmeasured.

### F3 — inclusion deltas are useful smoke checks, not full pixel correctness

Evidence: lines 133–141 hide the search sibling and surface in separate captures, then require a nonzero whole-image byte delta. The generated backdrop has no corresponding hide/delta control. CI output is checked for dimensions and pixel limit only.

A passing delta shows that a visibility change affected output; it does not prove all 35 glyphs/captions, intended layer composition, backdrop coverage, spatial alignment, or sharp foreground exclusion. Some changing pixels, incidental redraw differences, or only part of the grid can satisfy it. There is no repeated identical-state control or region-specific expected-color check. All generated icons are identical solid 48×48 blue squares (`AppContentTestSupport.swift:82–108`), which further limits fidelity conclusions.

Likewise, the test never verifies that the filtered output contains the expected blur rather than merely a valid-sized CGImage. The detached-folder assertion establishes source exclusion for this static fixture, not exclusion during opening/reversal/retained exit or a future production composition. Keep these as inclusion smoke checks; stronger scalar region checks could be considered by Main if needed without saving pixels. Confidence: high.

### F4 — timer boundaries omit material end-to-end costs

Evidence: the loop times bitmap allocation, `cacheDisplay` and CGImage extraction first; then CIImage creation, clamp/filter/crop, `createCGImage` and output assertions. Both run on the main actor. The autorelease pool exits after the timed values have been computed.

The first field is a combined allocation/capture API wall time, not isolated drawing time. The second is a CI API wall interval, including test/assertion overhead; the field name `synchronous_ci_render_ms` must not imply a separate measurement of all GPU work. There is no explicit completion/readback instrumentation for the filtered result or final presentation. This does not prove that `createCGImage` does no GPU work or returns before rendering; it means the probe does not independently account for GPU scheduling/completion and subsequent display use.

Neither field accounts for complete object release/autorelease draining, worker scheduling, queue transfer, texture upload for presentation, layer installation, compositor blending, frame presentation or input-to-visible latency. Snapshot validation/key construction and production invalidation are absent. `one_rgba_buffer_bytes` measures one image's row storage only: the three validation captures remain live through sampling, and input/output, framework caches and intermediates may coexist. It is neither peak RSS nor an in-flight memory bound.

Do not sum separately summarized medians or percentiles and label the result an end-to-end percentile. Matched per-iteration elapsed totals would be needed for that narrower statistic. Confidence: high for timer omissions; actual deferred/GPU/internal allocation behavior unmeasured.

### F5 — reduced pixel count does not isolate equal-quality savings

Evidence: all edges/viewports apply `CIGaussianBlur` radius 12 in output-image coordinates. Scaling the result back to the same host makes that correspond to different point-space blur radii. At a 2560-point longest edge, the nominal radius maps to approximately 120 points at edge 256, 60 at edge 512 and 30 at edge 1024.

The nine cases therefore compare bounded synthetic workloads, not matched visual effects. Low-resolution rasterization also changes text/icon fidelity. AppKit may still traverse/draw the same hierarchy and process existing source/backing resources at every limit; capture time need not scale with output pixel area. Unchanged content and a shared CIContext can benefit from reuse, while synthetic simple imagery can underrepresent real image work. Native compositor behavior can differ in either direction. Confidence: high for scale mismatch; caching effects and cost direction unmeasured.

### F6 — no compositor, transition or lifecycle acceptance is exercised

The copied `makeSurface` helper explicitly sets `frameDriver = nil` (`TestSupport.swift:14–26`). The test captures an unshown, static, closed-folder background and never installs the blurred output. It does not exercise native material comparison, 1×/2× display transitions, color/appearance variants, representative wallpaper detail, opening/closing coherence, resize fallback, gesture contention, generation cancellation, hide/teardown image release, Reduce Transparency behavior, energy/idle cost, or first-frame black/brightness changes.

The spec explicitly requires these independent gates before enabling exterior blur. Their absence is appropriate for this discovery task, but blocks any promotion to native/performance acceptance. No claim of retained-native-effect superiority or snapshot superiority follows from this probe. Confidence: high.

## Handoff to Main

Preserve r1 as a failed diagnostic run. r2 source addresses the visibility predicate and misleading cold labels and improves accounting, but its execution outcome remains outside this review. Even a successful r2 run establishes only the bounded synthetic assertions and API costs described above. A large capture cost is a warning about this path, not proof that all exterior blur designs are expensive; small filter costs alone do not establish feasibility.

The specification authorizes omitting exterior blur if evidence is missing or costs/regressions are unacceptable. Main can choose that fallback without a new preference question. This report neither makes that decision nor approves a production snapshot architecture. The stage summary's inspected pending-implementation text predates the r1/r2 updates; Main should reconcile its final execution evidence and next action in its own closeout.

Review actions: source/document reads, one test-file comparison and source hashes only. **Zero builds, tests, performance runs, UI operations, reference-project reads or agent dispatches.** No interaction with scratch session 11590. The only file written by this review is `Workflow/results/FOLDER_BLUR_PROBE_SOURCE_REVIEW.md`; no probe, production source, candidate, state, stage summary or formal data was changed. No source changes are recommended as already authorized production work.
