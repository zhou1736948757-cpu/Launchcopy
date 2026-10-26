# Main Grid Capacity — Independent Foundation Source Review

Date: 2026-10-17
Review attempt: R1, including Main's subsequent row-envelope guard and mismatch test.
Verdict: **FAIL — one P2 foundation correctness finding (F1).** This is a bounded source verdict only. It is not a whole-feature, full-parity, runtime, native, physical, performance, or release verdict.

## Authority, scope and evidence boundary

The human waived Chief and approved at most three agents including Main. This reviewer created no agents and owns only this report. No production or test edits, tests, builds, UI, process management, reference-code access, or formal-data operations were performed. The first two read-only bootstrap commands (reading RTK.md and identifying the working directory) mistakenly lacked the required RTK prefix; every subsequent shell command used `rtk proxy`. This deviation did not change repository data.

Read the repository AGENTS.md, approved specification and implementation stage summary. Reviewed the new capacity/anchor domain, store and tests, coordinator and tests, readability helper and tests, and only the bounded capacity changes in AppGridGeometry, AppGridPageView and AppCatalogAssembly, plus the two new page/renderer metric test files. Inspected the existing AppLibraryStore I/O primitive only through its protocol/read/atomic-replacement/directory-traversal implementation (lines 26–148), and existing GridItemAppearance/content geometry to resolve the actual caption/icon formulas. Those dependencies are not represented as new implementation.

The original input inventory has 467 entries. Independently SHA-256 verified all three reconstructed `*.before.txt` files against their corresponding original-source entries. Used those reconstructed originals to identify the new hunks; did not treat the full Git diff as new work. Initial geometry/readability-test hashes were superseded by Main's explicit update; the manifest below includes the latest guard/test hashes. The original reconstructed geometry remains unchanged and still matches the frozen original hash.

Main reports focused R1 executed **42 tests / 0 failures in 0.740 s**, comprising 4 existing geometry tests and 38 new tests. That report predates the latest guard/test and is attributed execution evidence only; this reviewer did not execute tests, inspect that log, or infer a green verdict. Main plans serialized focused/full/build reruns. No later execution is certified here.

## Finding F1 — P2: readability admits a search layout whose actual glyphs are below the minimum

**Location:** `Sources/AppGridUI/MainGridReadability.swift:13–15` (function/API at lines 8–9). Related actual rendering: `Sources/AppGridUI/AppGridPageView.swift:381–388`; spacing/width formulas: `Sources/AppGridUI/AppGridGeometry.swift:21–26,35–36`.

**Evidence and concrete trigger:** `isReadable` always constructs `.ordinary` geometry using a full `capacity.itemsPerPage`, whereas the page renderer uses its actual `layoutMode` and `cells.count`. Fewer occupied search rows can increase vertical spacing; that same spacing is subtracted from horizontal column width. The full ordinary grid is therefore not a conservative lower bound on search glyph width.

For bounds `(0,0,350,800)`, capacity 8×8, default appearance and visible labels, the existing source formulas give:

| Quantity | Helper's full ordinary grid | Actual search page with 9 items |
| --- | ---: | ---: |
| Usable width / height | 302 / 680 pt | 302 / 680 pt |
| Row count | 8 | 2 |
| Cell height | 85 pt | 88 pt |
| Spacing | 0 pt | 16 pt |
| Cell/icon width | 37.75 / 37.75 pt | 23.75 / 23.75 pt |
| Name-frame width | 33.75 pt | 19.75 pt |

At the default 11 pt label size, the full ordinary probe has the complete 14 pt name and 12 pt count lines and a 37.75 pt icon, so the helper returns true. The actual search page's glyph is 23.75 pt, below the helper's required 24 pt minimum, and its caption width is also below the helper's 24 pt threshold. These values are a manual source derivation, not an executed geometry/native test. Existing `MainGridReadabilityTests.swift:49–66` checks search row count only; it never calls the admission helper against actual search content.

**Impact / affected scope:** An owner using this foundation API for the approved readability protection can expose an unreadable search grid even when it faithfully supplies the committed capacity and appearance. The API currently provides no layout-mode or item-count input with which the owner could correct the decision. This finding concerns the helper's current calculation, not the absence of owner/settings integration.

**Likely root cause:** Treating a full ordinary envelope as uniformly more restrictive than occupied search geometry without accounting for shared horizontal/vertical spacing.

**Recommended solution:** Evaluate the actual committed mode and page item count using the same bounds/geometry as the renderer, preserving full-shape probing for ordinary empty/partial pages and deterministic empty-search behavior. Alternatively, prove and evaluate a conservative envelope across every supported occupied search row count. Do not silently force search to ordinary geometry or alter logical capacity. Reuse the actual content-geometry metric source. Main owns the API/integration decision.

