# BUG6 修复任务 Prompt（Chief / Worker 分发用）

- 状态：待 Chief 规划 → Worker 实现
- 上游：`Workflow/BUG6-REPORT.md`（用户实机验收，4 缺陷）
- 本文用途：把 4 个缺陷的**已定位根因**、**修复方向**、**验收标准**写死，供 Chief 拆包、Worker 实现、Reviewer 独立判定
- 测试基线：1012/0（swift test 全量通过；debug/release 双构建 exit 0）
- 隐私：本文与全部产出禁真实 app 名 / bundle ID / 路径 / folder 标题 / 成员列表，一律 A/B/C 代称

---

## 0. 本次修复的总原则：净删代码

四个缺陷里有三个的正确修法是**删掉现有机制**，不是加新机制。Worker 若发现自己在往上加状态、加分支、加字段，先停下来报 Main —— 大概率方向错了。

- 缺陷 3 + 4：删掉 `DropZones` 的 `insertionZones` / `appCenterZones` 两个字典字段及其构建循环，换成两个纯函数。zone 表本身就是 bug 来源。
- 缺陷 2：删掉一条重复的点击通路，随之删掉为了让两条通路互斥而存在的抑制状态机。
- 缺陷 1：三行语义修正 + 注释同步。

改完总行数应该是**减少**的。这是本次任务的硬性风格约束。

---

## 1. 四缺陷根因（Main 已完成只读定位，Worker 不必重新诊断）

### 缺陷 1：folder 长在 A 的位置（应在 B 的位置）

`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:116-122`。`createFolder` 用 `min(targetIndex, sourceIndex)` 当插入点。A 在 B 左边时 `min` = A 的位置。

这不是实现偏离设计 —— 文件头 `:15` 的注释明确写了"新 folder 落在两原位置区间内（min 原 index）"，是**当初的规格就写错了**。所以本次要改的是规格本身，注释必须一起改。

### 缺陷 3：拖到 B 右侧不出蓝条

`Sources/AppGridUI/DragSession/DropIntent.swift:107-117` 与 `:174-179`。

`appCenterZones` 是**全宽** strip：`DragRect(x: f.minX, ..., width: f.width, ...)`，只在竖直方向取中间 1/3。而 `DropZoneClassifier` 里 center zone **优先于** insertion 带。

结果：B 的整个宽度（除左右各 8pt margin）都是 createFolder 语义，insertion 带只剩条目之间的窄缝。用户必须把 A 挪到"B 左边一点点"才能命中缝隙 —— 与实机报告逐字吻合。

用户说的"放过去两个软件交换位置"是 `reorderTopLevel` remove-then-insert 在相邻元素上的正常表现，不是独立 bug，但牵出一个真 bug，见 §4。

### 缺陷 4：folder 内拖成员到另一成员上无反应

两处叠加：

1. `Sources/AppGridUI/FolderOverlayView.swift:106-116`，`memberDragItemFrames` 把每个成员标成 `.app(ref)`，于是 `DropZoneBuilder` 给**每个成员**都生成了全宽 `appCenterZone`。
2. `DropIntent.swift:186-190`，分类器 `.folderMember` 分支遇到"别人的 center zone"直接返回 `.invalid`。

两者相乘：folder 内只有 A、B 两个成员时，面板几乎整个区域都是 `.invalid`，拖到 B 上永远没反应。

`:187` 的注释原意是"成员之间不能建夹"（对，M3 操作数必须顶层 app），但**实现方式是把整块区域废掉**，而不是降级成 insertion。这是本缺陷的核心错误。

"鼠标直动不了"是另一半：`FolderOverlayView.hitTest`(`:297-303`) 对所有非按钮区返回 self，成员 cell 自己收不到事件；intent 一路 `.invalid` 时 `DragUIVisuals.updateIntent` 走 `case .invalid: clearAll()`，preview 和指示全部清空 → 用户看到的就是"没有任何反馈、像卡住了"。

### 缺陷 2：建夹后点击打不开 + 空白点击退不出

`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:190-199`。

`pointerUp` 的 `clickFallbackCell` 分支派发完 `onCellClick(fallback)` 后**直接 return，不调用 `endSession()`**。而 `endSession()` 是恢复 `clickRecognitionSuppressor?(true)` 的唯一位置（`:348-353`）。于是 `isSuppressingClickRecognition` 停在 true，surface 上的 `NSClickGestureRecognizer` 被永久禁用。

