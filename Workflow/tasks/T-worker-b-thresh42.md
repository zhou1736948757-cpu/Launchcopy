# Task: T-worker-b-thresh42 — 阈值 0.43/0.36 → 0.42/0.35

- **Task ID**: T-worker-b-thresh42
- **Role**: Worker (PagingCore)
- **Status**: PASSED (Main 判定)
- **Origin**: 用户指示「前进阈值改成0.42，回退系数改成0.35」（2026-08-29 decision_recorded；理解=回退阈值 0.35 → factor 35/42）
- **Write scope**: `Sources/PagingCore/PagingParameters.swift`、`Sources/PagingCore/PageTargetPolicy.swift`（注释）、`Tests/PagingCoreTests/PagingCoreTests.swift`、`Workflow/results/T-worker-b-thresh42.md`
- **Forbidden**: Package.swift、PagingUI/、PagingPrototypeApp/（用户已自行重构帧驱动，零接触）、其他 Sources/、其他 Tests/、Docs/、Workflow/STATE.json、Workflow/events.jsonl（Main 独占）

## 改动
- `displacementThreshold` 0.43 → 0.42
- `retreatDisplacementFactor` 36.0/43.0 → 35.0/42.0（0.42×35/42 = 0.35 页精确）
- PageTargetPolicy 注释同步（35/42 ≈ 0.833333 → 前进 0.42 / 回退 0.35），零代码改动
- 冻结参数（momentumDecay 0.55、glideFrames 1、maxOvershoot 0.20）原值在位

## 验证（Main 独立复验）
- `swift test` 全量：**462 tests, 0 failures**（基线 462/0，net 0）
- `swift build -c release`：exit 0，0 warnings
- 边界（velocityContribution=0 隔离）：前进 410px→bounce / 420px→advance；回退 −340px→bounce / −350px→retreat
- 混合路径：0.4163<0.42→bounce；0.3463<0.35→bounce；−350px@200px/s→位移分支 retreat
- 1-ulp：零偏移（0.42×35/42==0.35、420/1000>=0.42、350/1000==0.35 精确）

## 结果文件
`Workflow/results/T-worker-b-thresh42.md`（worker-pagingcore2，NO_PRIOR_EXPOSURE 声明，未自我认证 PASS）
