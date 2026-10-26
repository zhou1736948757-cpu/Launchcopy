# LaunchBetter Experience on the Launchcopy Framework

Status: APPROVED_SCOPE — user confirmed recommended staged scope on 2026-10-13
Date: 2026-10-13

## 1. Problem, users and outcome

Implement the user-visible UI and functions of LaunchBetter in the existing
Launchcopy application, without copying source code or resources. Target existing
local Apple-Silicon macOS users. Preserve the validated paging experience and
saved organization while improving product completeness and visual coherence.

User clarification: LaunchBetter already contains the desired product functions;
its performance is the reason for this rewrite. The target is experience parity
on Launchcopy's performant framework, not a newly invented product or an arbitrary
redesign. Preserve the approved staged order, but identify every reference function
as mapped, pending, deferred by explicit decision, or verified. The user describes
Launchcopy as performant; this is a product baseline, not proof of all refresh rates
or a resolution of the previously unresolved long-tail frame causes.

The user explicitly selected independent implementation on 2026-10-13. This is
not authorization to replace validated input contracts, adopt another product's
identity, distribute proprietary assets, or claim strict historical clean-room
development. The source governance plan remains applicable:
`/Users/mac/Projects/Launch_Copy/RISK_REDUCTION_PLAN.md`.

## 2. Discovery evidence and limits

A read-only feature audit found these intended LaunchBetter capabilities. Source
presence does not establish working runtime behavior. Reference defects should
not become requirements; for example, a label-visibility setting appears in the
reference settings, but its grid consumption was not established by this audit.

| Area | Existing Launchcopy capability | Remaining product requirement |
| --- | --- | --- |
| Main UI | Wallpaper, search, gear, app grid, folders | Unified geometry/type/material settings; safe-area chrome; no decorative top page number |
| Paging | Gesture/keyboard paging with validated physics | Page dots and explicitly designed direct-page selection |
| Search | Display-name matching; keyboard navigation | Alias/bundle-ID matching policy, empty/no-result presentation |
| Organization | Drag, folders, rename, persistence | App context menu, hide/unhide, aliases, folder assignment UI |
| Settings | Activation, shortcut, four-finger, login launch | Layout, appearance, language, sources, hidden-app management |
| App catalog | Bounded scanning and refresh | User-managed roots and installation/removal notifications |
| App Library | No equivalent established | Categories, details, suggested/recent sections, manual classification |
| Activation | Resident launcher and basic entry points | Optional spread-to-hide / additional gesture parity, subject to explicit scope |

Discovery source locations are recorded separately from implementation input.
Implementers receive observable requirements, not translated routines, class
layouts, address maps, decompiled text, or reference assets. Raw Buho evidence
and old rebuild source remain excluded.

## 3. Recommended scope and open decisions

Approved scope defaults (user selected the recommended staged route):

1. Reproduce the desired LaunchBetter visual structure, styling intent and
   interactions through independently authored code and Launchcopy branding.
   Do not substitute an unrelated new design or copy source/resources.
   Preserve the user-requested removal of top page-number text.
2. Keep the current 5-by-7 default and paging physics. First add appearance controls
   that do not change capacity; adjustable rows/columns need a separate anchor,
   focus, folder-capacity and persistence compatibility decision.
3. Add name/alias search first; bundle-ID matching is an optional documented mode.
   Hidden apps are excluded consistently from visible pages/search/Library but
   their saved arrangement is retained. Hiding is not deletion/uninstallation.
4. Start the App Library as a separate optional view, not a synthetic negative
   page inserted into the existing pager. A leftmost Library page requires an
   explicitly approved page-number/navigation model before implementation.
5. Begin with safe context-menu actions: launch, alias, hide, folder assignment
   and Finder reveal using public APIs. App deletion, Finder scripting, three-finger
   drag and expanded pinch/toggle semantics remain identified parity backlog,
   not silently implemented or treated as already accepted.

