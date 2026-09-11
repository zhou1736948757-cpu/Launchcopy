# Phase 1I — Independent Visual System and Product Polish

> Status: **APPROVED — 2026-09-11** (Gate 0 + wallpaper whitelist)
>
> Decisions: `Workflow/decisions/2026-09-11-phase1i-gate0-approved.md`
> Route B whitelist + digest: `Docs/PHASE1I_VISUAL_REFERENCE_DIGEST.md`
> Provenance: `PROVENANCE/PHASE1I_SOURCE_ACCESS.md`
>
> Project root: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
>
> Purpose: turn the functionally mature AppKit launcher into an independently identifiable,
> maintainable, accessible, and performance-safe product interface before release-candidate freeze.
>
> This prompt does **not** authorize release, signing, notarization, upload, Git publication,
> destructive cleanup, or access to Buho reverse-engineering evidence.

---

## 0. Executive mission

You are the Main/Orchestrator for Phase 1I of Launchcopy, a native macOS launcher built with Swift 6,
AppKit, Core Animation, and Swift Package Manager.

Phase 1A through Phase 1H established paging physics, real app content, keyboard navigation, search,
folders, drag and persistence, resident activation entries, four-finger inward-pinch activation,
settings, Launch at Login integration, and local `.app` packaging.

The main launcher surface is still visibly prototype-oriented in several areas: system-default
backgrounds, fixed geometry values, neutral folder presentation, generic focus treatment, placeholder
or absent product iconography, and incomplete visual-state documentation. Packaging this directly as
a release candidate would freeze an unfinished product expression.

The Phase 1I outcome is therefore:

1. establish one independent visual language for the complete launcher;
2. translate that language into reusable AppKit/Core Animation tokens and components;
3. apply it consistently to every user-visible state;
4. preserve all accepted behavior, identity, persistence, and performance contracts;
5. produce reproducible visual, accessibility, and physical-device evidence;
6. document provenance so no third-party visual expression is silently imported;
7. close the remaining Phase 1H visual product-shell debt that belongs in this phase;
8. prepare, but do not start, Phase 1J release-candidate validation.

This is not a cosmetic reskin. Treat visual architecture, interaction feedback, accessibility,
rendering cost, and source provenance as product contracts.

Communicate with the user in Chinese. Write specifications, ADRs, code, comments, test names,
filenames, and technical artifacts in English unless a user-facing localized string or an existing
repository convention requires Chinese.

---

## 1. Mandatory Gate 0: reconcile the real repository

### 1.1 Do not equate a user completion statement with every evidence gate

The user reported that Phase 1H is complete. Record this as:

```text
USER_REPORTED_PHASE1H_COMPLETE
```

Treat it as important product acceptance input, but inspect the repository before declaring a
formal state.

At the time this prompt was authored, live repository evidence showed:

- `Workflow/STATE.json` still reported the older
  `PHASE1G_AUTOMATED_COMPLETE_PHYSICAL_PENDING` state;
- no Phase 1H tasks were represented in that state file;
- `Docs/PHASE1H_CHECKPOINT.md` reported Gate 0, settings/apply work, Launch at Login support,
  composition, and unsigned local packaging as completed;
- the recorded focused Phase 1H verification was 55 tests with zero failures;
- the checkpoint still listed an app icon, editable shortcut recorder, independent Reviewer, signed
  or notarized artifact, and inherited Phase 1G physical gates as remaining;
- `Scripts/package-app.sh` assembled `.build/packaged/Launchcopy.app` with the public name
  `Launchcopy` and bundle identifier `com.launchcopy.app`;
- `ADR-014-PACKAGING-AND-DISTRIBUTION.md` was accepted but remained a short readiness ADR rather
  than proof of release eligibility;
- the repository had no commits and appeared as an all-untracked Git working tree, so ordinary Git
  diff could not establish a trustworthy source baseline.

These are authoring-time observations, not guaranteed current facts. Re-read everything.

### 1.2 Gate 0 required reads

Before changing code, read at least:

- all applicable `AGENTS.md` files;
- `MEMORY.md`;
- `README.md`;
- `Package.swift`;
- `Workflow/config.json`;
- `Workflow/STATE.json`;
- `Workflow/events.jsonl` entries relevant to Phase 1G and Phase 1H;
- `Workflow/PLAN.md` and `Workflow/MAIN_BRIEF.md`;
- `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md`;
- `Docs/PHASE1H_CHECKPOINT.md`;
- `Docs/PHASE1H_PRODUCT_SETTINGS_AND_PACKAGING_READINESS_PROMPT.md`;
- `Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md`;
- `Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md`;
- `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`;
- `Docs/ADR-014-PACKAGING-AND-DISTRIBUTION.md`;
- the existing UI source under `Sources/AppGridUI`, `Sources/PagingUI`, and
  `Sources/PagingPrototypeApp`;
- all tests that cover grid rendering, folders, search, focus, drag visuals, presentation,
  activation settings, and packaging;
- the current packaged app metadata and bundle contents if the artifact exists.

### 1.3 Gate 0 reconciliation output

Create or update:

```text
Workflow/stage-summaries/2026-09-11-phase1i-visual-productization.md
Docs/PHASE1I_CHECKPOINT.md
```

Record separately:

