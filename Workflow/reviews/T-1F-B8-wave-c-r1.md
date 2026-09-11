# T-1F-B8-wave-c — Reviewer Review r1（Stage 1 取证装置 + Stage 2 预授权修复 N1/N3/N2）

- Reviewer: 独立 Reviewer（chef-worker-reviewer-workflow v1.4.1，只读；glm-5.3-flash:cloud）
- AccessDeclaration: **NO_PRIOR_EXPOSURE**（未读取 /Users/mac/Projects/LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）
- 日期: 2026-09-01；判定: **PASS**
- 实跑记录: `swift build -c debug` exit 0；`swift test` 全量 **Executed 1052 tests, 0 failures**（Test Suite 'All tests' passed, 22:08:44；RunLoopFrameDriverTests 本轮无 flaky，未触发隔离复跑；0-executed 情形未出现）；`swift build -c release` exit 0。零 git 操作；除 build/test 外零写操作（本评审文件除外）。

## A. Stage 1 装置完整性 ✓

15 个 mandate 行位置逐一在代码中定位（行号为 Stage 2 后现行行号，sink 注释保留 2026-09-02 锚点）：coordinator s0:201/s1:207/s2:208/s4a+s4b:222-224/s3:239/s4c:233与:249/s4e:306-307+s4d:309/s4f:324/s5:339；window s8:1068/s8b:1075/s8c:1095/s8d:1100（AppDelegate.swift）；handleDragCellClick s7:671/:679；launchMember s7b:784/:789。外加 s6/s6b(dispatchClick:474/:477)、s9_leak(:204-206)、s9b(:496)、sA（AppDelegate:381-383 经公开 onLaunchAttempt，S9 只读观察）。**env 门控属实**：全仓唯一 stderr 输出点 DragUISessionCoordinator.swift:92-94，被 `stderrEnabled`（:83-84，env `PAGING_CLICK_CENSUS=="1"`，启动时定值）单一门控；grep 确认无其它无条件 census 输出（现存 print 均为 telemetry/smoke/perf 既有代码，非本波）。仅计数：sink 名 + 中性 outcome 描述符，无身份/标题/路径/bundleID。

## B. Stage 1 harness 质量 ✓

6 测试真实建模（逐一走代码）：全链测试用真 QuitOnBlankClickWindow（mountInQuitWindow:538-567，seams 生产同构）+ 合成 NSEvent 经 `AppGridCellView.mouseDown`（AppGridCellView:184-197 实核：无 super、`dragCoordinator ?? shared` 真视图入口）+ 真实 pointer 会话建夹（down→4 段 dragged 过阈值→up 落 B → commits==1、members==[beta,alpha]，无 onCommit seam 直呼）+ Path A 识别器状态断言（:615 抑制/:634 恢复）。`testWindowSendEventClassifies…` 用真 sendEvent + 真 blankClickResolvesToCell；`testWindowSwallows…` 断言 s8b+cancel(.escape)。**「仍未建模层」7 项显式在册**（results §Stage1.2：真 handleDragCellClick 方法体/搜索腿/super.sendEvent 无头路由/key-window/全屏传递/识别器真识别/真 NSWorkspace）。测试 5 纯滞留态形成确定性（stale secondDrag 同步事件链，无 sleep/timer）：s9_leak==1（:880）+ Path A 死断言 `!recognizer.isEnabled`（:882）。

## C. Stage 2 修法正确性 ✓

- **N1**（coordinator :300-322）：endSession 位于 s4e/s4d 计数后、`onOverlayBlankClick()`（:319）之前；幂等（endSession 内 isSuppressingClickRecognition guard :492）；与 fallback 分支 :331「先清后派发」同先例；`onOverlayBlankClick` 仍被调用（isBlankClick 时），派发语义未改；endSession 覆盖未过阈值/过阈值两子形态，在 §6.1「分支内」授权内。
- **N3**（:226-238）：pendingBlankPress 收窄为 `sourceCell == nil`（:227-228，真空白行为不变）；sourceCell≠nil 解析失败 → s4c+clickFallbackCell/DownPoint 武装，复用 pointerUp fallback 分支（:323-337）派发——死路 A 归位；s4b 保留观测（:222-224）。
- **N2**：两处均注释（coordinator :145-148、AppDelegate :542-544）；单 `dragGate` 变量单 guard（:207）未拆 drag/click 门，行为零变更。
- **无额外加固**：coordinator 增量仅 census 装置+N1/N3+N2 注释+clickFallbackCell 文档扩展（N3 的一部分）；DragSessionController（mtime 08-31）等禁写文件零触碰。

