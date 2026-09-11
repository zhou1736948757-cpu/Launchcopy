# BUG10 交接文档（致 Codex 审查方）

- 日期：2026-09-04
- 项目：/Users/mac/Projects/Launch_Copy/PagingPrototype（SwiftPM + AppKit，macOS 14，macOS Launchpad 类应用独立重实现）
- 构建：`swift build -c release`；运行 `.build/release/PagingPrototypeApp`；census 埋点经 env `PAGING_CLICK_CENSUS=1` 门控输出到 stderr
- 测试基线：1123 tests exit 0（BUG10 取证/修复波合并后）；当前二进制含全部 census sink + B1 手动投递门（默认关）

---

## 一、用户报告症状（原话）

1. 「点击应用打不开」（主界面顶层 app 单击无法启动；**键盘 Return 可正常启动**——早前实机确认）
2. 「点空白处也退出不了」（用户观感；下方 §五 说明实际机制）
3. 「点 ESC 好像才退出的」（ESC keyDown 退出正常）

## 二、事件链（census 实测，2026-09-04 门控关实例 /tmp/bug10_b1_a_run.log，34 次点击）

```
sE6_monitor_down/up 1→34       ← 全部 leftMouseDown 进入 NSApp（addLocalMonitor 捕获，返回原样放行）
sE6b_meta_type_1_subtype_3     ← 全部为触控板触摸合成事件（subtype=3）——但见 §四，subtype 无关
s8e key1_active1 1→34          ← 窗口全程 key + app active（R5 激活假说排除）
sE1_window_owner_match 1→34    ← event.windowNumber == self == keyWindow（归属一致）
s18_hit_manual_chain_AppGridCellView_AppGridPageView_PageHostView_NSView_PagingSurface_ClickDeliveryProbeView 1→33
                                ← 窗口层手动 hitTest 33/34 命中真实 AppGridCellView（cell）
s18_hit_internal_chain（同链）present 8 / absent 25
                                ← AppKit 内部 hit-test 仅 8/34 被调用；且命中同一 cell
s8d_window_cell_passthrough 1→33  ← 窗口层判定 cell 命中，放行 super.sendEvent(event)
s10_cell_mousedown_fired 恒 0     ← ★ AppGridCellView.mouseDown 从未被调用（34/34）
sA_launch_accepted 恒 0           ← ★ surface 级 NSClickGestureRecognizer（Path A）零触发
第 34 击（页面空白处）：
s18_hit_manual_chain_AppGridPageView_PageHostView_...（无 cell）
s8_window_blank_unclassified 1 → s8c_window_blank_terminate 1（页面空白退出正常）
```

**核心矛盾**：事件进入 NSApp 事件循环（monitor 34/34）→ 窗口层手动 hitTest 与（少数）AppKit 内部 hit-test 都命中同一真实 cell → super.sendEvent 放行 → 但 `mouseDown(with:)` 永远到不了任何视图（cell s10=0、contentView 探针 s18_delivered_contentview=0、中间层零覆写）。

## 三、代码路径

- 窗口层：`Sources/PagingPrototypeApp/AppDelegate.swift` `QuitOnBlankClickWindow.sendEvent`（:1000+ 区域）——leftMouseDown → contentView.convert + hitTest → `blankClickResolvesToCell`（沿 superview 链找 AppGridCellView，搜索 field 为交互区）→ 命中 cell→`s8d` 放行 `super.sendEvent(event)`；空白→`s8c` terminate（或 folder 打开时关夹、drag active 时 `s8b` 吞）
- 视图层：`Sources/AppGridUI/AppGridCellView.swift`——`hitTest(_:)` 漏斗（点在 bounds 内恒返回 self，BUG9 wave-a 修复，:215-217）；`mouseDown` :188-195（首行 `s10` :189；`(dragCoordinator ?? DragUISessionCoordinator.shared)?.pointerDown(...)` :192-193，nil 时 `s11`）；`mouseUp` :202-204 → coordinator.pointerUp；`mouseDragged` :197-205
- 拖拽协调器：`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` pointerDown :200-266（s0 tornDown/s9 抑制滞留/s1 dragGate/s2 visualHost/s3 layoutProvider/s4a/s4b/s4c 空白与 fallback 判定）——**从未被进入**（s0 亦零输出）
- 启动双通路：Path A = `AppLaunchController.install()`（AppLaunchController.swift:93-98，冻结文件）surface 挂 NSClickGestureRecognizer→handleClick→handleCell 校验链（:129-143 冻结）；Path B = cell.mouseDown→coordinator→.clicked→onCellClick→handleDragCellClick→launchMember。**两条都死**（sA=0 且 s10=0）

## 四、已排除（实验证据）