**Regression risks / follow-up verification:** Add the above ordinary-readable/search-unreadable counterexample; vary search counts around column/row boundaries, all 36 shapes, labels on/off, default/max appearance and nonzero origins. Preserve ordinary partial-page geometry and verify the owner recomputes after committed search changes without icon work or catalog-revision forgery. Reviewer runs none of these checks.

**Confidence:** High from the direct formulas and different arguments at the two call sites. Severity P2; fix before accepting this helper as a complete main-grid readability gate.

## Additional source observations (not additional FAIL findings)

- **Domain and anchor:** No concrete correctness defect found in the bounded source. Both dimensions validate before multiplication; hostile page indices clamp before arithmetic; empty and replaced sequences have deterministic handling. Visible old-page selection gets anchor priority, valid off-page selection relocates separately, and nil selection stays nil. Query, deferred-focus visibility and canonical sequence ownership remain caller responsibilities.
- **Store:** No concrete new corruption/future-envelope overwrite defect found. Bounded raw-header inspection precedes typed decoding, escaped/duplicate/unknown keys are protected, supported malformed pairs require explicit recovery, saves freshly re-read, and `.saved` requires the real replacement call. The reused primitive checks exact baseline bytes under the cooperative lock, pins/no-follows directory traversal, checks namespace identity before rename and flushes file/target directory. No universal CAS guarantee exists against arbitrary writers ignoring that lock. A post-rename error remains an indeterminate failure; equal-value retries still write. Real factory/profile choice and a dedicated capacity directory remain required integration gates. No filesystem behavior was executed by this reviewer.
- **Coordinator:** No concrete receipt-order, accepted-write cancellation or stale-presentation-callback defect found in the current bounded source. Each save awaits its predecessor; immutable drafts are retained independently of the settings draft and weak owner; stale results update only that old owner's accounting/real persisted baseline, with current-publication guarded by active state and generation. A newest failure publishes the prior actual receipt and keeps Quit protection; timeout does not cancel the writer. `invalidate()` revokes presentation callbacks without canceling accepted I/O. This is not proof that an eventual replacement owner or termination pipeline uses it correctly. Tests lack a suspended-load teardown case and owner-release/multiple-queued-write handoff; these are suggested integration/ownership checks, not established bugs.
- **Metric fan-out:** New values reach live pages, pooled pages and newly rendered pages. Same-product shape changes compare the full value. The metric setters deliberately do not revoke bindings or request icons; the single owner transaction must perform its separate invalidation/reload/focus boundary. Existing icon-generation checks cannot certify that future transaction by themselves.
- **Latest row-envelope repair:** `AppGridGeometry.swift:30–31` now refuses indices beyond the configured row count; the new `MainGridReadabilityTests.swift:69–74` checks a 10-item/3×3 mismatch. This addresses the pure geometry overflow. It does not hide/reset cells already retained by AppGridPageView: its layout loop assigns frames only for non-nil results. If a 64-cell page is merely changed from 8×8 to 3×3, excess cells retain their previous frames/bindings. Treat this as an explicit owner-transaction precondition: content must be reduced/rebound under suppression before exposure, or invalid cells must be defensively suppressed. The current metrics-only API assigns rebind/admission responsibility to the owner, so this is a concrete integration hazard rather than a second foundation failure. The pure nil-frame test must not be represented as proof that stale rendered cells or actions disappear.

## Remaining gates — intentionally not foundation failures

1. Owner-controlled idle transaction across provider/search/refresh/Surface/renderer/keyboard/dots/drag, same-product shape changes, stable identity/query/deferred focus, page motion and live folder source frames.
2. Ownership/readiness wakeups for held input, gesture/settle, Folder including retained exit, Library return, IME/edit/menu/modal/restore/Quit; generation/epoch invalidation of stale scheduled callbacks and old owner completions.
3. Independent localized settings draft/Apply/Defaults/error/queued/applied behavior, real capacity-store factory/dedicated profile selection, corrupt recovery, future/denied storage and retry/cancel semantics.
4. Explicit capacity participation in Quit admission/drain/current-owner epochs, accepted-write retention on timeout/failure/cancel, owner replacement and native restart. Coordinator source alone is not Quit integration.
5. Readability masking/input/AX suppression, actual unobscured bounds/search chrome/safe areas, settings reachability, all committed modes and appearance/language/resize transitions. F1 must be corrected first; the helper alone is not a complete viewport policy.
6. Nonzero latest-source focused/full execution, Debug/Release/package/localization checks, candidate/source hashes, isolated native endpoints/default/compact viewport/restart verification and separately bounded physical/IME/AX/performance evidence. No whole-feature, full-parity, memory, 120 Hz, or physical PASS is issued.

