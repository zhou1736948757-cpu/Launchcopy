# ADR-012 — SYSTEM-WIDE ACTIVATION PRIVACY

- **状态**：**ACCEPTED（Q2/Q3 由 T-1G-D 锁定；其余问保持 T-1G-A 草稿语义，待 Main 全量转正）**
- **阶段**：Phase 1G（PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.6-3.11、§4、§5.2；权威依据）
- **关联**：ADR-011（presentation 生命周期）；ADR-013（四指后端，G-P0 决策后）；PARAMETER_RATIONALE；PRIVACY_DATA_MAP
- **回答**：Prompt §5.2 全部 12 问（§Q1–Q12 一一对应）
- **范围**：系统级激活入口（status item/Dock reopen/global shortcut/Hot Corner）的默认启用集、公开 API 选择、权限与隐私边界、dwell/hysteresis/cooldown/re-arm 语义、多屏/sleep/lock 处理、配置持久化与隔离、能耗门与降级、冲突恢复、无 trigger 访问、延期项
- **T-1G-D 锁定日期**：2026-09-10

## 背景

Phase 1G 引入系统级激活入口。本 ADR 定**默认低权限、公开 API、隐私红线**：默认全部系统级 trigger Off；不用 global NSEvent monitor / CGEvent tap / Accessibility / Input Monitoring / Screen Recording（四指获批窄例外除外，ADR-013）；不记录/持久化指针坐标、屏幕身份、前台 app、按键流、真实快捷键文本（PLAN §9 不变量 6-7、§11）。纯逻辑部分已由 T-1G-A 实现并测试（§9.6 14 项、§9.7 10 项、§9.8 9 项）。

## Q1. status item、Dock reopen、shortcut、Hot Corner 哪些默认启用？

**决策**：

| 入口 | 默认 | 理由 |
|---|---|---|
| status item | **显示**（应用内入口，非系统级 trigger） | 无 trigger 时应用仍可达（Q11）；菜单 Show/Hide/Activation Settings/Quit |
| Dock reopen | **始终可用**（系统行为） | `applicationShouldHandleReopen`；hidden→show，visible→key，不建第二窗 |
| global shortcut | **Off** | 系统级 trigger 默认 Off；用户显式启用后才注册（§3.6） |
| Hot Corner | **Off** | 用户显式选择 corner 后才启动检测（§3.7） |
| fourFingerActivationEnabled | **true（用户决策 2026-09-05 默认开启）** | 用户决策覆盖原锁定 false（`Workflow/decisions/2026-09-05-four-finger-user-decisions.md` 决策 2）；实现+验证+物理门通过后才生效；ADR-013 §7 |

- 默认值由 `ActivationSettings` 纯模型锁定（§9.8 项 1 测试）；非法值 decode 回安全 Off（§9.8 项 3）。
- 不偷偷注册任何系统级组合；Hot Corner disabled = 零 timer 零轮询（§9.6 项 1/14）。

## Q2. 全局快捷键用什么公开 API，为什么不监听一般键盘事件？

**决策（ACCEPTED — T-1G-D）**：候选比较（§3.6）：

| 候选 | 结论 |
|---|---|
| (1) 公开 `RegisterEventHotKey`/`UnregisterEventHotKey`（Carbon/HIToolbox） | **ACCEPTED 选定路线**（T-1G-D：`CarbonGlobalShortcutRegistrar`；`import Carbon` 在当前 SDK **无需** Package.swift `linkerSettings`——探针构建已通过） |
| (2) `NSMenuItem.keyEquivalent` | 仅应用 active 时生效，不能冒充全局快捷键（不采用） |
| (3) 第三方快捷键依赖 | 默认不新增第三方依赖（不采用） |
| (4) `NSEvent` global monitor / event tap | **禁止**（PLAN §9 不变量 6） |

**选定理由**：
1. 公开 API，只投递**已注册** hot-key 事件（`kEventHotKeyPressed`），不订阅一般 `keyDown` 流 → 满足隐私红线与最小权限。
2. 无需 Accessibility / Input Monitoring / Screen Recording。
3. 当前工具链下 `import Carbon` 即可链接 HIToolbox 符号，Worker 未改 Package.swift。

