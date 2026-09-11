# T-1E-H2-repair — servedPageCount 硬编码 35 修复（Gate 0 假设 H2）

- Role: Worker → Reviewer
- Status: PASS
- Date: 2026-08-30

## Objective
修复 `AppGridUIPageContentProvider.servedPageCount` 用 `Self.defaultItemsPerPage`(35) 而非实际 itemsPerPage 计算页数的缺陷。非默认 `--items-per-page` 下搜索激活路径 `PagingSurface.applySameRevisionReload`(:662) 用此错误页数设 core.pageCount，且 AppDelegate `applyPresentationUpdate(overridePageCount: false)` 不自纠。

## Root cause
`Sources/AppGridUI/AppGridUIPageContentProvider.swift:56-60` — `servedPageCount = ceil(presentationRecords.count / 35)`，硬编码 35，忽略实际 itemsPerPage。例：70 结果 + itemsPerPage=20 → servedPageCount=2（实际 4 页）。

## Fix
- `AppGridUIPageContentProvider` 增加实例属性 `itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage`；`servedPageCount` 改用实例 `itemsPerPage` 推导。
- `AppDelegate.installContentAssembly` 在既有 itemsPerPage 对齐行旁设置 `assembly.provider.itemsPerPage = surface.itemsPerPage`（provider 与 searchPresentation 共享同一实例，一处设置即覆盖两条路径）。

## Files changed
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`
  - `:58-61` `servedPageCount` 改用实例 `itemsPerPage`（`:61` `(count + itemsPerPage - 1) / itemsPerPage`）。
  - `:74` 新增实例属性 `public var itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage`。
- `Sources/PagingPrototypeApp/AppDelegate.swift`
  - `:290` `assembly.provider.itemsPerPage = surface.itemsPerPage`（并列于 `:287` refreshController、`:366` presentation 对齐行）。
- `Tests/AppGridUITests/AppGridUIPageContentProviderTests.swift`
  - `:226` `testServedPageCountUsesInstanceItemsPerPage` — 70 条 + itemsPerPage=20 → servedPageCount == 4（非 2）。
  - `:234` `testServedPageCountDefaultItemsPerPageUnchanged` — 默认 35：35→1 页、36→2 页。

## Test counts
- Filtered (AppGridUITests): **134 tests, 0 failures**.
- Full (`swift test`): **633 tests, 0 failures** (≥631 要求满足). swift-testing 显示 '0 tests in 0 suites'（正常）。

## Build results
- `swift build -c debug` → exit 0.
- `swift build -c release` → exit 0.

## Frozen-tree verification
mtime 基线对比（改动前捕获 vs 改动后复查），全部一致，未触碰：
- Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/（默认冻结）
- Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift

## Hygiene
- 改动文件无 trailing whitespace、无 conflict markers（grep 均无命中）。
- 无 git 操作。
- 无禁止 token（ALL_HITCHES_FIXED/ROOT_CAUSE_FOUND/FIX_VALIDATED）。
- 纯页数数学，无隐私/telemetry 泄漏。

## Deviations
无。未修改 AppCatalogAssembly.swift（provider 经 `assembly.provider` 访问，符合 write scope）。

## Summary
`servedPageCount` 改用实例 `itemsPerPage` 并在 AppDelegate 装配处与 surface 对齐，非默认 `--items-per-page` 下页数推导正确；633 测试全绿、debug/release 构建通过、冻结树未动。
