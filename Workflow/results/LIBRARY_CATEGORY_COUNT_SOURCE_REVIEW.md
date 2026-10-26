# Library category count visibility — independent source review

Date: 2026-10-15

## Verdict

**Bounded SOURCE PASS. No actionable blocking or major source defect found in the reviewed freeze.** The independent trailing count is a proportionate presentation repair for the reported long Japanese title/count truncation. This verdict does not close native, package, physical performance, VoiceOver, IME, or broader parity gates.

Reviewer executed **0 tests, 0 builds, 0 Swift invocations, and 0 UI/process-control operations**. Main owns serial execution and subsequent native/package acceptance. The only file written by this reviewer is this report; existing dirty work was preserved. No agent was dispatched or messaged. User-authorized Chief waiver and Main + one reviewer / maximum-three-including-Main boundary were retained.

AccessDeclaration: **NO_PRIOR_EXPOSURE** to restricted reference material in this review. No LaunchBetter/Buho reference source, reverse-engineering material, raw assets, or reference screenshots were read. Hashing declared current-project inputs did not inspect asset contents for design information.

## Scope and evidence integrity

Read project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, current stage summary `Workflow/stage-summaries/2026-10-15-library-category-count.md`, relevant current plan/handoff/state/config context, the three assigned source/test files, unchanged Library localization/focus seams, and Main's recorded RED/focused logs. All shell commands were RTK-prefixed. Old global state/handoff contains historical stages; the current stage summary and explicit bounded assignment govern this review.

The project is a SwiftPM tools-5.9, macOS-14 AppKit launcher with native view-based tables, a separate Library domain/projection, localization resources, and XCTest coverage. The new internal cell follows the existing native cell and MainActor conventions; it adds no package target or public interface.

Independently compared the two supplied JSON hash manifests and recomputed every final declared input hash:

| Evidence | Result |
| --- | --- |
| Baseline `.build/verification/20261015/native-text-editing/source-inputs-final.json` | 448 inputs; SHA-256 `62b28124114ceb29226f801ac9bbd401746cfe06704ce96a1237285f16c683e0` |
| Final `.build/verification/20261015/library-category-count/source-inputs-final.json` | 450 inputs; SHA-256 `e2c3da147659ce0eb232ff2744ef435dcf9a34e8f1887a01d18451d03d86ea20` |
| File delta | 1 modified + 2 new, 447 existing inputs unchanged, 0 removed |
| Current final hash mismatches | 0 / 450 |
| Frozen PagingCore/PagingUI inputs | All 18 unchanged |

Exact changed/new paths and final hashes:

- `Sources/PagingPrototypeApp/AppLibraryView.swift` — `a25e332229376ca03ba8c4a3b50f253005a2a41054e20c0bc9b942f3f3421f39`.
- `Sources/PagingPrototypeApp/AppLibraryCategoryCell.swift` — `a0e4cefff659d8fbf9ac87b2c101c91d0e98d5ef1c10f0e707d4205f3fe387fe`.
- `Tests/PagingUITests/AppLibraryCategoryCellTests.swift` — `5162bfb0e0a24eea2bc82f1c83699e109e2077ab15dff05d63e3524f32b7bcb3`.

Baseline limitation: these manifests contain hashes, not historical file bodies. Exact changed-file membership/current bytes were independently verified; a byte-for-byte historical hunk diff or every deleted factory line cannot be reconstructed from these manifests alone. The old combined tail-truncated field is documented by the current stage and corroborated by Main's actual-delegate RED. The prior Japanese screenshot observation is supplied evidence, not an image independently inspected by this reviewer.

## Source assessment

### Ownership, binding, and preserved behavior

`AppLibraryView.swift:352–362` retains the category table's reuse identifier, category row mapping, snapshot category counts, All aggregation, and localized title provider. It obtains the dedicated cell and performs a complete bind. The former combined-field factory is absent from the current file. The presentation cell contains no selection/query/domain logic, callbacks, observer, or asynchronous state.

`AppLibraryCategoryCell.swift:9–37` constructs its two labels once, retains them as native subviews, and rewrites title, decimal count, full accessibility label, and tooltip on every bind. `needsLayout` invalidates geometry when reused with a new number or language. There is no stale separately cached count or localized title. Both labels remain passive label controls; no new responder target/action or key handler competes with the table.

Current focus transfer, category selection, query invalidation, and compact picker paths remain in their existing owners (`AppLibraryView.swift:297–328`, `373–410`, `445–464`, `681–713`). Compact picker titles remain title-only under the existing contract. Domain, taxonomy, count producers, resources, and package inputs match baseline hashes. Existing All aggregation is not newly overflow-hardened; arbitrary synthetic Int.max totals are outside this bounded visual contract.

### Geometry and width boundary

