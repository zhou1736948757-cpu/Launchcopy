# T-1D-planning — Phase 1D Chief planning + ADR-007 architecture

- **Role**: Chief (plan interpretation / architecture / scope / acceptance)
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` (authoritative, 949 lines, SHA-256 `78a0e5acdc4f082f1f274a94cd11ea93200a150c1c20d94fd87b279e56c00154`)
- **Status**: EXECUTING (Gate 0 passed first)

## Gate 0 (Main, done before Chief)
- `swift test` = **526 tests, 0 failures, exit 0**; `swift build -c debug` exit 0; `swift build -c release` exit 0.
- Baseline manifest: `Docs/PHASE1C_BASELINE_MANIFEST.sha256` (frozen inputs: PagingCore dir, AppLaunchController.swift `bc596a4e…`, Package.swift `c214f04f…`, Phase 1C acceptance docs).
- STATE: phase=PHASE_1C_COMPLETE, active_agent_jobs=[], watchdog pid 18983.

## Chief deliverables
1. Rewrite `Workflow/PLAN.md` for Phase 1D (supersede Phase 1C plan; keep 1A/1B/1C history in reports/ADRs).
2. Rewrite `Workflow/MAIN_BRIEF.md` for Phase 1D.
3. Decide ADR-007 provider/filter/reload architecture (Prompt §19 list of 10 comparisons) — Main writes the ADR doc from Chief's decision.
4. Produce task packets T-1D-A..E (writable scopes per Prompt §15, mutually exclusive).

## Constraints (from Prompt)
- PagingCore FROZEN; CatalogRevision single owner = CatalogRepository (no fake revision / query-hash-in-revision / generation-as-revision).
- Same-revision reload seam in PagingUI only (narrow, e.g. `reloadCurrentPresentation()`); seven-field ItemBindingToken default stays.
- Search = pure in-memory filter of committed CatalogSnapshot; no Spotlight/NSMetadataQuery/persistence.
- Launch reuses AppLaunchController.handleCell; no parallel path.
- Privacy: query/result names never in telemetry/log/profile; no PagingTelemetry schema change.
- Diagnostics stay CAUSALITY_UNRESOLVED/PARTIAL_CONTRIBUTOR_SUPPORTED/PRODUCT_DEFAULT_UNCHANGED.
- No commit/push/tag/reset/clean; no forbidden-source reads.
