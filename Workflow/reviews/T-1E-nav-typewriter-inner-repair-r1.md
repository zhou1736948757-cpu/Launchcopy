# T-1E-nav-typewriter-inner-repair（Task B：文件夹内 ↓/↑ 打字机环绕）— Reviewer r1

Verdict: **PASS**

Reviewed: 2026-08-30（独立 Reviewer，只读；未修改任何文件）
Review basis: `Workflow/tasks/T-1E-nav-typewriter-inner-repair.md`（原始任务包）、
`Workflow/results/T-1E-nav-typewriter-inner-repair.md`（Worker 结果）、
`Sources/AppGridUI/FolderKeyboardLogic.swift`、`Tests/AppGridUITests/FolderKeyboardLogicTests.swift`、
`Tests/PagingUITests/FolderIntegrationTests.swift`、`Sources/PagingPrototypeApp/KeyboardFocusController.swift`。

## 1. 语义契约实现（FolderInnerNavigator.move，FolderKeyboardLogic.swift）

- **↓（:78-89）**：`next = currentIndex + columns`；`next < pageEnd` → `Move(next, false)`（:79-82）。
  列底分支（:84-87）：`col = slot % columns`；`col + 1 < columns && pageStart + col + 1 < pageEnd`
  → `Move(pageStart + col + 1, false)`（下一列第一个，同页）；否则 `pageEnd < memberCount`
  → `Move(pageEnd, true)`（下一页首格，crossedPage: true）；否则 nil（:88-89）。✓
- **↑（:90-108）**：`prev = currentIndex - columns`；`prev >= pageStart` → `Move(prev, false)`（:91-94）。
  列顶分支（:96-104）：`col > 0` → 遍历求页内最大 slot s（`pageStart <= s < pageEnd && s % columns == col - 1`）
  → `Move(s, false)`（上一列最后一个，同页）；否则 `page > 0` → `Move(prevPageEnd - 1, true)`
  （上一页末格，crossedPage: true）；否则 nil（:105-108）。✓
- **←/→（:60-77）**：与任务包证据描述的原行为逐行一致（行内 slot±1；行末 → 下一页首格；行首 → 上一页末格；
  全局边界 nil）——未变。✓
- **守卫（:53）**：`memberCount > 0, currentIndex >= 0, currentIndex < memberCount` 存在且正确；`testInnerInvalidIndexReturnsNil` 通过。✓
- **头注释（:24-28）**：已更新为打字机语义（↓/↑ 列底/列顶环绕 + 跨页 + 全局边界 nil）。✓

## 2. 偏差核验（关键焦点）——必要且正确

任务包 :31-32 字面公式 `pageStart + col + 1 < pageEnd` 在**满页末列**确实误触发：
- 满页（membersPerPage 35、columns 5、memberCount 70），slot 34（第 0 页末列底）：
  字面公式 `0 + 4 + 1 = 5 < 35` 为真 → 错误 `Move(5, false)`（第 0 列第 2 行，同页）。
- Worker 实现加 `col + 1 < columns` 守卫：`5 < 5` 为假 → 跳过同页分支 → `35 < 70` → `Move(35, true)`
  （第 1 页首格，crossedPage: true）。**正确**，与语义条款（任务包 :14-15）一致。

偏差已如实记录于 Worker 结果 :12-21，且实现与语义契约（权威条款）一致——判定为必要且正确的勘误。

## 3. 手工追踪（全部通过）

**满页（70 成员 / 35 每页 / 5 列）**：
- ↓ slot 34（末列底）→ `Move(35, true)`（第 1 页首格，非 slot 5）✓
- ↓ slot 30（第 0 列底）→ `Move(1, false)`（第 1 列第一个）✓
- ↓ slot 39（末页末列底）→ nil ✓
- ↑ slot 1（第 1 列顶）→ 遍历 s=34→30（30%5==0）→ `Move(30, false)`（第 0 列最后一个）✓
- ↑ slot 0（首页首列顶）→ nil ✓
- ↑ slot 35（第 1 页首列顶）→ `Move(34, true)`（上一页末格）✓

**部分页（8 成员 / 5 列，单页）**：
- ↓ slot 5（第 0 列底）→ `Move(1, false)`；↓ slot 7（第 2 列底）→ `Move(3, false)`；↓ slot 4（末列底）→ nil ✓
- ↑ slot 1（第 1 列顶）→ `Move(5, false)`；↑ slot 3（第 3 列顶）→ `Move(7, false)`；↑ slot 0 → nil ✓

