# Task: T-worker-b-thresh43 — 阈值调参轮 0.45/0.38 → 0.43/0.36

- **Task ID**: T-worker-b-thresh43
- **Role**: Worker (PagingCore parameter tuning)
- **Status**: PASSED (Main 判定)
- **Origin**: 用户真实内容全屏实测 phys1b-03 后指示「前进改成0.43，回退改成0.36」（Phase 1B 调参轮，decision_recorded 2026-08-28T23:5x+09:00）
- **Write scope**: `Sources/PagingCore/PagingParameters.swift`、`Tests/PagingCoreTests/`、`Sources/PagingCore/PageTargetPolicy.swift`（注释同步）、`Workflow/results/T-worker-b-thresh43.md`
- **Forbidden**: Package.swift、其他 Sources/、其他 Tests/、Docs/、Workflow/STATE.json、Workflow/events.jsonl（Main 独占）

## 改动
- `displacementThreshold`: 0.45 → **0.43**
- `retreatDisplacementFactor`: 38.0/45.0 → **36.0/43.0**（0.43×36/43 = 0.36 页精确）
- 冻结参数未动：momentumDecay 0.55、momentumGlideFrames 1、momentumMaxOvershoot 0.20
- `PageTargetPolicy.swift` L64-67 注释同步 36/43 语义，零代码改动

## 验证（Main 独立复验）
- `swift test` 全量：**414 tests, 0 failures**
- `swift build -c release`：exit 0，0 warnings
- 边界证据（worker 实测）：前进 420px→bounce / 430px→advance；回退 −350px→bounce / −360px→retreat；混合路径 0.4263<0.43→bounce、0.3563<0.36→bounce、−360px@200px/s→位移分支 retreat
- 1-ulp：零偏移（0.43×36/43==0.36、430/1000>=0.43、360/1000==0.36 均精确，Main 预验证 + worker 独立复核一致）

## 结果文件
`Workflow/results/T-worker-b-thresh43.md`（worker-pagingcore2，NO_PRIOR_EXPOSURE 声明，未自我认证 PASS）
