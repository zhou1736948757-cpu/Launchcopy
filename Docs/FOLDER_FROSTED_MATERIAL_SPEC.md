# Folder Frosted Material Specification

Status: PANEL_BUILD_VERIFIED_PARTIAL_NATIVE_OBSERVED_HUMAN_PERFORMANCE_PENDING; EXTERIOR_DEFERRED
Date:2026-10-16

## Superseding user decisions — 2026-10-16
The user explicitly selected blur for both the panel and its exterior, superseding the initial panel-only recommendation below. The user then prioritized performance over this visual feature and authorized omitting exterior blur if its cost is too high. No additional whole-window dimming is authorized. The historical panel-only proposal is retained below as the fallback, not the current requested ideal.

### Performance-first feasibility contract
- Investigate a single low-resolution, in-memory blurred representation of this application's own static launcher background. The folder's member icons, text, editor, controls and drag presentation must stay outside that representation and remain sharp. Exterior blur must include background grid content, not merely reblur the already-blurred wallpaper.
- A shared static blur texture with a restrained translucent panel treatment is a candidate to avoid two overlapping blur passes. This is a hypothesis, not an implemented or benchmarked optimization. Compare against a retained native effect before committing to custom snapshot complexity; native compositing is not inherently expensive or free.
- If testing the snapshot candidate, render directly at bounded low resolution rather than taking a full-resolution screenshot and shrinking it afterward. Reuse the image-processing context. AppKit capture must remain on the main thread; only immutable pixel input/filtering may move off-thread. Off-thread filtering does not erase main-thread capture cost.
- Never capture the display, other windows or applications. Never persist captured pixels, paths, names or image payloads in diagnostics. Bound memory/in-flight work and release invalidated images. No screen-recording permission, periodic recapture, per-frame blur, new animation timer, wallpaper reread or icon rebinding.
- Snapshot only an eligible stable background, not an interrupted outer paging/presentation transform. Key validity to viewport/backing scale, content/appearance/wallpaper revisions and lifecycle generation. Reject stale completions; do not keep old app icons after catalog/visibility changes. Resize, hide, teardown, move-out drag or inaccessible capture falls back without blocking interaction. Do not snapshot the existing live/retained folder exit; preserve its current presentation-aware implementation.
- No waiting for blur before opening or accepting input. Missing/late/failed output must not cause a sudden material switch or black first frame; if coherent transition timing cannot be achieved, omit exterior blur for that opening rather than delay it. Avoid continuous background regeneration while paging or dragging.
- Reduce Transparency disables optional exterior blur and keeps the accessible opaque panel fallback; Increase Contrast and Reduce Motion remain independent policies. No exterior tint/scrim is reintroduced by any fallback.
- Before enabling exterior blur, collect matched baseline/candidate native measurements for opening, inner paging, repeated open/close, resize and idle. Record synchronous capture time separately from filtering, allocation and whole-frame intervals. Include cold/warm runs and representative viewport sizes; compare under the same instrumentation. An apparent low filtering time alone is insufficient evidence.
- Acceptance is no reproducible added opening stall, degraded finger-following/settling, sustained work while static, unbounded memory or black/dark flash. If evidence is missing or shows regressions, ship panel-only glass and record exterior blur as deferred, not as a completed feature. Existing >25ms unexplained tails and pending real gesture acceptance stay unresolved.

Implementation remains pending a concrete feasible design and a proportional confirmation if the resulting architecture materially changes the approved view-only proposal. This investigation may conclude that panel-only is the appropriate delivery; the user has already authorized that fallback. No new product preference question is needed merely to exercise it.

## Execution sequence — 2026-10-16
Implement the already-approved retained native panel background using the original view-only contract first. Normal policy uses a clear panel-host fill and one clipped pass-through within-window popover material. Reduce Transparency or Increase Contrast uses an opaque semantic panel fill with its effect hidden. Park the material inactive while detached, opaque, collapsed or torn down; preserve it while a transparent drawing-only exit remains mounted. Keep the panel/editor host stable. This is not a decision that exterior blur is too expensive; exterior remains unimplemented pending the separate feasibility gate. No snapshot architecture has been approved as production implementation.

## Snapshot feasibility result — 2026-10-16
An isolated copied-package probe executed9 viewport/resolution cases,279 timed own-view captures, plus sibling/grid inclusion checks (1 test/0fail final). At256px output edge main-thread allocation/capture medians were6.38–7.15ms; at512px8.71–10.46ms; at1024px17.73–20.46ms. First captures and context initialization were separately nontrivial. This is an unshown synthetic actual app assembly, not native compositor/physical performance proof. No capture pixels persisted, canonical inputs unchanged.

