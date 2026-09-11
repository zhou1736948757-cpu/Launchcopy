# T-G-P2 — 平台 provider（Mock 先行）

## Objective
1. 定义 `TouchProvider` protocol：设备生命周期（start/stop/restart）、有效触点帧（device-scoped）、值转换、状态通知（Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended）。
2. Mock provider：合成匿名触点帧注入（可编程序列），生命周期测试（start/start、stop/stop、start-stop-start、退出时异步回调、同步重入假后端无死锁）。
3. 生命周期测试覆盖 Prompt §23.1 P13/P14/P15 与 §20.2 锁序要求（回调锁外派发、缓冲有界、保留 begin/end/cancel）。
4. 真实 MultitouchSupport 后端**不实现**（需 T-G-P0 风险清单用户确认后独立子任务）。

## Expected / Allowed Write Scope
- 新文件 `Sources/PagingPrototypeApp/`（TouchProvider.swift、MockTouchProvider.swift 等）
- 新测试 `Tests/PagingUITests/`
- 禁止：真实 MultitouchSupport 后端、窗口代码、AppDelegate、冻结树、Package.swift

## 验收
- Mock 生命周期测试 executed > 0 且 0 failures
- 无真实设备访问；无 dlopen/dlsym
- 不 commit/push/tag
