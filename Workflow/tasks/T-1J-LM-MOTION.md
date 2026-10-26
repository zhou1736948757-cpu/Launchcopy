# T-1J-LM-MOTION — Folder Motion Primitive

Status: READY
Owner: Worker

## Objective

Implement deterministic, interruptible Folder presentation primitives inside AppGridUI without changing application wiring.

## Dependencies

- `D-1J-LAYOUT-MOTION`

## Scope

Add explicit transition trigger/source inputs, 180ms pointer transform/opacity motion, opacity-only Reduce Motion, presentation-state retargeting, generation-gated completion, and a noninteractive transient exit visual. Preserve immediate/drag move-out paths and prevent refresh or inner-page changes from replaying entry.

## Expected / Allowed Write Scope

- `Sources/AppGridUI/FolderOverlayView.swift`
- `Sources/AppGridUI/FolderMotion.swift`
- `Tests/AppGridUITests/FolderOverlayTests.swift`
- `Tests/AppGridUITests/FolderMotionTests.swift`
- `Workflow/results/T-1J-LM-MOTION.md`

## Acceptance Criteria

- Pointer, keyboard, lifecycle, Reduce Motion, missing source, reversal, stale completion, A-to-B, hide/cancel, resize, and teardown behavior is deterministic.
- Exit visuals are noninteractive, inaccessible, memory-only, bounded, and generation-gated.
- No callback after teardown mutates UI; no motion blocks input or drag capture.

## Required Verification

- Run focused `AppGridUITests` filters with nonzero executed count.
- Record exact parameters, changed files, test counts, deviations, risks, and Reviewer focus.

## Prohibitions

Do not edit AppDelegate/renderer/grid geometry, existing drag policy, `Package.swift`, workflow decisions/stage summaries, or forbidden source trees. No commit/push.