Do not enable the synchronous AppKit snapshot exterior path in the current candidate. Use the authorized panel-only fallback while exterior remains deferred. This is a scoped rejection of an insufficiently cheap/unverified approach, not evidence all blur methods are too expensive. Retained native material or immutable-model composition alternatives remain unevaluated and require appropriate visual/performance evidence before inclusion. Results and limitations: Workflow/results/FOLDER_BLUR_FEASIBILITY_RESULTS.md.

## Problem, users and outcome
The launcher user rejects the opaque, flat dark folder panel and requests an iOS-inspired frosted/translucent surface with background blur, without the previously rejected whole-screen dimming pulse. Existing adaptive layout is accepted. The goal is a readable floating folder that reveals blurred ambient color, while preserving Launchcopy interaction performance and independent implementation.

## Discovery and evidence
- Current native AppKit/SwiftPM project targets macOS14+. FolderOverlayView retains an ordinary NSView panel with opaque windowBackgroundColor. Removing the exterior dim did not make that panel translucent.
- Existing wallpaper pipeline already renders a blurred wallpaper beneath the grid. Do not blur this full-screen image again simply to simulate a folder material.
- Current463input/2791-green baseline includes the actual startup-order window scroll callback repair. Real two-finger physical acceptance remains pending; the user's recent OK was not explicitly confirmed as both gesture and shadow PASS.
- Apple HIG explains translucency, blur and vibrancy as material properties, distinguishes standard content materials from Liquid Glass controls/navigation, and requires semantic choices and legibility. Apple documentation does not publish SpringBoard folder source code or exact blur/tint parameters. This is an independent visual interpretation, not a verified reproduction of private implementation.
- Native NSVisualEffectView withinWindow blends content behind the effect inside the same app window; behindWindow would instead sample desktop/other windows and is not the intended source here.

## Historical panel-only proposal / authorized fallback
1. Replace only the folder panel's opaque normal fill with a native frosted backdrop. Keep its rounded clipping, a restrained separator/highlight and soft separation, avoiding an opaque black rectangle or clear unreadable pane.
2. Reveal blurred color rather than readable background app names. Foreground member icons and names remain sharp; no blur on the folder's own content.
3. Exterior overlay stays clear. Opening a folder must not add a whole-screen tint or brightness change. Main grid and wallpaper outside the panel retain their current rendering and established baseline settings.
4. Preserve the accepted panel geometry, typography sizing, inner-page capacities/order, navigation, member drag, title draft, outside-close and opening/exit motion. No geometry/layout redesign in this slice.
5. No new appearance setting or persistence schema. First deliver one coherent default material, not an unrequested slider system.

## Non-goals
No full-screen extra blur by default, custom refraction/shimmer, private filters/frameworks, capture of other applications, Apple artwork/resources, whole UI/theme rewrite, new functionality, engine/gesture-parameter tuning or declaration that pending physical paging/performance gates passed. Do not raise the minimum deployment target to26 for a material effect.

## Architecture and interfaces
- Preserve the stable panel/content host and title editor parent identity; add a retained, pass-through native material view at the bottom of that host rather than replacing/remounting content every refresh/frame.
- Use public NSVisualEffectView with withinWindow blending; evaluate the popover semantic material as the initial transient-panel choice. Material selection is not an assertion that Apple folders use this API/value.
- Material bounds follow the panel at layout boundaries only and clip to the same rounded silhouette. Do not place an opaque layer above it or let it capture input/accessibility focus.
- Keep existing applyMaterialPolicy ownership and lifecycle gates. Retained visual-only exit/teardown remains inert; opening, interrupted reversal, moving out and restoring must not produce black fallback frames or leave an active detached effect.
- Reuse the established main-thread UI model. No screenshot loop, per-frame Core Image/CPU blur, extra animation timer, wallpaper reread, repeated icon/name binding, or frame-by-frame preference writes. Native compositor cost still needs measurement; native API use is not a performance guarantee.
- Expected bounded write scope: AppGridUI folder material/view implementation plus material/owner tests. Any required owner change must preserve startup-order route helper and explain why it is needed. Do not touch PagingCore/mapper/frame-source/physics or the wallpaper loading pipeline.

## Accessibility and fallback
Respect Reduce Transparency with an opaque panel-only system-color fallback; never restore an opaque exterior scrim. Increase Contrast must keep readable text and a stronger contour, using a heavier/opaque panel when necessary. Reduce Motion preserves the existing opacity-only transition, independent of transparency. Light/dark appearances and inactive test windows must remain legible and avoid sudden unintended material changes. Do not change system accessibility or appearance settings to prove tests; inject policies in automated coverage.

