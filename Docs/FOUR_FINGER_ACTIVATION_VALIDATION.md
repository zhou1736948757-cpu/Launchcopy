# FOUR_FINGER_ACTIVATION_VALIDATION — 四指轨验证计划与状态

> Phase 1G 四指轨验证矩阵（§24 文档清单；§23 自动化/实机/能耗门）。状态：**自动化 PASS；实机部分 PASS（识别器级）；完整矩阵挂账 T-1G-E 集成**。最后更新：2026-09-06。

## 1. 自动化验证（全部 PASS）

| 套件 | 用例数 | 状态 | 评审 |
|---|---|---|---|
| PinchRecognizerTests（P01-P12/P17/P19 + 合同 2/3/7/12 + 3 新用例 + MINOR-1 回归） | 39 | PASS | T-G-P1-r1 PASS、T-G-P6-r2 PASS、T-G-P7-r1 评审中 |
| PinchRecognizerLifecycleTests（P13/P14/P15 + 合同 11） | 10 | PASS | 同上 |
| TouchProviderLifecycleTests（P13/P14/P15 + §20.2） | 14 | PASS | T-G-P2-r1 PASS |
| MockTouchProviderTests | 17 | PASS | 同上 |
| TouchProviderIntegrationTests（provider→recognizer 接线） | 7 | PASS | 同上 |
| ActivationPreferencesTests | 15 | PASS | T-G-P3-r1 PASS |
| ActivationServicePlanTests | 18 | PASS | 同上 |
| FourFingerActivationStateTests | 24 | PASS | 同上 |
| FourFingerActivationCoordinatorTests | 20 | PASS | T-G-P4-r1 PASS |
| MultitouchFrameSynthesisTests（R-02 位掩码） | 18 | PASS | T-G-P6-r1（后端） |
| MultitouchSupportBackendTests | 15 | PASS | 同上 |
| FourFingerCaptureStatsTests | 8 | PASS | 同上 |
| **四指轨合计** | **205** | **PASS** | — |
| **全量 swift test** | **1412** | **0 failures** | 多次独立重跑 |

- 关键自动化断言：负样本 events==[]×24 / fireCount==0×17 / no-fire×77；§19.2 合同 12 条逐条；§19.3/§21.1 逐行。
- 红线静态扫描：17 模式扫 8 源 + 9 测试文件零代码命中（T-G-P5 独立执行）。

## 2. 实机验证（识别器级，2026-09-06 完成）

| 场景 | 数据 | 结果 | 证据 |
|---|---|---|---|
| fast-pinch 快速捏合 | 471 帧 6 段 | fired=6/6 ✓ | §R-06 |
| slow-pinch 慢速捏合 | 8168 帧 | fired=1 ✓ | §R-06 |
| spread 向外张开 | 2536 帧 6 段（扩散 +118~196%） | fired=0 ✓ | §R-07 |
| negative 单指/三指/五指 | 1970 帧 28 会话 | fired=0 ✓ | §R-07 |
| R-02 state 位掩码 | rawdiag 64905 帧 | 定案（bit2 主导/bit1 移动/bit0 接触） | §R-02 |

## 3. 实机矩阵（M01-M12，挂账 T-1G-E 集成后）

| 门 | 内容 | 状态 |
|---|---|---|
| M01 | 后台呼出 20 次 ≥19 成功 | 未跑（依赖集成） |
| M02 | 慢/快捏合各 10 次 ≥9 | 识别器级已过（6/6、1/1）；完整计数待集成 |
| M03 | 可见时幂等 10 次 | 未跑（依赖集成） |
| M04 | 张开 20 次零误触 | 识别器级已过（6/6 零触发）；完整计数待集成 |
| M05 | 负样本各 20 次（单指/五指/快速落指不捏合） | 部分（单/三/五指已过）；快速落指未采集 |
| M06 | 连续手势单会话一次 | 识别器级已过（slow fired=1） |
| M07 | 多入口（四指+Hot Corner+快捷键同时） | 未跑（依赖 T-1G-B/C/D/E） |
| M08 | 生命周期（suspend/stop/restart/teardown） | 自动化已过（P13/P14/P15）；实机未跑 |
| M09 | 无设备（外接屏/无触控板） | 未跑（依赖集成） |
| M10 | 设备差异 | 未跑（仅本机 MacBook 触控板） |
| M11 | 输入交接（会话结束优先） | 未跑（依赖 T-1G-E） |
| M12 | 回归（1F 功能不受影响） | 自动化已过（1412/0）；实机未跑 |

## 4. 能耗门（挂账 T-1G-E 集成后）

- disabled/enabled A/B：同 Release 构建、同屏幕环境；隐藏空闲每条件 ≥3 轮 60s 采样；先写阈值再运行；CPU/wakeup 单位与工具写明；不得只凭 Activity Monitor 截图写 PASS。
- 失败 → `HOT_CORNER_ENERGY_GATE_FAILED`（保留菜单/快捷键，Hot Corner 标 Failed/Deferred）。

## 5. 未跑门（硬件/依赖）

- MANUAL_SINGLE_DISPLAY_ACTIVATION_GATE / RAPID_RACE / SLEEP_LOCK / 120HZ / MULTI_DISPLAY：T-1G-B/C/D/E 后。
- PHASE1F 物理门（B10 实机 A/B、B11 视觉验收）：用户决策延后（PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING）。

## 6. 完成门（§25.1 相关）

- 四指轨自动化 PASS ✓（205 用例 + 全量 1412/0）
- 四指物理门：识别器级 PASS；完整 M01-M12 挂账 → 整体 **PARTIAL**（接口已预留 ≠ 用户功能完成；PLAN §10 状态分解要求）
