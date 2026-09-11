# ADR-001 — 分页状态模型（Paging State Model）

- **状态**：ACCEPTED（2026-08-28，T-step1，Main 编写并自查通过）
- **决策范围**：Phase 1A PagingCore 状态语义、所有权、中断与 stale completion 机制；受 `Docs/PHASE1_SPEC.md` §2.1.G/F 约束
- **输入**：T-explorer 只读分析（`Workflow/results/T-explorer.md`，Explorer A，glm-5.2）
- **变更需**：Chief 决策（状态模型变更 = PLAN.md Chief-Owned #2）

## 1. 背景与问题

Prompt §3.G 要求先设计明确状态模型再写 UI 细节，并必须回答 7 个问题（语义页/视觉偏移所有权、gesture session 生命周期、settle 识别与取消、旧回调提交资格、resize/pageCount change、teardown 无残留回调）。§3.F 定义 6 条中断硬门禁。本 ADR 固定 PagingCore 的状态机契约。

## 2. 决策

### D1 五状态与所有权

采用五语义状态，**视觉偏移唯一所有权归 Core**：Core 持有 `visualOffset: Double`（以 pageWidth 为单位的连续值），是 UI 渲染唯一数据源；UI 只读，不自算偏移。**语义页归 Core**：`committedPage: Int` 只在 settle 自然完成（commit 到 targetPage）或 cancel/teardown（clamp）时变更；tracking 中不 commit。

| 状态 | 视觉偏移持有者 | 语义页 | 进入/退出 |
|---|---|---|---|
| idle | Core（确定值） | committedPage | 无手势无动画 |
| tracking | GestureSession | committedPage 不变 | began 进入；ended→settling / cancelled→idle |
| settling | TransitionContext（动画插值） | targetPage 未 commit | ended 进入；自然完成→idle / 中断→interrupted |
| interrupted | 新 GestureSession（从旧动画当前位置接管） | 不变 | settling + began 进入；瞬时状态立即转 tracking |
| cancelled | Core（重置到合法确定值） | clamp | 异常/外部干预进入；清理后→idle |

momentum 视为 tracking 子阶段（session 内部标记），不引入新顶层状态。

### D2 动画驱动方式：display link 手动插值（不用 NSAnimationContext 驱动 settle）

- **选定**：CVDisplayLink（或等价帧回调）手动插值驱动 settle；每帧写 Core `visualOffset`；中断 = 设 cancel flag 下帧退出，当前 visualOffset 即接管点；token 检查位于每帧回调与完成路径。
- **否决**：NSAnimationContext 驱动 settle（completion handler 时序不可靠、无法精确取中间值——社区已知问题）；CAAnimation 作为主驱动（presentation layer 读取有延迟、`finished=false` 不表示逻辑取消）。CAAnimation 仅作可选的视觉辅助，commit 逻辑绝不依赖其 completion。
- 理由：中断最简单、token 检查位置自然、不依赖 Apple 动画 completion 时序；teardown 必须正确停 display link（D7）。

### D3 stale completion rejection：单调递增 generation token

- 每次 `beginSettle` 时递增 `UInt64 transitionToken`；TransitionContext 持有 token + `commitState: .pending/.committed/.stale` + `hasCommitted` 保证单次 commit。
- 完成回调携带创建时 token；仅当 `token == activeTransition.token && commitState == .pending && !isTearingDown` 时 commit；否则计数 `staleRejectionCount` 并忽略。
- 中断路径：`activeTransition.commitState = .stale; activeTransition = nil`；token 在新 settle 开始时递增（中断本身不递增）。
- 否决：时间戳比较（精度/回拨）、仅状态枚举检查（竞态）、对象身份作为唯一判据（闭包强引用）。
- 与 CAAnimation 配合时用 KVC `animation.setValue(token, forKey:)` 读回比较（若启用）。

### D4 中断接管路径（§3.F 门禁 1–3）

settling 收到 `.began` 时同步完成：①停旧动画（cancel flag / removeAnimation）②读取当前显示位置（手动插值 = 上帧写入的 visualOffset；CAAnimation = presentation layer）③新 GestureSession 以该位置为 `currentOffset` 起点 ④settling→interrupted→tracking。**禁止**以旧动画 source/target 作为新起点；旧 TransitionContext 作废后其偏移不再被读取。连续性验证：接管差值 < 1px（或 < 1/refreshRate × maxVelocity 容差）。

### D5 防御性事件处理

