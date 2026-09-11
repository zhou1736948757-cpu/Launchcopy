# T-G-P7 — 四指轨收口（修复挂账 + 收口文档 + 清理）

## Objective
四指轨收口：修复 T-G-P6-r2 评审 MINOR-1（refreshAggregateState）；同步 MINOR-2 文档契约文字（Prompt §19.2 + ADR-013）；建 §24 收口文档（SPEC/VALIDATION/RESULTS/CHECKPOINT/ARTIFACTS.sha256）；执行删除义务（临时采集文件与工具）；汇总挂账（M01-M12/能耗 A/B 依赖 T-1G-E 集成）。

## Expected / Allowed Write Scope
- `Sources/PagingPrototypeApp/PinchRecognizer.swift`（仅 MINOR-1 一行修复）
- `Tests/PagingUITests/PinchRecognizerTests.swift`（仅回归用例）
- `Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`（§19.2 合同文字同步）
- `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`（合同同步 + 修订记录）
- `Docs/PHASE1G_CHECKPOINT.md`、`Docs/FOUR_FINGER_ACTIVATION_SPEC.md`、`Docs/FOUR_FINGER_ACTIVATION_VALIDATION.md`、`Docs/FOUR_FINGER_ACTIVATION_RESULTS.md`、`Docs/ARTIFACTS.sha256`
- `Workflow/results/T-G-P6.md`（§R-08）、`Workflow/reviews/T-G-P7-r1.md`、`Workflow/STATE.json`、`Workflow/events.jsonl`
- 删除：/tmp/fourfinger-capture-*.jsonl（4 份）、/tmp/pinch-replay3、/tmp/fourfinger-capture-tool、/tmp/fourfinger-rawdiag、/tmp/rawdiag-out.log（保留为证据则移入仓库）

## Forbidden
- 冻结树（Sources/PagingCore、PagingTelemetry、PagingUI、AppCatalogCore、MacAppCatalog、AppIconPipeline、AppGridUI 全部、Package.swift、AppLaunchController.swift）
- AppDelegate/AppMain/AppArguments；T-1G-B/C/D/E 行为代码；真实四指后端改动
- commit/push/tag

## 状态
- MINOR-1 修复：Worker 05e22654 完成（filter 49/0、全量 1412/0）
- T-G-P7-r1 评审：Reviewer fc051d0f PASS（0B/0M/0MINOR/0Q/5INFO）
- 文档：CHECKPOINT/SPEC/VALIDATION 已建；RESULTS/ARTIFACTS.sha256 待建
- 删除义务：待执行
