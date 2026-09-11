# T-1F-B6-wave-a — BUG6 Wave A: drop-zone 几何重写（缺陷 3+4）+ insertion off-by-one

Status: ready
Wave: BUG6 A（三波中必须先行；与 wave-c 写范围不相交，可与之一同经 Main concurrency_check 放行；wave-b 的串并资格由本波方案选择决定）
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified — 固化自 BUG6-FIX-PROMPT §1，不要重新诊断)

- 缺陷 3（B 右侧不出蓝条）：`Sources/AppGridUI/DragSession/DropIntent.swift:82-117` —— `appCenterZones` 是全宽 strip（:107-117 `DragRect(x: f.minX, width: f.width)`，仅竖直取条目高 1/3），而 `DropZoneClassifier`（:174-179）center zone **优先于** insertion 带。结果：B 整个宽度（除左右各 8pt margin）都是 createFolder 语义，insertion 只剩条目间窄缝 —— 与用户实机报告逐字吻合。
- 缺陷 4（folder 内拖成员无反应）：`Sources/AppGridUI/FolderOverlayView.swift:106-116` `memberDragItemFrames` 把每个成员标成 `.app(ref)` → `DropZoneBuilder` 给每个成员生成全宽 appCenterZone；`DropIntent.swift:186-190` `.folderMember` 分支遇到"别人的 center zone"直接返回 `.invalid` 而不是降级 insertion。相乘后 folder 内几乎全区域 `.invalid`；`FolderOverlayView.hitTest`(:297-303) 返回 self 收不到事件、`DragUIVisuals` 遇 `.invalid` 清空全部视觉 → "直动不了、没任何反馈"。
- off-by-one（Main 新发现，报告未记录）：`.insertion(index:)` 与 `reorderTopLevel`（`LayoutMutation.swift:77-81`，remove-then-insert）不匹配：源在目标前时移除源使目标左移一位，"插到 B 之后"多走一格。`[A,B,C]` 拖 A 到 B 右侧 → 判定 `.insertion(index:2)` → remove A 得 `[B,C]` → insert 2 → `[B,C,A]`，**期望 `[B,A,C]`**。当前被 center zone 挡住，本波修完缺陷 3 必然暴露 → 必须同波修。
- 用户"交换位置"现象是 reorder remove-then-insert 在相邻元素上的正常表现，非独立 bug。

## 2. Fix spec（BUG6-FIX-PROMPT §2 全量固化）

### 2a. 净删目标行为表（这就是验收规格；顶层与 folder 内同一套规则）

| 指针落点 | 视觉 | 落下结果 |
|---|---|---|
| 目标条目左半 | 该条目左侧插入蓝条 | 插到该条目**之前** |
| 目标条目右半 | 该条目右侧插入蓝条 | 插到该条目**之后** |
| 目标条目正中小方块内 | 建夹指示（虚线框 + `+`） | 与该条目建夹 |
| 条目之间缝隙 | 就近一侧插入蓝条 | 插到对应位置 |
| 页面空白 / 边距 | 最近插入位蓝条 | 插到对应位置 |

**硬性要求：任何落点都有明确 intent，不允许死区**（现在的死区就是缺陷 3/4 本体）。folder 内唯一差异：成员之间无建夹语义 → "正中"**降级为左右半区插入**（不是 `.invalid`）。

### 2b. 实现（§0 净删代码）
- 删掉 `DropZones` 的 `insertionZones` 与 `appCenterZones` 字段及 `DropZoneBuilder.zones` 的两个构建循环（DropIntent.swift:82-105 与 :107-117），换成**两个纯函数**：
  1. 命中查询：指针 → 落在哪个 `DragItemFrame` 上（或 nil）。
  2. 意图判定：指针 + 命中的 frame → 建夹（中心内缩区内）/ 插入前 / 插入后。
- 未命中任何条目时：插入位 =「指针左侧有多少个条目的水平中点」直接算出 —— 自然覆盖首条目前/末条目后/缝隙/空白/边距，不为它们各写 rect。
- `folderCellZones` **保留**（语义正确）。
- `topLevelLandingZones` 复用同一插入位函数（`moveOutArmed` 时对 `topLevelFrames` 跑一遍），删掉 :128-152 与 insertion 带逐字重复的循环。
- 中心区大小 = `dropZoneMarginsPT`（现值 8pt，DragParameters.swift:61）内缩后条目框中间部分。**禁新增参数**；确需新参数 → 停下报 Main（`DragParameters.swift:1-9` PARAMETER_RATIONALE 来源类别纪律）。
- 分类器语义：`.topLevelApp` 命中他人中心内缩区 → `.createFolder`；`.folderMember` 命中他人中心 → **降级 insertion**（不再 `.invalid`）；判定函数按「图标 / 中心 / 两侧」分区，不按「整格 / strip」。**本波不改视图层命中模型**（不动 AppGridPageView / PagingSurface 事件路由）。

