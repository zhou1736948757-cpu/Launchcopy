# T-1F-planning — Phase 1F 正式计划 + ADR-009/ADR-010 草案

- **Task**: T-1F-planning（Chief 规划任务；PHASE1F_DRAG_PERSISTENCE_PROMPT §8）
- **状态**: complete（2026-08-31；交付物见下，正文完整）
- **角色**: Chief（glm-5.3）；依据：PHASE1F_DRAG_PERSISTENCE_PROMPT.md §0–§17（权威）、Workflow/PLAN.md（1E）、Workflow/MAIN_BRIEF.md、Workflow/STATE.json、Workflow/config.json、ADR-004/006/007/008、PRIVACY_DATA_MAP.md、PARAMETER_RATIONALE.md、Sources/AppGridUI/FolderDomain.swift、Sources/PagingPrototypeApp/AppDelegate.swift
- **AccessDeclaration**: NO_PRIOR_EXPOSURE（未接触任何禁读来源/LauunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/反编译 dump）

## 交付摘要

1. **Workflow/PLAN.md 追加「Phase 1F Plan」部分**：DAG（Gate 0 → T-1F-A → T-1F-B∥T-1F-C → T-1F-D → T-1F-E → T-1F-F）、每任务最小写集（文件级，共享文件禁并发）、并发波次方案（每波 Worker 数、写集互斥、独立临时目录、.build 串行）、任务间依赖。既有 1E 内容保留，只追加。
2. **Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md（草案）**：回答 Prompt §6.1 全部 16 问；工作区布局/持久化引用/投影/generation/mutation/锚定所有权；bundle-ID 主 + 确定性 fallback 的 ≥3 方案比较；FolderID 稳定持久化；schema v1 + 工程上限（1 MiB/512/10,000/2,048，标「待验证工程上限，非既有产品事实」）；Application Support 中性子目录 + 注入；A/B 双槽 generation journal；corruption 只读保护；reconcile；reset；隐私清单；AppCatalogCore 默认冻结；FolderSnapshot 不直接 Codable 的理由；renameFolder 真 mutation + 64-grapheme。
3. **Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md（草案）**：回答 Prompt §6.2 全部 14 问；默认自定义窗口内 pointer state machine（非 NSDraggingSession）；DragTransaction/状态机/DragScope；统一 cancel；pasteboard 零身份；5 类 mutation；insertion vs folder-create；参数来源类别（5 类，禁 3 类）；无障碍同引擎；Reduce Motion；PARAMETER_RATIONALE 参数清单；不支持 nested/merge/外部 drop。

## 关键规划事实（读盘核实）

- `Workflow/config.json`: models main=current-main-conversation / chief=glm-5.3 / worker=deepseek-v4-flash:0731 / reviewer=glm-5.3-flash:cloud；max_worker_concurrency=3；thinking_depth 全 max。
- `Workflow/STATE.json`（当前磁盘事实，与 Prompt §1.2 声称不一致，Gate 0 需核实）：
  - `phase` 已为 `PHASE_1F_IN_PROGRESS`；`next_action` 已为 "Phase 1F Gate 0 (reconciliation + 789 baseline freeze) in progress; then T-1F-A ADR+layout domain"；`updated_at` 2026-08-30T22:30:00+09:00。
  - `T-1E-folder-open-repair` 已 PASSED + reconcile_note（split -cell/-wiring 均有真实证据，parent 关闭，未伪造历史）——Prompt 声称"仍 EXECUTING"与当前磁盘不符。
  - 1E 打字机波次（outer/inner/launch-test-repair）均在 STATE 内；789/0 基线为 1E 记录，Gate 0 必须重跑。
