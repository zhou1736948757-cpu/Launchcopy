# Folder Material Native Matrix R2 — Independent Source Review

Review recorded: 2026-10-16T22:53:00+09:00

## Scope and verdict

**Source-only verdict: admissible for the bounded, manually observed production-folder material-policy matrix; no confirmed blocking source defect or safety violation found in the reviewed harness. Native execution and visual acceptance remain unverified by this review.**

This is an independent source review of an already approved verification harness, not approval of a new implementation or a native PASS. The project is a macOS 14+ Swift Package using AppKit, Core Animation, and modular production UI/domain/icon services. The probe is a separate copied-package executable that assembles the existing production view with generated data. Production changes are outside this task.

The project `AGENTS.md` and `/Users/mac/.codex/RTK.md` were read. The user's explicit Chief-workflow waiver and bounded reviewer assignment govern this review. No agents were created. The sole authored file is this report; shared implementation and workflow state were not edited or reverted.

## Source identity and permitted deviations

Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

Copy: `.build/experiments/folder-material-native-matrix-20261016-r2/Package/`.

Baseline: `.build/verification/20261016/folder-source-origin/source-inputs-r3.json`.

A read-only Python SHA-256 comparison examined the manifest's 464 entries, without importing project code or executing tests:

- Canonical repository: 464/464 present and matching the manifest at the audit snapshot.
- Copied package: 464/464 present; 463 matching; the sole manifest-listed mismatch is the authorized copied `Package.swift`.
- A textual comparison of canonical and copied `Package.swift` shows exactly one added line, copied line 14: `.executableTarget(name: "FolderMaterialProbe", dependencies: ["AppGridUI", "AppCatalogCore", "AppIconPipeline"]),`.
- Within copied `Sources/`, `Tests/`, `Resources/`, and `Scripts/`, the sole additional file outside the manifest is `Sources/FolderMaterialProbe/main.swift`.
- The material/layout/pipeline/appearance source paths inspected in the copy resolve inside that copy and are not symlinks to canonical files.

| Input | SHA-256 at review snapshot |
| --- | --- |
| Source-origin r3 manifest | `3a63895941faa4521425d3bbf69c5ba1a141f9e3304815fa6f02b2a366beac60` |
| Canonical `Package.swift` (manifest value) | `f9a62774751745b8cbd0aa7b3ed98be2f08e12ba5545824fb7df5549e3e9986a` |
| Copied `Package.swift` | `8a6fe666e7934bbfab2cc24276e079f8098d17d7f235ab41c2d700768f46ee76` |
| Copied `Sources/FolderMaterialProbe/main.swift` | `77763d3d204a7a2cd965f641e9278f85e86dda2d33717e14ecb100a8740421e6` |
| Canonical and copied `Sources/AppGridUI/FolderOverlayView.swift` | `e91e50e70beb81220e5ff026d4c99b3fea491101694ed393dec2a11adc4da289` |

These are source snapshots, not binary provenance. They do not establish what executable Main subsequently builds or launches. Any later source change requires rechecking the relevant hashes and conclusions. No whole-tree Git diff or dirty-tree review was performed.

## Findings

No confirmed severity-rated defect was identified that invalidates the requested fixed-fixture material-policy matrix or crosses the stated safety boundary. This conclusion is bounded by the following source evidence and claim limits; it is not a claim that all product behavior has been reviewed.

### Production view and same-window backing

Evidence uses copied `Sources/FolderMaterialProbe/main.swift` line numbers, and matching canonical `Sources/AppGridUI/FolderOverlayView.swift` line numbers:

- Probe lines 57–58 construct the production `IconPipeline` with a generated loader and instantiate the imported production `FolderOverlayView`. There is no substitute panel or probe-defined material implementation.
- Probe lines 78–83 mount a generated backdrop below the overlay under the same window content view. Lines 109–115 size the backdrop to the root and apply the production `FolderLayoutPolicy` to the overlay. Controls and status occupy the reserved upper strip.
- Production overlay lines 398–425 construct a stable content panel and a native `NSVisualEffectView` with `.popover`, `.withinWindow`, rounded clipping, and content siblings above the material. The overlay and glass-mode panel backgrounds are clear. This is the correct source arrangement for testing generated same-window content behind the panel, rather than desktop wallpaper or another window.
- Production lines 29–45 reconcile native material activity with mount/rendering permission and keep the decorative material out of hit testing and accessibility children. Production lines 1299–1323 size the material to the actual panel.

This establishes intended composition and production-code reuse. It does not prove actual compositor sampling, blur quality, corner rendering, readable text, or aesthetic fidelity on the host.

### Appearance and matrix injection

- Probe lines 63–65 hold independent appearance, Reduce Transparency, and Increase Contrast switches. Lines 25–45 provide three generated backgrounds: bright gray, dark gray, and a busy tiled/text fixture. No external artwork or application icons are loaded by the generated loader at lines 7–20.
- Probe lines 122–136 set `window.appearance` to `.aqua` or `.darkAqua` and explicitly execute `overlay.applyMaterialPolicy(...)` within `performAsCurrentDrawingAppearance`. That scope matters because production lines 486–495 resolve semantic `NSColor` values into layer `CGColor` values. Every probe toggle reapplies the policy; background selection also requests redraw.
- Independent switches and a three-state backdrop cycle make 2 × 3 × 2 × 2 = **24 selectable combinations**, starting at Aqua/Bright/RT OFF/Contrast OFF. This is source reachability, not evidence that 24 cases were exercised.