phase 防御：重复 `.began` 忽略或按中断处理；`.ended`/`.cancelled` 后 `.changed` 忽略直到新 `.began`；momentum 与 phase 并存时 phase 优先；无 phase 事件（旧鼠标滚轮）走 fallback 路径且不用于物理验收门。

### D6 resize 与 pageCount change 策略

- **resize/pageWidth**：tracking → 比例保持 rebase（`ratio = offset/oldWidth`，`offset = ratio × newWidth`），手势继续；settling → 重算 target（round + clamp）用**新 token** 重启动画；idle → 更新 pageWidth + 一次布局。**防布局风暴**：resize 通知 coalesce（runloop 空闲或下一帧统一处理），不每帧重算。
- **pageCount 减少**：tracking → clamp committedPage 与 visualOffset，不中断手势；settling → target ≥ newCount 则 cancel（token 作废）+ clamp + 重置（可新启短 settle 到 clamped 页），target 合法则继续动画；idle → 仅 clamp。

### D7 teardown 时序（无残留回调）

`NSWindow.willCloseNotification`（或 windowWillClose）中按序：①`isTearingDown = true`（第一时间）②停 display link（同步，之后无新帧）③移除全部动画 ④移除全部 observer/timer ⑤清 activeTransition ⑥定最终状态。所有回调（completion/display link/timer）首查 `isTearingDown` 立即返回。telemetry 验证：teardown 后 100ms 内 callback count == 0。

### D8 Reduce Motion：参数变、逻辑不变

检测 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` + 监听 `accessibilityDisplayOptionsDidChangeNotification`（运行时可切换）。降级：settleDuration → 0–50ms 或即刻 commit、overscroll → 0、momentum 缩短。**状态机、转换条件、token 机制完全一致**；仅动画参数不同。动态切换不破坏中断/旧回调机制。单独测试。

### D9 目标页策略（与状态机接口）

释放后由 `PageTargetPolicy` 计算 targetPage：输入 = 位移比例（visualOffset - committedPage×pageWidth 归一化）、近期速度（含 momentum）、边界位置、Reduce Motion；输出 = 回弹/前进/后退。策略阈值全部来自集中参数（见 PARAMETER_RATIONALE.md），禁止 magic number。commit 时机：settle 自然完成（D3 token 校验通过）。

### D10 Core 纯逻辑边界

PagingCore 不依赖 AppKit/Core Animation/窗口/真实事件：输入为规范化的手势事件（phase/delta/timestamp），输出为状态 + visualOffset + commit/stale 事件；UI 层负责 NSEvent 转换与渲染。Core 可被可重复事件序列测试直接驱动（§7.2）。

## 3. 验收映射（本 ADR 自查）

| §3.F 门禁 | 机制 | 验证（§7.1/7.2） |
|---|---|---|
| 1 立即接管 | D4 同步接管 | 中断测试 |
| 2 位置连续 | D4 当前显示位置起点 | 中断 + interruptSourceOffset telemetry |
| 3 不跳回旧点 | D4 旧 context 作废 | 连续反向中断测试 |
| 4 旧 completion 不覆盖 | D3 token 三防线 | 旧 completion 晚到测试 |
| 5 无双重 commit | D3 commitState 单次 | commit 次数断言 |
| 6 close/resize/pageCount | D6/D7 | settling→resize / settling→pageCount / tracking→close 序列 |
| §3.G 7 问 | D1–D10 全部回答 | — |

## 4. 被否决方案记录

- NSAnimationContext 驱动 settle（completion 不可靠、中间值不可取）
- CAAnimation 作为 commit 唯一来源（presentation 延迟、finished 语义不可靠）
- 时间戳/纯状态检查/对象身份作为 stale 判据
- momentum 作为独立顶层状态（子阶段更简单）
- UI 拥有视觉偏移（双写竞争）

## 5. 设计者接触声明

- 设计者（Main，T-step1）：未读取 BuhoRebuild / LaunchBetter 源码；阅读过 Launch_Copy 治理文档（审计摘要，非实现细节）。分析输入来自 Explorer A（fresh、只读、glm-5.2），其报告声明未读取禁止来源与治理文档。本 ADR 决策基于 Prompt §3.F/G 需求、公开 AppKit/CoreVideo 平台知识与本项目实验目标独立推导；命名采用 §11.2 中性词汇。

## 6. 变更记录

| 日期 | 变更 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建并 ACCEPTED（基于 T-explorer 分析） | Main |
