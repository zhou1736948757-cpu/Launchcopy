# Folder Frosted Material Discovery — 2026-10-16

## Objective / user feedback
User requests iOS-inspired frosted glass/background blur instead of the opaque dark folder panel, retaining no whole-background dim. User did not explicitly answer the prior two-gate acceptance clarification; do not record physical gesture or shadow PASS from generic OK.

## Discovery
Read current AppKit folder/material and wallpaper architecture and actualmacOS26.5.2, deploymenttarget14. Baseline463inputhashes unchanged. Followed localapple-design materials/accessibility guidance; official Apple HIG, AppKit material/blending documentation and iPhone folder guide inspected. Private iOS folder implementation/blur parameters are not documented by these sources, and no SpringBoard reverse engineering/copying is proposed.

## Decision / scope
Created Docs/FOLDER_FROSTED_MATERIAL_SPEC.md PROPOSED_PENDING_USER_CONFIRMATION. Recommend one native within-window material behind stable folder content/editor, panel-only blur, clear exterior, panel accessibility fallbacks, no full-screen blur/extra timer/CPUfiltering/frame work or engine/layout changes. Existing native startup route repair retained. Need user choice panel-only vs expanded outside blur before implementation.

## Changed files / evidence boundaries
Docs only in this discovery stage; no implementation/tests/build/UI actions. Prior2791green and appbb1cabc3running are historical evidence, not new material verification. No subagent needed for this bounded discovery/decision step; maxconcurrency1. No referenceproject/assets/formaldata/systemsettings/process/installation changes. Next executable action: obtain confirmation, then implement bounded view/material slice and native performance/visual tests.

## Superseding conditional scope — 2026-10-16
User chose panel plus exterior blur, then stated performance is more important and exterior blur may be omitted if expensive. Updated specification and project PLAN/MEMORY, preserving the original proposal as history. Main inspected current container/overlay composition, existing thumbnail wallpaper filter and presentation-aware exit. Dispatched one read-only architecture sidecar (total2 including Main), no concurrent writes/tests. Main owns scope/performance contract; sidecar owns integration feasibility advice. Apple Core Image performance guidance supports reduced output pixel count and context reuse, not any measured speedup for Launchcopy. Current production code and candidate unchanged. No benchmark, new test/build or GUI acceptance claimed. Outstanding: architecture decision, appropriate confirmation for material contract changes, implementation and matched native evidence.

### Sidecar result / closeout
Aristotle read-only architecture review completed, no files edited or executions/UI. Confirms capture must include root siblings and exterior image must not be a child of transformed FolderOverlayView; direct low-resolution still capture at a stable opening boundary is a candidate, not a proven optimization. Main recorded findings in Workflow/results/FOLDER_BLUR_PERFORMANCE_FEASIBILITY.md. Agent closed; no live test/build jobs or new candidate. Specification records conditional scope and authorized panel-only fallback, not falsely approved/implemented snapshot internals.
