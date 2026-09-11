# T-1F-B10-regression-fix — 主页面点击全死回归（取证先行 + 条件修复）

Status: ready（Chief 诊断完成；**取证步 §2.1 为硬前置，未完成取证禁止进入 §2.2 实现**）
Wave: BUG10-regression-fix（与 wave-a-fix 领地不交集；AppDelegate 与 wave-b 区域不交集）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并
关联: Workflow/BUG10-REGRESSION-REPORT.md（Chief 诊断，权威）

## §1 根因（带行号；Chief 诊断结论）

- **症状**：冷启动 8 次点击，7 次窗口层判 cell 放行（s8d ×7、s17_ov0 ×7），但 `AppGridCellView.mouseDown` 从未触发（s10=0）、surface 手势零启动（sA=0）、overlay 零参与（s14=0、s16=0）。事件在窗口层与 cell 之间被整体吞掉，**未进入 surface 子树**。
- **wave-b 排除**：`setVisualHost`（Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:202-205）与 `setHost`（Sources/AppGridUI/DragUI/DragUIVisuals.swift:65-73）唯一驱动点 = `refreshFolderOverlay`（Sources/PagingPrototypeApp/AppDelegate.swift:835-855），三个调用点 :764/:792/:826 全部要求 folder 交互；冷启动路径（:66-305 → :312-455 → :454 installDragUI）零调用；s16=0 证明 closeFolder 未运行。**wave-b 冷启动休眠，非直接原因。**
- **同源性**：症状与 BUG9 wave-a 修复前逐字相同（BUG9-REPORT §1「s8d 增、s10 零输出」）；run2 中段已现 23 次连续 s8d 不增 s10（BUG10-FIX-PROMPT §4.1 :71-115，当时 Path A 仍活掩盖 Path B 死）。死态先于 wave-b 存在。
- **已排除**：hitTest 漏斗坐标语义（探针实证：point 为父视图坐标系，`frame.contains` 正确，Sources/AppGridUI/AppGridCellView.swift:215-217）；子视图拦截（漏斗返回 self）；overlay 残留（s14/s16/s17_ov0）；R5 激活（s8e key1_active1）；R2 抑制滞留（s13a/s13b/s9b 零输出）。
- **已推翻候选**：①原始表述（手动 vs 内部 hit-test 不同源）被 probe 读数数值推翻——内部 hit-test 命中同一 cell 的 7/13 次同样不投递（s10=0）。断点不在 hit-test 结果，而在 **hit-test 之后、mouseDown 分发之前**。②构建陈旧：本波基线 1089/0 强制重建 + 探针读数齐全，基本排除。③既有间歇死态：与 f 合并（同一机制假说）。**e（窗口归属不一致）：E1 13/13 一致，排除。**
- **现行候选（按强弱排序，源 §8/§10/§12 REPORT）**：
  - **触摸类事件路由缺失：已排除（§14 A1）**——A1 换输入（USB 鼠标，/tmp/bug10_a1_swap.log）subtype=0 30/43 亦死、s10 恒 0 → 「事件类型无关」，**本行作废，T1（触摸规范化）不得基于此假说实现**。
  - **f) 命中视图缓存/跟踪会话滞留**（弱化）：E5 relayout 仅首击（yes 1/no 2-9），与 absent 切换（第 4 击起）不同步 → 本轮无支撑，保留为次候选。
  - **b) 全屏过渡窗口状态**：AppDelegate.swift:908-914「全屏过渡吞识别器」注记先例；过渡异步（:273-276）；过渡吞掉 mouseDown/mouseUp 对 → 识别器/跟踪会话滞留。
  - **g) 投递目标=中间层视图**（并入 f 族）：Main 核验 s18_delivered_contentview=0；E6a' 实证 AppGridPageView 亦零 → 投递目标排除集={cell, contentView, AppGridPageView}；剩余 PagingUI 层或 AppKit 内部处理（与触摸假说观测等价）。
  - **h）AppKit 内部分发层吞事件：§15 E4 结果 A 定罪完成（现行根因定论）**——手动投递 1:1 触发 s10（sE4 16==s8d 16==s10 16）证事件链/视图层健全，断点实证在 AppKit 内部分发层（super.sendEvent 后 mouseDown 不到视图）；B 运行副产物（无闭环 → state 卡 .pressed，DragSessionController.swift:67-71）定义 **B1 修复必须含 up/dragged 投递闭环（§2.2/§15）**。
  - **c/j) 系统级手势/事件拦截**：E6b 未现 button 变体（button=0），出现的是 subtype=3（触摸合成）；换输入复测未做——与触摸假说共享判别路径。
  - **i) 坐标基准**：E6c 真空白对照通过（s8c 触发、空白退出正常）→ 窗口层 hitTest/空白判定链健康 → **i 基本排除**。
