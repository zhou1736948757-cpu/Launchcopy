# T-1F-B10-wave-a-forensics — BUG10 缺陷 A 取证（零行为变更 census 布点）

Status: ready（独立于 wave-c/wave-b，可先行；AppDelegate 与 wave-b 区域不交集）
Wave: BUG10-wave-a-forensics
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并 → Main 组织实机 6 步复测

## §1 背景（FIX-PROMPT §4，强假设 → 先取证）

触发条件已修正为「**开过 folder 再关**」非建夹（census run2 :64-71 时序：s4a+s4d 空白关夹后，s8d 7→29 连续 23 次窗口层判 cell 放行而 s10 恒 5 不增；s8e key1_active1 排除 R5；s13a/b/s9b 配平排除 R2；s10 此前正常触发排除 R1）。静态假设：closeFolder（AppDelegate.swift:774-782）只 removeFromSuperview，而 FolderOverlayView.hitTest:297-303 非按钮区恒 self → overlay 若仍参与命中则吞事件且不留痕迹（与「s8d 增、s10 不增、s0-s9 全零」观测完全一致）。本波**只加 census 布点 + 判别表，零行为变更**；实现包 wave-a-fix 另立且 blocked。

**Main 核验注记（2026-09-02，census run2 行号重钉）**：s4a+s4d 在 :62-63；s8d 7→29 连续 23 次在 :65-115（交替 s8e key1_active1 13→36）；s10 恒 5 至 :190 才恢复；**sA_launch_accepted 4-8 在 :121-149（s8d 段之后、s10 恢复之前）**——FIX-PROMPT「sA×8 全在此前」表述不准确。存在「s10 不增但 sA 增」的启动路径（疑似 Path A surface 手势），其归属待 Chief 定夺是否加布点 5（见 §2 注记）。

## §2 取证布点（FIX-PROMPT §4.4 定案 4 处，现行行号）

1. `FolderOverlayView.swift:297` `hitTest` 入口：overlay 参与 hitTest 次数 + `superview == nil` 布尔位（判别「残留命中」的直接证据）。
2. `FolderOverlayView.swift:281-283` `mouseDown` 静默 return 路径（panel 内非成员区/panel 外循环无命中 return）：现无计数点，补「静默 return」计数（区分「进了 overlay 被吞」vs「根本没进」）。
3. `closeFolder`（AppDelegate.swift:774-782）执行后：overlay 的 `superview` 是否为 nil —— sink 携带该布尔位（判别「移除成功但仍在命中」vs「根本没移除」）。
4. `blankClickResolvesToCell`（AppDelegate.swift:1131-1143，superview 链找 AppGridCellView）：返回 true 时命中链是否含 `FolderOverlayView` —— 判别「cell 在 overlay 内 vs grid 内」关键位。
5. **surface 手势层（D3 增补→Main 实机核实后降级，D-2026-09-02-bug10-fix-plan D3 二次增补）**：实测 AppLaunchController.swift:95 手势 `NSClickGestureRecognizer(target: self, action: #selector(handleGesture(_:)))`，handleGesture @objc private :102-106，**AppDelegate 无挂接闭包** → 按停手条款 s18 不落地（不硬改冻结面；冻结语义=「校验链 :129-143 不可改、缺陷改调用方」，纯计数亦属触碰冻结树文件， Chief 定夺不升级）。中间态（手势触发但 handleCell 未达）判别降级：以既有 sA（onLaunchAttempt :377-385）+ s10 组合判别，见 §7 第 5 行。

## §3 写范围 / 禁写

