# Folder Assignment — Approved Scope Implementation Contract

Date: 2026-10-13
Authority: approved LAUNCHBETTER_PARITY_SPEC.md sections3.5 and6.3.

## Outcome and scope

Expose the existing organization operations through app context menus: Move to
an existing folder, and Move to main pages for a current member. This completes
the approved safe folder-assignment requirement without introducing a new layout
model, destructive actions, one-member folder creation or alternate persistence.
No copying of reference code/resources or review of original reverse-engineering
materials. Preserve all unrelated dirty state and historical candidate artifacts.

## Functional and data contract

- Folder choices come from canonical current layout, not filtered visible cells.
  Include hidden/temporarily unavailable groups; exclude the app's current owner.
  Order by canonical top-level position. Folder IDs, not names or menu indices,
  determine the target; duplicate titles remain distinguishable with a local
  ordinal suffix. Do not log titles, app identities or membership.
- Menu bindings retain weak cell ownership and expected item token, catalog
  revision, canonical URL, exact layout snapshot/generation and selected folder ID.
  Revalidate all before a mutation; reject stale menus/reused cells/hidden apps,
  renamed or removed targets, active drag/title edit/teardown and read-only layout.
  Healthy app-management future schema must not prevent layout-only operations;
  layout-store protection independently governs organization writes.
- Apply existing LayoutMutation.addToFolder with tail insertion. Cross-folder
  move and source-folder dissolution remain atomic existing behavior. Member move
  out inserts after the source folder's canonical position, preserving other
  hidden/missing references. No-op/rejection causes no layout write or UI refresh.
- Both drag and menu successes enter the same application commit function for
  session layout, provider/search presentation, focus/folder reconciliation and
  asynchronous coalesced persistence. Menu actions cancel stale input/animations
  before commit; re-run active global query without changing catalog revision.
- Shared write readiness also protects drag start/final commit: no organization
  mutation before saved-layout bootstrap or while layout store is protected.
  Ordinary clicks keep their existing fallback. When cancellation runs an idle
  callback, revalidate a weak cell/token closure before closing any folder UI.
- Preserve an existing stored reference even if the same app now has a bundle ID;
  record matching determines representation, not preferred-key inequality. No
  implicit reference migration or duplicate-tail append. Cached drag geometry and
  source identity use that same stored reference. Member view bindings receive the
  actual catalog revision, independently of folder-generation tokens.
- Capture the intended store/generation before scheduling persistence, and reject
  superseded work before enqueue. A store replacement cancels accepted-but-not-yet
  enqueued work; an already in-flight write remains on its original store and cannot
  publish obsolete state feedback. Never route an old write to a replacement store.
- Menu feedback is neutral and local. Do not claim success for a stale or protected
  operation. No filesystem changes except the existing private layout store.

## Architecture, performance and maintenance

Independent menu sub-controller owns submenu generation and immutable action
binding. AppContextMenuController embeds its output; application owner supplies
canonical layout/protection and dispatches mutation outcomes. Keep folder mutation
policy independently testable; no synthetic pointer/key events or new drag logic.

Budget: no scan, icon request, preferences/layout I/O or list rebuild per frame.
One bounded menu build when requested; one layout mutation/projection/persistence
enqueue per successful action. Existing resolved-layout cache is reused. Main owns
application commit/search/bootstrap integration; one Worker owns bounded menu
consumer/policy/tests. A separate Reviewer follows stable integrated evidence.
At most3 active agents including Main; Main alone executes SwiftPM/GUI/builds.

## Acceptance and delivery

Regression tests: default no-folder menu; app-to-folder and cross-folder move;
member-to-top-level dissolution and order; duplicate titles; hidden/missing refs;
exact snapshot/generation stale rejection; reused/deallocated cells; query retains
original/alias matching and layout order; future/read-only protections; active drag
and teardown reject; no-op produces zero enqueue. Test actual selectors and owner
callbacks, not merely mutation models. Keep full suite green, independently review,
build Debug/Release and package uniquely with executable hash/source manifest.

Exact-candidate real context-menu/keyboard/restart/physical paging gates remain
pending locked desktop; source/tests are not GUI acceptance. No install, signature,
notarization, commit, publishing or process stop without explicit authorization.

## Next contract, not included

Page-dot direct navigation has separate interruption/focus/capacity decisions.
Record its proposal and obtain specific approval before extending PagingCore.
