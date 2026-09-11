# BUG10-REGRESSION-REPORT — wave-b 合并后主页面点击全死（Chief 诊断）

- 日期：2026-09-02
- 角色：Chief（只读诊断；不写产品代码）
- 上游：Main 记录 `Workflow/tasks/T-1F-B10-regression.md`；census 日志 `/tmp/bug10_forensics_run.log`
- 基线：1083/0（wave-a-forensics 合并后；wave-b/wave-c 已合并）
- 隐私：全文 A/B/C 代称；无真实 app 名 / bundle ID / 路径 / 标题

---

## §1 结论（一句话）

**wave-b 宿主切换在冷启动路径上完全休眠（三个调用点全部要求 folder 交互，s16=0 证明 closeFolder 从未运行），其运行时行为不可能直接导致冷启动点击全死；本次复测复现的是 BUG9 wave-a 修复前就存在、run2 中段已出现过的「窗口层判 cell 放行（s8d）但事件未达 surface 子树」死态——本次连 Path A（surface 手势）也一并死亡（sA=0），比 run2 死段更彻底。**

## §2 证据与判别（census 逐条）

| sink | 计数 | 判读 |
|---|---|---|
| s8e key1_active1 | 8 | 窗口全程 key+active → 排除 R5 激活吞点 |
| s17_ov0 | 7 | 命中链含 AppGridCellView 且**不含** FolderOverlayView → 命中真实 grid cell，非 overlay 成员 |
| s8d | 7 | 窗口层判 cell 命中 → 放行 super.sendEvent |
| s8_window_blank_unclassified → s8c | 1 | 第 8 次点击空白 → terminate（用户退出） |
| **s10** | **0** | **AppGridCellView.mouseDown 从未触发（Path B 死）** |
| **sA** | **0** | **AppLaunchController 通路零启动（Path A 死）** |
| s14（overlay hitTest） | 0 | overlay 从未参与 hitTest → 不在命中链 |
| s16（closeFolder） | 0 | closeFolder 从未运行 → 无 folder 开/关 |
| s4a/s4d | 0 | coordinator 空白路径未触发 |

**判别表命中**：`s8d 增、s10 不增、s14 不参与、sA 不增` —— 不匹配 wave-a-forensics §7 判别表任何一行（该表第 4 行要求 sA 增 = Path A 活；本运行 Path A 也死）。**事件在窗口层与 cell 之间被整体吞掉，未进入 surface 子树。**

## §3 根因分析

### 3.1 wave-b 冷启动休眠证明（排除 wave-b 运行时行为）

- `DragUIVisuals.setHost`（Sources/AppGridUI/DragUI/DragUIVisuals.swift:65-73）与 `DragUISessionCoordinator.setVisualHost`（Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:202-205）唯一生产驱动点 = `AppDelegate.refreshFolderOverlay`（Sources/PagingPrototypeApp/AppDelegate.swift:835-855）。
- `refreshFolderOverlay` 三个调用点全部要求 folder 交互：`:764`（openFolder）、`:792`（closeFolder）、`:826`（setFolderInnerPage）。启动路径（applicationDidFinishLaunching :66-305 → installContentAssembly :312-455 → installDragUI :454）**无任何调用**。
- 冷启动时 `visualHost = surface`（DragUISessionCoordinator.swift:184-193 init；installDragUI :547 `DragUISessionCoordinator(host: surface)`），与 wave-b 前完全一致；visuals 四视图未挂载（仅 drag 会话中 attach）。
- census 佐证：s16=0（closeFolder 未运行）、s14=0（overlay 未入层级）→ refreshFolderOverlay 的 folder 开/关分支均未执行。
- **结论：wave-b 在冷启动的视图层级/事件路由零改动。** 若二进制确为 wave-b 合并后重建，则回归必另有来源（见 §3.3）。

### 3.2 死态机制（窗口层与 cell 之间的事件吞没）

