# T-1E-folder-focus-layout-repair（Task A：焦点布局/导航器组合化）

Status: OPEN
Phase: 1E
Depends on: T-1E-A（ADR-008 已 ACCEPTED）
Supersedes: 无
Created: 2025-08-30（Main，用户 Bug 4 报告后只读根因调查）

## 用户报告（逐字，Bug 4）

"现在在那个键盘界面的话，移到这个文件夹Folder里面，然后按下Return是进不了这个文件夹的。"

## 根因（Main 只读调查，证据齐全）

外层焦点布局 `AppGridFocusLayout` 基于 **app-only** `CatalogSnapshot` 构建，而网格 cell 按
**统一组合** `presentationEntries: [TopLevelEntry]`（app + folder）渲染。两者槽位映射不一致：

- `Sources/AppGridUI/FolderDomain.swift:238-257` `TopLevelComposition.build`：文件夹在前
  （snapshot 顺序），未分组 app 在后（catalog 顺序）。fixture（3 文件夹 + 32 未分组 app）→
  composition[0..2] = 文件夹，composition[3..34] = app。
- `Sources/AppGridUI/AppGridFocusLayout.swift:47-52` `validAppID(page:slot:)` 返回
  `snapshot.records[index].id`（app-only 索引）——folder 槽位返回的是**同索引的 app id**。
- `Sources/AppGridUI/AppGridFocusNavigator.swift:66-70` `makeIdentity` 用 `appID:` 构造身份
  （`AppGridFocusIdentity(catalogRevision:pageIndex:slotIndex:appID:)`）——落在 folder cell 上的
  身份 `entryIdentity == .app(<同索引 app>)`，**不是 `.folder(folderID)`**。
- 后果链：folder cell 上 Return → `KeyboardFocusController.routeActivation`（:393-402）→
  `ActivationRouter.decide(.app)` → `.launchApp` → `onActivate` → `KeyboardLaunchAdapter.activate`
  → `cellResolver`（AppDelegate.swift:364-367 按 page/slot 取 cell）→ folder cell →
  `AppLaunchController.handleCell` → `as? AppID` 失败 → `.rejectedNoBinding` → **无动作**
  （用户观察："按下Return是进不了这个文件夹的"）。
- 同根因潜伏 bug：app cell（slot ≥ 3）身份 `appID: records[slot].id` 与 cell 实际条目
  `composition[slot]` 不一致（差文件夹数）→ Return 启动**错误 app**。
- 同根因潜伏 bug：`pageCount` 基于 app 数（32 → 1 页），组合 35 条目 → 1 页（本例巧合一致；
  ≥70 app + 文件夹时页数分叉 → 跨页导航/落点错误）。
- ADR-008 §3 Q3（Docs/ADR-008-FOLDER-PRESENTATION.md:84）意图设计：
  "`AppGridFocusLayout` is built from the top-level composition; focus identity carries neutral
  entry identity"——**实现 GAP**。

## 修复规格（Task A：AppGridUI 域，纯逻辑）

### 1. `Sources/AppGridUI/AppGridFocusLayout.swift`

- 存储属性：保留 `snapshot: CatalogSnapshot`（revision + remap 源），**新增**
  `entries: [TopLevelEntry]`（统一组合；app-only 构建时 = records.map { .app($0) }）。
- 新增构建：`public static func build(from snapshot: CatalogSnapshot, composition: [TopLevelEntry],
  itemsPerPage: Int) -> AppGridFocusLayout`。
- 既有构建 `build(from:itemsPerPage:)` 保留：内部 `composition = snapshot.records.map { .app($0) }`
  （搜索路径 + 既有测试零改动）。
- `validItemCount` → `entries.count`；`pageCount` → `ceil(entries.count / itemsPerPage)`。
- 新增主 API：`public func validEntry(page: Int, slot: Int) -> TopLevelEntryIdentity?`
  （`entries[page*itemsPerPage+slot].identity`；越界/无效 → nil）。
- `validAppID(page:slot:)` 改为兼容助手：`validEntry(...)` 的 `.app(id)` case → id；folder/占位 → nil
  （搜索路径 AppSearchController.swift:218 + 既有测试继续可用）。
