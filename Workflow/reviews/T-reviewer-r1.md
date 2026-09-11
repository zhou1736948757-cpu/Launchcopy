# Reviewer E 审查报告 — T-reviewer-r1

- **审查者**：Reviewer E（ollama/glm-5.3-flash:cloud，max；独立只读审查）
- **日期**：2026-08-28
- **任务**：T-reviewer（依赖 T-step7 完成；本报告为 CODE_REVIEWED / SOURCE_REVIEWED / VISUAL_NEUTRALITY_REVIEWED 回填证据）
- **审查输入**：Prompt §3/§7/§8/§9/§11/§12/§13/§16；PROVENANCE/ 三件套；Docs/ 七份；Sources/ 19 文件；Tests/ 13 文件（6138 行）；Workflow/results/ 7 份；PLAN.md / MAIN_BRIEF.md；Package.swift / README.md / .gitignore / AGENTS.md / MEMORY.md；决策记录 1 份
- **审查方式**：全文通读 + 独立复跑静态扫描（grep/find/git/strings，只读；未执行构建或测试——任务包 Out of Scope）

## Reviewer E 本人访问声明（供 Main 登记 ACCESS_DECLARATION）

本人（Reviewer E，本会话）在本次审查期间：**未读取** BuhoReverseNotes、LaunchBetter/Packages、LaunchBetterApp、2026-08-25-buho-launchpad-reverse、Launch_Copy 三份治理文档（RISK_REDUCTION_PLAN / CONTEXT_LEDGER / SOURCE_MANIFEST）。读取范围仅限：主 Prompt、PagingPrototype 项目内文件、`/tmp` 下本项目 telemetry 产物（`ls`/`head` 抽查）。**NO_PRIOR_EXPOSURE（本人确认）**。

---

## Verdict

# **PASS**

无 BLOCKER、无 MAJOR 级 Finding；5 项 MINOR + 2 项 QUESTION（均为文档回填滞后、注释一致性与边缘 UI 行为，不构成来源纪律、诚实标记或架构独立性缺陷）。7 项审查范围全部完成，验收标准 8/8 满足。

---

## Findings

### MINOR

**M-1｜PROVENANCE 登记滞后：COMPONENTS.md 全部组件仍 NOT_STARTED；ACCESS_DECLARATION.md 表格状态未回填**
- 组件已全部交付并通过 T-step7 验证，但 `PROVENANCE/COMPONENTS.md:11-19` 八个组件状态仍为 NOT_STARTED/PARTIAL，其自承诺的回填项（规格版本/hash、实现者访问声明、来源审查结果、验证证据）一项未回填。
- `PROVENANCE/ACCESS_DECLARATION.md:17-21`：Chief 仍"待确认"、Worker B/C/D 仍"待确认"、Explorer A 仍"待派发确认"——而三位实现 Worker 的**亲笔声明实际已存在**于各自结果文件（T-worker-b.md:6-9 列明仅读 6 份输入；T-worker-c.md:6-12 逐项列出未读清单；T-worker-d.md:6 与 T-step6.md:6；T-explorer.md:146 尾注）。声明机制（ACCESS_DECLARATION §1：Main 收到结果后登记）的登记步骤未执行。
- **定性**：无代签迹象——Main 如实保留"待确认"而非代签"未接触"，实质声明由各 Worker 本人在结果文件给出且措辞各异（符合"禁止统一代签"）。属登记滞后，非诚实性问题。
- 证据：文件+行号如上；对照 `Docs/IMPLEMENTATION_LOG.md:140-147`（组件均已交付）。

**M-2｜PARAMETER_RATIONALE 验证结果列未在 T-step6 后回填；缺"修改日期"列；§3 平台表缺"合法范围"列**
- 文档头部（PARAMETER_RATIONALE.md:6）承诺"标 TUNING_REQUIRED 的参数需经 Step 6 性能实验或物理门验证后回填验证结果"；T-step6 已完成（自动可测指标全部达标，IMPLEMENTATION_LOG.md:114-121），但 §1 交互参数 11 项验证结果仍全部为 TUNING_REQUIRED、§2/§3 仍"待验证/待 accessibility 验证"。TUNING_REQUIRED 语义上仍成立（物理调参未发生，自动化 baseline ≠ 参数验证），但按文档自身承诺应回填"自动化 baseline 通过、物理待 T-step8"类状态。
- Prompt §9/§3.E 要求每参数含"修改日期"；本文件仅有文档级变更记录（§5），无逐参数修改日期列。§3 平台参数表（:35-40）缺"合法范围"列（§1/§2/§4 表均有）。
- 证据：PARAMETER_RATIONALE.md:6,10-22,26-31,35-40。

