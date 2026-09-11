# T-1G-A Review Report (r1)

- **Reviewer**: 独立质量评审（只读，未编辑任何实现/测试/文档文件）
- **日期**: 2026-09-05
- **任务**: T-1G-A — ADR-011/012 草稿 + 纯 presentation/activation 状态机 + 测试（chef-worker-reviewer-workflow v1.4.1）
- **评审对象**: 13 个新文件（6 source + 4 test + ADR-011 + ADR-012 + PRIVACY_DATA_MAP.md §9 追加段）
- **Verdict**: **PASS**（0 BLOCKER / 0 MAJOR）

---

## 1. 评审方法

1. 从原始任务包 `Workflow/tasks/T-1G-A.md` 出发逐项核对验收标准（不依赖 Worker 摘要）；
2. 通读全部 6 个新源文件、4 个新测试文件、2 个 ADR 草稿、PRIVACY_DATA_MAP.md §9；
3. 独立运行测试（命令/exit code/executed/passed/failed 见 §4）；
4. 静态红线扫描（§9.10 清单）+ 写集合规 mtime 核验（无 git 历史，全部 untracked，以文件时间戳 + 内容比对为准）；
5. 对照权威需求 `Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md` §3.7/3.8/3.9/3.10/3.11/4.3/5.1/5.2/9.1/9.6/9.7/9.8/9.10 与 `Workflow/PLAN.md` L510-732。

---

## 2. 逐验收标准结果

| # | 验收标准 | 结果 | 证据 |
|---|---|---|---|
| 1 | ADR-011 草稿回答 §5.1 全部 12 问 | **PASS** | `Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md` §Q1–Q12 与 §5.1 12 问一一对应；状态 Chief DRAFT；Q3（窗口形态）与 Q9（status/shortcut/Dock target screen）明确标注待 T-1G-B/C/D spike 证据 + `WINDOW_ARCHITECTURE_DECISION_REQUIRED`，未越权定案 |
| 2 | ADR-012 草稿回答 §5.2 全部 12 问 | **PASS** | `Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md` §Q1–Q12 与 §5.2 12 问一一对应；状态 Chief DRAFT；Q3 poll scheduler 与 Q2 快捷键 API 定案标注待 T-1G-D 实现证据 |
| 3 | 纯 Foundation 逻辑，无 AppKit 行为代码 | **PASS** | 6 个源文件均仅 `import Foundation`（LauncherPresentationState.swift:11、LauncherPresentationCoordinator.swift:17、HotCornerStateMachine.swift:14、ScreenGeometrySnapshot.swift:12、ShortcutRegistrationOutcome.swift:11、ActivationSettings.swift:14）；红线扫描无 AppKit 使用（仅注释提及"UI 层"职责） |
| 4 | 状态机语义（show/hide 幂等、toggle 原子、quit dominates、stale rejection、teardown once） | **PASS** | 见 §3 逐项（代码位置 + 测试名） |
| 5 | Hot Corner 只发 `.show`，永不反向 hide | **PASS** | `HotCornerStateMachine.swift:67-69` `HotCornerEvent` 仅 `showRequested(corner:screenID:)` 一个 case；`sample()` 唯一事件输出为 `[.showRequested]`；测试 `testHotCornerRepeatedShowNeverHides` |
| 6 | 测试执行 > 0 且 0 失败 | **PASS** | 65 executed / 65 passed / 0 failed / exit 0（§4） |
| 7 | 不污染真实 UserDefaults | **PASS** | 新文件零 `UserDefaults` 使用（grep 仅注释提及 T-G-P3 职责）；`ActivationSettings` 为纯 Codable 值模型，测试全部走内存 JSON（`testModelIsPureAndTransportAgnostic`）；"独立 suite" 持久化机制按 PLAN §7 归 T-G-P3，属已披露偏差 |
| 8 | 写集合规（未触碰冻结树 / AppDelegate / AppMain / AppArguments / KeyboardFocusController / Package.swift / AppLaunchController.swift） | **PASS** | mtime 核验：13 个新文件均在 9月5 18:27–18:30（T-1G-A 窗口）；冻结树全部早于 9月5（Package.swift 8月28、AppLaunchController.swift 8月28、PagingCore 8月28–30、PagingTelemetry 8月28–29、PagingUI 8月28–30、AppCatalogCore/MacAppCatalog/AppIconPipeline 8月28、LayoutDomain 8月30–9月1、LayoutStore 8月31、DragSession 8月31–9月2）；AppDelegate.swift 9月5 14:09、AppMain.swift 8月29、AppArguments.swift 8月30、KeyboardFocusController.swift 8月30 均早于 T-1G-A 窗口，未触碰 |
| 9 | 隐私红线（无 addGlobalMonitorForEvents / CGEvent.tapCreate / AXIsProcessTrusted / IOHID / private API / pointer 坐标记录 / frontmostApplication） | **PASS** | 静态扫描 6 源文件 + 4 测试文件：零命中（grep exit=1）；`HotCornerStateMachine.swift:71` 注释提及 `NSEvent.mouseLocation` 仅描述生产 adapter 职责（§3.7 允许的公开 API），非使用 |
| 10 | 无 commit/push/tag | **PASS** | 项目无 git 历史、全部 untracked；评审期间未执行任何 git 操作 |
| 11 | PRIVACY_DATA_MAP.md 更新（§4.3 要求） | **PASS** | `Docs/PRIVACY_DATA_MAP.md:173-184` §9 追加段：禁记清单、允许中性清单、坐标单次内存判定、ScreenID 中性化、ShortcutSpec 中性表示、无全局监听/权限、配置持久化边界、测试强制映射 |

