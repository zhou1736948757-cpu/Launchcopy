# Phase 1E — Main Operational Brief

- **Author**: Chief (glm-5.3)
- **Date**: 2026-08-30
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md`
- **Plan**: `Workflow/PLAN.md` (Phase 1E)
- **Supersedes**: Phase 1D MAIN_BRIEF (Phase 1D history in reports/ADRs)

This brief tells Main how to run Phase 1E operationally. It does not restate the full plan; it is the dispatch/concurrency/evidence/reviewer/escalation playbook.

---

## 1. Roles & ownership

- **Main** owns runtime scheduling, concurrency, retries, evidence, and state. `Package.swift` is Main-exclusive. `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, and `Sources/PagingPrototypeApp/AppLaunchController.swift` are frozen — Main enforces this.
- **Chief** (glm-5.3) owns planning, ADR-008 draft, task packets, and decision deltas. Chief does not write product code.
- **Worker** (deepseek-v4-flash:0731) implements one task packet. Fresh context; must not inherit any old reverse-engineering context.
- **Reviewer** (glm-5.3-flash:cloud) independently reviews each implementation task (read-only, never fixes code).
- **Expert Worker** — fresh isolated worker used on a second formal Reviewer FAIL.

## 2. Dispatch order & concurrency policy

`max_worker_concurrency = 3` (Workflow/config.json). DAG:

```
Gate 0 (done) → T-1E-A → T-1E-B ∥ T-1E-C → T-1E-D → T-1E-E (serial) → T-1E-F
```

- **Wave 1**: T-1E-A (no deps). T-1E-H2-repair is already in flight (independent, AppGridUI code) and may run alongside; its write scope (`AppGridUIPageContentProvider.swift` servedPageCount fix) overlaps T-1E-B's file, so **T-1E-B must not start until T-1E-H2-repair has passed review** (serialize on that file).
- **Wave 2**: T-1E-B ∥ T-1E-C — **only** because their write scopes are fully disjoint (B: provider/presentation/state; C: cell/pageview/overlay). Before dispatching, record a concurrency check: dependencies satisfied? write scopes fully disjoint? test resources isolated? Reviewer has independent stable evidence? concurrency won't lower quality?
- **Wave 3**: T-1E-D (deps B/C).
- **Wave 4**: T-1E-E (deps B/C/D, serial — AppDelegate/shared provider integration).
- **Wave 5**: T-1E-F (independent Reviewer + docs + physical gates).

Read-only Explorer/Reviewer may run concurrently. AppDelegate / shared provider / shared ADR / Package.swift integration is always serial. Builds serialize on the SwiftPM `.build` lock.

## 3. Event recording

`Workflow/events.jsonl` is **append-only** and may only be appended via the project workflow script. Record, at minimum, for each wave: `concurrency_check`, `worker_dispatched`, `worker_completed`, `review_started`, `review_passed`/`review_failed`, `state_changed`. Do **not** modify historical events, back-fill old dispatches/reviews, or delete watchdog records. Use idempotency keys per event.

## 4. Reviewer policy

- Every implementation task (T-1E-A..E) gets an independent Reviewer PASS gate before it is considered done.
- Reviewer is read-only; it never fixes code. A Reviewer finding is evidence for a repair task, not a silent edit.
- A formal Reviewer **FAIL** is the only event that increments `worker_failures`. Worker self-repair, tool errors, and transient timeouts do **not** count.
- `exit_code == 0` with `executed_tests == 0` = `INVALID_TEST_EXECUTION` (a hard failure, not a pass).

## 5. Failure / escalation rules

- **Reviewer FAIL #1** → Main builds an escalation packet to Chief for a **Decision Delta** (Chief records `Workflow/decisions/D-*.md`).
- **Reviewer FAIL #2** → Main dispatches a fresh isolated **Expert Worker** (unless plan-level evidence already resolves it).
- **Expert Worker FAIL** → escalate to Chief.
- **Escalation table**:
  - `Sources/PagingCore/`, `Package.swift`, `AppLaunchController.swift`, global NSEvent monitor, Accessibility/Input Monitoring, scope expansion (drag/persistence) → **BLOCKED** (stop, report, do not work around).
  - Reviewer FAIL → per the failure policy above.
  - User decision needed → Worker → Main → user.

## 6. Privacy & provenance enforcement

