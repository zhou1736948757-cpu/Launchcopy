# T-1F-C — Drag session state machine + drop resolver（Worker）

**Worker**: worker-c（T-1F-C）
**任务**: 实现纯（无 AppKit）drag session 状态机 + drop resolver + hit-zone/drop-intent 分类 + 5 类 mutation 统一引擎 + edge paging 纯 seam + 统一 cancel + stale 防护
**日期**: 2026-08-31
**接口契约**: `Workflow/tasks/T-1F-C.md`；ADR-010（Accepted，Q1–Q14）；Phase 1F Prompt §3.3/§10.5；PLAN.md §7/§10 C 行
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `BuhoReverseNotes` / `LaunchBetter` / `2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本任务包、ADR-010、Apple 公开文档与本工程自身文件）

---

## 状态：in progress

- 交付摘要（计划）：
  - `Sources/AppGridUI/DragSession/` 新增纯文件：`DragTransaction`（opaqueToken/scope/sourceIdentity/layoutGeneration/catalogGeneration）、pointer 状态机（idle → pressed → dragging/edgeTurnPending → commit|cancel → idle）、按下阈值仲裁（click vs drag）、drop resolver、hit-zone/drop-intent 分类（insertion vs create-folder 视觉异构 → enum 输出，视觉执行在 D 层）、5 类 mutation 统一引擎（全部经 `LayoutMutation(expectedGeneration:)` 单一写入口）、edge paging 纯 seam（enter/dwell/turn/leave/cancel/first-last，只产事件）、统一 cancel（ESC/resign/refresh/search/title edit/overlay close/teardown/second drag → 零写盘、无 preview/edge-timer 残留）、stale 防护（stale source/target/layout/catalog 拒绝；duplicate drop consumed once；invalid/external token rejected；second drag invalidates first）。
  - `Tests/AppGridUITests/` 新增 drag-intent 测试（§10.5 矩阵全覆盖）。
  - `Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md` 末尾追加「T-1F-C 实现注记」（不改草案主体）。
- 验证计划：`swift build -c debug` exit 0；`swift test` 全量（基线 789 + A 的 48 + C 新增；既有不得回归；写集外失败如实报告不修改）。
- 红线：不读禁止来源；隐私零身份输出；冻结树 mtime 不变（除写集）；无 git 操作。
