> **SUPERSEDED**（2026-08-28 Gate 0）：本报告为 Step 0–7 阶段快照（144 tests，物理门未执行）。最终 Phase 1A 报告见根目录 `PHASE1A_REPORT.md`（181 tests；60Hz PASS / 120Hz BLOCKED）。历史保留，不删除。

# Phase 1A 最终报告 — PagingPrototype（分页滑动性能原型）

- **日期**：2026-08-28
- **范围**：Step 0–7 全部完成（自动化 + 独立审查）；Step 8 物理门**等待用户执行**
- **报告格式**：Prompt §16（A 完成内容 / B 验证表格 / C 诚实边界 / D 唯一建议）

---

## A. 完成内容

独立全新实现的 macOS AppKit 分页滑动原型（`/Users/mac/Projects/Launch_Copy/PagingPrototype/`，全新目录；能力匹配，非复制任何旧项目）：

| 模块 | 内容 | 交付 |
|---|---|---|
| PagingCore | 纯逻辑状态机：五状态（idle/tracking/settling/interrupted/cancelled）、monotonic transition token 三防线 stale rejection、中断接管（接管点=当前显示位置）、resize/pageCount 三分支、teardown 零回调、Reduce Motion 动态切换、手动 spring 插值 settle、PageTargetPolicy | 6 文件，51 测试（§7.1 22 类场景 + §7.2 6 条序列） |
| PagingTelemetry | JSONL telemetry：17 必需字段 + 4 扩展、run/gesture/transition ID、开关与路径安全 | 4 文件 + 33 测试 |
| PagingUI | AppKit 视图：live 页面承载（ADR-002 方案 1）、NSEvent→Core 归一化、display link 驱动 settle、中断/动画/teardown、Reduce Motion 接线、中性几何页面（无品牌元素）、可访问性描述 | 4 文件 |
| PagingPrototypeApp | NSApplication 入口、窗口、7 个 CLI 参数（--paging-lab/--page-count/--items-per-page/--page-hosting/--reduce-motion-override/--paging-telemetry/--run-id）、帮助与错误处理、telemetry 接线 | 4 文件 |
| Tests | Core/Telemetry/UI 全量 **144 tests**（含 §3.F 六门禁、§7.3 六判据、§7.4 四边界、性能探针） | 13 文件 |

文档：`Docs/PHASE1_SPEC.md`、`ADR-001-PAGING-STATE-MODEL.md`（§3.G 七问全答）、`ADR-002-PAGE-HOSTING.md`（两方案+否决项）、`PARAMETER_RATIONALE.md`（23 参数、来源类别合规、TUNING_REQUIRED 如实）、`VALIDATION_PLAN.md`、`VALIDATION_RESULTS.md`、`MANUAL_TEST_STEPS.md`、`IMPLEMENTATION_LOG.md`；`PROVENANCE/` 三件套（全部参与者亲笔声明登记）。

工作流：chef-worker-reviewer-workflow（Main/Chief/Explorer/Worker B/C/D/Reviewer E），事件链 42 条、心跳与状态机全程可审计。

## B. 验证表格

| 验证项 | 结果 | 证据 |
|---|---|---|
| BUILD_DEBUG（清洁 .build） | **PASS** | `swift build -c debug` exit 0，0 警告 |
| BUILD_RELEASE（清洁 .build） | **PASS** | `swift build -c release` exit 0，0 警告 |
| AUTOMATED_TESTS | **PASS** | `swift test` **144 tests, 0 failures**（51 Core + 33 Telemetry + 60 UI），exit 0 |
| CODE_REVIEWED | **PASS** | Reviewer E 独立审查（`Workflow/reviews/T-reviewer-r1.md`）：无 BLOCKER/MAJOR，5 MINOR+2 QUESTION 全部处理 |
| SOURCE_REVIEWED | **PASS** | 8 类扫描（源码/测试/文档/资源/plist/Git/strings/绝对路径）0 泄漏命中（命中均为规格要求禁止性说明/工程自身路径）；**扫描=泄漏预警，非原创性证明** |
| VISUAL_NEUTRALITY_REVIEWED | **PASS** | 中性命名与页面（无 Buho 身份/品牌元素/旧标识符） |
| 性能 baseline（自动） | **PASS** | 单帧 update mean 4.5–5.9µs、max 3.3ms、miss16=0、hitch50=0；view≤14；layout 0.5–0.6 次/甩动；stale 零提交；冷创建≤3 后 100% 复用（5 预设 × 3 run，9 个 telemetry 日志保留） |
| MANUAL_PHYSICAL_GATE_60HZ | **NOT_RUN** | 等待用户在真实 GUI + 触控板执行（`Docs/MANUAL_TEST_STEPS.md`） |
| MANUAL_PHYSICAL_GATE_120HZ | **NOT_RUN** | 无 120Hz 证据；无设备证明时最终状态 = BLOCKED |
| 产物 hash | — | Debug `224d1305…81fd979`；Release `183b7eb6…53d6297a`（SHA-256） |

## C. 诚实边界

1. **物理门未执行**：60Hz/120Hz 的"主观跟手/连续/settle ≥4/5"与真实帧节奏**尚未验证**。自动化探针（miss16=0/hitch50=0）只作回归预警，**不替代**真实触控板（Prompt §7.4/§8）。
2. **无头环境局限**：CADisplayLink 在无头环境不触发（硬证据：T-step6 run1 零帧事件，日志保留）；回退帧泵已明确标注 synthetic，未被当作物理门证据。
3. **异常 run 全保留**：9 个 telemetry 日志（含 run1 零帧异常、perf-cli-p10 双 run 追加）未删除；Reviewer 已核查。
4. **来源扫描局限**：扫描可发现已知泄漏，不是原创性或法律证明；结构相似性因禁止读取旧码无法对照证明（Reviewer 已声明该局限，依据为独立设计痕迹）。
5. **无 commit/push**（§15 纪律）：git init 后仓库保持无提交；产物 hash 记录于 IMPLEMENTATION_LOG。
6. **参数调参未发生**：交互参数保持 TUNING_REQUIRED（自动化 baseline ≠ 物理调参）；120Hz 目标 NOT_RUN/BLOCKED。

## D. 唯一建议

**现状态**：架构 + 实现 + 自动化 + 独立审查全部通过；唯一未过项是**真实触控板物理门（等待用户）**。

**条件性建议：RECOMMEND_PROCEED_TO_PHASE_1B（待物理门通过后生效）** —— 依据：live views 架构自动余量 300×–4600×、六条 §3.F 硬门禁全部有自动化证据、Reviewer E PASS、0 编译警告、144 测试全绿；无任何证据指向需要架构返工（REWORK_PAGING_ARCHITECTURE 无触发条件）。

**生效条件**：用户按 `Docs/MANUAL_TEST_STEPS.md` 执行物理验收后：
- 60Hz 门通过（无硬门违规 + 主观三项中位数 ≥4/5）→ 建议正式生效：**RECOMMEND_PROCEED_TO_PHASE_1B**
- 60Hz 门未达标（硬门违规或主观 <4/5）→ 建议切换为：**RECOMMEND_TUNE_AND_REPEAT_PHYSICAL_GATE**（参数调参后重复物理门）
- 120Hz：除非能证明实际 120Hz 刷新率，否则维持 NOT_RUN/BLOCKED，**不影响** 60Hz 结论，但 Phase 1B 的高刷目标需另行证明

**不适用项**：BLOCKED_BY_ENVIRONMENT_OR_PROVENANCE（环境齐备、来源纪律与声明全部登记，无阻塞证据）。