点击打不开、空白点击退不出，是**同一个残留状态**的两种表现。

BUG6-REPORT §4 疑点 b 猜"fallback 路径也未 beginArbitration，理论上无抑制残留"——**这个推断是错的**。抑制是上一次真实会话 `beginArbitration` 开的，fallback 路径只是没关它。

`pointerDragged` 的 fallback 清除分支（`:153-161`）有同样的漏。

---

## 2. 波次 A：落点判定重写（缺陷 3 + 4）

两个缺陷共用同一处几何代码，必须同波修，不可拆。

### 2.1 目标行为（用户可观察层面，这就是验收规格）

顶层与 folder 内**同一套规则**：

| 指针落点 | 视觉 | 落下结果 |
|---|---|---|
| 目标条目左半 | 该条目左侧插入蓝条 | 插到该条目**之前** |
| 目标条目右半 | 该条目右侧插入蓝条 | 插到该条目**之后** |
| 目标条目正中小方块内 | 建夹指示（虚线框 + `+`） | 与该条目建夹 |
| 条目之间缝隙 | 就近一侧插入蓝条 | 插到对应位置 |
| 页面空白 / 边距 | 最近插入位蓝条 | 插到对应位置 |

**硬性要求：任何落点都必须有明确 intent。不允许存在"既不建夹也不插入、什么都不发生"的死区。** 现在的死区就是缺陷 3、4 的本体。

folder 内的差异只有一条：成员之间无建夹语义，所以"正中"降级为按左右半区插入（**不是** `.invalid`）。

### 2.2 实现方向

删掉 `DropZones` 的 `insertionZones` 与 `appCenterZones` 字段及 `DropZoneBuilder.zones` 里对应的两个构建循环（`DropIntent.swift:82-117`），换成两个纯函数：

- **命中查询**：指针 → 落在哪个 `DragItemFrame` 上（或 nil）。
- **意图判定**：指针 + 命中的 frame → 建夹（在中心内缩区内）/ 插入前 / 插入后。

未命中任何条目时，插入位由"指针左侧有多少个条目的水平中点"直接算出 —— 这自然覆盖首条目前、末条目后、缝隙、空白、边距，**不需要为它们各写一个 rect**。这是删掉 zone 表的关键收益。

`folderCellZones` 保留（folder cell 是真的整块目标区，语义正确）。

`topLevelLandingZones` 复用同一个插入位函数（`moveOutArmed` 时对 `topLevelFrames` 跑一遍），删掉 `:128-152` 那段与 insertion 带逐字重复的循环。

中心区大小取 `dropZoneMarginsPT`（现值 8pt，`DragParameters.swift:61`）内缩后条目框的中间部分。**不要新增参数** —— 用现有参数表达，若确实需要新参数，报 Main 由 Chief 定，因为参数族有 `PARAMETER_RATIONALE` 登记纪律（见 `DragParameters.swift:1-9` 的来源类别红线）。

### 2.3 可借鉴的简化思路（行为层，非代码）

一个成熟启动器的做法是：**图标是实体，格子背景不是**。命中测试只认图标矩形，格子的空白部分、标签区、缝隙全部落到下层页面视图。

本项目当前是 `AppGridCellView` 整块 bounds 都算 cell（`AppGridCellView.swift` 无 hitTest 覆写），所以落点判定只能靠 `DragItemFrame` 在 host 坐标系里重建几何。这条差异是**为什么本项目会出现"全宽 center zone"这种 bug** 的结构性原因。

本波**不要**改视图层命中模型（改动面太大、会动到 `AppGridPageView` 与 `PagingSurface` 的事件路由）。但判定函数应该按"图标 / 中心 / 两侧"来分区，而不是按"整格 / strip"，这样几何语义和视觉才对得上。

### 2.4 必须同时修的 off-by-one（报告未记录，Main 新发现）

`.insertion(index:)` 的下标语义与 `reorderTopLevel` 的 remove-then-insert 不匹配。

`LayoutMutation.reorderTopLevel`（`:77-81`）先 `remove(at: fromIndex)` 再 `insert(at: clamped)`。当**源在目标之前**时，移除源使目标左移一位，于是"插到 B 之后"算出来的下标会多走一格。

具体：`[A, B, C]`，拖 A 到 B 右侧 → 判定给出 `.insertion(index: 2)` → remove A 得 `[B, C]` → insert at 2 → `[B, C, A]`。**期望是 `[B, A, C]`。**