| Layer | Required status |
|---|---|
| Phase 1H implementation | Current source-backed state |
| Phase 1H automated validation | Exact fresh or explicitly historical count |
| Phase 1H independent review | PASS, FAIL, or NOT_RUN |
| Phase 1H manual GUI acceptance | User statement plus exact tested scope |
| Phase 1G physical debt | Preserve every still-unrun item |
| Packaging | Local unsigned, signed, notarized, or released — never merge these labels |
| Git baseline | Commit-backed, manifest-backed, or unavailable |

Do not fabricate task dispatches, reviews, test counts, binary hashes, or physical gates.

### 1.4 First-response approval stop

Before product implementation, provide the user with a concise Chinese decision packet containing:

1. Gate 0 findings;
2. the proposed Phase 1I scope and non-goals;
3. the visual-source and ownership decision in section 4;
4. the proposed visual direction and appearance modes;
5. the app-icon plan;
6. expected source write sets;
7. performance and accessibility gates;
8. what remains deferred to Phase 1J.

Ask the user to approve or amend the specification. Stop before modifying product source. Updating
planning documents and recording the decision packet is allowed before approval.

---

## 2. Product and risk objective

### 2.1 What this phase is reducing

The project originated from behavior research, but the delivered product must have its own visual
expression and engineering identity. Phase 1I reduces the risk that a user sees the final product as
a visual clone of another launcher.

The target evidence chain is:

```text
Observable launcher behavior
        ↓
Independent behavior specifications and Swift implementation
        ↓
User-owned or newly designed visual system
        ↓
Launchcopy-specific AppKit components and assets
        ↓
Provenance, screenshots, review, and physical acceptance
```

This phase does not provide legal advice or guarantee freedom from claims. It creates a clearer
engineering and provenance record and removes unnecessary expressive similarity.

### 2.2 What visual independence means here

Visual independence requires more than changing a color:

- distinct background composition and depth hierarchy;
- coherent typography and label behavior;
- independently chosen spacing, sizing, radius, and icon treatment;
- independent search, folder, pagination, hover, focus, drag, and empty-state expression;
- independent launch/show/hide motion where motion is appropriate;
- an original or user-owned app icon and menu-bar symbol;
- product-specific copy and accessibility language;
- no third-party screenshots, resources, source strings, or exact animation parameter sets in the
  shipping bundle.

Behavior such as pagination, keyboard navigation, search, drag, or folder semantics may remain, but
their user-visible expression must come from the approved Phase 1I system.

---

## 3. Frozen behavioral contracts

Visual work must not silently change these contracts:

1. Existing app enumeration and stable app identity.
2. Existing 5×7 capacity unless a separately approved responsive-layout ADR explicitly changes
   presentation without changing persistence identity or page semantics.
3. Existing page order, folder membership, drag/drop mutations, and persisted layout schema.
4. Existing search result ordering and pagination.
5. Existing typewriter-style keyboard navigation inside and outside folders.
6. Existing focus seeding, Escape priority, Return/Enter launch semantics, and blank-click behavior.
7. Existing drag threshold, edge paging, drop intent, transaction commit/cancel behavior, and
   persistence timing.
8. Existing launcher show/hide/quit lifecycle and single presentation coordinator.
9. Existing status item, Dock reopen, shortcut, Hot Corner, Launch at Login, and four-finger routing.
10. Four-finger inward pinch shows; outward spread does not hide.
11. Existing catalog/icon asynchronous cancellation and stale-write protections.
12. Existing page reuse and generation protections.
13. `Timer.tolerance = 0ms` production default.
14. Existing paging thresholds and settle parameters unless an independently approved performance
    task later changes them.
15. `SHORT_TAIL_MITIGATED_BY_TOLERANCE` applies only to the recorded short tail.
16. `CAUSALITY_UNRESOLVED_FOR_GT25MS` remains true.
17. No visual test may be “fixed” by weakening behavioral assertions.

If a visual design cannot be implemented without changing one of these contracts, stop and create a
decision delta. Do not hide a product-semantics change inside a style patch.

---

## 4. Visual source, ownership, and access decision

### 4.1 Sources that remain prohibited

Do not open, inspect, quote, copy, summarize, or use:

```text
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/evidence/
/Users/mac/Projects/BuhoReverseNotes/
any Buho binary, decompiler output, Objective-C dump, screenshot set, resource, string table,
address map, report, or activation-related material
```

The prohibition applies to Main, Chief, Worker, Reviewer, visual reviewer, temporary scripts, and
generated prompts.

### 4.2 LaunchBetter is not automatically unrestricted

The project history states that LaunchBetter is user-owned and was intended as the visual source.
That history does not by itself establish which files, assets, third-party dependencies, fonts, or
design fragments can be transferred into Launchcopy.

At Gate 0 ask the user to confirm one of these routes:

| Route | Meaning | Recommendation |
|---|---|---|
| A — behavior-only inspiration | Do not read LaunchBetter UI source; design a new system from the requirements | Lowest provenance coupling |
| B — user-owned visual reference | Read a narrow approved whitelist and independently reimplement the visual language | Recommended if ownership is confirmed |
| C — explicit asset/code transfer | Copy only specifically enumerated user-owned assets or components | Requires a transfer manifest and license audit |

Do not interpret “LaunchBetter is mine” as permission to copy every dependency or every file.

### 4.3 If Route B is approved

Before opening LaunchBetter UI source:

