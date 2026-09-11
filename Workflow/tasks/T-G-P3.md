# T-G-P3 — 配置与入口状态（四指开关/迁移/展示）

## Objective
1. `ActivationPreferences`：专用 namespace UserDefaults（与 Phase 1F layout store 分离）、schema version、非法值回 Off 不崩溃、独立 suite 测试、reset activation settings 独立动作、unknown future schema 不被旧代码静默覆盖。
2. 四指入口状态模型：Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended；Enabled≠Ready（用户打开开关但后端失败时显示事实）。
3. 持久化只写用户开关及获批配置，不写触点/设备序列号/原始坐标/后台应用身份。
4. 配置改变后 service start/stop 原子、幂等、可回滚。

## Expected / Allowed Write Scope
- 新文件 `Sources/PagingPrototypeApp/`（ActivationPreferences.swift、FourFingerActivationState.swift 等）
- 新测试 `Tests/PagingUITests/`（独立 UserDefaults suite）
- 禁止：AppDelegate 接线、真实 defaults 污染、窗口代码、冻结树、Package.swift

## 验收
- 测试覆盖 Prompt §9.8（9 项）与 §21.2 状态模型
- 测试绝不污染真实用户 defaults
- 不 commit/push/tag
