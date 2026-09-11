# BUG9-REPORT — 主页面点击全部失效（census 实证 + 链路取证）

诊断人：Chief（BUG9 诊断轮，chef-worker-reviewer-workflow v1.4.1）
基线：1052/0（BUG8 wave-c+wave-v 已合并）。取证：Main bash-24 census + Chief 只读实测（本文件行号全部为 2026-09-02 现行树实测，含对 Main 事实清单的 3 处行号漂移修正，见 §4）。

## §0 用户原话（隐私代称 A/B/C）

- 本轮：「现在在主页面点击软件都打不开」。
- 上一轮（BUG8 §0 存档）：「形成folder以后folder里面的软件点击是可以打开的，但是主页面里面的软件点击打不开」。
- 症状三现：BUG6 缺陷2 → BUG7 缺陷3 → BUG9（同一症状第三现）。

## §1 Census 实证（Main bash-24 + Chief 复核）

- 读数：`s8d_window_cell_passthrough ×9`、`s8_window_blank_unclassified ×1`、`s8c_window_blank_terminate ×1`。
- 窗口层健康：QuitOnBlankClickWindow.sendEvent（AppDelegate.swift:1016-1130，cell 判定 :1077-1090）9 次点击全部判为 cell 命中并放行 `super.sendEvent(event)`；空白分支也活（s8c 已 terminate 一次）。
- coordinator 层全灭且**强于 Main 的推断**：pointerDown 首行即 `guard !isTornDown else { ClickCensus.hit(Sink.pointerDownTornDown); return }`（DragUISessionCoordinator.swift:200-201）——连 teardown 态入口都会吐 s0。**s0-s9/sA/s6 全无 = pointerDown 从未被进入**（不是入口内被拒）。
- census 机制健康（s8d 同一 stderr 管道有输出）。

## §2 链路实测与假设裁决

实测（现行行号）：
- 装配：installDragUI 内 `DragUISessionCoordinator.shared = coordinator`（AppDelegate.swift:**:548**，Main 清单写 :533 为漂移）；`self.dragCoordinator = coordinator`（**:615**）。
- cell 接线：**全仓无任何代码给 `cell.dragCoordinator` 赋值**（grep 仅命中两处 weak 属性声明：AppGridCellView.swift:58、FolderOverlayView.swift:65）；生产 cell 依赖 `?? DragUISessionCoordinator.shared` 兜底（AppGridCellView.swift:60-62 注释自述「cell 由渲染器懒创建，无法逐 cell 注入」）。
- pointerDown 入口序（DragUISessionCoordinator.swift:200-236）：s0 guard → s9 抑制观测（if，:202-205）→ s1 dragGate → s2 visualHost → … 任一入口必吐 sink。
- cell 子视图（AppGridCellView.swift:44/:47/:78-96）：iconView=NSImageView（iconSide² 居中，**最大点击靶**）、nameLabel/memberCountLabel=NSTextField(label)、folderSymbolView=NSImageView；**cell 无任何交互性子控件**。
- **关键对照（R 定案证据）**：FolderOverlayView.hitTest（FolderOverlayView.swift:**:297-303**）除 prev/next 按钮外**恒返回 self** → overlay 区域一切点击都进 FolderOverlayView.mouseDown（:267-284）→ coordinator → 成员启动活。AppGridCellView **无 hitTest 覆写**（全仓 grep acceptsFirstMouse/hitTest 覆写仅此一处对照）。
- :908-914 = installFullScreenToggle（纯菜单装配）→ Main 假设 C 该区域**排除**。
- 排除 B（shared 运行时 nil）：`DragUISessionCoordinator.shared = nil` 全仓唯一 :1000（teardownAll）；teardownAll 调用点仅 selfDrive 结束（:893-898，且 :897 紧跟 `NSApp.terminate(nil)`）/windowWillClose（:963-965）/applicationWillTerminate（:967-969）；applicationShouldTerminateAfterLastWindowClosed=true（:949-951）→ **UI 存活期间 shared 不可能为 nil**。teardownAll 首行 `guard let surface else { return }`（:972）提前返回时更不会清 shared。
- 排除「命中非 cell 链」：s8d 的 cell 判定走 superview 链（:1077-1090），9 次全判 cell。

结论：断点在**窗口放行之后、pointerDown 之前**的未布点区间，剩两个活候选：

