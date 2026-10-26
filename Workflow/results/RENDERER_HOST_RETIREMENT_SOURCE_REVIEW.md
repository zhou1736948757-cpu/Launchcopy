# Renderer Host Retirement — Independent Source Review

Date: 2026-10-17
Verdict: **PASS — bounded source review; no actionable findings.**

## Scope and input integrity

Reviewed the Swift/AppKit renderer lifecycle change in `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` against `.build/verification/20261017/renderer-host-retirement/AppCatalogAssembly.before.txt`, plus `Tests/PagingUITests/AppGridRendererRetirementTests.swift`. Inspected existing page/cell cleanup and host ownership/call ordering as supporting context. Chief workflow was waived by the task instruction. This review makes no architecture or capacity-feature decision.

Compared `source-before.json` (464 inputs) with `source-inputs-r1.json` (465 inputs): exactly one modified input, `AppCatalogAssembly.swift`, and one added test file; no removals. All 465 current input hashes matched the latter manifest at review. The saved before-file hash matches the former manifest. The production diff changes only `sweepRetiredHosts()`; no Core/UI physics, protocol, parameter, storage, or other production changes appear in that manifest delta. The supplied designation of the earlier baseline as source-origin r3 is context, not independently reconstructed provenance.

## Findings and reasoning

- **Retirement is correct at the existing sweep boundary.** A missing/deallocated weak host now yields its page index, just as a retained but detached host already did. An attached host still yields no retirement. Collecting indices before mutating the dictionaries avoids mutation during enumeration. `retire` removes both ownership entries, clears the page, and appends it once to the existing pool; subsequent sweeps cannot append that entry again.
- **Cleanup preserves intended reuse.** `AppGridPageView.clearForReuse()` invalidates queued text, advances `surfaceGeneration`, resets page/presentation/reuse identity, and calls `clearCells()`. Each cell clears its binding, text, icon, folder state, and focus. The cell array intentionally remains allocated. The existing async delivery guard rejects the old surface generation. Requiring zero allocated cells would contradict this existing reuse design; the corrected test checks cleared ownership and retained cell identity without another production change.
- **Tests distinguish release from detachment.** The explicit-sweep and 16-distinct-index cases mount a real `NSView` host, remove it, leave an autorelease scope, and assert its weak reference is nil. Keeping the page itself alive does not substitute for host deallocation. The explicit case checks live-map removal, pool membership, invalidated page identity/binding, retained cell allocation, and repeat-sweep idempotence. The next-render case checks page object identity, one live instance, one total creation, and attachment to each replacement host. The mounted negative control checks unchanged page/cell/token and an empty pool.
- **Old host ownership remains bounded by existing behavior.** For a retained detached host, clearing a page does not itself remove its view from that host; reuse moves it through `addSubview`. That behavior is unchanged. Real `PageHostView` owns its custom renderer; the renderer's recorded hosts/render target remain weak. `PagingSurface` currently calls host cleanup before removal on ordinary retirement, so that particular call can still preserve the then-attached host until a later sweep. The empty-range branch removes hosts without invoking renderer cleanup. This patch does not alter either ordering.

## Existing evidence inspected

Read Main's existing logs only; executed no tests, builds, packages, UI actions, or process operations:

- `red.log`: 3 tests, 53 assertion failures; host-deallocation assertions did not fail, and the mounted control passed. These are assertion failures, not 53 failing test methods. The original zero-cell assertion was also erroneous, so the raw RED total is not a count of distinct production defects.
- `focused-r1.log`: 33 tests, 1 failure, the explicit test's retained-cell count expectation (actual 1 versus expected 0).
- `focused-r2.log`: 33 tests, 0 failures, including all 3 retirement tests. This is Main-produced log evidence, not an independently executed run.

The stage summary still says `REPRODUCTION_PENDING` at the hashed snapshot; Main should append the verified results and review verdict during closeout. This is a documentation follow-up, not a source defect.

## Limits and remaining gates

The new tests directly exercise generic AppKit hosts and folder cells, not a complete native surface session or real app-icon delivery. They do not newly test a retained detached host or a mixed stale/attached host set; the detached predicate is unchanged and the mounted negative control covers the preservation branch. Async invalidation is supported by inspected existing guards, not a new delayed-icon experiment.

No immediate zero-count/empty-search cleanup, pool eviction, whole-process memory cap/leak elimination, frame-time improvement, or capacity-feature acceptance follows from this repair. Capacity remains PROPOSED/pending answer. Full tests, builds, package/localization results and final candidate provenance remain Main's gates and are not certified here. Prior human acceptance concerns the old bdb9 candidate only; no new native/manual/performance PASS is granted.

Only this report was written. No implementation, test, stage summary, evidence, or asset was modified.

## SHA-256 review anchors

Paths below are repository-relative; evidence filenames are under `.build/verification/20261017/renderer-host-retirement/`.

| Input | SHA-256 |
| --- | --- |
| `AppCatalogAssembly.before.txt` | `8174fe17c95454b75df5fd09f2d6b7ac2eef8c0f54b65d20cf4c7da3c6c8111b` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `2eda6626fdca84701fe303fbb13a8174aff0067084ae4c9c2d619116c83da6cc` |
| `Tests/PagingUITests/AppGridRendererRetirementTests.swift` | `cee5d0356cb5534141c939a787e880b80532141c545cfeed754cdc921bb7fc9f` |
| `Sources/AppGridUI/AppGridPageView.swift` | `331514e9da1b1a3af7b1c4ec5d44fcdec97ce030201c386c72d93e63e5a60c00` |
| `Sources/AppGridUI/AppGridCellView.swift` | `eb38dce836c0214fd6a29ccf4f8fa4c1946e1cd5cc8ac61104c24b9d5339195a` |
| `Sources/PagingUI/PageHostView.swift` | `65cd891554d66b9c3bd5cac7f1adcfe9e86682053d5298254129b626ba22eb83` |
| `Sources/PagingUI/PagingSurface.swift` | `966615670bde489514a734779befae082a3e79b692eab28de83e770c04b3e439` |
| `source-before.json` | `3a63895941faa4521425d3bbf69c5ba1a141f9e3304815fa6f02b2a366beac60` |
| `source-inputs-r1.json` | `aff4f7d3cd7de192adf0fc07c25edf9403693b04f2206bebca239f258778004e` |
| `red.log` | `3a581b1fa40c1e2cfd40c1fcf05318819f8cd84033ab9ea2491dc9468608d58b` |
| `focused-r1.log` | `dd3bffe0f641e03db01ec77fa9b907c61938b01145ce72ad1ba990a357560ab0` |
| `focused-r2.log` | `e400d2e294402be9f7e43b0b449c05b069294290e02b306e40c12ab7b812d0b6` |
| `Workflow/stage-summaries/2026-10-17-renderer-host-retirement.md` | `494ad140f2c92754821e2298b5976b7ab70de5ddc491695dc544041c8ed33d8e` |