| 假说 | 排除证据 |
|---|---|
| R5 激活点击吞首击（窗口非 key） | s8e key1_active1 34/34；E1 归属 match 34/34 |
| 触摸 subtype=3 专用路由缺失 | A1 换输入实验：USB 鼠标 subtype=0 30/43 同样 s10=0（事件类型无关） |
| 窗口归属不一致（event.window≠key） | E1 三布尔一致 34/34 |
| overlay 残留吞事件 | s14/s16/s17_ov0 全程零/ov0 |
| 抑制滞留（clickRecognitionSuppressor 卡死） | s13a/s13b/s9b 全程零输出（本次无拖拽会话） |
| 二进制陈旧 | 强制重建 + strings 核验全 sink PRESENT |
| hitTest 坐标语义错（漏斗误判） | /tmp/hittest_probe 实证 point 为父坐标系、frame.contains 正确 |
| 子视图拦截（iconView/nameLabel） | BUG9 修复后 hitTest 恒 self，且 33/34 命中 cell 仍不触发 |
| relayout 时序（命中缓存失效） | E5 差分仅首击 yes，与 absent 无关 |

## 五、空白"退不出"的机制（本次实测解释）

窗口层空白判定 = `hitTest` 不是 cell 才算空白。但 **AppGridCellView 的整块格子 bounds 都算 cell**（hitTest 漏斗返回 self；cell 无 isFlipped、bounds 覆盖整格，图标仅是子视图）——用户点在**格内空白/格子之间**时 hitTest 返回 cell → `s8d` 放行 → 随后 mouseDown 丢失（主 bug）→ 无任何反应 =「退不出」观感。真·页面空白（PageHostView 层）退出正常（第 34 击 `s8c` 实证）。即：**空白退出问题与点击打不开是同一个根因的两面**——AppKit 内部分发层不投递 mouseDown。

## 六、定罪与修复候选

- **定罪（h）**：AppKit 内部分发层吞掉 mouseDown——事件在 `super.sendEvent` 之后、视图 mouseDown 之前被丢弃/内部处理（AppKit 多数时候不做 hit-test 就处理了该事件：absent 25/34，提示其走非标准内部路径，与 8/34 的内部 hit-test 旁路行为自洽）
- **手动投递实验（E4 结果 A，门控开）**：sendEvent 放行分支手动 `hit?.mouseDown(with: event)` + return——16/16 全触发 cell.mouseDown（s10==s8d==sE4==16）：证明窗口层判定正确、视图链健全，断点唯一在 AppKit 内部
- **B1 候选（已实现并合并，默认关）**：env `PAGING_CLICK_MANUAL_DELIVERY=1` 门控——leftMouseDown 命中 cell→手动投递+记录视图→return；leftMouseUp/leftMouseDragged→投记录视图→return（闭环）；空白/ESC/失 key→原语义；转正需实机验证（s10 增量=击数、sA>0、空白/ESC 退出、拖拽回归）

## 七、当前状态与待办

- 基线 1123/0；B1 已合并；**门控关 A 复测完成**（§二 读数=基线对照，行为与修复前一致）
- **待办：门控开 B 复测**（`PAGING_CLICK_MANUAL_DELIVERY=1 PAGING_CLICK_CENSUS=1`）——预期 s10 增量=击数、sA_launch_accepted>0、无 stuck-.pressed、拖拽/空白/ESC 全回归
- 观察项（不开新任务）：keyActive=false 启动瞬间（AppDelegate.swift:276 makeKeyAndOrderFront 先于 :281 activate）+ Path A 识别器 allowableMovement 默认 10pt 静默失败
- 冻结树（不可改）：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、AppLaunchController.swift
- 治理：Main 不实现业务代码；修复 = Worker 实现 → 独立 Reviewer 显式 PASS → 合并；无 git（零提交）；隐私中性（A/B/C 代称）

## 八、给 Codex 的开放问题（供独立判断）

1. AppKit 在什么条件下对 leftMouseDown 不做窗口内 hit-test 就内部消化（absent 25/34）？窗口层手动 hitTest 与 AppKit 内部路由不同源的合理解释？
2. 全屏过渡（启动 0.3s 后 toggleFullScreen）是否破坏 AppKit 鼠标事件路由状态（tracking/内部视图缓存）？为何 scrollWheel/keyDown 正常而 mouseDown 全灭？
3. B1 手动投递闭环作为生产方案的结构风险（如 AppKit 状态未建立导致的后续事件错位）与更优替代（如事件重建、视图层拦截、NSView 子类化窗口内容视图）？
4. cell 格内空白语义：若修复 mouseDown 投递，用户点格内空白应关夹/无操作还是退出？（行为规格问题）