**边界**：首页 ↑ → nil（:105 `page > 0` 守卫）；末页 ↓ → nil（:88 `pageEnd < memberCount` 守卫）✓

**跨页焦点/页一致**：↓ 跨页 `Move(pageEnd, true)` → `memberIndex / membersPerPage = page+1`、`% = 0`（新页首格）；
↑ 跨页 `Move(prevPageEnd - 1, true)` → 新页末格。消费者 `KeyboardFocusController.handleInnerArrow`
（:336-341）按 `crossedPage` 通用处理（`onInnerPageChange?(move.memberIndex / membersPerPage)`），无需改动 ✓

## 4. 测试核验

- `FolderKeyboardLogicTests.swift`：
  - `testInnerDownNoMoveWhenRowAbsent` → `testInnerDownWrapsAtColumnBottom`（:98-108）：列底 → 下一列第一个；
    末列底 → 下一页首格 crossedPage: true；末页 → nil ✓
  - `testInnerUpNoMoveAtTopRow` → `testInnerUpWrapsAtColumnTop`（:116-126）：列顶 → 上一列最后一个；
    首列顶 → 上一页末格 crossedPage: true；首页 → nil ✓
  - 新增 `testInnerPartialPageColumnWrap`（:128-145）：8 成员 5 列部分页列底/列顶环绕 ✓
  - 新增 `testInnerDownUpCrossPageKeepsFocusPageConsistent`（:147-156）：跨页后 memberIndex/membersPerPage
    与 crossedPage 一致 ✓
  - ←/→ 测试（:55-90）未变且通过 ✓
- `FolderIntegrationTests.swift`：**未改动**（mtime 1788092425，早于 Task A 合并时间 1788094451）。
  核验 `testNavigatorToFolderSlotReturnOpensFolder`（:637）、`testNavigatorToAppSlotIdentityIsActualApp`
  （:669）等导航序列测试：全部箭头仅用外层导航器（downArrow 播种 + rightArrow 移动，:649/655/680-682），
  不触内层导航器——新语义下不受影响 ✓

## 5. 验证命令（串行执行，全部通过）

| 步骤 | 结果 |
|---|---|
| `swift build -c debug` | exit 0（Build complete） |
| `swift test` | **Executed 789 tests, with 0 failures**（Test Suite 'All tests' passed；基线 787 + 新增 2） |
| `swift build -c release` | exit 0（Build complete） |

## 6. 冻结树核验（mtime 与 Worker 记录的前/后值逐一比对，全部一致）

Package.swift 1787917375、Sources/PagingCore 1788057962、Sources/AppCatalogCore 1787917822、
Sources/MacAppCatalog 1787918515、Sources/AppIconPipeline 1787930560、Sources/PagingTelemetry 1787918942、
Sources/PagingUI 1788070530、Sources/PagingPrototypeApp/AppLaunchController.swift 1787921214、
Sources/AppGridUI/AppGridFocusNavigator.swift 1788094451、Tests/PagingUITests/KeyboardLaunchTests.swift 1788094729。
另核验：Sources/AppGridUI/FolderDomain.swift 1788073923、AppGridUIPageContentProvider.swift 1788074905、
AppGridFocusModel.swift 1788010500、Sources/PagingPrototypeApp/KeyboardFocusController.swift 1788092409 —— 均未动。
全仓扫描：Task B 期间仅 `FolderKeyboardLogic.swift`（1788095033）与 `FolderKeyboardLogicTests.swift`
（1788095041）两个写范围内文件被修改。✓

## 7. 写范围外失败

无。全量 789 测试 0 失败。

## 8. 备注

- **MINOR（信息性，非缺陷）**：↑ 的"上一列最后一个"遍历（:99-100）的 `if s >= pageStart` 回退分支实际不可达
  （`col = slot % columns < pageSlots` 恒成立 → 列 col-1 在页内必有槽位，循环必找到 s）。防御性代码，
  行为正确，无需修改。
- **MINOR（信息性）**：仓库无 git 历史（全部文件 untracked），无法做 diff 级比对；本审核基于当前文件状态 +
  mtime 证据 + 任务包内嵌的"当前行为"证据（:19-25）交叉核验，←/→ 与守卫"未变"的结论依据充分。

## 结论

所有验收标准满足：↓/↑ 打字机语义正确（列底/列顶环绕 + 页端跨页 crossedPage: true + 全局边界 nil）；
←/→ 未变；跨页焦点/页一致；789 测试 0 失败；双构建 exit 0；冻结树未动。偏差（`col + 1 < columns` 守卫）
经手工追踪验证为必要且正确。**Verdict: PASS**。
