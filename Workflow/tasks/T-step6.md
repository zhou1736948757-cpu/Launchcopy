# Task Packet: T-step6

- **Task ID**: T-step6
- **Role**: Worker D (continuing from T-worker-d)
- **Step**: 6 (Prompt §6 Step 6)


## Objective

性能实验——先测 live views baseline，如果未达标再实现或实验轻量页面合成路径；保留全部 baseline 和改动前后数据

## Dependencies

- **T-worker-d**（需要 UI 完成且可运行）
- **T-worker-c**（需要 Telemetry 模块可用以收集性能数据）

## Context

Prompt §6 Step 6 要求先测 live views（ADR-002 方案 1），通过 telemetry 判断是否需要方案 2（轻量 compositor）。不能未经测量就假定复杂 compositor 一定更快。

此任务由 Worker D 继续执行（同一角色，同一写入范围），因为性能优化涉及 PagingUI 的页面承载实现。

## Scope

### 性能 baseline 测量
- 使用 Telemetry（T-worker-c 产出）收集 live views 模式下的性能数据
- 测量指标（Prompt §7.4）：
  - 纯 Core 处理开销
  - 单帧 update 的 CPU 时间
  - 页面 view 数量
  - layout 调用次数
  - 预热与缓存
  - 长序列内存增长
  - stale completion 是否为零提交
- 在不同页面预设下测量（1/2/5/10/20 页）
- 记录 baseline 数据

### 性能优化实验（如果 baseline 未达标）
- 如 telemetry 显示 live views 不满足初始性能目标（Prompt §8.5）：
  - 实现或实验方案 2（轻量 compositor / 预渲染页面视觉）
  - 可构建可切换 A/B（--page-hosting live vs --page-hosting composited）
- 每个优化保留：
  - 优化前的假设
  - 改动前后数据
  - 是否改善
  - 是否引入正确性问题
  - 最终保留或回退理由

### 禁止为了得到好看的数字删除异常 run

## Out of Scope

- 修改 PagingCore 或 PagingTelemetry 的内部实现
- 修改 Package.swift（报告给 Main 整合；如需新增 --page-hosting composited 参数支持，由 Main 整合 Package.swift 后 Worker 再使用）
- 物理触控板验收（属于 T-step8，等待用户）
- 自动化性能测试替代真实触控板

## Expected / Allowed Write Scope

- `Sources/PagingUI/`
- `Sources/PagingPrototypeApp/`
- `Tests/PagingUITests/`


## Forbidden Write Scope

**禁止写入**：
- `Sources/PagingCore/`、`Sources/PagingTelemetry/`
- `Package.swift`
- `Docs/`、`PROVENANCE/`

## Constraints

- 自动化性能测试只能作为回归预警，不能替代真实触控板（Prompt §7.4）
- 禁止为了得到好看的数字删除异常 run
- 每个优化保留假设、改动前后数据、是否改善、是否引入正确性问题、保留或回退理由
- 不从旧项目搬运性能优化策略或精确参数
- 参数来源类别禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN
- 如果实现 compositor 方案，须更新 ADR-002（报告给 Main，由 Main 修改 Docs/）
- 不回滚他人改动
- 不修改 Package.swift

## Acceptance Criteria

- [ ] live views baseline 数据已收集（不同页面预设下的性能指标）
- [ ] baseline 数据记录在 Worker Result 中（或 Docs/IMPLEMENTATION_LOG.md，由 Main 补充到 Docs）
- [ ] 如果 baseline 未达标：
  - [ ] 优化假设已记录
  - [ ] 改动前后数据已记录
  - [ ] 是否改善已判断
  - [ ] 是否引入正确性问题已验证
  - [ ] 保留或回退理由已记录
- [ ] 如果实现 compositor 方案：
  - [ ] `--page-hosting composited` 参数可用
  - [ ] A/B 可切换
  - [ ] 正确性测试在两种模式下均通过
- [ ] 异常 run 未被删除
- [ ] stale completion 在性能测试中为零提交

## Required Verification

- Telemetry 数据文件存在且包含性能指标
- baseline 和优化后数据可比较
- 正确性测试在性能优化后仍全部通过
- 无异常 run 被删除（检查 telemetry 日志完整性）

## Reviewer Focus

- baseline 数据是否真实（未被选择性删除）
- 优化是否有假设和数据支撑
- 性能优化是否引入正确性问题
- compositor 方案（如有）是否未经测量就假定更快
- 异常 run 是否被保留
- 自动化性能测试是否被不当替代为物理门

## Deliverables

- 性能 baseline 数据（记录在 Worker Result 或由 Main 转录到 Docs）
- 优化实验记录（如有）
- Sources/PagingUI/ 修改（如有优化）
- Tests/PagingUITests/ 新增性能边界测试（如有）
- Workflow/results/T-step6.md（Worker Result）