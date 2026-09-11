# Task Packet: T-worker-b-symdamp（负向阻尼线对称化）

- **Task ID**: T-worker-b-symdamp
- **Role**: Worker（PagingCore 作者）
- **来源**: T-step8 物理调参第 8 轮：用户感知往左/往右手感不对称
- **日期**: 2026-08-28

## 用户反馈（原话）

"这个你就不能改成跟往右走一样吗？"——往左（下一页）手感与往右（上一页）不一致。

## 证据（phys-auto-11 telemetry + 代码，Main 已定位）

**几何不对称**（PagingCore.swift:571-583）：
- 正向（下一页）阻尼线 = `committed + 1 + 0.2` → offset 到目标页 +0.2 才阻尼 → 往左 momentum 段全量滑行 ~0.37 页（gi=76：1.122→1.493 全量）
- 负向（上一页）阻尼线 = `committed − 0.2` → offset 往回滑 0.2 页就阻尼 → 往右 momentum 段 ~0.15 页（gi=73：0.888→0.741，其中后半已阻尼）
- 结果：往左滑行长/拖沓，往右滑行短/干脆 → 手感不一致。

## 修复要求

1. **负向阻尼线对称化**：`committed − 0.2` → **`(committed − 1) − overshoot`**（目标页之前 0.2；与正向"目标页之后 0.2"几何对称）。即条件 `newOffset < Double(committedPage - 1) - overshoot`（guard `committedPage > 0` 保留——第 1 页无负向目标，overscroll 由既有边界阻尼管负责）。注释同步（565 行附近）。
2. 行为验证（对称后）：
   - 往左（gi=76 形态）：阻尼线 2.2 不变，行程不变
   - 往右（gi=73 形态，committed=1）：阻尼线 -0.2 → momentum 段 0.888→0.741 全程全量（无阻尼），行程 ~0.27 页与往左同量级（依事件 delta）
   - 边界页（committed=0 往右）：overscroll 阻尼不变
3. **测试更新**：
   - `testMomentumOvershootSoftDampReverse`（负向递推序列）期望值按新阻尼线重算（终点/拉回精确值）
   - 新增/更新"对称性"断言：相同 |delta| 序列下，正向与负向的自由行程相同（阻尼线 = 目标±overshoot）
   - 慢甩/边界/RM/glide/正向快甩断言不变
   - 全量 swift test 0 failures（174+）
4. `swift build` exit 0（0 warning）。不动：默认值 0.20、CLI、软阻尼递推机制本身。

## Write Scope

- `Sources/PagingCore/PagingCore.swift`（571-583 段 + 注释）
- `Tests/PagingCoreTests/`
- `Workflow/results/T-worker-b-symdamp.md`（简短）

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`、`Sources/PagingPrototypeApp/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- 心跳 role Worker, task-id T-worker-b-symdamp, ACTIVE

## Status

- 2026-08-28：Main 定位几何不对称；Worker 修复中。
