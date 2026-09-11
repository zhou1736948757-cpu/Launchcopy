# T-1D-E Result — 搜索装配 / 空白点击 / 启动集成

- **Task ID**: T-1D-E
- **Role**: Worker E（fresh context，未读取任何逆向材料）
- **Phase**: 1D — 装配 / 空白点击 / 启动集成（serial after A–D）
- **Status**: ✅ COMPLETE — 全部验证通过

## 1. Files Written

| File | What it does |
|------|--------------|
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 搜索接线 + 空白点击 interaction-zone 分类。新增 `search` 属性；`installContentAssembly` 内装配 search controller / presentation controller；窗口 contentView 改为容器（surface + search field 作为 sibling overlay）；`blankClickResolvesToCell` 扩展搜索 field 分类；`teardownAll` 调 `search.teardown()`。 |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | **仅搜索接线**：新增 `public let searchPresentation: AppGridSearchPresentationController`（init 内以 `provider` 创建），使装配层成为搜索 presentation 的 composition root。 |
| `Tests/PagingUITests/AppSearchIntegrationTests.swift` | **新**：8 个集成测试，镜像生产 AppDelegate 接线（sibling overlay、Command-F、实时过滤、空白点击分类、启动复用 handleCell、刷新重跑查询、Escape 清空/还焦）。 |
| `Tests/PagingUITests/BlankClickToQuitTests.swift` | 扩展：+3 个搜索 field 分类测试（field 本身 / 子视图 / 容器中 field 均为 interaction zone）。 |
| `Workflow/results/T-1D-E.md` | 本结果文档。 |

## 2. Wiring Implemented（6 handoff items）

1. **`keyboard.onSearchShortcut = { search.activateSearch() }`** — 在 `installContentAssembly` 内接线，Command-F → 搜索框 first responder。
2. **`search.field` 作为 sibling overlay** — 窗口 contentView 改为容器 `NSView`；`surface` 与 `search.field` 均为容器子视图（field 不随页面容器平移）。field 顶部居中（宽 300、高 28、距顶 12pt），autoresizing `[.minXMargin, .maxXMargin, .minYMargin]`。
3. **`search.install(in: window)` / `search.teardown()`** — field 加入容器后调 `install(in:)`（观察窗口 key 状态重建 first responder）；`teardownAll` 内 `MainActor.assumeIsolated { search?.teardown() }`。
4. **`blankClickResolvesToCell` 扩展** — 先检查 `AppSearchFieldView.isSearchFieldOrSubview(hit)` → 返回 true（interaction zone，不退出）；真实背景空白仍首击退出。**未做 hitTest 改写**（保留 scrollWheel 路由）。
5. **`search.commitPendingAtIdleBoundary()` 从 `surface.onIdleBoundary` 调用** — 与刷新控制器并列，覆盖 busy 态 pending 搜索提交。**关键顺序**：搜索提交**优先**于刷新控制器（见 §4 设计决策）。
6. **`presentation.onSearchResultCommitted` → `surface.reloadCurrentPresentation()`** — 同 revision 重载 seam。

## 3. Test Counts

- **New tests**: 11（AppSearchIntegrationTests 8 + BlankClickToQuitTests 新增 3）
- **Full suite**: **620 tests, 0 failures, exit 0**（基线 609 + 11 新增）

## 4. Build Results

- `swift build -c debug` → **exit 0**（无警告）
- `swift build -c release` → **exit 0**
- `swift test`（full suite）→ **620 tests, 0 failures, exit 0**

## 5. Forbidden-Tree Confirmation

- `Sources/PagingCore/`、`Sources/PagingUI/`、`Sources/AppGridUI/`、`Sources/MacAppCatalog/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift` — **均未修改**（mtimes 为 Workers A–D 时期，早于本 Worker 会话）。
- 七字段 `ItemBindingToken`（catalogRevision / pageIdentity / itemSlot / appID / reuseGeneration / iconKey / surfaceGeneration）**完整未动**。
- 无 CatalogRevision 伪造：焦点布局用 `CatalogSnapshot(revision: base.revision, records: presentationRecords)`（served revision，与搜索控制器 `firstValidResultOnCurrentPage` 同模式）。
- 无全局 NSEvent monitor / Accessibility / Spotlight / 同步 I/O / 查询结果持久化。
- 无 PagingTelemetry schema 变更；query/result 名绝不进 telemetry/log/stdout/signpost/profile/report。
- 帧 Timer tolerance 保持 8.333ms（`?? (1.0 / 120.0)` 未改）。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`（无 hitch-fix 声明）。
- 无 commit/push/tag/reset/clean。未读取任何禁止来源。

## 6. Deviations from Packet（with rationale）

1. **BlankClickToQuitTests 未含 field-editor 单测**：`AppSearchFieldView.currentEditor()` 在 field 非 first responder（无窗口/未编辑）时返回 nil，无法在无头隔离测试中构造真实 field editor。field-editor 分类改由集成测试 `testBlankClickOnSearchFieldDoesNotQuit` 覆盖（先 `search.activateSearch()` 使 field 成为 first responder，再断言 `blankClickResolvesToCell(editor)`）。覆盖等价，无功能缺失。
2. **AppCatalogAssembly 新增 `searchPresentation` 属性**：任务要求"仅搜索接线：连接 search controller → presentation controller → provider"。为让装配层成为搜索 presentation 的 composition root，新增该只读属性（init 内以 `provider` 创建）。这是搜索接线的最小 seam，未触碰其他装配逻辑。

## 7. Design Decisions（for Reviewer）

- **idle 边界顺序**：`applyPendingAtIdleBoundary()` 先调 `search.commitPendingAtIdleBoundary()`，再调 `assembly.refreshController.applyPendingAtIdleBoundary()`。原因：presentation controller 的 `applyPendingAtIdleBoundary` 只有**自己**应用 pending catalog snapshot 时才会在新 base 上重跑当前查询；若刷新控制器先应用，`provider.applyPending` 会重置 `presentationRecords` 并清空 `pendingSearchResult`，导致搜索查询丢失。搜索先行后，刷新控制器对 pending catalog snapshot 为 no-op。
- **`presentation.onPresentationUpdate` 接线**：presentation controller 应用 catalog snapshot（搜索激活路径）时，刷新控制器不参与 → 需自行更新 urlResolver + 刷新 surface。搜索激活时 `overridePageCount = false`（按过滤后 `presentationRecords` 的 servedPageCount 刷新，不覆盖 pageCount）；非搜索时 `overridePageCount = true`（对齐非默认 `--items-per-page`）。
- **焦点布局基于 presentationRecords**：`applyPresentationUpdate` 用 `CatalogSnapshot(revision: base.revision, records: presentationRecords)` 构建焦点布局（搜索激活时 = 过滤结果集；非搜索 = base records），与搜索控制器 `firstValidResultOnCurrentPage` 一致。

## 8. Handoff Notes for Reviewer

- 请独立核对：idle 边界顺序（搜索提交优先）是否破坏 catalog refresh 的 pin/latest-wins；`presentation.onPresentationUpdate` 的 urlResolver 更新是否与刷新控制器路径一致；搜索 field 点击是否被错判为空白退出；搜索启动是否复用 `AppLaunchController.handleCell`（无并行路径）；query/result 名是否泄漏；禁止来源/品牌/私有 API 是否触碰。
- 自动化测试为 headless-safe：启动测试用 `RecordingLauncher`（fake launcher），断言启动漏斗被调用（`launcher.opened`），**不**启动真实 bundle。
- 真实 GUI 启动（全屏过渡、真实触控板、真实 NSWorkspace 启动）为手工验收项，不在单测范围。