- `Sources/AppGridUI/FolderDomain.swift`（258 行）：FolderID（UUID storage、init()/init(uuid:)、redactedDescription=<redacted>、无 rawValue 公开面）；FolderGeneration（UInt64 latest-wins，独立于 CatalogRevision，永不铸造 revision）；FolderTitle（maxLength=64 Character、normalized trim/空白回退/截断）；FolderEntry/Builder（去重保序）；FolderSnapshot（generation+entries）；TopLevelEntry/Identity；ActivationRouter（openFolder/launchApp/reject）；FolderMembership.rebase（已删移除/空移除/单成员解散）；TopLevelComposition.build（folders 在前 + 未分组 apps 在后）——**派生序，非用户布局真相源**（§3.1 缺口 2 的直接代码证据）。
- `Sources/PagingPrototypeApp/AppDelegate.swift`（862 行）：
  - `private var folderOpenState: FolderOpenState?`（L33，会话级，membersPerPage 与 surface 对齐）；
  - `installFolderWiring(assembly:surface:keyboard:launch:)`（L418）：folderSnapshotProvider / onFolderClick→handleFolderCellClick / FolderOverlayView（onActivateMember→launchMember、onRequestClose→closeFolder、onInnerPageChange→setFolderInnerPage）/ FolderTitleEditor（onCommit→commitFolderTitle、onCancel→cancelFolderTitle）/ keyboard 的 folder 感知 seam / search.modeFirstResponderProvider（标题编辑>folder 打开>search>顶层）；
  - `commitFolderTitle(_:)`（L630）：**当前为会话内演示，提交结果不落盘、不进入任何遥测/日志** —— §6.1 Q16 的现状锚点：标题编辑尚未构成真实 layout mutation，T-1F-A 必须补 renameFolder 真 mutation + 64-grapheme + 重启恢复验证；
  - `applyPresentationUpdate(_:overridePageCount:)`（L495）与 `applyPendingAtIdleBoundary()`（L517，顺序：search commitPending → rebuildFolderCompositionIfNeeded → refreshController.applyPendingAtIdleBoundary → reconcileSettledCrossPage）—— **T-1F-E 单一可测提交链（catalog→folder→search→provider→focus）的挂点**；
  - `teardownAll()`（L744，applicationWillTerminate/windowWillClose 双入口）—— **T-1F-E termination flush barrier 挂点**；
  - `QuitOnBlankClickWindow.sendEvent`（L813）+ `blankClickResolvesToCell(_:)`（L849）——空白单击两阶段（folder open 优先、搜索其次、否则退出）现有仲裁，1F 输入仲裁必须与其共存；
  - SELFDRIVE（PAGING_PROTOTYPE_GUI_SELFDRIVE=1）自驱脚本可作为 1F 自动化输入的既有模式参考。
- `Docs/ADR-006-KEYBOARD-FOCUS.md`（152 行）：§9 标题当前磁盘为「2026-08-30」——Prompt 所称「§9 标题日期 2026-08-31」与磁盘不符，Gate 0 核实为笔误后修复（或记录已修复）；§6.3 `reconcileSettledCrossPage`、§8.5 空白两段式、§8.3 ESC 语义（退出键盘选择）均为 1F 焦点调和/输入仲裁的上游约束。

## 波次方案摘要（详见 PLAN.md Phase 1F §6）

- **Wave 1**（1 Worker）：Gate 0 —— 重跑 tests/builds/hash、基线清单、1E 对账核对；无实现写集（只写 Docs/PHASE1F_BASELINE_MANIFEST.sha256 + Workflow 台账）。
- **Wave 2**（1 Worker）：T-1F-A（ADR 定稿草案阶段 + 纯 layout/mutation 领域；纯 Foundation，无 AppKit/I/O）。
- **Wave 3**（2 Worker 并行）：T-1F-B（store）∥ T-1F-C（drag 状态机/意图）—— 写集全分离（B: AppGridUI 新 store 文件 + Tests 新文件；C: AppGridUI 新 state/resolver 文件 + Tests 新文件），各自独立临时目录，不触碰 AppDelegate/Provider/FolderDomain.swift 既有文件。
- **Wave 4**（1 Worker）：T-1F-D（AppKit drag UI，依赖 C）—— 写 AppGridUI 视图层新文件，不动 PagingUI/PagingCore。
- **Wave 5**（1 Worker）：T-1F-E（Provider/AppDelegate/persistence 集成，依赖 A/B/C/D，串行，共享文件）。
- **Wave 6**（Reviewer 波 + Main 收尾）：T-1F-F —— 逐任务独立 Reviewer；Main 全量 tests/builds/hash；隐私/溯源/持久化审查；物理手动门。
- .build 全程 Main 串行控制；每波前做 6 问并发检查并记录（依 config.json max_worker_concurrency=3，本方案实际峰值 2 个实现 Worker）。

## 待 Main 升舱确认项

1. STATE.json 已自报 PHASE_1F_IN_PROGRESS + next_action 已指向 1F Gate 0 —— 与 Prompt §1.2「(2) workflow_status ACTIVE、(3) next_action 仍 1E 手动门 pending」冲突：Gate 0 按磁盘事实执行，还是先回退 state 完成 1E closeout 再进 1F？（本计划假设按磁盘事实 + 在 Gate 0 内完成 1E closeout 核实后自然过渡。）
2. ADR 草案由 Chief 起草后，需 Main 转正流程（1E 先例：ADR-008 Chief draft → Main 转写 Accepted）—— 1F 的 ADR-009/010 转正时机：T-1F-A 完成时？还是 T-1F-E 前？本计划建议 T-1F-A 交付后即转正（实现须锚定 ADR），请 Main 确认转正门。
3. 789 基线重跑若与记录不符（如 >789 或失败）：Gate 0 记录差异 + 冻结实际数字，不伪造——无需升舱除非出现 1E 回归。
