# T-1E-folderlab-membercount-repair — folder 成员数显示 0 修复（Worker 结果）

- 角色：Worker（chef-worker-reviewer-workflow）
- 日期：2026-08-30
- 状态：完成，待 Reviewer

## 根因（Main 定位，Worker 复核确认）

`Sources/AppGridUI/AppGridPageView.swift:131`
`let memberCount = folderSnapshotProvider?()?.entry(for: folderID)?.members.count ?? 0` ——
`folderSnapshotProvider` 在生产接线中从未设置（grep 全 Sources/ 仅
`Tests/AppGridUITests/FolderCellTests.swift` 设置）→ nil → `?? 0` → 每个 folder 显示 "0 items"。
组合本身正常（folder 条目带标题渲染）。`AppDelegate.installFolderWiring` 未接线该属性。

## 修复（最小）

1. `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`（非冻结）—— `AppGridRenderer` 新增
   `public var folderSnapshotProvider: (() -> FolderSnapshot?)?`，`didSet` 透传到全部既有页实例
   （镜像既有 `onIconApplyResult` 模式）；`render` 内每次选页后 `page.folderSnapshotProvider =
   folderSnapshotProvider`（含池化复用页，旧 provider 可能已变，须每次重设）。
2. `Sources/PagingPrototypeApp/AppDelegate.swift`（写集）—— `installFolderWiring` 内一行接线：
   `assembly.renderer.folderSnapshotProvider = { [weak assembly] in assembly?.provider.servedFolderSnapshot }`
   （弱捕获防引用环；与组合渲染同一 snapshot 源，FolderID 一致）。
3. 回归测试：`Tests/PagingUITests/FolderIntegrationTests.swift` 新增
   `testFolderCellMemberCountWiredFromServedSnapshot` —— 复刻生产接线（renderer.folderSnapshotProvider
   接到 assembly.provider.servedFolderSnapshot），经 fake .app 临时目录 + folder lab 组合提交后，
   渲染含 folder 条目的一页，断言 cell 显示真实成员数（`"\(expectedCount) items"`，非 0）。
   未改 Package.swift；未扫描真实 /Applications。

## 验证

- `swift test`：**758 tests, 0 failures, exit 0**（≥757 达标；新增 1 测试）。
- 新测试单独运行：`testFolderCellMemberCountWiredFromServedSnapshot` passed。
- `swift build -c debug`：exit 0。
- `swift build -c release`：exit 0。

## 冻结树验证

- 修改文件仅 3 个：`AppCatalogAssembly.swift`、`AppDelegate.swift`、`FolderIntegrationTests.swift`。
- 冻结树 `Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`：未动。
- `Package.swift`（mtime Aug 28 20:42）、`AppLaunchController.swift`（mtime Aug 28 21:46）未动。
- 无 git 操作。

## 隐私红线

- 未将 folder 标题/成员/身份原值或图标数据写入 telemetry/JSONL/stdout/signpost/profile/report；
  仅中性计数（member_count）。测试注释显式声明不打印原值。

## 偏差

- 写集仅列 `AppDelegate.swift` + 测试 + 结果文件；本修复额外修改了 `AppCatalogAssembly.swift`
  （非冻结树）。原因：`AppGridPageView` 由 `AppGridRenderer` 工厂按页创建，`folderSnapshotProvider`
  必须在渲染器层透传才能到达每页实例 —— 无此改动无法在生产接线点设置该属性。改动最小且镜像
  既有 `onIconApplyResult` 透传模式。
