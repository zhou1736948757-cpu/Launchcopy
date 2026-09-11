# Task Packet: T-1E-F

- **Task ID**: T-1E-F
- **Role**: Independent Reviewer + docs + physical gates (Main-coordinated)
- **Phase**: 1E — independent review, documentation, physical acceptance
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §6 T-1E-F, §10, §12, §14

## Objective

Independently review every Phase 1E implementation task, re-run full tests/builds, run provenance/privacy/visual-neutrality scans, execute real fullscreen GUI + physical keyboard/trackpad gates, and produce the final report with a unique next-phase recommendation.

## Dependencies

- **T-1E-A..E** all complete and individually reviewed (each implementation task gets an independent Reviewer PASS gate before it is considered done).

## Context

**Fresh Context requirement (source discipline)**: fresh context, no old reverse-engineering context. Never read the forbidden sources (see T-1E-A).

## Scope

- **Independent review** of each implementation task (T-1E-A..E): read-only, never fixes code. A Reviewer finding is evidence for a repair task, not a silent edit. Formal Reviewer FAIL increments `worker_failures`; per failure policy (FAIL#1 → Chief Decision Delta; FAIL#2 → fresh Expert Worker; Expert FAIL → Chief).
- **Main re-runs** full `swift test`, `swift build -c debug`, `swift build -c release`; records real executed/passed/failed counts (not pre-written totals); records Debug/Release executable SHA-256. Existing 631 baseline tests must not decrease or silently skip.
- **Provenance / privacy / visual-neutrality scan**: no forbidden sources read; no real names/titles/paths/query in telemetry/JSONL/stdout/signpost/profile/report; only neutral counters; no PagingTelemetry schema change; no Buho/LaunchBetter visual/brand/asset/copy replication.
- **Physical gates** (user real fullscreen + physical keyboard/trackpad): `MANUAL_FOLDER_GUI_GATE`, `MANUAL_KEYBOARD_GATE`, `MANUAL_TRACKPAD_60HZ_REGRESSION_GATE`, `MANUAL_REDUCE_MOTION_RESIZE_GATE`, `MANUAL_120HZ_GATE` (`BLOCKED_BY_HARDWARE` on 60Hz panel unless a real 120Hz device is available). Record device, actual refresh-rate evidence, macOS version, Reduce Motion, run params, test rounds, abnormal runs, and user subjective conclusion.
- **Docs deliverables**:
  - `Docs/PHASE1E_SPEC.md`
  - `Docs/PHASE1E_VALIDATION_PLAN.md`
  - `Docs/PHASE1E_REPORT.md` (completed capabilities; modified files + reasons; actual test count + build/hash; each Reviewer conclusion; manual gates PASS/NOT_RUN/BLOCKED; privacy + provenance scan; known limitations; drag/persistence explicitly not done; `>25ms` long tail still unresolved; unique next-phase recommendation)
  - `Docs/PHASE1E_BASELINE_MANIFEST.sha256`
  - Appends: `Docs/VALIDATION_RESULTS.md`, `Docs/IMPLEMENTATION_LOG.md`, `Docs/PARAMETER_RATIONALE.md` (new params only), `Docs/PRIVACY_DATA_MAP.md` (folder data flow)
  - `PROVENANCE/COMPONENTS.md` (append), `PROVENANCE/ACCESS_DECLARATION.md` (append per actual participants)
  - `Workflow/results/T-1E-*.md`, `Workflow/reviews/T-1E-*-r*.md`

## Out of Scope

- Any product code change (this task is review + docs + gates only).
- Modifying `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`.
- Drag / persistence / Hot Corner / Spotlight / Launchpad-Dock DB / brand visuals.

## Expected / Allowed Write Scope

- `Docs/` (Phase 1E spec/validation/report/baseline manifest + appends)
- `PROVENANCE/` (appends)
- `Workflow/results/T-1E-*.md`, `Workflow/reviews/T-1E-*-r*.md`

## Forbidden Write Scope

- All product source trees (`Sources/`), `Tests/`, `Package.swift`.
- `Workflow/PLAN.md`, `Workflow/MAIN_BRIEF.md`, `Workflow/tasks/T-1E-*.md` (Chief-owned; do not rewrite).

## Constraints

- Reviewer is read-only on code; never fixes code.
- Do not fabricate PASS; record `PASS_USER_REPORTED_WITH_EVIDENCE` (with evidence pointer), `PASS_USER_REPORTED` (verbal only, minimal pointer), `NOT_RUN`, or `BLOCKED_BY_HARDWARE`.
- If automation passes but the user has not physically tested, write at most `AUTOMATED_IMPLEMENTATION_VERIFIED` + `PHYSICAL_ACCEPTANCE_PENDING`.
- Diagnostics stay `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`; never write `ALL_HITCHES_FIXED` / `ROOT_CAUSE_FOUND` / `FIX_VALIDATED`.
- No commit/push/tag/reset/clean/release; do not modify LaunchBetter / BuhoReverseNotes.

## Acceptance

- `INDEPENDENT_REVIEW = PASS` (each implementation task independently reviewed).
- `FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT`; `BUILD_DEBUG = PASS`; `BUILD_RELEASE = PASS`.
- `PRIVACY_REDLINE = PASS`; `PROVENANCE_REVIEW = PASS`.
- Manual gates recorded honestly.
- Final report with unique next-phase recommendation: `RECOMMEND_PROCEED_TO_PHASE_1F_DRAG_AND_PERSISTENCE` (if all pass) or `PHASE1E_AUTOMATED_COMPLETE_PHYSICAL_PENDING` (if physical gates incomplete), keeping `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` / `CAUSALITY_UNRESOLVED_FOR_GT25MS`.