- **健康侧证**：sA_launch_accepted=1 via Return 键（键盘路径健康）；翻页正常（scrollWheel）；空白退出正常（E6c s8c 1）；**唯独 AppKit 内部 mouseDown 投递链死**——与「触摸事件不投递标准 mouseDown」精确吻合；死态先于探针合并（forensics 波已死），探针非因非果。
- **§13 裁决（源审阅对照，Chief 落盘）**：主因=触摸类 mouseDown 投递缺失（census 定罪，A1 为定罪门槛）；潜因=激活顺序倒置（AppDelegate.swift:276/:281，潜伏缺陷→H1 加固，s8e key1_active1 9/9 数值排除其为现行机制）；Buho 手动投递=仅 h 定罪时兜底参照（B1）。三份 digest 仅参考、禁止照搬。**（§14 A1 更新：触摸主因已被数值排除；h 升为现行最强，B1 资格达成——T1 作废，现行修复收敛到 E4 二分后的 B1 系。）**

## §2 修复规格

### §2.1 取证步（硬前置；零行为优先，E4 例外须隔离）

**已完成观测（E6 波，读数 /tmp/bug10_e6_run.log）：**
- E6a'（AppGridPageView sink）：零输出 → 投递目标排除集={cell, contentView, AppGridPageView}。
- E6a''（local monitor）：down/up 各 9/9 → 事件进入 NSApp 分发层。
- E6b（事件元数据）：type=1 subtype=3 button=0 全 9 击 → 触摸合成事件。
- E6c（真空白对照）：s8c 触发、空白退出正常 → 窗口层判定链健康，i 基本排除。
- E1/E5：E1 13/13（e 排除）；E5 relayout 仅首击 1（f 弱化）。

**已完成观测（A 波，/tmp/bug10_a1_swap.log，43 击 USB 鼠标）：**
- **A1 换输入**：subtype=0 30/43 亦死、s10 恒 0 → **触摸假说数值排除、「事件类型无关」** → 按 §9 判别表既定分支 **转 E4（h/f 系）**（§14）。
- **A2 会话切换观察**：internal present 8 / absent 34，无触摸会话式稳定切换特征。
- 复测脚本已执行（PAGING_CLICK_CENSUS=1，对照 run2 正常段 / E6 波读数）。

**已完成（E4 波，/tmp/bug10_e4_a_run.log + /tmp/bug10_e4_b_run.log）：**
- **E4 结果 A 实机确认（h 定罪完成，§15）**：门控开 `sE4 16 == s8d 16 == s10 16`——手动投递 1:1 全触发 cell.mouseDown → 事件链/视图层健全，断点 = AppKit 内部分发层。
- **E4 B 运行副产物（决定修复设计）**：s6=0、sA=0、s13a/s13b/s9b 各 3；空白退出失效（s8c=0、s8b 吞 1）、ESC 退不出——手动投递无闭环 → state 卡 .pressed（DragSessionController.swift:67-71 cancel(.secondDrag)）→ **生产候选必须实现 up/dragged 投递闭环**。
- **4b 补读**：启动瞬间 keyActive=false（AppDelegate.swift:276/:281 顺序倒置的运行级证据）；点击时 s8e key1_active1 全击 → **并入 H1 观察项（§15 ③，不另立任务）**。

