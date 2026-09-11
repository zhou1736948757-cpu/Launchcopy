# T-1F-B6-planning — BUG6 修复波次规划（Chief）

Status: ready
Wave: 0 (planning; before any Worker dispatch)
Role: Chief (plan only; no product code, no source edits)

## 1. Upstream
- Workflow/BUG6-REPORT.md (4 user defects, baseline 1012/0, approval pending)
- Workflow/BUG6-FIX-PROMPT.md (authoritative fix plan by Ops; all file:line refs verified by Ops)

## 2. Required planning outputs
1. `Workflow/PLAN.md` — append Phase 1F BUG6-fix section: 3-wave semantic DAG, write-scope table, acceptance mapping to the 4 user defects.
2. `Workflow/decisions/D-2026-08-31-bug6-fix-plan.md` — Chief decision record, including the ADR-010 M3 revision (createFolder top-level position = drop-target position, not min original index; supersedes the ADR-010 M3 implementation note).
3. Task packets:
   - `Workflow/tasks/T-1F-B6-wave-a.md` (defects 3+4 + insertion off-by-one; force two-way tests; no dead zones; pure-function zone geometry replacing DropZones dict fields)
   - `Workflow/tasks/T-1F-B6-wave-b.md` (defect 1: createFolder target-position semantics + header-comment sync; both-direction tests)
   - `Workflow/tasks/T-1F-B6-wave-c.md` (defect 2 layer 1: endSession on every early return; layer 2 split out as separate task with frozen-tree BLOCKED condition for AppLaunchController.install())
4. Memory candidates for MEMORY.md (Main gates).

## 3. Chief reading list (minimal)
1. Workflow/BUG6-FIX-PROMPT.md (full; authoritative)
2. Workflow/BUG6-REPORT.md
3. Docs/ADR-010-*.md (find exact filename) — M3 note to revise
4. Docs/ADR-009-*.md (generation invariants context)
5. Sources/AppGridUI/DragSession/DropIntent.swift (:74-209)
6. Sources/AppGridUI/LayoutDomain/LayoutMutation.swift (:94-126, :1-23 header contract)
7. Sources/AppGridUI/DragSession/DragMutationEngine.swift (insertion branch)
8. Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift (:103-235)
9. Sources/PagingPrototypeApp/AppLaunchController.swift (:93-98 install) — layer-2 frozen-tree assessment seed
10. Tasks packet format sample: Workflow/tasks/T-1F-D1-fix-ui.md

## 4. Red lines
- Never read LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse.
- Chief writes no product code and no test code.
- Frozen tree (no write ever): Sources/PagingCore/, AppCatalogCore/, MacAppCatalog/, AppIconPipeline/, PagingTelemetry/, PagingUI/, Package.swift, PagingPrototypeApp/AppLaunchController.swift.
- Wave packets must embed the full root-cause verified notes from BUG6-FIX-PROMPT (Worker does not re-diagnose).

## 5. Output discipline
- Packet format identical to T-1F-D1-fix-ui.md (Status/Wave/Role/§1 Root cause/§2 Fix spec/§3 Write scope/§4 Forbidden/§5 Required reading ≤4 files/§6 Verification/§7 Acceptance/§8 Output discipline).
- Reply <400 words; no large code blocks; list artifact paths created.