**M-3｜velocityContribution 注释与合法范围不一致**
- `Sources/PagingCore/PageTargetPolicy.swift:72` 注释 "velocityContribution：0=纯位移，1=纯速度"，而合法范围为 0.0–0.5（PageTargetPolicy.swift:53-54 头注、PagingParameters.swift:53-54、PARAMETER_RATIONALE.md:15）。代码行为（blended = ratio + w×v/vMax，w∈[0,0.5]）正确，仅注释失真。

**M-4｜PagingSurface.layout() 仅守卫宽度，高度单独 resize 不触发重布局**
- `Sources/PagingUI/PagingSurface.swift:510-519`：仅当 `|bounds.width − lastLayoutWidth| > 0.5` 才 setPageWidth + relayoutPages。窗口**仅高度变化**时 live host 保持旧 frame 高度（host 高度由 relayoutPages 写入，:483,492）。§7.3 "resize 后所有页面重新对齐"的宽度路径已被 `testResizeRealignsAllPages` 覆盖，高度路径未覆盖（测试均只改宽度，如 PagingSurfaceInterruptionTests.swift:126）。不影响状态机/偏移正确性（宽度未变则 Core 无需 rebase），属视觉边缘缺陷。

**M-5｜README.md 快速开始仍为占位**
- `README.md:29-32`："快速开始（Step 1 后可用）：待规格与 Package.swift 完成后补充构建/运行说明"。源码已可构建运行且 README 状态行（:9"Step 0 完成，规格/ADR 进行中"）过期。T-step8 用户物理验收需要可操作的构建/运行/参数说明；当前仅 IMPLEMENTATION_LOG 内有零散命令记录。

### QUESTION

**Q-1｜Worker B 与 Worker D 为同一 fresh member 顺序承担，PLAN 角色表未注明**
- T-worker-d.md:3（"本 worker 亦为 PagingCore 作者；Core 于早前完成"）+ T-worker-b.md:4：B/C/D 均由同一 fresh member（ACCESS_DECLARATION.md:20 登记为 subagent f0484f47，deepseek-v4-flash:0731）顺序完成；PLAN.md:177-188 将 B/D 列为两个独立 fresh worker 行。
- **不构成违规**：§1.2/§12 的 fresh 要求针对"继承旧逆向上下文"，该成员零接触且写入范围互斥得到遵守（顺序执行，Main 有运行时顺序决定权）；声明文件实际已按单一 subagent id 如实登记。建议在 PLAN.md 或结果文件补一句"运行时串行同人执行"以保计划-执行可对照性。

**Q-2｜TransitionContext.createdAt 在 resize/pageCount/RM 重启路径恒为 0**
- `Sources/PagingCore/PagingCore.swift:285,337,355`：非手势发起的 beginSettle 传 `createdAt: 0`，与字段注释"创建时间戳"（TransitionContext.swift:48-49）语义不符。该字段不在 17 必需 telemetry 字段内，仅影响可选诊断关联。

### 结构相似性审查的固有局限（声明，非 Finding）

审查纪律禁止（本人也未）读取旧项目代码，故第 6 项无法做逐行/常量对照。判定依据为正面证据链：(a) ADR-001 记录 5 个被否决方案及理由（ADR-001 §4）；(b) 边界阻尼作用于**越界增量**而非绝对位置、momentum 作为 tracking 子阶段、闭式 spring 解 ω0=ln(100)/(ζ·T) 推导——均为有文档的独立设计选择（PagingCore.swift:539-564,566-588；T-worker-b.md:104-106）；(c) 测试命名与组织逐一对应 **Prompt §7.1/§7.2 的公开枚举清单**（51+7 用例名与任务包场景表对齐，非外部结构）；(d) 23 参数均有合法来源类别+范围+理由，初始值（0.35/250ms/0.85/800px/s 等）标 TUNING_REQUIRED，无"精确参数簇"无解释匹配迹象。该结论为"未发现不独立迹象"，不等价于证明独立性——与 Prompt §11.3"扫描不是原创性证明"的边界一致。

---

## 7 项审查范围结论（逐项）

