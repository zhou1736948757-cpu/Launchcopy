# Phase 1F 验证结果（VALIDATION_RESULTS）

> 状态：**AUTOMATED_COMPLETE_PHYSICAL_PENDING**（2026-09-05 Gate 0 对账补建）
> 自动化证据为 2026-09-05 fresh 重跑；物理门未完成项如实标注，不冒充 PASS。

## 1. Fresh 自动化基线（2026-09-05，Main 实跑）

| 项 | 结果 |
|---|---|
| `swift test` | **Executed 1137 tests, 0 failures (0 unexpected)**，exit 0（17.2s） |
| `swift build`（debug） | exit 0（Build complete） |
| `swift build -c release` | exit 0（Build complete） |
| Debug SHA-256 | `69f7f88fe3a0a370dca3e54e54af52000a3827c69cb488becb47710c738c9b5c` |
| Release SHA-256 | `ebbf77c0aa83ff49798e6b636268c90daee6028381c3394cd1c8b500af2d8384` |
| 测试隔离 | LayoutStoreActorTests 用 `FileManager.default.temporaryDirectory`（makeTempStoreDirectory）；Tests 无 Application Support 引用 |

## 2. 专项回归（既有 fresh 证据，2026-09-05 补录）

| 套件 | 结果 | 证据来源 |
|---|---|---|
| B1ManualDeliveryTests | 14/0 | T-1F-B10-regression-fix 结果 §10.4 + r5 评审 |
| Bug11RowBoundaryIndicatorTests | 10/0 | T-1F-B11 结果 §7（Main fresh 补录） |
| BUG8/BUG6/BUG10PreviewHost/DragUIIntegration | 40/0 | T-1F-B11 结果 §7 |
| 全量（当时基线） | 1133/0 | T-1F-B11 结果 §7；本次 fresh 1137/0 为更新基线 |

## 3. 关键任务状态（Gate 0 对账后）

| 任务 | 状态 | 说明 |
|---|---|---|
| T-1F-A（ADR-009/010 + 纯 layout/mutation domain） | PASSED | |
| T-1F-B（layout store）子任务 | 全 PASSED | tests-codec / codec-folder-duplicate-repair / tests-actor / actor-hasloaded-repair / BC-compile-repair |
| T-1F-C（drag session + drop resolver）子任务 | 全 PASSED | tests-session / tests-drop / tests-edge |
| T-1F-B10-regression-fix | PASSED（r5） | 门控默认关=生产零变更；**Q-1 实机 A/B 未回填** |
| T-1F-B11-row-boundary-indicator | PASSED（r1） | **PHYSICAL_VISUAL_ACCEPTANCE_PENDING**（评审明示未做真实窗口验收） |
| T-1F-B9-diagnosis | worker_completed | BUG9 诊断完成（断点定界）；无独立评审文件，诚实标记 |

## 4. 物理门状态

| 门 | 状态 | 证据 |
|---|---|---|
| B10 生产默认路径 | **PENDING** | `PAGING_CLICK_MANUAL_DELIVERY` 默认关（getenv 严格 `=="1"`）；门控开全链自动化 14/0 通过，但用户实机 A/B 读数未回填（r5 Q-1） |
| B11 视觉验收 | **PENDING** | 评审 r1 明示"未做真实窗口/trackpad 人工复现" |
| Folder 功能 | USER_REPORTED_PHASE1F_FUNCTIONALLY_COMPLETE | 用户 2026-09-05 报告；拖拽与持久化其余验收按实际证据对账 |

## 5. 结论

自动化全部通过（1137/0，debug/release exit 0，hash 已记录）；物理门（B10 实机 A/B、B11 视觉验收）未完成。
按 Phase 1G Prompt §1.3：**Phase 1F 标记 `PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING`**，Phase 1G 行为代码在物理门回填前不启动；纯逻辑/文档/识别器 Mock 工作不受影响。
