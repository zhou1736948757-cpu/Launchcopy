# Real Folder Rename — Next Bounded Repair

Date: 2026-10-13
Authority: existing approved folder organization/rename experience and ADR-009
renameFolder mutation; this fixes missing application wiring, not a new name model.

## Current evidence and problem

FolderTitleEditor exists and normalizes/cancels/commits input, but AppDelegate
creates it without attaching it to the open overlay. beginTitleEditing therefore
finds no editor window, while commitFolderTitle only ends editing and persists
nothing. Existing domain/editor tests do not establish a working user rename flow.
FolderOverlayView exposes a drawing-only titleLabel and the canonical layout has
an existing atomic renameFolder mutation. Full parity ledger records this gap.

## Repair approach

1. Add a bounded title-edit request/host/frame seam to the open overlay. Mount the
   app-owned editor in the actual panel using current layout coordinates; use a
   discoverable title interaction/accessibility control, not a global shortcut or
   unapproved new keyboard-navigation contract. Keep visual-only exit and move-out
   proxies inert. Reposition the editor on layout and restore title drawing on exit.
2. Capture edited folder ID, canonical layout snapshot/generation, catalog revision
   and edit lifecycle token. Start only when the shared layout readiness guard
   allows it, no active physical gesture/drag, and folder ownership is current.
   Initialize editor from canonical persisted title and reset its finish gate.
3. Enter/focus-loss commit uses the existing64-grapheme/trim/blank-fallback policy.
   Revalidate the captured edit before invoking LayoutMutation.renameFolder and
   the shared workspace commit. No-op/cancel/reject does not enqueue persistence.
   Member IDs/order, hidden/missing refs, query and paging parameters remain unchanged.
4. Escape, folder switch/close, search, hide, screen change and teardown cancel
   obsolete edit BEFORE responder changes can trigger focus-loss commit. A stale
   callback can never rename a newly opened folder or resurrect a removed view.
5. The editor itself still does no disk I/O or diagnostics. Its successful owner
   transaction writes the title only to the existing controlled private layout
   payload, as already allowed by ADR-009; not to telemetry/reports/stdout.

## Regression and delivery gates

Actual title interaction -> mounted editor -> production callback -> canonical
layout -> one persistence enqueue, with member order/identity unchanged. Test
Enter/focus-loss once, Escape none, duplicate/stale callbacks, same-title/blank
no-op, Unicode limits, folder switch/close/hide/teardown, readonly/bootstrap and
hidden/missing refs. Reopen/reload checks must use actual app owner, not only domain
mutation fixtures. Keep existing drag/context/search/keyboard tests green.

Independent source review, focused/full suites, Debug/Release and unique candidate
with hashes. No install/sign/commit/process stop. Exact-candidate GUI/restart and
matched physical performance remain separate and require an unlocked CUA session.

## Related follow-ups

Related lifecycle follow-up: AppDelegate has no observed layout flush/termination
barrier. Verify accepted asynchronous writes when Quit immediately follows an edit,
and implement a bounded existing-store flush/wait if required. Do not conflate
resident hide with actual process termination. Queued/in-flight write tests are
needed before claiming restart durability for immediate Quit.

Approved failure policy (user confirmed2026-10-13): ordinary Quit waits asynchronously for accepted enqueues
and bounded store flush. On timeout/failure, ask Cancel Quit or Quit Anyway, with
Cancel as default; never silently approve data loss. Queue and drain mechanics
must pass fault-injection before wiring the actual termination delegate; retain
the user choice and distinguish resident hide from process termination.

Identity follow-up: management metadata currently keys lookups by the preferred
record reference. Verify hidden/alias continuity when an old path-only record gains
a bundle ID; canonical layout preservation alone does not prove that separate
namespace preserves the flags. Keep explicit unhide/reset-alias working for old keys.

Do not re-label the full migration complete after this repair: remaining visual
settings, page-dot decisions, sources/watching, localization and Library still apply.

## 2026-10-15 maintenance addendum: preserve existing key-restoration ownership
The documented title-edit > folder > search > grid priority applies before a mounted title obtains its native field editor, as well as after it has one. A current owned/mounted title request must not fall back to keyboard solely because currentEditor() is temporarily nil. Conversely an existing field editor owned by a mode control is already the correct first responder; a key-window notification must not unnecessarily reacquire its control. Stale contexts, unmounted/moved editors and different windows must not win restoration.

This repairs existing responder priority and idempotence only. It does not activate a background app, order a window front, change passive test-entry behavior, install an event interceptor, or redefine ordinary focus-loss save/IME cancellation. Tests use actual composition/observer and explicit synthetic pending-admission fixtures; exact-candidate native inactive and already-active controls remain separate. See the title-edit-focus stage for before/after evidence and limits.