- 窗口层手动 hitTest（QuitOnBlankClickWindow.sendEvent，AppDelegate.swift:1101-1103：`contentView.convert(event.locationInWindow, from: nil)` + `contentView.hitTest(point)`）**找到真实 cell**（s8d/s17_ov0）→ 放行 `super.sendEvent(event)`（:1142）。
- 但 AppKit 内部路由**未把 mouseDown 投递给该 cell**（s10=0），也未让 surface 上的祖先手势识别器观察到事件（sA=0，AppLaunchController.install :93-98 的 NSClickGestureRecognizer 挂在 surface 上，事件若进入 surface 子树必被观察）。
- 两条独立接收路径同时静默 = **事件未进入 surface 子树**。窗口手动 hitTest 与 AppKit 内部路由结果不一致。
- 已实证排除：hitTest 漏斗坐标语义（/tmp/hittest_probe 探针：`AppGridCellView.hitTest` 收到的 point 为**父视图坐标系**，`frame.contains(point)` 正确；`frame.contains` 非坐标 bug）；子视图拦截（漏斗返回 self，命中即 cell 自身）；overlay 残留（s14/s16/s17_ov0 全否定）；R5 激活（s8e key1_active1）；R2 抑制滞留（s13a/s13b/s9b 全程零输出，无仲裁发生）。
- **未排除的候选机制**（按可能性排序）：
  1. **窗口内部 hit-test 状态与手动调用不一致**：AppKit 对 mouseDown 的投递目标可能来自窗口自身的 hit-test 机制（含 tracking 会话缓存/坐标系基准差异），与 sendEvent 覆盖层的手动 `contentView.hitTest` 调用不同源；全屏过渡（AppDelegate.swift:273-276，启动 0.3s 后 toggleFullScreen）可能使窗口内部状态与视图树短暂/持续失配。
  2. **二进制/构建状态与 run2 不一致**：run2 验证的是 wave-a 合并后的构建；本次复测若构建自含未合并/部分合并改动的树，或漏斗/手势接线被意外回退，症状与 BUG9 修复前完全一致（BUG9-REPORT §1：「9 次点击全部 s8d…s10 零输出」）。
  3. **死态为既有间歇性条件**：run2 中段已出现 23 次连续 `s8d 不增 s10`（BUG10-FIX-PROMPT §4.1 :71-115），当时 Path A 仍活（sA 继续增）掩盖了 Path B 死亡；本次冷启动即进入同态且 Path A 也死。

### 3.3 与 BUG9 修复前症状的同源性（关键）

- BUG9-REPORT §1 记录的 wave-a 修复前症状 = **「s8d 增、s10 零输出」**，与本次逐字相同。
- wave-a 漏斗修复后 run2 前段 s10×5 正常，但 run2 中段（FIX-PROMPT §4.1）已再现「s8d 连续 23 次、s10 恒 5 不增」——**死态在 wave-b 之前就存在**，wave-b 不是死态的必要条件。
- 本次复测（冷启动即死 + Path A 也死）比 run2 死段更彻底，说明死态触发条件与 folder 无关（wave-a-forensics 的「开过 folder 再关」假设被 s14/s16/s17_ov0 直接证伪）。

## §4 修复建议（方向，供任务包定案）

1. **先取证后实现（沿用 FIX-PROMPT §0 纪律）**：死态机制未实机定位前禁止写修复代码。取证目标 = 判别「窗口内部路由目标 vs 手动 hitTest 结果」：
   - 在 `QuitOnBlankClickWindow.sendEvent` 的 cell 放行分支（AppDelegate.swift:1136-1139）加**窗口内部投递目标观测**：`super.sendEvent` 后无法直接观测，改为在 `AppGridCellView.mouseDown` 与 surface 手势之外，加一个**窗口级 `NSView` 子类探针**（或 `NSWindow` 的 `_hitTest` 等价观测）记录 AppKit 实际投递视图——若投递目标非 cell（如 pageHost/containerView/搜索框），即锁定机制 3.2-1。
   - 复测脚本：冷启动 → 点 cell → 记录「窗口手动 hitTest 视图」vs「AppKit 实际投递视图」；对照 run2 正常段。
2. **构建状态核验**：复测前 `swift build -c release` 强制重建 + `git diff --stat`（无 git 则核对文件 mtime/内容哈希），排除陈旧/部分二进制。
3. **若锁定窗口内部路由失配**：修复方向 = 消除窗口层手动 hitTest 与 AppKit 路由的依赖差异（如把 cell 判定改为不依赖 hitTest 的坐标直算，或把拦截点从 sendEvent 移到视图层），**不动冻结树**。
4. **若锁定构建/环境**：重建后复测，无需代码修复。
5. **Path A 可靠性**（run2 死段暴露）：surface 手势依赖 `allowableMovement`（默认 10pt），位移即静默失败——作为独立观察项，不在本波修（wave-a-forensics §7 第 4 行同判）。

## §5 约束与红线

- 冻结树零触碰：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift。
- 禁读：LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse。
- 隐私：新增 census sink 只允许中性名+计数+布尔位。
- 流程：Main/Chief 不写业务代码；缺陷 → Workflow 任务 → Worker → 独立 Reviewer PASS → 合并。

---

## §7 probe 实机读数回填（/tmp/bug10_probe_run2.log；基线 1089/0）