- Folder title / membership / identity raw values and icon data must **never** enter telemetry / JSONL / stdout / signpost / profile / report. Only neutral counters (`folder_count`, `member_count`, open/close outcome enum, stale rejection count, apply-duration numeric). No PagingTelemetry schema change.
- Every Worker must declare `AccessDeclaration` honestly (`NO_PRIOR_EXPOSURE` unless it actually touched restricted material). If a Worker has prior exposure, mark `PRIOR_EXPOSURE` and prefer a fresh Worker.
- Forbidden sources: `/Users/mac/Projects/LaunchBetter/`, `/Users/mac/Projects/BuhoReverseNotes/`, `/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/`, and any Ghidra/otool dump / decompiled text / old-project source / screenshot / resource / precise visual parameter. Main must not read these either.

## 7. Diagnostics discipline

Keep `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`. Never write `ALL_HITCHES_FIXED` / `ROOT_CAUSE_FOUND` / `FIX_VALIDATED`. Timer tolerance stays `0ms` (T-A5); Phase 1E must not re-tune Timer tolerance, frame source, or paging params. `>25ms` long tail remains `CAUSALITY_UNRESOLVED`.

## 8. Manual gates

Phase 1E final recommendation requires user real fullscreen + physical keyboard/trackpad acceptance. Main records each manual gate as `PASS_USER_REPORTED_WITH_EVIDENCE` (with evidence pointer), `NOT_RUN`, or `BLOCKED_BY_HARDWARE`. `MANUAL_120HZ_GATE` stays `BLOCKED_BY_HARDWARE` on the 60Hz panel. If the user only verbally confirmed without evidence, record `PASS_USER_REPORTED` with a minimal evidence pointer — never fabricate PASS.

## 9. Artifact map

| Artifact | Owner |
|---|---|
| `Workflow/PLAN.md`, `Workflow/MAIN_BRIEF.md` | Chief |
| `Workflow/tasks/T-1E-*.md` | Chief (initial) / Main (runtime) |
| `Workflow/results/T-1E-*.md` | Workers |
| `Workflow/reviews/T-1E-*-r*.md` | Reviewer |
| `Workflow/decisions/D-*.md` | Chief |
| `Workflow/STATE.json`, `Workflow/events.jsonl` | Main |
| `Docs/ADR-008-FOLDER-PRESENTATION.md` | Chief draft → Main transcribes/finalizes |
| `Docs/PHASE1E_SPEC.md`, `Docs/PHASE1E_VALIDATION_PLAN.md`, `Docs/PHASE1E_REPORT.md`, `Docs/PHASE1E_BASELINE_MANIFEST.sha256` | Main |
| `Package.swift` | Main (exclusive) |
| `PROVENANCE/` | Main |

## 10. Stop conditions

Stop the affected branch and report `BLOCKED` (blocking fact, affected scope, saved evidence, Chief/user decision needed, minimal next step) on any of: forbidden-source read required; old source/visual/asset/copy required; `PagingCore` modification required; Launchpad/Dock private DB read/write required; drag/persistence/global-listener required; Timer/frame/param change to make tests green; app vs folder identity indistinguishable; folder/search/catalog generation overwrite risk; real names/titles/paths/query entering logs; concurrent Workers writing the same file/shared mutable state; tests exit 0 with executed tests = 0; automatic commit/push/tag/release required.

---

# Phase 1G Runtime Handoff（2026-09-05 追加；Chief 两次中断后由 Main 按 PLAN.md L510-732 补写）

## 1G 目标（浓缩）
驻留进程 + 菜单栏 + Dock reopen + 可选全局快捷键 + 可选 Hot Corner + 四指向内捏合呼出（向外张开不自动 Hide）；多入口单一 `LauncherPresentationCoordinator` 仲裁；空白点击/ESC 从退出进程改为关闭界面；明确 Quit 才终止。权威输入：`Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`（1655 行）。

## 本轮只做纯逻辑（用户决策 2026-09-05）
T-1G-A（ADR-011/012 草稿 + 纯 presentation/activation 状态机 + Hot Corner 纯状态机 + geometry 值模型 + shortcut outcome 模型 + 测试）、T-G-P0（审计已完成 → ADR-013 + 风险清单）、T-G-P1（四指识别器纯值状态机）、T-G-P2（TouchProvider protocol + Mock）、T-G-P3（ActivationPreferences + 入口状态）。
**T-1G-B/C/D/E 与真实四指后端在物理门回填（PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING 解除）+ 用户确认 G-P0 风险清单前不启动。**

