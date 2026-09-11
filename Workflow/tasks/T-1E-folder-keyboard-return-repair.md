# T-1E-folder-keyboard-return-repair（Task B：键盘 Return 打开 folder 接线）

Status: OPEN（依赖 Task A 合并后启动）
Phase: 1E
Depends on: T-1E-folder-focus-layout-repair（Task A，提供组合化布局 API）
Created: 2025-08-30（Main，用户 Bug 4 报告后只读根因调查）

## 用户报告（逐字，Bug 4）

"现在在那个键盘界面的话，移到这个文件夹Folder里面，然后按下Return是进不了这个文件夹的。"

## 根因（Main 只读调查；Task A 包内完整证据链）

外层焦点布局基于 app-only `CatalogSnapshot` 构建，网格 cell 按统一组合渲染 → folder 槽位身份
`entryIdentity == .app(<同索引 app>)` → Return 走 `.launchApp` → folder cell 被
`AppLaunchController` 的 `as? AppID` 拒绝 → 无动作。Task A 已把 `AppGridFocusLayout` /
`AppGridFocusNavigator` 组合化（validEntry + entryIdentity 身份）。本任务把**调用方**切到组合化
API：

- `Sources/PagingPrototypeApp/KeyboardFocusController.swift:472-480` `currentLayout()`：
  用 `provider.presentationEntries`（组合）构建布局，替换 `AppGridFocusLayout.build(from:
  snapshot, itemsPerPage:)`。
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift:483-489` `committedPageTarget`：
  `layout.validAppID` → `layout.validEntry`，身份用 `entryIdentity:` 构造。
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift:238-241` `reconcileSettledCrossPage`：
  pending 目标槽位有效性检查 `layout.validAppID` → `layout.validEntry`（entryIdentity 比较）。
- `Sources/PagingPrototypeApp/AppDelegate.swift:506-510` `applyPresentationUpdate`：
  布局构建源 `presentationRecords`（app-only）→ `assembly.provider.presentationEntries`（组合；
  搜索激活时该属性 = 结果 .app 条目，语义不变）。

## 修复规格

1. `KeyboardFocusController.currentLayout()`：`guard let provider = surface.contentProvider as?
   AppGridUIPageContentProvider, let snapshot = provider.servedSnapshot` →
   `AppGridFocusLayout.build(from: snapshot, composition: provider.presentationEntries,
   itemsPerPage: surface.itemsPerPage)`。
2. `committedPageTarget`：`guard let slot = layout.validSlots(on: committedPage).first,
   let entry = layout.validEntry(page: committedPage, slot: slot)` →
   `AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: committedPage,
   slotIndex: slot, entryIdentity: entry)`。
3. `reconcileSettledCrossPage`（:238-241）：pending 目标有效性 → `layout.validEntry(page:
   pending.pageIndex, slot: pending.slotIndex) == pending.entryIdentity`（或等价 entryIdentity
   比较；Worker 按上下文最小改动）。
4. `AppDelegate.applyPresentationUpdate`（:506-510）：`let layout =
   AppGridFocusLayout.build(from: snapshot, composition: assembly.provider.presentationEntries,
   itemsPerPage: surface.itemsPerPage)`。
5. 不改 `routeActivation` / `ActivationRouter` / `openFolder` / `openFolderFromClick` /
   `handleInnerArrow` / `applyInnerFocusVisual` 语义（Task A 后身份已正确，Return 自然走
   `.openFolder`）。

## 测试（Tests/PagingUITests/）

- 新增集成测试（FolderIntegrationTests.swift 或新文件，Worker 自定）：
  - (a) 组合 fixture（3 folder + 若干 app）→ `keyboard.setFocus` 到 folder 槽位身份
    （entryIdentity: .folder）→ `keyDown(returnKey)` → `folderOpenState.isOpen == true`。
  - (b) **导航器路径**（关键回归）：`keyDown(downArrow)` 播种 → 连续方向键移到 folder 槽位 →
    断言 `keyboard.focusModel.current?.entryIdentity` 为 `.folder`（Task A 后导航器构造正确）
    → `keyDown(returnKey)` → `folderOpenState.isOpen == true`。
  - (c) app 槽位身份正确：移到 app cell → `entryIdentity == .app(<该 cell 实际 app>)`
    （防"差文件夹数"错位回归）。
  - (d) 既有测试（testKeyboardOpenDefersInnerRingUntilFirstArrow 等）保持通过。
- 若既有 KeyboardFocusControllerTests / AppSearchResponderTests 因 API 变化需微调，允许
  最小适配（断言语义不变）。

## 写范围

- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Tests/PagingUITests/`（新增/修改测试）

## 禁止（绝不修改）

- 冻结树：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、
  `Sources/PagingPrototypeApp/AppLaunchController.swift`
- `Sources/AppGridUI/`（Task A 已合并，本任务只消费其 API）、`Sources/AppCatalogAssembly.swift`
- 无 git 操作（仓库无 commit）

## 验证

- `swift build -c debug` exit 0
- `swift test`：XCTest "Executed N tests" N > 0 且 0 failures（基线 772 + Task A 新增；本任务
  新增 ≥ 3 测试）
- `swift build -c release` exit 0
- 冻结树 mtime 不变（记录修改前后）

## 输出纪律（Worker 必读）

- **先写** `Workflow/results/T-1E-folder-keyboard-return-repair.md`（"in progress"）再实现。
- 最终回复 < 250 词，无大代码块。
- 结果文件 Status: PASS 需含：改动文件清单、测试计数、双构建结果、冻结树 mtime 核验。

## 验收（Reviewer 独立核验）

- 三个调用点全部切到组合化 API；身份 entryIdentity 正确。
- 集成测试 (b) 覆盖"导航器移到 folder → Return 打开"全链路（用户 Bug 4 精确复现路径）。
- 全部测试通过；双构建 exit 0；冻结树未动。