**实现契约**（`GlobalShortcutRegistrar.swift`）：
- 窄 `GlobalShortcutRegistering` protocol + `FakeGlobalShortcutRegistrar`（测试）+ `CarbonGlobalShortcutRegistrar`（生产）。
- 默认 Off：未 `register` = 零系统注册。
- 默认非 exclusive；冲突（`eventHotKeyExistsErr`）/失败 → 中性 `configured`/`conflict`/`unavailable`；其他入口继续工作。
- `reconfigure`：先以 pending hot-key ID 试注册新组合；失败保留旧注册（`ShortcutRegistration.applying` rollback）；成功再卸旧。
- 禁止无修饰键（`ShortcutSpecValidator` → `.unavailable`）；`fireDebounce`（默认 0.25s）抑制 key repeat 抖动。
- `teardown`/`unregister` 解除 `EventHotKey` + `RemoveEventHandler`。
- 测试只用 Fake，不抢真实系统快捷键；不记录真实快捷键文本/其他按键。

## Q3. Hot Corner 用什么公开 API、poll scheduler 与纯状态机？

**决策（ACCEPTED — T-1G-D）**：

- **公开 API**：`NSEvent.mouseLocation` 低频可暂停轮询 + `NSScreen.screens`/screen frame 纯几何判定（生产 adapter 才接触 AppKit；纯逻辑在 `ScreenGeometrySnapshot` + `HotCornerStateMachine`，T-1G-A 已实现）。`ScreenGeometrySnapshotBuilder.fromNSScreens` 只映射 index/frame/scale，不读 UUID/名称。

### Poll scheduler 比较与定案

| 候选 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| (A) 主线程 `Timer`（`.common` mode，tolerance≈25% interval） | 与 AppKit 生命周期同线程；可暂停（invalidate）；实现简单；不绑 display link | 依赖 RunLoop；后台/sleep 需显式停 | **ACCEPTED** |
| (B) `DispatchSourceTimer` | 可挂后台队列 | 回调需跳回主线程采 `NSEvent.mouseLocation`/喂状态机；多一层同步；测试面更宽 | 不采用（同功能更高复杂度） |
| (C) 专用低功耗 scheduler / frame pump | 理论上更省 | 易与 60Hz `PagingSurface` 帧泵耦合（§4.2 明确禁止）；过度设计 | **禁止**绑定帧泵 |

**定案（ENGINEERING_JUDGMENT / PRODUCT_DECISION）**：
- **选用 (A) 主线程 `Timer`**，默认 `pollInterval = 0.075s`（75ms，落在 50–100ms 候选带；见 `PARAMETER_RATIONALE`）。
- **disabled = 零 timer / 零轮询**（不 `start`；`FakeHotCornerScheduler` 测试锁定）。
- **暂停条件**：`suspend(sleep/sessionInactive)` → `scheduler.stop()`；launcher visible 时状态机内抑制触发（可继续低频 poll 或由接线层选择停——本实现保留 poll 但状态机不发 show，避免可见时丢 re-arm 观测；能耗门 T-1G-F 可再收紧为 visible 时停 timer）。
- **唤醒/恢复**：`WorkspaceSessionObserver` → `resume()` 重建 geometry + `requiresExitBeforeDwell`（状态机已编码）。

- **纯状态机**：`.disabled/.armed/.insideCandidate(corner, enteredAt)/.triggeredAwaitingExit(corner)/.suspended(reason)` + 可注入 fake clock（§9.6 14 项测试）。
- **适配器**：`HotCornerMonitor`（注入 pointer/geometry/scheduler/clock）+ `WorkspaceSessionObserver`（sleep/session/screens）。
- 参数与显示刷新率无关（dwell/cooldown 不用 frame count；§3.9）；一次 poll 只做有界判定（§4.1）；触发只回调 `.show`（永不 hide）。

## Q4. 为什么不使用 global NSEvent monitor、CGEvent tap 或 Accessibility？

**决策**：**全部禁止**（PLAN §9 不变量 6）：`NSEvent.addGlobalMonitorForEvents`、`CGEvent` tap、`AXObserver`/Accessibility API、`IOHID` 私有/底层输入抓取。

- 理由：隐私红线（不读前台 app/按键流/指针轨迹）；权限最小化（无 Accessibility/Input Monitoring/Screen Recording）；发布可行性。
- 四指获批窄例外除外（ADR-013，用户确认风险清单后才运行采集实验）。
- 静态红线扫描（§9.10）：新增/修改源码不得出现 `addGlobalMonitorForEvents`、`CGEvent.tapCreate`、`AXIsProcessTrusted`、`IOHID`、private API selector strings、`LaunchBetter`、`Buho`、license crack/bypass、pointer coordinate logging、`frontmostApplication` query。

