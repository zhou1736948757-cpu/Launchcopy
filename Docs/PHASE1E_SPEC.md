# PHASE1E_SPEC — 文件夹基础垂直切片（Folder Foundation）

- 日期：2026-08-30
- 范围：Phase 1E（chef-worker-reviewer-workflow v1.4.1）
- 依据：`Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md`（838 行，SHA-256 `efae3c1b236070c3bc4a69a2714cef5e9a551c885d32c8aba063a1ff00585797`）
- 架构决策：`Docs/ADR-008-FOLDER-PRESENTATION.md`（ACCEPTED）

## 1. 目标

在现有分页启动器中加入文件夹基础垂直切片：顶层文件夹条目、打开层（成员网格 + 内部分页）、键盘/焦点/标题编辑、搜索与刷新兼容、空白单击两段式。不做拖拽/持久化/Hot Corner/品牌视觉（Phase 1F）。

## 2. 范围（A–I）

- A. 独立文件夹领域模型（FolderID/FolderEntry/FolderSnapshot/folder generation/TopLevelEntry/ActivationRouter）
- B. 文件夹数据源：会话内、显式测试入口（`--folder-lab` 标志，默认 off）
- C. 顶层呈现（apps + folders 统一组合，每文件夹一个槽位，页数/锚点/5 级 remap）
- D. 文件夹视觉 + 打开层（中性独立视觉、成员网格、内部分页、层外点击只关文件夹）
- E. 指针与键盘行为（打开 vs 启动路由、ESC 优先级、焦点恢复、无全局监听）
- F. 标题编辑（会话内，Enter/Escape/失焦语义，隐私）
- G. 搜索兼容（仅按 app 显示名过滤、扁平化成员、Command-F 先关文件夹）
- H. 目录刷新兼容（idle 提交、成员删除、空文件夹移除、单成员 dissolve）
- I. 无障碍 + Reduce Motion

## 3. 非目标（Phase 1F）

拖拽创建/重排/跨页移动、持久化、Hot Corner、品牌视觉。越界记 `SCOPE_EXPANSION_REQUIRES_USER_DECISION`。

## 4. 冻结树（NEVER modify）

`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`（默认冻结，本阶段零改动）、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`。

## 5. 允许写集

`Sources/AppGridUI/`、`Tests/AppGridUITests/`、`Sources/PagingPrototypeApp/`（除 AppLaunchController）、`Tests/PagingUITests/`、`Docs/`、`PROVENANCE/`、`Workflow/`。

## 6. 关键设计（ADR-008 摘要）

- 统一呈现 item：`[TopLevelEntry]` = `.app(AppRecord)` / `.folder(FolderEntry)`，在现有 `AppGridUIPageContentProvider` 内提交；拒绝独立 folder overlay provider。
- 中性 grid-entry identity + 统一 activation router：顶层 app→AppLaunchController / 顶层 folder→打开 / 成员 app→AppLaunchController / placeholder/stale→安全拒绝。
- `FolderID` 独立 Hashable 类型；启动路径既有 `as? AppID` cast（AppLaunchController.swift:131）天然拒绝 folder identity，无弱化第二启动路径。
- PagingUI 零改动（`PagingPageContentItem.identity: AnyHashable` seam 已可表达 folder kind）。
- 单成员文件夹策略 = **DISSOLVE**（用户决策 2026-08-30，覆盖 Chief 的 KEEP 建议）：恰好 1 成员的文件夹呈现为成员 app 条目；≥2 成员才存在文件夹条目；空文件夹移除。
- folder-lab 分组规则 = 稳定目录序前 N 个/组（默认 groupSize 35），中性标题 `Group 1`…，默认 off，会话内，无持久化。
- 搜索 = 仅 app 显示名过滤的扁平化切片，永不匹配 folder 标题；退出搜索恢复完整组合。
- 内部分页 = 呈现层状态，永不驱动 PagingCore。
- pending 优先级：新 catalog snapshot > 重建 folder composition > 新 base 重跑 search > 恢复/关闭 folder open state > relayout/focus reconcile。
- 异步图标走 AppIconPipeline + ItemBindingToken 7 字段 generation 门控；folder cell 永不请求 app 图标。
- 输入优先级：标题编辑 Enter/Escape > folder 打开层 Escape/方向键/激活 > 搜索 field > 顶层键盘焦点 > 窗口背景退出。
- 空白单击两段式：打开层外点击只关文件夹；真实背景首击退出。
- ESC：编辑→取消/结束，folder 开→关闭，否则→清网格选择。Command-F：先安全关 folder 再进搜索。
- 标题编辑 first responder；标题/成员/identity 原值 + 图标数据永不入 telemetry/JSONL/stdout/signpost/profile/report；仅中性计数（folder_count/member_count/open-close outcome enum/stale rejection count/apply duration）；无 PagingTelemetry schema 变更。
- Reduce Motion 减大幅位移/缩放（MotionParams standard 0.18/0.96/8 vs reduceMotion 0/1/0）。

## 7. 测试与验收

- 基线 631 tests（Phase 1D closeout）→ 最终 **789 tests, 0 failures**（+158：H2 2 / A 27 / B 20 / C 29 / D 32 / D-repair 3 / E 12 = 756；修复波次 +33：inner-nav 16 / focus-layout 10 / keyboard-return 3 / typewriter-outer 2 / typewriter-inner 2）。Gate 0 复跑确认 789/0（2026-08-30）。
- 每任务独立 Reviewer PASS（T-1E-A..E、T-1E-D-titleedit-repair、T-1E-H2-repair 各 r1/r2）。
- Debug/Release 构建 exit 0；冻结树 mtime/hash 核验未变；无冲突标记；隐私扫描 clean。

## 8. 手动门（待用户物理测试）

`MANUAL_FOLDER_GUI_GATE` / `MANUAL_FOLDER_KEYBOARD_GATE` / `MANUAL_TRACKPAD_60HZ_REGRESSION_GATE` = NOT_RUN（用户实机测试后 PASS_USER_REPORTED_WITH_EVIDENCE）；`MANUAL_120HZ_GATE` = BLOCKED_BY_HARDWARE（60Hz 面板）。

## 9. 最终建议

`RECOMMEND_PROCEED_TO_PHASE_1F_DRAG_AND_PERSISTENCE`（生效条件：手动门通过；未通过前保持 `PHASE1E_AUTOMATED_COMPLETE_PHYSICAL_PENDING`）。
