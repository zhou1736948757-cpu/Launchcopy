# PROVENANCE / REFERENCE_EXPOSED.md

- **用途**：记录接触参考代码（LaunchBetter 四指手势白名单）的事实（Prompt §2.1：读取参考代码的角色记录 `REFERENCE_EXPOSED`）。
- **性质**：如实记录；**不宣称 clean-room**；代码所在目录由用户持有并明确指定为参考，不等于每段代码来源和使用权已验证（Prompt §2.1；审计 §6）。

## 接触记录

| 日期 | 接触者 | 角色 | 接触对象（白名单） | 范围 | 记录位置 |
|---|---|---|---|---|---|
| 2026-09-05 | Main（当前主对话） | 主控/编排 | LaunchBetter 白名单 4 文件：`Packages/LaunchPlatform/Sources/LaunchPlatform/PinchAnalyzer.swift`、`MultitouchSupport.swift`、`GestureCaptureEngine.swift`；`LaunchBetterApp/ActivationCoordinator.swift` | 逐文件审计（行号/摘要/代码事实/注释/推断）；测试文件仅定位未读取 | `Docs/FOUR_FINGER_REFERENCE_AUDIT.md` |
| 2026-09-05 | T-G-P0 Worker | 实现（文档任务） | **未直接读取 LaunchBetter 源码**；仅复核审计文档完整性（对照 Prompt §17.3） | 复核记录见审计文档 §8 | `Docs/FOUR_FINGER_REFERENCE_AUDIT.md` §8 |

## 边界声明

- 未读取：`BuhoReverseNotes`、`2026-08-25-buho-launchpad-reverse`、任何 Buho 反编译全文/逆向资料（Prompt §2.1 禁止路径）。
- 未读取白名单外 LaunchBetter 文件。
- 未复制整份参考源码；仅行为规格提取与逐文件审计摘要（Prompt §17.3）。
- 后续任何角色读取白名单文件须追加登记本文件。

## 更新记录

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-09-05 | 创建（登记 Main 接触 + T-G-P0 Worker 复核声明） | T-G-P0 Worker |
