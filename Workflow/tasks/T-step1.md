# Task Packet: T-step1

- **Task ID**: T-step1
- **Role**: Main
- **Step**: 1 (Prompt §6 Step 1)


## Objective

编写规格文档、架构决策记录、参数说明和验证计划；创建 Package.swift 初始骨架

## Dependencies

- **T-step0**（需要 provenance 骨架和工具链记录）
- **T-explorer**（需要 Explorer A 的状态模型分析作为 ADR-001 输入）

## Context

Prompt §6 Step 1 要求在 ADR 被自查通过前，不进入完整 UI 实现。Main 负责编写全部规格文档和 ADR。Package.swift 由 Main 独占创建。

## Scope

### 文档（写入 Docs/）
1. **PHASE1_SPEC.md**：Phase 1A 规格
   - 工程目标和成功定义
   - 测试页面规格（中性视觉、占位 item、可配置 page/item 数量、预设 1/2/5/10/20 页）
   - 默认负载说明（每页约 35 item，标记为本项目测试负载选择，非旧产品复制的不可变常量）
   - 命令行参数规格（Prompt §10 全部参数）
   - 模块边界说明

2. **ADR-001-PAGING-STATE-MODEL.md**：状态模型架构决策
   - 状态语义定义（idle/tracking/settling/interrupted/cancelled 或等效命名）
   - 状态所有权（谁拥有当前语义页、当前视觉偏移、gesture session）
   - settle 动画识别和取消机制
   - 旧回调提交资格确认机制（transition identity/context）
   - resize/pageCount change 处理策略
   - teardown 无残留保证
   - 被否决方案及理由
   - 设计者是否看过 LaunchBetter/BuhoRebuild（如实记录）
   - 与旧项目结构相似处及独立理由

3. **ADR-002-PAGE-HOSTING.md**：页面承载方案决策
   - 方案 1：live AppKit view 层级
   - 方案 2：轻量 compositor / 预渲染
   - 选择理由（先 live，telemetry 驱动后续决策）
   - 手势热路径约束
   - 内存/view 上界策略
   - 被否决方案及理由

4. **PARAMETER_RATIONALE.md**：参数说明
   - 表格格式：参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果 | 修改日期
   - 来源类别只允许：PRODUCT_DECISION / PLATFORM_REQUIREMENT / ACCESSIBILITY_REQUIREMENT / INDEPENDENT_EXPERIMENT / PUBLIC_DOCUMENTATION
   - 建议至少参数化：input sensitivity / boundary resistance / displacement threshold / velocity contribution / settle duration 或 spring 参数 / maximum overscroll / live page radius / prewarm distance / Reduce Motion 行为
   - 无法解释的参数标 TUNING_REQUIRED，使用明显实验值

5. **VALIDATION_PLAN.md**：验证计划
   - 自动化测试范围（Prompt §7.1–7.4）
   - 物理验收矩阵（Prompt §8.2–8.3）
   - 环境证据清单（Prompt §8.1）
   - 性能目标（Prompt §8.5）
   - 主观评分模板（Prompt §8.6）
   - VALIDATION_RESULTS.md 状态分类说明（Prompt §13）

### Package.swift（写入项目根）
- SwiftPM executable target
- 声明全部 target：PagingCore（library）、PagingTelemetry（library）、PagingUI（library）、PagingPrototypeApp（executable）
- 声明全部 test target：PagingCoreTests、PagingTelemetryTests、PagingUITests
- macOS 14+ 部署目标
- 不依赖旧项目绝对路径

## Out of Scope

- 写产品代码（Sources/ 下任何 Swift 文件）
- 写测试代码（Tests/ 下任何 Swift 文件）
- 实现 Telemetry（属于 T-worker-c）
- 执行构建（属于 T-step7）

## Expected / Allowed Write Scope

- `Docs/PHASE1_SPEC.md`
- `Docs/ADR-001-PAGING-STATE-MODEL.md`
- `Docs/ADR-002-PAGE-HOSTING.md`
- `Docs/PARAMETER_RATIONALE.md`
- `Docs/VALIDATION_PLAN.md`
- `Package.swift`
- `README.md`（更新，补充构建/运行说明）

## Constraints

- ADR 必须比较至少两个候选方案并记录被否决方案
- 参数来源类别禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN
- 不从旧项目搬运字段名、状态机映射或精确参数簇
- ADR-001 设计者是否看过旧项目须如实记录
- Package.swift 不依赖旧项目路径
- 不自动 commit/push

## Acceptance Criteria

- [ ] PHASE1_SPEC.md 包含工程目标、测试页面规格、命令行参数规格、模块边界
- [ ] ADR-001 包含状态语义、所有权、settle 取消机制、旧回调资格确认、resize/pageCount/teardown 处理、被否决方案、设计者接触声明
- [ ] ADR-002 包含两种方案比较、选择理由、热路径约束、内存上界策略、被否决方案
- [ ] PARAMETER_RATIONALE.md 包含全部建议参数，每个有来源类别（合规类别），无法解释的标 TUNING_REQUIRED
- [ ] VALIDATION_PLAN.md 包含自动化测试范围、物理验收矩阵、环境证据清单、性能目标、主观评分模板
- [ ] Package.swift 声明全部 4 个 source target 和 3 个 test target，macOS 14+，不依赖旧路径
- [ ] ADR 被自查通过（状态模型回答了 Prompt §3.G 全部 7 个问题）

## Required Verification

- ADR-001 自查：确认回答了"当前语义页由谁拥有 / 当前视觉偏移由谁拥有 / 一个手势 session 如何开始和结束 / settle 动画如何被识别和取消 / 旧回调如何确认自己仍有提交资格 / resize/pageCount change 如何处理 / teardown 如何保证无残留 display callback"
- Package.swift `swift package describe` 或等效命令验证结构正确
- PARAMETER_RATIONALE.md 来源类别合规检查

## Reviewer Focus

- ADR-001 是否完整回答 Prompt §3.G 全部 7 个问题
- 参数来源类别是否全部合规
- ADR 是否把实现手段包装成了产品需求
- Package.swift 是否不依赖旧项目路径
- 设计者接触声明是否如实

## Deliverables

- Docs/PHASE1_SPEC.md
- Docs/ADR-001-PAGING-STATE-MODEL.md
- Docs/ADR-002-PAGE-HOSTING.md
- Docs/PARAMETER_RATIONALE.md
- Docs/VALIDATION_PLAN.md
- Package.swift
- README.md (updated)