| sink | 计数 | 判读 |
|---|---|---|
| s18_hit_manual_chain_AppGridCellView…ClickDeliveryProbeView | 13 | 窗口手动 hitTest（AppDelegate.swift:1101-1103）13/13 命中同一 cell 链 |
| s18_hit_internal_chain（同链） | 4 | AppKit 内部 hit-test 4/13 被调用且命中**同一 cell** |
| s18_internal_hittest_absent | 9 | AppKit 9/13 **未调用 contentView.hitTest** 即处理 mouseDown |
| s10 | 0 | 即使内部命中 cell 的 4 次也未触发 mouseDown |
| sA_launch_accepted | 1 | Return 键启动成功（键盘路径健康，app 逻辑层无问题） |
| s8e key1_active1 | 13 | 排除 R5 |
| s8d | 13 | 窗口层 13/13 放行 super.sendEvent |
| s17_ov0 | 13 | 排除 overlay |
| s14/s16 | 0 | folder 零参与 |

探针非因非果：死态先于探针合并存在（forensics 波 s8d×7/s10=0），Reviewer 确认探针纯转发。

## §8 新判读（推翻 §3.2 候选①原始表述）

1. **候选①（手动 vs 内部 hit-test 不同源）被数值推翻**：内部 hit-test 命中同一 cell 的 4 次仍不投递 → 断点不在 hit-test 结果，而在 **hit-test 之后、mouseDown 分发之前的环节**。
2. **决定性新事实：internal_hittest_absent 9/13** —— AppKit 多数时候不做 hit-test 就「处理」了 mouseDown。事件未触发任何项目识别器（s10=0、sA=0）→ 事件像被直接丢弃或走了非标准路径。
3. 两态并存（absent 9 / present 4，present 均命中同 cell）的候选解释：
   - **e) event 窗口归属不一致**（上升为最强候选）：sendEvent 收到的事件其内部 window/窗口编号与当前窗口不一致（全屏 space 过渡、窗口编号漂移）→ AppKit 不走常规 hit-test 路由（absent）或走特殊路径（present 但不投递）。
   - **f) AppKit 命中视图缓存/跟踪会话指向失效目标**（新候选）：窗口对 mouseDown 投递目标有缓存（`_lastHitView` 类机制），缓存因视图层级重建（refreshPresentation / PageHostView 复用池，PagingSurface.swift:759-785）失效后才重算（present 4 次）；缓存条目指向已移除/复用的 cell → 投递被丢弃。能解释间歇性（run2 前段活/中段死）。
   - **c) 系统级手势/事件拦截**：用户此前报「鼠标直动不了」类症状（触控板三指拖移等）→ 系统把 click 吞入手势系统。多为全态（13/13 absent），与两态并存弱兼容。
   - **b) 全屏过渡窗口状态**：AppDelegate.swift:908-914 已有「全屏过渡吞识别器」注记先例；过渡异步（:273-276）若窗口内部过渡标志滞留，mouseDown 走简化路径（不做 hit-test）。
4. **未排除但降级**：②构建陈旧（本波已强制重建，读数与 sink 齐全，基本排除）；③既有间歇死态（与 f 同源假说合并）。
5. **键盘路径健康**（sA=1 via Return）= app 逻辑层/焦点/启动管线无问题，断点纯在鼠标事件分发。

## §9 判别实验（按序执行；零行为优先）

