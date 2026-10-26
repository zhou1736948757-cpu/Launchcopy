# Empty Presentation Retirement — Independent Source Review

Date: 2026-10-17
Verdict: **PASS for the bounded source review; no actionable findings.**

## Scope and baseline

Reviewed only the zero-range `relayoutPages()` change against `.build/verification/20261017/empty-presentation-retirement/PagingSurface.before.txt`, the new `EmptyPresentationRetirementTests.swift`, and the existing host/renderer cleanup and asynchronous delivery chain needed to assess them. Read RTK, applicable AGENTS instructions, and `Workflow/stage-summaries/2026-10-17-empty-presentation-retirement.md`. This is routine cleanup within the assigned maintenance scope; it grants no additional freeze authority, capacity work, API change, or physics change.

## Review findings

- **Ordering is necessary and correct** (`PagingSurface.swift:843–856`). The sole production hunk replaces the direct language invalidation with `host.clearForReuse()` after `removeFromSuperview()`. `AppGridRenderer.sweepRetiredHosts()` identifies retirement using the recorded host's missing parent (or released weak reference). Clearing before detaching would miss a still-retained host. Each detached page now clears immediately, without requiring a later render; retirement removes its live map entry and pools the cleared grid page.
- **Existing ownership and protocol remain intact** (`PageHostView.swift:142–152`). The existing entry point owns language invalidation, host generation advancement, binding reset, accessibility clearing, neutral cleanup, and delegated renderer cleanup. Removing the separate language invalidation avoids redundant work. No signature or protocol edit is needed. The normal nonempty branch is unchanged by the supplied baseline diff.
- **No new application-level reentrancy hazard found in the inspected production cleanup chain.** Cleanup is synchronous under the existing main-thread view convention; it contains no suspension or explicit external application callback. Surface bookkeeping is cleared before `onLayoutPerformed?(0)`. Icon delivery runs on MainActor, and grid-page clearing advances its generation and clears cell tokens before return. This assessment is not a proof against arbitrary injected renderers or AppKit observers that recursively mutate the surface.
- **Neutral compatibility is preserved** (`NeutralPageRenderer.swift:80–93`). Cleanup removes tiles and empties/hides the retained page label. The corrected test allows that existing label rather than requiring zero subviews; no production change was made for the incorrect expectation.

## Tests and evidence limits

The new tests use real in-process Surface/host/grid-renderer instances. Four zero/restore cycles retain hosts and check immediate host/page/cell reset, renderer live/pool counts, and reuse of the same grid-page identities. The fixture is **four pages with one generated item each**, not a 245-item dense-budget test. The separate asynchronous test blocks one generated icon load, installs an observer before release, waits for all recorded consumers, and checks no application or retired-cell image. Same-key requests merge in the existing pipeline; the loader fixture is scoped to that single-key scenario. The neutral test covers cleanup, not a new neutral restore or native-window acceptance gate.

Read existing logs, without rerunning them: RED records 3 methods/74 assertion failures, including one invalid neutral expectation and an actual old-image application; focused r1 records 23/1; corrected focused r2 records 29/0 in 0.216 seconds. The Swift Testing footer reporting zero tests is not the XCTest result. Main subsequently reports full 2821/0 in 63.720 seconds and Debug 0.30 seconds; those are Main-reported results, not independently executed verification here. Release/package were still finishing at that update.

## Input identity

SHA-256, independently calculated; both reviewed files match the supplied 467-entry manifest:

| Input | SHA-256 |
| --- | --- |
| `PagingSurface.swift` | `0197dce825a7c381373b0dc25e1df818f904e5398458aa5789749f322d416409` |
| `EmptyPresentationRetirementTests.swift` | `d06044e04e2b3fe91237a472223154fd5090adcb43b8d470156d3809ced8ee89` |
| `PagingSurface.before.txt` | `966615670bde489514a734779befae082a3e79b692eab28de83e770c04b3e439` |
| `source-inputs-r1.json` | `886936f61630b5adf76ea1a9e8af9cad6613413910fef9917366f494c7552022` |

The nine consulted supporting source/helper files also matched their manifest entries. This is scoped input identification, **not canonical full Git diff certification**, verification of every manifest entry, or independent certification of the 465-unchanged baseline claim.

Only this report was written. No implementation edits, tests, builds, UI/process operations, or additional agents were performed. Main retains integration/release/package/native verification ownership. No total-RSS, empty-pending-queue, physical-performance, or capacity PASS is claimed; the capacity decision remains pending.