---

## 3. 状态机语义逐项核对（代码 + 测试）

| 语义 | 实现位置 | 测试 |
|---|---|---|
| show 在 visible/presenting 幂等 | `LauncherPresentationCoordinator.swift:55-56`（→ `.none`） | `testVisibleShowIsIdempotent`、`testPresentingRepeatedShowIsIdempotent` |
| hide 在 hidden/dismissing 幂等 | `LauncherPresentationCoordinator.swift:67-68`（→ `.none`） | `testHiddenHideIsIdempotent`、`testDismissingHideIsIdempotent` |
| toggle 原子（committed state 单步决策，唯一写者） | `LauncherPresentationCoordinator.swift:80-93` | `testVisibleToggleHides`、`testHiddenToggleShows` |
| presenting+hide / dismissing+show 中断反向 | `LauncherPresentationCoordinator.swift:57-58, 69-70, 88-89` | `testPresentingHideInterrupts`、`testDismissingShowInterrupts` |
| stale completion 拒绝 | `LauncherPresentationCoordinator.swift:133-134`（`guard requestID == activeRequestID`） | `testStaleCompletionRejected`、`testCompleteTransitionWithoutTransitionIsNoop` |
| 同刻多入口 → 单 present effect | `beginPresent` 单次生成（L174-183） | `testTwoSourcesSameTimestampSinglePresent` |
| quit dominates 后续请求 | `LauncherPresentationCoordinator.swift:96-101`（任何状态 → `.terminating`，后续命令拒绝） | `testQuitDominatesLaterRequests`、`testQuitFromEveryState`、`testTerminatingRejectsEverything` |
| terminate teardown once | `LauncherPresentationCoordinator.swift:104-110`（`teardownCount` 0→1 guard） | `testTerminateTeardownOnce`、`testQuitThenTerminateTeardownOnce` |
| suspend 取消 in-flight transition（completion 变 stale） | `LauncherPresentationCoordinator.swift:152-163`（`activeRequestID = 0`） | `testSuspendCancelsInFlightTransition` |
| resume 确定性 → `.hidden`（不自动弹窗） | `LauncherPresentationCoordinator.swift:166-170` | `testResumeReturnsToHidden` |
| Hot Corner §9.6 14 项 | `HotCornerStateMachine.swift:172-233` `sample()`（disabled 零动作 / 区内不触发 / dwell 一次 / 提前离开取消 / hysteresis re-arm / cooldown / 重复采样零重复 / visible 暂停 / 按键拖拽抑制 / sleep/session 挂起 / 唤醒需退出重进 / 几何变化取消 dwell / 乱序样本忽略 / disable 停一切） | 20 个测试（含负样本：`testStaleSampleIgnored`、`testFastCrossingCornerDoesNotTrigger`、`testScreenRemovedDuringDwellCancels`、`testOnlySelectedCornerTriggers`） |
| §9.7 几何 10 项（含任务包第 10 项"屏外点不命中"） | `ScreenGeometrySnapshot.swift`（负坐标 L43-53 测试、内角规则 L106-114、含边界 contains L52-54、原子替换 L143-151 状态机侧） | 11 个测试（含负样本：`testInternalCornerPointNotMatched`、`testPointOutsideAllScreensNoMatch`、`testPointerExactlyOnBoundsInclusive` 边界外一丁点不命中） |
| §9.8 偏好 9 项 | `ActivationSettings.swift`（默认全 Off L28-35、非法值回 Off L48-57、future schema 安全默认 L41-45、resetActivation 只重置 trigger L63-70） | 10 个测试（含负样本：`testInvalidCornerFallsBackOff`、`testInvalidShortcutFallsBackOff`、`testNoCoordinatesOrAppDataInDefaults` 键白名单） |
| shortcut outcome 模型（configured/conflict/unavailable + rollback） | `ShortcutRegistrationOutcome.swift:60-67`（conflict/unavailable 保留旧注册） | `testShortcutRollbackKeepsOldRegistration` |