## D. 测试完整性 ✓

test 4 拆二（N3Fix:742-785 / N1Fix:791-844），净 +1 与 1051→1052 自洽。**census 累计语义增量断言独立验证成立**：N1Fix step 3 空白 pointerDown 入口合法计 s9_leak=1（controller idle+抑制 true），step 4 endSession 愈合；step 5 用 `residentBefore` 增量断言（:837-840）——绝对零断言在该序列结构性必假，Worker「初版误用已纠正」声明与代码事实一致。四回归面：空白退出（sendEvent terminate/s8b 吞点）、成员启动（§3 合成 cell + 全链 launched）、folder 打开（全链+§2）、拖拽（§1 重排+真实会话建夹）全绿；全链 s9_leak==0 双断言（:659/:669）= 验收面达标。

## E. 写范围（mtime 取证）✓

wave-c 窗口 22:02:38–22:06:04 内恰 4 文件：DragUISessionCoordinator.swift（22:02:38）、AppDelegate.swift（22:02:38）、DragCommitIntegrationTests.swift（22:04:39）、results/T-1F-B8-wave-c.md（22:06:04）。冻结树六目录最新均 ≤08-30、Package.swift 08-28、AppLaunchController.swift 08-28 21:46、Docs 最新 19:01（B′ ADR）、PROVENANCE 08-31——零触碰。DragUIVisuals.swift 21:29:36 系并行 wave-v 窗口，早于 wave-c 代码窗且文件零交集，不属本波。19:33 前 mtime 均为 B7/B′ 遗留。

## F. 独立实跑 ✓

见头部实跑记录：debug 0 / 1052-0 / release 0，全部真实执行，与 Worker §Stage2.3（1052/0）一致。

## G. 红线与隐私 ✓

grep buho/launchbetter/ghidra/otool 零命中；census 仅计数无身份；夹具中性（Alpha…Foxtrot、fixture.*、Group 1、固定 UUID）。

## Findings

- **MINOR-1**（D 文档）：DragCommitIntegrationTests.swift:594 引「仍未建模层清单见结果文件 §Stage1.4」，实际清单在 §Stage1.2（§Stage1.4 为验证记录）——交叉引用漂移，不影响判定。
- **QUESTION-1**（记录项，非本波缺陷）：endSession（:491-508）不重置 controller.state。N3 流程中 controller 仍持旧 .pressed 时（resolveSource 失败早退于 controller.pointerDown），fallback 分支 endSession 后 isSessionActive 因 controller 残态短暂为 true，至下一次 pointerDown（secondDrag 重建）/cancel 自愈——系 BUG6 Wave C 以来 endSession 既有语义（fallback 分支同性质），非本波引入、非恶化；生产窗口层 onDragActiveCancel 可兜底。若后续 census 显示该形态有实机症状，宜另立任务而非本波补丁。
- **QUESTION-2**（Main 侧待办，按任务包语义不构成本评审阻塞）：验收六态的 census 表（E1-E7 × S1-S9）当前为待回填占位。任务包 §7 以「Stage 1 证据落盘」为 Stage 2 闸（已满足），且 N1/N3/N2 属 §6 预授权、Worker 经 Main 批准提前执行（results §Stage1.7/§Stage2.4 有据）；但 **Main 最终合并验收仍须以 E1-E7 回填 + 各修法补注「依据：census E 编号」为前置**（§Stage2.4 已自declared）。

## 结论

A–G 全项独立核验完成，证据在册（15 计数点逐一定位、env 门控 grep 证实、N1/N3/N2 逐行核对、mtime 窗口取证、1052/0 真实实跑）。判定 **PASS**：Stage 1 装置符合 mandate，Stage 2 三项预授权修法位置/幂等/先例一致且无过度修复，测试增量断言正确、四回归面覆盖。建议：MINOR-1 顺手改注释；QUESTION-1/2 记入 Main 合并前置清单。