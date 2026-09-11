# T-1E-nav-typewriter-outer-repair — Worker Result

- Status: PASS
- Task: Task A — 外层导航器打字机环绕（AppGridFocusNavigator 四方向 typewriter wrap + 跨页目标 = 页首/页末有效 slot）
- Packet: `Workflow/tasks/T-1E-nav-typewriter-outer-repair.md`

## Plan

1. `Sources/AppGridUI/AppGridFocusNavigator.swift` — `move(_:direction:in:)` 四方向打字机语义：
   - →：行内右移 → 下一行第一个（同页）→ 下一页首格（`crossPageRight` 改为 `slots.first`）→ 末页 nil。
   - ←：行内左移 → 上一行最后一个（同页）→ 上一页末格（`crossPageLeft` 改为 `slots.last`）→ 首页 nil。
   - ↓：列内下移 → 下一列第一个（同页）→ 下一页首格 → 末页 nil。
   - ↑：列内上移 → 上一列最后一个（同页）→ 上一页末格 → 首页 nil。
   - 守卫（validEntry == entryIdentity）与 `makeIdentity` 不变；文件头 :5-8 策略注释更新。
2. `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift` — 更新旧断言 + 新增部分末页列环绕测试。
3. `Tests/AppGridUITests/AppGridFocusCompositionTests.swift` — 核验（仅 mid-grid 移动，无需改动）。
4. `Tests/PagingUITests/KeyboardFocusControllerTests.swift` — 跨页触发序列改为"走到页末再跨页"。
5. 验证：`swift build -c debug` exit 0；`swift test`；`swift build -c release` exit 0；冻结树 mtime 前后核验。

## Write scope

- Sources/AppGridUI/AppGridFocusNavigator.swift
- Tests/AppGridUITests/AppGridFocusNavigatorTests.swift
- Tests/AppGridUITests/AppGridFocusCompositionTests.swift
- Tests/PagingUITests/KeyboardFocusControllerTests.swift

## Forbidden (untouched)

- 冻结树：PagingCore / AppCatalogCore / MacAppCatalog / AppIconPipeline / PagingTelemetry / PagingUI / Package.swift / AppLaunchController.swift。
- FolderKeyboardLogic.swift（Task B）、FolderDomain.swift、AppGridUIPageContentProvider.swift、AppGridFocusModel.swift、Sources/PagingPrototypeApp/。
- 无 git 操作。

## What changed

1. `Sources/AppGridUI/AppGridFocusNavigator.swift`（94 → 110 行）：
   - 文件头 :5-10 策略注释更新为打字机语义（→/←/↓/↑ 四方向 + 全局边界不环绕）。
   - `move` 四方向均改为两段式：行/列内移动 → 行末/列底（行首/列顶）环绕到下一行/列第一个（上一行/列最后一个，同页）→ 跨页。
   - `crossPageRight(layout, from:)`：row-preserving → 下一页 `validSlots.first`（页首格）。
   - `crossPageLeft(layout, from:)`：row-preserving → 上一页 `validSlots.last`（页末格）。
   - 守卫（:35-37 validEntry == entryIdentity）与 `makeIdentity`（:89-93）不变。
2. `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift`（182 → 263 行）：
   - `testRightLeftIn5Columns` / `testRightLeftInNon5Columns`：补行末 → 下一行第一个、行首 → 上一行最后一个断言。
   - `testUpDownIn5Columns` / `testUpDownInNon5Columns`：列底 → 下一列第一个（列 1 顶，slot 1）、列顶 → 上一列最后一个。
   - `testIncompleteLastPageNoOutOfBounds`：页 1 slot 0 ↓ → 环绕到页内 slot 1（不再 nil）。
   - `testCrossPageRight` / `testCrossPageLeft`：断言不变（slot 0 / slot 4），注释更新为打字机跨页。
   - `testCrossPageClampWhenNextPageShorter` → 改名 `testCrossPageRightToShorterNextPageLandsOnFirstSlot`：断言 slot 2 → 0（页首格，不再 row-preserving clamp）。
   - `testNoWrapAtGlobalBoundary`：补 ↓/↑ 全局边界 nil 断言。
   - `testRepeatedArrowKeysPredictable`：补页 1 行内右移 → slot 1 步骤。
   - `testRapidSequencePredictable`：按新语义重算序列（右→1，下→2，右→3，右→4，下→页1 slot0，下→页1 slot1）。
   - 新增 `testColumnWrapOnPartialPage`（32 项单页：slot 30 ↓ → slot 1；slot 1 ↑ → slot 30；slot 29 ↓ → nil）。
   - 新增 `testColumnWrapCrossesPage`（32 项 2 页：页 0 slot 19 ↓ → 页 1 slot 0；页 1 slot 0 ↑ → 页 0 slot 19）。
