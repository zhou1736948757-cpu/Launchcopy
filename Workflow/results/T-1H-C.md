# T-1H-C — Launch at Login adapter（Worker 结果）

- **Task**: T-1H-C（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-11
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective**: `LaunchAtLoginServicing` 窄协议 + Fake + `SMAppService.mainApp` 生产适配；默认 Off；测试永不注册真实 login item
- **Authority**: `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md` D4（SMAppService；default off；实机启用需单独宣布可逆授权）

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/LaunchAtLoginService.swift` | CREATE | `LaunchAtLoginStatus` + `LaunchAtLoginServicing` + `FakeLaunchAtLoginService` + `SMAppServiceLaunchAtLoginService` |
| `Tests/PagingUITests/LaunchAtLoginServiceTests.swift` | CREATE | 12 tests（Fake enable/disable/failure/requiresApproval/unavailable；纯 mapStatus；生产适配器仅构造断言 flag） |
| `Workflow/results/T-1H-C.md` | CREATE | 本结果 |

## Untouched（硬约束）

- `Sources/PagingPrototypeApp/AppDelegate.swift` — **未改**
- Settings UI — **未改 / 未新增**
- `Package.swift` — **未改**（`import ServiceManagement` 探针证明无需 linkerSettings）
- 无真实机 login item enable
- 无 git commit

## ServiceManagement / Package.swift 结论

- 探针包 `/tmp/SMAppServiceProbe`：`import ServiceManagement` + `SMAppService.mainApp` + `status` 映射 **链接成功，无 linkerSettings**。
- 因此 **生产 `SMAppServiceLaunchAtLoginService` 已交付**，**不**对 Main 报 BLOCKED。
- 平台下限已是 macOS 14（Package.swift），`SMAppService` 可用；无需额外 `@available` 门控。

## API / 服务类型

| 项 | 定案 |
|---|---|
| 服务类型 | **`SMAppService.mainApp`** — 主 `.app` 自身作为 login item；无需 helper executable / LoginItems 子 bundle |
| 协议 | `@MainActor LaunchAtLoginServicing`：`currentStatus()` / `setEnabled(_:)` → `LaunchAtLoginStatus`；`usesRealLoginItemRegistration` |
| 状态枚举 | `disabled` / `enabled` / `requiresApproval` / `unavailable` / `failure(message:)`（中性文案，无路径/密钥/PII） |
| 默认 | Fake 与产品语义均为 **Off**（`.disabled`） |
| Fake | 纯内存；`usesRealLoginItemRegistration == false`；可强制 failure / requiresApproval / unavailable |
| 生产 | `register()` / `unregister()`；错误后优先读真实 `status`；否则中性 failure message |

### Status mapping

| `SMAppService.Status` | `LaunchAtLoginStatus` |
|---|---|
| `.notRegistered` | `.disabled` |
| `.enabled` | `.enabled` |
| `.requiresApproval` | `.requiresApproval` |
| `.notFound` | `.unavailable` |
| `@unknown default` | `.unavailable` |

## Test counts

- 命令：`swift test --filter LaunchAtLoginServiceTests`
- exit code：**0**
- executed：**12**；passed：**12**；failed：**0**

| 套件 | executed | passed | failed |
|---|---:|---:|---:|
| LaunchAtLoginServiceTests | 12 | 12 | 0 |
| **合计** | **12** | **12** | **0** |

### Evidence（命令输出摘要）

```
Test Suite 'LaunchAtLoginServiceTests' passed ...
	 Executed 12 tests, with 0 failures (0 unexpected)
Test Suite 'Selected tests' passed ...
	 Executed 12 tests, with 0 failures (0 unexpected)
```

Build：`swift test --filter LaunchAtLoginServiceTests` 编译并链接成功（含 `LaunchAtLoginService.swift`）。

### 测试覆盖对照（§9.4）

| # | 验收项 | 结果 | 证据 |
|---|---|---|---|
| 1 | Unit tests never call real registration | **PASS** | Fake `usesRealLoginItemRegistration == false`；生产适配器测试只构造、**不**调用 `setEnabled` |
| 2 | Status mapping：enabled/disabled/requiresApproval/unavailable/failure | **PASS** | Fake 路径 + `mapStatus` 纯映射测试 |
| 3 | Default off | **PASS** | `testDefaultStatusIsDisabled` |
| 4 | Failure message 中性无秘密 | **PASS** | `testForcedFailurePreservesFailureStatus` / `testNeutralFailureMessageHasNoSecrets` |

## T-1H-F / Settings 接线责任（本任务不写 AppDelegate / Settings UI）

1. Settings domain 增加 Launch at Login 偏好（默认 `false`）→ 经 apply plan 调用 `setEnabled`。
2. UI 展示 `currentStatus()`：`.requiresApproval` 给可操作提示；`.failure` 显示中性 message；`.unavailable` 禁用控件。
3. 启动时 **不要** 自动 `setEnabled(true)`；仅用户显式动作 +（实机）单独授权后才允许真实 enable。
4. 注入缝：生产 `SMAppServiceLaunchAtLoginService()`；测试 / preview 用 `FakeLaunchAtLoginService`。

## Privacy / red-line

- 无真实 login item 注册发生在本任务测试或实现副作用路径（生产 `setEnabled` 未在本机调用）。
- failure message 固定中性字符串，不拼接 `localizedDescription` / userInfo / 路径。
- 不记录 bundle path、用户主目录、token、密码。

## Deviations / disclosures

1. `setEnabled` 采用 **返回 `LaunchAtLoginStatus`**（非 `throws`），以便把 requiresApproval/failure 一并作为 truthful displayed state 回传 UI；与任务包 “throws 或 Result-based” 等价。
2. 测试含 `mapStatus` / `neutralFailureMessage` 纯函数断言，以及对生产适配器的 **构造-only** flag 断言；**从未**对生产适配器调用 `setEnabled`。
3. 未改 Package.swift（ServiceManagement 无需 linkerSettings）。

## AccessDeclaration

- `NO_PRIOR_EXPOSURE` to forbidden reverse-engineering trees.
- Read: Gate 0 approval、Phase 1H prompt §6.7/§9.4、既有 `GlobalShortcutRegistrar` 模式、Package.swift platforms。
- Wrote only the three deliverable paths listed above.
