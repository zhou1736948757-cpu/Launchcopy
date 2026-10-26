## Historical proposal superseded — 2026-10-19 clarification

Do not treat the original PROPOSED paragraphs below as the current contract. The human subsequently approved `Docs/MAIN_GRID_CAPACITY_SPEC.md` (2026-10-17), including main-grid-only3…8 rows/columns, default5×7, independent adaptive folder capacity and small-window readability protection. The later approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md` moves these controls into live, automatically saved Appearance; there is no healthy Apply button or separate Grid tab. `Workflow/results/MAIN_GRID_CAPACITY_RESULTS.md` and `Workflow/results/LIVE_APPEARANCE_GRID_RESULTS.md` contain delivery evidence; the human accepted live changes. In particular, this old proposal's shared folder-capacity and explicit-Apply assumptions must not override the newer decisions. Original text is retained verbatim as history, not renewed approval or implementation instructions.

# Grid Appearance and Capacity — Next Slice Proposal

Status: PROPOSED_CAPACITY_CONTRACT,2026-10-13. No implementation started.
Authority: approved parity scope includes layout settings; adjustable capacity
requires a separate user decision. A concise asynchronous question has been sent.

## Outcome and scope

Expose independently implemented icon sizing/type settings and adjustable grid
rows/columns on the existing pager. Keep the current default5 columns by7 rows,
35 cells/page and ALL physical paging parameters. No reordering/migration of saved
app/folder references, new app identity, private system layout access or resources.
Do not redefine whole parity as only the implemented scalar controls.

## Recommended capacity contract (awaiting confirmation)

- Apply a new capacity only at an idle, non-dragging, non-title-editing boundary;
  do not interrupt a gesture/drag/editor to make settings apply faster.
- Preserve the current selected visible entry as anchor, otherwise the current
  visible page's first valid app/folder; remap its index to the new page/slot.
  If gone/hidden, choose nearest still-valid visible entry deterministically.
- Maintain the same current search/query and logical app/folder/hidden/alias order.
  Never persist pagination indices as canonical arrangement.
- Folder member capacity follows the same configuration. Keep an open folder and
  selected member identity when still valid; remap inner page, not outer state.
- A pending update is latest-wins; display saved/queued/applied/failure honestly,
  protect accepted writes on Quit, and reject stale settings/session callbacks.
- Re-render at one discrete boundary; invalidate old binding/generation/focus/drag
  geometry so an old icon/cell/request cannot write into the changed capacity.
- Validate numeric bounds/product overflow and viewport fit, with bounded controls,
  slots, icon cache/request work and clear errors. Exact numeric UX ranges still
  need design/evidence from the prior requirement audit, not copied implementation.

Alternative user option: first icon size/type only; row/column control stays
explicitly pending, not certified as absent/not needed.

## Architecture and data

Independent versioned layout/appearance preferences (safe defaults, corrupt/future
policy, candidate-local isolation). Coordinate provider capacity, Surface requests,
renderer metrics, keyboard navigator/typewriter model, folder geometry and drag
logical index mapping through ONE owner transaction, not separate mutable values.
Reconcile canonical ordering and current query via existing idle assembly seam.
No CatalogRevision forgery; use a distinct neutral layout-generation/configuration
boundary for bindings. Existing pinned physical content is not changed mid-input.

Icon/type-only settings should update views without catalog rescans, per-frame
IO/image creation, persistence or classification. Capacity/frame-cost/hit geometry
budgets must be recorded before implementation; real physical AB stays unverified
until matched hardware/catalog/viewport/build measurements are collected.

## Acceptance and maintenance

Default35/backward compatibility; first/last/partial pages; same/count-changing
search; hidden/alias/latent refs; selected folder/member anchor; typewriter arrows;
held input/queued latest update; unexpected failure/future settings; save/real
restart; stale icon/cell/drag generation; Reduce Motion/Transparency independently.
Independent source review, nonzero focused/full tests, Debug/Release/hash/source
manifest, exact-candidate GUI and matched physical budget before acceptance.

Preserve old artifacts/dirty work and all parity ledger rows. No reference source/
assets, installation/signing/commit/process stop or cleanup. Full objective stays
active. Only the specific user-confirmed branch may be implemented next.

## 2026-10-16 — Confirmed folder-only exception; outer decision still pending

The human separately approved and received Docs/ADAPTIVE_FOLDER_LAYOUT_SPEC.md: open-folder capacity is now independent of the outer pager, maximum5x3 with safe adaptive reductions. Therefore the older proposed sentence “Folder member capacity follows the same configuration” is NOT an approved requirement and must not be carried into outer-capacity implementation. Outer rows/columns/anchor controls remain the separately pending product decision; the earlier asynchronous question is not answered by the folder-only approval. Do not resend that question or implement arbitrary numeric ranges while the decision remains unresolved. Existing5x7/35 outerdefault and acceptedphysics remain unchanged. Forty-six new folder regressions/2746green and actualnative layout transactions do not certify an outer adjustable-capacity feature.
