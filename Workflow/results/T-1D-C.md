# Worker Result — T-1D-C（PagingUI 窄同 revision 重载 seam）

- **Task**: T-1D-C
- **Role**: Worker C（fresh context，不继承含逆向材料的旧会话上下文）
- **Status**: DONE（实现 + 测试 + 构建 + PagingCore 未变验证通过；待独立 Reviewer 门禁）
- **Date**: 2026-08-30

## 摘要

在 `PagingSurface`（`Sources/PagingUI/`）新增窄的**同 revision 重载 seam**
`reloadCurrentPresentation()`：以**相同 `servedRevision`** 重渲染 live hosts，但使用 provider
当前 presentation records（pageCount 可能变化）。尊重 idle/busy latest-wins、不丢失 pending
catalog revision、不让旧同 revision 重载覆盖新 catalog revision、强制重渲染使旧图标回调无法写入
新 query 的 cell、teardown 后零写回。**未触碰 `PagingCore`**（冻结），未 mint/forge
`CatalogRevision`，七字段 `ItemBindingToken` 契约保持不变。

## 交付物

| 文件 | 类型 | 说明 |
|------|------|------|
| `Sources/PagingUI/PagingSurface.swift` | 修改 | 新增窄 seam `reloadCurrentPresentation()` + `applySameRevisionReload()` + `pendingSameRevisionReload` 状态；`endInteraction()`/`teardown()` 接线 |
| `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift` | 新增 | 14 个同 revision 重载测试（§16.3 全覆盖） |
| `Workflow/results/T-1D-C.md` | 新增 | 本结果 |

## 实现要点

- **新增状态** `public private(set) var pendingSameRevisionReload = false`（§8.3）：与既有
  `pendingLatestSnapshot`（catalog revision pending）**独立**，二者在 idle/cancelled 边界按
  **catalog revision 优先**（ADR-007 §2.4）调和。
- **`reloadCurrentPresentation()`**（public seam）：
  - `guard !isTearingDown, let provider = contentProvider`；`provider.servedRevision == nil`
    （未就绪）→ 无操作（中性占位）。
  - `core.state == .idle/.cancelled` → 立即 `applySameRevisionReload()`；
  - `tracking/settling/interrupted` → 只置 `pendingSameRevisionReload = true`（latest-wins，
    幂等不堆积），idle/cancelled 边界一次应用。
- **`applySameRevisionReload()`**（private）：
  - `surfaceGeneration &+= 1`（§6.4 字段 7：surface 级 generation bump → 在途绑定作废）；
  - 若 `provider.servedPageCount != core.pageCount` → `core.setPageCount(newPageCount)`（D6
    三分支，合法 clamp，非 shrink-then-restore）+ **显式 `relayoutPages()`**（关键：pageCount
    缩小但 offset 不变时 Core 不触发 `onVisualOffsetChange`，须显式重算可见范围）；
  - `refreshLiveHostContent(revision: effectiveRevisionForPass())` 全量重渲染 live hosts
    （同 servedRevision，不改变 revision）。
- **`endInteraction()`** 接线：idle/cancelled 边界先 apply `pendingLatestSnapshot`（catalog
  revision 优先）并丢弃同 revision 重载；否则若 `pendingSameRevisionReload` → apply 并清空。
- **`teardown()`** 接线：置 `pendingSameRevisionReload = false`（teardown 后零写回）。
- **servedRevision 保持 base snapshot revision**：seam 从不写 `servedRevision`，绝不 mint/forge
  `CatalogRevision`。

## 验证

- `swift test --filter PagingSurfaceSearchReload`：**14/14 通过，0 失败**（`executed_tests = 14 > 0`）。
- `swift build -c debug`：**exit 0**（Build complete）。
- `swift build -c release`：**exit 0**（Build complete）。
- **PagingCore 未变**：`Sources/PagingCore/*.swift` 六个文件 SHA-256 与
  `Docs/PHASE1C_BASELINE_MANIFEST.sha256` 完全一致（GestureSession `0bc99894…`、
  PageTargetPolicy `530b7f23…`、PagingCore `2b4c029b…`、PagingParameters `fa2a107b…`、
  PagingState `f7e4ffa3…`、TransitionContext `268c4a46…`）。
