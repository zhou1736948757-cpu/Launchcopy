# T-G-P3 Review r1 — 配置与入口状态（四指开关/迁移/展示）

- **Reviewer**: 独立评审（只读实现；未编辑任何实现/测试文件；未 commit/push/tag）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P3.md`
- **Worker result**: `Workflow/results/T-G-P3.md`
- **Review basis**: `AGENTS.md`、`MEMORY.md`、`Workflow/PLAN.md`（§5 写集 / §7 任务表 / §9 不变量 #6/#7 / §10 全局验收 / §11 隐私红线）、`Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`（§3.10 / §9.8 九项 / §21.2 状态模型 / §9.10 红线）、`Workflow/decisions/2026-09-05-four-finger-user-decisions.md`（决策 2：四指默认开启）、`Workflow/reviews/T-1G-A-r1.md`（MINOR-2 跨任务契约）、实际实现 3 源文件 + 3 测试文件、参考 `Sources/PagingPrototypeApp/ActivationSettings.swift`（T-1G-A 纯值模型）、`Sources/PagingPrototypeApp/TouchProvider.swift`（T-G-P2 七态）、`Sources/PagingPrototypeApp/PinchRecognizer.swift`（PinchSuspensionReason）、`Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`（§7 用户决策标注）、`git status`/文件 mtime、实测命令输出
- **Access declaration**: 本 Reviewer **未读取** `LaunchBetter/`、`BuhoReverseNotes/` 源码（遵守评审禁令）；未运行任何采集/设备访问代码；仅执行 `swift test`（两次过滤 + 两次全量）与只读 grep/stat/probe（probe 脚本在 /tmp，未触碰项目文件）
- **Verdict**: **PASS**（0 BLOCKER / 0 MAJOR / 2 MINOR / 2 QUESTION / 5 INFO）

---

## 0. 结论摘要

T-G-P3 交付物满足任务包全部验收标准：专用 namespace 持久化（独立 suite + `activation.` 前缀双保险 + failable init 绝不回退标准 defaults）、MINOR-2 契约闭环（load 先读原始版本→futureSchema 不解码不覆盖；save 前再查版本→refusedFutureSchema；版本 999 载荷原样保留零新值写入）、非法值回 Off 不崩溃、resetActivation 独立动作、持久化 key/载荷字段白名单、服务启停计划（stops→restarts→starts 顺序契约/幂等/回滚/原子）、四指入口七态与 TouchProviderState 1:1 对齐、Enabled≠Ready、§9.8 九项 + §21.2 状态模型测试覆盖、独立 suite 测试隔离。独立重跑 `swift test --filter 'ActivationPreferencesTests|ActivationServicePlanTests|FourFingerActivationStateTests'` → **57 tests / 0 failures / exit 0**（15+18+24，与 worker 声明一致）；全量 `swift test` → **1342 tests / 0 failures / exit 0**（基线 1285 + 本任务 57，与 worker 声明一致）。写集合规（仅 6 个新文件，冻结树/AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift/AppLaunchController.swift/既有文件未触碰）；隐私红线静态扫描零命中（仅注释「无 AppKit」政策文字）；无 AppKit、无墙钟依赖、无 commit/push/tag。7 项偏差全部在代码中核实，其中偏差 2 的披露对 Bool 型损坏版本 key 不精确（MINOR-1，方向安全）。发现 2 MINOR / 2 QUESTION / 5 INFO，均不构成验收阻断。

---

## 1. 逐验收标准结果（任务包「验收」节）

| 验收标准 | 证据 | 结果 |
|---|---|---|
| 测试覆盖 Prompt §9.8（9 项）与 §21.2 状态模型 | 见 §3/§4/§5 逐项（测试名 + 代码位置） | ✅ |
| 测试绝不污染真实用户 defaults | `ActivationPreferencesTests.swift` L22-27（UUID suite `com.pagingprototype.activation.tests.<UUID>`）+ L29-34（tearDown `removePersistentDomain`）；`testIsolatedSuiteDoesNotTouchStandardDefaults`（L175-185）显式断言标准 defaults 零 `activation.` 前缀 key | ✅ |
| 不 commit/push/tag | 仓库零提交（`git log` → `your current branch 'main' does not have any commits yet`）；git status 全部 untracked 无 staged；Reviewer 未执行任何 git 写操作 | ✅ |

## 2. Objective 逐项验证

| Objective 要求 | 实现位置（已逐行核对） | 结果 |
|---|---|---|
| 专用 namespace UserDefaults（与 Phase 1F layout store 分离） | `UserDefaultsActivationPreferencesStore`（ActivationPreferences.swift L81-99）：默认 suite `com.pagingprototype.activation`（L83）+ key 前缀 `activation.`（L85-89）双保险；failable init `init?`（L95-99）suite 创建失败返回 nil，**绝不回退标准 defaults** | ✅ |
| schema version 字段；decode 前检查原始版本——unknown future schema 不被旧代码静默覆盖（MINOR-2） | `load()` L103-132：L105 先读原始 `activation.schemaVersion`；L109-112 `storedVersion > current` → `.futureSchema(storedVersion:)`，**不解码不覆盖**；`save()` L136-151：L138-141 写入前再查版本 → `.refusedFutureSchema`；L144-147 数据先写、L149 版本最后写（提交标记） | ✅ |
| 非法值回 Off 不崩溃（布尔/枚举非法值 → 安全默认） | 非 Bool → Off（L116-120）；损坏 JSON 载荷 → 安全默认（L124-127）；非法角枚举由 ActivationSettings 安全解码（ActivationSettings.swift L48-52：非法 corner → `hotCornerEnabled=false`） | ✅ |
| reset activation settings 独立动作（只清 activation namespace，不动 layout store） | `resetActivation()` L155-160 只 remove 3 个 activation key；`testResetActivationClearsOnlyActivationKeys`（suite 内外来 key 保留）、`testResetActivationDoesNotTouchLayoutStore`（独立 layout suite 不受影响）、`testLoadAfterResetReturnsProductDefaults` | ✅ |
| 持久化只写用户开关及获批配置，不写触点/设备序列号/原始坐标/后台应用身份 | `testNoCoordinatesOrAppDataInDefaults`（L241-266）：持久域 key ⊆ 3 个白名单 key；载荷顶层字段 ⊆ 6 个中性字段（schemaVersion/hotCornerEnabled/selectedCorner/globalShortcutEnabled/shortcut/showStatusItem） | ✅ |
| 配置改变后 service start/stop 原子、幂等、可回滚 | `ActivationServicePlanDiff`（ActivationServicePlan.swift L79-125）：同计划零转换（L88-115 全条件不成立）；顺序契约 stops→restarts→starts（L87-115 三块顺序构造）；rollback = 反向 diff（L122-125）；diff 整体计算 + apply 确定性（L60-75） | ✅ |
| 四指入口状态模型 Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended（与 TouchProviderState 对齐） | `FourFingerActivationState` 七态（FourFingerActivationState.swift L16-23）+ `init(providerState:)` 1:1 映射（L26-36）；与 `TouchProviderState`（TouchProvider.swift L22-30）逐 case 同构，`suspended(reason: PinchSuspensionReason)` 关联值类型一致 | ✅ |
| **Enabled≠Ready**（用户打开开关但后端失败时显示事实） | `FourFingerActivationStatus.isReady = enabled && state == .ready`（L167-169）；`displayKind` 开关开按后端事实展示（L172-189）；`testEnabledNotReadySemantics`/`testDisplayKindShowsFactsWhenEnabled`/`testDisplayKindDisabledWhenSwitchOff`/`testEnabledAndReadyAreIndependentDimensions` | ✅ |
| 状态转换纯值模型 + 测试 | `FourFingerActivationStateMachine`（L62-132）：合法表 `nextState`（L79-131），非法返回 nil → `apply` 返回 false 状态不变（L71-75）；24 tests 覆盖启动/解析/降级/恢复/recheck/挂起/恢复/停止/非法拒绝/全生命周期 | ✅ |
| §9.8 Preferences 9 项（按 Prompt 原文逐项） | 见 §3 表 | ✅ |
| §21.2 状态模型（Enabled≠Ready 语义、各状态转换） | 见 §4/§5 | ✅ |
| 独立 UserDefaults suite 测试（suiteName 隔离，测试后清理，绝不污染真实用户 defaults） | UUID suite + tearDown `removePersistentDomain`（ActivationPreferencesTests.swift L24/L30）；`testIsolatedSuiteDoesNotTouchStandardDefaults` 显式断言 | ✅ |
| MINOR-2 契约测试（future schema 版本不被静默覆盖） | `testFutureSchemaLoadPreservesData`（L127-141）/`testFutureSchemaSaveRefused`（L143-159）：版本 999 + 载荷原样保留、拒绝写入、零新值 | ✅ |
| 不 commit/push/tag | 见 §1 | ✅ |
| 隐私红线（PLAN §11 静态扫描） | 见 §7 | ✅ |
| 写集合规（未触碰冻结树/AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift/AppLaunchController.swift/既有文件） | 见 §8 | ✅ |

## 3. §9.8 Preferences 九项逐项验证

| §9.8 项 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| 1 default all system-wide triggers Off | `ActivationPreferences()` 默认（L35-41）：fourFinger=true（用户决策覆盖，偏差 1）、hotCorner/shortcut 全 Off（ActivationSettings() 默认 L28-35） | `testFreshLoadReturnsProductDefaults`（L38-50） | ✅ |
| 2 encode/decode round trip | `save()`/`load()` 对称（L136-151/L103-132） | `testSaveLoadRoundTrip`（L54-73）、`testSaveLoadRoundTripDefaults`（L75-82） | ✅ |
| 3 invalid enum fallback Off | 非 Bool → false（L116-120）；损坏载荷 → 安全默认（L124-127）；非法角 → ActivationSettings 安全解码（ActivationSettings.swift L48-52） | `testInvalidFourFingerValueFallsBackOff`、`testCorruptPayloadFallsBackSafeDefaults`、`testInvalidCornerInPayloadFallsBackOff`（L86-123） | ✅ |
| 4 future schema safe behavior | load 先读版本（L105）→ futureSchema 不解码（L109-112）；save 前再查版本（L138-141） | `testFutureSchemaLoadPreservesData`、`testFutureSchemaSaveRefused`（L127-159） | ✅ |
| 5 isolated suite | 独立 suite + 前缀双保险（L83/L85-89） | `testIsolatedSuiteDoesNotTouchStandardDefaults`（L175-185） | ✅ |
| 6 reset activation settings only | `resetActivation()` 只清 3 key（L155-160） | `testResetActivationClearsOnlyActivationKeys`、`testResetActivationDoesNotTouchLayoutStore`、`testLoadAfterResetReturnsProductDefaults`（L189-237） | ✅ |
| 7 changing corner stops old service before new | `transitions` restarts 块（L98-104）：`restartHotCorner(newCorner)` = 停旧启新 | `testCornerChangeRestartsStopsOldBeforeNew`（ActivationServicePlanTests.swift L73-79） | ✅ |
| 8 shortcut rollback | 计划级：`rollback` = 反向 diff（L122-125）；注册级：T-1G-A `ShortcutRegistrationOutcome`（conflict/unavailable 保留旧注册） | `testShortcutChangeRestarts`、`testRollbackRestoresOldPlan`、`testRollbackOfRestartIsRestart`、`testRollbackOfStartIsStop`（L97-102/L150-176） | ✅ |
| 9 no coordinates/app data in defaults | key 白名单 3 个 + 载荷字段白名单 6 个（测试断言） | `testNoCoordinatesOrAppDataInDefaults`（L241-266） | ✅ |

## 4. MINOR-2 契约闭环验证（T-1G-A-r1 MINOR-2 → T-G-P3 闭环）

| 契约要求 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| load 先读原始版本 → futureSchema 不解码不覆盖 | `load()` L105 读原始 `activation.schemaVersion`；L109-112 版本 > current → `.futureSchema(storedVersion:)`，**在 L124-125 任何 decode 之前** | `testFutureSchemaLoadPreservesData`：版本 999 + 载荷 `Data("future-schema-payload")` 原样保留（L139-140 断言 data 与 integer 均未变） | ✅ |
| save 前再查版本 → refusedFutureSchema | `save()` L138-141 写入前检查，> current → `.refusedFutureSchema(storedVersion:)`，**在 L144 任何写入之前** | `testFutureSchemaSaveRefused`：版本 999 保留、载荷原样、`fourFingerActivationEnabled` key 为 nil（零新值写入，L155-158） | ✅ |
| 版本 999 载荷原样保留零新值写入 | 同上两处 guard | 同上两测试 | ✅ |
| 数据先写、版本最后写（提交标记） | L144-147 数据 → L149 版本最后写 | 代码核对（崩溃方向安全：见 INFO-2） | ✅ |

## 5. 服务启停计划语义验证

| 语义 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| stops→restarts→starts 顺序契约 | `transitions` L87-96（stops）→ L98-104（restarts）→ L106-115（starts）三块顺序构造 | `testStopsBeforeRestartsBeforeStarts`（L122-128：`[.stopFourFinger, .restartHotCorner(B), .restartShortcut(B)]`）、`testMixedStartStopOrdering`（L130-136：`[.stopHotCorner, .stopFourFinger, .startShortcut(A)]`） | ✅ |
| 同计划零转换 = 幂等 | L88-115 全部条件不成立 → `[]` | `testSamePlanNoTransitions`（L51-55）、`testApplyIsIdempotent`（L178-185） | ✅ |
| rollback = 反向 diff | `rollback(from:to:)` = `transitions(from: new, to: old)`（L122-125） | `testRollbackRestoresOldPlan`（L150-161：应用 rollback 后恢复旧计划 + 断言等于反向 diff）、`testRollbackOfRestartIsRestart`（L163-169）、`testRollbackOfStartIsStop`（L171-176） | ✅ |
| 整体计算/应用 = 原子 | diff 整体计算（L83-118 纯函数）；`apply` 每步确定性（L60-75） | `testApplyTransitionsReachesNewPlan`（L140-148：逐条应用后到达新计划） | ✅ |
| restart = 停旧启新（§9.8-7） | `restartHotCorner/restartShortcut` 语义文档化（L26-35 注释 + L98-104 生成条件：仅新旧值均非 nil 且不同） | `testCornerChangeRestartsStopsOldBeforeNew`、`testShortcutChangeRestarts` | ✅ |
| 计划派生（仅已启用 trigger 进入计划） | `init(settings:fourFingerEnabled:)` L53-57：`hotCornerEnabled ? selectedCorner : nil` | `testPlanFromSettingsAndFourFinger`、`testPlanFromSettingsIgnoresDisabledTriggers`（L23-47） | ✅ |

## 6. 状态机与 Enabled≠Ready 验证

| 语义 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| 七态与 TouchProviderState 1:1 对齐 | `FourFingerActivationState`（L16-23）与 `TouchProviderState`（TouchProvider.swift L22-30）逐 case 同构；`init(providerState:)` L26-36 全 case 映射 | `testSevenStatesAlignWithTouchProviderState`（L19-32）、`testSuspensionReasonPreservedInConversion`（L34-39，覆盖 PinchSuspensionReason 全部 3 case：sleep/sessionInactive/screenConfigurationChanged，PinchRecognizer.swift L152-156） | ✅ |
| Enabled≠Ready | `isReady = enabled && state == .ready`（L167-169） | `testEnabledNotReadySemantics`（L226-239：enabled=true + 各失败态 → 非 ready；enabled=false + ready → 非 ready）、`testEnabledAndReadyAreIndependentDimensions`（L265-277） | ✅ |
| displayKind 按事实展示 | L172-189：开关开 → 按后端事实；开关关 → `.disabled` | `testDisplayKindShowsFactsWhenEnabled`（L241-254）、`testDisplayKindDisabledWhenSwitchOff`（L256-263） | ✅ |
| 非法转换拒绝不崩溃 | `nextState` 默认 nil（L128-129）→ `apply` 返回 false 状态不变（L71-75） | `testIllegalTransitionsRejected`（L183-202：11 组非法组合，含 off+backendReady/checking+recheck/ready+backendReady/suspended+backendReady 等） | ✅ |
| start/stop 幂等（与 provider 对齐） | `(_, .start) where state != .off` → no-op（L84-85）；`(.off, .stop)` → no-op（L126-127） | `testStartIsIdempotentFromAnyActiveState`（L53-61）、`testStopFromOffIsIdempotentNoop`（L175-179） | ✅ |
| 挂起中可更新原因 | `(_, .suspend) where state != .off`（L120-121）覆盖 suspended→suspended | `testSuspendWhileSuspendedUpdatesReason`（L141-145） | ✅ |
| resume → checking（不自动弹权限/不呼出窗口，§21.2） | `(.suspended, .resume)` → `.checking`（L122-123） | `testResumeFromSuspendedGoesChecking`（L147-152） | ✅ |
| 全生命周期 | 转换表完整（L81-127） | `testFullLifecycleSequence`（L206-222：off→checking→ready→suspended→checking→noDevice→ready→off） | ✅ |

## 7. 测试证据（实测命令与输出）

**命令 1**：`swift test --filter 'ActivationPreferencesTests|ActivationServicePlanTests|FourFingerActivationStateTests'`（workdir = /Users/mac/Projects/Launch_Copy/PagingPrototype）
**输出**（节选）：
```
Test Suite 'FourFingerActivationStateTests' passed at 2026-09-05 19:50:53.278.
	 Executed 24 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 19:50:53.278.
	 Executed 57 tests, with 0 failures (0 unexpected) in 0.034 (0.038) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:50:53.278.
	 Executed 57 tests, with 0 failures (0 unexpected) in 0.034 (0.039) seconds
