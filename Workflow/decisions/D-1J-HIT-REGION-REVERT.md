# D-1J-HIT-REGION-REVERT — User decision delta

- Date: 2026-09-16
- Trigger: Reviewer r1 FAIL, finding M1 (`Workflow/reviews/T-1J-LM-r1.md`)
- Decision authority: **user** (supersedes Chief escalation; the blocking question Q1 was
  itself a user-authorization question)

## Decision

1. **Launch hit-region contract = icon±4pt, restored.** The Phase 1J committed change to
   whole-cell `bounds.contains` is NOT authorized and is reverted. Clicking a name label or
   cell-interior padding misses the cell and resolves to the existing blank-click path.
2. The unified `acceptsLaunchHit(at:)` shared-contract architecture introduced by the B1
   work is **retained** — only the contract body reverts to the padded icon frame
   (folder cells use `folderSymbolView` frame, per baseline `6382bd9`).
   `appGridCellAncestor` / `blankClickResolvesToInteractionZone` structure stays untouched
   (orthogonal to hit width, per reviewer recommendation).
3. Falsified docs are reconciled to truth: `Docs/PHASE1J_FAILURE_TRIAGE.md` (dispositions
   4–5 + accepted-contracts list), `Docs/PHASE1J_CHECKPOINT.md:126`,
   `Docs/PHASE1J_REPORT.md` Track-A table must state icon±4 was **restored after r1 FAIL**,
   not claim it was never changed.
4. Minor findings handled in the same bounded repair wave: m1 `pendingPointerFolderID`
   gets a dedicated consume site or an explicit comment at `AppDelegate.swift:982-988`;
   m2 `rebuildFolderCompositionIfNeeded` pendingSnapshot preference is recorded in the
   closeout. m3 (pre-existing Sendable warning) stays recorded, untouched.

## Consequences

- Worker `T-1J-LM-HITREVERT` dispatched (swe-2-max declared); Reviewer r2 (glm-5.2-max)
  re-reviews the slice after the repair.
- Known trade-off accepted by user: under icon±4, a click on the name label or cell padding
  classifies as blank → launcher dismisses. This is the contract the Phase 1J spec recorded
  as user-accepted; the user reaffirmed it on 2026-09-16.
- GUI/physical re-verification of the boundary (cell gaps still blank→quit; icon±4 hits
  launch) joins the pending Track B manual gate list.