## Q5. dwell/hysteresis/cooldown/re-arm 语义是什么？

**决策**（T-1G-A 已实现，§9.6 测试锁定）：

- **dwell**：从 zone 外进入才开始计时；应用启动时指针已在角落**不立即触发**（§9.6 项 2）；dwell 满足后**只触发一次 `.show`**（§9.6 项 3）；dwell 未满离开 → 取消（§9.6 项 4）。
- **hysteresis re-arm**：触发后必须离开带 hysteresis 余量的 re-arm 区才能再次触发（§9.6 项 5）。
- **cooldown**：触发后冷却期内快速重触发被抑制（§9.6 项 6）。
- **re-arm**：离开 re-arm 区 → armed；重复采样零重复事件（§9.6 项 7）。
- 参数分离：poll interval / corner zone size / dwell duration / hysteresis inset / cooldown / toggle debounce / presentation transition duration（PARAMETER_RATIONALE 标注来源类别，禁 reverse-derived）。
- **Hot Corner 只发 `.show`，永不反向 hide**（§9.1 项 10）。

## Q6. 多屏幕、屏幕变化、sleep/lock/session inactive 如何处理？

**决策**（T-1G-A 已实现，§9.6/§9.7 测试锁定）：

- **多屏**：`ScreenGeometrySnapshot` 支持负坐标、上下/左右排列、不同 scale/分辨率；内角规则（共享边/拼接处不可达角非有效热角）；Hot Corner show 的 target screen = 实际触发屏（§9.7 项 8）。
- **屏幕变化**：原子替换 geometry + 取消旧 dwell（§9.6 项 12、§9.7 项 7/8）；不持久化 display UUID/名称/几何（§9.7 项 9）。
- **willSleep** → suspend polling + 取消 dwell；**didWake** → 重建 geometry + 要求指针重新离开/进入后才 re-arm（§9.6 项 10/11）。
- **session resign / screen locked** → suspend；**become active / unlock** → 延迟到稳定状态后重新 arm，不立即触发。
- 测试不用真实 sleep/lock，使用 fake event source（T-1G-D）。

## Q7. 配置如何持久化、迁移、reset 和测试隔离？

**决策**（§3.10；T-1G-A 纯模型 + T-G-P3 持久化）：

- **只持久化**：`hotCornerEnabled`/`selectedCorner`、`globalShortcutEnabled`/shortcut representation、`showStatusItem`、`schemaVersion`（§9.8 项 9 测试锁定白名单）。
- **专用带 schema/namespace 的 UserDefaults**（T-G-P3 `ActivationPreferences`），与 Phase 1F layout store 分离。
- **decode 非法值 → 安全 Off 不崩溃**（§9.8 项 3）；**unknown future schema 不被旧代码静默覆盖**（§9.8 项 4）。
- **reset activation 与 reset layout 是两个动作**（§9.8 项 6）。
- **测试隔离**：注入独立 suite name，绝不污染真实 defaults（§9.8 项 5；T-1G-A 纯模型测试零 UserDefaults 接触）。
- 配置改变后 service start/stop 原子、幂等、可回滚（换 corner 先停旧服务，§9.8 项 7）。

## Q8. 哪些数据短暂接触、哪些严禁日志/持久化？

**决策**（§4.3；PRIVACY_DATA_MAP 追加 Phase 1G 段）：

- **短暂接触（仅内存、单次判定）**：当前 pointer point、screen frame、corner 命中结果。
- **严禁记录/持久化**：raw pointer 坐标/轨迹、screen UUID/name/serial、frontmost app、按键流、真实快捷键文本（默认日志）、app 名称/bundle ID/path/URL、folder title/UUID/member list、搜索词、窗口标题。
- **允许中性**：activation source enum、show/hide/toggle/quit outcome enum、corner enum、dwell/cooldown state enum、screen count、registration outcome enum、transition duration aggregate、counter（如 `triggerCount`）。
- 所有坐标只存在于一次内存判定；日志只记录中性 enum/计数；默认 telemetry 不增加事件。

