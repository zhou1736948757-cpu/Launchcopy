# T-1F-B8-planning — BUG8 诊断与修复波次规划（Chief 任务）

Status: ready
Role: Chief (glm-5.3；诊断 + 规划；不写产品/测试代码)
上游：用户实机复测（2026-09-01，BUG7 三波合并基线 1036/0 后）报告 2 缺陷

## 1. 用户报告（原话要点）

1. 「a软件移到边缘的时候，也就是右边最后一列那里的时候，蓝色的那个线会显示到最右下角的地方，但是功能是没问题的」—— 蓝条视觉指示位置错（显示在最右下角，非落点处）；落点/功能正确。**已知问题**：Reviewer B′（T-1F-B7-wave-b-r1 QUESTION-1）已确认 = Wave B′ 全局换算引入、纯视觉层（DragUIVisuals 消费同一 intent + 页内 frames，未按注记回减）、落点语义正确；已挂账"单文件小波"。
2. 「形成folder以后folder里面的软件点击是可以打开的，但是主页面里面的软件点击打不开」—— **主界面顶层 app 单击打不开再次复现**（folder 内成员启动正常，与 BUG7 缺陷 3 症状逐字相同）。关键事实：Wave C′（合成 cell + 当前 servedRevision 路径）已合并，此症状三现（BUG6 缺陷 2 → BUG7 缺陷 3 → 本次），说明历史修复（fallback endSession 泄漏 / live-token 合成路径）均未触及真根因，或存在另一条未覆盖的吞点路径。

## 2. 已知相关代码锚点（供 Chief 参考，需 Chief 重新验证而非采信）

- 点击链：AppGridCellView.mouseDown → DragUISessionCoordinator.pointerDown（:107-141）→ pointerUp click 路径（:206-214, state==.pressed → .clicked）→ handleEvents（:287 → dispatchClick :335）→ onCellClick（AppDelegate.swift:578-580）→ handleDragCellClick（:640-654）
- C′ 已改：handleDragCellClick app-cell 分支统一 launchMember(appID)（合成 cell + servedRevision；身份从 bindingToken?.appID as? AppID 读）；QuitOnBlankClickWindow.sendEvent 收窄为仅空白+session active 才 cancel/吞；DragUISessionCoordinator 5 处 DBG 已删
- 可疑未覆盖路径（Reviewer C′ QUESTION「死路 A」）：resolveSource 失败 → pendingBlankPress → pointerUp 未过阈值 → onOverlayBlankClick（主界面 overlay 未开时该回调的语义需核实）；pointerDown 中 controller.pointerDown 返回非 .pressed 且 sourceCell nil 时 clickFallbackCell 不武装 → 点击落入哪条路径
- Wave C（BUG6）修过 fallback 不 endSession → suppressor 泄漏（isSuppressingClickRecognition 永久 true）；本次复测不排除新的泄漏路径
- QuitOnBlankClickWindow 收窄后：cell 命中 → blankClickResolvesToCell true → 放行 super → mouseDown 进 cell/coordinator——这条路径在 C′ 后是否真的通（用户实测：不通）——重点是确定吞点

## 3. Chief 产出要求

1. `Workflow/BUG8-REPORT.md`（诊断报告）：用户原话 §0；两缺陷逐一定位 §1-2（带行号、机制推演、与历史修复的关系）、约束与红线 §3、修复波次建议 §4（含取证 mandate——若 harness 无法复现须明确静态链路排查与实机取证手段）、教训 §5（症状三现的流程反思）
2. 修复任务包（Worker 可执行、Reviewer 可门禁）：沿用 T-1F-B8-wave-* 命名；Status/写范围/禁写/必读/验证/验收/输出纪律完整
3. 蓝条视觉小波并入本 BUG8 波次（已挂账，用户实机确认）
4. 若需决策（冻结树/参数/范围），写 Workflow/decisions/D-*.md

## 4. 红线（Chief 须在报告中声明）

- 绝不读取 /Users/mac/Projects/LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何 Ghidra/otool dump（行为期望以用户原话为规格）
- Main 不实现业务代码；每个缺陷 = Worker → 独立 Reviewer PASS → Main 合并
- 冻结树：Sources/PagingCore/、AppCatalogCore/、MacAppCatalog/、AppIconPipeline/、PagingTelemetry/、PagingUI/、Package.swift、PagingPrototypeApp/AppLaunchController.swift
- 隐私：A/B 代称；中性计数；夹具中性
- 基线：1036/0（debug/release exit 0）；无 git 操作

## 5. 输出纪律

- 诊断报告与任务包落盘后回复 <250 词；无大代码块
- 所有 file:line 引用须对照源码实测（不得凭记忆）；Chief 修正任何旧报告漂移