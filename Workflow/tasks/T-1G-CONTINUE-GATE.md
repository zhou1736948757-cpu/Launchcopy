# T-1G-CONTINUE-GATE - Chief decision packet

## Objective

Reconcile the current Phase 1G checkpoint with the user's 2026-09-08 instruction to inspect the four-finger activation work, fix verified problems, and continue development. Decide whether and how T-1G-B/C/D/E may proceed despite the previously deferred Phase 1F B10/B11 physical gates.

## Role and write scope

- Role: persistent Chief (`gpt-6-astra`, medium)
- Read: project instructions, current PLAN/MAIN_BRIEF/STATE, Phase 1F/1G validation, pending questions, relevant source and tests.
- Write only: `Workflow/decisions/2026-09-08-phase1g-continuation.md` and, only if required to make the accepted plan executable, bounded updates to `Workflow/PLAN.md` and `Workflow/MAIN_BRIEF.md`.
- Do not edit product code, tests, STATE.json, or events.jsonl.

## Required decisions

1. Distinguish the user's new continuation authorization from evidence that remains physically untested.
2. Decide whether B10/B11 remain prerequisites, become explicitly deferred non-blocking gates, or still block T-1G-B/C/D/E.
3. Resolve the window architecture gate and sequence the smallest executable next task(s).
4. Preserve privacy, provenance, no-release, no-commit, frozen-tree, and real-device evidence boundaries.
5. Incorporate the known T-1G-E contracts: `flushPendingShows()` as the only dispatch exit, production input through `process()`, suspend/resume stale-token handling, and hide-versus-terminate semantics.

## Acceptance

- Return exactly one decision: `PROCEED`, `PROCEED_WITH_DEFERRED_GATES`, `ASK_USER`, or `BLOCKED`.
- Give a semantic task sequence and per-task acceptance boundaries without planning runtime concurrency.
- Record any remaining user decision separately; do not infer physical PASS.
- Return a concise stage-summary contribution covering decisions, rationale, unresolved gates, and the next executable action for Main to persist in `Workflow/stage-summaries/2026-09-08-phase1g-continuation.md`.
