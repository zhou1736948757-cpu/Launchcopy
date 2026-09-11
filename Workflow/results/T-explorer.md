# Worker Result: T-explorer（Explorer A 只读分析）

- **Task**: T-explorer（Explorer A：状态机与 Core 测试分析）
- **Role**: Explorer A（ollama/glm-5.2，max）
- **Date**: 2026-08-28
- **归档**: Main 存档（只读角色，未写任何项目文件）
- **依据**: PHASE1_PAGING_PROTOTYPE_PROMPT.md §2.1/§3.C–J/§6/§7.1–7.2/§8.4/§9 + Apple 公开 API 文档

## Main 验证结论

- 覆盖度：5 状态+转换表、§3.F 六条硬门禁逐条机制、monotonic token stale rejection、pageCount/resize/teardown 边界、Reduce Motion 完整性、18+ 参数来源类别——与任务包验收标准一一对应。
- 来源纪律：未读取 §1.3 禁止路径、未读取治理文档、未引用旧项目字段/类结构/参数簇（报告自称，待 Reviewer E 抽查）。
- 状态：**PASSED**（Main 验证）。

---

## 1. 状态模型语义

### 1.1 五状态定义与所有权

| 状态 | 语义 | 谁拥有视觉偏移 | 谁拥有语义页 |
|------|------|---------------|-------------|
| `idle` | 无手势、无动画，页面静止 | Core（pageWidth × currentPage 的确定值） | Core（committedPage，整数） |
| `tracking` | 用户手指在触控板上，位移实时跟随 | Core（gestureOffset，连续值，由 gesture session 持有） | Core（committedPage 不变，仅在 tracking 结束时可能变更） |
| `settling` | 手势结束后正在动画到目标页 | Core（动画插值的连续值，由 transition context 持有） | Core（targetPage 已决定但未 committed，commit 在动画自然完成时发生） |
| `interrupted` | settling 中收到新手势，旧 transition 被作废 | Core（从旧动画当前显示位置接管的连续值，新 gesture session 持有） | Core（committedPage 仍为 settle 开始前的值） |
| `cancelled` | 异常或外部干预（窗口关闭、pageCount 骤降）导致当前操作放弃 | Core（重置到合法确定值） | Core（clamped 到新合法范围） |

**关键所有权原则**

1. **视觉偏移唯一所有权**：Core 拥有 `visualOffset: Double`（以 page-width 为单位的连续值），是 UI 层渲染的唯一数据源；UI 不自行计算偏移。
2. **语义页提交时机**：`committedPage` 只在以下时刻变更：settle 动画自然完成时 commit 到 targetPage；cancel/teardown 时 clamp；tracking 中不 commit。
3. **手势 session 生命周期**：从 `NSEvent.phase == .began` 创建，到 `.ended`/`.cancelled` 结束；session 持有 visualOffset 写权。
4. **Transition context 生命周期**：从 settle 开始创建，到自然完成或被中断结束；携带 monotonic token；被中断后永远不能再 commit。

### 1.2 状态转换表

| 当前状态 | 输入事件 | 目标状态 | 关键动作 |
|----------|---------|----------|---------|
| idle | gesture began | tracking | 创建 GestureSession，visualOffset = committedPage × pageWidth |
| tracking | gesture changed | tracking | 累积位移，更新 visualOffset（含边界阻尼） |
| tracking | gesture ended | settling | 计算 targetPage，创建 TransitionContext（新 token），启动 settle 动画 |
| tracking | gesture cancelled | idle | 丢弃 session，visualOffset 回到 committedPage × pageWidth |
| tracking | momentum | tracking* | momentum 属同一 session，继续更新 visualOffset |
| tracking | window close | cancelled | 停止一切，teardown |
| tracking | pageCount decrease | tracking | rebase：clamp committedPage；visualOffset 超界则 clamp |
| settling | gesture began | interrupted→tracking | **核心中断路径**：读取当前显示位置作为新 session 起点，作废旧 transition token |
| settling | animation natural complete | idle | 验证 token 仍有效 → commit targetPage → 清除 transition |
| settling | pageCount decrease | cancelled→idle | clamp committedPage，visualOffset 重置到 clamped page × pageWidth |
| settling | resize | settling* | rebase visualOffset 到新 pageWidth 等价位置，重算 targetPage |
| settling | window close | cancelled | 停止动画，teardown |
| interrupted | (同 tracking) | — | 短暂状态，立即转为 tracking |
| cancelled | (terminal) | idle | 清理后回到 idle |

