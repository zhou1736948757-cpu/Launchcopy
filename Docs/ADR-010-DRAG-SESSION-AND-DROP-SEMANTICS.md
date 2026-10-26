# ADR-010 — DRAG SESSION AND DROP SEMANTICS

- **状态**：Accepted（T-1F-A 交付并合并后由 Main 转正，2026-08-31；实现注记见文末）
- **阶段**：Phase 1F（PHASE1F_DRAG_PERSISTENCE_PROMPT §5、§6.2；权威依据）
- **关联**：ADR-009（布局持久化/生成所有权）；ADR-008（folder 呈现/dissolve/输入优先级）；ADR-006（ESC/焦点/空白两段式）；PARAMETER_RATIONALE；PRIVACY_DATA_MAP
- **回答**：Prompt §6.2 全部 14 问（§Q1–Q14 一一对应）
- **范围**：拖拽会话模型、drop 语义、取消生命周期、输入仲裁、无障碍等价、Reduce Motion、参数来源纪律

## 背景

1F 新增产品变量：用户通过本应用自己的拖拽 + 等价无障碍操作重排顶层 app/folder、建夹、移入移出、folder 内重排、跨页；逻辑布局持久化由 ADR-009 管辖。本 ADR 定拖拽交互的**状态机、意图语义与仲裁**，全部改动落在 `AppGridUI/` + `PagingPrototypeApp/`（AppDelegate 接线由 T-1F-E 串行处理），不触碰 PagingUI/PagingCore/AppLaunchController。

## Q1. AppKit 拖拽 API vs 自定义指针状态机（选定：自定义）

**决策**：默认 **自定义窗口内 pointer state machine**；本阶段**不采用 `NSDraggingSession`/`NSDraggingSource`/`NSDraggingDestination`**。

比较（Prompt §5.1 清单）：

| 维度 | NSDraggingSession | 自定义（选定） |
|---|---|---|
| click-vs-drag 区分 | 系统管理 mouseDown/up-阈值，与既有 `NSClickGestureRecognizer`（cell 单击启动）仲裁复杂；AppKit 拖拽在 mouseDown 后立即占有会话 | 单一输入仲裁硬门：pointer-down 只能进 `pressed`；过阈值才 `dragging`；未过阈值的 mouse-up 派发既有 click/open/launch —— 与 1E 空白两段式/AppLaunchController 识别器共存可测 |
| 跨页/overlay 控制（edge dwell、move-out "先退 overlay 再落顶层"、inner page turn） | 系统会话的 drop 目标在 window/view 级，跨页面/跨 overlay 命中与"每页一次 turn 后重新 hit-test"需大量桥接 | 自定义状态机天然按帧重新 hit-test；`DragScope = .topLevel \| .folder(id)` 直接裁决当前上下文；move-out 显式 coordinator 状态可单测 |
| drop 可测性 | 依赖真实 NSEvent 会话；单测需合成 session 对象 | 纯状态机 + 纯 drop resolver：输入序列 → 状态迁移 → mutation 意图，全部纯逻辑可测（§10.5） |
| pasteboard 隐私 | 系统要求 pasteboard 承载拖拽（外部进程可观察）→ 须放 opaque token（§Q9） | **不用 pasteboard**：进程内 registry 验证即可；opaque token 仅用于统一事务结构（`DragTransaction`），不落 pasteboard |
| 外部伪造/重复 drop | 系统会话校验 + 自定义 token 仍需做 | 纯内存 registry：token 只存在于进程内 active session；外部 payload 无从进入 |
| teardown/cancel | 系统会话取消回调路径固定；与 resign/refresh/search/标题编辑的"统一 cancel"需各自桥接 | 单一 `cancel()` 出口：ESC/失焦/resign/refresh/search/标题编辑/overlay 关/teardown/第二个 drag 全部收敛同一路径，零写盘 |
| 与既有输入冲突 | scrollWheel（PagingCore）、blank-click（QuitOnBlankClickWindow.sendEvent）、键盘焦点（KeyboardFocusController）均需与系统拖拽仲裁 | 全部经同一 `inputArbiter`（Q7）：pointer-down → pressed → 阈值 → dragging；滚动/空白/键盘路径不变量保持 1E 语义 |

