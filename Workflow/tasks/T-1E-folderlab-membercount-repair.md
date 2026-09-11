# T-1E-folderlab-membercount-repair — 文件夹成员数显示 0 修复

- 创建：2026-08-30（Main）
- 类型：repair（用户实机验收发现，--folder-lab 修复后复测）

## 缺陷证据

- 用户实机（--folder-lab 修复合并后）：顶层出现 Group 1–4 文件夹条目，但每个显示 "0 items"；网格下方无 app 条目（140 apps 全部分组 → ungrouped=0，属预期）；截图 /tmp/p1e_folder_lab3.png。
- 根因（Main 只读定位）：`Sources/AppGridUI/AppGridPageView.swift:131` `let memberCount = folderSnapshotProvider?()?.entry(for: folderID)?.members.count ?? 0` —— `folderSnapshotProvider` 在生产接线中从未设置（grep 全 Sources/ 仅 Tests/AppGridUITests/FolderCellTests.swift 设置），nil → `?? 0` → "0 items"。
- `AppDelegate.installFolderWiring`（AppDelegate.swift:418）未接线 `pageView.folderSnapshotProvider`。

## 修复要求

1. 在 `AppDelegate.installFolderWiring`（或等价生产接线点）设置 `pageView.folderSnapshotProvider`，返回装配的 served folder snapshot（如 `assembly.provider.servedFolderSnapshot`，以实际 API 为准；须与组合渲染同一 snapshot 源，FolderID 一致）。
2. 回归测试：验证接线后 folder cell 成员数正确（若集成测试可达；不得改 Package.swift；不得扫描真实 /Applications）。
3. 全量 `swift test` 通过（≥757/0）、debug + release exit 0。
4. 冻结树未动：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`AppLaunchController.swift`。
5. 无 git 操作；隐私红线不变。

## 写集

`Sources/PagingPrototypeApp/AppDelegate.swift`（installFolderWiring 一行接线）、`Tests/PagingUITests/FolderIntegrationTests.swift`（或新测试）、`Workflow/results/T-1E-folderlab-membercount-repair.md`。

## 验收

- 修复后 `--folder-lab` 启动：Group N 显示真实成员数（35 items），打开层成员网格正常（用户实机复核）。
- 全量测试 + 构建 + 独立 Reviewer PASS。
