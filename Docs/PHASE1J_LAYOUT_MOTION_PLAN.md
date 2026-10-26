# Phase 1J: Grid Layout and Folder Motion

Status: DRAFT_FOR_USER_CONFIRMATION. No implementation authorized by this document alone.
Date: 2026-09-12
Owner: Main, discovery and proposed implementation gate; Chief review remains pending.

## 1. Goal and Boundaries

Improve content placement and make occasional Folder transitions spatially legible for existing Launchcopy users. Preserve the accepted launcher, paging, keyboard, search, drag, persistence, and activation behavior.

Authority: PHASE1J_CHECKPOINT.md, especially sections 3 and 4. The retracted Dock observation supersedes the older handoff's instruction to reduce a black slab. The Dock is not an application defect. The user-accepted idle-cell transparency repair stays closed.

No paging physics, frame source, Timer.tolerance (0ms), capacity (35, five columns/seven rows), persistence schema, icon-hit padding, drag intent policy, signing, notarization, publication, or source-provenance expansion. Do not read LaunchBetter, BuhoRebuild, reverse-engineering dumps, or their assets for this slice.

## 2. Current Evidence

- Swift Package, macOS 14 minimum, AppKit/Core Animation. AppGridUI depends on PagingUI and catalog/icon modules; it cannot import the executable target.
- AppGridPageView currently uses five columns, 88pt cells, 16pt spacing, 24pt side/bottom inset, and 96pt top reserve. Its row positions are top anchored.
- FolderOverlayView is in Sources/AppGridUI, not Sources/PagingPrototypeApp. MotionParams.standard is 0.18s/0.96/8pt; reduceMotion is currently 0s/1/0pt.
- AppDelegate.refreshFolderOverlay configures and mounts immediately; closing clears content, removes the overlay, and restores the drag visual host immediately.
- Close also cancels dragging and ends title editing. Existing move-out proxy and click-routing contracts make delayed interactive-overlay removal unsafe.
- Current checkout is dirty. Existing source, packaging, tests, workflow files, and untracked artifacts must be preserved.
- Handoff records 1530 tests/0 failures and the phase1j-rc-20260911 candidate. These results and candidate hash have not been rerun or independently verified during this discovery.

## 3. Proposed Product Decisions Requiring Confirmation

1. Keep 48pt icons, existing label styling, five columns, and row-wise horizontal centering. This slice changes placement, not a visual theme or icon redesign.
2. Ordinary pages use one shared seven-row geometry envelope, centered in the usable region. Partial ordinary pages retain the same row positions as full pages to avoid vertical jumps during paging.
3. Search results may center their actual occupied rows, preserving existing horizontal centering. Identify search mode explicitly through existing assembly state, not by guessing from item count.
4. Usable space excludes application chrome and relevant screen safe margins. Convert screen geometry into host coordinates once; avoid subtracting Dock/menu exclusions twice. Keep full-screen coverage and wallpaper unchanged. Prefer bounded content margins over following transient Dock animation.
5. Use existing 88pt/16pt dimensions when they fit. When seven rows do not fit, derive bounded row spacing/cell geometry while preserving label and icon clearance. Establish the minimum supported viewport from actual cell layout before implementing a clamp; do not hide overflow behind negative frames or silently reduce capacity.
6. Pointer-triggered Folder entry uses existing 180ms/0.96 defaults and a strong non-bouncy ease-out, with the source folder as spatial reference. Close reverses the path in 180ms. No scale(0), frame animation, or new animation dependency.
7. Keyboard-initiated open/close remains immediate, following the motion-frequency guidance. Escape immediately cancels/settles an in-flight transition and restores correct interaction. Pointer reversals resume from presentation values without lockout.
8. Reduce Motion for pointer transitions uses an explicit short opacity-only fade (proposed 180ms), identity transform, and zero displacement. This intentionally changes the existing zero-duration parameter contract and requires targeted tests and rationale. Keyboard transitions remain immediate.

## 4. Architecture and Lifecycle

### Geometry ownership

Introduce a small testable grid metrics value/helper in AppGridUI. Keep reusable geometry independent from LaunchcopyVisualTokens in the executable. Application assembly injects safe-region/search-mode inputs where needed. Avoid a new target or reverse module dependency.

Cell frames, click targets, drag geometry, keyboard focus, and folder source lookup must use the same resulting layout. Keep icon-plus-4pt hit regions and member row-band semantics unchanged. Validate source identity and convert actual visible cell geometry into overlay coordinates; never derive origin from a persisted index alone.

### Motion ownership

