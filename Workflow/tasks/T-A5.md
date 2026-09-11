# T-A5 — Timer.tolerance 物理验收(用户定案)

- **任务**: T-A5 物理 ABBA 验收(旧默认 8.333ms vs 新默认 0ms)
- **状态**: 用户直接定案(协议截短:A1 完成 + B1 部分)
- **证据基础**:
  - T-A2 完整 6 轮物理 A/B(2026-08-30): 跟手 4.00 vs 3.87, 总体 3.85 vs 3.77, 误 commit/误回弹 0 双臂
  - T-A1 梯度 SELFDRIVE: p95 17.57 ≤ 18.5 ✓; >20ms 率 9.2 vs 27.8/千帧(降 67% ≥ 50%)✓
  - 0ms SELFDRIVE commit 副作用(+137%)物理未复现 → 归档为合成伪影
- **用户决策(verbatim)**: 「直接定案把」; 此前「还是改成0吧。觉得还是没有0的丝滑。」
- **结果**: T-A5 = PASSED(用户定案); token `SHORT_TAIL_MITIGATED_BY_TOLERANCE` 允许; `REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE` 移除(活状态)
- **保持**: 长尾 >25ms 仍 `CAUSALITY_UNRESOLVED`; 禁止 `ALL_HITCHES_FIXED`/`FIX_VALIDATED`/`ROOT_CAUSE_FOUND`
- **记录**: 2026-08-30, Main
