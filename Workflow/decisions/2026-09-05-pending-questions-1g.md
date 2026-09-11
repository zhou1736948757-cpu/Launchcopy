# Phase 1G 挂账决策项（2026-09-05 汇总）

来源：T-G-P1 评审（Workflow/reviews/T-G-P1-r1.md）、T-G-P0 评审（Workflow/reviews/T-G-P0-r1.md）、T-1G-A 评审（Workflow/reviews/T-1G-A-r1.md）。状态：OPEN（待 Chief 决策或用户确认）。

## 需用户确认（Main 汇总批次）
- **Q-2 静默恢复 re-arm**（T-G-P1）：PinchRecognizer.swift L374-383 静默恢复（无结束证据）即 re-arm 候选——合同 8（静默可恢复）vs 合同 12（仅结束证据清除 Fired）张力。Worker 已选保守策略（静默恢复两档：候选保守重置 dataExpired / 锁存保持待 provider 结束证据）。评审建议 Chief/用户确认。
- **Q-3 慢速连续捏合**（T-G-P1）：advanceCandidate re-anchor（L508-513）重启稳定窗口 → 慢速捏合（指间距离变化慢于阈值）永不触发。评审建议 T-G-P6 实机验证（非阻塞）。

## 需 Chief 决策
- **Q-1 suspend 不 bump generation**（T-G-P1）：suspend()（L324-329）不递增 generation（stop L301 / restart L319 会）→ §16.1 重放风险（T-G-P4 若排队 suspend 前事件）。**T-G-P4 集成若未处理升级 MAJOR**。
- **Q-4 冷却跨设备**（T-G-P1）：cooldown 是识别器级跨设备（L251-252、L537），测试仅覆盖同设备。Chief 定：保持跨设备 or 改 per-device。
- **M-3 HotCornerParameters 缺 poll 参数**（T-1G-A）：HotCornerStateMachine.swift L39-55 未含 poll interval / toggle debounce / transition duration → T-1G-D 回填。
- **PLAN.md:542 措辞**（T-G-P0）：写「白名单 6 文件」实际 4 文件读取 + 2 测试文件仅定位 → Chief 修订措辞。

## 已披露不阻塞（记录在案）
- **M-1 dismissReason 归因**（T-1G-A）：LauncherPresentationCoordinator.swift L197-206 非 statusItem/globalShortcut 来源中性回退归因 .statusItem。
- **MINOR-1 stale frame 重建候选**（T-G-P1）：PinchRecognizer.swift L408-411 乱序守卫仅覆盖既有会话，endSession 后 stale frame 可重建候选（未测边缘，低影响）。
- **参数暂定值**（T-G-P1，T-G-P5 评审修正版，与代码一致）：requiredContactCount=4 / baselineStableWindow=0.1 / shrinkThreshold=0.15 / expansionCancelThreshold=0.15 / maxGestureDuration=1.5 / noiseTolerance=0.02 / cooldown=0.5 / maxContactCount=8 / minBaselineRadius=0.02 / dataExpiryInterval=0.5——非参考值，待 §19.2 定案 + T-G-P6 实机验证。

## T-G-P5 评审新增挂账（2026-09-05 深夜）
- **MINOR-1 参数列表乱码已修正**（T-G-P5 → 已关闭）：本文件 L18 原参数列表与代码不符（noiseTolerance 0.15 vs 0.02、cooldown 0.02 vs 0.5、dataExpiry 1.5 vs 0.5、幻影「冷却窗口」「重锚定」参数），已按 T-G-P1 result L93 正确列表修正。
- **MINOR-2 ADR 状态声明**（T-G-P5 → Chief）：PLAN.md:676 写 ADR-011/012/013=ACCEPTED，实际三者均 DRAFT（011/012 Chief DRAFT、013 Worker DRAFT）——Chief 需修订 PLAN.md 措辞或推进 ADR 状态。
- **QUESTION-3 process() 镜像返回**（T-G-P5 → T-1G-E）：FourFingerActivationCoordinator.process() 返回镜像入队事件——T-1G-E 必须用 flushPendingShows() 作为唯一派发出口，避免双派发。
- **证据缺口 (b) 整体状态**（T-G-P5 → Chief）：FOUR_FINGER_PHYSICAL_GATE 未跑（T-G-P6 READY），PLAN L691 要求整体状态 PARTIAL 直到物理门——Chief 定夺。

## T-G-P4 评审新增挂账（2026-09-05 晚）
- **MINOR-1 resume 清队列**（T-G-P4）：FourFingerActivationCoordinator.swift resume()（L151-155）不清 pendingShowTokens——挂起期间经外部路径 handlePinchEvent 注入的事件在「延迟 flush 到 resume 之后」可被派发（挂起拒绝只在 flush 仍处于挂起期时生效）。Q-1 主屏障（suspend 清队列）完好；识别器路径在 .suspended 返回 [] 无此问题。建议 resume() 同步清队列或显式声明 flush 时机契约。
- **QUESTION-1 flush 调用点**（T-G-P4 → T-1G-E）：T-1G-E 需确认 flush 调用点（异步队列时挂起期间未 flush 则 MINOR-1 可达）。
- **QUESTION-2 生产路径恒为 process()**（T-G-P4 → T-1G-E）：handoffToken 清除依赖 process() 帧流；若 T-1G-E 主路径改为 handlePinchEvent 则交接永不清除，需确认生产路径恒为 process()。