The production policy predicts:

| Reduce Transparency | Increase Contrast | Panel path | Border policy |
| --- | --- | --- | --- |
| OFF | OFF | Native material visible and rendering allowed while mounted | Separator color, width 1 |
| ON | OFF | Material hidden/inactive; opaque window-background fill | Separator color, width 1 |
| OFF | ON | Material hidden/inactive; opaque window-background fill | Label color, width 2 |
| ON | ON | Material hidden/inactive; opaque window-background fill | Label color, width 2 |

Thus six selectable combinations request the glass path; eighteen request the opaque fallback. Both flags still need independent observation even where their opaque fill behavior overlaps. The status at probe lines 129–130 reports requested settings, not measured native renderer state or automated assertions.

### Isolation and termination ownership

- The copied target depends on UI/domain/icon modules, not `PagingPrototypeApp` or `MacAppCatalog`. The probe does not instantiate launcher startup, catalogue scanning, persistence, login services, shortcut registration, or product preference owners.
- Fixture identities, names, icons, and backdrops are generated in memory. `GeneratedIconLoader` is explicitly injected, so the production system-icon loader is not selected by this assembly. The relevant pipeline constructor and loading path (`IconPipeline.swift:171–193,343–354`) retain the supplied loader and use an in-memory cache. Default cache/concurrency bounds are defined in `IconCache.swift:8–22`.
- Probe lines 70–76 use an ordinary, normal-level titled window. Lines 106 and 145–150 request accessory activation policy and order the window behind other windows; there is no explicit application activation, make-key request, fullscreen takeover, global input monitor, or OS appearance/accessibility preference mutation in the probe.
- Probe lines 137–141 use `NSApp.terminate(nil)` for the probe's quit button or its own window close. This targets the current executable's application instance; no external PID, application identifier, shell kill, or cross-process termination operation is present. Termination calls overlay teardown followed by pipeline shutdown. Production `FolderOverlayView.swift:650–686` invalidates the view and removes member cells; `IconPipeline.swift:319–333,385–390` cancels in-flight work, clears cache/observers, and gates queued callbacks after shutdown.

This is source-level isolation evidence, not a guarantee of zero ordinary framework-managed macOS state, nor an inspection of Main's packaging or launch commands. Isolation depends on Main launching the separate probe executable and preserving its process identity. An external launcher that instead starts the product or terminates processes by broad name matching is outside this review and must not be justified by it.

## Claim limits and risks for Main's native evidence

1. **Policy injection is not OS accessibility integration.** The booleans directly call the production view seam. This does not exercise workspace accessibility notifications, actual System Settings changes, or the production observer/owner wiring. The host compositor may also respond to existing host accessibility settings independently of these injected booleans. An OFF label alone does not establish that the host allows translucency. Main should record host conditions without changing preferences and qualify any restricted glass observation.
2. **No native coverage ledger or assertion exists in this harness.** Controls and status make manual cases identifiable, but there is no automatic sweep, screenshot capture, render-state assertion, or completion verdict. Main must associate observed evidence with each requested combination and allow AppKit redraw/composition to settle. A status string alone is insufficient evidence of the resulting material.
3. **Generated fixtures bound aesthetic conclusions.** The busy background uses semantic system colors; its rendered palette can vary by appearance/OS. These are representative generated fixtures, not real wallpaper, another product's evidence, or proof of origin-opening fidelity. Identical generated app icons and static folder content do not test the full visual diversity of installed apps.
4. **Settled material scope only.** The probe configures a static folder with Reduce Motion enabled (lines 100–103). It does not wire the production launcher owner callbacks for member launch, title editing, paging, or close behavior, and does not drive origin-based open/close transitions, detached reuse, drag/move-out, or window lifecycle animation. Those omissions do not invalidate this material matrix, but any corresponding runtime or glass-plus-origin acceptance claim would exceed its evidence.
5. **Layout and screen claims stay bounded.** The probe applies production geometry and exposes resizing; it does not independently validate member reconfiguration when capacity changes, display scale changes, multi-display behavior, or minimum-size behavior. Keep comparative material captures at a recorded stable size. This review does not certify adaptive folder integration.
6. **Visibility and process observations belong to Main.** Accessory policy and `orderBack` can leave the probe obscured. Source does not prove visibility, key status, successful startup, graceful exit, or preservation of the currently running launcher. This reviewer performed no process actions and left the existing launcher untouched.

## Verification performed and remaining gates

Performed: bounded text inspection, manifest parsing, SHA-256 comparisons, copied-package extra-input enumeration, path-resolution checks, and the one-line package diff. These are source checks, not builds or tests. Canonical material and directly relevant layout/icon code were read only where needed to interpret the copied harness.

Not performed: compilation, package execution, tests, UI interaction, screenshot inspection, process enumeration or control, OS-preference changes, signing, installation, deletion, reset, or commit. LaunchBetter, Buho, and original evidence were not read. No source review result here asserts native PASS or approves aesthetic acceptance.

Main retains ownership of build/package identity, launch safety, per-combination native evidence, visual review of the approved glass-plus-origin requirements, user acceptance, and final results. No implementation repair is requested by this source-only review.