## Acceptance
- A non-solid native frosted panel is visually evident over bright, dark and busy controlled backgrounds; rear color diffuses while foreground icons/labels stay sharp and readable.
- Exterior brightness stays unchanged on open/close. No unintended rectangular black layer, blur bleed outside rounded corners or visible first-frame material switch.
- Native title editing, Latin drafts and cancel/no-save behavior, keyboard/page controls, inner gesture routing, drag/move-out, interrupted open/close, resize and source replacement remain valid. Existing real Chinese/Japanese IME/VoiceOver gates are not implied by synthetic tests.
- No layout/capacity/canonical-order/schema changes. Outside transparent hit region closes only the folder; drawing-only exits export no input/AX content.
- Frame callbacks do not trigger material creation, CPU filtering, catalog work or repeated icon binding. Compare matched native paging/opening behavior before/after; do not silently accept degraded fluidity for appearance. Record any GPU/compositor or hardware limits honestly.

## Verification and delivery
Test material hierarchy/configuration, clear exterior and policy matrix, stable host/editor, lifecycle/visual-only teardown, no-new-icon-binding invariants and startup-order input regression. Run actual focused/full suites, Debug/Release/package/localization checks and independent bounded source review. Deliver an unsigned candidate-local ordinary/non-topmost test build without installing/overwriting formal data or terminating unrelated apps. Inspect native visuals; passing tests alone do not accept glass appearance or physical smoothness. Retain old candidates and receipts; document results in Workflow/results and stage summary, with project PLAN/MEMORY checkpoint.

## Risks and unresolved decision
Native material tint/opacity is OS- and appearance-dependent; a dark native material can still appear too heavy and needs actual visual calibration. Animated within-window compositing and rounded clipping require native verification. Additional full-screen blur would widen scope/cost and must not be smuggled into this panel-only change.

Original decision request (superseded): panel-only versus additional exterior blur. See the dated user decisions above for the current conditional scope.

## Primary references (accessed2026-10-16)
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/documentation/appkit/nsvisualeffectview
- https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum
- https://developer.apple.com/documentation/appkit/nsvisualeffectview/material-swift.enum/popover
- https://support.apple.com/guide/iphone/organize-your-apps-in-folders-iph822ece7dd/ios

Local guidance: apple-design Skill (materials/depth, reduced-transparency, restraint); adapt its web examples to native AppKit and preserve approved project physics rather than copying unrelated spring constants. write-swift guidance is subordinate to the actual project/toolchain and established conventions.

Additional performance reference (accessed 2026-10-16): https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_performance/ci_performance.html — smaller outputs and context reuse reduce image-processing work; this is not a benchmark of our capture/compositing path.

## 2026-10-16 — Aesthetic acceptance and subsequent motion delivery

The user explicitly accepted the existing folder frosted appearance, then approved a separate glyph-origin opening/closing contract. Aesthetic acceptance does not certify physical gestures, first-frame/flash behavior or performance. Source-origin candidate r2 preserves this material; its native run remained wallpaper-loading, so ambient-colored appearance from the earlier wallpaper-ready run is not asserted for the new build. See `Workflow/results/FOLDER_SOURCE_ORIGIN_RESULTS.md`. Exterior blur remains deferred under the user's performance-first permission.

## Controlled native material check completed (bounded) — 2026-10-16

New current-baseline generated-fixture probe compiled (Debug13.30s) and actually observed through CUA: six glass states (Aqua/Dark Aqua × Bright/Dark/Busy) plus six independent RT/contrast fallback states on Busy, then glass restoration. Rounded panel diffuses busy details while icons/labels stay sharp; RT or contrast yields semantic opaque panel; contrast strengthens border. This is 12 distinct component-native cases, not all24 combinations, OS notification wiring, opening motion or matched performance. Probe-only control strip has poor contrast on opposite-luminance fixtures; do not mislabel it as product chrome. Hume independent source-only admissible/no blocking finding, zero executions/UI, closed. No product code/test/resource changes.

Probe86591 normally quit via own control; exact process absent, closed binding not queried. Current launcher bdb9a6e3/PID82034 retained, freshAX folderOPEN/15members/page1of3/originaltitle/wallpaperready. All464 canonical inputs/candidate/profile hashes unchanged; no system settings/formaldata/install/sign/kill/commit/reference access or saved personal screenshot. Previous/current goal turns PROGRESS (native resize/editor, then controlled material evidence), not a verified job wait or blocked impasse. Report Workflow/results/FOLDER_MATERIAL_NATIVE_MATRIX_R2_RESULTS.md; structured .build/verification/20261016/folder-material-native-matrix-r2/native-results.json. Remaining human actual source-origin/flash/physical gestures and reserved product/hardware/OS gates unchanged; whole goal NOT complete. Do not repeat these closed12cases to stay active.