**选 NSDraggingSession 的失败条件**（若未来重开此议题，需证明这 5 点更优：取消覆盖、edge dwell 重试、overlay move-out、自动化注入、与 QuitOnBlankClickWindow 共存；仅"系统 API"不构成理由）。**禁用**：全局 `NSEvent` monitor、`CGEvent` tap、Accessibility/Input Monitoring 权限、私有 AppKit API、Finder file URL drag。

## Q2. drag 状态、所有者、session token（Q2）

- **事务结构**：`DragTransaction { opaqueToken: UInt64 /* 进程内随机 */, scope: DragScope, sourceIdentity: TopLevelEntryIdentity?, layoutGeneration: LayoutGeneration, catalogGeneration: UInt64 }`。
  - `scope = .topLevel | .folder(FolderID)`；`sourceIdentity` 可为 nil（空白处起拖 → 直接无效/仅移动已开始？**决策：空白处 pointer-down 不进入 drag**（沿用空白两段式：首击退出/关 folder）；sourceIdentity 非 nil 才可能 pressed→dragging）。
- **状态机**（所有者 = DragSessionController，AppGridUI 内，纯逻辑核心 + AppKit 薄壳）：
  `idle → pressed（pointerDown，记 sourceIdentity + layoutGeneration + catalogGeneration）→ dragging（过阈值）→ commit | cancel → idle`；
  在 dragging 内可进入 `edgeTurnPending`（edge dwell 计时中；dwell 满 → 一次 page turn → 重新 hit-test + 重新验证 token/双 generation → 回 dragging）。
- 每 session 限制：**至多 1 个 drag preview + 1 个 edge timer**。
- 第二个 drag 开始（前一个未结束）：**先取消旧 session**（废其 completion），再开始新的 —— 旧 preview/edge timer 清理，旧 completion 绝不覆盖新 drag（§3.8）。
- session token 生命周期：pressed 时生成，commit/cancel 或 teardown 销毁；`DropResolver.consume` 只认唯一活动 token。

## Q3. click/drag 阈值、edge dwell、drop zones：独立确定 + 参数来源类别

三个参数族，各自独立确定、独立测试、独立来源类别（进 PARAMETER_RATIONALE §6 新段）：

| 参数 | 含义 | 来源类别（5 类之一） | 初值（**待实验验证，非产品事实**） |
|---|---|---|---|
| `dragStartThresholdPT` | pressed→dragging 最小位移（pt） | PRODUCT_DECISION | 初值 6 pt（与 NSClickGestureRecognizer allowableMovement 默认量级对齐属 PUBLIC_DOCUMENTATION 参考，**不复制任何被禁来源**） |
| `edgeDwellDurationMs` | 边缘区驻留触发一次翻页 | PRODUCT_DECISION（结合 ACCESSIBILITY_REQUIREMENT：RM 下可缩短动画但逻辑等待不变或按 RM 规则处理） | 初值 500 ms（待实验） |
| `edgeZoneWidthPT` | 左右边缘热区宽度 | PRODUCT_DECISION | 初值 40 pt（待实验） |
| `edgeHysteresisPT` | 离开边缘须回退的距离，防抖动 | PRODUCT_DECISION | 初值 10 pt（待实验） |
| `dropZoneMarginsPT` | 各 drop zone（insertion 带/folder-cell 中心/folder-create 区）判定余量 | PRODUCT_DECISION | 随 T-1F-C 实验定 |