1. inventory filenames only, excluding all reverse/evidence directories;
2. propose a minimal whitelist of visual-system, asset, and presentation files;
3. receive user confirmation for that whitelist;
4. record every opened path in `PROVENANCE/PHASE1I_SOURCE_ACCESS.md`;
5. record whether each item is user-authored, Apple system material, third-party licensed, or unknown;
6. extract design intent and component behavior into
   `Docs/PHASE1I_VISUAL_REFERENCE_DIGEST.md`;
7. implement Launchcopy components from the digest and approved spec rather than mechanically
   translating source line by line.

No Worker that reads LaunchBetter may claim `NO_PRIOR_EXPOSURE`. Use `REFERENCE_EXPOSED` with an
exact path list.

### 4.4 If Route C is approved

Create `PROVENANCE/PHASE1I_TRANSFER_MANIFEST.md` before copying anything. For each item record:

- source path;
- destination path;
- author/owner basis supplied by the user;
- third-party notices or font licenses;
- whether the item is copied, transformed, or reimplemented;
- hash before and after transfer;
- Reviewer disposition.

Unknown ownership is a block, not an invitation to infer permission.

### 4.5 Required provenance map

For every visible component, record one source class:

```text
NEW_ORIGINAL
USER_OWNED_LAUNCHBETTER_REFERENCE_REIMPLEMENTED
USER_OWNED_TRANSFER_EXPLICIT
APPLE_SYSTEM_COMPONENT
THIRD_PARTY_LICENSED
TEMPORARY_DEVELOPMENT_ASSET
UNKNOWN_BLOCKED
```

The final phase cannot pass with any shipping component marked `UNKNOWN_BLOCKED`.

---

## 5. User decisions required before implementation

Present a recommendation and practical consequences for each decision.

### D1 — Visual-source route

Choose Route A, B, or C from section 4. Recommendation: Route B if the user confirms LaunchBetter's
relevant visual files and assets are fully user-owned; otherwise Route A.

### D2 — Primary appearance

Choose:

- system-adaptive light and dark;
- dark-first with an accessible high-contrast fallback;
- one fixed appearance.

Recommendation: system-adaptive light/dark unless the intended launcher experience depends on a
single full-screen material. A fixed appearance still must pass Increase Contrast and Reduce
Transparency behavior.

### D3 — Background model

Choose one independently specified model:

- restrained opaque/tinted surface;
- system material/vibrancy with controlled fallback;
- user-selected wallpaper treatment;
- approved original branded background.

Recommendation: a restrained material or tint with an opaque Reduce Transparency fallback. Do not
add continuous blur or wallpaper processing without profiling.

### D4 — Density and scaling

Confirm whether 5×7 remains visually fixed or whether icon/cell geometry adapts within the same
capacity. Recommendation: keep 5×7 behavior and page capacity fixed, but scale icon and spacing
within bounded tokens for usable screen sizes.

### D5 — App icon

Choose:

- a user-supplied original icon;
- an explicitly commissioned/generated original icon with documented prompts and rights;
- a temporary development icon with Phase 1J blocked.

Recommendation: use an approved original asset before Phase 1I closure. Do not imitate macOS
Launchpad or another launcher icon closely.

### D6 — Motion character

Choose restrained, expressive, or minimal motion. Recommendation: restrained and interruptible.
Existing paging physics remain frozen; this decision applies to presentation, hover/focus, folder,
search, settings, and drag feedback only.

### D7 — Localization scope

Phase 1H selected Chinese as the primary UI language. Confirm whether Phase 1I also delivers an
English localization or only creates localization-ready keys. Recommendation: Chinese + English for
all product strings before Phase 1J.

### D8 — Shortcut recorder debt

Confirm whether the Phase 1H read-only shortcut display becomes an editable native recorder in this
phase. Recommendation: include it because an incomplete control undermines the Settings product
surface, but keep it isolated from the main visual-system work.

Record approved decisions in a dated file under `Workflow/decisions/` and update the Prompt status
to `APPROVED` without rewriting the original decision history.

---

## 6. Visual architecture requirements

### 6.1 Create a typed visual system

Introduce a small, testable visual-system module or namespace appropriate to the existing package.
Do not create a global mutable theme singleton.

The system should express semantic roles, not raw component-specific constants:

- canvas/background;
- primary, secondary, elevated, selected, hover, pressed, disabled, destructive surfaces;
- primary, secondary, muted, selected, destructive, placeholder text;
- separators, focus rings, drop targets, error and success feedback;
- icon primary/secondary/disabled treatment;
- typography roles;
- spacing scale;
- icon-size scale;
- radii;
- borders and shadows;
- motion durations/curves or spring descriptors;
- window/material fallback policy;
- appearance, Increase Contrast, Reduce Transparency, and Reduce Motion variants.

Tokens must be inspectable and injectable or resolvable from a small immutable context so tests can
exercise appearance variants without mutating global system state.

### 6.2 Avoid token theater

Do not move every numeric literal into a giant token file. A value belongs in the visual system when
it expresses a reusable design decision or accessibility variant. Local geometry that is unique and
mathematically derived may remain local with a clear name.

No arbitrary dictionary-based styling, stringly typed token lookups, or runtime JSON theme engine is
required. Prefer Swift types and compile-time discoverability.

### 6.3 Separate behavior from presentation

The visual system must not own:

