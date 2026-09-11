# D-2026-09-02-bug9-click-delivery — BUG9 点击交付层诊断定案

Status: adopted（BUG9 诊断轮 Chief 定案）

## D1 断点定界（census 实证）

窗口层健康（QuitOnBlankClickWindow.sendEvent AppDelegate.swift:1016-1130，s8d_window_cell_passthrough ×9 + 空白分支 s8c 已 terminate），pointerDown 从未被进入（DragUISessionCoordinator.swift:200-201 首行 teardown 守卫 s0 亦零输出）。断点 = 窗口放行后 → cell.mouseDown（AppGridCellView.swift:184-187）→ pointerDown 之间。shared 运行时 nil 排除（唯一清点 :1000，其调用方 :893-898/:963-965/:967-969 均以应用终止收场；:972 guard surface 早返回不清 shared）。

## D2 双候选与判别归属

- R1 视图路由：cell 子视图（iconView=NSImageView :78-82、nameLabel/memberCountLabel=NSTextField :84-96）默认拦截 mouse 事件不转发 → cell.mouseDown 永不触发；库内正向先例 FolderOverlayView.hitTest :297-303 恒 self（folder 点击活的唯一路由差异）。→ wave-a 修复 + s10/s11 计数。
- R5 交付层：窗口 key 状态全仓零观测 + acceptsFirstMouse 无覆写（NSView 默认 false）→ 激活点击吞没假说。→ wave-b s8e + E1/E2/E3 判别。
- R2 Path A：识别器 may-not-fire 系仓库自述（AppDelegate.swift:935-942）+ 抑制状态不可测（s9 在 pointerDown 内 :202-205）→ wave-b s13。**静态分析无法在 R1/R5 间独审定罪 → 两波并进、以 census 读数收束**（BUG8 §5 教训的执行）。

## D3 wave-a 最小修原则

单文件 AppGridCellView.swift；hitTest 恒 self 无需交互子控件例外；census sink 以同文件 `extension ClickCensus.Sink` 追加，ClickCensus 核心（DragUISessionCoordinator.swift:22-100）零触碰。若 R5 才是真凶，本波零害（cell 子视图全被动，漏斗无行为损失）且布点自证。

## D4 Stage 2 预授权边界

仅两项（wave-b §3）：s8e 实锤非 key → acceptsFirstMouse 仅 cell + 全屏后 key 恢复（≤10 行）；s13 实锤抑制滞留 → 不自动修，回报另立波。Path A 识别器本体在冻结面，永不硬改。

## D5 调度

wave-a（AppGridCellView.swift）与 wave-b Stage 1（AppDelegate.swift）零文件交集可并行；E 序列在两波合并后的实机跑（wave-a 未合并时 E1/E2 读数同样有效，归因更干净，Main 可先跑 Stage 1）。每波 Worker→独立 Reviewer PASS→Main 合并；Reviewer FAIL #1→Chief Decision Delta、#2→Expert Worker（MAIN_BRIEF 1E 沿用）。

## D6 观察项（不修）

「folder 成员点击活、主页面死」的对照差异是诊断资产，修 R1 后应消失；若消失后仍偶发单点失效，挂 BUG10 取证，不在本轮回。