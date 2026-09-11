# T-1F-B8-wave-v — BUG8 缺陷 1：蓝条钳位页末右缘（global→local 回减）

Status: ready
Wave: BUG8-wave-v（可与 wave-c 并行——写范围零交集）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并

## §1 背景

B′ 全局换算后，DragUIVisuals 消费**全局** intent 下标但以**页内** frames 定位，page≥1 中部列全局下标 ≥ 页内帧数 → `insertionRect` clamp 末帧右缘 = 网格右下角。用户实机确认（BUG8-REPORT §1，根因静态铁证）。Reviewer B′ r1 QUESTION-1 挂账项转正。

## §2 根因锚点（全部已实测）

- Sources/AppGridUI/DragUI/DragUIVisuals.swift:87-112 `updateIntent`：:89-90 `.insertion` 与 :92-93 `.topLevelTarget` 均把全局 index 传给页内 frames；:169-184 `insertionRect(for:frames:)`；:176-178 `index >= frames.count` clamp 末帧右缘。
- Sources/AppGridUI/DragSession/DragGeometry.swift:80-82 注记字段 `pageIndex`/`itemsPerPage`；:96-99 `annotated(pageIndex:itemsPerPage:)`（D 层注入：AppDelegate.swift:617-618 顶层、:634-636 folder move-out topPage；成员帧**绝不注记** :625）。
- 全局换算唯一出处：Sources/AppGridUI/DragSession/DropIntent.swift:245-250（勿动）。

## §3 写范围 / 禁写

- 写：`Sources/AppGridUI/DragUI/DragUIVisuals.swift`（唯一实现文件）+ 新测试文件 `Tests/PagingUITests/Bug8VisualIndexTests.swift`（或并入既有 visuals 测试文件，二选一，报告声明）。
- 禁写：冻结树六目录 + Package.swift + AppLaunchController.swift；DropIntent/DropResolver/DragMutationEngine/DragSessionController/DragUISessionCoordinator/AppDelegate（本波零触碰）；Docs/；无 git。

## §4 必读

Workflow/BUG8-REPORT.md §1、Workflow/reviews/T-1F-B7-wave-b-r1.md（B 项/C 项/G 节）、DropIntent.swift:214-250、DragGeometry.swift:73-100、AppDelegate.swift:608-645。

## §5 实施要求

1. 在 `showInsertionBar` 入口（或 updateIntent 两调用点前）加 global→local 回减 helper：读**帧注记**（首帧 pageIndex/itemsPerPage；帧间注记一致），`local = global − pageIndex×itemsPerPage`，clamp 到 [0, frames.count]；注记 nil → 原样（page 0/folder 成员帧/夹具直构向后兼容，兼收 B′ r1 MINOR-3）。
2. `.insertion` 与 `.topLevelTarget` 两条路径**同修**；`insertionRect` 保持页内纯函数、:176-178 clamp 保留（local==count=页末右缘是正确位）。
3. 绝不使用 `geometry.page`（folder scope=innerPage 陷阱）；只信帧注记。空 frames 回退维持 :170（hide）。
4. 零行为面外溢：resolver/engine/DropIntent 零改动；蓝条形状/颜色/动画不动。

## §6 验证与验收

- 测试（夹具中性）：①page≥1 中部列（global 38、页帧 5 → 竖条在第 3/4 帧之间，**不钳位**）；②page≥1 末列右半（local==count → 末帧右缘）；③page 0 全列行为不变（既有断言绿）；④folder 成员帧（未注记）不回归；⑤.topLevelTarget move-out（帧注记 topPage）回减正确（用 committedPage≠innerPage 几何，锁页号陷阱）；⑥未注记/空注记回退路径。
- `swift build -c debug` / `swift build -c release` exit 0；`swift test` 全量（1036+新增；RunLoopFrameDriverTests 5 失败时按隔离复跑程序定性）。
- 验收：实机语义 = page≥1 任意列蓝条与落点一致；BUG7 PageAwareDropTests 全绿（落点语义未被触碰）。

## §7 输出纪律

results 写 Workflow/results/T-1F-B8-wave-v.md：改动清单/测试证据（executed/failures 原文）/deviation 逐条/未触碰声明。禁大代码块贴报告。

## §8 风险与 Red flags

- 回减后 local<0 或 >count 必 clamp（防全局公式与注记页号不一致时越界）。
- 若发现 updateIntent 还有第三消费点，先停手报告 Chief，勿自行扩波。
- 出现「必须改 DropIntent/冻结文件才能修」的冲动 = 规格理解错误，回读 §2/§5。