### 2c. off-by-one（必须同波修）
- 方案 i（建议）：`DragMutationEngine` `.insertion` 分支换算 —— 源在目标前时 `index - 1`。
- 方案 ii：`.insertion` 载荷改为"插到哪个条目之前 / 末尾"（更健壮但波及 enum/分类器/引擎/视觉/全部测试，并影响 wave-b 并发资格）。
- **由 Worker 选定并在结果文件声明理由 + 报 Main**（Main 据此裁定 wave-b 串/并并记 `concurrency_check`）。建议方案 i，除非发现 `reorderFolderMembers`(:230-236) 与 `moveOutOfFolder`(:210) 需要相反换算方向，那时方案 ii 更省（并报 Chief）。

### 2d. 必须新增的测试（不可只靠实机）
- 拖 A 到 B 左半/右半/正中 → 分别"插到 B 前"/"插到 B 后"/"与 B 建夹"。
- folder 内成员拖到成员正中 → `.insertion`，**不是** `.invalid`。
- **死区回归锁**：3×2 网格，遍历每格九宫格采样点 + 所有缝隙点 + 四周页边距点，断言**没有任何点**得 `.invalid`（源 = 顶层 app）。
- off-by-one **双方向锁**：`[A,B,C]` A→B 右 → `[B,A,C]`；`[A,B,C]` C→B 左 → `[A,C,B]`（只测一个方向测不出换算符号错误）。

## 3. Write scope
- Sources/AppGridUI/DragSession/DropIntent.swift
- Sources/AppGridUI/DragSession/DragMutationEngine.swift
- Sources/AppGridUI/FolderOverlayView.swift（**仅** `memberDragItemFrames`）
- 对应测试：`Tests/` 下新建测试文件；**允许**更新现有 DropZone/DropIntent 相关测试中编码旧几何语义的预期（本包显式授权），其余现有测试文件禁改。

## 4. Forbidden writes
- 冻结树：Sources/PagingCore/、Sources/AppCatalogCore/、Sources/MacAppCatalog/、Sources/AppIconPipeline/、Sources/PagingTelemetry/、Sources/PagingUI/、Package.swift、Sources/PagingPrototypeApp/AppLaunchController.swift
- `Sources/AppGridUI/DragParameters.swift`（禁新增参数）、`LayoutDomain/LayoutMutation.swift`（wave-b 范围）、`DragUI/DragUISessionCoordinator.swift`（wave-c 范围）、`AppDelegate.swift`
- Docs/、PROVENANCE/；Workflow/results/ 只允许本任务结果文件

## 5. Required reading (minimal, ≤4 files)
1. Sources/AppGridUI/DragSession/DropIntent.swift — zones(:74-155)、classify(:158-202)、insertionIntent(:204-209)
2. Sources/AppGridUI/DragSession/DragMutationEngine.swift — 全文 58 行，`.insertion` 分支 :20-31
3. Sources/AppGridUI/FolderOverlayView.swift — memberDragItemFrames(:106-116)、hitTest(:297-303)（只读理解，不改）
4. Sources/AppGridUI/DragSession/DragParameters.swift — :1-9 来源纪律头 + :61 dropZoneMarginsPT

## 6. Verification
- swift test 全量：基线 1012 全绿 + 2d 新测试全绿；真实执行（`exit_code==0` 且 `executed_tests==0` = `INVALID_TEST_EXECUTION`，不是 PASS）；范围外失败报而不修
- swift build -c debug 与 release 均 exit 0（`.build` 由 Main 串行调度）
- **总行数净减少**（§0 判据；若净增，结果文件必须说明为什么不得不加，否则 Reviewer FAIL）

## 7. Acceptance（对用户缺陷）
- 缺陷 3：2a 行为表第 1/2/4/5 行全项通过（B 右侧出蓝条、放下 A 在 B 后面；B 左侧同理）。
- 缺陷 4：2a 第 1/2 行在 folder member 源下成立（正中降级插入，非 `.invalid`）；实机脚本 5/6 跟手 + 蓝条 + 顺序改变。
- 死区回归测试存在且全非 `.invalid`；off-by-one 双方向正确；总行数净减少；方案 i/ii 选择已在结果文件声明并报 Main。

## 8. Output discipline
- 先写 `Workflow/results/T-1F-B6-wave-a.md` 为 Status: in progress；终态附：方案选择+理由、改动清单（逐文件）、测试证据（executed counts）、验收映射、风险。
- 回复 <250 词；不贴大代码块；隐私红线（中性计数器，A/B/C 夹具）；无 git 操作。
- 结果文件须存在后事件才可经 `record_workflow_event.py` 记录。