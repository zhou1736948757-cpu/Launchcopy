# D-2026-09-01 — BUG7 修复方案裁决（三波：建夹落点 / 页内→全局下标 / 顶层点击）

- **日期**：2026-09-01；**角色**：Chief
- **上游**：`Workflow/BUG7-REPORT.md`（Main 只读定位）+ `Workflow/BUG7-FIX-PLAN.md`（270 行定案方案，Main 逐条手算核验）+ `Workflow/tasks/T-1F-B7-planning.md`
- **关联**：`D-2026-08-31-bug6-fix-plan.md` D1（其 `targetIndex-1` 换算被本次 D2 推翻）
- **基线**：1026 tests / 0 failures；debug/release exit 0

## D1 格子位置语义（非相对锚点）——教训制度化

- BUG6 Wave B 验收表"索引 1 = B 原位"曾按**相对锚点**自洽裁决；用户实机证明语义必须按**屏幕格子**裁定。本原型无 live reflow（拖动中格子不让位），落点一律按屏幕格子算，"先抽走 A、B 左移一格"的相对补偿**禁止**。
- 规则固化：后续任何验收表内部矛盾，回**用户原话字面**裁定，不得自行合理化（BUG7-REPORT §6.1）。

## D2 createFolder 落点公式（定案，覆盖 BUG6 D1）

- `insertion = targetIndex`（folder 顶替 **B 原格**）；先删 max、再删 min、`min(insertion, ordered.count)` clamp 不变；成员序 `[target, source]` 不变。
- 验收表（格子语义）：`[A,B,C]` A→B ⇒ `[C,F]`；`[B,A,C]` A→B ⇒ `[F,C]`；`[A,X,B,C]` A→B ⇒ `[X,C,F]`。
- 注释三处同波同步（LayoutMutation.swift :14-16 / :92-94 / :120-123）；**ADR-010 M3 文本修订（删 targetIndex-1）由 Main 在 Wave A′ 合并时誊写**，Worker/Chief 不碰 `Docs/`。

## D3 页偏移公式（定案）

- 顶层 scope intent 产出处：`globalIndex = page * itemsPerPage + localIndex`；覆盖 `.insertion`（顶层）与 `.topLevelTarget`（move-out）。
- **禁令（职责不混）**：engine/resolver 不二次换算；`DragMutationEngine.reorderAdjustedIndex`（DragMutationEngine.swift:77-80）只负责 remove-then-insert 差一，与页偏移无关。
- folder scope 不乘外层 `itemsPerPage`（回归锁）；`DragGeometry` 增 `itemsPerPage`，`makeDragGeometry` 传 `surface.itemsPerPage`；folder scope 下 geometry.page = innerPage 陷阱 → `.topLevelTarget` 用顶层 committedPage。
- 次因（edge zone 40pt 与末列右侧重叠）：只评估记录，不改参数、不单独开波。

## D4 C′ 取证门槛 + 统一启动路径

- 强制第一层取证：`handleDragCellClick` 读 `launchController.lastOutcome`，六态处置表（拒绝族 → `launchMember(appID)`/`launchApp(appID)` 共用；nil → 查 pointerUp/sourcePresent；launched/failedToLaunch → 不在本波）。**取证结论写进结果文件后才实施结构性修改。**
- 结构修法：顶层与成员共用合成 cell（`AppCatalogAssembly.makeMemberLaunchCell` + 当前 servedRevision），不信任重建后 live token；`AppLaunchController.swift` 冻结不动（handleCell 校验链保持）。
- 顺手收口：`QuitOnBlankClickWindow.sendEvent` 收窄为"仅空白 + session active"；删 `DBG pointerDown` 打印（DragUISessionCoordinator.swift:105-123）。

## D5 调度与并发

- A′ ∥ B′（写范围不相交）；**C′ Status: blocked，串在 B′ Reviewer PASS 之后**（AppDelegate 共享）。
- `max_worker_concurrency = 3`；每波独立 Reviewer PASS 才合并；事件经 `record_workflow_event.py`（任务包文件先存在）。

## D6 观察项（本三波不修）

- `sessionLayout` generation 恒零：维持 BUG6-FIX-PROMPT §4.3 观察项；除非 C′ 取证证明它是顶层点击失败的直接原因。
- 测试缺口补齐归属：page≥1 drop 零覆盖 → B′ 补；handleCell outcome 断言缺口 → C′ 补（fake launcher）。