---

## 4. 测试证据（独立运行）

**命令**:
```
swift test --filter 'LauncherPresentationCoordinatorTests|HotCornerStateMachineTests|ScreenGeometrySnapshotTests|ActivationSettingsTests'
```
（workdir = /Users/mac/Projects/Launch_Copy/PagingPrototype）

- **exit code**: 0
- **executed**: 65（LauncherPresentationCoordinatorTests 24 + HotCornerStateMachineTests 20 + ScreenGeometrySnapshotTests 11 + ActivationSettingsTests 10）
- **passed**: 65
- **failed**: 0（0 unexpected）

**观察输出**（关键行）:
```
Test Suite 'LauncherPresentationCoordinatorTests' passed ... Executed 24 tests, with 0 failures (0 unexpected)
Test Suite 'ScreenGeometrySnapshotTests' passed ... Executed 11 tests, with 0 failures (0 unexpected)
Test Suite 'PagingPrototypePackageTests.xctest' passed ... Executed 65 tests, with 0 failures (0 unexpected)
Test Suite 'Selected tests' passed ... Executed 65 tests, with 0 failures (0 unexpected)
[status: completed, exit code: 0]
```

**构建新鲜度**: 测试输出中的测试名与当前源文件一一对应（如 `testTwoSourcesSameTimestampSinglePresent`、`testStaleSampleIgnored`），证明编译的是当前源码而非旧 `.build` 产物（MEMORY.md 陷阱已规避）。

---

## 5. Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

1. **M1 — `dismissReason(for:)` 中性回退归因不精确**
   `Sources/PagingPrototypeApp/LauncherPresentationCoordinator.swift:197-206`：非 statusItem/globalShortcut 来源（如 `.testHarness`、`.dockReopen`）经 `toggle()`/`handle(.hide)` 时归因为 `.statusItem`。仅影响中性归因 enum（允许记录），不影响状态机语义；Worker 已披露（偏差③）。建议：为 `.testHarness` 等补充显式映射，或在 ADR-011 Q6 中文档化回退语义。

