# T-1F-B8-wave-v — BUG8 缺陷 1：蓝条钳位页末右缘（global→local 回减）

Status: done
Role: Worker（chef-worker-reviewer-workflow v1.4.1，fresh context）
AccessDeclaration: NO_PRIOR_EXPOSURE（未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何 Ghidra/otool dump）
Git: 零 git 操作

## 改动清单

1. `Sources/AppGridUI/DragUI/DragUIVisuals.swift`（唯一实现文件）：
   - `showInsertionBar(at:frames:)` 入口（:134-147）新增 global→local 回减调用：`let index = localInsertionIndex(fromGlobal: globalIndex, frames: frames)` 后再进 `insertionRect`——`.insertion` 与 `.topLevelTarget` 两条路径经同一私有入口一次覆盖（updateIntent :89-90/:92-93 两调用点未改形参语义，全局下标传入、入口回减）。
   - 新增私有 helper `localInsertionIndex(fromGlobal:frames:)`（:152-162）：读**首帧注记** pageIndex/itemsPerPage（与 DropIntent.globalIndex 同契约：同帧列表同页、取首帧为代表），`local = global − pageIndex×itemsPerPage`，clamp `[0, frames.count]`（§8 红旗 1：防全局公式与注记页号不一致越界；local==count=页末右缘是正确位）。注记 nil（pageIndex 或 itemsPerPage 任一为 nil）→ 原样返回（page 0/folder 成员帧/夹具直构向后兼容，兼收 B′ r1 MINOR-3）。**绝不使用 geometry.page**（folder scope=innerPage 陷阱）；只信帧注记。空 frames → 注记取不到 → 原样 → insertionRect 返回 nil → 维持原 :170 hide 回退。
   - `insertionRect(for:frames:)`（原 :169-184）**零改动**：页内纯函数、原 :176-178 末帧右缘 clamp 保留。
   - 新增只读可观测属性 `public var insertionIndicatorFrame: NSRect`（:41-42，与既有 previewFrame 同区，注释标 BUG8 wave-v）：测试/诊断断言蓝条坐标所需，零行为面（纯 getter）。见 Deviation D1。

未改动（核对过无第三消费点）：updateIntent 其余分支（.intoFolder/.createFolder/.invalid 走 identity 查帧，不涉下标）；showInsertionBar 仅 .insertion/:92-93 .topLevelTarget 两处调用（§8 红旗 2 未触发，未停手事项）。

2. 新增 `Tests/PagingUITests/Bug8VisualIndexTests.swift`（9 测试，夹具中性 fixture.*；二选一声明：**新文件**——Tests/ 内原无任何 visuals/insertion 指示测试文件可并入）：①②③④⑤⑥全实现 + §8 红旗负下标 clamp + 空 frames hide + .topLevelTarget 未注记回退。

## 测试证据（真实执行原文）

- `swift build -c debug` → `Build complete!` exit 0（修复恢复后终态复验）
- `swift build -c release` → `Build complete!` exit 0
- `swift test` 全量（2026-09-01 22:27，修复恢复后终态）：
  ```
  Test Suite 'Bug7PageAwareDropTests' passed
  Test Suite 'Bug8VisualIndexTests' passed
  Test Suite 'All tests' passed
  Executed 1052 tests, with 0 failures (0 unexpected) in 22.239 (22.399) seconds
  ```
  - Bug8VisualIndexTests: `Executed 9 tests, with 0 failures (0 unexpected)`
  - Bug7PageAwareDropTests（BUG7 落点语义未触碰验收）: `Executed 7 tests, with 0 failures (0 unexpected)`
  - RunLoopFrameDriverTests: 本轮全绿 `Test Suite 'RunLoopFrameDriverTests' passed`——flaky 未现，无需隔离复跑定性
  - 日志仅有的 "failed" 字符串 = 既有 DBG7 flush 探针诊断行（非测试失败，基线即存在）
- 全量数字口径：运行时全量 1052 = 当时既有基线 1043 + 本波新增 9（Main 通报"基线 1052+新增"系并行波合并前口径；本日志为终态实测，无范围外失败）。
- **变异检查（测试有效性证明）**：临时禁用回减（`local = globalIndex`，无注记减法）后 `swift test --filter Bug8VisualIndexTests`：
  ```
  Executed 9 tests, with 5 failures (0 unexpected)
  ```
  恰好 3 个带注记 page≥1 路径测试失败（5 处断言）：①中部列不钳位、负下标 clamp、⑤.topLevelTarget committedPage 回减；page 0/未注记/回退 6 测试保持绿（证明回退路径与旧行为一致）。随后恢复修复、重建重测全绿（上表）。

