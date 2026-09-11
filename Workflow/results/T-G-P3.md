# T-G-P3 — 配置与入口状态（四指开关/迁移/展示）（Worker 结果）

- **Task**: T-G-P3（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-05
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective 完成度**: 4/4（ActivationPreferences 专用 namespace 持久化 + MINOR-2 契约、四指入口状态模型 Enabled≠Ready、§9.8 九项 + §21.2 状态模型测试、服务启停原子/幂等/可回滚偏好层语义）

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/ActivationPreferences.swift` | 新增 | `ActivationPreferences`（schemaVersion + fourFingerActivationEnabled + settings(ActivationSettings)，产品默认四指开启）；`ActivationPreferencesLoadResult`（.loaded/.futureSchema(storedVersion:)）；`ActivationPreferencesSaveResult`（.saved/.refusedFutureSchema(storedVersion:)）；`ActivationPreferencesPersisting` 协议；`UserDefaultsActivationPreferencesStore`（专用 suite 默认 `com.pagingprototype.activation`，key 带 `activation.` 前缀双保险；failable init 绝不回退标准 defaults；load 先读原始版本→futureSchema 不解码不覆盖（MINOR-2）；非法布尔→Off、损坏载荷→安全默认；save 前再查版本拒绝写入、数据先写版本最后写（提交标记）、始终写当前 schema 版本；resetActivation 只清 3 个 activation key；removePersistentDomain 供测试清理） |
| `Sources/PagingPrototypeApp/ActivationServicePlan.swift` | 新增 | `ActivationServiceKind`（hotCorner/globalShortcut/fourFinger）；`ActivationServiceTransition`（start/stop/restart 携带目标值，restart=停旧启新）；`ActivationServicePlan`（由 ActivationSettings+fourFinger 派生，apply 确定性）；`ActivationServicePlanDiff`（transitions 顺序契约 stops→restarts→starts；同计划零转换=幂等；rollback=反向 diff 恢复旧计划=可回滚；整体计算/应用=原子） |
| `Sources/PagingPrototypeApp/FourFingerActivationState.swift` | 新增 | `FourFingerActivationState` 七态（off/checking/ready/noDevice/unavailable/permissionNotConfirmed/suspended(reason:)，与 TouchProviderState 1:1 对齐含 init(providerState:)）；`FourFingerActivationTransition`（start/backendReady/backendNoDevice/backendUnavailable/permissionNotConfirmed/recheck/suspend/resume/stop）；`FourFingerActivationStateMachine`（纯值状态机，合法表 nextState，非法拒绝返回 false 不崩溃，start/stop 幂等与 provider 对齐，挂起中可更新原因）；`FourFingerActivationDisplayKind`（中性展示 enum，UI 层映射文案）；`FourFingerActivationStatus`（enabled 与 state 双维度，isReady = enabled && state == .ready，displayKind 按事实展示） |
| `Tests/PagingUITests/ActivationPreferencesTests.swift` | 新增 | §9.8 持久化部分 + MINOR-2 契约 + 独立 suite 隔离（15 tests；UUID suite + tearDown removePersistentDomain） |
| `Tests/PagingUITests/ActivationServicePlanTests.swift` | 新增 | §9.8-7/§9.8-8 服务启停计划：派生/幂等/顺序/应用/回滚（18 tests） |
| `Tests/PagingUITests/FourFingerActivationStateTests.swift` | 新增 | §21.2 状态模型：七态对齐/转换表/非法拒绝/全生命周期/Enabled≠Ready/displayKind（24 tests） |

未改动：冻结树、Package.swift、AppDelegate/AppMain/AppArguments/KeyboardFocusController、AppLaunchController.swift、ActivationSettings.swift、TouchProvider.swift、任何既有测试、任何既有源文件（mtime 核验：全部早于本任务窗口 19:47–19:48）。

## Test counts

- 命令：`swift test --filter 'ActivationPreferencesTests|ActivationServicePlanTests|FourFingerActivationStateTests'`
- exit code：**0**
- executed：**57**；passed：**57**；failed：**0**

| 套件 | executed | passed | failed | 覆盖 |
|---|---|---|---|---|
| ActivationPreferencesTests | 15 | 15 | 0 | §9.8 持久化 9 项 + MINOR-2 + 独立 suite |
| ActivationServicePlanTests | 18 | 18 | 0 | §9.8-7/§9.8-8 服务启停计划 |
| FourFingerActivationStateTests | 24 | 24 | 0 | §21.2 状态模型 + Enabled≠Ready |

全量回归：`swift test` → **1342 executed / 0 failures**（基线 1285 + 本任务 57；exit 0）。

## Evidence（命令 + 输出）

```
$ swift test --filter 'ActivationPreferencesTests|ActivationServicePlanTests|FourFingerActivationStateTests'
Test Suite 'ActivationPreferencesTests' passed at 2026-09-05 19:48:45.781.
	 Executed 15 tests, with 0 failures (0 unexpected) in 0.026 (0.027) seconds