- `firstValidIdentity()` → 用 `validEntry` 构造 `entryIdentity:` 身份。
- `contains(_:)` / `position(of:)` → 按 `TopLevelEntryIdentity` 搜索 `entries`（不再搜
  snapshot.records——app 在组合中的网格位置含文件夹偏移）。
- `migrate(identity:)` → anchor = `identity.entryIdentity`：
  - `.app(id)` → 既有路径（position in entries → located；消失 → CatalogPlanner.remap 五级降级）；
  - `.folder(id)` → entries 中存在 → `.located`（新位置）；消失 → `.clamped(firstValidIdentity())`
    （确定性；folder 无 remap 路径）；
  - nil → 既有"无有效 anchor → clamped 首有效"路径。
- `Equatable` 保持（TopLevelEntry 已 Equatable）。

### 2. `Sources/AppGridUI/AppGridFocusNavigator.swift`

- :32-33 守卫：`layout.validEntry(page: identity.pageIndex, slot: identity.slotIndex) ==
  identity.entryIdentity`（替换 validAppID == appID——否则 folder 身份上导航被误拦）。
- :66-70 `makeIdentity`：`guard let entry = layout.validEntry(page:page, slot:slot)` →
  `AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: page, slotIndex: slot,
  entryIdentity: entry)`。

### 3. 测试（Tests/AppGridUITests/）

- 新增 `AppGridFocusCompositionTests.swift`（或并入既有文件，Worker 自定）：
  - 组合布局：3 folder + 32 app → pageCount == 1、validSlots == 0..<35、
    validEntry(0,0..2) == .folder、validEntry(0,3) == .app(未分组首 app)、
    validAppID(0,0) == nil（folder 槽位）、validAppID(0,3) == 未分组首 app id。
  - 导航器：从 slot 0（folder）↓ → 目标身份 entryIdentity == .folder（同列下一行）；
    从 folder 身份 ↑/↓/←/→ 均可移动（守卫不误拦）；app 槽位身份 entryIdentity == .app(正确 app)。
  - migrate：folder anchor 存在 → .located；消失 → .clamped；app anchor 在组合中偏移后仍
    .located 到正确位置。
  - 既有 AppGridFocusTests / AppGridFocusNavigatorTests 全部保持通过（app-only 构建兼容）。

## 写范围

- `Sources/AppGridUI/AppGridFocusLayout.swift`
- `Sources/AppGridUI/AppGridFocusNavigator.swift`
- `Tests/AppGridUITests/`（新增/修改测试）

## 禁止（绝不修改）

- 冻结树：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、
  `Sources/PagingPrototypeApp/AppLaunchController.swift`
- `Sources/PagingPrototypeApp/`（Task B 范围）、`Sources/AppGridUI/FolderDomain.swift`、
  `Sources/AppGridUI/AppGridUIPageContentProvider.swift`、`Sources/AppGridUI/AppGridFocusModel.swift`
- 无 git 操作（仓库无 commit）

## 验证

- `swift build -c debug` exit 0
- `swift test`：XCTest "Executed N tests" N > 0 且 0 failures（基线 772；本任务新增 ≥ 6 测试）
- `swift build -c release` exit 0
- 冻结树 mtime 不变（记录修改前后）

## 输出纪律（Worker 必读）

- **先写** `Workflow/results/T-1E-folder-focus-layout-repair.md`（"in progress"）再实现。
- 最终回复 < 250 词，无大代码块（历史教训：5 个 Worker 因上下文耗尽产出空结果）。
- 结果文件 Status: PASS 需含：改动文件清单、测试计数、双构建结果、冻结树 mtime 核验。

## 验收（Reviewer 独立核验）

- 组合布局 API 正确（validEntry/validAppID 兼容/pageCount/position/migrate folder 分支）。
- 导航器守卫 + makeIdentity 用 entryIdentity；folder 身份可导航。
- 全部测试通过（含既有 app-only 测试）；双构建 exit 0；冻结树未动。