3. `Tests/AppGridUITests/AppGridFocusCompositionTests.swift`：核验后**无需改动**（全部为页内 mid-grid 移动：slot 0→5→0、0→1→0、2→7，不受打字机语义影响）。
4. `Tests/PagingUITests/KeyboardFocusControllerTests.swift`（319 → 320 行）：
   - `testCrossPageFocusVisualLandsOnNewPage` / `testCrossPageSettleReconcilesFocusToCommittedPage` / `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` / `testCrossPageLeftSettlePreservesRowEndLanding`：跨页触发序列由"4× → 到 slot 4"改为"34× → 到页 0 末位 slot 34 再跨页"（打字机下需更多 → 按键）；断言语义（跨页落点/调和）不变；`testCrossPageLeftSettlePreservesRowEndLanding` 落点断言 slot 4 → slot 34（页末格）。

## Verification

- `swift build -c debug`：exit 0（Build complete! 2.83s）。
- `swift test`（两次运行，结果一致）：**Executed 787 tests, with 3 failures**（基线 785 + 新增 2 测试 = 787）。3 个失败全部位于**写范围外**的 `Tests/PagingUITests/KeyboardLaunchTests.swift` 单个测试 `testAccessibilityVisualFocusLaunchObjectConsistency`（3 条断言，见下）。写范围内全部测试通过（含更新后的既有测试 + 2 个新增测试）。
- `swift build -c release`：exit 0（Build complete! 4.52s）。

## Frozen-tree mtime check

修改前后 12 项冻结树 mtime 完全一致（before 记录于本文件 in-progress 版，after 复核）：

```
1787917375 Package.swift
1787917822 Sources/AppCatalogCore
1787918515 Sources/MacAppCatalog
1787918942 Sources/PagingTelemetry
1787921214 Sources/PagingPrototypeApp/AppLaunchController.swift
1787930560 Sources/AppIconPipeline
1788010500 Sources/AppGridUI/AppGridFocusModel.swift
1788057962 Sources/PagingCore
1788070530 Sources/PagingUI
1788073923 Sources/AppGridUI/FolderDomain.swift
1788074905 Sources/AppGridUI/AppGridUIPageContentProvider.swift
1788075778 Sources/AppGridUI/FolderKeyboardLogic.swift
```

## Out-of-scope failure report（写范围外，未修改）

- `Tests/PagingUITests/KeyboardLaunchTests.swift:291` `testAccessibilityVisualFocusLaunchObjectConsistency`（3 条断言失败，:316/:318/:322）：
  - 该测试的导航序列为"4× → 到 page 0 slot 4（行末）→ 再 → 跨页"，在打字机语义下第 5 次 → 落到**同页下一行** slot 5（app05），不再跨页；断言期望跨页到 page 1 首格（app00）→ 失败。
  - 根因：测试序列基于旧 row-preserving 跨页语义，需改为"走到页末（34× →）再跨页"（与 KeyboardFocusControllerTests 同款更新）。
  - 该文件不在本任务写范围（写范围仅 4 个文件），按任务包规则**未修改**，如实报告。建议 Main/Chief 决策：创建后续任务更新 KeyboardLaunchTests 的跨页触发序列（或并入 Task B 范围）。

## Deviations

- 无。实现与任务包修复规格逐条一致（含跨页目标 = 页首/页末有效 slot、守卫与 makeIdentity 不变、文件头注释更新）。

## Reviewer focus

- 四方向打字机语义（行末/行首/列底/列顶环绕 + 页端跨页 + 全局边界 nil）。
- 跨页目标 = 页首/页末有效 slot（非 row-preserving）。
- 写范围内测试全绿；写范围外 KeyboardLaunchTests 单测试失败已如实报告。

## Memory candidates

- 打字机环绕语义下，跨页触发需要"走到页末"（如 35 项/页需 34× →），依赖旧 row-preserving 跨页序列的测试（KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency）需同步更新。
- 列底环绕目标 = 下一列**顶格**（`slots.first(where: { $0 % columns == col + 1 })`），非同行的下一列位置。