| # | 实验 | 操作 | 判别 |
|---|---|---|---|
| E1 | 窗口归属一致性（零行为） | 探针在 :1093 加中性观测：`event.windowNumber` vs `self.windowNumber` vs `NSApp.keyWindow?.windowNumber` 一致性布尔位 | 不一致 → 命中 e |
| E2 | 系统手势对照（用户侧） | 系统设置关闭「三指拖移/轻点」后复测；或换 USB 鼠标 | 恢复 → 命中 c |
| E3 | 非全屏对照（用户侧/参数） | 若可窗口模式运行 → 冷启动点击对照；否则在 `windowDidEnterFullScreen` 通知回调记录到达时序 | 窗口模式恢复 → 命中 b |
| E4 | A/B 手动投递（env 门控改码，可回退） | `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 时在 cell 放行分支（:1136-1139）手动 `hit?.mouseDown(with: event)` 并 return；默认关 = 生产零行为变更 | 手动投递触发 s10 → 断点在 AppKit 分发；仍不触发 → 断点更深（系统标记/窗口状态） |
| E5 | 缓存失效对照（零行为） | 探针记录每次点击前 `liveHosts` 计数/最近 `relayoutPages` 时间戳（中性） | absent 与 relayout 强相关 → 命中 f |

---

## §10 E1+E5 读数判读（/tmp/bug10_e1_run.log；13 次点击，用户操作：点软件×2→翻页→另页点软件→点空白）

**排除/降级更新：**
- **e（窗口归属不一致）排除**：sE1_window_owner_match 13/13，零 mismatch。
- **f（命中视图缓存/复用池失效）未排除——E5 阴性无效**：E5 funnel 降级漏翻页 relayout（Reviewer M1：`PagingSurface.swift:169 layoutPerformedCount` 为 public private(set) 只读入口，后续波次直接读）。s18 内部模式 present×6→absent×4→present→absent×2 与翻页后 relayout 时序相容；但前 6 次 present 亦死（s10=0）→ f 单独不足，需「启动期 relayout（E5 yes×1）即污染缓存」才自洽。

**决定性事实：**
- 断点最终定位：手动 hitTest 13/13 + 内部 hitTest 7/13 命中同一 cell 链，mouseDown 0/13 → **断点在 AppKit 投递层（super.sendEvent 之后、视图方法之前）**，§8 判读强化为定论。
- **空白误判 cell**（s8d 13/13 含空白、s8c/s8b/s8_window_blank_unclassified 零输出）：手动与内部 hitTest 同源同果 → 若为坐标问题则出在 contentView 坐标系本身（frame 失配），非转换代码；或用户空白点击实际落在 cell 上（cell frame 错位/误判）。待 E6c 真空白对照。
- **翻页可用而点击全死**：若翻页走 scrollWheel（PagingSurface.scrollWheel :317），则 hitTest 投递对 scroll 有效、对 mouseDown 失效 → **mouseDown 专属状态（跟踪会话/手势识别器滞留）**，非通用 layer 脱同步。待用户确认翻页方式（滚轮/按钮/键盘）。

**现行候选排序：** f（复活：跟踪/缓存滞留，启动期 relayout 污染）> b（全屏过渡状态，:908-914 注记先例）> g（投递目标=contentView/探针，缺 mouseDown sink 未验证）> h（窗口级消费）> c/j（系统拦截，E2 未做，用户「鼠标直动不了」史）> i（坐标，内部同源矛盾，低）。

**下一判别实验（E6 优先，零行为；读数仍不足定罪）：**

| # | 实验 | 操作 | 判别 |
|---|---|---|---|
| E6a | 探针投递观测（零行为） | ClickDeliveryProbeView（contentView）加 `mouseDown/mouseUp/mouseDragged/rightMouseDown/otherMouseDown` 纯转发 census（中性计数，隐私合规） | 探针收 mouseDown → 投递目标=contentView（滞留跟踪会话）→ 命中 g/f；只收 mouseUp 不收 mouseDown → 事件对被拆散 → 识别器滞留（b/f 系）；两者皆零 → 窗口级消费（h） |
| E6b | 事件元数据（零行为） | 每点击记录 `event.type.rawValue`/`subtype.rawValue`/`buttonNumber`（中性 int） | subtype≠0 或 type≠leftMouseDown → 非正常事件 → c/j 系统拦截 |
| E6c | 真空白对照（零行为） | 用户点窗口极端角落（明确空白） | s8c 触发 → 此前空白点击实为 cell（frame 错位/误判）；仍 s8d → 窗口层 hitTest 坐标/帧问题坐实 |
| E2 | 系统手势对照（用户侧） | 关三指拖移/轻点或换 USB 鼠标复测；**同时确认翻页方式**（滚轮/按钮/键盘） | 恢复 → 命中 c/j；翻页=滚轮 → scroll 投递活/mouseDown 死 → 跟踪会话滞留坐实 |
| E5-fix | relayout 相关度重测（零行为） | 直接读 `PagingSurface.layoutPerformedCount`（:169）替代降级 funnel | absent 与 layoutPerformedCount 增量强相关 → 命中 f |
| E4 | A/B 手动投递（行为变更，E6 后置） | 同 §9 E4：env 门控 `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 手动 `hit?.mouseDown(with:)` | 触发 s10 → 事件本身正常、断点在 AppKit 分发；不触发 → 事件被标记 handled/非正常事件 |

---

## §11 Main 侧核验判读（s18_delivered_contentview 零输出）

**新事实（Main 核验，采信）：** `s18_delivered_contentview` sink 确认存在于 release 二进制（strings count=1），E1 日志全程零输出 → **contentView（探针）的 mouseDown 从未被调用**（sink 布点在探针 mouseDown 入口）。

**判读：**
- 投递目标排除集扩为 **{cell（s10=0），contentView（s18_delivered_contentview=0）}** → 剩余：**中间层视图**（PageHostView/PagingSurface/AppGridPageView/rendererView NSView——均无 mouseDown 覆写，默认 NSView 实现为空操作 → 静默吞）或 **AppKit 内部消费（h）**。
- **g 的 contentView 分支排除**；g 重定义为「投递目标=中间层视图」。
- **f 族强化**：投递目标既非 hitTest 结果（cell）也非 contentView → AppKit 投递不基于 hitTest 结果，而基于窗口内部缓存/跟踪会话，指向中间层视图（relayout 复用池操作后缓存滞留）。present 7/13 的 hitTest 调用为旁路（cursor rects/其他），其结果不用于投递——**自洽解释 present+不投递**。
- 中间层无 mouseDown 覆写 = 事件静默消失，与全部 sink 零输出完全一致；这也解释 absent 6/13（纯缓存投递，不 hitTest）。
- 与 §10 候选排序合并：**f（投递目标=中间层视图，缓存/跟踪滞留）> b（全屏过渡吞事件对）> g（重定义后并入 f 族）> h（AppKit 内部消费，与 f 观测等价，需 E6a' 区分）> c/j > i**。