- app identity;
- page selection;
- search matching;
- drag mutation;
- folder membership;
- persistence;
- activation routing;
- catalog scanning;
- frame-driver decisions.

Views may observe domain state and map it into semantic visual state. Styling must not become a
second product state machine.

### 6.4 Appearance updates

Handle effective appearance changes without reconstructing the app, losing state, or causing stale
icon writes. A theme refresh may update visible views and cached presentation properties, but it may
not rescan applications, rewrite layout persistence, reset search, or recreate the launcher window.

Apply updates on the main actor. Keep expensive color/image preparation out of repeated per-frame
paths.

---

## 7. Surface-by-surface requirements

### 7.1 Launcher window and background

Define:

- window fill and material composition;
- safe-area behavior around menu bar, notch, and screen edges;
- screen-covering behavior on single and multiple displays;
- fallback when transparency is reduced;
- transition into and out of the launcher;
- behavior when Settings is visible;
- no captured wallpaper or screen-content persistence unless separately approved.

Do not use private WindowServer or Space APIs. Do not query or log the frontmost application merely
to style the background.

If using `NSVisualEffectView`, validate the real compositing cost. A material that looks correct but
causes frame instability fails the phase.

### 7.2 App cells

Replace prototype presentation with a coherent component contract covering:

- icon size, alignment, scaling, and fallback;
- app-name typography, truncation, tooltip, and accessibility label;
- hover, pressed, selected, keyboard-focused, dragging, drop-target, disabled, and stale/empty
  states;
- hit target independent of visible ornament;
- no layout jump when an icon loads asynchronously;
- no old icon/name flash during reuse;
- readable labels over every supported background;
- Retina and non-Retina rendering behavior.

The component must not introduce app-icon masks or decorations that imply affiliation with macOS or
another launcher unless they are standard system behavior and appropriate here.

### 7.3 Page layout and pagination indicator

Define a Launchcopy-specific page hierarchy:

- vertical relationship among search, content grid, and page indicator;
- responsive insets and bounded spacing;
- last-row centering;
- page indicator selected/unselected/hover/accessibility states;
- large page-count behavior;
- reduced-motion page-state feedback;
- no conflict with gesture hit testing.

Keep page capacity and paging state semantics frozen unless D4 explicitly authorizes a narrow layout
ADR.

### 7.4 Search

Define:

- idle, hover, focused, typing, populated, empty-result, and disabled states;
- placeholder and clear-button behavior;
- focus ring and keyboard accessibility;
- transition between normal grid and results;
- pagination relationship;
- privacy-safe copy and telemetry.

Search visuals cannot alter matching, result ordering, query lifetime, Escape priority, or page
navigation semantics.

### 7.5 Folder cell and folder overlay

Define independently:

- closed-folder visual;
- member-count treatment, if retained;
- open overlay/background and hierarchy;
- title display/editing;
- inner grid and focus treatment;
- empty/invalid folder state;
- drag-in, drag-out, reorder, and target feedback;
- dismissal and transition;
- keyboard and VoiceOver navigation.

Do not create a collage by borrowing third-party thumbnails or folder compositions. If a collage is
desired, specify and implement a new deterministic layout using the user's own app icons at runtime,
with asynchronous cancellation and privacy constraints.

Folder opening/closing animation must be interruptible and must not change the accepted domain
state or commit drag mutations prematurely.

### 7.6 Drag and drop

Define:

- lift/drag preview;
- source-cell treatment;
- valid/invalid/reorder/folder-create target feedback;
- edge paging feedback;
- cancel and successful-drop settlement;
- behavior when the launcher hides, sleeps, or loses the session.

Do not add a second drag state machine for animation. Derive visual state from the existing drag
session and keep per-frame work bounded.

No per-frame diffable snapshot, disk write, app scan, icon reload, layout serialization, or dynamic
blur allocation.

### 7.7 Focus, hover, and selection

Mouse hover, keyboard focus, pressed state, and persistent selection are different concepts. Define
them separately and test combinations.

The keyboard focus indicator must remain visible under Increase Contrast and must not rely solely on
color. Avoid focus treatments that shift layout or obscure app names.

### 7.8 Empty, loading, and failure states

Provide product-quality states for:

- catalog loading;
- no applications;
- search with no results;
- icon loading failure;
- catalog refresh/reconcile;
- activation backend unavailable where it appears in Settings;
- persistence/load failure where surfaced.

Copy must be concise and actionable. Do not expose internal paths, bundle identifiers, exception
strings, raw errors, or diagnostic tokens in product UI.

### 7.9 Settings and status item

Bring the Phase 1H Settings window into the same visual language while preserving native AppKit
semantics. Do not turn it into a custom-painted control suite that harms accessibility.

Complete the editable shortcut recorder if D8 is approved. It must show normalized shortcuts,
invalid/reserved conflicts, clear behavior, apply rollback, and current registration truth.

Create or confirm an independent menu-bar symbol and accessibility description. Template images
must render correctly in light and dark menu bars.

### 7.10 Product icon and bundle resources

Resolve the missing app-icon debt:

- source asset is original or explicitly user-owned;
- preserve a high-resolution editable master outside the bundle;
- generate required macOS representations deterministically;
- set `CFBundleIconFile` or the selected packaging equivalent correctly;
- confirm Finder, Dock, application switcher, Settings, and About presentation;
- document hashes and provenance;
- do not use a third-party icon as a temporary shipping placeholder.

