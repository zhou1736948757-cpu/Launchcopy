# FOUR_FINGER_ACTIVATION_RESULTS — 四指轨最终结果

> Phase 1G 四指轨结果汇总（§24 文档清单）。状态：**自动化 PASS；实机识别器级 PASS；完整矩阵挂账 T-1G-E 集成（整体 PARTIAL）**。定稿：2026-09-06。

## 1. 交付物清单

| 组件 | 文件 | 状态 |
|---|---|---|
| 识别器（首帧基线模型） | `Sources/PagingPrototypeApp/PinchRecognizer.swift` | PASS（T-G-P1-r1 + T-G-P6-r2 + T-G-P7-r1） |
| 后端（MultitouchSupport） | `Sources/PagingPrototypeApp/MultitouchSupportBackend.swift` | PASS（T-G-P6-r1） |
| Provider protocol + Mock | `Sources/PagingPrototypeApp/TouchProvider.swift`、`MockTouchProvider.swift` | PASS（T-G-P2-r1） |
| 配置与入口状态 | `Sources/PagingPrototypeApp/ActivationPreferences.swift`、`ActivationServicePlan.swift`、`FourFingerActivationState.swift` | PASS（T-G-P3-r1） |
| 协调器接线 | `Sources/PagingPrototypeApp/FourFingerActivationCoordinator.swift` | PASS（T-G-P4-r1） |
| 采集工具（实验用） | `Tools/FourFingerCaptureTool/`（main.swift/rawdiag.swift/build.sh） | 实验完成，已清理产物 |
| 决策文档 | `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`（含修订记录） | DRAFT → 收口定稿 |
| 审计/风险 | `Docs/FOUR_FINGER_REFERENCE_AUDIT.md`、`Docs/FOUR_FINGER_RISK_REGISTER.md` | PASS |
| 规格/验证/检查点 | `Docs/FOUR_FINGER_ACTIVATION_SPEC.md`、`FOUR_FINGER_ACTIVATION_VALIDATION.md`、`PHASE1G_CHECKPOINT.md` | 已建 |

## 2. 测试结果（最终）

- **四指轨自动化**：205 用例（39+10+14+17+7+15+18+24+20+18+15+8）全部 PASS
- **全量 swift test**：**1412 tests / 0 failures**（多次独立重跑：T-G-P6-r2 1411/0、T-G-P7-r1 1412/0）
- **构建**：swift build / swift build -c release exit 0
- **红线静态扫描**：17 模式零代码命中（T-G-P5 独立执行）
- **冻结树**：全程零触碰（mtime 逐项核验）

## 3. 实机验证（2026-09-06，用户真实触控板）

| 场景 | 结果 | 关键证据 |
|---|---|---|
| fast-pinch 6 段 | fired=6/6 ✓ | 收缩 47-57%，首帧基线模型触发 |
| slow-pinch 8168 帧 | fired=1 ✓ | 单次触发无重复 |
| spread 6 段（张开 +118~196%） | fired=0 ✓ | 张开不触发（用户决策） |
| negative 1970 帧（单/三/五指） | fired=0 ✓ | 零误触 |
| R-02 state 位掩码 | 定案 | rawdiag 64905 帧直方图 |

## 4. 关键决策记录

1. 严格 4 指（恰好 4 触点；5 指不触发）——用户 2026-09-05
2. 四指默认开启——用户 2026-09-05（覆盖 ADR-013 §7 原锁定 false；默认开启≠立即启用）
3. 风险清单接受（R-01..R-07）→ 采集实验获批
4. 参照 LaunchBetter PinchAnalyzer 模型（首帧基线+相对收缩）——用户指示（events.jsonl #824）
5. 张开不自动 Hide——用户 2026-09-05
6. 0.15 收缩阈值保持（实机余量 >3 倍；ADR-013 修订记录补记依据）
7. maxGestureDuration 1.5s → 3.5s（慢速手势候选到触发 1.6-3.2s 实测定案）

## 5. 挂账（未完成项，诚实标签）

- **整体状态：PARTIAL**（PLAN §10 状态分解：四指自动化 PASS / 四指物理识别器级 PASS / 完整 M01-M12 未跑）
- M01-M12 完整实机矩阵：依赖 T-1G-E 集成（T-1G-B/C/D/E 待物理门回填 + Chief 确认解除）
- 能耗 A/B：依赖集成
- 快速落指不捏合负样本（M04/M05 补）：未单独采集
- 多设备差异（M10）：仅本机 MacBook 触控板
- 分发未评估（ADR-013 §9）
- PLAN.md:542 白名单措辞 6vs4（Chief 修订挂账）
- T-1G-E QUESTION-3：flushPendingShows() 唯一派发出口契约

## 6. 删除义务执行

- 采集 jsonl（4 份）：/tmp/fourfinger-capture-2026-09-05T14-36-13Z.jsonl、2026-09-06T14-14-03Z.jsonl、2026-09-06T14-56-32Z.jsonl、2026-09-06T14-59-35Z.jsonl
- 临时工具：/tmp/pinch-replay3、/tmp/fourfinger-capture-tool、/tmp/fourfinger-rawdiag、/tmp/rawdiag-out.log（证据保留则移入仓库）
- 状态：见 §7 执行记录
