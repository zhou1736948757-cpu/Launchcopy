# B1 手动投递门控转正决策（2026-09-06）

- **决策**：`PAGING_CLICK_MANUAL_DELIVERY` 门控从「默认关」转正为「默认开」（生产路径）。
- **依据（实机 A/B，2026-09-06）**：
  - 默认关（AppKit 正常投递）：点击 cell 仅 s8d 放行、s10 恒 0、cell.mouseDown 不触发、软件不启动（B10 修复前死路径复现；/tmp/b10-run1-nog1.log：8 次点击全命中 cell 但零 s10/sA）。
  - 门控开（手动投递）：s8d → s10_cell_mousedown_fired → s13a_enable → s6_dispatch_click_cell → sA_launch_accepted（软件启动成功）→ s13b_disable → s9b_endsession_restored；空白点击 s8c 正常退出（/tmp/b10-run1-gated.log）。
  - 用户确认：「好像这次可以了」。
- **推翻**：2026-09-05 用户决策「接受默认关为生产定案」（Workflow/decisions/2026-09-05-gate0-user-decisions.md）——实机证明默认关 = 点击 cell 不启动。
- **实现**：AppDelegate.swift B1ManualDeliveryGate.isEnabled `guard let raw = getenv("PAGING_CLICK_MANUAL_DELIVERY") else { return true }`（未设或 =1 开；=0 显式关，诊断对照）。
- **测试**：B1ManualDeliveryTests 两个「默认关」测试改为「默认开」断言（testB1GateOnByDefaultCellHitDeliversManually / testB1GateOnByDefaultFullChainLaunches）；E4ManualDeliveryTests setUp 显式 B1=0（E4 分支可测）；ClickDeliveryProbeTests / DragCommitIntegrationTests 两个窗口分类测试显式 B1=0（保持测试意图）。全量 1412/0。
- **行为变化**：cell mouseDown 手动投递会激活 drag 会话（pointerDown → fallback 武装）；只发 down 不发 up 时后续空白点击被 drag 守卫吞掉（测试已隔离）。
- **遗留**：B10 实机复测矩阵（门控开 10+ 击、拖拽/搜索/folder 回归）待用户复测回填；B11 视觉验收仍挂账。
