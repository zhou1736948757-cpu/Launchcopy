# Task Packet: T-step0

- **Task ID**: T-step0
- **Role**: Main
- **Step**: 0 (Prompt §6 Step 0)


## Objective

环境检查、PROVENANCE 骨架建立、参与者访问声明、初始目录状态记录

## Dependencies

无（起始任务）

## Context

Phase 1A 第一步。在写任何产品代码前，必须建立来源记录和环境基线。Prompt §17 要求主控代理先完成环境检查和 provenance，再进入规格和 ADR。

## Scope

- 检查 `xcodebuild -version`、`swift --version`、macOS 版本并记录
- 检查 `/Users/mac/Projects/Launch_Copy/PagingPrototype/` 现有内容和 Git 状态（不覆盖无法确认来源的文件；不执行 `git reset`/`git clean`/删除用户文件）
- 创建 `PROVENANCE/ACCESS_DECLARATION.md`：为每位参与者如实声明 `NO_PRIOR_EXPOSURE` 或 `PRIOR_EXPOSURE`，禁止统一代签
- 创建 `PROVENANCE/COMPONENTS.md`：组件清单骨架（PagingCore/PagingTelemetry/PagingUI/PagingPrototypeApp）
- 创建 `PROVENANCE/CONTAMINATION_LOG.md`：空骨架（记录格式说明 + 表头）
- 创建 `Docs/IMPLEMENTATION_LOG.md`：初始记录（目录状态、工具链版本、Step 0 完成内容）
- 确认 fresh implementation worker 未读取禁止来源且不继承旧逆向上下文

## Out of Scope

- 写产品代码（Sources/ 下任何文件）
- 写 Package.swift
- 写规格文档或 ADR（属于 T-step1）
- 修改 LaunchBetter 或 BuhoReverseNotes
- 自动 commit/push

## Expected / Allowed Write Scope

- `PROVENANCE/ACCESS_DECLARATION.md`
- `PROVENANCE/COMPONENTS.md`
- `PROVENANCE/CONTAMINATION_LOG.md`
- `Docs/IMPLEMENTATION_LOG.md`
- `README.md`（初始骨架，仅工程描述）

## Constraints

- 不读 Prompt §1.3 列出的任何路径
- 不复制旧代码
- 参与者访问声明如实填写，禁止统一代签
- fresh implementation worker 使用不继承旧逆向上下文的模式
- 不自动 commit/push/tag/release

## Acceptance Criteria

- [ ] `xcodebuild -version`、`swift --version`、macOS 版本已记录到 IMPLEMENTATION_LOG.md
- [ ] `/Users/mac/Projects/Launch_Copy/PagingPrototype/` 目录状态和 Git 状态已记录
- [ ] `PROVENANCE/ACCESS_DECLARATION.md` 存在，含每位参与者的 NO_PRIOR_EXPOSURE 或 PRIOR_EXPOSURE 声明
- [ ] `PROVENANCE/COMPONENTS.md` 存在，列出四个模块骨架
- [ ] `PROVENANCE/CONTAMINATION_LOG.md` 存在，含记录格式说明
- [ ] `Docs/IMPLEMENTATION_LOG.md` 存在，含 Step 0 完成记录
- [ ] 无禁止来源读取记录

## Required Verification

- 工具链命令输出已记录（命令 + 退出码 + 版本字符串）
- 目录状态记录（find 输出摘要 + Git status）
- 访问声明完整性检查（每位参与者都有声明）

## Reviewer Focus

- 访问声明是否如实（是否有统一代签迹象）
- 目录状态记录是否准确
- 是否有意外接触禁止来源的迹象

## Deliverables

- PROVENANCE/ACCESS_DECLARATION.md
- PROVENANCE/COMPONENTS.md
- PROVENANCE/CONTAMINATION_LOG.md
- Docs/IMPLEMENTATION_LOG.md (Step 0 entry)
- README.md (initial scaffold)