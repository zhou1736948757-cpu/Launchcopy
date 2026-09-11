# Task Packet: T-step7

- **Task ID**: T-step7
- **Role**: Main
- **Step**: 7 (Prompt §6 Step 7)


## Objective

从不依赖旧 .build 的状态执行清洁构建（Debug + Release）、单元测试、集成测试、静态来源预警扫描、git diff check，并记录命令、退出码、工具链和产物 hash

## Dependencies

- **T-step6**（全部 worker 代码和性能实验完成）

## Context

Prompt §6 Step 7 要求清洁构建和自动化验证。Main 负责整合 Package.swift（如需更新 target/依赖）、执行构建和测试、执行来源扫描。这是自动化验收的最终步骤，物理门在 T-step8。

## Scope

### 清洁构建
- 从不依赖旧 .build 的状态执行（删除 .build 或使用全新检出）
- Debug build
- Release build
- 记录命令、退出码、工具链版本、产物 hash

### 自动化测试
- 单元测试（PagingCoreTests + PagingTelemetryTests）
- 集成/UI 测试（PagingUITests）
- 记录命令、退出码、executed/passed/failed 数量
- `exit_code == 0` 且 `executed_tests == 0` 为 INVALID_TEST_EXECUTION

### 静态来源预警扫描（Prompt §11.3）
扫描以下内容是否含已知泄漏模式：
- 源码
- 测试
- 文档
- 资源
- Info.plist
- Git history
- 构建产物 strings
- 绝对路径

扫描可以发现已知泄漏，但不能被描述为原创性或法律证明。

### git diff check
- `git diff --check` 执行并记录

### Package.swift 整合
- 如 Worker 需要新增 target/依赖，Main 在此步骤整合 Package.swift
- 确保 Package.swift 声明全部 target 且不依赖旧项目路径

### 记录
- 构建命令、退出码、工具链、产物 hash 记录到 Docs/IMPLEMENTATION_LOG.md
- 来源扫描结果记录
- git diff check 结果记录

## Out of Scope

- 物理触控板验收（属于 T-step8）
- 修改产品代码（如发现 bug，路由给对应 Worker 修复）
- 修改旧项目
- 自动 commit/push

## Expected / Allowed Write Scope

- `Package.swift`（整合更新，如需）
- `Docs/IMPLEMENTATION_LOG.md`（构建和验证记录）
- `Docs/VALIDATION_RESULTS.md`（初始，状态记录）
- `Workflow/results/T-step7.md`（验证结果）

## Constraints

- 清洁构建不依赖旧 .build
- 来源扫描结果明确写明"仅是泄漏预警，不是原创性证明"
- 验收状态必须分开记录（BUILD_DEBUG / BUILD_RELEASE / AUTOMATED_TESTS 等）
- 未执行项写 NOT_RUN，不写 PASS
- 不自动 commit/push
- 不修改旧项目

## Acceptance Criteria

- [ ] Debug build 成功，命令和退出码已记录
- [ ] Release build 成功，命令和退出码已记录
- [ ] 单元测试全部通过，executed/passed/failed 数量已记录
- [ ] 集成/UI 测试全部通过，executed/passed/failed 数量已记录
- [ ] 来源扫描完成（源码/测试/文档/资源/Info.plist/Git/构建产物/绝对路径），结果已记录
- [ ] `git diff --check` 已执行并记录
- [ ] 工具链版本和产物 hash 已记录
- [ ] VALIDATION_RESULTS.md 初始状态已写入（BUILD_DEBUG=PASS/FAIL, BUILD_RELEASE=PASS/FAIL, AUTOMATED_TESTS=PASS/FAIL, 其余=NOT_RUN）
- [ ] 来源扫描结果标注"仅是泄漏预警，不是原创性证明"

## Required Verification

- `swift build -c debug` 退出码 == 0
- `swift build -c release` 退出码 == 0
- `swift test` 退出码 == 0 且 executed_tests > 0
- 来源扫描无已知泄漏模式命中（或有命中已记录处理）
- `git diff --check` 无错误

## Reviewer Focus

- 构建是否确实从清洁状态执行（不依赖旧 .build）
- 测试数量是否合理（非零）
- 来源扫描是否覆盖全部 8 类内容
- VALIDATION_RESULTS.md 状态是否分开记录
- 是否有未执行的 gate 被标为 PASS

## Deliverables

- Docs/IMPLEMENTATION_LOG.md（Step 7 记录）
- Docs/VALIDATION_RESULTS.md（初始状态）
- Workflow/results/T-step7.md（验证结果汇总）