`AppLibraryCategoryCell.swift:40–52` reserves the count's rounded native intrinsic width first, capped by the available width after two 8-point insets. Its trailing edge stays within that available region. Only the title uses tail truncation; its width is the remaining nonnegative space before the 8-point gap. Count alignment is trailing/right and single-line; clipping is the explicit fallback when its text itself exceeds available space.

For nonnegative widths below 16 points, available width becomes zero and the leading origin is capped at the bounds width. At other widths both frame widths remain nonnegative and contained. Height is bounded to the available nonnegative height, capped at 20 points. Title/count cannot overlap with positive widths; zero-width frames may coincide without rendering content. No division by a tiny dimension or unbounded layout loop is introduced.

The supported-width stress assertions cover **112, 184, and 200-point cell widths**, three shipped languages, two long categories, and representative counts **0, 7, 12,345, 999,999**. This is representative sampling within 0…999,999, not exhaustive enumeration. It supports the stated finite sidebar use case. There is no full-readability guarantee for arbitrary Int.max strings or transient tiny bounds; full source accessibility text/tooltip survives clipping.

### Accessibility, native role, and selected styling

`AppLibraryCategoryCell.swift:21–36` exposes the native cell and suppresses the two visual labels as separate accessibility elements, while setting the complete localized title plus count and tooltip together. Rebinding overwrites both complete values; geometry never shortens those strings. This is an appropriate source design for a single cell announcement rather than a duplicate count control.

The class remains an `NSTableCellView`, with no custom accessibility role, selection implementation, or mouse handling. Actual resolved cell role, row/cell hierarchy, duplicate announcements, and VoiceOver speech are native acceptance questions; these tests only inspect source-level accessibility properties.

No explicit text colors or background-style overrides are introduced. The local AppKit SDK `NSTableCellView.h` documents that its default backgroundStyle setter forwards to direct NSControl subviews and system label colors adapt to emphasized backgrounds. Both labels are direct native NSTextField subviews and retain that inherited path. Consequently there is no identified source reason for the count to miss normal selected-row styling. Mounted selected/unselected and active/inactive contrast still requires Main's native observation.

## Test quality and execution attribution

The new four tests are meaningful for this repair:

- `AppLibraryCategoryCellTests.swift:17–57` obtains a cell through the actual Library delegate, supplies localized long titles/counts, and asserts full count text, sufficient measured count width, nonoverlap, containment, and complete AX/tooltip text. Main's `red.log` records the original delegate failing at the missing independent count field: **1 XCTest / 1 failure**. This establishes a relevant regression trigger, although that first failure alone is structural rather than a screenshot measurement.
- Lines 60–77 rebind the same cell/labels across long Japanese, English, and Chinese values, checking updated full text and no separately exposed visual labels. This verifies bind reuse; it does not exercise native table reuse-pool lifecycle or actual screen-reader traversal.
- Lines 79–98 verify All = 19 from the supplied category counts, Japanese relabel, and retained category/query. The inconsistent display-stress snapshot is intentional and is not presented as domain count-engine validation.
- Lines 100–114 cover containment/nonnegative widths at 0, 4, 8, 16, and 30 points with a six-digit count. Tiny-bounds readability is not asserted.

The count identifier, use of NSTextField, intrinsic-size reference, and exact 8-point gap couple parts of these assertions to the selected presentation strategy. That coupling is acceptable here because independent numeric reservation is the approved repair, and the tests additionally check externally meaningful geometry/text/state outcomes. They do not merely restate arithmetic. The production localized-title provider is reused in expectations; independently authored localization/taxonomy tests remain the authority for translation correctness. Native role, glyph visibility, real tooltip display, and selected contrast are not established by these assertions.

Read-only inspection of Main's `focused-r1.log` confirms **34 XCTest / 0 failures, 4.047 seconds**, comprising 4 new cell tests, 9 localization tests, and 21 existing Library view tests, including category focus/composition regressions. The separate Swift Testing footer reporting zero tests does not replace the nonzero XCTest execution. These are Main's recorded results; reviewer execution remains zero. No conclusion is taken from a potentially in-progress full-suite log.

## Remaining acceptance and performance boundary

Main should attach terminal full-suite, Debug/Release/package and strict packaged-resource results to the same final freeze, then inspect the isolated native candidate for the long Japanese category with its full count (including the reported count 12), selected-row contrast, category interaction, and current AX cell structure/full text. A source getter/AX tree is not VoiceOver, and typed Japanese is not real IME acceptance. Previous broader focus/interaction/native gates retain their own evidence requirements.

Static review finds no added I/O, timer, observer, framework dependency, catalog/projection work, icon invalidation, frame/gesture callback, or physics/parameter change. The cell has a fixed number of native layout operations per layout call; intrinsic text measurement still depends on native text handling. This is static boundedness only, **not a physical performance PASS** or measured 60-Hz no-regression claim.

No implementation repair is requested by this source verdict. Native-after/full/package gates and overall project completion remain separately owned by Main.