- **来源类别硬规则**：只允许 `PRODUCT_DECISION / PLATFORM_REQUIREMENT / ACCESSIBILITY_REQUIREMENT / INDEPENDENT_EXPERIMENT / PUBLIC_DOCUMENTATION`；**绝对禁止** `REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN`。每个参数在 PARAMETER_RATIONALE 表内有一行（默认值/合法范围/类别/理由/验证结果/修改日期）。
- 阈值与 edge 参数**独立于** 1C 键盘/1B 分页参数：互不引用、互不调参（诊断边界不变：PRODUCT_TIMER_TOLERANCE_0MS / SHORT_TAIL_MITIGATED_BY_TOLERANCE / CAUSALITY_UNRESOLVED_FOR_GT25MS）。

## Q4. 5 类 mutation 语义（全部走 LayoutMutation，ADR-009）

| # | Mutation | 触发 | 语义 |
|---|---|---|---|
| M1 | app reorder（顶层） | 顶层 app 拖到另一顶层条目间的 insertion 区 | 原子重排顶层序；drop 无位移 → **no-op（不加 generation、零写盘）**；目标位置明确可视（insertion indicator） |
| M2 | folder reorder（顶层） | 顶层 folder 拖到顶层 insertion 区 | 同 M1，folder 整条目移位；不改 folder ID/标题/成员 |
| M3 | create folder | app 拖到另一 app 的 **folder-create drop zone** | 新建 folder：目标+源为初始成员（**初始成员顺序 = 产品决策固定并被测试**；顺序：先目标后源，落盘即此序）；folder 占确定顶层位（drop 目标 target 原 index，**格子位置语义：insertion = targetIndex，不做 targetIndex − 1**；先算后删再 clamp；BUG7 2026-09-01 wave-a 语义修订，取代 BUG6 wave-b 的 targetIndex − 1）；中性默认标题（沿用 `Group N` fallback 语义，**默认关闭 folder-lab 分组无关**）；FolderID 新 UUID；取消/无效/stale → 不建 |
| M4 | move into folder | 顶层 app / 另一 folder 成员拖到目标 folder **cell 目标区** | 加入成员（确定插入序：folder 尾部；或按 drop 在成员网格中的位置）；已是成员 → no-op；stale/已删 target → 拒绝；跨 folder move 原子；源 folder 剩 1 **逻辑**成员 → 逻辑 dissolve（ADR-009 Q9）；成功 commit 一次 + 持久化入队一次 |
| M5 | move out / cross-folder | 成员拖到顶层明确 target（顶层条目间 insertion 区或空白顶层区） | 成员成为顶层条目指定位置；源 folder 删除该成员；剩 1 → 逻辑 dissolve；剩 0 → 删 folder；**全部一个原子 mutation**；取消/失焦/stale → 无部分移出；"先退 overlay 再落顶层"经显式 drag coordinator 状态（`overlayMoveOutArmed`）实现，可测，不依赖多回调碰运气 |

- M1–M5 全部：成功 → `LayoutMutation(expectedGeneration:)` 原子提交 → layoutGeneration++ → 呈现更新 → **异步持久化入队**；失败（stale generation/target 不存在）→ 无副作用 + 中性拒。
- 交叉组合：M4 的 cross-folder 与 M5 同引擎；folder-on-folder 拖 → **拒绝**（不嵌套不合并，Q14）；对打开的 overlay 拖入自己的成员 → 正常；拖入自身 folder（move into self）→ no-op。

## Q5. insertion vs folder-create 区分

- **两种 drop zone 视觉可区分**（不只靠颜色，Prompt §5.3）：
  - insertion 带（顶层条目间 / folder 内成员间）：细插入线 + 位置标记（中性色，非品牌色）；
  - folder-create zone（app 条目上的显式高亮区，如 1/3 高度 strip 或角标区域）：独立高亮形状 + 标题提示（如 "新建文件夹"），与 insertion 线形态异构。
- 语义区分：app 条目中心区拖动悬停 = folder-create 候选；条目间窄带 = insertion。判定先于 commit：`DropIntent = .insertion(index) | .createFolder(target) | .intoFolder(target, at:) | .topLevelTarget(index) | .invalid`。
- 测试锁：同一几何输入，两种意图可区分（§10.5）。

