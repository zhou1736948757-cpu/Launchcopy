# Wallpaper pipeline integration controls — 2026-10-15

## Delivery and authority

Implemented two new integration controls for Main's serial execution. This is a source-only worker handoff, not a test PASS or wallpaper-loading repair. Read the repository AGENTS.md and Workflow/stage-summaries/2026-10-15-wallpaper-loading.md; the human waived the historical Chief workflow. No subagents were used.

Authorized changed paths (both new):

- `Tests/PagingUITests/WallpaperBackdropPipelineTests.swift`
- `Workflow/results/WALLPAPER_PIPELINE_CONTROL.md`

Production code, package configuration, existing tests, stage summaries, and other contributors' edits were not changed. All shell invocations used the required `rtk` prefix.

## Controls

1. `testColdPipelineReachesReadyWithRenderedDimensionsAndResponsiveMainQueue`
   - Creates an authored, two-color 8×8 PNG and a fresh provider with an initially absent private cache directory.
   - Uses the real `WallpaperBackdropController.backgroundLoader`, real `WallpaperBackdropProvider.blurredWallpaper`, and real controller attached to an in-memory NSView. Only the source resolver substitutes the authored local URL; an observation wrapper forwards requests and completions unchanged.
   - A bounded scheduling gate precedes the actual provider call. After the worker enters, a main-queue heartbeat checks that the controller remains loading with no installed image, then releases the gate. Real PNG decoding, cover transform, Gaussian blur, CGImage creation, and controller application follow.
   - Checks off-main rendering, main-thread completion and state publication, loading → ready, one provider cache entry, output CGImage dimensions, installed bitmap dimensions, logical NSImage size, and visible image presentation.
2. `testRepeatedPipelineRequestsShareProviderImageAcrossWarmRefresh`
   - Submits two refreshes before the main actor yields, through the same real pipeline and provider, then performs a third warm refresh after both initial completions.
   - Checks equal submitted requests, identical returned CGImage references, one cache entry, accepted current-generation ready state, installed dimensions, and retained backdrop while the warm request is pending.
   - Background completion order is intentionally unspecified. Initial callbacks are all awaited; the controller publishes one ready transition for the initial pair and another for the warm refresh.

## Fixture and execution boundaries

At execution time each test creates its own UUID directory beneath:

`.build/verification/20261015/wallpaper-pipeline-fixtures/<UUID>/`

Only the authored PNG and that test's provider cache live there. The helper follows the existing provider-test build-artifact convention and deliberately retains the directory: no deletion or teardown removal is introduced. The provider's asynchronous disk write may complete after controller delivery; the controls do not poll for or assert disk persistence.

No reference directories, raw/personal wallpapers, system wallpaper resolver, OS settings, visible windows, application launch, or native UI automation are involved. The controller still uses current screen geometry (or its existing host fallback) to form its request; assertions derive expected dimensions from that captured request and the production render-scale token rather than a fixed monitor size. The PNG is tiny; output size still follows controller geometry.

The gate wait and XCTest completion timeouts are liveness/deadlock guards only. There are no elapsed-time measurements, latency thresholds, sleeps, or performance claims. The scheduling gate demonstrates main-queue progress while background work is pending; it does not measure UI frame delivery or responsiveness under sustained GPU/CPU load.

## Verification and remaining gates

Source review checked the current provider/controller APIs and the existing provider, controller, and load-state test conventions. Whitespace and bounded structural checks are recorded below after inspection. No Swift command, compilation, test, build, package, or native UI execution was performed; Main owns all serial runtime validation.

Main's next action is to compile and run `WallpaperBackdropPipelineTests` through the project's existing serial test entry, confirm that exactly these two controls execute, and assess failures before broadening verification. Compilation and runtime behavior remain unverified in this handoff.

These controls cover a synthetic local-source pipeline only. They cannot establish readiness of the current real wallpaper source, reproduce or diagnose the observed black/loading candidate, validate source inspection, prove disk-cache persistence, or replace native candidate acceptance. The repeated-request control verifies same-key image reuse through the full pipeline. It does not force overlap inside the provider, count internal renders, or independently prove that its in-flight wait branch executed; existing provider concurrency tests retain that narrower responsibility. No production repair or broader parity completion is claimed.

### Static inspection receipt

- `rtk proxy git diff --no-index --check /dev/null <new-file>` was run for each authorized file: exit 1 with no diagnostics for both, reflecting new-file differences in no-index mode; this is not test evidence.
- A read-only Python structural check exited 0: exactly two test methods, two real background-loader/provider call chains, two synthetic source resolvers, a UUID fixture directory, no `removeItem`, and no elapsed-time measurement assertion.
- A separate read-only whitespace check below verifies final newlines and absence of trailing whitespace for both final files. These checks do not parse Swift or establish compilation.
- Scoped Git status reported both authorized paths as untracked new files. No staging or commit was performed.

Source snapshot SHA-256 values at inspection time (Main must recheck if inputs change):

- `Tests/PagingUITests/WallpaperBackdropPipelineTests.swift`: `fa8b21e24efd7398d1b9065f8ae7968fda6f2b29d59a7a4204e16fe75ee03fab`
- `Sources/PagingPrototypeApp/WallpaperBackdropProvider.swift`: `63f4958112f158f66fd888853f369adb80077971d90008272f77cc6b94fe1a3a`
- `Sources/PagingPrototypeApp/WallpaperBackdropView.swift`: `4261f9b357a976a2fd18c7b7bdbea65beb41eeaa7de4891f8cb1d53ae9d656f7`
- `Sources/PagingPrototypeApp/LaunchcopyVisualTokens.swift`: `b0e33cdf67e3a53385026f39e67508abaeecce3e185ff601f5a54e85ab4f2220`

## Main execution correction (supersedes wrapper assumptions above)
Main actually executed the controls. Initial16-test selection failed with3 failures (one unexpected): NSImage(cgImage:size:) did not expose NSBitmapImageRep and the early throw left the later warm expectation unwaited. Second run failed6 assertions because the public wrapper reported device-dependent2940x1912 pixels while the real rendered CGImage was1029x669. These are harness assumptions, not a production rendering defect. Final helper checks the returned CGImage's actual reduced dimensions, installed NSImage validity/nonempty representations/logical size, and visible view. It deliberately does not assert the wrapper's private pixel mapping. Final focused-r3.log:16tests/0fail,0.304s. No production source changed.

## Independent review coverage boundary
Chandrasekhar accepted this bounded source/test-control slice with no blocking defect. Identical CGImages across requests cannot discriminate obsolete-generation installation; do not cite the repeated-request control alone as generation-guard proof. No additional test was requested for this slice. Reviewer performed no execution. Main full2677/0 and focused16/0 are separate execution receipts.
