# D-2026-08-31-bug6-fix-plan — BUG6 修复波次规划决策（Chief Decision Delta）

- **角色**：Chief（glm-5.3；chef-worker-reviewer-workflow v1.4.1）
- **日期**：2026-08-31
- **上游**：`Workflow/BUG6-FIX-PROMPT.md`（Ops 权威，275 行；file:line 已由 Chief 抽查源码核对一致）、`Workflow/BUG6-REPORT.md`（4 缺陷 + 4 疑点）、`Workflow/MAIN_BRIEF.md`（1E 政策沿用）
- **产出**：`Workflow/PLAN.md` 追加节「Phase 1F BUG6-fix（2026-08-31）」+ 任务包 `T-1F-B6-wave-a/b/c/c2.md`
- **基线**：1012/0（swift test 全量；debug/release exit 0）

---

## 1. 决策总览

| # | 决策 | 波及 |
|---|---|---|
| D1 | ADR-010 M3 修订：createFolder 顶层位置语义 = drop 目标原地 | ADR-010 注记 + LayoutMutation.swift 头注释/实现（Wave B） |
| D2 | off-by-one 修法分岐（方案 i/ii）与并发裁决规则 | Wave A/B 串并关系，Main 记 concurrency_check |
| D3 | Wave C 第一层只堵漏；每条提前 return 标注 endSession 需求 | Wave C 自查清单 |
| D4 | C 第二层 BLOCKED-on-frozen-tree；解冻前置评估条件 | Wave C2 状态 |
| D5 | sessionLayout generation 恒零 = 观察项，排除在三波之外 | PLAN F5.3 |
| D6 | 净删代码为硬约束；Worker 发现自己加状态/分支/字段必须停下报 Main | 全部波次包 §0 |

---

## 2. D1 — ADR-010 M3 修订（createFolder 顶层位置语义）

**旧语义（废弃）**：ADR-010 §Q4 M3 行「folder 占确定顶层位（ADR-009：创建位置 = 两 app 原位置区间内，失败回退顶层尾部）」；ADR-010 文末「T-1F-A 实现注记」之「folder 顶层位 = 两 app 原位置区间内（min 原 index）」；`LayoutMutation.swift:14-15` 头注释「新 folder 落在两原位置区间内（min 原 index）」；`LayoutMutation.swift:91` doc 注释「两 app 原位置区间内（min 原 index，失败兜底尾部由 clamp 保证）」。

**新语义**：新 folder 落在 **drop 目标（target）的原顶层位**。A 是「被拖走的」，B 是「留在原地被拖到的」，用户对「folder 出现在被拖到的 B 位置」有直接期望（BUG6-REPORT §1 逐字报告）。

**下标移位陷阱（must-embed to Wave B）**：`createFolder` 现实现先 `remove(at: second)` 再 `remove(at: first)` 再回填，两删之间 target 的原下标已失效。规定算法顺序：**先算后删再 clamp** —— 从 `targetIndex` 与 `sourceIndex` 的相对关系直接得到移除两项后 folder 应落的下标（source 在 target 前 → `targetIndex - 1`；否则 → `targetIndex`），再 `min(..., ordered.count)` 兜底。禁用「先删 source 再查 target 下标」这类依赖中间态的写法。

**文档同步（合并时执行）**：
- `LayoutMutation.swift` 文件头语义速查行（:14-15）与 `createFolder` doc 注释（:91）由 Wave B 同波修改 —— **注释与实现不一致 = Reviewer FAIL**（该文件 :1-23 语义速查块是契约声明）。
- ADR-010 §Q4 M3 行与「T-1F-A 实现注记」段的修订文本 = 本节新语义；按 MAIN_BRIEF 惯例（ADR Chief draft → Main transcribes）由 **Main 在 Wave B 合并时誊写入 ADR-010**（Chief 已在本文记录权威文本，不直接改 Accepted ADR）。ADR-009 generation 不变量（10 不变量、generation 单调、与 CatalogRevision 分离）不受本次修订影响。

## 3. D2 — off-by-one 方案 i/ii 与并发规则

根因（已固化，Worker 不重诊断）：`.insertion(index:)` 载荷与 `reorderTopLevel`（:77-81 remove-then-insert）不匹配 —— 源在目标前时，移除源使目标左移一位，「插到 B 之后」算出的下标多走一格（`[A,B,C]` A→B右 ⇒ `[B,C,A]`，期望 `[B,A,C]`）。此 bug 目前被全宽 center zone 挡住，Wave A 修完缺陷 3 后必然暴露 → 必须**与缺陷 3+4 同波修**。

- **方案 i（建议）**：`DragMutationEngine` `.insertion` 分支换算（源在目标前 → `index-1`）。只动一处，Wave B 不受影响 → Main 记 `concurrency_check`（6 问）后可裁定 A∥B。
- **方案 ii**：`.insertion` 载荷语义化（before-entry/尾插）。波及 enum、分类器、引擎、视觉、全部相关测试，且与 Wave B 测试预期重叠 → **强制 A→B 串行**。
- 升级条件：Worker 若发现 `reorderFolderMembers`(:230-236) 与 `moveOutOfFolder`(:210) 对同一换算需要相反方向，则方案 ii 更省，直接切换并报 Chief（Decision Delta 增补）。
- Worker 选定后**必须**在结果文件声明方案与理由并报 Main；Main 的并发裁决必须记 `concurrency_check` 事件。