## Q6. 顶层 / inner / 跨页输入隔离

- `DragScope` 运行时裁决：drag 源于顶层 cell → `.topLevel`；源于打开 folder 的成员 → `.folder(id)` + inner 语义。
- **顶层 edge turn 只能调用已接受的外层分页入口**（PagingCore 既有、经 surface 的 accepted entry），**绝不直写 visualOffset**；folder scope 的 inner page 变更只影响 overlay 内页（`FolderOverlayView` inner paging 既有路径），**绝不触发外层分页**。
- 内 drag 不得驱动外层 PagingCore offset（既有 inner paging 隔离的延续，1E 已验证模式）。
- 跨页 drop（外层）：turn 后重新 hit-test + 重验 token/layout/catalog generation；目标页呈现新位置；焦点随 drop（ADR-006 焦点迁移规则）。
- 触控板 scrollWheel 与 drag 不同时驱动（输入仲裁：drag active 时 scrollWheel 仍可翻页？**决策：edge dwell 翻页与外层 scrollWheel 互斥——drag active 时 scrollWheel 翻页被抑制，edge turn 接管**；folder 内 drag 时外层 scroll 无效。仲裁经统一 `inputArbiter`，1E scrollWheel 路径语义不变）。

## Q7. 取消路径（search / title edit / refresh / resign / teardown）与输入优先级

- **统一 cancel 出口**（唯一实现）：`DragSessionController.cancel(reason:)` 覆盖：
  ESC（keyCode 53，ADR-006 ESC 语义延伸：drag 中 ESC = 取消 drag，不进焦点清除分支——优先级 drag-cancel > keyboard-selection-exit）；
  窗口失焦/resign active；catalog refresh 到达（先 cancel → 提交新 catalog → reconcile，ADR-009 Q8）；进入 search（`onSearchShortcut` Command-F → cancel → 激活搜索）；标题编辑开始（`beginTitleEditing` → cancel）；overlay 关闭/folder 视觉消失（drag 中 dissolve）；teardown（AppDelegate teardownAll 链）；第二个 drag 开始（废旧）。
- cancel 后：已提交布局不变；preview/insertion/edge timer 全清；焦点回合法位（drag 源条目仍存在 → 回源；不存在 → ADR-006 迁移/文档化 fallback）；**零磁盘写**；旧 completion 不覆盖新 drag。
- **输入优先级**（1E 既有序的扩展，ADR-008 §3：title-edit > folder 层 > search > 顶层 > 背景退出）：drag 仲裁插入在 title-edit 与 folder 层之间？**决策：drag active 时优先级 = drag 自身最高（cancel 除外），但 drag 开始受上层抑制**——标题编辑 active 不开始 drag；搜索 active 禁拖（pointer-down 在 search active 时不进入 pressed）；folder overlay 打开时只允许 member drag（除非 move-out 模式显式 arm，Q4 M5）。
- pointer-down 硬门（统一仲裁）：pointer-down 只能进 `pressed`——不启动、不开 folder；过阈值 → dragging；未过阈值 mouse-up → 派发既有 click/open/launch（顶层 cell、member、空白同一 coordinator，防双重识别）。

## Q8. source/target view 复用 + stale generation 防御

- 视图复用（1E 已有 cell 复用生成门）：drag 绑定 **sourceIdentity + session token**，而非 view 实例；view 复用/重排不破坏进行中 drag 的身份裁决。
- stale 防线（drop 时全部验证）：token 仍在 active registry；layoutGeneration 未过期（drag 期间若被其他 mutation 提交 → cancel 或按 newLayout 重建，**决策：布局 mid-drag 变更 → cancel drag**（安全默认），refresh/catalog 变更 → cancel）；catalogGeneration 未过期；target 仍存在（顶层条目/folder 未消失）；session 未被取消/消费。
- 旧 completion 回调：每 session 一次 commit/cancel 后，controller 置 session 结束；任何迟到回调由 token 校验拒绝。