## 验收映射（任务包 §6）

| # | 必测 | 测试 | 结果 |
|---|---|---|---|
| ① | page≥1 中部列不钳位（global 38、页帧 5 → 第 3/4 帧间） | testPage1MiddleColumnInsertionBarSitsBetweenFrames34（page1 5 帧=全局 35-39 注记 1/35；38→local 3，bar x=263.5≠末帧右缘 437） | 绿 |
| ①+ | §8 红旗：global 10 < 页起点 35 → local<0 clamp 0 首帧左缘 | testPage1GlobalBelowPageStartClampsToFirstFrameLeftEdge | 绿 |
| ② | page≥1 末列右半 local==count → 末帧右缘正确位 | testPage1AfterLastInsertionBarSitsAtLastFrameRightEdge（global 40→local 5，bar x=437=末帧右缘） | 绿 |
| ③ | page 0 全列行为不变（未注记=全局即页内） | testPage0UnannotatedInsertionBarBehaviorUnchanged（index 0/3/5/38 四断言） | 绿 |
| ④ | folder 成员帧（未注记）不回归 | testFolderMemberFramesUnannotatedIndexUnchanged（index 2 中点 / index 7 末缘原样） | 绿 |
| ⑤ | .topLevelTarget move-out 帧注记 topPage 回减，锁 committedPage≠innerPage 陷阱 | testMoveOutTopLevelTargetSubtractsAnnotatedTopPageNotGeometryPage（geometry.page=0=innerPage，topFrames 注记 topPage=1；38→local 3 第 3/4 帧间；实现若误用 geometry.page 即失败） | 绿 |
| ⑥ | 未注记/空注记回退路径 | testPartialAnnotationFallsBackToUnchangedBehavior（注记不成对→原样）、testEmptyFramesKeepsInsertionIndicatorHidden（空 frames 两路径 hide）、testTopLevelTargetUnannotatedFramesUnchanged | 绿 |
| — | BUG7 PageAwareDropTests 全绿（落点语义未触碰） | 全量内 7/0 | 绿 |
| — | 实机语义：page≥1 任意列蓝条与落点一致 | ①② + resolver/engine/DropIntent 零改动（同一全局值消费，落点不变） | 结构性满足 |

## Deviation

- D1（可观测性，写范围内）：DragUIVisuals.swift 新增只读属性 `insertionIndicatorFrame`（纯 computed，转发既有私有视图 frame）。理由：新测试须断言"竖条在第 3/4 帧之间"的坐标，原类仅暴露 previewFrame 无 insertion frame；沿用同文件既有"可观测状态（测试/诊断）"模式，零行为面外溢（不进布局/动画/形状/颜色）。若 Reviewer 认为超规格可移除并改经 host.subviews 遍历断言（备选已评估，更脆）。
- D2（测试文件位置）：按任务包首选路径新建 Tests/PagingUITests/Bug8VisualIndexTests.swift（§3 允许"新文件或并入既有 visuals 测试文件二选一"；Tests/ 无既有 visuals 文件可选，声明选择为新文件）。
- D3（数字口径）：全量 1052 与 Main 通报"基线 1052+新增"差 9，原因 = 运行时刻既有基线实为 1043（并行波合并进度差异）；无范围外失败，日志原文已附。若 Main 口径预期 1061，请以本日志实测为准复核合并时序。
- 无其他 deviation；未发现 updateIntent 第三消费点；未触碰 DropIntent/冻结文件。

## 未触碰声明

本波仅写入：`Sources/AppGridUI/DragUI/DragUIVisuals.swift`、`Tests/PagingUITests/Bug8VisualIndexTests.swift`（新建）、`Workflow/results/T-1F-B8-wave-v.md`。以下零触碰：Sources/PagingCore/、Sources/AppCatalogCore/、Sources/MacAppCatalog/、Sources/AppIconPipeline/、Sources/PagingTelemetry/、Sources/PagingUI/、Package.swift、AppLaunchController.swift、DropIntent.swift、DropResolver、DragMutationEngine、DragSessionController、DragUISessionCoordinator、AppDelegate.swift、Docs/、PROVENANCE/、Workflow/results/ 其他文件。零 git 操作；蓝条形状/颜色/动画未动（insertionIndicator 配置 :231-233 未改）；geometry.page 未读取。