## 4. D3 — Wave C 第一层边界（堵漏，不重设计）

三个落点（顺序敏感）：
1. `pointerUp` clickFallbackCell 分支（:190-199）：**先 `endSession()` 再 `onCellClick(fallback)`** —— onCellClick 链可重入 `cancel(.catalogRefresh)`，须先清干净再派发。
2. `pointerDragged` fallback 清除分支（:153-161）：过阈值清除后同样 `endSession()`。
3. `pointerDown`（:125-135）：`sourceCell` 在 :124 已赋值、controller 返回 `.cancelled(.secondDrag)` 且无 `.pressed` 的路径，排查其抑制状态残留并一并堵。

**自查清单（强制性）**：把 `pointerUp` / `pointerDragged` / `pointerDown` 每一个提前 `return` 逐条列出，标注「需要 / 不需要 `endSession()`」及理由，写入结果文件。两条防错注记（Chief 计划级约束，防过度修复）：
- 会话建立**之前**就 return 的路径（`isTornDown` / `dragGate()` false / 无 host）不需要 `endSession()`——此时无会话，盲目调用可能误清上一轮仲裁状态。
- surface 级抑制在「第二个 drag」仲裁（pointerDown :112-115 注释）被设计为保持到整个仲裁结束；`.cancelled(.secondDrag)` 保持仲裁是**既有设计**，不得顺手改成结束会话——只修「fallback/click 派发后残留」，不改仲裁语义。

## 5. D4 — C 第二层解冻条件（BLOCKED）

写范围涉及冻结文件 `Sources/PagingPrototypeApp/AppLaunchController.swift`（`install()` :93-98 挂 surface 级 `NSClickGestureRecognizer`；该 recognizer 与 `AppGridCellView.mouseDown`→coordinator→`.pressed→.clicked` 判据是**同一件事的两条通路**，抑制状态机正是为两条通路互斥而存在）。

**解冻流程（唯一路径）**：
1. Worker 先评估 **AppDelegate 侧不调用 `install()`** 能否等效（核实调用方——`AppCatalogAssembly.swift` / AppDelegate 装配链；确认测试入口 `handleClick(at:)` 保留、仅删 recognizer 挂载即可达成单通路）。
2. 可行 → 不解冻，C2 缩窄为 `AppDelegate.swift` + `AppGridCellView.swift`（删 `folderClickRecognizer` :43/:94-96）+ coordinator 抑制状态机全套自删，正常走任务包。
3. 不可行 → Worker 报 Main，Main 向用户/Chief 申请解冻 `AppLaunchController.swift`；**任何情形 Worker 不得自行改冻结文件**。
4. 实施前置：全量测试确认无测试依赖 recognizer 存在；有则改测试直接调 `handleClick(at:)`。

C2 拆包为独立任务 `T-1F-B6-wave-c2.md`，Status: blocked，不进入本次三波可执行范围；第一层验收通过 + 用户实机确认四缺陷消失后由 Chief 决定派发时机。

## 6. D5 — sessionLayout generation 恒零（观察项，本波不修）

`AppDelegate.swift:539-547` layoutProvider 一旦 sessionLayout 非 nil 永远返回它；`onCommit`(:561) 仅 commit 时更新；`makeSessionLayout` 恒产出 `generation: .zero`（DragUISessionCoordinator.swift:444）而 `applyCommittedLayout` 走递增 folder generation（AppGridUIPageContentProvider.swift:259）。这是「为什么会走到 fallback 路径」的**上游成因**；第一层修完 fallback 不再泄漏状态，但 fallback 本身仍在。**三波均不修**（牵扯 generation 语义，影响面大）；触发条件：用户复测报「**第二次拖拽行为异常**」→ 直接指向此项（指针写入 PLAN F5），再由 Chief 评估单独任务。

## 7. 红线重申（对全部波次）

- 禁读：`LaunchBetter` / `BuhoReverseNotes` / `2026-08-25-buho-launchpad-reverse`；行为规格以 BUG6-REPORT §1 用户原话 + FIX-PROMPT §2.1/§2.3 提炼的行为层结论为准（clean-room 链条）。
- 冻结树不改；`DragParameters` 禁新增参数（中心区大小用现有 `dropZoneMarginsPT`(=8pt) 内缩表达，需新参数必须报 Main→Chief 走 PARAMETER_RATIONALE 登记纪律）。
- 无 git 操作；测试必须真实执行（`exit 0` + `executed_tests == 0` = `INVALID_TEST_EXECUTION`）；夹具中性 A/B/C；隐私红线照 MAIN_BRIEF/PLAN §10。
- Worker 不重新诊断根因——根因以 FIX-PROMPT §1 为准，已逐条固化进各任务包 §1。