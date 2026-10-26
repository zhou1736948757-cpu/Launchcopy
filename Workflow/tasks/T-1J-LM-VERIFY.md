# T-1J-LM-VERIFY — Review, Build, Candidate, and GUI Gates

Status: BLOCKED_ON_DEPENDENCIES
Owner: Verification Worker under Main orchestration

## Objective

Produce stable review evidence, run serialized verification, package a unique unsigned candidate, and record honest GUI/manual gates.

## Dependencies

- `T-1J-LM-WIRING`

## Scope

Create task-specific review bundles for independent Reviewer assessment. After PASS, run the full suite and debug/release builds serially, then use the safe packaging script with a unique candidate ID. Capture executable SHA and labeled before/after GUI evidence from exact builds. Update Phase1J validation/checkpoint documents only after evidence exists.

## Expected / Allowed Write Scope

- `Workflow/review-bundles/T-1J-LM-GRID/`
- `Workflow/review-bundles/T-1J-LM-MOTION/`
- `Workflow/review-bundles/T-1J-LM-WIRING/`
- `Workflow/artifacts/T-1J-LM-VERIFY/`
- `Workflow/results/T-1J-LM-VERIFY.md`
- `Docs/PHASE1J_VALIDATION_RESULTS.md`
- `Docs/PHASE1J_CHECKPOINT.md`
- `Workflow/stage-summaries/2026-09-12-phase1j-layout-motion.md`
- `.build/candidates/phase1j-layout-motion-*/`

## Acceptance Criteria

- Independent Reviewer reports are read-only and based on stable task-specific evidence; each implementation task requires PASS.
- Full tests execute with nonzero count; baseline drift from recorded 1530/0 is explained. Debug and Release builds pass.
- New candidate does not overwrite prior candidates, kill processes, sign, install, or publish; executable SHA and dirty HEAD identity are recorded.
- GUI evidence covers page-to-page row stability, search placement, Folder origin/close/reversal/Escape, drag regression, and Reduce Motion. Smoothness and physical-input claims remain manual.
- Dock observation stays retracted; accepted black-frame repair stays closed; no `LOCAL_RC_VALIDATED` claim while required A-D gates remain pending.

## Required Verification

- Serialize SwiftPM commands and report command, exit code, and executed counts.
- Re-read `scripts/package-app.sh`; require `LEGACY_DESTRUCTIVE=0` and a fresh `CANDIDATE_ID`.
- Record unrun, blocked, and user-reported checks distinctly.

## Prohibitions

No product/test implementation edits, fixture repairs, commit/push/tag, process termination, replacement of installed apps, signing, notarization, upload, or publication.
