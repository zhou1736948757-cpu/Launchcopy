# Icon and Typography Preferences — Bounded Specification

Status: APPROVED_IMPLEMENTATION_CONTRACT, 2026-10-13.
Authority: appearance controls are on the approved parity roadmap. This file
specifies new geometry/data contracts; user confirmation was received before
production implementation. It does not approve the separate adjustable-capacity branch.

## Problem, users and outcome

Provide native, persistent icon-size and caption-size controls for launcher users
without adopting reference source/assets, changing organization or sacrificing
paging performance. Keep ordinary/search/folder appearance coherent and existing
Launchcopy behavior rather than introduce a second grid stack.

## Scope and exclusions

Extend Appearance preferences, controls and the existing renderer/folder cells.
Keep default5 columns/7 rows/35 slots,88pt ordinary cells, icon48pt, caption11pt,
member count10pt and existing label/wallpaper settings. Keep grid frame positions,
page count, saved references/order, current query and current focus identity.
No row/column changes, app rescans, layout migration, library implementation,
activation change, physics/timer adjustment, copied resources or distribution.
These exclusions belong to this slice only, not a reduced definition of parity.

## Confirmed user interaction

- Icon preferred side32–64pt and caption size9–16pt, integer steps. Defaults48/11.
  These are independently chosen bounded preference ranges, not a claim about
  reference exact values or verified rendered quality.
- Size is a preference, not a promise of an exact physical pixel count. Fit the
  icon into each existing cell, reserve readable caption/member-count bounds and
  preserve non-overlapping content; settings explains automatic fitting. Cell
  frames/order/capacity do not expand to accommodate an impossible combination.
  Hidden labels free space; showing them again deterministically restores fit.
- App and folder symbol use the same fitted icon geometry. Public hit-testing
  retains icon-plus4pt padding and complete-cell drag/hit identity; do not enlarge
  launch hits into gaps. Folder-title editor and page/chrome controls do not scale.
- Stage changes; Apply persists accepted preferences first. Closing discards only
  unsaved draft. Restore Defaults remains draft until explicit Apply. Equal-value
  Apply has no rendering/IO work; failed save changes no rendered state.
- If paging/direct-page motion, held-pointer/drag, folder transition or title
  editor currently owns geometry, defer this presentation update to a safe
  boundary. Latest accepted draft wins. Distinguish saved/queued/applied/failure;
  do not report queued geometry as already on screen. No cancellation of the
  user's interaction merely to make a settings slider take effect faster.
- Keep app/folder focus identities, query and open folder; update geometry only
  once at the resolved boundary, including retained pools and move-out proxy.
  Cancel obsolete visual-only exits rather than mutate their old geometry.

## Architecture and data decisions

Use one neutral value-type grid appearance policy in AppGridUI, with validated
numeric preferences and a pure fitted-cell geometry function. The AppKit cell
consumes resolved frames/fonts; application preferences do not become a dependency
of AppGridUI. Default geometry must match current behavior exactly unless an
existing clipping defect is independently reproduced and fixed as maintenance.

Extend dedicated appearance payload to schema2, reading explicit schema1 with
48/11 defaults. No automatic writes on load. Decode required schema2 values
strictly; reject invalid/range/nonfinite/corrupt data with recoverable defaults.
Protect schema>2 from overwrite, including equal Apply/Restore Defaults. Preserve
other suites, layout payloads and existing profile-specific namespace separation.
Older executables must see schema2 as future, not silently erase new values.

Maintain separate accepted/saved and applied presentation state, owned by the
application coordinator. Only one latest pending geometry policy exists; no task
per frame. Teardown cancels pending UI work, not already accepted persistence.
Existing Quit accepted-write protection remains intact.

Renderer applies the policy to active/new/reused/pooled views; folder applies to
current/new/reused member cells and move-out proxy. Icon geometry changes use
existing async pipeline/cache, bounded page residency, request cancellation and
binding-generation gates. A result for the previous icon key/size cannot replace a
new request or resurrect a hidden/torn-down view. Font-only changes issue zero
icon requests and preserve bound images. No catalog revision fabrication, provider
reload/rescan or saved-order mutation for appearance.

## Nonfunctional and performance budget

