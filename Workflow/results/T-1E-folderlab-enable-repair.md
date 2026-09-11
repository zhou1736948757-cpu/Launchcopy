# T-1E-folderlab-enable-repair — --folder-lab 未生效修复（Worker 结果）

- 角色：Worker（chef-worker-reviewer-workflow）
- 日期：2026-08-30
- 状态：完成，待 Reviewer

## 根因（Main 定位，Worker 复核确认）

`Sources/PagingPrototypeApp/AppCatalogAssembly.swift:282-283` 闭包调用
`FolderLabFixture.makeGroups(from: catalog)`，未传 configuration → 默认
`Configuration(enabled: false)`（`Sources/AppGridUI/FolderLabFixture.swift:22` `defaultEnabled = false`；
`:46` `guard configuration.enabled, configuration.groupSize > 0 else { return nil }`）→ 返回 nil →
`rebuildFolderCompositionIfNeeded` 无 pending → 顶层网格无文件夹条目。
`--folder-lab` 置 `assembly.folderLabEnabled = true` 但闭包未使用该标志。

## 修复（最小）

1. `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`（闭包一行）：
   `FolderLabFixture.makeGroups(from: catalog, configuration: .init(enabled: true))`
   （groupSize 默认 35）。**未改** `FolderLabFixture.swift` 默认值（产品启动不重排用户应用）。
2. 回归测试：`Tests/PagingUITests/FolderIntegrationTests.swift` 新增
   `testFolderLabFlagWiringProducesNonEmptySnapshot` —— 经 `AppRuntimeFactory.makeAssembly(options:)`
   （`--folder-lab`）断言装配非 nil、`folderLabEnabled` 置位、`folderSnapshotGenerator` 已接线，
   并以 fixture snapshot 驱动生成器断言非 nil / 非空 folder snapshot（不 begin，避免扫真实 /Applications）。
   未改 Package.swift；未削弱既有测试。

## 验证

- `swift test`：**757 tests, 0 failures, exit 0**（≥756 达标）。
- `swift build -c debug`：exit 0。
- `swift build -c release`：exit 0。

## 冻结树验证

- 仅修改写集内两文件：`AppCatalogAssembly.swift`、`FolderIntegrationTests.swift`。
- 冻结树 `Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`：
  0 个文件 mtime 晚于本次编辑（`find -newer` 计数为 0）。
- `Package.swift`（mtime Aug 28 20:42）、`AppLaunchController.swift`（mtime Aug 28 21:46）未动。
- 无 git 操作。

## 隐私红线

- 未将 folder 标题/成员/身份原值或图标数据写入 telemetry/JSONL/stdout/signpost/profile/report；
  仅中性计数与决策枚举。测试注释显式声明不打印原值。

## 偏差

- 无。闭包按任务要求改为显式 `enabled: true`（等价于用 `assembly.folderLabEnabled` 驱动，
  因闭包内 `assembly` 尚未完全初始化，直接传字面量更稳妥且最小）。