Keep panel/scrim presentation in FolderOverlayView or a narrowly scoped AppGridUI helper. AppDelegate supplies transition reason and source geometry and preserves logical lifecycle ownership. Extend MotionParams instead of introducing unrelated animation constants.

Use Core Animation transform/opacity with explicit final model values. Sample the presentation layer before retargeting. Keep a separate transition generation so stale completion callbacks cannot remove a reopened folder or a newer folder's view. Content refresh and inner-page changes must not replay entry animations.

Logical close remains immediate: cancel drag, end editing, clear logical folder state, restore the visual host, and remove the interactive overlay. If an exit visual is retained, it must be a bounded noninteractive presentation surface, excluded from hit testing/accessibility and detached on completion, cancellation, hide, or teardown. Do not persist screenshots or title/icon data. Chief must approve the exact implementation before dispatch because this intersects historical click routing.

Folder dissolution, drag move-out, launcher hide, and teardown should use immediate cleanup, not decorative exit delays. Missing/invalid source geometry falls back to fade rather than animating toward an unrelated cell. Screen/size changes invalidate or settle motion before recomputing geometry.

## 5. Task Graph and Ownership

- L0: Main records this proposal; user confirms product choices; Chief reviews lifecycle/interface design and creates bounded task packets. No business-code edits before both gates.
- L1: Geometry Worker owns AppGridPageView, a narrow grid metrics helper, and new geometry tests. AppGridCellView is conditional scope only, requiring an explicit packet if needed.
- L2: Motion Worker owns FolderOverlayView, a narrow motion helper, and focused motion tests after the shared input contract is accepted.
- Integration: one Worker owns AppDelegate wiring and integration tests after L1/L2. LauncherWindowController changes only if necessary for safe-region input; Package.swift remains unchanged.
- L3: Independent Reviewer checks stable diffs and evidence; serialize SwiftPM builds/tests. Run focused suites, full suite, and debug/release builds with executed counts and exit codes.
- L4: Re-read safe packaging script, create a unique new candidate, preserve old candidates, record executable SHA and exact build identity. No default process termination or replacement of the installed app.
- L5: Update checkpoint/validation and stage summary with code, automated, reviewer, and manual outcomes separately. Do not promote LOCAL_RC_VALIDATED while required gates remain pending.

Concurrency: L1/L2 may overlap only after contracts are fixed and write sets/test resources are disjoint. AppDelegate integration and shared build/GUI resources are serial. Recheck current Workflow config, STATE, active jobs, and available role tooling before dispatch. Do not treat the old Phase 1E MAIN_BRIEF as the current Phase 1J task graph or fabricate Chief/Reviewer approval.

## 6. Acceptance and Verification

- Geometry: empty/1/5/6/34/35 items; full and partial ordinary pages share rows; search placement explicit; small/current/large viewport; nonzero coordinate origins; safe margins; no negative dimensions, clipped labels, or chrome overlap at supported sizes.
- Interaction regression: icon hit regions, blank click, focused cells, typing/navigation, drag reorder, folder in/out and two-member dissolution use actual new frames. Do not change fixtures merely to conceal altered product contracts.
- Motion: expected transform/opacity/duration; source conversion; missing source; open-close-open; A-to-B replacement; stale completion; refresh during entry; source removal; hide/teardown; Reduce Motion; keyboard instant path; no residual event-blocking view.
- Run tests with nonzero executed counts. Recorded baseline is 1530/0, not a substitute for current execution. Explain any baseline drift before attributing failures to this slice.
- Capture labeled pre-change and post-change visuals with each exact executable hash, matching screen/viewport/content conditions. Never describe different builds as the same candidate. Post-change visual and interaction checks must use the newly packaged candidate.
- User checks grid spacing/readability, first-to-last page stability, search placement, Folder origin/feel, rapid reversal, Escape, drag, and Reduce Motion. Screenshot evidence cannot establish smoothness or physical gesture acceptance.
- Preserve A-D pending items and accepted/retracted distinctions. This slice does not establish 120Hz support, fix unresolved >25ms frame tails, or certify release readiness.

## 7. Delivery and Resume Point

Deliver bounded source/test changes, independent review, exact verification logs, a preserved new candidate, and an updated stage summary under Workflow/stage-summaries. Keep implementation parameters and rationale together; avoid parallel token systems and duplicated geometry math.

Current resume point: proposal written; user confirmation and Chief review pending. No code edited, agents dispatched, tests run, candidate built, or GUI acceptance claimed by this document. After confirmation, inspect current runtime state and record the stage summary before role dispatch.
