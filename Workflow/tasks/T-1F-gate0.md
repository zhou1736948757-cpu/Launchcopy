# T-1F-gate0 — Phase 1E 对账与 789 基线冻结（Main 直接执行）

- 创建：2026-08-30（Asia/Tokyo）
- 角色：Main（文档/状态对账，非业务代码；无 Worker/Reviewer 波次）
- 依据：Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md §1.2 / §1.4

## 范围

1. 关闭/对账遗留 `EXECUTING` task（T-1E-folder-open-repair，基于拆分任务 PASS 证据，不伪造历史）。
2. 更新当前态：test count（756→789）、manual gate 状态、ADR-006 §9 日期笔误（08-31→08-30）。
3. 重新跑 `swift test` / `swift build -c debug` / `swift build -c release`，记录真实 executed/passed/failed 与 Debug/Release SHA-256。
4. 创建 `Docs/PHASE1F_BASELINE_MANIFEST.sha256`。
5. 扫描本阶段实际修改文件的 trailing whitespace、冲突标记、禁止来源路径。

## 对账结果（允许值）

- `PHASE_1E_WORKFLOW_RECONCILED`
- `PHASE_1E_KEYBOARD_AND_FOLDER_GUI_ACCEPTED`（用户打字机实机验收"没问题了"）
- `PHASE_1E_TRACKPAD_60HZ_REGRESSION_PENDING`（无独立触控板证据，不从键盘验收推导）

## 禁止

- 不伪造历史 review/dispatch；
- 不把历史 789/0 当成本轮重新运行结果（必须真实复跑）；
- 不改业务代码（Sources/ 任何文件）。

## 验收

- STATE.json 无遗留 EXECUTING；phase=PHASE_1F_IN_PROGRESS；
- 5 个文档（PHASE1E_REPORT/SPEC/VALIDATION_PLAN、VALIDATION_RESULTS、PROVENANCE/COMPONENTS）测试数 789；
- baseline manifest 存在且含真实 SHA；
- 事件已记录（state_changed + note）。