- 无冲突标记（`<<<<<<<`/`=======`/`>>>>>>>`）、无行尾空白。

### 测试覆盖（§16.3 映射）

| §16.3 场景 | 测试 | 结果 |
|-----------|------|------|
| idle 立即 reload | `testIdleReloadAppliesImmediately` | PASS |
| servedRevision 不变（不 mint/forge） | `testReloadKeepsServedRevisionUnchanged` | PASS |
| tracking 只 pending | `testTrackingReloadOnlyPending` | PASS |
| settling 只 pending | `testSettlingReloadOnlyPending` | PASS |
| 多次 pending 只应用最新 | `testMultiplePendingReloadAppliesLatestOnce` | PASS |
| 新 catalog revision 优先于旧同 revision 重载 | `testNewCatalogRevisionOutranksOldSameRevisionReload` | PASS |
| 旧同 revision 重载不覆盖新 catalog revision | `testOldSameRevisionReloadDoesNotOverrideNewCatalogRevision` | PASS |
| pageCount 缩小 | `testReloadUpdatesPageCountShrink` | PASS |
| pageCount 0 | `testReloadUpdatesPageCountZero` | PASS |
| pageCount 1 | `testReloadUpdatesPageCountOne` | PASS |
| pageCount 多页 | `testReloadUpdatesPageCountMulti` | PASS |
| host/view 数上界不变 | `testReloadKeepsHostViewUpperBound` | PASS |
| 旧图标乱序回调零错写（generation/token gating） | `testReloadBumpsGenerationRejectingOldIconCallback` | PASS |
| teardown 后零写回 | `testReloadAfterTeardownZeroWriteback` | PASS |

## 越权检查

- 未修改 `Sources/PagingCore/`（冻结）、`Package.swift`、`Docs/`、`PROVENANCE/`。
- 未修改 `Sources/AppGridUI/`、`Sources/PagingPrototypeApp/`、`Sources/MacAppCatalog/`、
  `Sources/AppCatalogCore/`、`Sources/AppIconPipeline/`（Worker B 拥有 AppGridUI）。
- 未修改他人 test 目录（`Tests/AppGridUITests/`、`Tests/PagingCoreTests/` 等）。
- 未读取禁止来源（BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）。
- 未 commit/push/tag/reset/clean。

## 隐私红线

- 查询/结果名绝不进 telemetry/log；未改 `PagingTelemetry` 契约。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` /
  `PRODUCT_DEFAULT_UNCHANGED`。

## 偏差

- 无功能偏差。测试实现中修正了 3 处测试自身断言问题（非 seam 缺陷）：
  - `testReloadUpdatesPageCountShrink`：reload 前清空 renderer 记录（初始 pass 的 pageCount-5
    渲染不应计入 reload 断言）。
  - `testReloadUpdatesPageCountMulti`：live host 数受可见范围上界约束（radius 3 → 最多 7），
    断言改为 `core.pageCount == 8` 且 `liveHostCount <= bound`（非等于 8）。
  - `testSettlingReloadOnlyPending`：settling 动画自身会重渲染 hosts，断言改为验证
    "settling 中只 pending + pageCount 不中途改 + idle 边界应用"。
- 一处真实 seam 修正：`applySameRevisionReload` 在 `core.setPageCount` 后**显式
  `relayoutPages()`**——pageCount 缩小但 offset 不变时 Core 不触发 relayout，须显式重算
  可见范围（`testReloadUpdatesPageCountOne` 暴露）。

## 待 Reviewer 关注

- 同 revision 重载是否保持 `servedRevision` 不变（不 mint/forge CatalogRevision）——是。
- busy 态是否只记录 latest pending、idle/cancelled 边界一次应用——是。
- 新 catalog revision 是否优先于旧同 revision 重载（latest-wins 双轴）——是。
- 是否强制重渲染使旧图标回调无法写入新 query 的 cell（generation/token gating）——是
  （`surfaceGeneration` bump + 全量 live host re-render）。
- teardown 后是否零写回——是。
- 是否触碰 PagingCore / 七字段 ItemBindingToken 契约——否（均未变）。
