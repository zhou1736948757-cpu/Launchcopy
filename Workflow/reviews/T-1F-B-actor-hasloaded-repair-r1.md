# Review r1 — T-1F-B-actor-hasloaded-repair

Reviewer: independent (read-only). Scope: verify Worker's two fixes in `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift`, change-scope discipline, and the 3 build/test gates.

## Verdict: PASS

## Verification points

### 1. Defect 1 — hasLoaded set on EVERY path of ensureLoaded() ✅
- `guard !hasLoaded else { return }` (:160) → `defer { hasLoaded = true }` (:163) registered immediately after the guard, so it fires on every exit of the load path: main classification switch end (:197-220), both `unknownFutureVersion` early returns (:188/:191), both `overLimit` early returns (:194/:195), and the catch branch (:166-172, which keeps its pre-existing explicit `hasLoaded = true` at :170 — redundant but idempotent, per packet "保持").
- Defer placement is correct: registered only when the guard passes (no redundant set on already-loaded calls); setting a Bool twice is harmless. No other logic in ensureLoaded changed (read order, classification, quarantine, setReadOnly untouched).

### 2. Defect 2 — labeled break exits the while loop on .failed ✅
- `drain: while let layout = pendingLayout` (:288); `.failed` case now `if pendingLayout == layout { break drain }` (:301) — exits the while, not just the switch. `isPersisting = false` (:310) therefore runs, flush barrier no longer times out.
- Semantics preserved: on .failed with no newer pending, `pendingLayout` is retained (not nil'd) for later flush/enqueue; if a newer pending arrived, the `if` is false and the loop re-reads it (supersede path unchanged). Other cases (.success/.superseded/.staleRejected/.rejectedOverLimit) unchanged. No debug probes remain in the source (grep clean).

### 3. Change scope — only LayoutStoreActor.swift ✅
Worker window = task packet 08:39:16 → result 08:43:34. `find -newermt` sweep (excluding .build/.git) shows only: LayoutStoreActor.swift (08:42:54), Workflow/results file (08:43:34), and Workflow runtime files (watchdog.json/events.jsonl/heartbeats.json/STATE.json). All other LayoutStore/ files (LayoutStore.swift 01:55, LayoutStoreCodec.swift 08:14, LayoutStoreIO.swift 03:14), LayoutDomain/ (00:47), frozen trees (PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI, 08-28~08-30), Package.swift (08-28), AppLaunchController.swift (08-28) all predate the window.

### 4. No test files modified ✅
Tests/AppGridUITests/LayoutStoreActorTests.swift mtime 08:31:58 predates the window; still 12 tests including testInterruptedWriteTriggersReadOnlyProtectionAndPreservesEvidence (:164) and testWriteFailureDegradesThenRecoversAndKeepsLKG (:242). Their expectations match the fixed semantics (state stays .readOnlyProtection after enqueue; flush returns .failed, not .timedOut).

## Build/test evidence (serial, project root)

| Gate | Result |
|---|---|
| `swift build -c debug` | Build complete!, exit 0 |
| `swift test` | Executed 885 tests, 0 failures (0 unexpected), exit 0; LayoutStoreActorTests 12/12 |
| `swift build -c release` | Build complete!, exit 0 |

Runtime traces confirm both fixes: DBG4 state after enqueue = readOnlyProtection (was healthy pre-fix); DBG7 flush1 = failed after 0.00047s (was 2s timedOut).

## Notes
- Worker result file claims match observed evidence (diff = exactly the two changes; probes removed).
- No git operations performed; review was read-only except this report file.