### 1. 来源纪律 — ✅ 通过
- **访问声明**：每位参与者均有独立自述（Main=PRIOR_EXPOSURE 已声明本人；Chief/Worker/Explorer/Reviewer 有声明或亲笔确认）；无统一代签迹象（Main 宁可标"待确认"也不代签）。登记滞后见 M-1。
- **污染日志**：CONTAMINATION_LOG.md 无事件（:18-21）。代码侧独立扫描未发现污染迹象，与空日志一致。
- **越界迹象扫描（本人独立复跑，命令+退出码）**：
  - `grep -rniE "buho|launchbetter|launchpad|decompil|disassembl|reverse.?engineer" Sources/ Tests/ Package.swift` → **仅 2 命中**：PagingTelemetry.swift:32、PagingParameters.swift:9，均为规格要求的**禁止性说明注释**（与 IMPLEMENTATION_LOG.md:142"唯一匹配为规格要求的禁止性注释"一致）。
  - 禁止路径片段（BuhoRebuild/BuhoReverseNotes/2026-08-25/LaunchBetterApp/Packages）→ 0 命中（exit 1）。
  - `/Users/mac` 绝对路径：Sources/Tests 内 0 命中（exit 1）；文档内 4 处均为工程自身/Prompt 路径（IMPLEMENTATION_LOG.md:18,25；PHASE1_SPEC.md:6；MEMORY.md:36），与"3 处工程自身路径"记录一致（另 MEMORY.md 1 处同性质）。
  - 旧项目字段名/常见换皮词（launchpad/gridview/collectionviewitem/foldercell/appiconview/springboard 等）→ 0 命中。
  - bundle id / CFBundle / os_log subsystem → 0 命中。
- **来源扫描 8 类覆盖（独立复验）**：①源码/测试 ✅（上述）②文档 ✅（Buho/LaunchBetter 字样 8 处全部为禁止性声明/扫描记录，PHASE1_SPEC.md:48,56,101,134、ADR-001:93、ADR-002:73、ACCESS_DECLARATION:17、IMPLEMENTATION_LOG:21,77,143）③资源 ✅ 无 xcassets/plist/entitlements（find 0 结果）④Info.plist ✅ 不存在 ⑤Git history ✅ `git log` → "does not have any commits yet"；`git status` 仅未跟踪文件 ⑥构建产物 strings ✅ 本人对 release 二进制复跑 `strings | grep -icE "buho|launchbetter"` = **0**；`launch-copy-paging-prototype` = 1（输出文件名前缀，正当）⑦绝对路径 ✅（上述）⑧扫描定性 ✅（IMPLEMENTATION_LOG.md:138 明确"仅是泄漏预警，不是原创性证明"）。

### 2. 参数来源文档 — ✅ 通过（M-2 为回填滞后）
- 23 参数逐一核对 `Sources/PagingCore/PagingParameters.swift` ↔ `Docs/PARAMETER_RATIONALE.md`：默认值/范围/类别一一对应，代码注释含来源类别。禁用三类（REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN）**0 使用**（Parameters 文件头 :9 即禁止性注释）。
- 无法解释参数均标 TUNING_REQUIRED（11 项交互参数 + momentumDecay/velocityThreshold）；无 UNKNOWN_ORIGIN 掩盖。
- 每参数有选择理由；验证结果列滞后见 M-2。

### 3. 自动化诚实性 — ✅ 通过
- VALIDATION_RESULTS.md 状态 8 项分开记录（:7-16），格式与 §13 完全一致。
- 未执行 gate 无一虚标 PASS：CODE_REVIEWED/SOURCE_REVIEWED/VISUAL_NEUTRALITY_REVIEWED = **NOT_RUN**（明确"待 Reviewer E"）。
- `exit_code==0 且 tests==0` 防线：AUTOMATED_TESTS 行明确"executed > 0，非 INVALID_TEST_EXECUTION"（:11）；本人独立清点测试函数：Core 44+7=51、Telemetry 11+5+17=33、UI 12+4+8+5+13+2+12=56 → **合计 140**，与宣称完全吻合。
- 自动化未夸大为物理门：VALIDATION_RESULTS 诚实边界（:28-34）明确"全部为自动化验证，不是物理验收"；§8.5 主观三项与真实帧节奏标"未执行"。
- 异常 run 全保留：`/tmp/launch-copy-paging-prototype-*.jsonl` 9 个日志 + perf-bench/gui-selfdrive stdout 工件**本人核实全部存在**（ls 输出见审查过程），无删除迹象。