If the user has not approved an icon, Phase 1I may finish implementation but must remain
`BLOCKED_BY_PRODUCT_ICON` for product completion.

---

## 8. Motion system requirements

### 8.1 Motion purpose

Every animation must answer one of these:

- show spatial relationship;
- confirm state change;
- preserve continuity during interruption;
- direct attention to an actionable result.

Do not animate decorative properties continuously. Avoid animation merely to make the UI appear
busy.

### 8.2 Existing paging physics are frozen

Do not modify paging thresholds, damping, settle timing, page reuse, presentation-layer handoff, or
frame source as part of visual polish.

New animations around search, folders, cells, drag, and presentation must coexist with paging and
must cancel cleanly when paging begins.

### 8.3 Interruption contract

For every new animation specify:

- initiating event;
- source and destination states;
- duration/curve or spring;
- interruption behavior;
- reverse behavior;
- repeated-trigger behavior;
- Reduce Motion behavior;
- completion ownership/generation;
- cleanup after hide, sleep, or reuse.

Old animation completions may not overwrite newer state. Do not solve this with arbitrary delays.

### 8.4 Property budget

Prefer opacity and transform for high-frequency transitions. Profile corner radius, shadows, masks,
blur, vibrancy, and large-area transparency before accepting them. Avoid per-frame layer-tree
reconstruction.

---

## 9. Accessibility and localization

### 9.1 Accessibility is a completion gate

Validate:

- VoiceOver roles, names, values, help, and actions;
- full keyboard navigation;
- visible focus;
- Increase Contrast;
- Reduce Transparency;
- Reduce Motion;
- light/dark or the approved appearance set;
- sufficient text/background and focus/background contrast;
- labels do not depend only on color or motion;
- large or long localized strings do not clip critical actions;
- tooltips do not replace accessibility names.

Do not claim accessibility PASS from static labels alone. At least one real VoiceOver manual pass is
required for the primary flows.

### 9.2 Localization boundary

Move product-facing strings behind a small localization boundary. Do not localize internal
diagnostic tokens, test fixture strings, or path names.

If Chinese and English are approved, verify at least:

- menu bar menu;
- launcher search placeholder and empty states;
- folder count/title editing;
- Settings sections, statuses, errors, reset confirmations;
- shortcut conflict messages;
- Launch at Login status;
- About/version strings.

Changing system language for manual validation is user-controlled; do not alter system preferences
without explicit authorization.

---

## 10. Performance, memory, and energy gates

### 10.1 Baseline before visual changes

Before implementation, capture a reproducible baseline from the current Release build:

- initial launcher show latency;
- first usable grid latency;
- steady hidden CPU and wakeups;
- steady visible-idle CPU and wakeups;
- paging frame intervals on the available 60 Hz device;
- memory after initial load and after 30 show/hide cycles;
- page reuse and stale icon counters;
- folder open/close and search transition responsiveness;
- app bundle size and resource size.

Use existing telemetry/profiling tools only when they do not distort the measurement. Clearly label
instrumentation effects.

### 10.2 Before/after protocol

Use the same machine, display mode, build configuration, app set, window geometry, and test script.
Run at least three comparable rounds when noise is material. Record raw summaries, not only a PASS
token.

Do not use SELFDRIVE as the sole physical paging verdict. Do not write 120 Hz PASS on a 60 Hz-only
device.

### 10.3 Acceptance constraints

Finalize exact numeric thresholds in `Docs/PHASE1I_VALIDATION_PLAN.md` before collecting final data.
At minimum:

- no repeatable new paging hitch class attributable to visual work;
- no hidden-state display timer or continuous animation;
- no per-frame icon reload, layout persistence, catalog scan, or snapshot rebuild;
- no unbounded layer/image cache growth across 30 show/hide cycles;
- no stale visual application after cell/page/folder reuse;
- no visible dropped state during appearance changes;
- no obvious latency regression in search/folder/drag interactions;
- bundle resource growth is explained and bounded.

If a material/blur/shadow design fails the performance gate, simplify the design. Do not change the
paging engine to mask visual cost.

---

## 11. Visual evidence workflow

### 11.1 Build an acceptance matrix before implementation

Create `Docs/PHASE1I_VISUAL_ACCEPTANCE_MATRIX.md` with named states and required evidence.

Minimum screenshot/state coverage:

| Surface | Required states |
|---|---|
| Launcher | initial load, populated grid, last partial row, multiple pages |
| Cell | idle, hover, pressed, keyboard focus, dragging, drop target, icon failure |
| Search | idle, focused, query, multi-page results, no results |
| Folder | closed, open, title edit, inner focus, drag in/out, invalid/empty |
| Paging | first, middle, last page; dragging and settled indicator |
| Settings | every section, error, requires approval, disabled/unavailable |
| Appearance | all approved appearances, contrast/transparency/motion variants |
| Display | smallest supported, main target, largest available, Retina scale |
| Localization | Chinese and English if D7 approves both |

### 11.2 Evidence rules

- Store screenshots under a named Phase 1I artifact directory excluded from the product bundle.
- Record build identity, size, scale factor, appearance, locale, and scenario.
- Do not include other users' window contents, notifications, account names, or sensitive paths.
- Static screenshots do not prove motion; use a short local capture or frame sequence where needed.
- A scripted capture proves repeatability, not visual quality. A human/visual Reviewer must inspect
  the rendered output.
