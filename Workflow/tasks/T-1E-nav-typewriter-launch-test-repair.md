# T-1E-nav-typewriter-launch-test-repair（Task C：KeyboardLaunchTests 跨页序列适配）

Status: OPEN
Phase: 1E
Depends on: T-1E-nav-typewriter-outer-repair（Task A 行为已实现）
Created: 2025-08-30（Main，Task A Worker 报告写范围外失败）

## 背景

Task A（外层打字机）合并前，`AppGridFocusNavigator` 的 → 在行末跨页（row-preserving）。
Task A 后：→ 行末 → 下一行第一个（同页），页末才跨页。Task A Worker 全量测试 787 项中
3 项失败，全部在写范围外的 `Tests/PagingUITests/KeyboardLaunchTests.swift`：
`testAccessibilityVisualFocusLaunchObjectConsistency`（:291-324）——旧序列"4×→ 到 slot 4
（行末）→ 跨页"在打字机语义下第 5 次 → 只到 slot 5（下一行第一个），跨页不再触发，
committed 页不变 → ②③④ 断言失败（视觉焦点=committed 页首格、identity.appID==焦点 cell
appID、启动对象=committed 页首个可启动对象）。Task A Worker 按包内规则未修改，如实报告。

## 修复规格

`Tests/PagingUITests/KeyboardLaunchTests.swift` `testAccessibilityVisualFocusLaunchObjectConsistency`：

- :302 注释 "导航到 page 0, slot 4（行末）→ 键盘跨页到 page 1" → "导航到 page 0, slot 34（页末）→ 键盘跨页到 page 1"。
- :303-305 `for _ in 0..<4` → `for _ in 0..<34`（打字机语义下从 slot 0 走 34 步到页末 slot 34）。
- :306-323 断言**不变**（已按"committed 页首个有效 cell"语义编写，与打字机跨页落点一致）。
- 其余测试不动。

## 写范围

- `Tests/PagingUITests/KeyboardLaunchTests.swift`（仅上述测试方法）

## 禁止（绝不修改）

- 冻结树：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、
  `Sources/PagingPrototypeApp/AppLaunchController.swift`
- `Sources/AppGridUI/AppGridFocusNavigator.swift`（Task A 已合并）、
  `Sources/AppGridUI/FolderKeyboardLogic.swift`（Task B 范围）、`Sources/PagingPrototypeApp/`
- 无 git 操作（仓库无 commit）

## 验证

- `swift build -c debug` exit 0
- `swift test`：XCTest "Executed N tests" N > 0 且 0 failures（基线 787，修复后 787/0）
- `swift build -c release` exit 0
- 冻结树 mtime 不变（记录修改前后）

## 输出纪律（Worker 必读）

- **先写** `Workflow/results/T-1E-nav-typewriter-launch-test-repair.md`（"in progress"）再实现。
- 最终回复 < 250 词，无大代码块。
- 结果文件 Status: PASS 需含：改动清单、测试计数、双构建结果、冻结树 mtime 核验。

## 验收（Reviewer 独立核验）

- 测试在打字机语义下通过（34× 到页末 → 跨页 → committed 页首格断言成立）。
- 全量测试 787/0；双构建 exit 0；冻结树未动；写范围外零改动。
