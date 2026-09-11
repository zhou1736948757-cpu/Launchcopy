# T-G-P6 — 四指轨实机与性能（含采集实验）

## Objective
1. **采集实验（用户已确认风险清单 FOUR_FINGER_RISK_REGISTER.md R-01..R-07，2026-09-05）**：按 ADR-013 §20.1/§20.2 防护计划运行真实 MultitouchSupport 采集实验。**实验前 Main 必须再次告知用户具体实验内容**（采集什么、运行多久、数据去向、如何停止），用户确认后才运行。
2. **真实后端实现**（仅 T-G-P5 PASS 且用户确认实验后）：MultitouchSupport 后端 provider（dlopen /System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport、MTDeviceCreateList/MTRegisterContactFrameCallback/MTUnregisterContactFrameCallback/MTDeviceStart/MTDeviceStop、MTTouch 结构布局按 FOUR_FINGER_REFERENCE_AUDIT.md 审计结论、回调锁外派发、有界缓冲保留 begin/end/cancel、无窗口操作回调、无 deinit dlclose 并发、设备隔离、单调时间域）——实现前先核对 T-G-P2 评审 Q-2（审计 §2.3/2.4 细节复核）。
3. **实机验证矩阵**（MANUAL_FOUR_FINGER_GATE，M01-M12）：后台呼出 20 次≥19、慢/快各 10 次≥9、可见幂等 10 次、张开 20 次零误触、负样本各 20 次、连续手势单会话一次、多入口、生命周期、无设备、设备差异、输入交接、回归。
4. **性能与能耗**：disabled/enabled A/B（同 Release 构建、同屏幕环境；隐藏空闲每条件≥3 轮 60s 采样；先写阈值再运行；CPU/wakeup 单位与工具写明；不得只凭 Activity Monitor 截图写 PASS）。Hot Corner 能耗门（若 T-1G-D 已启动）独立。
5. **挂账项实机验证**：Q-3 慢速连续捏合（advanceCandidate re-anchor L508-513）实机是否触发；Q-2 静默恢复 re-arm 实机行为；Q-4 冷却跨设备实机。
6. 输出 Workflow/results/T-G-P6.md + 实机证据（日志/计数/阈值对比）。

## Expected / Allowed Write Scope
- 真实后端 provider 文件（Sources/PagingPrototypeApp/，仅 T-G-P5 PASS + 用户确认实验后）
- 采集实验脚本/工具（Tools/ 或临时目录，实验后清理或归档）
- Workflow/results/T-G-P6.md、Docs/ 实机记录
- 禁止：窗口行为代码（物理门未回填）、AppDelegate 接线、AppLaunchController、冻结树、Package.swift（Carbon/HIToolbox 例外需 Main 单独改+Reviewer）

## 验收
- 实验前告知用户内容并获确认（事件记录）
- M01-M12 逐项结果（PASS/PARTIAL/BLOCKED_BY_HARDWARE，不可用/Deferred 不算完成）
- 能耗 A/B 阈值先写后测，数据可复现
- 不 commit/push/tag