- Reviewer findings must point to an exact state and artifact.
- Do not approve from source code alone.

### 11.3 Visual regression tests

Add deterministic snapshot or geometry/style-contract tests where stable and useful. Avoid brittle
full-screen pixel tests that fail because of OS antialiasing or unrelated icon content.

Good candidates:

- token resolution;
- appearance variants;
- cell geometry and semantic states;
- search/folder layout at fixed sizes;
- page indicator geometry;
- Settings layout and accessibility identifiers;
- bundle icon/resource presence.

Use tolerance and masking only when justified. Never mask the component under test.

---

## 12. Architecture and implementation constraints

1. Use AppKit/Core Animation consistent with the existing project.
2. Do not replace the main grid with a giant SwiftUI hierarchy.
3. Do not add a third-party UI framework without a decision gate and license review.
4. Do not add a runtime theme engine, plugin system, or remote design configuration.
5. Do not put `NSImage`, `NSColor`, `NSView`, or `CALayer` into catalog/layout domain models.
6. Do not put per-frame animation state into persisted settings or layout store.
7. Do not use `DispatchQueue.main.sync`.
8. Do not add unchecked sendability merely to silence Swift 6 warnings.
9. Keep main-actor UI ownership explicit.
10. Use generation/identity checks for asynchronous visual writes.
11. Keep image decoding/scaling off the paging hot path.
12. Avoid layout constraint churn during gestures.
13. Preserve current clean shutdown and cancellation behavior.
14. Do not rename broad modules or public types merely for cosmetic vocabulary cleanup.
15. Any responsive geometry must be deterministic and testable from available bounds/safe area.
16. Keep real app names, search queries, folders, paths, and touch traces out of durable visual
    telemetry.

---

## 13. Suggested task graph and ownership

The Main must reconcile live workflow configuration before dispatch. The configured concurrency
limit is a ceiling, not a requirement.

Suggested tasks:

| Task | Objective | Primary write scope | Dependencies |
|---|---|---|---|
| T-1I-G0 | Gate 0, decisions, baseline, source policy | Docs/Workflow/Provenance only | none |
| T-1I-A | Visual-system tokens and appearance resolver | new visual-system files + tests | G0 approval |
| T-1I-B | Launcher canvas, grid, cells, focus, indicator | assigned UI files + tests | A |
| T-1I-C | Search and empty/loading/failure states | search/status UI files + tests | A |
| T-1I-D | Folder and title-edit visual system | folder UI files + tests | A |
| T-1I-E | Drag visual feedback and animation cleanup | drag UI files + tests | A |
| T-1I-F | Settings, status item, shortcut recorder | app/settings files + tests | A, D8 |
| T-1I-G | Product icon/resources/packaging integration | Resources/Scripts/metadata tests | D5 |
| T-1I-H | Localization and accessibility audit/repair | resource/accessibility files + tests | B–G stable |
| T-1I-I | Performance and rendered-state verification | evidence/docs; narrow repairs only | integrated build |
| T-1I-J | Independent code, provenance, visual review | review artifacts only | stable candidate |
| T-1I-K | Physical acceptance and phase closeout | validation/report/checkpoint | Reviewer PASS |

### 13.1 Parallelization

After A stabilizes, B/C/D/E/F/G may run in parallel only when:

- write sets are disjoint;
- shared component APIs are frozen for the wave;
- each Worker has independent tests;
- package/build resources are serialized;
- no two Workers edit `Package.swift`, `AppDelegate.swift`, shared tokens, packaging scripts, or the
  same resource catalog;
- Main records the concurrency decision.

If workers share a working tree and cannot isolate builds, use targeted non-mutating checks during
the wave and serialize full builds/tests afterward.

### 13.2 Reviewer independence

Implementing Workers cannot self-certify PASS. Use independent Reviewers for:

- code/architecture;
- visual output;
- provenance/asset licensing;
- performance evidence;
- integrated regression.

Reviewer does not modify product source. Findings must include severity, evidence, affected state,
likely cause, recommended repair, regression risk, and confidence.

### 13.3 Context persistence

After every material task, update `Docs/PHASE1I_CHECKPOINT.md` with:

- current candidate identity;
- decisions and exact user scope;
- changed files and owner;
- test/build evidence;
- rendered artifacts;
- open Reviewer findings;
- physical gates;
- provenance status;
- next executable action.

Do not use memory or chat as the only durable record.

---

## 14. Automated validation matrix

At minimum, add or preserve tests for:

### Visual system

- semantic token completeness;
- light/dark or approved appearance variants;
- Increase Contrast and Reduce Transparency fallback resolution;
- Reduce Motion descriptors;
- finite/nonnegative geometry and duration values;
- no global mutable theme state.

### Cell and page

- icon frame remains stable before/after async load;
- reuse clears old text/icon/folder state;
- hover/focus/pressed/drag/drop combinations resolve deterministically;
- focus indication does not change layout;
- partial last row remains centered;
- 5×7 capacity remains unchanged unless approved otherwise;
- page indicator handles zero, one, many, and large page counts;
- appearance change does not alter page/domain state.

### Search