## Q9. pasteboard 零身份

- **本阶段不用 pasteboard**（自定义状态机，Q1）。若未来切 NSDraggingSession：pasteboard **只放**随机短期 opaque token（进程内 registry 校验），**绝不放** AppID 原值/bundle ID/canonical path/URL/app 名/folder 标题/UUID 原值/成员列表/layout JSON/任何身份或正文。
- 进程内 registry = 身份唯一驻留点；外部进程可观察 pasteboard 也无内容可取（零身份数据）。
- 重复 drop / 外部 payload：token 不匹配或已消费 → 拒绝。

## Q10. commit 顺序：drag commit → UI commit → persist enqueue

固定顺序（单一可测提交链，ADR-009 Q：catalog → visible layout → optional search → provider → open-state/focus）：
1. **DragSessionController**：输入序列 → `DropIntent` → `LayoutMutation(expectedGeneration:)` 提交（纯逻辑，返回新 layout + generation）；
2. **UI commit**：AppGridUI provider 应用新投影（呈现更新、插入线/preview 撤除、pageCount 对齐）；
3. **focus/open-state reconcile**：ADR-006 焦点迁移 + folder open-state 重配（按 folder identity；已开 folder 成员变化 → clamp inner page；folder 消失 → 关 overlay）；
4. **persist enqueue**：异步入队（ADR-009 Q6 持久化；热路径零磁盘）。
- 禁：provider 后置 commit 清掉先前的 search state（search projection 在链中位于 layout 之后、provider 之前；refresh pending 与 search pending 顺序沿用 1E `applyPendingAtIdleBoundary` 既有裁定：search 先）。

## Q11. keyboard / VoiceOver 等价（同一 mutation 引擎）

- 动作集：Move Before/After（顶层与 folder 内）、Move to Previous/Next Page、Move Into Folder、Move Out of Folder、Cancel Reorder。
- 入口：菜单（App 菜单/视图菜单新增"重新排列"子菜单）、上下文菜单（cell 右键）、键盘重排模式（显式进入，如 Option+箭头组合经 `performKeyEquivalent`）、`NSAccessibility` custom actions。
- **硬规则：全部经同一 `DragSessionController` 的 intent 构造 → 同一 LayoutMutation 引擎**——指针与无障碍路径产出**逐位一致**的 mutation（无第二套算法；Q4 表复用）。
- 非法动作（如对 folder 执行 Move Into Folder）→ 动作不可用（灰）或安全拒绝；announcement 可理解（"App 已移动到文件夹 X 之后"类别描述，**不含 path/ID 原文**）。
- 不需要 Accessibility/Input Monitoring 权限；无全局监听。
- VoiceOver/键盘：至少手动门（MANUAL_KEYBOARD_ACCESSIBILITY_GATE）。

## Q12. Reduce Motion + 视觉

- `respectSystemReduceMotion`：drag preview 不缩放/不飞行（中性描边/淡入淡出仅限允许最小位移）；edge turn 动画缩短或取消，**逻辑页仍正确**（ADR-008 既有 RM 参数族：settleDurationReduceMotion 0ms / reduceMotionOverscroll 0.0 / 沿用）。
- 视觉元素（中性，不复制任何被禁来源品牌）：drag preview（半透明条目轮廓 + 名称类别）、insertion indicator、folder-create highlight、invalid 态（**不只靠颜色**：invalid 时 indicator 形态改变+可选项中性符号）。
- preview 不进资源/报告；不含真实 app 截图/图标字节。

## Q13. 入 PARAMETER_RATIONALE 的参数清单