**现行硬门槛：B1 候选验证（env 门控 `PAGING_CLICK_MANUAL_DELIVERY=1`，默认关；按 §2.2 B1 定案行实现后 A/B 对照）：**
- 基线（门控关，10+ 击）：s10=0、sA=0、计数与 A 运行（35-38 击）一致 = 生产路径零行为变更自证。
- 候选（门控开，10+ 击）：s10 增量=击数、s5 增量≥击数（up 闭环）、s6>0、**sA_launch_accepted>0（点击启动）**、连续多次点击正常（无 stuck-.pressed，s13a/s13b/s9b 不异常抬高）；空白退出 s8c 正常；ESC key53 正常；拖拽预览正常。

### §2.2 条件修复（取证命中后按行执行；未命中禁止实现）

- **命中触摸路由缺失（A1 定罪：subtype=0 且 s10>0）**：**作废（§14——A1 已验 subtype=0 亦死 s10=0）。T1 不得实现。**
- **H1 激活顺序加固（潜因，独立低风险提交；§13 裁决——非本回归的现行修复）**：将 `NSApp.activate(ignoringOtherApps: true)`（:281）提前至 `makeKeyAndOrderFront`（:276）之前（X2 f6f7f1b 教训：makeKeyAndOrderFront 在未激活应用下不会真正置 key，macOS 会把首次 mouseDown 作激活点击吞掉；本项目顺序与之相反）。**s8e key1_active1 9/9 已数值排除其为现行死态机制 → H1 必须独立标注为潜伏缺陷加固，不得以「修复回归」名义捆绑提交**；单独验证（冷启动首击即达 + 全量回归），Reviewer 独立审查。写范围：仅 `Sources/PagingPrototypeApp/AppDelegate.swift` 启动序（:273-281 区域）；冻结树/wave-b 领地零触碰。
- **B1 生产修复候选（§15 定案——h 定罪完成，现行唯一修复行；E4 结果 A 实机确认）**：env 门控 **`PAGING_CLICK_MANUAL_DELIVERY=1`**（默认关；与诊断探针门 `PAGING_CLICK_PROBE_MANUAL_DELIVERY` 分离——probe 为无闭环二分器，候选含闭环）。行为层规格：
  - ① **leftMouseDown 命中 cell**（现有 :1136-1139 判定）：手动 `hit?.mouseDown(with: event)` + 记录 `lastManualMouseDownView`（weak）→ return（不调 super）；
  - ② **leftMouseUp**：记录非 nil → 投记录视图 `.mouseUp(with: event)` → 清记录 → return。**闭环关键环**：cell.mouseUp → coordinator.pointerUp（:305-377，s5 :351）→ endSession（:329/:343，s9b :508）→ dispatchClick（:484-492，s6 :486）→ onCellClick（:590-592）→ sA launch；
  - ③ **leftMouseDragged**：记录非 nil → 投记录视图 `.mouseDragged(with: event)` → return（拖拽链 AppGridCellView.swift:197-205 → coordinator s4a-s4c）；
  - ④ 空白分支（非 cell）、记录 nil 的 up/dragged、ESC key53（:1089-1092）维持原 `super.sendEvent` 语义零触碰；**窗口失 key / ESC 打断时清记录**（防 stale，B 运行边界外防护）。
  - 验证零新增 census sink（复用 s10/s0/s1/s3 + s5/s9b + s6 + sA）；**禁止照搬 Buho 实现（行为层结论仅参照，§13/§14）**；验证通过 + Reviewer 显式 PASS 后由 Main/Chief 定案转正（**默认关状态不得擅自转正**）。写范围：仅 `Sources/PagingPrototypeApp/AppDelegate.swift` sendEvent + 门控常量；冻结树/wave-b 领地/FolderOverlayView/DropIntent/DragParameters 零触碰。