2. **M2 — future schema "不静默覆盖" 保证依赖持久化层，模型本身无法闭环**
   `Sources/PagingPrototypeApp/ActivationSettings.swift:41-45`：decode 未来 schema（version > current）返回安全默认，`schemaVersion` 被重置为 1；若随后 encode 并写回，未来 schema 数据会被覆盖。§3.10 的"unknown future schema 不应被旧代码静默覆盖"需 T-G-P3 持久化层在 decode 前检查原始存储版本并拒绝写入。当前测试仅覆盖 decode 行为（`testFutureSchemaReturnsSafeDefaults`）。属跨任务契约缺口，不阻塞 T-1G-A 验收，建议在 T-G-P3 任务包中显式要求。

3. **M3 — `HotCornerParameters` 未集中 §3.9 全部参数**
   `Sources/PagingPrototypeApp/HotCornerStateMachine.swift:39-55`：仅含 zoneSize/dwellDuration/hysteresisInset/cooldown；§3.9 要求的 poll interval / toggle debounce / presentation transition duration 未纳入（属 UI 层/scheduler 参数）。建议 T-1G-D 回填时按 §3.9 集中全部 7 参数并补 `PARAMETER_RATIONALE.md` 标注（禁 reverse-derived）。

### QUESTION

1. **Q1 — `isActive` 与 `.suspended` 的 timer 契约**
   `Sources/PagingPrototypeApp/HotCornerStateMachine.swift:104-106`：`isActive = state != .disabled`，`.suspended` 仍返回 true；§3.11 要求 sleep/session inactive 时暂停轮询。状态机在 `.suspended` 下 `sample()` 返回 `[]`（安全），但 UI 层需自行特判 `.suspended` 停 timer。建议 T-1G-D 明确 `shouldPoll` 契约。

2. **Q2 — suspend 自 `.visible` 的 effect 契约**
   `Sources/PagingPrototypeApp/LauncherPresentationCoordinator.swift:152-163`：`.visible → .suspended` 仅发 `.suspend` effect，窗口隐藏动作由 UI 层执行（`committedVisibility` 已翻转为 false）。契约已文档化，待 T-1G-B 验证。

3. **Q3 — §9.7 项数差异（任务包 10 项 vs Prompt 9 项）**
   Worker 补第 10 项"point outside all screens no match"（`Tests/PagingUITests/ScreenGeometrySnapshotTests.swift:179-190`）。超集，无缺陷；建议在结果文档中标注差异来源。

---

## 6. verified facts / inference / suggestions

- **verified facts**: 65 测试 0 失败 exit 0；红线扫描零命中；写集合规（mtime 证据）；ADR-011/012 各答 12 问且与 §5.1/§5.2 对应；状态机语义与代码、测试三方一致；PRIVACY_DATA_MAP §9 已追加；Worker 结果中的文件清单、测试计数、偏差披露均与事实相符。
- **inference**: 无（所有结论均有代码/测试/命令输出支撑）。
- **suggestions**: M1–M3 为改进建议（不阻塞验收）；Q1–Q3 为 T-1G-B/C/D 回填时的契约确认点。

---

## 7. Verdict

**PASS**

- 0 BLOCKER / 0 MAJOR（PLAN §10 `INDEPENDENT_REVIEW = PASS` 条件满足）
- 全部 11 项验收标准通过；状态机语义、Hot Corner 只发 `.show`、纯 Foundation、负样本断言、UserDefaults 零污染、写集合规、隐私红线全部核实
- 已披露偏差（ActivationSettings.swift 命名、PRIVACY_DATA_MAP §9、DismissReason 归因、suspend/resume 语义、interrupt 策略）均合理且与 PLAN §7/§9 一致
- 遗留项（ADR-011 Q3/Q9、ADR-012 Q3、B10 物理 A/B）均为 Chief 决策项/后续任务，已在 ADR 中正确标注，不构成 FAIL