现在这个 bug 被 center zone 挡着（根本走不到 insertion），修完缺陷 3 才会暴露。所以必须同波修，否则用户复测时会看到"蓝条出来了但落点仍然不对"。

两个方案，Worker 选一个并在结果文件说明理由：

- **方案 i**：在 `DragMutationEngine`（`DragMutationEngine.swift` 的 `.insertion` 分支）做换算 —— 源在目标前时 `index - 1`。换算只在一处发生，域层语义不动。
- **方案 ii**：把 `.insertion` 的载荷从"下标"改成"插到哪个条目之前 / 末尾"。更健壮，但改动面波及 enum、分类器、引擎、视觉、全部相关测试。

**建议方案 i**，除非 Worker 发现 `reorderFolderMembers`（`:230-236`，同样 remove-then-insert）和 `moveOutOfFolder`（`:210`，从 folder 移除但插入顶层数组 —— 语义不同，可能本来就是对的）需要不一致的换算方向，那时方案 ii 更省事。

**方案 ii 会改 `DropIntent` 的 enum 载荷，可能波及波次 B 的测试预期。Worker 选定后必须先报 Main，由 Main 决定波次 B 能否并发。**

### 2.5 自动化验收（必须新增，不可只靠实机）

- 拖 A 到 B 左半 / 右半 / 正中 → 分别得到"插到 B 前" / "插到 B 后" / "与 B 建夹"。
- folder 内拖成员 A 到成员 B 上（正中）→ 得到 `.insertion`，**不是** `.invalid`。
- **死区回归**：对一个 3×2 网格，遍历每格的九宫格采样点 + 所有缝隙点 + 四周页边距点，断言**没有任何点**得到 `.invalid`（源为顶层 app 时）。这条测试是缺陷 3、4 的回归锁。
- off-by-one 方向锁：`[A,B,C]` 拖 A 到 B 右侧 → `[B,A,C]`；拖 C 到 B 左侧 → `[A,C,B]`。**两个方向都要测**，只测一个方向测不出换算符号错误。

---

## 3. 波次 B：建夹落点（缺陷 1）

### 3.1 目标行为

拖 A 到 B 上建夹 → 新 folder 出现在 **B（drop 目标）** 原来的位置。A 是"被拖走的"，B 是"留在原地被拖到的"。

### 3.2 实现方向

`LayoutMutation.swift:116-122`。当前用 `min(targetIndex, sourceIndex)`，改为 target 的位置。

**注意下标移位陷阱**：`ordered.remove(at: second)` 再 `remove(at: first)` 之后，target 的原下标可能已失效。当 source 在 target 之前时，移除 source 会使 target 左移一位。必须先算出"移除两项后 target 应落的下标"，再 `min(..., ordered.count)` 兜底。

**不要**用"先删 source 再查 target 下标"这种依赖中间态的写法 —— 两次 remove 之间数组状态易错。直接从 `targetIndex` 与 `sourceIndex` 的相对关系算：source 在前则 `targetIndex - 1`，否则 `targetIndex`。

同步更新：
- 文件头 `:15` 的语义速查行（当前写"落在两原位置区间内（min 原 index）"）。
- `createFolder` 的 doc 注释 `:91`（当前写"两 app 原位置区间内（min 原 index，失败兜底尾部由 clamp 保证）"）。

**注释与实现不一致会被 Reviewer 判 FAIL** —— 这是本项目的既有纪律（见 `LayoutMutation.swift:1-23` 的语义速查块，它是该文件的契约声明）。

### 3.3 自动化验收

- A 在 B 左边（`[A, B, C]`，A 拖到 B）→ folder 在**索引 1**（B 原位），结果 `[C 之前的位置关系保持]`，即 `[folder, C]`。
- A 在 B 右边（`[B, A, C]`，A 拖到 B）→ folder 在**索引 0**（B 原位），结果 `[folder, C]`。
- **两个方向都必须测。** 只测一个方向无法区分"用了 target 位置"和"用了 min"—— 当 target 恰好是较小下标时两者结果相同，这正是当前 bug 能长期存活的原因。
- 成员顺序仍为 `[target, source]`（先目标后源，`:114`），本波不改，但要有测试锁住它没被顺手改掉。

---

## 4. 波次 C：抑制状态泄漏（缺陷 2）

分两层。**第一层必须做，第二层建议单独排期。**

