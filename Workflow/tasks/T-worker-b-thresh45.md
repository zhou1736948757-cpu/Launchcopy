# Task: T-worker-b-thresh45 — 阈值调参轮 0.46/0.40 → 0.45/0.38

- **Task ID**: T-worker-b-thresh45
- **Role**: Worker (PagingCore parameter tuning)
- **Status**: PASSED (Main 判定)
- **Origin**: 用户真实内容全屏物理实测后指示「把前进改成45，回退改成38」（Phase 1B 调参轮，decision_recorded 2026-08-28T23:23:23+09:00）
- **Write scope**: `Sources/PagingCore/PagingParameters.swift`、`Tests/PagingCoreTests/`、`Workflow/results/T-worker-b-thresh45.md`、`Sources/PagingCore/PageTargetPolicy.swift`（注释清理，t16 后续）
- **Forbidden**: Package.swift、其他 Sources/、其他 Tests/、Docs/、Workflow/STATE.json、Workflow/events.jsonl（Main 独占）

## 改动
- `displacementThreshold`: 0.46 → **0.45**
- `retreatDisplacementFactor`: 20.0/23.0 → **38.0/45.0**（0.45×38/45 = 0.38 页精确）
- 冻结参数未动：momentumDecay 0.55、momentumGlideFrames 1、momentumMaxOvershoot 0.20
- `PageTargetPolicy.swift` L64-67 陈旧注释（0.875 → 0.42 页 / 前进 0.48 / 回退 0.42）更新为 0.45/0.38 语义，零代码改动

## 验证（Main 独立复验）
- `swift test` 全量：**414 tests, 0 failures**（Main 复验 8.883s）
- `swift build -c release`：exit 0，0 warnings
- 边界证据（worker 实测）：前进 440px→bounce / 450px→advance；回退 −370px→bounce / −380px→retreat；混合路径 0.4463<0.45→bounce、0.3763<0.38→bounce、−380px@200px/s→位移分支 retreat
- 1-ulp：零偏移（450/1000==0.45、0.45×38/45==0.38、380/1000==0.38 均精确）

## 结果文件
`Workflow/results/T-worker-b-thresh45.md`（worker-pagingcore2，NO_PRIOR_EXPOSURE 声明，未自我认证 PASS）
