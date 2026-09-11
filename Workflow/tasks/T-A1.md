# T-A1 — tolerance 梯度 SELFDRIVE(探针,零代码)

- 类型: 探针(investigation-only,零新代码)
- 依赖: Phase 0 启用(已确认)
- 依据: Docs/FRAME_LAG_FIX_PLAN.md §5
- 目的: 在 0/2/4/8.333ms 上画出短尾是否单调;看 4ms 是否已够用;量每臂 commit/stale 副作用。

## 写入范围
- `Docs/TIMER_TOLERANCE_GRADIENT_RESULTS.md`(新)
- `/tmp` JSONL 产物
- **禁止**: 任何 Sources 改动、任何默认值改动、git 操作、`ROOT_CAUSE_FOUND` 类结论。

## 协议(固定,禁止事后挑 run)
- 同一 Release 二进制(重建一次,记录 SHA-256)。
- 环境: `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`,40 次 synthetic fling,正常 teardown。
- 主轨 flags: `--neutral-content --disable-telemetry-bridge --frame-callback-profile --frame-timer-tolerance-ms <ARM>`;**不要** `--frame-profile` / `--runloop-profile`。
- 交错顺序: G1 8.333, G2 0, G3 4, G4 2, G5 2, G6 4, G7 0, G8 8.333。
- 有效 run: `run.end=1` 且 `teardown.complete=1`。失败 run 保留,不删。
- 每 run 前 pkill 既有 PagingPrototypeApp 实例。

## 指标(每 run + 每臂池化)
- raw interval 数(first tick 排除)、p50/p95/p99/max
- >20 / 20–25 / >25 / >33.3 / >50 次数与 /1000
- first-tick 表(arm→first-entry)
- committed / stale / interrupted(从 SELFDRIVE 日志/telemetry 取;取不到则补一轮仅 `--paging-telemetry` 无 profile 的轻量轨)

## 判读规则(写入结果文档,不代用户决策)
- 短尾单调: 8.333 的 20–25ms 率 > 4 > 2 > 0(允许 2 与 0 接近)
- 4ms 足够: 4ms 的 p95 ≤ 18.5ms 且 20–25ms 率 ≤ 8.333ms 臂的 40%
- 0ms 副作用: 0ms commit 数相对 8.333 变化 > 20% → 写入风险,推荐倾向 4ms
- >25ms: 任何臂之间的差异不得写成「0ms 改善/恶化长尾」(样本太稀)

## 约束
- 隐私: JSONL 不含 app 名/bundleID/路径/URL/搜索词/图标。
- 不把 SELFDRIVE 当物理手感 PASS。
- 不改默认;不创建「已修复」叙事。
