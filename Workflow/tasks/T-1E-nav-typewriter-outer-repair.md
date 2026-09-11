# T-1E-nav-typewriter-outer-repair（Task A：外层导航打字机环绕）

Status: OPEN
Phase: 1E
Depends on: 无（与 Task B 顺序执行，写范围互斥）
Created: 2025-08-30（Main，用户设计请求）

## 用户请求（逐字）

"我想了一下，往下按的话应该跟往右按一样。比如说我在这比如说这一面啊，它一共有n多个就是APP，然后像我们往右按对吧？往右按到第一行的末端了，然后再往右的话，再往右按的话，就会到下面一行的第一个，对吧？所以我觉得按下按或者往上按应该也是一样的道理。就是说，比如说我在第一列当中往下按到底了，再按一下下的话，应该到下一列的第一个，对吧？然后这个逻辑的话，我觉得是在这个就是主页面和这个APP这Folder里面的页面应该都是这样的。"

## 需求语义（打字机环绕模型）

- **→**：行内右移；行末 → 下一行第一个（同页）；末行末 → 下一页首格；末页 → nil。
- **←**：行内左移；行首 → 上一行最后一个（同页）；首行首 → 上一页末格；首页 → nil。
- **↓**：列内下移；列底 → 下一列第一个（同页）；末列底 → 下一页首格；末页 → nil。
- **↑**：列内上移；列顶 → 上一列最后一个（同页）；首列顶 → 上一页末格；首页 → nil。
- 全局边界不环绕（末页最右/最下、首页最左/最上 → nil，保持既有策略）。
- 主页面与文件夹内页面行为一致（用户明确要求；文件夹内 ←/→ 已是打字机式，见 Task B）。

## 当前行为（证据）

`Sources/AppGridUI/AppGridFocusNavigator.swift`（94 行，已读）：
- :44-48 →：行内右移；行末 → `crossPageRight`（**下一页同 row**，row 越界 → 末个有效 cell）。
- :49-53 ←：行内左移；行首 → `crossPageLeft`（**上一页同 row**）。
- :54-58 ↓：列内下移；列底 → **nil（clamp）**。
- :59-63 ↑：列内上移；列顶 → **nil（clamp）**。
- :73-93 `crossPageRight/Left`：row-preserving 跨页。
- 文件头 :5-8 注释文档化旧策略（需同步更新）。

用户观察到的"行末 → 下一行第一个"来自**文件夹内**导航器（FolderInnerNavigator ←/→ 已是打字机式，Task B 范围）；外层 ←/→ 是跨页同位置，↓/↑ 是 clamp——与用户模型不一致，本任务统一外层为打字机式。

## 修复规格（Task A：外层导航器）

`Sources/AppGridUI/AppGridFocusNavigator.swift` `move(_:direction:in:)`：

- **→**：`slots.first(where: { $0 > slot && $0 / columns == row })` 无 → `slots.first(where: { $0 / columns == row + 1 })`（下一行第一个）无 → 下一页首格（`crossPageRight` 改为返回下一页**首个有效 slot**）；末页 → nil。
- **←**：`slots.last(where: { $0 < slot && $0 / columns == row })` 无 → `slots.last(where: { $0 / columns == row - 1 })`（上一行最后一个）无 → 上一页末格（`crossPageLeft` 改为返回上一页**末个有效 slot**）；首页 → nil。
- **↓**：`slots.first(where: { $0 > slot && $0 % columns == col })` 无 → `slots.first(where: { $0 % columns == col + 1 })`（下一列第一个）无 → 下一页首格；末页 → nil。
- **↑**：`slots.last(where: { $0 < slot && $0 % columns == col })` 无 → `slots.last(where: { $0 % columns == col - 1 })`（上一列最后一个）无 → 上一页末格；首页 → nil。
- 守卫（:33-34 validEntry == entryIdentity）与 `makeIdentity`（:67-71 entryIdentity 构造）**不变**。
- 文件头 :5-8 策略注释更新为打字机语义。
- 跨页目标语义：`crossPageRight` → 下一页 `slots.first`；`crossPageLeft` → 上一页 `slots.last`（替换 row-preserving 逻辑）。

## 测试更新（Tests/AppGridUITests/ + Tests/PagingUITests/）

- `AppGridFocusNavigatorTests.swift`：更新旧行为断言——
  - `testUpDownIn5Columns` / `testUpDownInNon5Columns`：列底 clamp → 下一列第一个；列顶 clamp → 上一列最后一个。
  - `testCrossPageRight` / `testCrossPageLeft` / `testCrossPageClampWhenNextPageShorter`：row-preserving → 页首/页末格。
  - `testRightLeftIn5Columns` / `testRightLeftInNon5Columns`：行末 → 下一行第一个（同页）；行首 → 上一行最后一个。
  - `testNoWrapAtGlobalBoundary`：保持（末页 → nil）+ 补 ↓/↑ 全局边界断言。
  - `testRepeatedArrowKeysPredictable` / `testRapidSequencePredictable`：按新语义重算序列。
  - 新增：部分末页（如 32 项）列底环绕到下一列第一个、末列底 → 下一页首格、首列顶 → 上一页末格。
- `AppGridFocusCompositionTests.swift`：导航器 folder 槽位测试按新语义核验（若断言旧 clamp/跨页行为则更新）。
- `KeyboardFocusControllerTests.swift`：`testCrossPageFocusVisualLandsOnNewPage` / `testCrossPageSettleReconcilesFocusToCommittedPage` / `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` / `testCrossPageLeftSettlePreservesRowEndLanding`：跨页触发序列改为"走到页末再跨页"（打字机下需更多 → 按键）；断言语义（跨页落点/调和）不变。
- 若全量测试出现**写范围外**的失败（如 FolderIntegrationTests 导航序列），**不要修改**——在结果文件如实报告（Task B 范围）。

## 写范围

- `Sources/AppGridUI/AppGridFocusNavigator.swift`
- `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift`
- `Tests/AppGridUITests/AppGridFocusCompositionTests.swift`
- `Tests/PagingUITests/KeyboardFocusControllerTests.swift`

## 禁止（绝不修改）

- 冻结树：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、
  `Sources/PagingPrototypeApp/AppLaunchController.swift`
- `Sources/AppGridUI/FolderKeyboardLogic.swift`（Task B 范围）、`Sources/PagingPrototypeApp/`（除
  KeyboardFocusControllerTests）、`Sources/AppGridUI/FolderDomain.swift`、
  `Sources/AppGridUI/AppGridUIPageContentProvider.swift`、`Sources/AppGridUI/AppGridFocusModel.swift`
- 无 git 操作（仓库无 commit）

## 验证

- `swift build -c debug` exit 0
- `swift test`：XCTest "Executed N tests" N > 0 且 0 failures（基线 785）
- `swift build -c release` exit 0
- 冻结树 mtime 不变（记录修改前后）

## 输出纪律（Worker 必读）

- **先写** `Workflow/results/T-1E-nav-typewriter-outer-repair.md`（"in progress"）再实现。
- 最终回复 < 250 词，无大代码块。
- 结果文件 Status: PASS 需含：改动文件清单、测试计数、双构建结果、冻结树 mtime 核验、写范围外失败报告（如有）。

## 验收（Reviewer 独立核验）

- 四方向打字机语义正确（行末/行首/列底/列顶环绕 + 页端跨页 + 全局边界 nil）。
- 跨页目标 = 页首/页末有效 slot（非 row-preserving）。
- 全部测试通过（含更新后的既有测试）；双构建 exit 0；冻结树未动。
