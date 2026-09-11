# Decision: Chief model glm-5.2 → glm-5.3 (ollama provider)

- **Date**: 2026-08-29
- **Requested by**: 用户（直接授权，覆盖"活动进行中不改模型"的默认约束）
- **Scope**: 仅 `Workflow/config.json` 的 `models.chief`；Worker/Reviewer/Main 模型、并发、思考深度不变
- **Decision**: `models.chief = "glm-5.3"`（来自 DSH `ollama` provider，baseURL `https://ollama.com/v1`）

## Rationale

- 用户明确要求把 Chief 模型从 `glm-5.2` 换成 Ollama Provider 里的 `glm-5.3`。
- `~/.dsh/settings.yaml` 的 `llm-pi-ai.providers.ollama.models` 已包含 `glm-5.3`（reasoningEfforts low/medium/high/max），provider 侧已就绪。
- 本变更只影响 Chief 的规划/决策模型，不改变 Chief 的角色契约、思考深度（仍 max）或语义依赖 DAG。

## Effects

- 后续 Chief 规划/决策调用使用 `glm-5.3`（ollama provider）。
- 已在进行中的 Phase 1C Chief 规划（subagent `f29b9ba8`）按原 `glm-5.2` 完成；本变更自下一个 Chief 调用起生效。
- 若上游实际路由与声明不一致，以可观测路由为准（声明身份 ≠ 最终路由证明）。
