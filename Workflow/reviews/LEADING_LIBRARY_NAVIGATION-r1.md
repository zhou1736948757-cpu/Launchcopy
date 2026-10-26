# Leading Library navigation — bounded independent review

Date: 2026-10-19. Reviewer: Ohm (`01a1531a-788e-7121-9b23-1f1e5c7a8ac9`). Read-only source inspection; no test/build/UI/preference operations. Agent closed after re-review.

## Findings and disposition
1. P2: native parent `.cancelled` only cancelled the engine, leaving Library preview/input ownership alive. Main repaired the actual feed path to use value-input `handleParentInput`; cancelled invokes complete parent cancellation and tail draining. Regression verifies preview removed, input unlocked, preview visibility reset, no frame demand, canonical page unchanged.
2. P2: terminal `parentFinished` flag prevented independent phase-less wheels from reopening navigation. Main removed the redundant flag. Terminal parent commits/cancellation drain through the sequence router, whose fresh began/independent wheel paths already restart ownership. Regression separates momentum tail from a new wheel.
3. Main integration finding: window identity is assigned after Library composition in production startup, so an early-only input hook could be absent. Factored `installLeadingLibraryWindowInput(on:)`, called after actual `self.window = window` and on later navigator installation. Added delayed-install fixture. Reviewer confirmed both actual production paths and folder-first ordering.

## Final bounded disposition
SOURCE ACCEPT for the reviewed repair and integration scope; no additional confirmed P1/P2. This is not a physical, native-runtime, full-suite or legal conclusion. Final focused result after wiring: 102/0 (Main-run; reviewer did not execute). Whole-source/current package verification remains Main-owned.

Scope: explicit parent identity/sequence ownership, preview/commit/cancel, shared-pump demand and reentrancy, app-only indexing, button-vs-swipe return, lifecycle/input readiness. Existing unrelated dirty history was not re-audited.