### 4. 物理门诚实标记 — ✅ 通过
- MANUAL_PHYSICAL_GATE_60HZ = **NOT_RUN**（:15，"待用户 T-step8"）；MANUAL_PHYSICAL_GATE_120HZ = **NOT_RUN**（:16，"无 120Hz 证据前不得 PASS"）。两门均未被标 PASS。✅
- 无 60Hz→120Hz 推断：全文无任何 120Hz 结果声明；frameMissTarget120Hz 仅为参数目标（PagingParameters.swift:128）。
- Synthetic probe 诚实区分（核查 T-step6 帧泵）：
  - `PagingSurface.simulateScrollInput/simulateFrame` 公开缝注明"**不作物理验收门**（真实触控板验收见 T-step8）"（PagingSurface.swift:273-275,294-297）。
  - AppDelegate runloop 回退泵注明"明确标注为 synthetic 帧源（真实 display link 节奏属物理门 T-step8）"（AppDelegate.swift:137-138）+ 静默检测日志（:125）。
  - PerfBenchmark 头注"这是 synthetic 脚本输入，只作回归预警"（PerfBenchmark.swift:21）。
  - T-step6 结果将 run1（display link 静默，零帧）与 run2（回退帧泵）分开记录，且"真实 display link 帧节奏：**NOT_RUN**"（T-step6.md:56）；VALIDATION_RESULTS 诚实边界重申"真实显示节奏验证依赖 T-step8 人工"（:32）。**未发现 synthetic 冒充物理门**。✅

### 5. 命名中立性 — ✅ 通过
- 使用的均为 §11.2 白名单词汇：PagingState / GestureSession / TransitionContext / PageTargetPolicy / PageHostView / PagingSurface / PagingFrameDriver（FrameTelemetry 语义由 PagingTelemetryBridge+TelemetryEvent 承担）。全库无 Buho 身份、无反编译地址（0x 长十六进制 0 命中；@objc 仅 CADisplayLink selector，平台必需）、无"原类型一一对应"含义命名。
- 无旧 bundle id / 日志 subsystem / 旧临时文件名：telemetry 前缀固定 `launch-copy-paging-prototype`（PagingTelemetry.swift:32,40，即 Prompt §6 指定形态）；队列标签 `launch-copy.paging-telemetry.session`（TelemetrySession.swift:57）；窗口 autosave "PagingPrototypeWindow"。均中性。✅

### 6. 结构相似性 — ✅ 通过（受固有局限约束，见上方声明）
- 状态机五状态+momentum 子阶段与 ADR-001 D1 逐条对应；实现为需求驱动的新设计（单调 token 三防线、增量式边界阻尼、闭式 spring、momentum 滑行 tick 驱动），每个非常量均有文档出处（PARAMETER_RATIONALE 或"实现细节常量"注释，PagingCore.swift:93-103）。
- 测试组织按 Prompt §7.1（44）/§7.2（7）/§7.3（6 判据）/§3.F（6 门禁+1）/§7.4（4+1 探针）公开需求映射，未见照搬外部组织。
- 无与旧项目"一一对应"的未解释结构（在禁止对照旧码的前提下，以独立理由文档完备性判定）。

### 7. ADR 完整性 — ✅ 通过
- **ADR-001 回答 §3.G 全部 7 问**：①语义页所有者→D1（Core/committedPage，commit 时机界定）②视觉偏移所有者→D1（Core/visualOffset 唯一所有权）③gesture session 起止→D1 + 生命周期（began 创建→ended/cancelled/finishGesture；momentum 子阶段，Worker B 偏差 #1 有记录）④settle 识别与取消→D2（display link 手动插值 + cancel flag/驱动停止）⑤旧回调提交资格→D3（token+commitState+hasCommitted 三防线，代码 TransitionContext.swift:7-10,65-72 落实）⑥resize/pageCount→D6（三分支，代码 setPageWidth/setPageCount 对应）⑦teardown 无残留→D7（isTearingDown 第一时间置位 + 全入口短路，代码 teardown():381-395 与测试 testTeardownStopsAnimationDriver/testWindowCloseDuringSettleLeavesNoResidual 验证）。
- **ADR-002 两方案比较 + 被否决方案**：方案 1/2 优缺点齐备（§2），决策理由 5 条（§3.1），被否决项明确（§3.2：方案 2 直接启用、每帧重建 view tree）。✅
- **设计者接触声明**：两 ADR 各含独立声明节（ADR-001 §5、ADR-002 §6），如实披露"读过治理文档（审计摘要）、未读源码"，与 ACCESS_DECLARATION Main 行一致。✅

---

## Likely Root Cause（针对全部 MINOR）

- M-1/M-2/M-5：**回填型文档缺少收尾任务路由**。T-step7 的验收标准未包含"PROVENANCE 回填 / 参数表回填 / README 更新"，T-step8 任务包（未在本次审查输入中）预计只覆盖物理门准备——三处滞后属任务边界缝隙，非隐瞒。
- M-3/M-4：**实现细节自检盲区**——注释与实现分离演化；layout 守卫按"布局风暴"核心关切（宽度）设计，高度边缘路径未被 §7.3 测试枚举覆盖。