## Frozen reviewed inputs (SHA-256)

This source verdict applies only to the exact reviewed bytes below. Before relying on it, compare relevant code/test/spec inputs. Any source/test change requires an explicit superseding review; do not silently reuse this verdict. A stage-summary update records progress but cannot change what this review certified.

| Input | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/MainGridCapacity.swift` | `96d6912ad8693398331ec3dddd247fa2bbdbaf580afb7df79674a9a209016d09` |
| `Sources/PagingPrototypeApp/MainGridCapacityStore.swift` | `ac60c473c917ac7d75a90f3aee22453aa61a50b62d7acfa27f9fc4c1037a3d69` |
| `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift` | `34b90c4e0d077489e46a7fd670bb66ae99ce54247c677e9c0711241dd53e502b` |
| `Sources/AppGridUI/MainGridReadability.swift` | `c7d5bf94f3167ece27a56b9d15ed56bbcf5bdf25860c25205b8c939c2d23ad1b` |
| `Sources/AppGridUI/AppGridGeometry.swift` | `463ab9ef172a7fdcb6058954ba055d6f820a0ed6b0b216df068b1454839bf01d` |
| `Sources/AppGridUI/AppGridPageView.swift` | `d33b150ac68a19c9ddac42ea7214a746ccd329adeb9c1f092b698bcf51a61037` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `3647b449bc573f607ab369f3864c0f00a0f9ebf4afaee7c0d3c7f081ca7ea862` |
| `Tests/AppGridUITests/MainGridCapacityTests.swift` | `663382a3304acc4064bc627c6dd38fc04a086cf81de1f34cbca8b2040182924d` |
| `Tests/PagingUITests/MainGridCapacityStoreTests.swift` | `63e0f3c055c591a0fa4418449270bfa9a1692057e1c1d3362942fbf5010602fb` |
| `Tests/PagingUITests/MainGridCapacityCoordinatorTests.swift` | `29701c026edc41bd4ff080b8ce22d9d82ad9607fb7ad808fe9ed657ad4037219` |
| `Tests/AppGridUITests/MainGridReadabilityTests.swift` | `3f570036dadcfd096d9c65ee3d46622ee21c93b1b28fab3fc48b5f9b2a6c307b` |
| `Tests/AppGridUITests/MainGridPageMetricsTests.swift` | `ddef5704452ee0eb234a2f212330cf2cfbf1c542486260c167d598bab23bd78b` |
| `Tests/PagingUITests/MainGridRendererMetricsTests.swift` | `ef3d0751cd69215e9693190cfcfc5facec0dd629e172088bbf9423387e8b8159` |
| `Sources/PagingPrototypeApp/AppLibraryStore.swift` | `f8b2560042a5ef3df7dbcf186198114de2f7ea51e1c64611fbc2182ed22f4464` |
| `Sources/AppGridUI/GridItemAppearance.swift` | `75f831d583be163d98f3dc306bdd34d1bf04a7da17b4b51ec3ac368674aeb8d4` |
| `AGENTS.md` | `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc` |
| `Docs/MAIN_GRID_CAPACITY_SPEC.md` | `e2b93a44dc5ef0be2296e05d03512f17ef7121d63705810058a0c7fb07e05ebe` |
| `Workflow/stage-summaries/2026-10-17-main-grid-capacity.md` | `1fa1ceec9c7e4be68524f70cf12b0b8ae748ef4aaba1340f655fe8d5b40c6888` |
| `.build/verification/20261017/main-grid-capacity/source-before.json` | `af130f9a2ec5243f5cd90a8d04cfddb4a401507185b291eafdf1f984dc842b68` |
| `.build/verification/20261017/main-grid-capacity/AppGridGeometry.before.txt` | `9ba66c1c0a03327df75920e5611a126489a56615e71d2dd7bb2a9d249c4e7e44` |
| `.build/verification/20261017/main-grid-capacity/AppGridPageView.before.txt` | `331514e9da1b1a3af7b1c4ec5d44fcdec97ce030201c386c72d93e63e5a60c00` |
| `.build/verification/20261017/main-grid-capacity/AppCatalogAssembly.before.txt` | `2eda6626fdca84701fe303fbb13a8174aff0067084ae4c9c2d619116c83da6cc` |

## Next action and change disclosure

Main should resolve F1 within the approved readability contract, retain this failed attempt and its hashes, run its serialized checks, and obtain an updated bounded source review of the changed inputs. Main may continue independent foundation verification, but those results do not erase F1 or close the remaining integration gates.

Changed by this reviewer: `Workflow/results/MAIN_GRID_CAPACITY_FOUNDATION_SOURCE_REVIEW.md` only. No other files written.


---

## R2 — F1 repair review, 2026-10-17

**Verdict: SOURCE PASS for the bounded foundation scope, with F1 closed at the hashes below.** No remaining actionable finding for F1. This supersedes R1's current source verdict only; the complete R1 FAIL, evidence, input hashes and original limitations remain above unchanged. It does not approve the concurrently developing owner/settings/Quit integration or issue any whole-feature/full-parity/physical PASS.

### Reviewed repair and source reasoning

Re-read `MainGridReadability.swift` and its amended tests, checked unchanged geometry/content-geometry formulas and renderer arguments, and compared every R1 manifest input with current SHA-256. Only the two readability files changed among those inputs. All other 20 manifest entries, including the original baseline/reconstructed files, remain byte-identical to R1 at this review boundary. Other owner work outside those inputs is not reviewed or certified here.

`Sources/AppGridUI/MainGridReadability.swift:17–27` first checks the full ordinary shape, then independently checks each occupied search row count from 1 through `capacity.rows`. The representative count `(rows - 1) * capacity.columns + 1` always yields that search row count for the validated 3…8 dimensions, stays within the logical page capacity and cannot overflow. In the unchanged `AppGridGeometry`, row count determines cell height and shared spacing; columns/bounds/spacing determine tile width. Counts with the same occupied row count have identical cell dimensions. Partial final rows change horizontal centering only. Testing the first cell therefore suffices for the cell-local glyph/caption dimensions being admitted. A zero-result search has no rendered cells; its existing minimum one-row geometry is conservatively represented by the one-item probe.

The original 350×800 / 8×8 / 9-item search now participates as the second-row-count probe, so its 23.75 pt icon width makes admission false. The production `fits` helper (`:31–48`) preserves the existing folder-count budget, 24 pt icon threshold, complete name/count line heights and minimum name width. No logical rows/columns, query, search placement or renderer layout-mode behavior is changed. At most one ordinary plus eight search geometry probes occur per invocation. This bounded helper does not introduce a timer, frame callback, icon request, rebinding, storage operation or asynchronous ownership change; actual invocation frequency remains the future owner's responsibility.

The chosen alternative is intentionally conservative: a viewport may be protected even while its current ordinary page would fit, if another permitted search occupancy would not. This implements the conservative-envelope remedy explicitly offered in R1 without silently reducing logical capacity or changing search geometry.

### Amended verification inputs and limits

- `Tests/AppGridUITests/MainGridReadabilityTests.swift:76–87` preserves the exact F1 bounds/shape/search-count counterexample and asserts the gate rejects it.
- `:89–115` iterates all 36 supported shapes, every nonempty search page count for admitted configurations, widths 350/700/1200, a nonzero origin, default/maximum appearance and both label states. It checks actual content-geometry glyph dimensions and the folder count-line height. Rejected configurations are skipped by that implication check; the existing large-viewport positive assertion prevents a globally always-false gate from satisfying the suite. This is reviewed test source, not executed evidence, and is not an exhaustive viewport/font/native-visibility claim.
- Reviewer executions for R2: **0 tests, 0 builds, 0 UI/process operations**. All shell calls used RTK. No result from R1, or from Main's earlier focused run, is relabeled as execution of these repaired inputs. Main still owns serialized current-source verification after settings inputs stabilize.
- R1's remaining integration gates and the stale retained-cell warning remain open. Actual unobscured geometry, input/AX masking, idle/epoch ownership, store factory, settings, Quit/restart and native acceptance require their separate review/execution. No new issue was inferred merely because those integrations are unfinished.

### R2 frozen hashes

| Input | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/MainGridReadability.swift` | `c695948502be5e1acf811ab0f2bd2668e2a2fbb66ae48843e807241138e73726` |
| `Tests/AppGridUITests/MainGridReadabilityTests.swift` | `90fab0636a4ddd584d52dd619103dec5868ac62b75503a21d70a5ee0090312f0` |

For the other 20 unchanged reviewed inputs, the R1 manifest remains the explicit frozen hash list, rechecked for R2. The preserved report before this append had SHA-256 `38e02eeb1a9f0ee0c428b18e34addc145c4e43b0ac9be707285c211bb7634739`. Later source changes require an explicit review update; this SOURCE PASS must not silently cover them.

R2 changed by reviewer: appended this section to `Workflow/results/MAIN_GRID_CAPACITY_FOUNDATION_SOURCE_REVIEW.md` only. R1 bytes preserved exactly; no production/test files modified.