新开 §6「Phase 1F drag」段，每参数一行（默认值/合法范围/来源类别/理由/验证结果/修改日期）：
`dragStartThresholdPT`、`edgeDwellDurationMs`、`edgeZoneWidthPT`、`edgeHysteresisPT`、`dropZoneMarginsPT`（Q3）；另含：`overlayMoveOutArmThresholdPT`（move-out 模式显式 arm 位移，PRODUCT_DECISION）、`maxDragPreviewScale`（RM=1.0 时禁缩放，PLATFORM/ACCESSIBILITY 类）、`edgeTurnMinIntervalMs`（翻页间最小间隔防连翻，PRODUCT_DECISION）。来源类别仅 5 类；验证结果列初始 `TUNING_REQUIRED`（物理调参未发生前不得写 PASS）。

## Q14. 为什么不支持 nested folder / merge / 外部 file drop

- **nested folder**：增加嵌套层 = 新的呈现/焦点/仲裁复杂度与全新持久 schema 维度；Prompt §13 明列非目标；folder 内成员只允许 2F 再评估。拖 folder 到 folder → DropIntent `.invalid`（视觉 invalid 态）。
- **merge**：folder-on-folder 合并会破坏"folder 只含 app"不变量（ADR-009 不变量②③）；合并语义（标题/顺序/溶解）无用户需求支撑，且与逻辑 dissolve 规则纠缠 → 非目标。
- **外部 file drop**：Finder/桌面/其他进程的 file URL drag 需要 AppKit 拖拽会话 + 文件系统权限语义，越过"本应用自定义窗口内"边界与隐私/权限红线（Q1 禁用清单）→ 拒（外部 payload token 校验即拒）。

## 后果

- 单一仲裁入口 + 单一 mutation 引擎：指针与无障碍一致性可测；cancel 全量覆盖可测；热路径零磁盘；pasteboard 零身份。
- 成本：自定义状态机需完整测试矩阵（§10.5/10.6）；edge dwell 参数需实验；Move-Out overlay 协调状态需专门测试。
- 需 Main 转正；实现偏差走 Decision Delta（用户可观察语义/隐私边界/冻结树/验收门不可改）。

## 待决 / Open items

1. `edgeTurnMinIntervalMs` 初值与 hysteresis 联动需 T-1F-C 独立实验（INDEPENDENT_EXPERIMENT 类）。
2. 上下文菜单/菜单入口的最终命名与位置由 T-1F-D 定（中性命名，无品牌复制）。
3. 与 ADR-009 的边界：所有 mutation 的持久化语义以 ADR-009 Q4/Q6/Q9 为准。

## T-1F-A 实现注记

- 无偏差。M3 create folder 初始成员 = [target, source]（先目标后源）、folder 顶层位 = drop 目标 target 原 index（**格子位置语义：insertion = targetIndex，不做 targetIndex − 1**；先算后删再 clamp；BUG7 2026-09-01 wave-a 语义修订，取代 BUG6 wave-b 的 targetIndex − 1）、中性默认标题 `Group N`（最小未用 N）；M4 already-member → no-op（不增 generation）；M5 剩 1 逻辑成员 → 原子逻辑 dissolve（剩余成员回 folder 原顶层位）、剩 0 → 删除 folder；跨 folder move 与源 folder 收缩归并进同一次原子提交（generation 只 +1）；取消路径不进入引擎（cancelled 语义保留位，零写盘）。

## 2026-10-19 implementation note: capture-independent move-out elevation
The pre-collapse preview capture remains authoritative. After collapsing the panel and switching visual host, AppDelegate now calls capture-free `elevateMoveOutPreview` instead of recapturing the potentially cleared/reused source. Existing preparation entry remains compatible; teardown guards prevent resurrection. New unshown tests preserve captured image/name across host changes/source reuse. No drop/threshold/page/commit semantics or measured physical-performance result changes. Explicit folderGrid content context/actual fractional fit is governed by FOLDER_MEMBER_LAYOUT_REFINEMENT_SPEC.md. Native generated move-out admission remains inconclusive; unit success must not be called physical/native motion PASS.