Decisions 1–5 are now confirmed at the product-scope level. Record per-slice
implementation contracts before substantial edits; direct-page navigation,
adjustable capacity, destructive actions and extra gestures still require their
specific decisions. The listed optional backlog is deferred, not implicitly
approved and not grounds to claim full reference parity.

## 4. Architecture and data decisions

- Retain the Swift Package/AppKit architecture and module boundaries:
  PagingCore/PagingUI for paging; AppCatalogCore/MacAppCatalog for identities and
  scanning; AppIconPipeline for asynchronous runtime icons; AppGridUI for grid,
  focus, folders and drag; application assembly for windows/settings/activation.
- Preserve Launchcopy's AppID and the existing launch validation path. Do not
  replace identities with LaunchBetter IDs or import its saved layout by default.
- Persist product preferences, hidden identities, aliases and category overrides
  separately from workspace layout. Version new stores, define defaults and
  recoverable corruption behavior, and avoid destructive layout migration.
- Catalog updates remain latest-wins and commit atomically with folder/search
  presentation at idle boundaries. Temporary absence never deletes saved layout.
- Direct page selection uses a deliberate pager API with interruption/focus rules;
  no loop of synthetic wheel/key events and no unapproved physics parameter change.
- Source watching is bounded/debounced and feeds the existing catalog seam.
  Runtime app icons remain runtime data; no third-party icon/resource distribution.
- Library category rules are independently specified. Usage-based suggestions,
  if approved, store minimal local data with an opt-out/reset control and no upload.

## 5. Functional and non-functional requirements

- Ordinary grid row positions remain stable across partial pages. Search geometry
  is explicit. Safe areas use current window/screen coordinates, including screen
  changes and supported sizes; do not hardcode this Mac's notch offset.
- Icon hit padding, click/drag discrimination, typewriter navigation, search-return
  focus, folder lifecycle, resident hide behavior and restoration remain regressions.
- Opening a folder from a pointer uses restrained origin-aware motion. Rapid
  reversal resumes presentation state; keyboard/Escape and teardown are immediate.
  Reduce Motion and Reduce Transparency are independently honored.
- I/O never blocks window presentation or frame callbacks. Async images cannot
  overwrite newer views/preferences. Cache and callback synchronization is testable.
- Maintain readable localized labels, keyboard/accessibility support, and explicit
  empty/error states. Do not advertise unavailable settings as working features.
- Keep diagnostics opt-in and free of application names, bundle IDs, paths or
  personal usage records. Do not use synthetic performance tests as physical PASS.
- Preserve the accepted 60Hz result and unresolved >25ms causality distinction.
  A new UI is not evidence that frame-hitch roots or 120Hz support were resolved.
- Performance is an acceptance requirement, not a final polishing task. Before
  each feature slice, record the current-candidate workload/baseline; after it,
  compare matched catalog size, screen/viewport, build mode, frame source and
  physical device. Separate frame-callback cost from end-to-end frame intervals.
  Establish a per-slice performance budget before implementing added work; do not
  claim no regression from mismatched synthetic traces or screenshots.
- Keep optional Library/settings content lazy and catalog/icon work off the main
  thread. A frame must not rescan apps, persist settings/layout or regenerate
  classification/images. Feature parity with degraded paging/startup/input
  performance fails acceptance even if its functional tests pass.

## 6. Incremental delivery and acceptance

1. **Baseline repair:** current click/search/folder bugs, nonblocking wallpaper,
   notch-safe search, top-label removal, and unobtrusive opt-in UI-test mode.
2. **Visual system:** independently defined tokens and settings; grid/chrome/folder
   consistency; page indicator with separately approved direct navigation.
3. **App management:** hide/aliases/context menus/source settings/watch refresh.
4. **Library:** category data/overrides and agreed navigation; optional suggestions.
5. **Additional parity:** explicitly approved gesture/destructive-action backlog.

Each slice needs an approved bounded contract, disjoint write ownership, independent
review, focused regressions, a nonzero full-suite result and debug/release builds.
Package into a unique candidate with executable hash; preserve older artifacts.
No signing, notarization, installation, publishing or commit without authorization.

