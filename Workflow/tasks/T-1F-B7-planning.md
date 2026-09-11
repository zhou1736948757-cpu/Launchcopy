# T-1F-B7-planning — BUG7 三波修复规划（Chief）

- Status: ready
- Wave: 0（规划，无依赖）
- Role: Chief（glm-5.3；持久会话 e49900a4）
- 上游：`Workflow/BUG7-REPORT.md`（用户实机复测报告）+ `Workflow/BUG7-FIX-PLAN.md`（用户/Ops 已写方案，Main 已逐条核验通过）
- 产出物：三个 Wave 任务包 + 决策文件 + PLAN.md 追加节（见 §3）
- 基线：1026 tests / 0 failures；debug/release exit 0

## §1 背景（Main 已核验，Chief 不重新诊断）

用户实机复测三波 BUG6 修复合并后的构建（窗口模式，基线 1026/0），报 3 缺陷；用户已澄清缺陷 3 范围（folder 内成员启动正常，只限建夹后主界面顶层 app 点击）。Main 已逐条手算核验 BUG7-FIX-PLAN.md 的全部公式与验收表，结论：方案成立。三缺陷根因已在 BUG7-REPORT.md 定位（缺陷 1 公式左偏一格；缺陷 2 页内/全局下标映射缺失；缺陷 3 顶层 live-token 启动路径静默拒绝，候选，须先取证）。

## §2 要求的输出（Chief 写盘）

1. `Workflow/tasks/T-1F-B7-wave-a`.md — Wave A′：缺陷 1 建夹落点
   - 公式（已定案，不改）：`LayoutMutation.createFolder` 落点 `insertion = targetIndex`（source 在 target 前**不做** −1）；仍先删 max 再删 min 再 `min(insertion, ordered.count)` clamp；成员序 `[target, source]` 不变
   - 验收表（Main 已手算确认）：`[A,B,C]` A→B ⇒ `[C,F]`（folder 在 B 原格 index 1）；`[B,A,C]` A→B ⇒ `[F,C]`；`[A,X,B,C]` A→B ⇒ `[X,C,F]`
   - 重写 `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift`（左方向 `[C,F]`、右方向 `[F,C]`、非相邻 `[X,C,F]`；成员序 `[B,A]` 锁；拒绝路径不回归）
   - 写范围：`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift`（仅 createFolder 落点行 + 头注释/doc 同步）+ 上述测试文件。**ADR-010 誊写由 Main 合并时做，Worker/Chief 不碰** `Docs/`
   - §4 禁写：冻结树、AppDelegate、DragSession/、DragParameters.swift、Docs/、PROVENANCE/
   - 注释与实现不一致 = FAIL（Wave B 教训）
2. `Workflow/tasks/T-1F-B7-wave-b`.md — Wave B′：缺陷 2 页内→全局下标映射
   - 公式（已定案）：顶层 scope intent 产出处换算 `globalIndex = page * itemsPerPage + localIndex`；folder scope 不做外层乘（回归锁：folder 内 insertion 不得乘外层 itemsPerPage）
   - 实现边界：`DragGeometry` 增加 `itemsPerPage`（AppDelegate.makeDragGeometry 从 `surface.itemsPerPage` 传入）；换算在 intent 产出边界（`DropZoneClassifier`/`insertionIntent` 或其输入带上 page+itemsPerPage），**禁止**在 engine/resolver 二次换算（`reorderAdjustedIndex` 只负责 remove-then-insert 差一，与页偏移无关，不得混改）
   - 必补测试：page 1 页内 k → 全局 35+k；末页最右列左半=该全局槽之前；满页插最后之后=全局末尾/下一页首位；folder 内不乘外层（回归锁）
   - 写范围：`Sources/AppGridUI/DragSession/DragGeometry.swift`、`DropIntent.swift`（或其分类输入）、`Sources/PagingPrototypeApp/AppDelegate.swift` 仅 `makeDragGeometry`、新建 Tests/AppGridUITests/ page≥1 夹具（新文件，勿只改 page 0 旧测试）
   - 次因（edge zone 40pt 与末列重叠）只评估+记录，不单独开波；不改 edge zone 参数
3. `Workflow/tasks/T-1F-B7-wave-c`.md — Wave C′：缺陷 3 建夹后顶层点击（Status: blocked，串在 B′ 后）
   - 第一层取证（强制）：`handleDragCellClick` 读 `launchController.lastOutcome`（及是否进入该函数），六态处置表（写进任务包）：rejectedStaleRevision/MissingApp/NoBinding → 顶层改走 `launchMember(appID)`（或抽 `launchApp(appID)` 共用，身份仍从 `cell.bindingToken?.appID as? AppID` 读）；nil → 点击没到 handleCell，查 pointerUp .clicked/fallback/idle + sourcePresent，查证后再修；launched/failedToLaunch → 不在本波
   - 结构性修法（取证后）：顶层与成员共用合成 cell + 当前 servedRevision 路径，不信任重建后 live token 做启动校验；**不改** `AppLaunchController.swift`（冻结；handleCell 校验链保持）
   - 顺手收口：QuitOnBlankClickWindow.sendEvent 收窄为"仅空白 + session active"才 cancel；删 `DBG pointerDown` 打印（T-1F-B-tests-actor-fu-1）
   - 写范围：AppDelegate.swift（handleDragCellClick/空白吞事件）、DragUISessionCoordinator.swift（DBG 清理/中性观察）、对应测试（建夹 commit 后顶层单击→启动管线被调，可用 fake launcher；folder 成员启动不回归）
   - 取证结论必须写进结果文件后才实施结构性修改
4. `Workflow/decisions/D-2026-09-01-bug7-fix-plan.md` — 记录裁决：格子位置语义（非相对锚点）；insertion=targetIndex；页偏移公式；C′ 取证门槛
5. `Workflow/PLAN.md` 追加「Phase 1F BUG7-fix（2026-09-01）」节（DAG/写范围/缺陷→验收映射）

## §3 任务包格式要求（沿用 v1.4.1）

`# <task-id> — 波次名`；Status: ready|blocked / Wave / Role / §1 Root cause (verified, 带行号) / §2 Fix spec（含验证优先 mandates）/ §3 Write scope / §4 Forbidden writes（冻结树全列）/ §5 Required reading (minimal ≤4 文件带行号) / §6 Verification（swift build -c debug exit 0；swift test 全量 1026 基线+新测试；swift build -c release exit 0）/ §7 Acceptance（缺陷映射）/ §8 Output discipline（results 先写 in-progress；回复<250 词；隐私中性 A/B/C）。所有 file:line 引用对照源码核实，Chief 不二次诊断根因、不读禁止来源、不改产品/测试/冻结代码。

## §4 红线

禁读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse；privacy A/B/C 代称；无 git；Worker 声明 AccessDeclaration。