Test Suite 'ActivationServicePlanTests' passed at 2026-09-05 19:48:45.784.
	 Executed 18 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds
Test Suite 'FourFingerActivationStateTests' passed at 2026-09-05 19:48:45.788.
	 Executed 24 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 19:48:45.788.
	 Executed 57 tests, with 0 failures (0 unexpected) in 0.032 (0.035) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:48:45.789.
	 Executed 57 tests, with 0 failures (0 unexpected) in 0.032 (0.036) seconds
$ echo $?
0

$ swift test
Test Suite 'All tests' passed at 2026-09-05 19:49:06.226.
	 Executed 1342 tests, with 0 failures (0 unexpected) in 17.148 (17.232) seconds
```

## Per-criterion results（任务包验收逐项）

| 验收项 | 结果 | 证据 |
|---|---|---|
| 专用 namespace UserDefaults（与 Phase 1F layout store 分离；独立 suite 或明确前缀，绝不碰真实用户 defaults 既有 key） | **PASS** | `UserDefaultsActivationPreferencesStore` 专用 suite（默认 `com.pagingprototype.activation`）+ `activation.` key 前缀双保险；failable init 绝不回退标准 defaults；`testIsolatedSuiteDoesNotTouchStandardDefaults`（标准 defaults 零 `activation.` 前缀 key）；`testResetActivationDoesNotTouchLayoutStore`（独立 layout suite 数据不受影响） |
| schema version 字段；decode 前检查原始版本——unknown future schema 不得被旧代码静默覆盖（MINOR-2 契约） | **PASS** | `load()` 先读原始 `activation.schemaVersion`，> current → `.futureSchema(storedVersion:)` 不解码不覆盖；`save()` 写入前再查版本 → `.refusedFutureSchema`；`testFutureSchemaLoadPreservesData` / `testFutureSchemaSaveRefused`（版本与载荷原样保留、零新值写入） |
| 非法值回 Off 不崩溃（布尔/枚举非法值 → 安全默认） | **PASS** | 非 Bool 类型 → Off（`testInvalidFourFingerValueFallsBackOff`）；损坏 JSON 载荷 → 安全默认（`testCorruptPayloadFallsBackSafeDefaults`）；非法角枚举 → Off（`testInvalidCornerInPayloadFallsBackOff`，复用 ActivationSettings 安全解码） |
| reset activation settings 独立动作（只清 activation namespace，不动 layout store） | **PASS** | `resetActivation()` 只 remove 3 个 activation key；`testResetActivationClearsOnlyActivationKeys`（suite 内外来 key 保留）；`testResetActivationDoesNotTouchLayoutStore`；`testLoadAfterResetReturnsProductDefaults` |
| 持久化只写用户开关及获批配置（fourFingerActivationEnabled 等），不写触点/设备序列号/原始坐标/后台应用身份 | **PASS** | `testNoCoordinatesOrAppDataInDefaults`：持久域 key 白名单 = 3 个 activation key；载荷 JSON 字段白名单 = ActivationSettings 6 中性字段（无坐标/设备/应用身份） |
| 配置改变后 service start/stop 原子、幂等、可回滚（偏好层语义，不接 AppDelegate） | **PASS** | `ActivationServicePlanDiff`：同计划零转换（`testSamePlanNoTransitions`）；顺序契约 stops→restarts→starts（`testStopsBeforeRestartsBeforeStarts`/`testMixedStartStopOrdering`）；整体应用到达新计划（`testApplyTransitionsReachesNewPlan`）；rollback=反向 diff 恢复旧计划（`testRollbackRestoresOldPlan`/`testRollbackOfRestartIsRestart`/`testRollbackOfStartIsStop`）；换 corner 先停旧再启新（`testCornerChangeRestartsStopsOldBeforeNew`）；快捷键重配 restart + 注册级 rollback 由 T-1G-A ShortcutRegistrationOutcome 覆盖 |
| 四指入口状态模型 Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended（与 TouchProviderState 对齐） | **PASS** | `FourFingerActivationState` 七态 + `init(providerState:)` 1:1 映射；`testSevenStatesAlignWithTouchProviderState` / `testSuspensionReasonPreservedInConversion` |
| **Enabled≠Ready**（用户打开开关但后端失败时显示事实） | **PASS** | `FourFingerActivationStatus.isReady = enabled && state == .ready`；`testEnabledNotReadySemantics`（enabled=true + 各失败态 → 非 ready）；`testEnabledAndReadyAreIndependentDimensions`；`testDisplayKindShowsFactsWhenEnabled`（开关开按后端事实展示）；`testDisplayKindDisabledWhenSwitchOff` |
| 状态转换纯值模型 + 测试 | **PASS** | `FourFingerActivationStateMachine`（合法表 nextState，非法拒绝返回 false 状态不变）；24 tests 覆盖：启动/解析/降级/恢复/recheck/挂起/恢复/停止/非法拒绝/全生命周期 |
| §9.8 Preferences 9 项（按 Prompt 原文逐项） | **PASS** | 1 默认全 Off（fresh load，四指默认开启为用户决策覆盖项，见偏差 1）；2 round trip（`testSaveLoadRoundTrip`/`testSaveLoadRoundTripDefaults`）；3 非法枚举回 Off（3 tests）；4 future schema 安全（2 tests）；5 独立 suite（`testIsolatedSuiteDoesNotTouchStandardDefaults`）；6 reset activation only（3 tests）；7 换 corner 先停旧再启新（`testCornerChangeRestartsStopsOldBeforeNew`）；8 shortcut rollback（`testShortcutChangeRestarts` + `testRollbackRestoresOldPlan`，注册级见 T-1G-A）；9 无坐标/app 数据（`testNoCoordinatesOrAppDataInDefaults`） |
| §21.2 状态模型（Enabled≠Ready 语义、各状态转换） | **PASS** | 见上两行；`testFullLifecycleSequence`（off→checking→ready→suspended→checking→noDevice→ready→off 全链） |
| 独立 UserDefaults suite 测试（suiteName 隔离，测试后清理，绝不污染真实用户 defaults） | **PASS** | 每测试 UUID suite + tearDown `removePersistentDomain`；`testIsolatedSuiteDoesNotTouchStandardDefaults` 显式断言标准 defaults 零污染 |
| MINOR-2 契约测试（future schema 版本不被静默覆盖） | **PASS** | `testFutureSchemaLoadPreservesData` / `testFutureSchemaSaveRefused`（版本 999 + 载荷原样保留、拒绝写入、零新值） |
| 不 commit/push/tag | **PASS** | 无任何 git 操作 |
| 隐私红线（PLAN §11 静态扫描） | **PASS** | 6 个新文件 grep 零命中（addGlobalMonitorForEvents/CGEvent.tapCreate/AXIsProcessTrusted/IOHID/LaunchBetter/Buho/frontmostApplication/pointer coordinate）；纯 Foundation 无 AppKit |
| 写集合规（未触碰冻结树/AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift/AppLaunchController.swift/既有文件） | **PASS** | mtime 核验：全部既有文件早于本任务窗口（19:47–19:48）；冻结树 find -newer 零命中 |

## Deviations（范围披露）

1. **四指默认开启**：`ActivationPreferences()` 默认 `fourFingerActivationEnabled = true`（用户决策 2026-09-05 覆盖 ADR-013 §7 原锁定 false）。hot corner / global shortcut 仍默认 Off（§9.8-1 其余项不变）。默认开启 ≠ 立即启用：由状态模型 Enabled≠Ready（后端就绪才 isReady）与物理门流程表达。
2. **非法存储值 vs 产品默认的区分**：全新安装（无版本记录）→ 产品默认（四指 true）；损坏布尔值（非 Bool 类型）→ least-privilege Off（"非法值回 Off" 字面语义，与 T-1G-A ActivationSettings 非法枚举回 Off 一致）。损坏版本 key（非 Int）→ 无法确认真实版本，按全新安装处理（允许写入）。
3. **resetActivation 语义**：清空 namespace 后 load 回到产品默认（四指默认开启）——reset = 恢复出厂默认，非强制 Off；只清 3 个 activation key，不动 suite 内其他 key 与 layout store。
4. **save() 始终写当前 schema 版本**：忽略结构体误设的未来版本（`testSaveWritesCurrentSchemaVersion`），避免自锁只读；结构体 schemaVersion 仅作读取报告。
5. **服务启停为纯值计划语义**：diff/apply/rollback 均为纯逻辑（原子=整体计算/应用、幂等=同计划零转换、可回滚=反向 diff）；真实服务 start/stop/restart 执行与失败回滚由 T-G-P4 接线层落实（任务包明确"不接 AppDelegate"）。
6. **展示层只产出中性 enum**：`FourFingerActivationDisplayKind` 不产出用户可见字符串（UI 层映射文案）；"保留菜单/Dock/快捷键入口" 为 UI/协调器策略，归 T-G-P4。
7. **状态机幂等语义**：start 已启动 = no-op、stop 未启动 = no-op（与 T-G-P2 provider 文档化语义对齐）；挂起中可更新挂起原因（保持显示事实，`testSuspendWhileSuspendedUpdatesReason`）。

## Unresolved questions

1. 真实服务启停接线（T-G-P4）：本层计划语义 → 实际 start/stop/restart 执行、失败回滚与 generation 校验。
2. 展示文案映射（UI 层）：displayKind → 用户可见文本；后端失败时"保留菜单/Dock/快捷键入口"的 UI 策略。
3. 版本 key 损坏（非 Int）按全新安装处理：若未来需更强保护（损坏版本也拒绝写入）由后续任务定案。
4. 迁移路径：stored version < current 时 save 升级到当前版本（本层已支持：decode 兼容旧版本、save 写当前版本）；显式 v0→v1 字段映射暂无需求。
5. 四指默认开启的最终生效仍依赖物理门（M01-M12）与 T-G-P4 接线；本任务只落偏好默认值与状态语义。

## Reviewer focus

1. **MINOR-2 契约闭环**：load 先读原始版本 → futureSchema 不解码不覆盖；save 前再查版本 → refusedFutureSchema；测试证明版本与载荷原样保留、零新值写入。
2. **独立 suite 隔离**：UUID suite + tearDown removePersistentDomain；标准 defaults 零污染显式断言；layout store（独立 suite）不受 reset 影响。
3. **非法值安全回退**：非 Bool → Off；损坏 JSON → 安全默认；非法枚举由 ActivationSettings 安全解码（不崩溃）。
4. **reset 边界**：只清 3 个 activation key，不动 suite 内其他 key、不动 layout store。
5. **服务计划语义**：stops→restarts→starts 顺序契约；同计划零转换（幂等）；rollback = 反向 diff 恢复旧计划（可回滚）；restart = 停旧启新（§9.8-7）。
6. **Enabled≠Ready**：isReady = enabled && state == .ready；displayKind 只按事实展示（开关开 + 后端失败 → 显示失败事实，不冒充就绪）。
7. **状态转换表**：合法/非法转换、幂等 start/stop、挂起原因更新、resume → checking（不自动弹权限/不呼出窗口）。
8. **隐私红线**：6 文件零命中；持久化 key 白名单 + 载荷中性字段白名单测试。

## Memory candidates（供 Main 门控）

1. **MINOR-2 闭环模式**：持久化层 decode 前检查原始 schema 版本；未来版本 → 拒绝写入 + 保留原值 + 明确错误（load 返回 futureSchema、save 返回 refusedFutureSchema）；数据先写、版本最后写（提交标记），中途崩溃不留"新版本+旧数据"。
2. **非法值回 Off 与产品默认的区分**：全新安装 → 产品默认（四指默认开启，用户决策）；损坏值 → least-privilege Off；损坏版本 key → 按全新安装处理。
3. **服务计划 diff 顺序契约**：stops → restarts → starts；restart = 停旧启新；rollback = 反向 diff（transitions(from: new, to: old)）恢复旧计划。
4. **Enabled≠Ready 双维度**：isReady = enabled && state == .ready；displayKind 只按事实展示；状态机 start/stop 幂等与 provider 对齐。
5. **四指默认开启 ≠ 立即启用**：偏好默认值 true（用户决策），生效仍须后端就绪（状态模型）+ 物理门 + T-G-P4 接线。
