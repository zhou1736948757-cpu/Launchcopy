# T-1E-nav-typewriter-inner-repair（Task B：文件夹内 ↓/↑ 打字机环绕）— Worker 结果

Status: **PASS**

## 任务

`Sources/AppGridUI/FolderKeyboardLogic.swift` `FolderInnerNavigator.move` 的 ↓/↑ 从 clamp（nil）改为打字机环绕：
列底 → 下一列第一个（同页）；末列底 → 下一页首格（crossedPage: true）；末页 → nil。
列顶 → 上一列最后一个（同页）；首列顶 → 上一页末格（crossedPage: true）；首页 → nil。
←/→ 不变。文件头策略注释同步更新。守卫（memberCount/currentIndex 合法性）与 ←/→ 分支未动。

## 实现说明（规格公式勘误）

规格 :31-32 公式 `pageStart + col + 1 < pageEnd` 单独使用在**满页末列**时错误：
35 成员 5 列满页，末列底 slot 34 → `pageStart + 5 = 5 < 35` 为真 → 会错误 Move(5, false)（第 0 列第 2 行），
而语义要求 末列底 → 下一页首格 Move(35, true)。实现按规格语义条款（:14-15，契约）补上
`col + 1 < columns` 条件：列底且存在下一列且下一列首格在本页 → Move(pageStart + col + 1, false)；
否则（末列底）→ `pageEnd < memberCount` → Move(pageEnd, true)；否则 nil。
↑ 的"上一列最后一个"用页内最大 slot s（`pageStart <= s < pageEnd` 且 `s % columns == col - 1`）
遍历求得；退化页（无上一列槽位）回退到首列顶分支（上一页末格 / nil）。消费者
`KeyboardFocusController.handleInnerArrow` 已按 crossedPage 通用处理（onInnerPageChange），无需改动。

## 改动文件

- `Sources/AppGridUI/FolderKeyboardLogic.swift`：↓/↑ 打字机环绕（:78-107）+ 头注释（:24-28）
- `Tests/AppGridUITests/FolderKeyboardLogicTests.swift`：
  - `testInnerDownNoMoveWhenRowAbsent` → `testInnerDownWrapsAtColumnBottom`（列底→下一列第一个；末列底→下一页首格 crossedPage: true；末页→nil）
  - `testInnerUpNoMoveAtTopRow` → `testInnerUpWrapsAtColumnTop`（列顶→上一列最后一个；首列顶→上一页末格 crossedPage: true；首页→nil）
  - 新增 `testInnerPartialPageColumnWrap`（8 成员 5 列部分页列底/列顶环绕）
  - 新增 `testInnerDownUpCrossPageKeepsFocusPageConsistent`（跨页后 memberIndex/membersPerPage 与 crossedPage 一致）
- `Tests/PagingUITests/FolderIntegrationTests.swift`：**核验后无需改动**——`testNavigatorToFolderSlotReturnOpensFolder`（:637）、`testNavigatorToAppSlotIdentityIsActualApp`（:669）等导航序列测试只用外层 ↓/↑ 播种 + ←/→ 移动，不触内层导航器；新语义下全部通过。

## 验证

| 步骤 | 结果 |
|---|---|
| `swift build -c debug` | exit 0（Build complete） |
| `swift test` | **Executed 789 tests, with 0 failures**（基线 787 + 新增 2；Test Suite 'All tests' passed） |
| `swift build -c release` | exit 0（Build complete） |
| 冻结树 mtime | 前后一致（见下表） |

## 冻结树 mtime 核验（修改前 → 修改后，全部一致）

| 路径 | mtime（前/后） |
|---|---|
| Package.swift | 1787917375 / 1787917375 |
| Sources/AppCatalogCore | 1787917822 / 1787917822 |
| Sources/MacAppCatalog | 1787918515 / 1787918515 |
| Sources/PagingTelemetry | 1787918942 / 1787918942 |
| Sources/PagingPrototypeApp/AppLaunchController.swift | 1787921214 / 1787921214 |
| Sources/AppIconPipeline | 1787930560 / 1787930560 |
| Sources/PagingCore | 1788057962 / 1788057962 |
| Sources/PagingUI | 1788070530 / 1788070530 |
| Sources/AppGridUI/AppGridFocusNavigator.swift | 1788094451 / 1788094451 |
| Tests/PagingUITests/KeyboardLaunchTests.swift | 1788094729 / 1788094729 |

## 写范围外失败

无。全量 789 测试 0 失败，无写范围外失败需报告。
