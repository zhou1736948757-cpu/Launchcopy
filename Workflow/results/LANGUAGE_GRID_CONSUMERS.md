# Grid and Pager Language Consumers — Task B

Status: Task B source implementation complete and frozen for Main serial compile/testing; no build, XCTest execution, application launch,
process control, packaging, signing, installation or commit performed by Task B.
The approved interface language contract governs this work. Existing dirty work is preserved.

## Resource requests

`GridTextKey` is `String, CaseIterable, Sendable`, with public `englishFallback`.
These independently authored static strings require identical coverage in all three tables.
The table below matches Main's currently integrated resource wording, verified by source read.
Spaces in the prefix/suffix entries are intentional.

| Exact case | Raw key | English | Simplified Chinese | Japanese |
| --- | --- | --- | --- | --- |
| pageNavigation | grid.pageNavigation | Page navigation | 分页导航 | ページ移動 |
| previousPageWindow | grid.previousPageWindow | Show previous pages | 显示前面的页码 | 前のページを表示 |
| nextPageWindow | grid.nextPageWindow | Show next pages | 显示后面的页码 | 次のページを表示 |
| currentPageSuffix | grid.currentPageSuffix | `, current page` | `，当前页` | `、現在のページ` |
| currentPage | grid.currentPage | Current page | 当前页 | 現在のページ |
| unselectedPage | grid.unselectedPage | Not selected | 未选中 | 未選択 |
| noPages | grid.noPages | No pages | 无页面 | ページなし |
| previousPage | grid.previousPage | Previous page | 上一页 | 前のページ |
| nextPage | grid.nextPage | Next page | 下一页 | 次のページ |
| renameFolder | grid.renameFolder | Rename folder | 重命名文件夹 | フォルダの名前を変更 |
| renameFolderPrefix | grid.renameFolderPrefix | `Rename folder: ` | `重命名文件夹：` | `フォルダの名前を変更：` |
| folderName | grid.folderName | Folder name | 文件夹名称 | フォルダ名 |

Existing `page(_:total:)` and `memberCount(_:)` are consumed directly.
Main owns `gridText(_:)`, `folderHelp(_:)` and all resources. Requested count templates:

| Helper | English one / other | Simplified Chinese | Japanese |
| --- | --- | --- | --- |
| folderHelp(count) | Folder containing {count} item / Folder containing {count} items | 文件夹，含 {count} 项 | {count} 項目を含むフォルダ |

No `uiState` or catalog status text exists in the assigned provider. Catalog/search
status relabeling belongs to Main's actual owner, including same-state refresh.

## Runtime integration required from Main

- Call `relabel(strings:)` on provider, surface, folder overlay, page dots and title
  editor immediately after construction and on accepted displayed-language presentation.
- Main owns `AppCatalogAssembly.swift`: `AppGridRenderer.relabel(strings:)` must retain
  the snapshot, forward it to live and pooled pages, and call `page.relabel(strings:)`
  before each new/reused render. All grid page/cell relabeling is queued, including
  calls made inside renderer.render. No separate stageLanguage API is necessary.
- Surface forwards the snapshot into live, pooled and newly reused PageHostView instances.
- Frozen visual-only folder exits reject relabeling; the live overlay includes its
  mounted members and move-out proxy. User titles and editor drafts remain verbatim.
- Permanently discarded page-dot chrome needs `teardown()` to invalidate queued text.
  Surface teardown invalidates queued surface/host text; grid pages invalidate on
  clear/reuse and teardown.
- Default constructors hold nil snapshots and English literals; they never construct
  LocalizedStrings or load resources when lazily invoked on a frame path.

## Verification and risks

Focused native test sources are complete. Main owns all execution
through the serial gate. Queued AX/diagnostic text intentionally requires a main-queue
turn; legacy tests asserting immediate text must drain that queue and supply their
intended language snapshot. This is an asynchronous contract adjustment, not an
executed regression PASS. Actual native GUI, VoiceOver, restart and performance gates
remain pending. No extra work in Core, assembly or shared resources is performed here.


## Changed paths

Only assigned Task B paths were edited directly:

- Sources/AppGridUI/AppGridCellView.swift
- Sources/AppGridUI/AppGridPageView.swift
- Sources/AppGridUI/AppGridUIPageContentProvider.swift
- Sources/AppGridUI/FolderOverlayView.swift
- Sources/PagingUI/PageHostView.swift (actual filename confirmed)
- Sources/PagingUI/PagingSurface.swift
- Sources/PagingPrototypeApp/PageDotsView.swift
- Sources/PagingPrototypeApp/FolderTitleEditor.swift
- Sources/LauncherLocalization/GridTextKey.swift (new)
- Tests/AppGridUITests/GridLanguageConsumersTests.swift (new)
- Tests/PagingUITests/PagerLanguageConsumersTests.swift (new)
- Workflow/results/LANGUAGE_GRID_CONSUMERS.md (new)

## Counting seams and focused native sources

All counters are internal read-only (`@testable`), cumulative, and increment only
where queued formatting actually executes; no counter increments on injection,
render staging or clear/invalidation. Default English fallback formatting is also
counted. Static key lookups are separate from parameterized formatting and are not
included in these counters.

- AppGridCellView.languageFormattingCount: +2 per current folder render, exactly
  one memberCount and one folderHelp call. App-only/cleared cells add zero.
- AppGridPageView.languageFormattingCount: +1 per current page text render.
- PageHostView.languageFormattingCount: +1 per current host page label render.
- PagingSurface.languageFormattingCount: +1 per nonempty current surface page text.
- PagingSurface.diagnosticFormattingCount: +1 per lab diagnostic String(format:) call.
- PageDotsView.languageFormattingCount: +1 per nonempty strip value and +1 per
  visible dot; at most ten per task, regardless of total page count.

GridLanguageConsumersTests contains nine native tests: three-language folder
count/help, zero/one/many and hidden captions, pending rebind/clear, retained page
identity/focus/geometry, real page+cell reuse and exact counts, terminal stale work,
provider pending+committed query preservation, mounted folder editor/frozen exits,
and multilingual footer/navigation. PagerLanguageConsumersTests contains nine:
actual host reuse/counts, retained surface and empty state, physical surface pool
reuse/latest snapshot, surface teardown, live-host count changes, browsed dot
window/actions, Int.max/selection/empty/teardown, actual unshown window field-editor
selection/responder/draft, and the actual AppGridRenderer frame transitive test.

The frame test runs real surface navigation across 100 folder pages through
AppGridRenderer, captures every live/reused/retired host/page/cell, and includes
page-dot updates in the transitive navigation callback. It asserts exact zero
synchronous formatting deltas per advanceFrame, then requires positive formatting
and selected Japanese values after a main-queue drain. It also asserts actual
host reuse, bounded residency and zero icon requests. Test-only capture arrays
are outside the frame call; production never creates all-page text arrays.

Source-only verification: bounded assigned-path git diff --check completed with
zero output. No build/test result is claimed. Existing immediate-text tests must
be adjusted by Main to drain the main queue; PageDotsView standalone defaults now
use English instead of fixed Chinese. AppGridPageView/PageHostView render text and
folder count binding are intentionally asynchronous even for nil standalone snapshots.

Main's renderer relay was observed in progress in the shared assembly source;
Main remains responsible for the final integration review, initial snapshot
installation, owner-safe presentLanguage, catalog/search status refresh, shared
resource coverage, serial native tests and actual GUI/VoiceOver acceptance.

Final bounded assembly read found a concrete remaining hook issue for Main:
`page.relabel(strings: languageStrings)` currently appears inside
`folderSnapshotProvider.didSet`, but the `render` new/reused-page path does not
forward the retained snapshot before `page.render`. Main must add that forwarding
at the actual render seam. Task B did not edit the shared assembly. The actual
renderer frame test intentionally verifies Japanese on newly created/reused pages
and will detect an English fallback at this boundary.

Final assigned-file whitespace inspection covered all twelve paths, including
new/untracked tests and the enum/report; zero trailing-whitespace issues. The eight
consumer files each expose one public `relabel(strings:)`, and none constructs a
LocalizedStrings snapshot. Task B implementation files are now frozen for Main's
serial compile gate; all eighteen test methods remain unexecuted by Task B.