> momentum 视为 tracking 子阶段（session 内部标记区分，不引入新顶层状态）；settling 中 resize：目标页新几何下仍合法则继续动画到新位置，不合法（targetPage 被删）则 cancel 并 clamp。

### 1.3 事件输入与防御处理

NSEvent scrollWheel 提供 `event.phase`（手势接触阶段）与 `event.momentumPhase`（惯性阶段）两个独立概念。

防御序列：`.began` 在非 idle/settling 到达 → 中断路径或忽略重复 began；`.ended`/`.cancelled` 后直接 `.changed` → 忽略直到新 `.began`；momentum 与 phase 并存 → phase 优先；完全无 phase（旧式鼠标滚轮）→ fallback 路径，不用于物理验收门。

## 2. 中断不变量（§3.F 六条硬门禁）

**门禁 1（立即接管）**：settling 收到 `.began`：同调用栈内①停止旧动画（CAAnimation → `layer.removeAnimation(forKey:)`；display link → cancel flag 下帧退出）②读取当前显示位置（CAAnimation → presentation layer；手动插值 → 上帧写入值）③创建新 GestureSession 以当前位置为起点④settling→interrupted→tracking。接管是同步的，无异步窗口。

**门禁 2（位置连续）**：禁止使用旧动画起点/目标作为新起点；唯一合法起点 = 当前帧用户实际看到的偏移；中断前最后一帧与接管起点差值应 < 1px（或 < 1/refreshRate × maxVelocity 容差）。

**门禁 3（不跳回旧点）**：旧 TransitionContext 作废后其 source/target offset 不再被读取；GestureSession 只存 `currentOffset`（从中断点开始），不存"动画起点"；`activeTransition` 作废后立即置 nil。

**门禁 4（旧 completion 不覆盖新状态）**：三层防护：①token 检查（回调 token != 当前 token → stale 忽略）②状态检查（非 settling → 忽略）③幂等 commit（pending→committed 才返回 true）。注意 `animationDidStop` 的 `finished` 参数不可单独作为取消依据。

**门禁 5（无双重 commit）**：每 GestureSession→Transition 链路最多一次 commit；`commitState: .pending/.committed/.stale`；快速来回场景下每次中断作废旧 token，新 token 递增，只有最后一个自然完成的 transition commit 生效。

**门禁 6（close/resize/pageCount 安全取消或重基准）**：窗口关闭 → `willCloseNotification` 中设 `isTearingDown`、停 display link、移除动画、清 observer/timer、清 activeTransition；resize → 比例保持 rebase（tracking 只更新 offset；settling 重算 target 用新 token 重启动画，debounce/coalesce 防布局风暴）；pageCount 减少 → tracking：clamp committedPage + clamp visualOffset，手势继续；settling：target ≥ newCount 则 cancel 并 clamp，target 合法则继续动画。

## 3. Stale Completion Rejection

**方案：单调递增 token（generation number）**，`UInt64`，每次 beginSettle 时递增；回调携带创建时 token，与 `activeTransition?.token` 比较；失效条件：token 不匹配 / activeTransition nil / commitState != .pending / isTearingDown。

| 方案 | 结论 |
|---|---|
| Monotonic token | ✅ 推荐（O(1) 比较，无泄漏） |
| 对象身份 === | 备选（闭包强引用风险） |
| 时间戳比较 | ❌（精度/时钟回拨） |
| 状态枚举检查 | 仅作第二防线（竞态：回调可能在状态变更前入队） |

与 CAAnimation 配合：用 `animation.setValue(token, forKey: "transitionToken")` KVC 模式在 delegate 中读回比较。与 NSAnimationContext 配合：completion handler 已知不稳定（社区报告），不将 commit 逻辑完全依赖它。

## 4. 边界处理

**PageCount tracking 时减少**：clamp committedPage → min(committedPage, M-1)；floatPage = visualOffset/pageWidth 超界则 clamp；不中断手势。**settling 时减少**：targetPage ≥ M → cancel + clamp + 重置到 clamped page × pageWidth（可新启短 settle）；targetPage < M → 更新约束继续动画。**Resize**：tracking：ratio 保持；settling：重算 target（round + clamp）新 token 重启动画；idle：更新 pageWidth 一次布局。布局风暴防护：标记 dirty 下一帧统一处理，不每帧重算。**Teardown 时序**：willClose → isTearingDown=true → CVDisplayLinkStop（同步，之后无新回调）→ removeAllAnimations → removeObserver → timer invalidate → activeTransition=nil → 定最终状态；telemetry 验证 teardown 后 100ms callback count == 0。

