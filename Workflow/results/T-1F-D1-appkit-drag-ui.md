# T-1F-D1: AppKit Drag UI

Status: PASS (closed by Main after repair waves)

The D1 Worker (1d7a77d6-4e65-407d-aff1-13b88653e64a) was interrupted mid-wave (context exhaustion) after landing all 8 write-scope files. Two repair waves fixed the remaining issues and merged with independent PASS reviews:
- T-1F-D1-test-repair (3 files: isTornDown permanent teardown; retainedHost + catalogSnapshotProvider wiring; folderLab/staleBefore/40-app fixture fixes) — review PASS, merged.
- T-1F-D1-visuals-preview-hidden-repair (1 file: hide() all four indicator views in configureViews) — review PASS, merged.

Full-wave independent review (Workflow/reviews/T-1F-D1-appkit-drag-ui-r1.md): PASS — all §5.1-5.7 invariants verified (unified input arbitration hard gate; threshold 6pt; click only below threshold; drag never launches/opens; onCommit seam; edge paging via KeyboardPageTurner/overlay nextPage-prevPage; move-out arming; unified cancel 8 reasons zero residue; isTornDown permanent; neutral visuals + Reduce Motion; privacy/pasteboard neutrality; hot-path prohibitions). Scope clean (8 files 09:18-09:46; frozen tree + forbidden files untouched). Serial verification: debug exit 0; swift test 997 executed 0 failures; release exit 0.

MINORs (non-blocking, from full-wave review): unconditional DBG prints in coordinator; preview shows same-source title text; handleClick fallback unreachable in production; results file in-progress (now closed by Main).