## Q9. 能耗门与失败降级是什么？

**决策**（§4.2；T-1G-F 执行）：

- **disabled/enabled A/B**：同 Release 构建、同屏幕环境；隐藏空闲每条件 ≥3 轮 60s 采样；**先写阈值再运行**；记录 CPU/wakeups/timer firings/内存趋势/触发延迟；不得只凭 Activity Monitor 截图写 PASS。
- disabled 证明**零 timer 零 callback**；轮询不得与 PagingSurface 60Hz frame pump 绑定；launcher visible 时暂停 polling；sleep/session inactive 时暂停。
- **失败 → `HOT_CORNER_ENERGY_GATE_FAILED`**：保留菜单/快捷键，Hot Corner 标 Failed/Deferred（Chief 决策项 11）。

## Q10. shortcut 冲突和注册失败如何恢复？

**决策**（§3.6；T-1G-D 实现）：

- 注册失败（conflict/unavailable）→ 中性状态展示，**其他入口继续工作**（不因 shortcut 失败阻塞 status item/Dock/Hot Corner）。
- reconfigure 先安全注册新组合或明确 rollback（旧注册保留，不悄悄丢掉；§9.8 项 8 测试锁定）。
- 用户可关闭或改组合；不读取系统快捷键私有偏好；与系统已有 Hot Corner 冲突时只提示用户自行选择，不篡改系统设置。

## Q11. 用户未配置任何系统级 trigger 时应用如何访问和退出？

**决策**：

- 无系统级 trigger 时：**status item（默认显示）+ Dock reopen 仍可用**；菜单 Quit / Cmd-Q 退出；应用不因无 trigger 而不可达。
- Hot Corner disabled = 零 timer 零轮询（§9.6 项 1）；shortcut Off = 零注册。
- 退出路径：status menu Quit / Cmd-Q / 系统 terminate → `quit()` → `terminate()`（teardown 一次，ADR-011 Q5）。

## Q12. 哪些行为延期到下一阶段？

**决策**（延期项，不阻塞本阶段验收）：

- 正式设置窗口（Phase 1H `RECOMMEND_PROCEED_TO_PHASE_1H_PRODUCT_SETTINGS_AND_PACKAGING_READINESS`）。
- 多 Hot Corner 同时启用（本阶段单 corner）；Hot Corner 自定义 zone 尺寸 UI；快捷键自定义 UI（本阶段固定组合或最小选择）。
- 四指激活（G-P0 决策门后，ADR-013）。
- 能耗门实机 A/B（T-1G-F）；120Hz/多显示器物理门（`BLOCKED_BY_HARDWARE` 挂账）。
- Launch at Login、发布/签名/公证（Phase 1H+，不自动授权）。

## 实现注记（T-1G-A）

- 纯逻辑交付：`HotCornerStateMachine.swift`（§9.6 14 项）、`ScreenGeometrySnapshot.swift`（§9.7 10 项）、`ShortcutRegistrationOutcome.swift`（outcome + rollback）、`ActivationSettings.swift`（§9.8 9 项）；测试 `Tests/PagingUITests/` 四套件。
- 待 T-1G-D 回填：scheduler 比较证据（Q3）、`GlobalShortcutRegistrar`/`HotCornerMonitor`/`ActivationPreferences` 实现；待 T-1G-F：能耗门 A/B。

## 实现注记（T-1G-D）

- **Q2/Q3 ACCEPTED**（见上）。
- 交付：`GlobalShortcutRegistrar.swift`（protocol + Fake + Carbon）、`HotCornerMonitor.swift`（Timer scheduler + 注入缝）、`WorkspaceSessionObserver.swift`（sleep/session/screens）。
- `ActivationPreferences` 已由 T-G-P3 交付；本任务不重复实现持久化。
- **T-1G-E 接线责任**：prefs → `enable`/`disable`/`register`/`unregister`；`onFired` → coordinator `toggle`（source `.globalShortcut`）；`onShowRequested` → coordinator `show`（source `.hotCorner`, targetScreen）；`WorkspaceSessionObserver.onEvent` → `WorkspaceSessionHotCornerBridge.apply`；launcher visible → `setLauncherVisible`；teardown 路径调用 `unregister`/`teardown`。
- 待 T-1G-F：能耗门 A/B（disabled 零 timer 证明 + enabled 空闲成本）。