## 5. Reduce Motion

检测：`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` + `accessibilityDisplayOptionsDidChangeNotification`。降级：settle duration 0–50ms 或即刻 commit、无/即刻回弹 overscroll、momentum 缩短；**状态机逻辑不变**（5 状态、转换、token 机制完全一致），只改动画参数；动态切换（开启/关闭时正在 settling）不破坏状态。测试：RM 下翻页/快速甩动/settle 中断/动态切换。

## 6. 参数建议（18 个，来源类别已标注；数值为初始建议，TUNING_REQUIRED 待实验）

| 参数 | 建议默认值 | 合法范围 | 来源类别 |
|---|---|---|---|
| inputSensitivity | 1.0（1:1） | 0.5–2.0 | PRODUCT_DECISION |
| boundaryResistance | 0.35 | 0.1–0.6 | PRODUCT_DECISION |
| displacementThreshold | 0.5（半页） | 0.25–0.75 | PRODUCT_DECISION |
| velocityContribution | 0.3 | 0.0–0.5 | PRODUCT_DECISION |
| velocityThreshold | 800 px/s | 200–2000 | INDEPENDENT_EXPERIMENT |
| maximumOverscroll | 0.25（1/4 页） | 0.0–0.5 | PRODUCT_DECISION |
| settleDuration | 250ms | 150–400ms | PRODUCT_DECISION |
| settleSpringDamping | 0.85 | 0.7–0.95 | PRODUCT_DECISION |
| settleDurationReduceMotion | 0ms | 0–50ms | ACCESSIBILITY_REQUIREMENT |
| livePageRadius | 1（±1 页） | 0–2 | PRODUCT_DECISION |
| prewarmDistance | 1.5 页 | 0.5–3.0 | PRODUCT_DECISION |
| reduceMotionOverscroll | 0.0 | 0.0–0.1 | ACCESSIBILITY_REQUIREMENT |
| momentumDecay | 0.95 | 0.8–0.99 | INDEPENDENT_EXPERIMENT |
| frameMissTarget60Hz | 1% | 0–5% | PRODUCT_DECISION |
| frameMissTarget120Hz | 2% | 0–5% | PRODUCT_DECISION |
| hitchThreshold60Hz | 50ms | — | PRODUCT_DECISION |
| hitchThreshold120Hz | 33ms | — | PRODUCT_DECISION |
| respectSystemReduceMotion | true | — | ACCESSIBILITY_REQUIREMENT |
| reduceMotionChangeHandling | dynamic | — | PLATFORM_REQUIREMENT |
| naturalScrollDirection | system | — | PLATFORM_REQUIREMENT |
| gesturePhaseHandling | full | — | PLATFORM_REQUIREMENT |
| displayLinkStopOnTeardown | true | — | PLATFORM_REQUIREMENT |
| animationRemovalOnInterrupt | true | — | PLATFORM_REQUIREMENT |

## 7. 验收标准自查清单

| 验收项 | 状态 |
|---|---|
| 状态模型语义覆盖 5 状态及转换条件 | ✅ |
| 中断不变量覆盖 §3.F 全部 6 条硬门禁 | ✅ |
| Stale completion rejection 有明确设计建议 | ✅ |
| Page count/resize/teardown 边界覆盖 §7.1 测试场景 | ✅ |
| Reduce Motion 对中断机制的影响有分析 | ✅ |
| 不引用旧项目字段名、类结构或精确参数簇 | ✅ |
| 所有参数建议有来源类别标记 | ✅ |

## 8. 补充建议（供 Main 决策）

- **动画驱动**：display link 手动插值 ✅（中断最简单、token 检查位置自然、不依赖 completion handler 时序；teardown 须正确停止）；CAAnimation+delegate 中；NSAnimationContext ❌（completion 不稳定、无法精确取中间值）。
- **Telemetry 补充字段**：transitionToken、staleCallbackFired、interruptSourceOffset、teardownCallbackCount（teardown 后 100ms）、reduceMotionEnabled。
- **ADR-001 决策点清单**（10 项）：状态定义/转换、visualOffset 单一所有权、commit 时机、token 机制、中断取位方式、动画驱动选择、resize rebase、pageCount 策略、teardown 时序、Reduce Motion 降级。

---

*报告结束。分析完全基于 Prompt 需求与 Apple 公开 API 文档独立推导。*