- 写：`Sources/AppGridUI/FolderOverlayView.swift`（仅 hitTest 入口/mouseDown 静默 return 两处 census 调用）+ `Sources/PagingPrototypeApp/AppDelegate.swift`（仅 closeFolder 后状态位 + blankClickResolvesToCell 命中链位两处；sink 声明用同文件 `extension ClickCensus.Sink`，沿用 T-1F-B9-wave-b 先例）+ 测试（新文件或并入，报告声明）。
- 禁写：DragUIVisuals/DragUISessionCoordinator（ClickCensus 核心，sink 用 extension 追加）；DropIntent（wave-c）；overlay 布局/hitTest 返回值/mouseDown 分支逻辑（**零行为变更**）；AppLaunchController.swift（校验链 :129-143 永不改）；冻结树全列；Docs/；无 git。
- census 纪律：中性名+计数+布尔位；禁坐标/标题/app 名/窗口标题（隐私 A/B/C）。

## §4 建议 sink 命名（Worker 可微调，中性一致）

`overlay_hittest_participates`（+superview==nil 布尔位）、`overlay_mousedown_silent_return`、`closefolder_overlay_state`（+superview==nil 布尔位）、`blankhit_chain_has_overlay`（布尔位）。~~`surface_gesture_fired`~~（s18 已定夺不落地，D3 二次增补）。stderr 输出格式沿用既有（`PAGING_CLICK_CENSUS <sink> <count>`，布尔位以 key1/key0 后缀或状态位，同 s8e 先例）。

## §5 验证

- 测试：①closeFolder 后布点触发且状态位正确（夹具挂/摘 overlay）；②hitTest 计数在 superview==nil 时布尔位翻转；③既有 overlay/census 测试全绿；零行为回归（hitTest 返回值/mouseDown 分支结果与改前逐一对齐——夹具断言）。
- `swift build` debug/release exit 0；`swift test` 全量（1062+新增）。

## §6 用户实机 6 步复测脚本（Main 组织，PAGING_CLICK_CENSUS=1，FIX-PROMPT §4.4 定死）

| 步 | 操� | 期望（假设成立时） |
|---|---|---|
| 1 | 冷启动点顶层 app | s10 + s6 + sA_launch_accepted |
| 2 | 建夹（拖 A 到 B 正中）→ 点顶层 app | **仍能启动** |
| 3 | 打开新 folder | 成员点击能启动（对照） |
| 4 | 空白点击关 folder | s4a + s4d；closeFolder 后 overlay.superview=nil 位 |
| 5 | 点顶层 app | s8d 增而 s10 **不增**；s14 显示 overlay 仍参与 hitTest |
| 6 | ESC 关 folder（对照） | 步 5 复现而本步不复现 → 锁定空白关闭路径 |

## §7 判别表（读数回 Main 后由 Main/Chief 判命中行，FIX-PROMPT §4.4）

| 观测 | 结论 | wave-a-fix 写范围 |
|---|---|---|
| s8d 增、s10 不增、s14 overlay 仍参与 | §1 假设成立 | overlay 移除/hitTest 生命周期（FolderOverlayView+AppDelegate） |
| s8d 增、s10 增、s7b_launchmember_silent 增 | 断在 launchMember guard | AppDelegate 调用方（查 servedRevision） |
| s8d 增、s10 增、sA_launch_rejected_* 增 | 断在校验链 | handleCell **调用方**（AppLaunchController :129-143 冻结不改） |
| s8d 增、s10 不增、s14 overlay 不参与、**sA 增**（s18 缺席；run2 :121-149 形态） | **Path A 手势承接了启动**（sA 增=启动达成 + s10 不增=cell 路径未走）——BUG9「点击打不开」实为部分现象：Path B 死但 Path A 活（时通时断） | 修 Path B 断点（cell.mouseDown→pointerDown 链）；Path A 不可靠性（位移>10pt 静默失败，AppDelegate.swift:935-942 自述）另立观察项，不在本波修 |
| 步 6 也复现 | 与空白路径无关 | 回 Main 重新定位（不实现） |

## §8 输出纪律 / §9 Red flags

- results 写 Workflow/results/T-1F-B10-wave-a-forensics.md：布点清单/单测证据/6 步读数表（回填）/判别建议。
- Red flags：①任何「顺手修」= FAIL（零行为变更铁律）；②hitTest 返回值/mouseDown 分支被布点改变 = 行为变更，Reviewer FAIL；③想碰 AppLaunchController = 红线，停手。