## 关键约束（1G）
- 冻结树：Sources/PagingCore、PagingTelemetry、PagingUI、AppCatalogCore、MacAppCatalog、AppIconPipeline、AppGridUI/LayoutDomain、AppGridUI/LayoutStore、AppGridUI/DragSession、Package.swift、AppLaunchController.swift。
- 允许写：Sources/PagingPrototypeApp/ 新增窄文件（LauncherPresentationState/Coordinator/WindowController/StatusItemController/GlobalShortcutRegistrar/HotCornerMonitor/HotCornerGeometry/ActivationPreferences/WorkspaceSessionObserver）、AppDelegate/AppMain/AppArguments、KeyboardFocusController（仅 ESC seam）、Tests/PagingUITests/、Docs/、PROVENANCE/、Workflow/。
- Package.swift 仅 Carbon/HIToolbox import 例外，Main 独占 + Reviewer。
- 隐私红线：无 global monitor/CGEvent tap/Accessibility/Input Monitoring/Screen Recording（四指获批窄例外除外）；不记录 pointer 坐标/轨迹/screen UUID/前台 app/按键流/真实快捷键/应用名/文件夹/搜索词/窗口标题；Hot Corner disabled=零 timer 零轮询；四指严格 4 触点、一会话一次、全指释放 re-arm、设备隔离、单调时钟。
- 性能 token 不变：PRODUCT_TIMER_TOLERANCE_0MS / SHORT_TAIL_MITIGATED_BY_TOLERANCE / CAUSALITY_UNRESOLVED_FOR_GT25MS。
- 不 commit/push/tag/reset/clean；不自动安装/签名/公证/发布。

## 任务 DAG（语义依赖）
Gate 0（已完成）→ T-1G-A（无依赖）∥ T-G-P0（无依赖）→ T-G-P1（依赖 P0）→ T-G-P2（依赖 P0/P1）∥ T-G-P3（依赖 P0）→ T-G-P4（依赖 P1/P2/P3 + T-1G-A 协调器）→ T-G-P5 评审 → T-G-P6 实机 → T-G-P7 收口；T-1G-B/C/D（依赖 A）→ T-1G-E（依赖 A/B/C/D 串行）→ T-1G-F。任务包：Workflow/tasks/T-1G-A.md、T-G-P0.md、T-G-P1.md、T-G-P2.md、T-G-P3.md（T-1G-B/C/D/E 预建未启动）。

## 1G 验收（浓缩）
ADR-011/012/013 = ACCEPTED；PRESENTATION_STATE_MACHINE_TESTS / HOT_CORNER_PURE_STATE_TESTS / SCREEN_GEOMETRY_TESTS / PREFERENCES_TESTS / FOUR_FINGER_RECOGNIZER_TESTS（P01-P20 纯逻辑）/ FOUR_FINGER_PROVIDER_MOCK_TESTS（P13/P14/P15）= PASS；FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT；BUILD_DEBUG/RELEASE = PASS；INDEPENDENT_REVIEW = PASS（0 BLOCKER/0 MAJOR）；PRIVACY_AND_PROVENANCE_REDLINE = PASS；MANUAL_*_GATES = PASS_USER_REPORTED_WITH_EVIDENCE 或 NOT_RUN/BLOCKED_BY_HARDWARE；FOUR_FINGER_PHYSICAL_GATE = PASS 或 PARTIAL/BLOCKED。四指未完成 → 整体 PARTIAL/BLOCKED，「接口已预留」≠ 完成。

## 1G 停止条件
BLOCKED_BY_PHASE1F_REGRESSION / SCOPE_EXPANSION_REQUIRES_USER_DECISION / PERMISSION_EXPANSION_REQUIRES_USER_DECISION / WINDOW_ARCHITECTURE_DECISION_REQUIRED / HOT_CORNER_ENERGY_GATE_FAILED / PHYSICAL_ACCEPTANCE_PENDING。不得为完成 1G 降低权限/隐私/物理门。

## 1G Chief 决策项（挂账，Chief 恢复或用户决策时处理）
窗口形态定案（T-1G-B spike 后）、target screen 策略、hide 保留策略、Dock 图标形态、Hot Corner poll scheduler、shortcut API 定案、四指严格四 vs 至少四（实机证据+用户）、四指默认开关值（用户确认前不默认启用）、输入交接策略、G-P0 风险清单接受、能耗门失败降级、T-1G-B/C/D/E 启动门。

## 1G 下一步（Main）
1. 派发 Worker T-1G-A（串行先行，基础轨根）；2. 派发 Worker T-G-P0 剩余（ADR-013 草稿，与 T-1G-A 写集互斥可并发）；3. 风险清单交用户确认；4. T-G-P1/P2/P3 按依赖派发；5. 每波前并发检查并记录。