- visual state follows focus/query/result state without changing match results;
- no-results state does not create a fake app/folder item;
- Escape behavior remains layered correctly;
- pagination and keyboard focus survive restyling.

### Folder

- folder/app identity remains visually and behaviorally distinct;
- folder symbol/collage never requests invalid resources;
- overlay reuse clears stale members/title/focus;
- title editor remains keyboard accessible;
- interrupted animations settle to the current domain state;
- drag in/out visuals do not commit mutations.

### Drag

- one visual state per existing drag state;
- invalid targets are not represented as valid;
- hide/session loss/cancel clears layers and timers;
- no per-frame persistence or snapshot application;
- old animation completion cannot revive a preview.

### Settings and shortcut recorder

- single Settings window remains single;
- control states map to committed preferences, not uncommitted service results;
- recorder normalization, clearing, invalid/reserved conflict, rollback, and accessibility;
- four-finger Enabled versus Ready remains truthful;
- disabling status item preserves the recovery path;
- Launch at Login tests remain fake-only.

### Resources and packaging

- icon resource exists at expected representations;
- asset provenance manifest entry exists;
- packaged `Info.plist` references valid resources;
- product bundle excludes Workflow, Tests, PROVENANCE, source, raw screenshots, and diagnostics;
- packaging remains deterministic enough for documented comparison;
- ordinary product execution does not enable diagnostic flags.

### Regression

- paging core full suite;
- app catalog and icon pipeline;
- search and focus;
- folder domain and presentation;
- drag/persistence;
- launcher show/hide/quit;
- status/Dock/shortcut/Hot Corner/four-finger;
- settings/apply/Launch at Login;
- Debug and Release builds;
- packaged app smoke.

Exit zero with zero executed tests is invalid. Report exact executed counts by target.

---

## 15. Manual and physical acceptance

Prepare a copyable user checklist. Do not report PASS without the user's actual result.

### M01 — First impression and identity

- Launch packaged app from Finder.
- Confirm app name, Dock icon, menu-bar icon, and Settings identity are coherent.
- Confirm the launcher does not visually present as Buho or macOS Launchpad branding.
- Confirm no development/prototype copy is visible.

### M02 — Main grid

- Inspect full page and partial last page.
- Hover, click, press, keyboard-focus, and launch apps.
- Verify labels remain readable over the background.
- Verify app icon loading produces no jump or old-icon flash.

### M03 — Paging

- Perform slow, normal, fast, interrupted, reversed, and edge swipes.
- Verify the new visuals do not make the accepted paging feel heavier or less direct.
- Verify indicator and focus remain synchronized.
- Run on 60 Hz; only run/report 120 Hz with real hardware.

### M04 — Search

- Open via keyboard/mouse, type, clear, paginate results, launch, and Escape.
- Test one result, partial row, many pages, no results, and long names.
- Verify focus and empty-state clarity.

### M05 — Folder

- Open by mouse and keyboard.
- Navigate inside, rename, dismiss, reopen, drag in/out, and test member counts.
- Interrupt open/close transitions.
- Confirm no stale collage/symbol/member/title state.

### M06 — Drag

- Reorder, create folder, move into/out of folder, edge page, cancel, hide during drag.
- Confirm valid/invalid targets are obvious but not distracting.
- Relaunch and verify persistence.

### M07 — Activation and lifecycle

- Menu bar, Dock reopen, shortcut, Hot Corner, and four-finger inward pinch.
- Show/hide repeatedly while appearance remains stable.
- Confirm outward spread does not hide.
- Confirm Settings remains usable while launcher hides/shows.

### M08 — Accessibility

- Complete core flows with keyboard only.
- Complete representative flows with VoiceOver.
- Test Increase Contrast, Reduce Transparency, and Reduce Motion.
- Confirm focus never disappears and information is not color-only.

### M09 — Appearance and displays

- Test every approved appearance.
- Test smallest supported screen and every actually available display arrangement.
- Verify correct target screen, safe areas, scale, and no clipped controls.
- Untested hardware remains `NOT_RUN`.

### M10 — Localization

- Test Chinese.
- Test English if approved.
- Check long app/folder names and all Settings/error text.
- Do not change global system language without user control.

### M11 — Performance

- Run the predefined before/after protocol.
- Inspect hidden idle, visible idle, paging, folder, search, drag, and 30 show/hide cycles.
- Record subjective feel separately from measured frame/CPU/memory data.

### M12 — Packaged product smoke

- Run the local packaged `.app`, not only `swift run`.
- Verify resources, icon, localization, menu/status behavior, launch, hide, quit, and relaunch.
- Confirm no terminal or development flag is required.

---

## 16. Required documentation and artifacts

Create or update:

```text
Docs/PHASE1I_SPEC.md
Docs/PHASE1I_VISUAL_SYSTEM.md
Docs/PHASE1I_VISUAL_ACCEPTANCE_MATRIX.md
Docs/PHASE1I_VALIDATION_PLAN.md
Docs/PHASE1I_VALIDATION_RESULTS.md
Docs/PHASE1I_REPORT.md
Docs/PHASE1I_CHECKPOINT.md
Docs/PHASE1I_VISUAL_REFERENCE_DIGEST.md          # only if Route B or C
Docs/ADR-015-VISUAL-SYSTEM-AND-APPEARANCE.md     # or next free ADR number
PROVENANCE/PHASE1I_SOURCE_ACCESS.md
PROVENANCE/PHASE1I_VISUAL_COMPONENT_MAP.md
PROVENANCE/PHASE1I_TRANSFER_MANIFEST.md          # only if Route C
Workflow/stage-summaries/2026-09-11-phase1i-visual-productization.md
Workflow/tasks/T-1I-*.md
Workflow/results/T-1I-*.md
Workflow/reviews/T-1I-*.md
```