Before source edits record the2092/0 Page Dots baseline fingerprint/candidate and
fixture/cell workload. Default unchanged appearance must preserve requested icon
keys and number of cells/requests. Font-only Apply requires zero scans, icon or
wallpaper requests; icon-only Apply requires zero scan/wallpaper/layout writes.
One bounded policy update per accepted change at safe boundary, no classification,
IO, image decode, persistence or appearance work in advanceFrame/offset callback.
Repeated equal values are no-op. Old icon callbacks are rejected, not synchronously
waited for. Tests establish structural budgets only; exact-candidate matched real-
icon physical AB is required before measured regression-free or final acceptance.
Unresolved>25ms causes and unsupported120Hz remain separately identified.

## Acceptance and testing

1. Defaults and schema1 compatibility, schema2 round-trip; invalid/corrupt/future
   data protection, failed-save/no-op/default-draft/profile isolation.
2. Actual native control -> draft -> Apply -> preference/queue/presentation;
   keyboard/accessibility labels and scrollable/clipped settings bounds.
3. Pure geometry bounds and no icon/caption/member-count overlap across default,
   min/max preferences, hidden labels, narrow/folder/ordinary/search cells. Launch
   hit uses fitted icon; no unexpected gaps/cell-window/chrome interception.
4. Live/new/pooled/proxy cells agree; async stale icon rejection, no icon request
   for font-only/equal update; no catalog/page identity/order/focus/query changes.
5. Queued latest-wins during held pointer, physical/direct settling, drag, title
   edit and folder motion; teardown/hide/resume; failed persistence and restart.
6. Nonzero focused/full XCTest, Debug/Release, diff-check, independent scoped
   review, source fingerprint/unique candidate hash, real GUI/restart/physical AB.
   Never turn synthetic tests into actual GUI/restart/VoiceOver/physical PASS.

## Delivery, maintenance and unresolved decisions

Preserve dirty tree/history/previous candidates. English files/comments and native
Chinese user labels. No install/sign/notarize/publish/commit or process stops.
Main handles owner/store/settings integration and serialized Swift; helpers may
own disjoint geometry/consumer/test files only after contract confirmation.
Maintain a visible stage summary, project memory and full parity ledger.

Unresolved: confirmation of preferred32–64/9–16 ranges and auto-fit semantics;
exact safe presentation boundary across existing interaction owners; final icon
key invalidation interfaces and settings scrolling need current-code discovery.
Rows/columns remain a separate unanswered question. Library, localization, extra
explicitly gated actions/gestures remain pending on the full parity ledger.

## Discovery evidence — current native font/grid limits

No-window NSFont measurement on the current toolchain reports system font11pt
line13pt and16pt line19pt; member-count15pt needs18pt. Existing folder count occupies
y14–26 in88pt cells; a64pt icon under current fixed12pt top inset starts y12, causing
12pt overlap. This disproves a constant-only size change. Fit semantics need
confirmation, and the default48/11/10 geometry must remain a strict regression.
Evidence: .build/verification/20261013/icon-type-discovery/font-metrics.swift/.log.
No rendered quality/performance/real GUI claim is made by these measurements.

## Survey reconciliation — do not silently rewrite default folder layout

ICON_TYPE_INTEGRATION_SURVEY documents current folder compression: even maximum
700pt panels give seven-row cell height~65.14pt and default48pt icons overlap the
14pt caption; shorter panels can spill because the56pt cell-height floor defeats
fit. These are source-derived arithmetic, not a rendered screenshot. Preserve
legacy default geometry in already-fitting cells; explicitly include a separately
reproduced maintenance exception for clipped/compressed defaults before enabling
universal no-overlap acceptance. No production fix or accepted fit contract yet.

Drag preview is separately drawn (fixed96x88, icon48/caption11) and must receive
confirmed style/label visibility at next drag start; do not restyle an active drag.
Overlay whole-cell launch semantics differ from ordinary icon+4pt hits and must
remain unchanged. Drop geometry and saved logical indexing use whole cells.
The SystemIconLoader sizing/key issue needs a resolved implementation choice, not
an unsupported promise of larger-quality raster output. Prefer reusing existing
keys where loader already provides suitable runtime icons; any needed new request
policy is bounded and independently reviewed. User confirmation remains pending.

## Proposed contract amendment — display-only icon sizing

