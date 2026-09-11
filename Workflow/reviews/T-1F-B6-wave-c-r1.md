# Review T-1F-B6-wave-c-r1 — BUG6 Wave C 第一层修复（缺陷 2）

Reviewer: 独立只读审查（不修改任何 Sources/Tests/Docs/冻结树）
日期: 2026-08-31（当晚独立复核）
任务包: Workflow/tasks/T-1F-B6-wave-c.md ｜ Worker 结果: Workflow/results/T-1F-B6-wave-c.md

## 唯一判定

**PASS** —— 可合并。

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR
- M-1（§2.1 清单行号漂移，仅文档）：清单若干行号与现文件差 1–4 行（如 pendingBlankPress 武装 return 标 :120、实际 :118-122 内 return :121；pressed 分支末 return 标 :209、实际 :213；handleEvents .clicked 标 :288-291、实际 :286-288）。所有分支仍可无歧义对应，不影响清单实质覆盖。
- M-2（理由表述精度）：pointerDown :123 「未建立任何状态」——实际 :109 已写 `currentPointer`（残留无害：下一 down 重写；endSession 在此反而会误清仍有效的 pendingBlankPress）。判定「不需要」正确，仅理由措辞欠准。

### QUESTION（不阻断；建议 Main 转交 wave-c2 评估）
- Q-1（预存残留窗口，本波已收窄未闭合）：公共 `cancel(reason:)`（:231-239）在 `controller.state == .idle` + 抑制残留 + fallback 武装的三元态下，先清 `clickFallbackCell`（:234）再因 idle 提前 return（:236）——恢复抑制的唯一出口（fallback 分支）被拔掉，抑制再次永久化。触发条件 = stale 武装窗口内发生外部 cancel（catalogRefresh/overlayClose 等），窗口仅一个手势周期，罕见。Worker 已在结果文件风险 §6.1 披露并按「不新增机制」注记保留现状；任务 §2.1 范围限定三指针函数族，cancel 不在其内，本波不扣分。建议 wave-c2 评估：cancel() idle 路径若 `isSuppressingClickRecognition` 为真则仍走 endSession（约 2 行，属第二层范围）。
- Q-2（共存角落）：fallback 武装 + 抑制残留态下再空白按下 → 空白 up 派发 `onOverlayBlankClick` 后抑制/fallback 均未清（pointerUp :183-188）。但空白 up 分支若调 endSession 会误杀同存的真实 `.pressed` 仲裁与 fallback 待派发，Worker 的「不需要/禁止」判断与 Chief 防过度修复注记一致；残留由下一个 fallback 消费点闭合。记录备查。
- Q-3（基线不可复验）：仓库无 git 历史（全部 untracked），446→450/+105 的基线行数无法 diff 复验；现文件实测 450 行、测试文件 608 行与声明终态一致。DBG print 语句（:105/:106/:110 等）是否预置不可考，但不含隐私内容。

## Evidence（实际核验，非转录 Worker 自述）

1. **①顺序**：pointerUp fallback 分支（:190-202）——`down`/`isClick` 于 :195-196 先行捕获（endSession 会清 `clickFallbackDownPoint`，捕获顺序正确）；`endSession()` :197 → `onCellClick(fallback)` :200。`fallback` 由 `if let` 于 endSession 前绑定，派发目标存活。endSession(:352-368) 为超集清场（抑制恢复 :353-357 + 全量清场 :358-366），重入 `cancel(.catalogRefresh)` 时无半旧半新状态。✅
2. **②**：pointerDragged :153-161 —— 过阈值 → `endSession()`（:158）；未过阈值保留 fallback 存活至 pointerUp；随后 pointerUp 走 :204 idle 守卫，无双派发（测试 2 断言 clicks==0 复核）。✅
3. **③清单实质覆盖**：逐条对照三函数全部提前 return（pointerDown 5 条 / pointerDragged 7 条 / pointerUp 7 条）与现文件一一对应；两条「禁止/不需要调用」的 blank 分支判断正确——endSession :360 清 `pendingBlankPress`、:361 清 fallback，在 blank 分支调用会破坏空白点击与 stale 回退，理由成立。§2.3 与 DragSessionController 实源一致：`pointerDown` :67-68 state!=.idle 先 cancel(.secondDrag)，:70-71 sourcePresent 拒 → 仅 `[.cancelled(.secondDrag)]` 无 `.pressed`，coordinator handleEvents(:294-300) 维持仲裁 → 抑制残留，两 fallback 消费点即唯一出口，闭合成立。✅
4. **④防过度修复**：pre-session return（isTornDown :104/:141/:177、dragGate :105、visualHost :106/:142/:178）均未加 endSession；`.cancelled(.secondDrag)` 仲裁语义原样保留（handleEvents :294-300）；全文无新增属性/字段/机制，仅两处 endSession 调用 + 注释（+4 净增可信）。✅
5. **⑤测试质量**（实读 :519-607）：用例 1 直接断言事件序列 `["suppress(false)","suppress(true)","click(stale)"]`（先恢复后派发时序，非 isSessionActive 替代）；用例 2 过阈值 `[false, true]` + up 无派发、无重复恢复；用例 3 ×20 断言 falseCount==20 ∧ trueCount==falseCount ∧ clicks==20 ∧ idle。夹具中性（app1/app2 合成 token；`makeLayoutOnlyApp1` 使 app2 为 stale source 复现 sourcePresent 拒绝）。✅
6. **⑥写范围**：无 git 历史，以 mtime 佐证——近 6h 仅 `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` 与 `Tests/AppGridUITests/DragUISessionCoordinatorTests.swift` 有改动；冻结树、AppDelegate.swift、AppGridCellView.swift、DragSessionController.swift、Package.swift 均无近期改动。✅
7. **⑦独立实跑**（ Reviewer 本机复现，非转录）：`swift build -c debug` exit 0；`swift build -c release` exit 0；`swift test --filter DragUISessionCoordinatorTests` 18/18 passed（含 3 个 MARK-12 用例，exit 0）；**`swift test` 全量 Executed 1015 tests, 0 failures（exit 0）**，与 Worker 主张 1015=1012+3 一致（本次运行全绿，与「RunLoopFrameDriverTests 全量间歇、隔离开 7/7」的 flake 判定互证；该套件属 PagingUI 冻结树，与 AppGridUI 改动无模块交集，报而不修处置合理）。✅
8. **⑧红线**：改动文件仅含中性夹具 token（app1/app2/DragPoint 合成值）；grep 无真实 app 名/用户路径/禁阅仓库痕迹；无 git 操作；AccessDeclaration 声明与可见证据无矛盾。✅

## 结论理由

三条修复点（pointerUp fallback 先清后派发、pointerDragged 过阈值清除恢复抑制、pointerDown sourcePresent 排查结论）与任务包 §2 逐字吻合；§2.1 逐条 return 清单实质完整且两条禁止项判断正确；防过度修复四项约束全部守住；三项新增测试直接命中验收（suppressor 直证 + 20 次配平 + 时序断言）且经 Reviewer 独立全量实跑 1015/0/exit0 复现；写范围与红线干净。残留项均为罕见角落（Q-1 cancel() idle 三元态）且已由 Worker 主动披露、属 wave-c2 语义层，不足以阻断。判定 **PASS**。

—— Reviewer（BUG6 Wave C r1）