### 4.1 第一层：堵漏（低风险，可立即验收）

`DragUISessionCoordinator.swift`：

1. `pointerUp` 的 `clickFallbackCell` 分支（`:190-199`）派发前后都要走 `endSession()`。
   **顺序要求：先 `endSession()`，再 `onCellClick(fallback)`。** 因为 `onCellClick` 会触发 `handleDragCellClick` → 可能 `launchController.handleCell` → 可能触发呈现更新 → 重入 `cancel(.catalogRefresh)`。先清干净再派发，避免重入时状态半旧半新。
2. `pointerDragged` 的 fallback 清除分支（`:153-161`）过阈值清除后同样调 `endSession()`。
3. 检查 `pointerDown` 里 `controller.pointerDown` 返回 `.cancelled(.secondDrag)` 但 `sourcePresent` 失败的路径（`:125-135`）：`sourceCell` 在 `:124` 已被赋值，这条路径上它会不会带着"已抑制"状态残留。若会，一并堵。

**自查清单：把 `pointerUp` / `pointerDragged` / `pointerDown` 的每一个提前 `return` 逐条列出，标注该路径是否需要 `endSession()`，写进结果文件。** 这个函数族的漏就是这么产生的 —— 不逐条过一遍会再漏。

### 4.2 第二层：根治（拆掉双通路，建议单独任务）

抑制机制本身是冗余的。

`AppLaunchController.install()`（`AppLaunchController.swift:93-98`）在 surface 上挂了 `NSClickGestureRecognizer`；而 `AppGridCellView.mouseDown`（`:184-187`）已经把事件路由给 coordinator，coordinator 的 `.pressed → .clicked` 判据（`DragSessionController.swift:177-180`）派发到**同一条** `AppLaunchController.handleCell` 校验管线。

**两条通路做同一件事，才需要那套抑制状态机让它们互斥。** 拆掉 recognizer，`clickRecognitionSuppressor` / `setClickRecognitionEnabled` / `isSuppressingClickRecognition` 整套跟着消失，缺陷 2 这类泄漏在结构上不可能再发生。

同理 `AppGridCellView.folderClickRecognizer`（`:43`, `:94-96`）也冗余 —— folder 点击现在走 `handleDragCellClick` 的 `cell.isFolderCell` 分支（`AppDelegate.swift:641-646`）。

`AppLaunchController.handleClick(at:)` 是测试入口，**保留**；删的只是 `install()` 里的 recognizer 挂载。

**⚠️ BLOCKED 条件：`Sources/PagingPrototypeApp/AppLaunchController.swift` 在冻结树内**（见 §5）。Worker 必须先评估"在 `AppDelegate` 侧不调用 `install()`"能否达到同样效果 —— 若可行则不碰冻结文件；若不可行，报 Main 申请解冻，**不得自行修改冻结文件**。

拆之前跑全量测试，确认没有测试依赖 recognizer 的存在；有则改测试直接调 `handleClick(at:)`。

### 4.3 关于 `sessionLayout`（本波不修，但要记录）

`AppDelegate.swift:539-547` 的 `layoutProvider` 一旦 `sessionLayout` 非 nil 就永远返回它；`onCommit`（`:561`）只在 commit 时更新，而 `makeSessionLayout` 恒产出 `generation: .zero`（`DragUISessionCoordinator.swift:444`），`applyCommittedLayout` 走的却是递增的 folder generation（`AppGridUIPageContentProvider.swift:259`）。

这是**"为什么会走到 fallback 路径"** 的上游原因。第一层只是让 fallback 路径不再泄漏状态，没有消除 fallback 本身。

**本波不动它** —— 改动牵扯 `applyCommittedLayout` 的 generation 语义，影响面大。第一层修完、用户实机确认四缺陷消失后，由 Chief 决定是否单独开任务。若用户复测发现"第二次拖拽行为异常"，直接指向这里。

### 4.4 自动化验收

- 单测：pointer-down 被 `sourcePresent` 拒 → pointer-up 未过阈值 → **断言 `clickRecognitionSuppressor` 收到 `true`**。直接断言 suppressor 的调用，不要只断言 `isSessionActive == false` —— 后者为 true 时前者仍可能没被调用，正是当前 bug。
- 单测：同一序列重复 20 次，断言无状态累积（suppressor 的 true/false 调用次数配平）。
- 实机：建夹后点其他 app 能启动；点空白能退出；拖拽与点击交替 20 次不退化。

