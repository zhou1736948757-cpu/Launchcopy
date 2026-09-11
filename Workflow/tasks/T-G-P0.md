# T-G-P0 — 四指参考审计 + ADR-013 + 风险清单

## Objective
1. `Docs/FOUR_FINGER_REFERENCE_AUDIT.md`：**已完成（Main 2026-09-05 直接产出，白名单 4 文件已读）**——本任务包确认该交付物，Worker 复核其完整性（§17.3 要求：文件/行号/摘要/读取日期、代码事实 vs 注释 vs 推断、来源标注、行为规格提取、拒绝沿用清单、风险清单）。
2. 创建 `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`：路线=私有 MultitouchSupport 窄例外（用户已接受）；独立实现来源边界；识别会话/设备隔离/锁序/输入交接/默认开关（fourFingerActivationEnabled=false 直到验证/获批）/私有实现排除方式（编译排除 vs 运行时禁用区分）；分发未评估。
3. 风险清单文档（用户确认后才运行采集实验）：私有 ABI 布局无公开文档、触点状态分类（state!=0 未区分 hover/开始/结束/取消）、零触点帧被丢弃、设备混流（回调无 device 参数）、锁序与生命周期（deinit dlclose 并发）、Input Monitoring 权限（设备枚举成功≠权限授予）、系统更新兼容性。

## Expected / Allowed Write Scope
- `Docs/FOUR_FINGER_REFERENCE_AUDIT.md`（复核/补全）
- `Docs/ADR-013-*.md`（新建）
- 风险清单文档（可并入 ADR-013 或独立）
- PROVENANCE/ 记录（REFERENCE_EXPOSED）
- 禁止：真实采集实现、任何 Sources/ 代码、复制整份参考源码、读取白名单外 LaunchBetter 文件、读取 Buho 逆向资料

## 验收
- 审计文档逐项覆盖 §17.3 要求；ADR-013 覆盖 §18 决策表与 §24 要求
- 风险清单明确"用户确认后才运行采集实验"门
- 不 commit/push/tag