Store rendered evidence in a dedicated Phase 1I artifact directory and include a SHA-256 manifest.
Do not bundle that evidence into the app.

Every major conclusion in the final report must follow:

```text
Evidence → Finding → Affected path/component → Decision or remaining action
```

---

## 17. Stop conditions

Stop the affected branch and report a precise status when:

- the user has not approved the visual-source route;
- a LaunchBetter file is needed outside the approved whitelist;
- any Buho reverse material appears necessary;
- an asset's ownership or license is unknown;
- the app icon is not approved;
- a visual change requires modifying frozen paging behavior;
- a responsive-layout proposal changes persistence/page semantics;
- a third-party dependency or font is proposed without license review;
- private AppKit/WindowServer/Space APIs appear necessary;
- visual work causes a repeatable paging/performance regression;
- tests pass with zero execution;
- Workers overlap write scopes;
- a test update merely blesses an unintended regression;
- the next action would sign, notarize, publish, commit, push, tag, or release;
- a destructive reset or evidence deletion is proposed.

Use explicit labels:

```text
PHASE1I_DECISION_REQUIRED
PHASE1I_BLOCKED_BY_VISUAL_SOURCE_OWNERSHIP
PHASE1I_BLOCKED_BY_PRODUCT_ICON
PHASE1I_BLOCKED_BY_LICENSE
PHASE1I_BLOCKED_BY_BEHAVIOR_CONTRACT
PHASE1I_PERFORMANCE_REGRESSION
PHASE1I_PHYSICAL_ACCEPTANCE_PENDING
PHASE1I_PARTIAL
```

---

## 18. Definition of done

Phase 1I may be labeled `PHASE1I_VISUAL_IMPLEMENTATION_COMPLETE_PHYSICAL_PENDING` only when:

- Gate 0 and user decisions are recorded;
- provenance routes and asset ownership are documented;
- one typed visual system is integrated across the launcher and Settings;
- main grid, search, folders, indicator, focus, drag, states, and activation shell use it coherently;
- an approved original/user-owned app icon is packaged, or the phase is explicitly blocked on it;
- shortcut recorder debt is closed if approved in D8;
- accessibility and localization implementation are complete for the approved scope;
- no behavior/persistence/activation contract regressed;
- fresh Debug and Release builds pass;
- fresh full and targeted tests pass with exact nonzero counts;
- local packaged `.app` smoke passes;
- performance comparison shows no unacceptable visual regression;
- independent code, provenance, and visual reviews report zero BLOCKER and zero unresolved MAJOR;
- all unrun physical/hardware checks remain visible as PENDING or BLOCKED.

Phase 1I may be labeled `PHASE1I_COMPLETE` only after the user performs and accepts the required
manual visual/physical matrix for the available hardware and approved appearance/localization scope.

Neither label means the app is signed, notarized, uploaded, published, or released.

After Phase 1I, the only recommended next phase is:

```text
RECOMMEND_PROCEED_TO_PHASE_1J_RELEASE_CANDIDATE_VALIDATION
```

Phase 1J must focus on freeze, release build reproducibility, complete regression, signing/notarizing
experiments when separately authorized, security/privacy review, upgrade/uninstall behavior, and
release-candidate acceptance. It must not become another visual redesign.

---

## 19. Required final handoff format

Return a concise Chinese final report with:

1. **Outcome** — exact Phase 1I status label.
2. **User-visible result** — what now looks and feels different.
3. **Behavior preservation** — frozen contracts and regression evidence.
4. **Provenance** — source route, files read/transferred, asset ownership, unresolved questions.
5. **Visual evidence** — artifact paths and reviewed states.
6. **Accessibility/localization** — implemented and manually tested scope.
7. **Performance** — before/after results and unresolved >25 ms truth.
8. **Verification** — exact builds, tests, counts, hashes, and packaged app identity.
9. **Physical gates** — PASS/FAIL/NOT_RUN by hardware and scenario.
10. **Distribution truth** — unsigned/signed/notarized/released states separately.
11. **Open debt** — only concrete remaining items.
12. **Next step** — whether Phase 1J is recommended and what authorization it would need.

Do not claim completion from code review alone, screenshots alone, automated tests alone, or a user
statement whose tested scope was not recorded.

---

## 20. Copyable execution instruction

Use this instruction when starting the implementation task:

```text
Read and execute:
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1I_INDEPENDENT_VISUAL_SYSTEM_AND_PRODUCT_POLISH_PROMPT.md

Start with Gate 0 and the user decision packet. Do not modify product source until the user approves
the Phase 1I specification and visual-source route. Preserve all frozen behavioral and performance
contracts. Do not access Buho reverse-engineering material. Do not read LaunchBetter UI source until
a minimal whitelist is proposed and explicitly approved. Use the project Main/Chief/Worker/Reviewer
workflow, write durable Markdown checkpoints, and keep shared builds/tests serialized. Do not sign,
notarize, publish, commit, push, tag, or release.
```