Acceptance distinguishes source/test evidence, exact-candidate GUI behavior,
physical gesture/motion feel, persistence restart evidence and distribution gates.
Record each requirement as verified, pending, failed or explicitly waived; never
infer complete LaunchBetter parity from build success or a settings screenshot.

## 7. Unobtrusive testing contract

The user works on Desktop 1. Do not open screen-covering test windows there.
Opt-in `--ui-test-windowed` uses an ordinary non-cross-Space window, ordered behind
other windows, without automatic activation or menu/Dock hiding. Production
defaults remain unchanged. This mode is not a separate input session: CUA mouse
and keyboard operations still affect the user. Arrange live UI sessions on
Desktop 2 and agree on input timing first; no silent Space/preference changes.

## 8. Maintenance, risks and resume point

Prefer existing boundaries and small testable policies over a second launcher
stack. Document defaults and compatibility decisions beside implementation.
Track provenance per component; the selected independent route is not a legal
clearance or proof of independent authorship for past code. Major risks are
capacity/page model drift, private gesture APIs, persistent layout loss, expanded
local usage recording, catalog churn and unverified source visual/asset rights.

Resume: independent implementation and staged product scope are approved. Finish
the current bounded repairs and evidence checkpoint, then proceed to the visual
system/settings slice. Physical baseline acceptance and GUI-capable full tests
remain scheduled for an agreed Desktop-2 session; background work must not
silently promote those gates.

## 2026-10-19 explicit leading Library approval
The user expressly approved the optional Library as the pane left of first grid page, retaining button entry, app-only page numbers, protected-work admission and prior-context Close/Escape. This supersedes separate-only/reserved leading-page dispositions for this branch only. Implementation contract: Docs/LEADING_LIBRARY_IMPLEMENTATION_SPEC.md. Default remainsOFF; implementation/native/physical acceptance pending.


## 2026-10-22 optional outward Hide supersession
The user explicitly approved default-OFF outward resident Hide in the idle main grid or committed Library, preserving inward Show and refusing protected work. The older inward-only/no-Hide or reserved-outward wording remains historical default-mode evidence, not the current optional-mode contract. Authority: `Docs/FOUR_FINGER_OUTWARD_HIDE_SPEC_2026-10-22.md` and matching final results. Code3550/0, build/package/native preference restart are verified, but physical recognition/calibration remains pending; current UI-test entry is fake-only and must not be relaxed to manufacture acceptance. Other expanded pinch/toggle/cold-outward/three-finger variants remain reserved. A separate real-device environment proposal is not an approved backend change.

## 2026-10-23 integrated preview approval
The user explicitly approved a separately identified preview combining real default-root application discovery/click launching with the accepted real four-finger backend, while all layout/preferences remain isolated from formal data. Destructive removal, activity recording, login/global shortcuts/hot corners stay unavailable. This does NOT weaken the original fake-only UI entry or non-launching gesture harness, and is not an install/release/full-parity acceptance. Contract: Docs/INTEGRATED_FUNCTIONAL_PREVIEW_SPEC_2026-10-23.md. Preserve production defaults, paging physics and all reserved variant decisions outside this scope.

## 2026-10-24 user correction: meaningful newly created folder names
The user explicitly requests meaningful names when dragging one app onto another, rather than generic `Group N` titles. This authorizes an independent local default-name policy: shared known category in the displayed language, otherwise the two current displayed names, bounded and uniquely suffixed. Keep existing titles and inline user rename; no retroactive migration or automatic creation-time editor is implied. This supersedes neutral-default naming only for newly created production app-on-app folders. Contract: `Docs/FOLDER_NAMING_AND_CATALOG_WARNING_2026-10-24.md`.

The same feedback asks what the partial-load banner means. Distinguish admitted missing-identifier metadata warnings from genuine discovery failures, retain anonymous totals and real error visibility, and use truthful localized wording. Do not claim a scan warning establishes launch failure or infer its exact live category without evidence. Broader source-policy changes are not authorized by this wording repair.