- **命中 e（窗口归属不一致）**：**已排除（E1 13/13），本行作废。**
- **命中 f（命中视图缓存/跟踪会话滞留）**：修复方向 = 使滞留的投递目标失效并复位——视图层级重建（relayoutPages / refreshPresentation）后从 AppDelegate 侧触发窗口命中状态复位（如 `window.invalidateCursorRects(for:)` 类轻量机制或重挂触发），或在复用池清空（PagingSurface.swift:760-765 clearForReuse+removeFromSuperview）后同步复位；若 E6a 证实投递目标=contentView → 确保 contentView 永不成为跟踪目标（拦截期不把事件交给 contentView 处理）。**只动 AppDelegate 层观测/联动或探针层，PagingUI/PageHostView 冻结零触碰。**
- **命中 g（投递目标=中间层视图）**：修复方向 = 与 f 同族——复位窗口跟踪状态（invalidateCursorRects 类/复用池清空后复位）；若 E6a' 证实投递目标=AppGridPageView → 在 relayout 复用池操作后从 AppDelegate 侧触发窗口命中状态复位（方案回 Main/Chief 定案）。
- **命中 h（窗口级消费/事件被标记 handled）**：修复方向 = 在 sendEvent 放行分支对事件做规范化（如重建/重发事件副本）后再 super.sendEvent；或 E4 手动投递作为兜底路径（env 门控转正需 Main/Chief 定案）。
- **命中 c/j（系统级手势拦截）**：无代码修复；结果文件记录用户侧排除结论（关三指拖移/轻点、换 USB 鼠标复测对照），若恢复 → f/b 候选降权、c/j 定型为用户环境项。
- **命中 b（全屏过渡状态）**：修复方向 = 过渡标志核验/时序对齐——记录 `windowDidEnterFullScreen`/`windowDidExitFullScreen` 到达时序，核验启动异步过渡（:273-276）结束前事件是否被吞；若命中 → 在过渡完成前屏蔽窗口层拦截或延迟 installDragUI 时序（方案回 Main/Chief 定案）。
- **命中 i（contentView 坐标系/帧失配）**：修复方向 = 核验 contentView（探针）frame 与窗口 content 区域一致（全屏/非全屏两态），失配则对齐 frame（方案回 Main/Chief 定案）。
- **命中②（构建陈旧，残留兜底）**：重建后复测，无代码修复；结果文件记录重建证据。

## §3 写范围

- 取证步：`Sources/PagingPrototypeApp/AppDelegate.swift`（仅 sendEvent 放行分支的只读观测 + 探针视图声明 + E6a'' local monitor，零行为变更）+ `Sources/AppGridUI/AppGridPageView.swift`（**仅加 mouseDown/mouseUp 纯转发 census sink，零行为变更**）+ 测试（探针触发/类名链断言，新文件或并入既有，报告声明）。
- 条件修复（现行唯一命中行 = **B1，§15 定案**）：`Sources/PagingPrototypeApp/AppDelegate.swift` — QuitOnBlankClickWindow.sendEvent 增门控 leftMouseDown/leftMouseUp/leftMouseDragged 手动投递闭环 + `lastManualMouseDownView`（weak）记录 + env 门控 `PAGING_CLICK_MANUAL_DELIVERY`（默认关）；零新增 census sink（复用 coordinator 既有 s10/s0/s1/s3/s5/s9b/s6/sA 计数）。

## §4 禁写

- 冻结树全列（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）。
- `Sources/AppGridUI/DragUI/DragUIVisuals.swift`、`DragUISessionCoordinator.swift`（wave-b 领地，本波零触碰——wave-b 已证休眠，**不得以任何理由改宿主切换**）。
- `Sources/AppGridUI/FolderOverlayView.swift`（坐标链与 forensics 领地）；`DropIntent.swift`（wave-c 领地）；`DragParameters`（不新增字段）；Docs/；无 git。
- **未完成 §2.1 取证的任何实现 = 越权，Reviewer 直接 FAIL。**
- **禁止照搬外部实现**：三份 digest（Workflow/results/T-1F-B10-source-digest-{launchbetter,touch,buho}.md）仅对照参考（AccessDeclaration: PRIOR_EXPOSURE 已记 CONTAMINATION_LOG.md），**绝不构成实现依据**；照搬 Buho 手动投递 / X2 启动序等外部代码 = 越权 FAIL。定罪与实现必须以本项目 census 与代码结构为准。

## §5 必读

