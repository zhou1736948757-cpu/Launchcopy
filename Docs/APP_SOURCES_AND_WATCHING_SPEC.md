# Application Sources and Change Watching — Approved Slice

Date: 2026-10-13. Status: APPROVED_CONTRACT — user selected the recommended root/removal/automatic-refresh scheme on2026-10-13.
Authority: approved parity scope contains source management and install/remove
watching. This document makes the privacy, root-removal and watcher defaults
explicit before substantial cross-module implementation.

## Product outcome and scope

Let users discover apps in selected local application folders and refresh when
applications are installed/removed, without changing the validated pager or
losing saved organization. Reuse CatalogRepository/latest-wins idle commit and
runtime icon pipeline. No parallel launch path, cloud sync, usage tracking,
Spotlight/Dock databases, raw filesystem-path diagnostics or reference code/assets.

## Confirmed decisions

Keep current default system/user Applications roots as fixed baseline. Allow
additional explicitly selected local folders via NSOpenPanel, but reject whole
filesystem/home/volume roots, remote/network locations, non-directories and aliases
escaping admitted roots. App bundles and their internal helper directories are not source folders.
Added roots must be readable using ordinary current
permissions; do not request Full Disk Access or change OS permissions. Removing
an added source removes only discovery input; do not uninstall/delete apps or
remove their canonical saved refs, folders, hidden flags or aliases.

Automatic refresh default On for admitted roots. Public directory change signals
produce neutral invalidation only, merged/debounced before the existing async
scanner. Native signals never become a log of installed app identities. Manual
refresh remains available; watcher unavailable/degraded is visible, not silent
advertising of real-time coverage. No timer/frame polling. Do not follow directory
symlinks by default; preserve existing scanner explicit-follow test contract.

## Data and interfaces

Independent versioned sources preference payload, separate from layout,
activation/appearance/management. Store canonical selected root references,
refresh toggle and no personal usage. Future schemas read-only; corrupt data
uses baseline safely, no automatic overwrite. Error states contain no private
path in diagnostics. Selected paths may be visible in the settings list/private
payload because that is the user's management operation, not telemetry.

Changing sources is a transaction: validate draft -> persist -> replace bounded
watch set -> request existing async catalog refresh. No success on failed save,
no direct provider/renderer update from the file-event thread. Existing snapshots
remain until the new refresh can commit; current gestures/search/drag/folders
keep the existing cancellation/idle contracts. Generation gates discard stale
watch events and callbacks after source switch/hide/teardown. Resident hide does
not lose settings or delete layout; process teardown releases watcher resources.

Watcher implementation choice must prove recursive install/remove coverage for
ordinary nested directories without walking app bundle contents or enabling
unbounded descriptor counts. Use a public root-level recursive event stream if
needed; bounded/debounced existing rescan is the only output. Failure handling
and event storm tests precede the real service consumer. Do not claim a root-only
nonrecursive descriptor catches every nested installation.

## Test isolation and safety

Extend the explicitly approved candidate-local test namespace for sources.
Writable isolated profile accepts only its synthetic Applications descendants,
not user-selected external roots; production adapters never leak into fake test
services. Never seed the ordinary sources store from a test or fixture. Tests
use temporary synthetic apps and injected watch events, not actual root changes.

## Acceptance, budgets and delivery

Root canonicalization/dedupe/boundaries, missing/unreadable/reappearing folders,
future schemas/corruption/no-save mutation; actual settings controls/add/remove/
manual refresh/auto toggle; installation/removal/nested events/merged storms,
latest-wins generation, teardown cleanup and no private event diagnostics.
Real idle-boundary catalog update preserves latent layout and metadata, query,
keyboard/drag/launch validation. Source disappearance cannot become layout deletion.

No added per-frame work/IO; bounded retained watchers/event backlog, no icon work
on file callback, one async refresh per merged batch plus existing latest-wins
follow-up. Record workload and compare existing scanner/pager cost without using
synthetic cadence as physical acceptance. Independent source review, focused/full
nonzero tests, Debug/Release, unique candidate/hash/source manifest. GUI/real
filesystem watching and physical AB remain distinct gates. No signing/install/
commit/process stop or access outside approved roots.

## Resume

Contract confirmed. Implement independent preferences foundation, root admission,
settings controls and bounded public watcher in separated ownership slices. Main
keeps application composition integration single-writer; all execution serial.
Do not treat an unwired preference model as this feature complete.
Continue already-approved accessibility repairs and preserve the complete parity
ledger; do not call the whole migration complete after source settings alone.

## Public API research (primary references)

The recursive event stream accepts directory hierarchy roots, and using events
from now avoids replaying historical modifications. Latency provides event
coalescing; this supports the bounded rescan design, not a performance PASS.
[Apple FSEventStreamCreate](https://developer.apple.com/documentation/coreservices/1443980-fseventstreamcreate).
A dispatch-scheduled stream must eventually be invalidated while still scheduled,
then released; do not remove its queue before invalidation.
[Apple FSEventStreamSetDispatchQueue](https://developer.apple.com/documentation/coreservices/1444164-fseventstreamsetdispatchqueue).
Volume locality is an optional requested resource value; absence is not proof of
a local source and must be handled explicitly by admission.
[Apple URLResourceValues](https://developer.apple.com/documentation/foundation/urlresourcevalues).