Current SystemIconLoader (Sources/AppIconPipeline/IconLoading.swift:31–37) returns
the public NSWorkspace runtime icon and does not rasterize by IconKey.pointSize.
Creating extra size keys would duplicate cache variants without proving better
resolution. Therefore supersede the earlier adaptive-request planning branch:
this slice changes DISPLAY geometry only and keeps existing48pt request keys,
binding tokens, generations and loaded images unchanged. No scan/page reload/new
icon request on either icon-only or font-only Apply; no stale-size request exists
to accept/reject. Existing identity/reuse/teardown async guards remain mandatory.
Any future actual raster-resolution policy is a separately specified requirement,
not silently bundled into a scalar appearance setter. Preferred32–64 values and
auto-fit geometry remain unchanged and still require confirmation. Native runtime
icon quality at the requested display size is an exact-candidate rendered gate,
not established by reading loader source or by synthetic generic icon fixtures.

Caption customization targets app/folder item names only. Member-count font10pt,
folder heading/editor22pt and footer12pt stay fixed; their bounds must still be
reserved. Drag preview/proxy must match confirmed name/style/visibility on next
interaction without altering outer drop rectangles or folder input semantics.

## User approval / exact implementation interfaces

User explicitly selected recommended icon/type contract on2026-10-13; scope and
32–64/9–16auto-fit/defer semantics confirmed. Rows/columns remain unapproved.
Display-only sizing amendment preserves existing image request keys/generations,
zero new icon/scan/wallpaper work for size/font-only changes. Member-count10pt,
folder heading/footer and all outer grid/cell/drop positions remain unchanged.

AppGridUI owns public GridItemAppearance: Codable/Equatable/Sendable integer
preferredIconSide(default48,32...64), appLabelFontSize(default11,9...16), isValid,
static default. AppGridCellView/AppGridPageView/FolderOverlayView expose
itemAppearance: GridItemAppearance (invalid setters restore old/no side effects).
AppGridCellView.layout uses public GridItemContentGeometry(bounds:appearance:
showsLabels:isFolderCell:) or equivalent shared pure returned frames for icon,
name and count; existing48/11/10fitting geometry must remain exact. AppKit font
metrics determine readable single-line caption height (default14); fitted icon
respects12pt top padding, minimum2pt caption separation and cell horizontalbounds.
Compressed/tiny cells use bounded fitting or zero-sized content; never negative
rectangles/overlap/overflow. Hidden captions do not remove accessible names.

Main owns renderer propagation, store/schema2/settings/accepted-vs-presented
owner queue, lifecycle/idle wiring andtests. Worker A owns GridItemAppearance/
sharedgeometry+Cell/Page/Folder view properties+newtest files ONLY. Worker B
owns DragUIVisuals/newpreview tests ONLY after Library discovery helper closes.
No other source/test publish during Main Swift runs; direct implementation waves
use disjoint files. Preserve existing live/pool/new/proxy policies and fullparity.

## 2026-10-14 correction — folder grid arithmetic

The original source reserves title40+top24 and footer44+bottom12, totaling120pt,
NOT132pt. The earlier survey's panelHeight-132 derivations are incorrect by12pt.
At max700pt panel, actualarea580pt yields7-row oldcellheight~66.857pt, not65.14.
The56ptfloor still produces realouter-rowoverflowonshortpanels. Corrected actual
view tests red4methods191assertfailures/alreadyfittingexactPASS, repairfocused49/0
recorded in2026-10-14-folder-viewport-fit stage. This dated correction supersedes
only the arithmetic/deriveddimensions; all historicalbytes archived inprior
verificationcheckpoint-docs remain intact. No oldGUI/performancePASS implied.

## Approved folder-only layout delta — 2026-10-15/16

User explicitly approved Docs/ADAPTIVE_FOLDER_LAYOUT_SPEC.md: open folders now use a safe-content-relative adaptive grid, at most5x3, reducing capacity before sacrificing requested icon/caption geometry. The prior fixed-cell/capacity exclusions remain for outer/search grids but are superseded for the open-folder presentation only. Appearance persistence/defaults/ranges and canonical membership/order are unchanged. Caption visibility alone does not alter inner capacity. A safe reflow that changes inner capacity necessarily rebinds its new visible member set via the existing cache/generation pipeline; unchanged-capacity font updates still issue no new icon requests. No per-frame reflow/IO. This is a documented human-approved delta, not a silent reinterpretation of the original acceptance.
