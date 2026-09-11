# PHASE1B_VALIDATION_PLAN.md — Phase 1B 验证计划

- **日期**：2026-08-28（Main，Wave 0 后）
- **源**：PHASE1B_REAL_APP_CONTENT_PROMPT.md §10/§11/§14

## 1. 自动化（§10）

| 项 | 内容 | 状态 |
|---|---|---|
| 基线不减门（§10.1） | 每 target executed > 0；Phase 1A 测试零回归 | PASS（414/414） |
| AppCatalogCore（§10.2） | 稳定 ID/排序/去重/PagePlan 35-36/remap 五级/空 catalog/SnapshotGate | 56 PASS |
| MacAppCatalog（§10.3） | fake .app 变体/stopAtAppBundle/cancel/URLNormalizer/失败分类无原文 | 45 PASS |
| AppIconPipeline（§10.4） | 缓存上界/in-flight 合并/取消/generation 拒绝/shutdown 零回调/stats 无隐私 | 23 PASS |
| AppGridUI/integration（§10.5） | provider 映射/token 失配矩阵/乱序图标只落最新/复用无残留/状态机/debounce | 49 PASS |
| 性能回归（§10.6） | 热路径无同步 I/O；复用计数；scan/refresh 不在手势路径 | PASS（review + 测试） |

## 2. 真实设备验收（§11）

- **60Hz 真实内容门**（§11.1）：真实 app 目录 + 图标下复验跟手/翻页/惯性/边界/图标加载无串图；主观 1–5；**用户实机**执行中（phys1b-01 窗口）。
- **120Hz**（§11.2）：BLOCKED_BY_HARDWARE（60.0Hz 面板，无 ProMotion）。

## 3. Reviewer 独立检查（§14）

- A 源码/架构：PASS（8 项全过，2 MINOR）
- B 隐私：PASS（5 项全过，1 MINOR）
- C 来源/资源：PASS 泄漏预警（4 项全过，1 MINOR）
- D 物理验证：用户复验证据到位后由 Reviewer 审查
