# T-1E-nav-typewriter-inner-repair（Task B：文件夹内 ↓/↑ 打字机环绕）

Status: OPEN（Task A 合并后启动）
Phase: 1E
Depends on: T-1E-nav-typewriter-outer-repair（Task A，顺序执行；写范围互斥）
Created: 2025-08-30（Main，用户设计请求）

## 用户请求（逐字）

"我想了一下，往下按的话应该跟往右按一样。……我在第一列当中往下按到底了，再按一下下的话，应该到下一列的第一个，对吧？然后这个逻辑的话，我觉得是在这个就是主页面和这个APP这Folder里面的页面应该都是这样的。"

## 需求语义（文件夹内 ↓/↑ 打字机环绕；←/→ 已符合，不变）

- **↓**：列内下移；列底 → 下一列第一个（同页）；末列底 → 下一页首格（crossedPage: true）；末页 → nil。
- **↑**：列内上移；列顶 → 上一列最后一个（同页）；首列顶 → 上一页末格（crossedPage: true）；首页 → nil。
- **←/→**：保持现状（已是打字机式：行内移动；行末 → 下一行第一个；页末 → 下一页首格；行首 → 上一行最后一个；页首 → 上一页末格；全局边界 nil）。
- 全局边界不环绕（末页最右/最下、首页最左/最上 → nil）。

## 当前行为（证据）

`Sources/AppGridUI/FolderKeyboardLogic.swift` `FolderInnerNavigator.move`（:51-90，已读）：
- :77-82 ↓：`next = currentIndex + columns`；`next < pageEnd` → Move(next, false)；否则 → **nil（clamp）**。
- :83-88 ↑：`prev = currentIndex - columns`；`prev >= pageStart` → Move(prev, false)；否则 → **nil（clamp）**。
- :60-76 ←/→：已是打字机式（行内 slot±1；行末 → 下一页首格；行首 → 上一页末格）——**不变**。
- 文件头 :24-27 注释文档化旧策略（需同步更新）。

## 修复规格（Task B：文件夹内导航器）

`Sources/AppGridUI/FolderKeyboardLogic.swift` `FolderInnerNavigator.move`：

- **↓**：`next = currentIndex + columns`；`next < pageEnd` → Move(next, false)。否则（列底）：
  - `col = slot % columns`；`pageStart + col + 1 < pageEnd` → Move(pageStart + col + 1, false)（下一列第一个，同页）；
  - 否则（末列底）→ `pageEnd < memberCount` → Move(pageEnd, true)（下一页首格）；否则 nil。
- **↑**：`prev = currentIndex - columns`；`prev >= pageStart` → Move(prev, false)。否则（列顶）：
  - `col = slot % columns`；`col > 0` → 上一列最后一个 = 页内最大 slot s（`pageStart <= s < pageEnd` 且 `s % columns == col - 1`）→ Move(s, false)；
  - 否则（首列顶）→ `page > 0` → Move(prevPageEnd - 1, true)（上一页末格）；否则 nil。
- 守卫（:52 memberCount/currentIndex 合法性）与 ←/→ 分支**不变**。
- 文件头 :24-27 策略注释更新为打字机语义。
- 实现方式 Worker 自定（公式或遍历），语义必须与规格一致。

## 测试更新（Tests/AppGridUITests/ + Tests/PagingUITests/）

- `FolderKeyboardLogicTests.swift`：
  - `testInnerDownNoMoveWhenRowAbsent`（:98）→ 改为列底环绕断言（列底 → 下一列第一个；末列底 → 下一页首格 crossedPage: true；末页 → nil）。
  - `testInnerUpNoMoveAtTopRow`（:110）→ 改为列顶环绕断言（列顶 → 上一列最后一个；首列顶 → 上一页末格 crossedPage: true；首页 → nil）。
  - 新增：部分页（如 8 成员 5 列）列底/列顶环绕；跨页后焦点/页一致（`move.memberIndex / membersPerPage` 与 crossedPage 一致）。
  - ←/→ 测试（:55-90）保持通过（行为不变）。
- `FolderIntegrationTests.swift`：核验导航序列测试（`testNavigatorToFolderSlotReturnOpensFolder` :637、`testNavigatorToAppSlotIdentityIsActualApp` :669 等）在新语义下仍通过；若序列落点变化，按新语义最小调整（断言语义不变）。Bug 1 相关（文件夹内 ↓ 到底）行为由环绕取代 clamp——若存在断言 clamp 的测试，更新为环绕断言。
- 若全量测试出现**写范围外**的失败，**不要修改**——在结果文件如实报告。

## 写范围

- `Sources/AppGridUI/FolderKeyboardLogic.swift`
- `Tests/AppGridUITests/FolderKeyboardLogicTests.swift`
- `Tests/PagingUITests/FolderIntegrationTests.swift`

## 禁止（绝不修改）

- 冻结树：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、
  `Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、
  `Sources/PagingPrototypeApp/AppLaunchController.swift`
- `Sources/AppGridUI/AppGridFocusNavigator.swift`（Task A 已合并）、`Sources/PagingPrototypeApp/`（除
  FolderIntegrationTests）、`Sources/AppGridUI/FolderDomain.swift`、
  `Sources/AppGridUI/AppGridUIPageContentProvider.swift`、`Sources/AppGridUI/AppGridFocusModel.swift`
- 无 git 操作（仓库无 commit）

## 验证

- `swift build -c debug` exit 0
- `swift test`：XCTest "Executed N tests" N > 0 且 0 failures（基线 = Task A 合并后计数）
- `swift build -c release` exit 0
- 冻结树 mtime 不变（记录修改前后）

## 输出纪律（Worker 必读）

- **先写** `Workflow/results/T-1E-nav-typewriter-inner-repair.md`（"in progress"）再实现。
- 最终回复 < 250 词，无大代码块。
- 结果文件 Status: PASS 需含：改动文件清单、测试计数、双构建结果、冻结树 mtime 核验、写范围外失败报告（如有）。

## 验收（Reviewer 独立核验）

- ↓/↑ 打字机语义正确（列底/列顶环绕 + 页端跨页 crossedPage: true + 全局边界 nil）；←/→ 未变。
- 跨页后焦点/页一致（memberIndex / membersPerPage 与 crossedPage 一致）。
- 全部测试通过；双构建 exit 0；冻结树未动。
