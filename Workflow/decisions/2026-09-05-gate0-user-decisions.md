# 2026-09-05 Gate 0 用户决策（Main 记录）

用户对 Gate 0 汇总决策门的明确回答（原话选项）：

1. **B10 实机 A/B**：接受默认关为生产定案，实机 A/B 延后。
   → B10 生产默认路径 = `PAGING_CLICK_MANUAL_DELIVERY` 默认关（getenv 严格 `=="1"`）；实机 A/B 读数挂账（r5 Q-1/Q-2 延后）。
2. **B11 视觉验收**：延后验收。
   → 保持 `PHYSICAL_VISUAL_ACCEPTANCE_PENDING` 挂账。
3. **四指 G-P0 路线**：接受私有 MultitouchSupport 后端。
   → 允许来源审计 + ADR + 风险清单先行；用户确认风险清单后运行采集实验；仅限获批四指 provider 窄范围私有 MultitouchSupport 例外，不解除其他禁令。
4. **Phase 1G 推进方式**：先做纯逻辑工作。
   → 状态机/四指识别器 Mock/ADR-011/012/SPEC 先行；不碰真实采集与窗口行为代码。

Phase 1F 状态：`PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING`（B10 默认关定案、B11 挂账）。