## Recommended Solution（建议，非修复授权）

1. **M-1**（Main，T-step8 前）：把 T-worker-b/c/d、T-explorer、Chief 的亲笔声明登记进 ACCESS_DECLARATION 表（状态改"已确认（本人，见 results/…）"）；COMPONENTS.md 回填各组件规格 hash/声明引用/验证证据引用，状态改 DELIVERED。
2. **M-2**（Main）：PARAMETER_RATIONALE 验证结果列回填"自动化 baseline 通过（T-step6）/物理待 T-step8"，保留 TUNING_REQUIRED 至物理门；补逐参数"修改日期"列；§3 表补"合法范围"列。
3. **M-5**（Main，T-step8 交付物）：README 补构建/运行/参数与 telemetry 用法（`swift run PagingPrototypeApp --page-count 5 --paging-lab` 等），并更新状态行。
4. **M-4**（可选，Worker D 下波或 T-step8 后）：layout() 守卫放宽为"宽度或高度变化"；补一条高度 resize 测试。
5. **M-3**（顺手微修）：PageTargetPolicy.swift:72 注释改为"0=纯位移，>0 位移为主速度为辅（合法上限 0.5）"。
6. **Q-1/Q-2**：PLAN.md 或 T-worker-d 结果补一句"运行时串行同人执行"备注；createdAt 语义可在 D6 路径传实际时间戳（或注释说明 0=非手势发起）。

## Affected Scope

- 全部为**文档/注释级**：PROVENANCE/、Docs/PARAMETER_RATIONALE.md、README.md、代码注释（M-3）、一处可选行为边缘（M-4，PagingSurface.layout）。
- **无来源纪律问题**：Sources/、Tests/、Package.swift 无需为来源纪律返工；无组件需要 BLOCKED_FOR_REVIEW。

## Regression Risks

- 文档回填（1/2/3/6）：无代码风险；注意只由 Main 写 Docs/PROVENANCE/（写入范围纪律）。
- M-4 修复：改动仅 layout 守卫分支，需回归 `testResizeRealignsAllPages`、`testResizeSameWidthDoesNotRelayout`、`testResizeDuringSettlingRebasesAndRealigns` 三个既有测试，防把"宽度守卫防风暴"放宽为每帧布局。
- M-3 注释修改：零行为风险。

## Confidence

**高**（约 90%）。
- 高置信项：禁词/路径/命名/物理门/自动化诚实性/ADR 完整性——均有本人独立复跑的命令级证据（grep/find/git/strings 退出码 + 工件存在性核实）。
- 中高置信项：结构相似性——受"禁止读取旧项目"纪律约束无法做对照证明，结论基于独立理由文档、测试与公开需求枚举的对应关系及无换皮痕迹；此为该审查项在设计内的能力边界（Prompt §11.3 亦声明扫描非原创性证明），已在报告中专节声明。
- 未覆盖（如实声明）：未执行构建/测试（Out of Scope，采信 T-step7 的 140/0 记录，其 executed>0 声明与本人清点的 140 个测试函数一致）；未验证 LaunchBetter/BuhoReverseNotes 目录是否被外部修改（该目录对本人属禁止读取范围，采信 IMPLEMENTATION_LOG 声明 + 本项目内无反证）。

## 验收标准自查

- [x] 来源纪律审查完成（声明逐人核实、污染日志空、越界迹象独立扫描 0、8 类覆盖复验）
- [x] 参数来源文档审查完成（23/23 合法类别、禁用 0、TUNING_REQUIRED 核实）
- [x] 自动化结果诚实性审查完成（状态分离、140>0、无虚标 PASS）
- [x] 物理门诚实标记审查完成（60Hz/120Hz=NOT_RUN、无推断、synthetic 诚实区分）
- [x] 命名中立性审查完成（白名单词汇、0 命中）
- [x] 结构相似性审查完成（独立理由文档完备、无未解释映射；局限已声明）
- [x] ADR 完整性审查完成（§3.G 7 问 7 答、两方案+否决项、接触声明）
- [x] 报告含 Verdict / Findings / Evidence / Root Cause / Recommended Solution / Affected Scope / Regression Risks / Confidence

---

*报告结束。Reviewer E 独立只读审查；本报告不构成修复授权。后续路由（含是否需要 FAIL#1 升级）由 Main 决定。*