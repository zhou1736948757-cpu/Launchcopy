# Task Packet: setup

- **Task ID**: setup
- **Role**: Main
- **Status**: COMPLETED


## Dependencies

无（已完成的历史任务，仅存档）

## Scope

初始化 Workflow 骨架、项目契约与 Watchdog；记录环境事实。

## Required Verification

config.json / STATE.json / watchdog 状态核对。

## Acceptance Criteria

- [x] `Workflow/config.json` 含四角色模型声明与思考深度（Main=current-main-conversation/max, Chief=ollama glm-5.2/max, Worker=ollama deepseek-v4-flash:0731/max, Reviewer=ollama glm-5.3-flash:cloud/max）
- [x] `AGENTS.md` 与 `MEMORY.md` 已创建（本目录原先不存在，无需 merge 决策）
- [x] `Workflow/STATE.json` `subagent_mode=ENABLED`（用户选择），`workflow_status=READY`
- [x] 可见 Watchdog 已启动（pid 77071，interval 600s / stale 600s）
- [x] `Workflow/PLAN.md` / `MAIN_BRIEF.md` 骨架待 Chief 填充

## Notes

- 用户确认 Subagent 模式启用；并发上限 2。
- 用户指定的 Reviewer 模型 `glm5.3 Flash` 经查证为 Ollama 新发布模型，已在 `~/.dsh/settings.yaml` ollama provider 增加路由 `glm-5.3-flash:cloud`（reasoningEfforts low/medium/high/max）。
- 治理文档读取范围：Main/Chief 可读 Launch_Copy 三份治理文档；实现 Worker 只接收本 Prompt + Apple 公开文档 + 新工程自身文件。
## Objective

初始化 chef-worker-reviewer-workflow v1.4 项目契约与可见工作流骨架。
