# Wallpaper occlusion repair — 2026-09-11

- User authorized direct repair after task-scoped model proposal; permanent model configuration unchanged.
- Primary hypothesis: PageHostView full-page controlBackgroundColor covers the already transparent grid and surface above the backdrop.
- Main orchestrates; sol/high Worker implements, independent Luna/max Reviewer follows.
- Single writer and serialized SwiftPM. Visible watchdog started. No product test or GUI result yet.
- Correction after live Git check: HEAD 6382bd9 now provides a commit baseline; an additional before-file snapshot is retained. No cleanup or reset authorized.
- Next: synthetic red-backdrop regression, minimal host fix, review, Release build and non-destructive candidate delivery.
- Physical wallpaper acceptance remains pending; root cause is not yet proven by rendered evidence.

## Verification update (supersedes initial hypothesis status)

- Confirmed occluding layer: the real PageHostView filled over a synthetic red backdrop. Fail-before screenshot center was dark; pass-after center is saturated red. Main inspected both synthetic images.
- Source change only in Sources/PagingUI/PageHostView.swift: custom renderers use no host background fill; nil renderer preserves neutral laboratory chrome. No input, paging physics, layout, reuse generation, provider, or window-architecture changes.
- New Tests/PagingUITests/PageHostBackdropTests.swift has 3 passing tests. Targeted renderer/seam/assembly set: 24 tests, 0 failures.
- Independent Reviewer: patch-level PASS, Workflow/reviews/T-WALLPAPER-OCCLUSION-r1.md.
- Fresh full suite after patch: 1525 tests, 12 failed assertions across 7 test cases. Isolated HEAD 6382bd9 baseline: 1522 tests, same 12 failed assertions in exactly the same 7 cases. No new failing case observed; the repository is NOT globally green.
- Baseline source extracted to /private/tmp/launchcopy-wallpaper-baseline-6382bd9 without resetting the worktree. All tests run serially. First sandboxed Main run could not write Swift's module cache; authorized rerun produced the recorded result.
- Release build exit 0; existing concurrency warnings remain. Candidate smoke exit 0, telemetry disabled.
- Existing packaged app retained unchanged. Its executable SHA-256: 6cac795194145a63079ca5b1a960e72dc457d6450efa51a1dc3b320f9ebf5475.
- Candidate: .build/wallpaper-occlusion-20260911/Launchcopy.app. Executable SHA-256: e41fc68f53be9655166646ffb8bd95498d81e58f645e4fd79417c4532b461897. No signing/notarization/publication performed.

## GUI boundary

- Main inspected the old running GUI: uniformly dark gray page background, consistent with the synthetic failure (not literally zero RGB).
- Old application exited using its normal Cmd-Q action; no kill/cleanup packaging script used.
- Candidate process started; a read-only process-path check confirmed the candidate executable, not the retained old package.
- Computer Use repeatedly timed out obtaining the candidate window. A one-second process sample showed the main thread in the ordinary application event loop; this is not proof of successful visual composition or physical responsiveness.
- No screenshot of real wallpaper was saved to project artifacts. Only synthetic red images are durable visual fixtures.
- Actual wallpaper GUI acceptance remains PHYSICAL_ACCEPTANCE_PENDING. Do not claim that the user has seen or accepted the new wallpaper.

## Next executable action

### Later same-day observation during cell-fill follow-up

Main successfully connected to the retained wallpaper-occlusion candidate using Computer Use and inspected its live screenshot. Blurred wallpaper is now visibly present behind the grid; this supersedes the earlier tool-timeout-only visibility boundary. Individual app cells still have dark rounded backgrounds, reported by the user and tracked separately as T-WALLPAPER-CELL-FILL. No real screenshot saved into the repository; no phase-wide physical or paging acceptance inferred.

User opens/focuses the candidate bundle and checks that blurred wallpaper appears behind icons, then pages forward/back and reopens the launcher. If dark background persists, continue from the candidate identity and inspect remaining compositing layers; do not re-tune blur based on cache output alone.

Existing full-suite failure set (outside this patch; same before/after): AppLaunchControllerTests.testClickHitPathReachesCell; Bug10PreviewHostTests.testMoveOutBarAndPreviewShareOverlayCoordinateSystem; Bug11RowBoundaryIndicatorTests.testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor; Bug9CellHitRoutingTests.testHitTestAtBackgroundReturnsCell; Bug9CellHitRoutingTests.testHitTestAtNameLabelReturnsCell; DragCommitIntegrationTests.testTwoMemberFolderMoveOutShowsRemainingAppProxyThenDissolves; T1FD1FixUITests.testPreviewShowsSourceCellIconAndName.
