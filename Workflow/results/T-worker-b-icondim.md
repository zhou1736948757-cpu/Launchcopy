# T-worker-b-icondim — 图标尺寸上限 256×256（Phase 1B 后续优化）

**Worker**: worker-icondim（deepseek-v4-flash:0731, max）
**任务**: t19（图标尺寸上限 256×256：加载后统一缩略，缓存 cost 自动下降）
**日期**: 2026-08-29
**用户指示**: "图标尺寸最大256*256"（修正版，最大 256×256）
**Scope（互斥）**: `Sources/AppIconPipeline/`（仅 IconPipeline.swift）、`Tests/AppIconPipelineTests/`（新增 IconPipelineCapTests.swift）、`Workflow/results/T-worker-b-icondim.md`
**未触碰**: Package.swift / 其他 Sources/ / 其他 Tests/ / Docs/ / PROVENANCE / Workflow/STATE.json / Workflow/events.jsonl 等一切其他文件（Main 独占）；未运行 record_workflow_event.py
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取任何治理文档 / §2.2 禁止来源 / 其他项目；仅依据 Main 任务指令与本仓库既有源码）

---

## 一、改动摘要

| 文件 | 改动 |
|---|---|
| `Sources/AppIconPipeline/IconPipeline.swift` | ① `performLoad` 在 loader 返回后、**写回缓存前**统一调用 `cappedImage`，缓存插入与 consumer 投递均用缩略后图像；② 新增 `static let maxIconPixelDimension = 256`（内部常量）；③ 新增 `static func cappedImage(_:maxDimension:)`：最大 rep 任一边 > 256px 时，取最大 rep 等比绘制到 ≤256×256 的新 `NSBitmapImageRep`（纯内存），返回含单 rep 的新 `NSImage`；≤256 原样返回同一实例；④ 私有辅助 `largestPixelSize(of:)`（多 rep 取面积最大；无 rep 回退 image.size）与 `largestRepresentation(of:)`（缩略绘制源）；⑤ 文件头设计要点补一行缩略不变量 |
| `Tests/AppIconPipelineTests/IconPipelineCapTests.swift` | 新增 5 个测试（见下） |

**公开面零改动**：协议/结构体/方法签名全部不变；新增符号均为 internal（`@testable` 可见），不破坏其他模块编译。

## 二、实现位置与理由

**位置**：`IconPipeline.performLoad`（写回缓存前统一处理），而非 `SystemIconLoader` 内。

理由：
1. **统一保证**：上限约束落在管道唯一咽喉点——无论 loader 实现（真实 NSWorkspace / 未来注入的 resolver loader / 测试 fake loader）返回多大图像，写回缓存与投递 consumer 的图像一律 ≤256×256；若放在 loader 内，fake/第三方 loader 可绕过约束。
2. **缓存 cost 自动下降**：`estimatedCost` 按最大 rep 计（w×h×4），缩略后单 rep 256×256 → cost=262144（原 1024×1024 为 4MB），64MB 缓存从 ~16 张提升到 ~256 张，无需改 cost 逻辑。
3. **cache hit 路径天然一致**：命中返回的即插入时的缩略图，无二次处理。
4. **隐私红线**：纯内存 `NSBitmapImageRep` 绘制；不读真实字节、不哈希、不写磁盘、不复制进资源；不触碰 IconKey/IconIdentity 结构。

## 三、测试证据（新增 5 个，全部程序生成图像 + fake loader，零文件系统/零真实资源）

| 测试 | 边界断言 |
|---|---|
| `testLargeIconCappedTo256` | fake loader 返回 1024×1024 → 写回/加载结果最大 rep = **256×256**（≤ 上限）；缓存命中返回**同一缩略图实例**（`===`）且不重载（loadCount=1） |
| `testSmallIconUnchanged` | 128×128 → **原样不变**：投递图像与 loader 图像同一实例（`===`），最大 rep 128×128 |
| `testAspectRatioPreserved` | 1024×512 → **256×128**；512×1024 → **128×256**（等比，宽高比保持） |
| `testCacheCostReflectsCappedSize` | maxCost=600_000：2 个 1024×1024 源图（未缩略 4MB×2 必驱逐）→ 缩略后 2×262144=524288 ≤ 600000 → **0 驱逐 + 双命中**（loadCount=2，cacheHits=2）——直接证明缓存 cost 按新尺寸计 |
| `testHelperCapsNonSquareBelowLimit` | 直接辅助边界：300×200（仅宽超限）→ **256×171**（等比，高不超限） |

## 四、验证结果

| 项 | 结果 |
|---|---|
| `swift build --target AppIconPipeline` | ✅ exit 0，0 warning |
| `swift test --filter AppIconPipelineTests` | ✅ **28 tests 全绿**（既有 23 + 新增 5，0 failures） |
| `swift test`（全量） | ✅ **419 tests，0 failures**（基线 414 + 新增 5） |
| `swift build -c release` | ✅ exit 0，**0 warnings**（Build complete） |

## 五、隐私确认

- 缩略为纯内存位图绘制（`NSGraphicsContext(bitmapImageRep:)`），不读真实字节、不哈希、不写磁盘、不复制进资源/fixture/发布包；
- 不改变 IconKey/IconIdentity 结构；stats 仍仅计数，无字节/哈希/路径；
- 测试仅用程序生成色块图像 + fake loader，绝不触碰真实 /Applications。

## 六、给 Main 的收口提示

1. 本任务不自我认证 PASS；请 Reviewer 独立核对 diff 与证据；
2. 若后续 UI 需要按上限预知尺寸（如 cell 布局），可把 `maxIconPixelDimension` 提升为 public——当前按"公开面零改动"保持 internal；
3. 建议全量验证纳入 `swift test --filter AppIconPipelineTests`（28 用例）。