- Workflow/BUG10-REGRESSION-REPORT.md（本波权威，含 §7 读数回填/§8 新判读/§9 判别实验表/**§13 最终裁决**/**§15 E4 定案**）；Workflow/BUG10-FIX-PROMPT.md §0/§4（取证纪律与判别表）；Workflow/tasks/T-1F-B10-wave-a-forensics.md §7（判别表，本运行不命中任何行）；§1 全部锚点文件。
- Workflow/results/T-1F-B10-source-digest-{launchbetter,touch,buho}.md（仅参考对照，**禁止照搬**；AccessDeclaration 见各文件头）。

## §6 验证

- 取证步：`swift build -c debug`/`-c release` exit 0；`swift test` 全量（1083+新增）；复测读数写入结果文件——s18 manual/internal 命中链、internal present/absent 计数、E5-fix layoutPerformedCount 增量相关度、E6a 探针投递计数（mouseDown/mouseUp/…）、E6b 事件元数据（type/subtype/buttonNumber）、E6c 真空白 s8c/s8d 对照、E2 用户侧结论、E4 手动投递 s10 增量表（如执行）、**A1 定罪读数（subtype / s10 / sA / present-absent 模式，逐击记录）**。
- 条件修复：按 §2.2 命中行验收（见 §7）；**H1（如执行）另附冷启动首击即达验证 + 独立 Reviewer 审查记录**。
- **B1 候选（门控开，§15）**：A/B 对照——门控关 10+ 击与 A 运行一致（s10=0/sA=0，生产零行为变更自证）；门控开 10+ 击 s10 增量=击数、s5 增量≥击数、s6>0、sA_launch_accepted>0、无 stuck-.pressed、空白 s8c 正常、ESC key53 正常、拖拽预览正常；debug+release 双构建 + swift test 全量（1083+）；转正需 Reviewer 显式 PASS + Main/Chief 定案。

## §7 验收

- [ ] §2.1 取证完成，读数写入结果文件，判别命中 §2.2 某行（T1/f/b/g/h/c/j/② 之一）
- [ ] **A1 定罪读数落盘：subtype=0 且 s10>0 → 主因定罪（进 T1）；subtype=0 且 s10=0 → 转 E4（h/f 系）**
- [ ] env 默认关自证：未设 `PAGING_CLICK_PROBE_MANUAL_DELIVERY` / `PAGING_CLICK_MANUAL_DELIVERY` 时生产路径零行为变更（Reviewer 复检门控分支；A 运行 35-38 击基线已采）
- [ ] **B1 闭环验收（门控开，§15）**：点击链全活——s10 增量=击数、s5 增量≥击数（up 闭环）、s6>0、**sA_launch_accepted>0（点击启动）**；无 B-run 式 stuck-.pressed（s13a/s13b/s9b 不异常抬高、连续多次点击正常）
- [ ] **空白退出 + ESC 退出强制回归（门控开）**：点空白 s8c_window_blank_terminate 正常；ESC key53 正常（对照 B-run 双失效态，必须翻转通过）
- [ ] **keyActive=false 观察项**：并入 H1（不另立任务）——4b 启动瞬间打印记录于结果文件；H1 加固后复测应转 true/窗口即刻 key；点击时 key1_active1 维持「潜伏非现行」判定
- [ ] 命中行对应修复实现 + 回归锁（冷启动点击 s10 正常增、sA 正常增）
- [ ] H1（如执行）独立提交：冷启动首击即达、全量回归通过、Reviewer 独立 PASS；未与回归修复捆绑
- [ ] 建夹 → 开 folder → 关 folder → 顶层点击能启动（wave-a-fix 验收项顺带复核）
- [ ] `swift test` 全量通过；debug+release 双构建 exit 0；冻结树零改动自证；**无任何照搬外部实现（digest 仅参考自证）**

## §8 输出纪律

- results 写 Workflow/results/T-1F-B10-regression-fix.md：取证读数原文/判别命中行/改动清单/测试证据/deviation 逐条/未触碰声明。
- Red flags：①任何「顺手修」= FAIL；②改宿主切换/wave-b 领地 = 越权 FAIL；③未取证直接实现 = FAIL；④想碰 AppLaunchController = 红线停手。
