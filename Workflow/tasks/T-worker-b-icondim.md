# Task: T-worker-b-icondim — 图标尺寸上限 256×256

- **Task ID**: T-worker-b-icondim
- **Role**: Worker (AppIconPipeline)
- **Status**: PASSED (Main 判定)
- **Origin**: 用户指示「图标尺寸最大256*256」（修正版，最大非最小；2026-08-29 decision_recorded）
- **Write scope**: `Sources/AppIconPipeline/IconPipeline.swift`、`Tests/AppIconPipelineTests/IconPipelineCapTests.swift`、`Workflow/results/T-worker-b-icondim.md`
- **Forbidden**: Package.swift、其他 Sources/、其他 Tests/、Docs/、Workflow/STATE.json、Workflow/events.jsonl（Main 独占）

## 改动
- `IconPipeline.performLoad` 写回缓存前统一 `cappedImage`：最大 rep 任一边 >256 时纯内存等比缩略（NSBitmapImageRep），≤256 原样透传同一实例
- `maxIconPixelDimension = 256`；缓存 cost 由 estimatedCost 按缩略后最大 rep 自动计（1024²→256²，4MB→256KB）
- 公开 API 零改动；隐私纯内存（不读字节/不哈希/不写盘）

## 验证（Main 独立复验）
- `swift test` 全量：**419 tests, 0 failures**（414 + 5 新增）
- `swift build -c release`：exit 0，0 warnings
- 测试证据：1024×1024→256×256；128×128 原样（同一实例）；1024×512→256×128 等比；maxCost 下 2 个 1024 源图 0 驱逐+双命中；300×200→256×171

## 结果文件
`Workflow/results/T-worker-b-icondim.md`（worker-icondim，NO_PRIOR_EXPOSURE 声明，未自我认证 PASS）
