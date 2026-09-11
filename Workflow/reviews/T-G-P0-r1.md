# T-G-P0 Review r1 — 四指参考审计复核 + ADR-013 + 风险清单

- **Reviewer**: 独立评审（只读；未编辑任何实现/测试/文档文件）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P0.md`
- **Worker result**: `Workflow/results/T-G-P0.md`
- **Review basis**: `AGENTS.md`、`MEMORY.md`、`Workflow/PLAN.md` Phase 1G（L510-732，§2.7/§8 ADR-013 摘要/§11 隐私红线）、`Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`（§17/§18/§19.2/§20.2/§20.3/§21.1/§24）、`Docs/ADR-011/012`、实际 diff（4 交付文件 + 结果文件）、`Workflow/events.jsonl`、`Workflow/STATE.json`
- **Access declaration**: 本 Reviewer **未读取** `LaunchBetter/`、`BuhoReverseNotes/` 源码（遵守评审禁令）；审计行级事实通过「与 Prompt §17.2 既定 10 项事实交叉核对 + 文档内部一致性 + 写集合规（git 状态/文件 mtime/事件日志）」验证
- **Verdict**: **PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 2 QUESTION）

---

## 1. 逐验收标准结果

### AC-1 审计文档覆盖 §17.3 要求 — ✅

| §17.3 要求 | 覆盖位置 | 结果 |
|---|---|---|
| 文件、行号、内容摘要、读取日期 | `Docs/FOUR_FINGER_REFERENCE_AUDIT.md` §1 清单表（4 文件 + 行数 + 日期 + 用途）+ §2 逐文件审计（行号齐全） | ✅ |
| 只摘必要短段，不复制整份参考源码 | 全文仅行号 + 短摘，无整文件复制 | ✅ |
| 代码事实 vs 注释 vs 推断 | §2 每文件分「代码事实」「注释 vs 事实」「推断」小节 | ✅ |
| 哪些经本机验证 | 头部性质声明 + §7 未核实事项 + §8.2.1「本轮**零项**经本机验证」显式化 | ✅ |
| 来源标注及未核实的权利依据 | §6（用户持有目录 ≠ 权利已验证；legacy 对齐注释未核实；不宣称 clean-room） | ✅ |
| 行为规格提取 | §3（5 条，拟重新设计） | ✅ |
| 准备重新设计的部分 | §3 标题 + §6「全部行为规格重新实现」 | ✅ |
| 明确拒绝沿用的部分 | §4（10 项拒绝表，逐项给理由） | ✅ |
| 私有 ABI / 触点状态 / 零触点事件 / 设备混流 / 锁序风险清单 | §5.1–5.4（5.2 含零触点帧；5.4 含锁序与生命周期） | ✅ |
| 拟直接复用代码：先提交范围与依据 | §6 末条（MTTouch 布局等直接移植须先经 Main/Chief 批准） | ✅ |
| 测试文件处理 | §1 末行：仅定位未读取，不当作已执行证据（对齐 §17.1） | ✅ |

审计内容与 Prompt §17.2 既定 10 项事实逐条一致：事实 1（`>=` 判定，§2.1 L56）、2/3（平均半径/0.18/0.2s，§2.1）、4（冷却≠一次会话一次，§2.1 L85-87）、5（dlopen/dlsym 符号，§2.2 L120-141）、6（count<=0 忽略/无 device 参数/state!=0 活跃，§2.2 L70-95）、7（legacy 对齐注释未核实，§2.2）、8（pinchIn→show 仅采纳前者，§2.4 L144-149）、9（锁/owner/generation 非线程安全证明，§2.2/§2.3）、10（墙钟 Date，§2.1）。

### AC-2 ADR-013 覆盖 §18 决策表与 §24 要求 — ✅

| 要求 | 覆盖位置 | 结果 |
|---|---|---|
| 三路线比较 | `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md` §1.1（公开 API「本轮未找到可验证方案」/ 私有 MultitouchSupport 选定 / 兜底 BLOCKED） | ✅ |
| 窄例外边界 | §1.2（不解除 AppKit/WindowServer/tap/键盘监听禁令；Input Monitoring 独立说明用途/实测依据/降级，未经同意不申请、不自动打开系统设置；设备枚举成功≠权限授予） | ✅ |
| 来源边界 | §2（白名单 4 文件只读；REFERENCE_EXPOSED；不宣称 clean-room；不复制源码/测试/注释/文件结构；参数不沿用 0.18/0.2s） | ✅ |
| 识别会话 | §3（§19.2 十二条合同逐条 + §19.3 单调时钟/禁止直接相减 + 事件身份 generation/token） | ✅ |
| 设备隔离 | §4（保留 device 参数；两设备各两指不得组合 P09；热插拔不重复注册；零触点帧不吞） | ✅ |
| 锁序生命周期 | §5（§20.2 全部要点：回调禁窗口操作/一次主线程派发/串行队列或窄锁+积压策略/重入/锁外 user closure/有界缓冲保留 begin-end-cancel/过载丢帧保守重置/teardown 双失效/主线程消费验证 generation；§20.3：隐藏不 stop 采集/生命周期分离/Quit 停用/新 generation/不在 deinit 承担主要注销；P14/P15 可测） | ✅ |
| 输入交接 | §6（`show(source: fourFingerPinch, eventToken:)` 唯一入口；已显示/显示中/隐藏中/Quit 语义；会话结束优先；不全局吞事件；P19/M11；不破坏已验收翻页核心） | ✅ |
| 默认开关 | §7（`fourFingerActivationEnabled=false` 直到验证/获批；Enabled≠Ready；持久化只写开关及获批配置） | ✅ |
| 私有实现排除方式 | §8（编译排除 vs 运行时禁用区分表） | ✅ |
| 分发未评估 | §8（不做上架/签名/公证/公开发布结论；不通过隐藏符号/伪装调用规避审查） | ✅ |

§24「至少 8 项记载」实际覆盖 10 项，全部满足。

### AC-3 风险清单「用户确认后才运行采集实验」门 — ✅

- `Docs/FOUR_FINGER_RISK_REGISTER.md` §0 GATE 明确：「**用户确认本风险清单后，才允许运行采集实验（dlopen MultitouchSupport、设备枚举、回调采样）**」；未确认前只做纯逻辑与文档。
- §2 风险接受流程 4 步含「用户**明确确认**（记录原话范围）后才运行采集实验」。
- 7 项风险 R-01..R-07 与任务包列举逐项对应（私有 ABI 无公开文档 / state!=0 未分类 / 零触点帧丢弃 / 设备混流无 device 参数 / deinit dlclose 并发 / 枚举成功≠权限授予 / 系统更新兼容性），每项含来源证据、影响、缓解/验证计划、状态。
- 与 ADR-012 L59、PLAN §15 #10、ADR-013 §9 表述一致。

### AC-4 无采集实验 / dlopen / 真实触控板接触 — ✅

- ADR-013「实现注记」：未实现任何采集代码；未 dlopen；未触碰真实触控板；未读取白名单外 LaunchBetter 文件；未读取 Buho 逆向资料。
- 写集合规核查（git 无基线，以 mtime + 事件日志为准）：2026-09-05 修改的 `Sources/`、`Tests/` 文件全部归属 **T-1G-A**（LauncherPresentationState/Coordinator、HotCornerStateMachine、ScreenGeometrySnapshot、ShortcutRegistrationOutcome、ActivationSettings、AppDelegate + 对应测试）与 **T-1F-B11**（Bug11RowBoundaryIndicator、DragCommit、DragUI、FolderOverlay），无任何四指采集代码；`.build` 产物为 T-1G-A 构建，无 MultitouchSupport 相关符号。
- 事件日志（`Workflow/events.jsonl` seq 783-787）：T-G-P0 派发（Wave 1 并发检查，与 T-1G-A 并行）→ 18:32:20 中断（零产物落盘，审计为 Main 派发前版本）→ 同会话恢复 → 18:35:42 完成。符合 AGENTS.md 同会话中断恢复协议（不计 FAIL）。

### AC-5 诚实性 — ✅

- 零本机验证显式声明：审计头部「源码阅读证据，**不是运行结论**」+ §7 五项未核实 + §8.2.1「本轮**零项**经本机验证」。
- 无 clean-room 虚假声明：审计 §6、ADR-013 §2、`PROVENANCE/REFERENCE_EXPOSED.md` 均显式「不宣称 clean-room」。
- 「与 legacy 验证可用布局对齐」注释被一致标注为**未核实 legacy 声明**（审计 §2.2/§6/§8.2.1），非本机验证结论。
- 公开 API 路线如实记录「本轮未找到可验证方案」（ADR-013 §1.1，措辞对齐 §18.1「不能凭记忆承诺存在公开全局四指 API」）。
- 与 ADR-012 Q1 一致：ADR-012 L23 `fourFingerActivationEnabled | false | 直到验证/获批（ADR-013，G-P0 决策门）` ↔ ADR-013 §7；ADR-012 L59 采集门表述一致；ADR-011 L11 将 fourFingerPinch 列为协调器入口之一，无冲突。

### AC-6 写集合规 — ✅

- 变更集 = 4 交付文件（审计 §8 追加、ADR-013 新建、风险清单新建、REFERENCE_EXPOSED 新建）+ 结果文件，全部在任务包 Expected/Allowed Write Scope 内（Docs/ + PROVENANCE/ + Workflow/results）。
- 无 Sources/ 改动归属本任务；无整份源码复制（审计仅行号 + 短摘）；无白名单外 LaunchBetter 读取声明（REFERENCE_EXPOSED 边界声明）；无 Buho 材料。
- 不 commit/push/tag：仓库无任何 commit（`git log` 失败 = 无提交历史），无 tag。

---

## 2. Findings

### BLOCKER
- 无。

### MAJOR
- 无。

### MINOR
- **M-1**（PLAN 措辞，非交付缺陷）：`Workflow/PLAN.md:542` 将 T-G-P0 描述为「LaunchBetter 白名单 **6 文件**逐项审计」，实际交付为 **4 文件读取 + 2 测试文件仅定位未读取**——与任务包「白名单 4 文件已读」及 Prompt §17.1「本轮已读前四项的相关代码；测试文件仅定位」一致，交付物本身无缺陷。建议 Chief 后续修订 PLAN 时统一为「4 文件审计 + 2 测试文件定位」。

### QUESTION
- **Q-1**（行号引用一致性）：审计 §2.2 对同一引文「与 legacy 验证可用布局完全对齐」给出两个行号——L18-19（`Docs/FOUR_FINGER_REFERENCE_AUDIT.md:43`，代码事实节）与 L5（`Docs/FOUR_FINGER_REFERENCE_AUDIT.md:50`，注释 vs 事实节）。可能该注释在文件头（L5）与结构体前（L18-19）各出现一次，也可能一处行号引用有误。审计的核心价值是行级精确引用（§17.3 要求行号），建议 T-G-P1 前由 Main 核对一次并统一标注（如「L5 与 L18-19 两处」）。不影响本任务结论——该声明始终被标注为未核实 legacy 声明。
- **Q-2**（超出 §17.2 既定事实的细节待实机阶段复核）：审计 §2.3 权限检测细节（启动后 3s 单次 DispatchSourceTimer、无回调且设备枚举 0 → `.waitingForPermission`，L122-130/L242-254）与 §2.4 热键/冲突检查细节（L35-50/L182-189）超出 Prompt §17.2 的 10 项既定事实，本 Reviewer 受读取禁令无法独立验证。建议在 T-G-P2 真实后端获批后，由 Main 以实际文件为准复核这些行级事实（与 Q-1 一并处理）。

---

## 3. Verdict

**PASS** — 0 BLOCKER / 0 MAJOR / 1 MINOR / 2 QUESTION。

- **Confidence**: High。纯文档任务，全部验收标准可静态核对；唯一无法独立验证的是审计对参考源码的行级事实——受评审读取禁令约束，已通过「Prompt §17.2 既定事实交叉核对 + 文档内部一致性 + 写集合规核查」覆盖，且审计自身已显式声明零本机验证、不宣称 clean-room。
- **后续门（本评审不改变）**: 用户确认 `Docs/FOUR_FINGER_RISK_REGISTER.md` 后才运行采集实验（§0 GATE；PLAN §15 #10）；T-G-P1/P2(Mock)/P3 纯逻辑可继续。
- **Memory candidates（供 Main 门控）**: 与 Worker 结果一致——四指后端路线定案（私有 MultitouchSupport 窄例外，用户已接受）；`fourFingerActivationEnabled=false` 直到验证/获批；采集实验门 = 用户确认风险清单；参考实现关键事实（`>=4` 拒绝沿用、冷却≠一次会话一次、state!=0 未分类、回调无 device 参数、deinit dlclose 并发、枚举成功≠权限授予）；本轮零项本机验证。