```
exit code 0。**57/0 与 worker 声明一致**（ActivationPreferencesTests 15 + ActivationServicePlanTests 18 + FourFingerActivationStateTests 24，逐文件方法计数核对：15+18+24=57）。

**命令 2**：`swift test`（全量，独立重跑两次）
**输出**（节选）：
```
Test Suite 'All tests' passed at 2026-09-05 19:51:45.841.
	 Executed 1342 tests, with 0 failures (0 unexpected) in 17.424 (17.511) seconds
```
exit code 0。**1342/0 与 worker 声明一致**（基线 1285 + 本任务 57）。

**构建新鲜度**：测试输出中的测试名与当前源文件一一对应（如 `testFutureSchemaSaveRefused`、`testCornerChangeRestartsStopsOldBeforeNew`、`testEnabledNotReadySemantics`），证明编译的是当前源码而非旧 `.build` 产物（MEMORY.md 陷阱已规避）。

## 8. 隐私红线静态扫描（PLAN §11）

命令：`grep -nE 'addGlobalMonitorForEvents|CGEvent\.tapCreate|AXIsProcessTrusted|IOHID|LaunchBetter|Buho|frontmostApplication|NSEvent|NSApp|AppKit|dlopen|dlsym|MTDevice|Date\(\)|Date\.timeIntervalSince|pointer coordinate|CGEvent|NSEvent\.mouseLocation'` 六文件 → 仅 3 处注释命中「纯 Foundation，无 AppKit」（ActivationPreferences.swift L14、ActivationServicePlan.swift L13、FourFingerActivationState.swift L10，属政策文字非代码使用）；其余零命中。`import` 检查：源文件仅 `import Foundation`（L17/L16/L13）；测试文件 `import XCTest` + `@testable import PagingPrototypeApp`。墙钟依赖检查：`Date\(\)|Date\.|timeIntervalSince|CACurrentMediaTime|ProcessInfo|wall` 六文件零命中（grep exit 1）。无触点坐标持久化（仅中性 enum/计数）。

## 9. 写集合规核查

- 仓库无基线提交（`git log`：`your current branch 'main' does not have any commits yet`），以文件 mtime 为准：
  - 6 个新文件：`ActivationPreferences.swift` 19:47:27、`ActivationServicePlan.swift` 19:47:31、`FourFingerActivationState.swift` 19:47:37、`FourFingerActivationStateTests.swift` 19:48:23、`ActivationServicePlanTests.swift` 19:48:34、`ActivationPreferencesTests.swift` 19:48:40 — 全部落在 T-G-P3 工作窗口（19:45-19:50），且 `find Sources Tests -newermt 19:45:00 ! -newermt 19:50:00` 仅命中这 6 个文件
  - 冻结树：`Package.swift` 2026-08-28 19:42:55、`AppLaunchController.swift` 2026-08-28 20:46:54 — 未触碰 ✅；冻结目录最新文件 `Sources/AppGridUI/FolderOverlayView.swift` 2026-09-05 14:13:49（早于窗口）✅
  - 共享文件：`AppDelegate.swift` 2026-09-05 14:09:47、`AppMain.swift` 2026-08-29、`AppArguments.swift` 2026-08-30、`KeyboardFocusController.swift` 2026-08-30 — 未触碰 ✅
  - 既有相关文件：`ActivationSettings.swift` 2026-09-05 18:28:07（T-1G-A 窗口）、`TouchProvider.swift` 2026-09-05 19:33:47（T-G-P2 窗口）— 均早于 T-G-P3 窗口，未触碰 ✅
  - 窗口内其他改动仅 `Workflow/` 文件（T-G-P2-r1.md 19:45:09、concurrency-check-1g-wave4.md 19:45:22、watchdog.json 19:48:02、results/T-G-P3.md 19:49:39）— 属 PLAN §5 允许写集（Workflow/）✅
  - 19:50 之后无任何 Sources/Tests 文件被修改（无后续任务污染）
- 写范围合规：仅 6 个新文件；无 AppDelegate 接线、无窗口代码、无 Package.swift 改动、无真实 defaults 污染、无真实轨迹提交。

## 10. Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**MINOR-1 [verified] 偏差 2 披露精度：Bool 型损坏版本 key 被 `as? Int` 桥接为 1，按「版本 1」处理而非披露的「按全新安装处理」**
- 位置：`ActivationPreferences.swift:105`（`defaults.object(forKey: Key.schemaVersion) as? Int`）。
- 实测（/tmp probe，未触碰项目）：`UserDefaults` 存 `true` 后 `object(forKey:) as? Int` 返回 `Optional(1)`（NSNumber 桥接，Bool→Int 成功）；String/Double 型损坏版本返回 nil（按全新安装处理，与披露一致）。
- 影响：Bool 型损坏版本 key 时，load 走「版本 1」路径（继续读 fourFinger key，缺失 → false），而非披露的「全新安装 → 产品默认（四指 true）」。方向安全：1 = 当前版本，无 future-schema 覆盖风险、不崩溃；仅属极端损坏场景（未来版本不可能以 Bool 存储）。披露「损坏版本 key（非 Int）→ 按全新安装处理」对 Bool 特例不精确。
- 建议：偏差 2 披露补充 Bool 特例说明，或版本读取改用更严格校验（如 `(object as? NSNumber)?.intValue` + objCType 检查）。非验收阻断。

**MINOR-2 [verified] `save()` 编码失败静默跳过载荷写入，形成「已提交的部分写」**
- 位置：`ActivationPreferences.swift:145`（`if let data = try? JSONEncoder().encode(preferences.settings)`）。
- 影响：若 encode 失败，fourFinger 与版本仍写入（L144/L149）、载荷保持旧值且无错误返回——与「数据先写、版本最后写（提交标记）」意图相悖（提交标记保护的是崩溃，不是编码失败）。实际不可达：`ActivationSettings` 为平凡 Codable（6 个基础字段），encode 不会失败。
- 建议：encode 失败时返回错误结果（如扩展 `ActivationPreferencesSaveResult` 加 `.encodingFailed`），保持持久化层失败显式化。非验收阻断。

### QUESTION

**QUESTION-1 `(.ready, .backendReady)` 被拒绝——provider 重复上报 ready 的接线契约**
- 位置：`FourFingerActivationState.swift:93`（ready 无 backendReady case → default nil）。
- 现状：`testIllegalTransitionsRejected`（L193）显式固化「ready + backendReady 非法」。设计一致（ready 只能经 checking 到达），但真实 provider 可能在瞬时抖动/重查后重报 ready；接线层（T-G-P4）须自行处理（如忽略重复 ready 或先经 checking）。建议 T-G-P4 明确该契约。

**QUESTION-2 `displayKind` 对 (enabled: true, state: .off) 返回 `.disabled` 的语义确认**
- 位置：`FourFingerActivationState.swift:174-175`（state == .off → `.disabled`，不区分 enabled）。
- 现状：开关开但后端 off（未启动）显示「disabled」——事实语义（后端 off = 无活动）合理，但该组合无测试覆盖（`testDisplayKindDisabledWhenSwitchOff` 只测 enabled=false）。建议补一条断言或由 T-G-P4 文档化 UI 映射。

### INFO

**INFO-1 [verified]** 提交标记崩溃语义：save 崩溃于数据写后、版本写前（L144-147 与 L149 之间）→ 下次 load 版本 key 缺失 → 按全新安装处理（产品默认），未提交值丢失。方向安全（不会出现「新版本+旧数据」），与披露的提交标记模式一致。

**INFO-2 [verified]** `ActivationPreferences.schemaVersion` 为可写结构体字段但 `save()` 忽略之（L149 始终写 `currentSchemaVersion`）；偏差 4 已披露（「结构体 schemaVersion 仅作读取报告」），`testSaveWritesCurrentSchemaVersion`（L270-283）固化。API 略易误解（字段写入不影响持久化），建议文档注释强化。

**INFO-3 [verified]** `testNoCoordinatesOrAppDataInDefaults`（L262-265）只枚举载荷**顶层**字段；嵌套 `shortcut`（keyCode/modifiers，ShortcutRegistrationOutcome.swift L35-42）未枚举。keyCode 为数值虚拟键码（非「真实快捷键文本」红线项）且快捷键属用户获批配置（§21.2「持久化只写用户开关及获批配置」），在红线允许内。

**INFO-4 [verified]** 版本 key 存 Double（如 999.5）时 `as? Int` 返回 nil（实测）→ 按全新安装处理，与偏差 2 披露一致；仅 Bool 例外（见 MINOR-1）。

**INFO-5 [verified]** 测试隔离机制完整：UUID suite（ActivationPreferencesTests.swift L24）+ tearDown `removePersistentDomain`（L30）；`testIsolatedSuiteDoesNotTouchStandardDefaults`（L175-185）显式断言标准 defaults 零 `activation.` 前缀 key；`testResetActivationDoesNotTouchLayoutStore`（L209-221）用独立 layout suite 验证跨 suite 隔离。

## 11. 与 worker 结果声明的一致性（含 7 项偏差核对）

| worker 声明 | 复核结果 |
|---|---|
| 57 测试（15+18+24），`swift test --filter ...` exit 0 | ✅ 实测 57/0，exit 0（逐文件方法计数 15+18+24=57） |
| 全量 `swift test` 1342/0 | ✅ 实测 1342/0，exit 0（两次独立重跑） |
| 变更文件仅 6 个新文件 | ✅ mtime 验证（19:47-19:48 窗口；冻结树/共享文件未触碰；19:50 后零改动；Workflow/ 文件属允许写集） |
| 偏差 1：四指默认开启 | ✅ `ActivationPreferences()` 默认 `fourFingerActivationEnabled = true`（L36）；用户决策文档决策 2 确认；ADR-013 §7 L79-80 已标注用户决策覆盖；`testFreshLoadReturnsProductDefaults` 固化；hotCorner/shortcut 仍默认 Off |
| 偏差 2：非法存储值 vs 产品默认 | ⚠️ 基本属实（全新安装→产品默认；非 Bool 布尔→Off；String/Double 损坏版本→全新安装），但 Bool 型损坏版本经 NSNumber 桥接按「版本 1」处理（MINOR-1，方向安全） |
| 偏差 3：resetActivation 语义 | ✅ reset 后 load 回产品默认（四指 true），只清 3 个 activation key，不动 suite 内其他 key 与 layout store（L155-160 + 3 测试） |
| 偏差 4：save 始终写当前 schema 版本 | ✅ L149 + `testSaveWritesCurrentSchemaVersion`（L270-283） |
| 偏差 5：服务启停为纯值计划语义 | ✅ diff/apply/rollback 纯逻辑（ActivationServicePlan.swift 全文件），无 AppDelegate 接线；真实执行归 T-G-P4（任务包明确「不接 AppDelegate」） |
| 偏差 6：展示层只产出中性 enum | ✅ `FourFingerActivationDisplayKind` 仅 enum case（L137-152），零用户可见字符串；文案映射归 UI 层 |
| 偏差 7：状态机幂等语义 | ✅ start 已启动 = no-op（L84-85）、stop 未启动 = no-op（L126-127）、挂起中可更新原因（L120-121），与 T-G-P2 provider 文档化语义对齐（TouchProvider.swift L44-46） |
| 未决项（T-G-P4 接线、UI 文案映射、版本 key 损坏策略、迁移路径、物理门） | ✅ 均属实且不属本任务验收范围（任务包明确纯逻辑 + 不接 AppDelegate） |

## 12. 置信度

- **高**：验收标准、§9.8 九项、MINOR-2 闭环、服务计划语义、状态机七态/转换表/Enabled≠Ready 全部基于逐行代码核对 + 实测命令输出（57/0、1342/0）+ 静态扫描 + mtime 证据，非仅依赖 worker 声明。
- **中**：MINOR-1 的 NSNumber 桥接行为经 /tmp 独立 probe 实测确认（非推演）；MINOR-2 为代码路径推演（encode 失败实际不可达）；QUESTION-1/2 为接线层契约确认点。
- 未执行：真实触控板/设备验证（T-G-P6 范围）、真实服务启停接线（T-G-P4）、UI 文案映射、物理门。

---

**Verdict: PASS**（0 BLOCKER / 0 MAJOR / 2 MINOR / 2 QUESTION / 5 INFO）— 满足 PLAN §10 `INDEPENDENT_REVIEW = PASS`（0 BLOCKER/0 MAJOR）与 `PREFERENCES_TESTS = PASS`（§9.8）门槛。MINOR-1/MINOR-2 为披露精度与理论路径改进建议，不构成验收阻断；QUESTION-1/2 为 T-G-P4 接线时的契约确认点。
