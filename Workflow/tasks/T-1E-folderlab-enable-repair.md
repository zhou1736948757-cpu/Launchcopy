# T-1E-folderlab-enable-repair — --folder-lab 未生效修复

- 创建：2026-08-30（Main）
- 类型：repair（用户实机验收发现）

## 缺陷证据

- 用户实机：`--folder-lab` 启动后顶层网格无文件夹条目（截图 /tmp/p1e_folder_lab.png：Page 3 of 4 全为普通 app）。
- 根因（Main 只读定位）：`Sources/PagingPrototypeApp/AppCatalogAssembly.swift:282-283` 闭包调用 `FolderLabFixture.makeGroups(from: catalog)`，未传 configuration → 默认 `Configuration(enabled: false)`（`Sources/AppGridUI/FolderLabFixture.swift:22` `defaultEnabled = false`；:46 `guard configuration.enabled, configuration.groupSize > 0 else { return nil }`）→ 返回 nil → `rebuildFolderCompositionIfNeeded` 无 pending → 无文件夹。
- `--folder-lab` 置 `assembly.folderLabEnabled = true` 但闭包未使用该标志。

## 修复要求

1. 闭包改为 `FolderLabFixture.makeGroups(from: catalog, configuration: .init(enabled: true))`（groupSize 默认 35；或等价地使用 assembly.folderLabEnabled 驱动 configuration.enabled）。
2. 回归测试：验证 `--folder-lab` 接线产生非 nil / 非空 folder snapshot（经 makeAssembly 或 fixture 层，视测试可达性；不得改 Package.swift）。
3. 全量 `swift test` 通过（≥756/0）、debug + release exit 0。
4. 冻结树未动：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`AppLaunchController.swift`。
5. 无 git 操作；隐私红线不变（folder 标题/成员/identity 不入 telemetry）。

## 写集

`Sources/PagingPrototypeApp/AppCatalogAssembly.swift`（闭包一行）、`Tests/PagingUITests/FolderIntegrationTests.swift`（或新测试文件）、`Workflow/results/T-1E-folderlab-enable-repair.md`。

## 验收

- 修复后 `--folder-lab` 启动顶层出现 `Group N` 文件夹条目（用户实机复核）。
- 全量测试 + 构建 + 独立 Reviewer PASS。
