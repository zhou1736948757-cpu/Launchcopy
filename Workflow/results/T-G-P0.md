# T-G-P0 Result — 四指参考审计复核 + ADR-013 + 风险清单

- **Worker**: deepseek-v4-flash:0731（fresh context）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P0.md`
- **Status**: COMPLETED（纯文档任务；待独立 Reviewer 评审 + 用户确认风险清单后进入采集实验门）
- **Access declaration**: 本 Worker **未直接读取 LaunchBetter 源码**（仅复核 Main 已产出的审计文档，对照 Prompt §17.3）；登记于 `PROVENANCE/REFERENCE_EXPOSED.md`

## Changed files

| 文件 | 操作 | 说明 |
|---|---|---|
| `Docs/FOUR_FINGER_REFERENCE_AUDIT.md` | 追加 §8 复核记录 | §17.3 逐项覆盖清单（11 项）+ 3 项补缺（本机验证显式声明 / LaunchBetter AGENTS.md 读取状态 / 复核元数据） |
| `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md` | 新建 | 私有 MultitouchSupport 窄例外路线；来源边界；识别会话/设备隔离/锁序/输入交接/默认开关/私有实现排除方式；分发未评估 |
| `Docs/FOUR_FINGER_RISK_REGISTER.md` | 新建 | 7 项风险（R-01..R-07）+ 用户确认门（§0 GATE） |
| `PROVENANCE/REFERENCE_EXPOSED.md` | 新建 | REFERENCE_EXPOSED 接触记录（Main 接触 + Worker 复核声明） |
| `Workflow/results/T-G-P0.md` | 新建 | 本结果文件 |

## Per-criterion results

1. **审计复核（§17.3）**：✅ 逐项覆盖（清单见审计 §8.1：文件/行号/摘要/读取日期、代码事实 vs 注释 vs 推断、来源标注、行为规格提取、拒绝沿用清单、风险清单、直接复用先提交范围）；补 3 项缺口（§8.2）；**未重读 LaunchBetter 源码**。
2. **ADR-013（§18 决策表 + §24 要求）**：✅ 三路线比较（公开 API 本轮未找到可验证方案 / 私有 MultitouchSupport 选定 / 兜底 BLOCKED）；窄例外边界（不解除 AppKit/WindowServer/tap/键盘监听禁令；Input Monitoring 独立说明用途/实测依据/降级，未经同意不申请）；§18.3 默认开关（`fourFingerActivationEnabled=false` 直到验证/获批）+ 编译排除 vs 运行时禁用区分；§24 至少 8 项记载全部覆盖（API/权限路线、独立实现来源边界、识别会话、设备隔离、锁序、输入交接、默认开关、私有实现排除方式）；分发未评估。
3. **风险清单**：✅ 7 项风险（R-01 私有 ABI 布局无公开文档、R-02 触点状态分类 state!=0 未区分 hover/开始/结束/取消、R-03 零触点帧被丢弃、R-04 设备混流回调无 device 参数、R-05 锁序与生命周期 deinit dlclose 并发、R-06 Input Monitoring 权限设备枚举成功≠权限授予、R-07 系统更新兼容性）；**明确标注「用户确认风险清单后才运行采集实验」门**（§0 GATE）。
4. **PROVENANCE REFERENCE_EXPOSED**：✅ 登记 Main 接触（4 白名单文件）+ T-G-P0 Worker 复核声明（未直接读取）。
5. **结果文件**：✅ 本文件。

## Evidence

- `Docs/FOUR_FINGER_REFERENCE_AUDIT.md`（§8 复核记录）
- `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`
- `Docs/FOUR_FINGER_RISK_REGISTER.md`
- `PROVENANCE/REFERENCE_EXPOSED.md`

## Deviations

- 无实质偏差。任务包允许「风险清单可并入 ADR-013 或独立」→ 选择**独立文件**（便于用户确认门单独呈现给用户，PLAN §15 #10）。

## Unresolved

- **用户尚未确认风险清单** → 采集实验不运行（门禁生效；T-G-P1/P2 Mock/P3 纯逻辑可继续）。
- 四指严格四 vs 至少四（PLAN §15 #7）与最终默认开关值（#8）待实机证据与用户决策（Main 汇总）。
- Apple 在线资料未取得可用正文（审计 §7）→ 公开 API 路线「本轮未找到可验证方案」已记录于 ADR-013 §1.1。
- 参考实现「与 legacy 验证可用布局对齐」注释的 legacy 来源未核实（审计 §6）——不宣称 clean-room。

## Reviewer focus

- ADR-013 是否完整覆盖 §18 决策表与 §24 至少 8 项记载；风险清单「用户确认后才运行采集实验」门是否明确；审计复核是否如实（未重读源码）。
- 检查 ADR-013/风险清单是否**误称任何「已验证」结论**（本轮零项本机验证——审计 §8.2 补 1）。
- 检查是否出现禁止内容：复制整份参考源码、白名单外 LaunchBetter 读取、Buho 逆向资料、Sources/ 代码改动、commit/push/tag。
- 检查 ADR-013 是否与 ADR-011/012 一致（四指默认 false 已在 ADR-012 Q1 锁定）。

## Memory candidates

- 四指后端路线定案：私有 MultitouchSupport 窄例外（用户已接受）；`fourFingerActivationEnabled=false` 直到验证/获批；采集实验门 = 用户确认风险清单（PLAN §15 #10）。
- 参考实现关键事实（供 T-G-P1/P2 引用）：判定 `>=4`（拒绝沿用，严格四）；冷却 ≠ 一次会话一次；`state!=0` 未分类；回调无 device 参数；deinit dlclose 并发风险；设备枚举成功 ≠ 权限授予。
- 审计文档 §8 复核记录：本轮零项本机验证；「与 legacy 验证可用布局对齐」为未核实声明。