**下一判别实验（更新）：**

| # | 实验 | 操作 | 判别 |
|---|---|---|---|
| E6a' | 中间层投递观测（零行为） | `AppGridPageView`（AppGridUI 非冻结）加 `mouseDown/mouseUp` 纯转发 census（sE6_page_down/up） | >0 → 投递目标=AppGridPageView → **f 族定罪**（缓存指向中间层）；mouseUp 目标同步记录（事件对完整性） |
| E6a'' | 分发入口监视（零行为） | AppDelegate 侧 `NSEvent.addLocalMonitorForEvents(.leftMouseDown/.leftMouseUp)` 中性计数（sE6_monitor_down/up） | monitor 有而视图全零 → 事件进入 AppKit 分发但投递到 PagingUI 冻结层或内部吞（h）；monitor 无 → 分发前即被吞 |
| E6b | 事件元数据（零行为） | 每点击记录 `event.type.rawValue`/`subtype.rawValue`/`buttonNumber`（中性 int） | subtype≠0 或 type≠leftMouseDown → 合成/特殊事件 → c/j 系统拦截 |
| E6c | 真空白对照（零行为） | 用户点窗口极端角落（明确空白） | s8c 触发 → 此前空白点击实为 cell；仍 s8d → 窗口层 hitTest 坐标/帧问题坐实 |
| E2 | 系统手势对照（用户侧） | 关三指拖移/轻点或换 USB 鼠标复测；**同时确认翻页方式**（滚轮/按钮/键盘） | 恢复 → 命中 c/j；翻页=滚轮 → scroll 投递活/mouseDown 死 → 跟踪会话滞留坐实 |
| E5-fix | relayout 相关度重测（零行为） | 直接读 `PagingSurface.layoutPerformedCount`（:169）替代降级 funnel | absent 与计数增量强相关 → 命中 f |
| E4 | A/B 手动投递（行为变更，E6 无果后置） | env 门控 `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 手动 `hit?.mouseDown(with:)` | 触发 s10 → 事件本身正常、断点在 AppKit 分发；不触发 → 事件被标记 handled/非正常事件 |

**注：** 若 E6a' 亦零且 E6a'' 有 → 投递目标在 PagingUI 冻结层（PageHostView/PagingSurface）或 AppKit 内部吞；PagingUI 冻结不可加 sink → 需 E4 或回 Main 申请定向解冻（仅只读观测）。

---

## §12 E6 读数判读（/tmp/bug10_e6_run.log；9 cell 点击 + 1 空白）

**读数要点：**
- sE6_monitor_down/up 1→9：local monitor（NSApp 分发入口）捕获全部 down+up → 事件确实进入 app 事件循环。
- **sE6b_meta_type_1_subtype_3_button_0 1→9：全部 9 击均为 type=1(leftMouseDown) subtype=3(NSTouchEventSubtype.touch) button=0** —— 触控板触摸类合成事件（用户已确认触控板操作）。
- sE6_page_down/up=0、s10=0、sA=0、s18_delivered_contentview=0：视图层全军覆没（page/cell/contentView 零接收）。
- s18 internal：前 3 present → 后 6 absent（**行为切换：第 4 击起 AppKit 不再调 contentView.hitTest**）。
- sE5 relayout：yes 仅首击 1、no 2-9。
- 第 10 击（极端角落空白）：s8_window_blank_unclassified 1 + s8c_window_blank_terminate 1 → **空白退出功能正常**（窗口层手动判定链活）。

**判读：**
1. **触摸类事件路由缺失（新，最强候选）**：subtype=3 全局特征 9/9 = 触控板触摸合成事件；**grep 实证视图链零触摸处理**（Sources/ 全树无 touchesBegan/touchesMoved/touchesEnded/allowedTouchTypes/wantsRestingTouches/NSTouch/touches(matching:) 消费）→ AppKit 对 NSTouchEventSubtype.touch 的 mouseDown 走触摸合成/路由路径，视图链无触摸消费（无 touchesBegan、无触摸识别器）→ 事件在 NSApp 层后、视图分发前被内部处理/丢弃，`mouseDown(with:)` 不被调用。
2. **present→absent 切换自洽于触摸会话**：前 3 击触摸会话建立阶段 AppKit 走标准 hitTest（present 但同样不投递 mouseDown——touch 路径不投递 mouseDown）；会话稳定后复用会话目标，连 hitTest 都省略（absent 6/9）。
3. **f 弱化**：E5 relayout 仅首击（yes 1/no 2-9），与 absent 切换（第 4 击起）不同步 → 「relayout 污染缓存」假说本轮无支撑。
4. **h 降为观测等价描述**：monitor 有 + 视图零 = 「NSApp 层后、视图分发前被吞」是触摸假说与纯吞假说共同的观测签名，非独立机制；需换输入判别。
5. **间歇性解释**：run2 正常段无 subtype 记录——若当时为鼠标/实体按压（subtype=0）或触摸路由不同，可解释 run2 活/现死；用户「鼠标直动不了」史 + 触控板确认 = 输入环境差异为候选变量。
6. **健康侧证**：scrollWheel（翻页）/keyDown（Return 启动）/窗口层手动判定（空白退出）全活——**唯独 AppKit 内部 mouseDown 投递链死**，与「触摸事件不投递标准 mouseDown」精确吻合。

**候选排序（更新）：** 触摸类事件路由缺失（最强）> h（纯投递层吞，观测等价，需换输入判别）> b（全屏过渡状态）> f（弱化）> c/j > i。

**下一判别实验（用户侧，零代码）：**

| # | 实验 | 操作 | 判别 |
|---|---|---|---|
| A1 | 换输入方式复测 | ①外接 USB 鼠标点击 5 次；或 ②系统设置→触控板→关闭「轻点来点按」，实体按压点击 5 次（PAGING_CLICK_CENSUS=1） | subtype=0 且 s10>0 → **定罪触摸路由缺失**；subtype=0 且 s10=0 → 与事件类型无关（h/f 系），转 E4 |
| A2 | 会话切换观察（并入 A1） | 记录 A1 各击 present/absent 模式 | 全稳定/无切换 → 支撑触摸会话假说；仍前 present 后 absent → 会话机制与输入无关 |

**修复方向（若定罪触摸路由缺失）：**
- **首选：local monitor 事件规范化**——AppDelegate 侧（非冻结）`NSEvent.addLocalMonitorForEvents(.leftMouseDown)` 检测 subtype=3 → 用 `NSEvent.mouseEvent(with: .leftMouseDown, …)` 重建 subtype=0 标准事件返回（monitor 支持替换事件），使触摸类点击走标准 mouseDown 链。**env 门控 `PAGING_CLICK_NORMALIZE_TOUCH=1` 先行验证，有效后转正；行为变更需 Reviewer 显式 PASS；不碰冻结树/wave-b 领地。** 代价：丢失触控板特殊语义（Force Touch 压感等，本 app 不需要）。
- 备选（不推荐）：视图链加 touchesBegan 消费——侵入视图层，改面大。

---

## §13 源审阅对照与最终机制裁决（digest 仅参考；定罪以 census 为准）

**材料地位（AccessDeclaration: PRIOR_EXPOSURE，2026-09-03 主控授权，已记 CONTAMINATION_LOG.md）**：三份 digest（`Workflow/results/T-1F-B10-source-digest-{launchbetter,touch,buho}.md`）仅作对照参考与启发，**绝不构成实现依据，禁止照搬外部实现**；本波定罪一律以本项目 census（§7/§8/§10/§11/§12）+ 代码路径为准。

**对照裁决表：**

| 外部材料 | 外部机制/教训 | 本项目对应事实 | 裁决 |
|---|---|---|---|
| X2 激活吞首击（LaunchBetter f6f7f1b：`NSApp.activate(ignoringOtherApps:)` 先于 `makeKeyAndOrderFront`；探针实证「sendEvent 会把激活点击吞掉，只有 acceptsFirstMouse 的控件收到」） | 非 key/未激活应用把首次 mouseDown 作激活点击吞掉（仅吞**首击**） | AppDelegate.swift:276 `makeKeyAndOrderFront` **先于** :281 `activate`（顺序与 X2 相反）+ :273-276 异步全屏 toggle 扰动 key 态；但 census **s8e key1_active1 9/9**（每次点击窗口均 key+active），死态覆盖第 1-9 全部点击（**非仅首击**），Return 键启动正常 | **倒置 = 潜伏缺陷，须加固（H1）；数值排除其为现行 9/9 死态机制**（X2 是「首击被吞」，本项目是「全死且 key 态恒真」） |
| Buho 窗口层手动投递（sendEvent 按 type 拦截 leftMouseDown/Up/Dragged → contentView hitTest → 直接 `[view mouseDown:]`；命中 nil 静默丢弃；无 subtype 分支，轻点照常投递） | 绕过 NSWindow 内部派发 → 激活吞点免疫；本地监视器对 `event.window==nil`（合成事件常见）分支是移植陷阱 | 本项目 sendEvent 手动 hitTest **仅分类**空白 vs cell（:1101-1104）；cell 命中走 `super.sendEvent` 靠 AppKit 内部路由——**与 Buho 的根本差异**；subtype=3 9/9 为本项目全局特征且无任何特殊处理 | **Buho 方案 = 仅 h 定罪时的兜底参照（B1）**：A1 显示 subtype=0 亦死（纯投递层吞）才有资格评估；不照搬、不默认采用 |
| 触摸维度（两目录零原生触摸处理；X2 与本缺陷「首次交互像被激活消耗掉」同文同种） | — | E6b：subtype=3（NSTouchEventSubtype.touch）9/9；Sources/ 全树零触摸消费（无 touchesBegan/allowedTouchTypes）；local monitor 9/9 收、视图层 9/9 零；present×3→absent×6 | 方向性支持「触摸类事件特殊处理」，但 X2 的**激活时序解释**被 census 数值排除——裁决以 census 为准 |

**统一裁决（单一主因 + 组合机制表述）：**

1. **主因（census 定罪，现行）——触摸类 mouseDown 投递缺失**：subtype=3 全局 9/9 + 视图链零触摸消费 + monitor 收/视图零 + 唯 mouseDown 链死 + present→absent 切换自洽于触摸会话建立。证据链闭合，**不依赖任何外部材料**。
2. **潜因（潜伏缺陷，非现行机制；加固项 H1）**：AppDelegate.swift:276/:281 激活顺序倒置 + 异步全屏 toggle——解释 run2 中段死段/间歇史与「唤起即点」场景风险；s8e 9/9 数值排除其为本次死态直接机制。**不得以「修复回归」名义提交，须独立标注为加固。**
3. **兜底（B1，仅 h 定罪时）**：Buho 式窗口层手动投递——行为变更大改，仅当 A1 显示 subtype=0 亦死时由 Main/Chief 定案评估；**禁止直接照搬外部实现**。
4. **回归窗口解释**：wave-b 等波次代码经 §3.1/§12 证明休眠/零行为 → 回归触发变量在**输入环境/系统状态**（触控板轻点 vs 实体按压；run2 正常段疑为实体输入），非波次代码。用户口述 A1 先验「好像是单机能打开」与触摸路由假说一致；正式定罪待 A1 读数。

**修复路径（定案顺序）**：**A1**（零代码用户侧判别，硬前置）→ **T1**（A1 定罪后：env 门控 `PAGING_CLICK_NORMALIZE_TOUCH=1` 触摸规范化，Reviewer 显式 PASS 后转正）→ **H1**（激活顺序加固，独立低风险提交）→ **B1**（仅 h 定罪且 Main/Chief 定案时评估，不照搬）。

---

## §14 A1 换输入判读（/tmp/bug10_a1_swap.log；43 次点击，用户 USB 鼠标）

**读数：**
- subtype=0（标准鼠标事件）30/43、subtype=3 13/43；**两态 s10 均恒 0**（标准事件同样从不触发 cell.mouseDown）。
- sE6_monitor_down 43 / up 42（全部 down 进入 NSApp）；internal present 8 / absent 34；s8e key1_active1 43/43（H1 维持排除）；sA 仅早前 Return 启动 1。

**判读：**
1. **触摸假说（§12 最强候选 / §13 主因）数值排除**：事件类型无关——subtype=0 亦死，断点下移为 **AppKit 内部投递层**（NSApp monitor 43/43 收 → 窗口层 s8d 放行 → 视图层 0 接收；internal hitTest 34/43 absent 佐证投递不咨询视图树）。
2. **h 升为现行最强候选**；A1 结果命中 §13「B1 兜底启用条件」原文（A1 显示 subtype=0 亦死 = h 定罪）→ **B1 资格达成（待 E4 确认事件链健全性）**。
3. H1 维持排除（key1_active1 43/43）；b（全屏过渡）保持次候选；f 与 h 静态不可分（§11 观测等价），E1 已排除覆盖窗（owner 13/13）、E6a'/a'' 已排除 contentView/AppGridPageView 投递目标 → **静态重审无新判别力，直接 E4 二分**。
4. **E4 授权**（§9 判别表既定分支「subtype=0 且 s10=0 → 转 E4」+ 任务包 §2.1④ 原规格：env 门控 `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`、默认关、诊断注释、Reviewer 显式 PASS）。收敛路径：**结果 A**（手动投递触发 s10）→ 事件与视图链健全、断点纯在 AppKit 分发 → B1 式 sendEvent 手动/规范化投递（env 门控先行、Main/Chief 定案、不照搬 Buho）；**结果 B**（仍零）→ 事件被标 handled 或命中视图非 cell → 升级「重建事件 + 手动投递」（T1 规范化泛化、去 subtype 门、仍 env 门控）。
5. **顺带零行为补读（并入 E4 门控构建）**：启动期一次性打印 `window.ignoresMouseEvents` / `contentView.ignoresMouseEvents` / `window.level` / `window.styleMask` / `NSApp.isActive && keyWindow==self`；每击内联 E1 复核（`event.windowNumber == self.windowNumber`）。

---

## §15 E4 A/B 实机对照定案（/tmp/bug10_e4_a_run.log + /tmp/bug10_e4_b_run.log）— h 定罪完成，B1 生产候选定案

**A 运行（门控关 = 生产行为，35-38 击）：**
- monitor 35→38（全入 NSApp）；s8e key1_active1 全击；s18 手动链全命中 cell；AppKit 内部 hitTest absent 25→28（多数不咨询视图树）；**s10=0**（cell.mouseDown 零触发）；sA=0。主 bug 稳定复现（用户「完全没反应」与读数吻合）。

**B 运行（`PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`，16 击）：**
- **sE4 16 == s8d 16 == s10 16**：手动投递 1:1 全触发 cell.mouseDown → **事件链 + 视图层健全；断点实证 = AppKit 内部分发层**（super.sendEvent 后 mouseDown 到不了视图、内部 hitTest 多数缺席）。§14「结果 A」收敛兑现。
- **B 运行副产物（决定修复设计）**：s6_dispatch_click=0、sA=0 —— 手动投递后 return 不调 super → AppKit 鼠标追踪状态未建立 → mouseUp 不投递 cell（AppGridCellView.swift:202-204 覆写收不到）→ controller.state 停在 .pressed → 后续点击 pointerDown 走 cancel(.secondDrag)（DragSessionController.swift:67-71）→ dispatchClick 永不触发；s13a/s13b/s9b 各 3（fallback/拖拽分支）。用户侧：点空白退不出（s8c=0、s8b 吞 1）+ ESC 退不出 —— **均为门控实验副产物（投递闭环缺失）而非生产路径；生产候选必须闭环。**
- **4b 补读**：启动瞬间 `ignoresMouseEvents window=false contentView=false level=0 styleMask=15 keyActive=false`——**keyActive=false** 与 X2 教训 / AppDelegate.swift:276/:281 顺序倒置同族；点击时 s8e key1_active1 全击 → **潜伏信号，非现行机制**。

**定案（Final，Chief）：**

1. **h 定罪完成**：断点 = **AppKit 内部分发层吞事件**（原因在 AppKit 内部、源码不可定位；census 证据链闭合：monitor 收 35→38 → 窗口层见 s8d → 手动可投 s10 16/16 → 内部路由死）。
2. **B1 生产修复候选规格**（行为层设计；env 门控 **`PAGING_CLICK_MANUAL_DELIVERY=1`** 默认关；与无闭环诊断探针门 `PAGING_CLICK_PROBE_MANUAL_DELIVERY` 分离）：
   - ① **leftMouseDown 命中 cell**（现有 :1136-1139 判定）：手动 `hit?.mouseDown(with: event)` + 记录 `lastManualMouseDownView`（weak）→ return（不调 super）；
   - ② **leftMouseUp**：记录非 nil → 投记录视图 `.mouseUp(with: event)` → 清记录 → return。**闭环关键环**：cell.mouseUp → coordinator.pointerUp（:305-377，s5 :351）→ endSession（:329/:343，s9b :508）→ dispatchClick（:484-492，s6 :486）→ onCellClick（:590-592）→ sA launch；s6=0/sA=0 的 B 运行死态由此消除；
   - ③ **leftMouseDragged**：记录非 nil → 投记录视图 `.mouseDragged(with: event)` → return（拖拽链 AppGridCellView.swift:197-205 → coordinator s4a-s4c，预览/拖拽不回归）；
   - ④ 空白分支（非 cell）、记录 nil 的 up/dragged、ESC key53（:1089-1092）维持原 `super.sendEvent` 语义零触碰；**窗口失 key / ESC 打断时清记录**（防 stale 记录，B 运行边界之外的必要防护）。
   - 验证零新增 census sink（复用 s10/s0/s1/s3 + s5/s9b + s6 + sA 既有计数即可闭环证明）。**禁照搬 Buho 实现**（行为层结论仅参照）。验证通过 + Reviewer 显式 PASS 后由 Main/Chief 定案转正（转正 = 独立决策）。
3. **keyActive=false（4b 启动瞬间）**：**不另立工作项**——与 H1 同根（激活顺序），并入 H1 观察/验证项：加固后复测 4b 打印（预期转 true / 窗口即刻 key）；点击时 key1_active1 全击维持其「潜伏、非现行」地位。
4. **回归触发变量终判**：输入环境/系统状态（非波次代码）——wave-b/forensics/c 均证休眠或零行为（§3.1/§12）；AppKit 内部分发层在当前系统状态吞事件、与输入类型无关（A1 43/43 + E4-A 35→38 全死）。
5. **修复路径最终态**：A1（完成）→ T1（作废）→ E4（完成，结果 A）→ **B1（定案，现行唯一修复行）**；H1（潜伏加固，独立提交）。