- **R5（交付层）**：点击被 AppKit 当激活点击吞掉——窗口非 key（全屏 0.3s 延迟 toggle 后 key 状态从未被观测过；全仓无任何 isKeyWindow/NSApp.isActive 记录点）或 acceptsFirstMouse 默认 false（全仓无覆写，grep 零命中）→ 非激活窗口首击只激活不交付。census 签名与 9/9 全灭一致（sendEvent 层 sees 一切、视图层全无）。
- **R1（视图路由层）**：点击命中 cell 子视图（iconView/label），NSControl/NSImageView 家族默认拦截 mouse 事件不向 nextResponder 转发 → AppGridCellView.mouseDown（:184-187）永不触发。用户瞄准图标（最大靶）→ 高占比全灭。overlay 对照（hitTest→self 则活）是同一代码库内的正向先例；反向不能由静态分析单独定罪（历史上 coordinator 拖拽曾真实工作，拖拽起点分布未知）。
- **R2（Path A 并行死亡）**：另一启动通路 = surface 上 AppLaunchController 识别器（冻结文件），仓库内自述不可靠（AppDelegate.swift:935-942 T-1C-D repair 注记：「全屏过渡…吞掉首击…位移即静默失败」——QuitOnBlankClickWindow 正为此而生）+ 仲裁期识别抑制。**抑制状态当前不可测**：s9_leak 计数点在 pointerDown 内部（:202-205），pointerDown 不跑则恒盲。R5/R1 杀 Path B、R2 杀 Path A → 双通路齐灭。

## §3 约束

冻结树：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift。Main 不实现；每缺陷 Worker→独立 Reviewer PASS→合并；禁读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse；无 git；隐私 A/B/C。

## §4 行号漂移修正（对 Main 事实清单）

① shared 赋值 :533→**:548**；② 窗口流程 activate :257→:259、toggleFullScreen :266-270→**:274-276**（:266-273 为注释与 collectionBehavior）；③ teardownAll :971-1010→**:971-1017**；④ pointerDown 现行 **:200-236**（wave-c census 块 :22-100 使整体后移，旧引用 :103-135 作废）；⑤ selfDrive 结束实为 **:893-898**（含 terminate）。

## §5 波次建议

1. **wave-a（ready，单文件）**：AppGridCellView.swift 加 hitTest 漏斗（唯一在库先例=FolderOverlayView.swift:297-303）+ cell 层 census s10/s11（同文件内 `extension ClickCensus.Sink`，不碰 coordinator 核心）。修 R1 候选 + 给未建模层装计数器；若真凶是 R5 则本波零害（cell 子视图全被动，漏斗无行为损失）且 census 会证明。
2. **wave-b（两段式，与 wave-a 零文件交集可并行）**：Stage 1 取证——s8e_window_key_state（QuitOnBlankClickWindow.sendEvent 内记 isKeyWindow/NSApp.isActive）+ s13 抑制可见性（AppDelegate 抑制闭包处）+ 实机 E1-E5 判别序列（icon vs cell 背景 vs 切换后首击 vs folder 成员 vs 空白）。Stage 2 仅在 census 证据上预授权：R5 实锤 → acceptsFirstMouse(:)→true（仅 AppGridCellView）+ 全屏后 key 恢复（AppDelegate，≤10 行）；s13 实锤抑制滞留 → 回报 Chief 另立波（沿用 BUG8 N1 语义），不自动修。
3. 判别表（Stage 1 读数 → 结论）：E2 背景点击开而 E1 icon 点击不开 → R1 定罪（wave-a 即修复）；s8e 显示死点击时 !isKeyWindow → R5 定罪（Stage 2 批准项一）；s10 有值而 s0-s4 全零 → 查 s11（lookup nil，B 复活证据，极低概率）；E4 folder 成员不开 → 全局交付层问题升级（Stage 2 批准项二）。

## §6 症状三现反思

三轮修复全部落在 coordinator 内部/派发层（BUG6 缺陷2 fallback、BUG7 统一启动、BUG8 N1/N3），**从未给「窗口放行 → cell.mouseDown → pointerDown」这段视图层装过任何计数器**；C′ harness 直呼 pointerDown，结构性测不到该区间（BUG8 §2 已列 5 层未建模，本轮补第 6 层=cell 子视图 hitTest 拦截）。纪律固化：修复波合并前必须声明事件链逐层布点覆盖；「复现不了」先加 census 再改结构。