---

## 5. 约束与红线

### 冻结树（绝不修改）

`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`

**波次 C 第二层需要动最后一项 → 见 §4.2 的 BLOCKED 条件。**

### 各波次可写范围

- 波次 A：`Sources/AppGridUI/DragSession/DropIntent.swift`、`DragMutationEngine.swift`、`Sources/AppGridUI/FolderOverlayView.swift`（仅 `memberDragItemFrames`）+ 对应测试
- 波次 B：`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift` + 对应测试
- 波次 C：`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` + 对应测试；第二层另涉 `AppDelegate.swift`、`AppGridCellView.swift`

波次 A 与 B 若都走方案 ii，写范围与测试预期重叠 → 串行。方案 i 下二者可评估并发（Main 决定，须记 `concurrency_check`）。

### 禁止来源

`BuhoReverseNotes` / `LaunchBetter` / `2026-08-25-buho-launchpad-reverse` —— **Worker 绝不读取**。

本文 §2.3、§4.2 已经把可用的行为层结论提炼进来了（"图标是实体不是格子"、"单一点击通路"），Worker 据本文实现即可，clean-room 链条保持干净。行为期望以 `BUG6-REPORT.md` §1 用户原话为准。

`DragParameters` 的来源类别红线照旧（`DragParameters.swift:1-9`）：新增/修改参数只能是 `PRODUCT_DECISION` / `PLATFORM_REQUIREMENT` / `ACCESSIBILITY_REQUIREMENT` / `INDEPENDENT_EXPERIMENT` / `PUBLIC_DOCUMENTATION`，禁 `REVERSE_ENGINEERING_COPY` / `OLD_SOURCE_TRANSLATION` / `UNKNOWN_ORIGIN`。

### 其他

- 无 git 操作（仓库无提交）
- 测试必须真实执行：`exit_code == 0` 且 `executed_tests == 0` 是 `INVALID_TEST_EXECUTION`，不是 PASS
- 测试夹具用中性 A/B/C，不出现真实 app 名 / bundle ID / 路径
- 每缺陷独立过 Reviewer 才合并；事件经 `record_workflow_event.py`（任务包文件须先存在）
- Worker 输出纪律：先写 `Workflow/results/<task-id>.md` 为 in-progress；回复 < 250 词；无大代码块；完成报告必须披露所有改动

---

## 6. 合并前检查清单（Reviewer 用）

- [ ] `DropZones` 的 `insertionZones` / `appCenterZones` 已删除，不是保留着旁边加新逻辑
- [ ] 死区回归测试存在且覆盖九宫格 + 缝隙 + 页边距，全部非 `.invalid`
- [ ] off-by-one 方向测试**两个方向**都有
- [ ] folder 内成员拖到另一成员正中 → `.insertion`，不是 `.invalid`
- [ ] 建夹落点测试**左右两种**相对位置都有
- [ ] `endSession()` 在 `pointerUp` / `pointerDragged` / `pointerDown` 的每条提前 return 前都已核过，结果文件有逐条清单
- [ ] 抑制恢复是**直接断言 suppressor 收到 true**，不是只断言 `isSessionActive`
- [ ] 全量测试 ≥ 1012 且真实执行；debug/release 双构建 exit 0
- [ ] `LayoutMutation.swift` 文件头语义速查块与新实现一致
- [ ] 无改动落在冻结树内（或已有 Main/Chief 书面解冻）
- [ ] **总行数净减少**（§0）；若净增加，结果文件须说明为什么不得不加

---

## 7. 用户实机复验脚本（每波次后跑）

1. 拖 A 到 B 上 → folder 出现在 **B** 的位置
2. 拖 A 到 B 右侧 → **B 右侧**出现蓝条 → 放下 → A 在 B **后面**
3. 拖 A 到 B 左侧 → B 左侧蓝条 → 放下 → A 在 B **前面**
4. 建夹后：点其他 app **能启动**；点空白**能退出**
5. 打开 folder：三指拖成员 A → **有 preview 跟手**；拖到成员 B 上 → **有蓝条**；放下 → 顺序改变
6. folder 内拖成员往面板外 → 移出 folder（超过 24pt arm 阈值，`DragParameters.swift:62`）
7. 交替拖拽与点击 20 次 → 无退化

任何一条不过 → Reviewer FAIL，附实机现象 + 复现步骤。
