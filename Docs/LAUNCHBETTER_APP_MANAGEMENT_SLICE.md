# App Management Parity — Hidden Apps, Aliases and Safe Actions

Date: 2026-10-13
Authority: approved migration scope in LAUNCHBETTER_PARITY_SPEC.md

## Contract

Independently implement app hide/restore, aliases (search both original name and
alias), context launch/reveal and settings management. No app deletion, reference
code/resources, fake catalog revisions or changed paging physics/capacity/hit region.

Metadata is a separately versioned private preference namespace. Stable keys use
the existing PersistentAppReference comparison key, never display names, hashes,
opaque descriptions or array positions. Metadata IDs/aliases must never enter
diagnostics, telemetry, stdout or reports; generated test fixtures only.

Preserve the canonical scanned catalog, launch URLs and expected saved layout.
Hiding removes only visible app entries/search results/folder members. Hidden
references and folder membership remain intact; restoring recovers their places.
For hiding (not uninstalling), keep a folder with one visible member as that same
folder; hide an all-hidden folder until a member returns. Actual logical folder
dissolution remains owned by existing layout mutations, not metadata edits.

Aliases trim surrounding whitespace; blank removes the alias; reject internal
control characters or more than128 graphemes. Aliases change displayed names but
not identity, icon keys, ordering or executable URLs. Original name and alias both
match using the existing case/diacritic/width folding; bundle-ID matching deferred.

## Ownership and update architecture

- Pure AppGridUI metadata value/projector; independent application store/coordinator.
- Provider retains canonical composition/folders and expected layout separately from
  managed presentation. Latest metadata stages/commits at idle with catalog/folder
  and current query. Same-revision updates use the existing presentation reload seam.
- Only new/changed metadata persists. Save first, then apply; future versions remain
  read-only, corrupt data remains untouched until explicit Apply. No layout writes
  for hide/alias edits, no scans or I/O in content/frame/drag paths.
- Launch and menu actions revalidate catalog revision/identity/hidden policy/file.
  Context menus share the existing launch path; Finder reveal uses public Workspace
  API. Alias editing is cancelable, and confirmation revalidates the original target.
- Settings lists canonical apps, including hidden entries, without loading icons.
  Restore and rename are real controls, not placeholder menu items.
- Drag consumes canonical expected layout but visible geometry. Annotate optional
  logical insertion indices by stable identity, including folder members, so hidden
  gaps cannot overwrite/misplace saved references. Existing default geometry remains
  unchanged. Do not disable dragging as a substitute for proper mapping.
  Reverse-map logical indices for indicator geometry, retaining cross-row anchoring.
  A catalog-unavailable member (not metadata hiding) still follows ADR-009 visual
  dissolution. Its displayed singleton is a proxy of the persisted group for
  top-level drag: reorder the group with latent members intact, and drops onto it
  target that group. Clicking still launches the displayed app. This translates
  scope ownership without deleting latent membership merely to enable a drag.
- Wire asynchronous existing layout-store loading with stale-result protection;
  pending first scan and layout restore must compose without losing either. This
  closes an observed missing startup-load hook; loaded layouts must never overwrite
  a user's newer drag. New installs without a layout keep current default ordering.

## Verification and performance

Defaults empty/unchanged; stable keys, normalization, invalid/future/corrupt stores;
canonical catalog remains unchanged; aliases/original search; hide all/restore;
folder0/1/many and membership preservation; search-query retention; pending scan;
persist/reload metadata and expected layout; hidden-launch rejection and stale menu
bindings; real controls-to-coordinator wiring; logical-index drop mapping and drag
commit after hidden gaps, including members. Existing full suite must remain green.

Structural budget: zero rescans/layout writes on metadata changes, one bounded
projection/reload per commit; no preference I/O in frame callbacks, constant-time
metadata lookup by stable key, no settings-list icon pipeline. Physical performance
acceptance remains separate from structural and synthetic test evidence.

## Current write ownership

Worker A: pure AppManagementPreferences model/projector and its tests. Worker B:
context-menu consumer plumbing in cell/page/Folder/renderer and its tests. Main:
provider/search/drag logical-index integration, application persistence/coordinator/
menu/settings/startup restore and tests/docs. Main waits for renderer owner before
editing AppCatalogAssembly. At most3 active agents including Main; SwiftPM serial.
No GUI until an unlocked session; preserve every existing dirty artifact.
