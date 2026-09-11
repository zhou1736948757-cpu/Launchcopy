# T-worker-b-launchsmoke — 应用启动 smoke（Phase 1B t11，§3.2 受控附加项）

**Worker**: worker-integration（deepseek-v4-flash:0731, max）
**任务**: t11（启动 smoke：触发方式选择与记录 / stale 拒绝 / 非致命失败 / 红线 / 无进程管理）
**日期**: 2026-08-28
**依赖**: t10 装配完成（AppCatalogAssembly / ItemBindingToken / servedRevision）
**接口契约**: PHASE1B_REAL_APP_CONTENT_PROMPT.md §3.2（启动 sub-gate 全项）+ §9（accessibility 键盘层级文档化允许）+ §10.3（资源隔离）
**Scope（互斥）**: `Sources/PagingPrototypeApp/`（AppLaunchController.swift）、`Tests/PagingUITests/`（AppLaunchControllerTests.swift）、`Workflow/results/T-worker-b-launchsmoke.md`
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 §2.2 任何禁止来源；仅依据 PHASE1B_REAL_APP_CONTENT_PROMPT.md、wave1-interfaces.md、PagingPrototype 既有源码与本团队 Main 任务指令）

---

## 一、触发方式（本项目独立决定，记录）

**单击** cell 启动（`NSClickGestureRecognizer` 挂在 `PagingSurface`；点击子视图经祖先识别器接收；命中测试沿视图链找到 `AppGridCellView` → 校验管线 → 启动）。公开 `handleClick(at:)` / `handleCell(_:)` 与手势识别器同一路径（可测）。
**双击 / Return 未接线，理由（文档化，§9 允许）**：键盘焦点模型需 cell 成为 key view（`acceptsFirstResponder` 属 AppGridUI 范围，Phase 1B 未交付），App 层无法在不越权的情况下安全接线 Return；键盘层明确标记 **Phase 1C gate**（§9「支持键盘焦点移动的基础能力，或在文档中明确本阶段只完成哪一层并标记后续 gate」——本项即文档化路径）。

## 二、§3.2 逐项落点

| §3.2 要求 | 实现 | 验证 |
|---|---|---|
| 触发方式自选并记录 | 单击（上节） | 记录于本文件 + 源码头注 |
| NSWorkspace 公开 API 仍可用 + catalog 中重新确认 | `NSWorkspaceAppLauncher`（`NSWorkspace.shared.open(url)`，macOS 14 SDK 编译通过）；启动前经 `AppCatalogAssembly.bundleURL(for:)` 在当前 snapshot 的 identity→URL 映射**重新确认**（映射随每次提交重建 → 旧 identity 立即失效） | 编译 + 单测（fresh/removed/deleted 三路径） |
| catalog revision 变化后拒绝 stale cell URL | `token.catalogRevision == provider.servedRevision` 不等 → `.rejectedStaleRevision`（不读 cell 捕获的任何 URL，只走当前映射） | `testStaleRevisionRejected`：构造旧 revision token → 拒绝且 launcher 零调用 |
| 启动失败非致命 + 中性错误状态 | `.failedToLaunch`：不崩溃、不弹窗、计数保留（内存 `outcomeCounts`），同会话可再次启动 | `testLaunchFailureNonFatalAndRecovers`：失败→恢复→成功 |
| 不把真实 bundle URL 写入 telemetry | telemetry 只记中性 `app.launch` 事件（无 URL/路径/名称/身份原文）；结果计数只进内存 | `testLaunchTelemetryContainsNoURL`：JSONL 含 `"event_phase":"app.launch"`，不含 Alpha/fixture.alpha/URL/`.app` |
| 无进程管理/最近使用/自动重启 | 未实现任何此类功能（无 LSSharedFileList / NSRunningApplication 管理 / 重启逻辑） | 代码审查（零新增面） |

**校验管线顺序**（`handleCell`）：① bindingToken 存在 → ② appID 类型解包 → ③ stale revision 拒绝 → ④ 当前 catalog 重新确认（bundleURL）→ ⑤ 磁盘 `fileExists` 重新确认 → ⑥ `launcher.openApplication`（失败 → 中性 `.failedToLaunch`）。全部拒绝路径返回中性枚举（无异常抛出）。

## 三、测试（Tests/PagingUITests/AppLaunchControllerTests.swift，8 测试全绿）

| 测试 | 断言 |
|---|---|
| `testSingleClickLaunchesCurrentApp` | `.launched`；launcher 收到 **Alpha 的 bundle URL**（fake .app，临时目录） |
| `testClickHitPathReachesCell` | `handleClick(at:)` 经 `surface.hitTest` 命中 cell → 启动（与手势识别器同一管线） |
| `testStaleRevisionRejected` | 旧 revision token → `.rejectedStaleRevision`，launcher 零调用 |
| `testRemovedAppRejected` | 幽灵 AppID（不在当前 catalog）→ `.rejectedMissingApp` |
| `testDeletedFileRejected` | 扫描后删除 bundle → `.rejectedMissingFile`（磁盘重新确认失败） |
| `testLaunchFailureNonFatalAndRecovers` | 失败 → `.failedToLaunch`；随后恢复 → `.launched`；计数分别累计 |
| `testBlankHitRejectedNoBinding` | 空白处点击 → `.rejectedNoBinding` |
| `testLaunchTelemetryContainsNoURL` | JSONL 有 `app.launch` 中性事件；无 app 名/bundle ID/URL/路径/`.app` |

**验证证据**：
- 8 测试全绿（含红线断言）；全量 `swift test` 414/414 通过（与 t10 一并收口）；
- `swift build -c release` exit 0、0 warnings；
- 真机 GUI 冒烟：`--catalog-root /tmp/paging-fakeapps` 装配运行 exit 0（启动控制器随装配接线编译进 release 二进制；物理单击不在无头环境执行——诚实声明：单击路径经同管线单测验证，未做真实鼠标事件注入）。

## 四、状态

**APP_LAUNCH_SMOKE = PASS**（§3.2 全项满足：触发方式记录、NSWorkspace 公开 API + catalog 重新确认、stale 拒绝、非致命失败、telemetry 无真实 URL、无进程管理；键盘层按 §9 文档化延至 Phase 1C——合法非阻塞）。
