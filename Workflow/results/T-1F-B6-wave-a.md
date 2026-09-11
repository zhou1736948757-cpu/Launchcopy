# T-1F-B6-wave-a — BUG6 Wave A: drop-zone 几何重写（缺陷 3+4）+ insertion off-by-one

Status: done
Worker: deepseek-v4-flash:0731
AccessDeclaration: NO_PRIOR_EXPOSURE — 全程未读 /Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump；无 git 写操作；夹具全部中性（fixture.appN/mN, 固定 UUID, 无真实名称/路径）。

## 1. 方案选择（§2c）：方案 i（engine .insertion 分支换算）+ 理由

- `LayoutMutation.reorderTopLevel`（:68-84）与 `reorderFolderMembers`（:218-240）均为 remove-then-insert 且 no-op 判据同构（`clamped == fromIndex`）→ 同一换算符号成立，无相反方向需求。
- `moveOutOfFolder`（.topLevelTarget，:176-213）不经换算：成员不在顶层序，槽位无自身左移问题（维持现语义，未触碰）。
- 方案 ii（payload 语义变更）会波及 enum/DropResolver/视觉/全部测试并动摇 wave-b 并发资格 → 不选。
- 引擎实现：`DragMutationEngine.reorderAdjustedIndex(baseIndex:sourceIndex:)` — 源在槽位左侧 → -1；源未知 → 透传（mutation 拒绝路径不变）。

## 2. 逐文件改动清单

### Sources/AppGridUI/DragSession/DropIntent.swift（210 → 239 行）
- 删除：`DropZones.insertionZones` / `appCenterZones` / `topLevelLandingZones` 字段、`AppCenterZone` struct、`DropZoneBuilder.zones` 的 insertion 带构建循环（旧 :82-105）、appCenter strip 循环（旧 :107-117）、顶层落点循环（旧 :128-152 与 insertion 带逐字重复）。
- 新增（§2b 两个纯函数族）：
  - `DropZoneGeometry.hitItem(pointer:frames:)` — 指针 → 命中条目（首含者，nil=未命中）。
  - `DropZoneGeometry.hitZone(pointer:frame:margin:)` — 中心（条目内缩 margin 后正中区，边长 = 内缩区短边 1/3，不新增参数）/ 左半 / 右半（中线归右）。
  - `DropZoneGeometry.insertionIndex(pointer:frames:)` — 指针左侧水平中点计数，按阅读行 + 更早行全部条目；覆盖首条目前/末条目后/缝隙/空白/边距。
  - `DropZoneGeometry.isTopLevelLanding(pointer:frames:margin:)` — M5 落点可达性（见 §4 注 3）。
- `DropZones` 重构为 `{itemFrames, topLevelFrames, folderCellZones, moveOutArmed, marginPT}`；`folderCellZones` 构建保留（语义正确）。`DropZoneBuilder.zones` 签名不变（`containerWidth` 保留以兼容冻结调用点 DragSessionController:255）。
- 分类器重写：folderCell 命中优先（folder 源 → .invalid）；`.topLevelApp` 他人中心 → `.createFolder`（落回自身 → 半区插入，引擎换算后 no-op）；`.folderMember` 他人中心 → **降级半区插入（缺陷 4 修复，不再 .invalid）**；armed 且指针在顶层行带缝隙/边距 → `.topLevelTarget`；其余任何落点 → `.insertion`（无死区，§2a 行为表全覆盖）。

### Sources/AppGridUI/DragSession/DragMutationEngine.swift（58 → 81 行）
- `.insertion` 分支三源均经 `reorderAdjustedIndex` 换算（方案 i）；`.createFolder/.intoFolder/.topLevelTarget/.invalid` 分支与注释不变（未触碰 wave-b 范围的 createFolder 成员序）。

### Sources/AppGridUI/FolderOverlayView.swift（452 行，0 改动）
- 无需改动：成员 `.app(ref)` 身份为引擎 `reorderFolderMembers` 所必需；缺陷 4 在分类器+纯函数层修复。仅授权写范围内的 `memberDragItemFrames` 经评估无需变更。

### Tests（§3 授权范围）
- Tests/AppGridUITests/DragDropTests.swift（579 → 550）：删除 3 个断言已删 zone 表字段的构造测试（insertionBands/appCenterZones/moveOutArmed）；`testClassifyAppSourceOnOwnCenterIsNotCreateFolder`（:226）预期 `.invalid → .insertion(1)`；`testClassifyMemberSourceOnAppCenterInvalid` 重构为 `testClassifyMemberSourceOnCenterDegradesToInsertion`（缺陷 4 正向锁）；`testEngineM1TopLevelAppReorder` 预期 `[app2,app3,app1] → [app2,app1,app3]`（off-by-one）。
- Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift（新增 254 行，10 tests）：§2d 全量 — B 左半→插前（A 已在 B 前 → no-op 锁）/ 右半→插后 / 正中→建夹；folder 成员正中 → `.insertion` 非 `.invalid`；**死区回归锁**（3×2 网格 6 格九宫格 54 点 + 列缝/行缝 + 四周页边距与角点，源 = 顶层 app，断言零 `.invalid`）；off-by-one 双方向全链锁（[A,B,C] A→B右=[B,A,C]；C→B左=[A,C,B]；folder 内同套）；M5 顶层落点复用中点计数 + 深入条目内部回退 inner 插入；insertionIndex 纯函数行划分/边距/空帧锁。
- Tests/AppGridUITests/DragSessionControllerTests.swift（**§3 解释**：DropZone/DropIntent 相关测试，事件序列直接编码 zone 几何 → 属显式授权的"旧几何语义预期更新"）：7 处 pointerMoved(50,40) 预期补 `.intentChanged(.insertion(index: 1))`（旧该点为 .invalid 静默死区）；4 处 (10,40) 边缘预期补 `.intentChanged(.insertion(index: 0))`；3 处 drop 点 (90,40)→(155,40)（旧缝带点在新几何为自身格左半 no-op；重定位到 B 右半保持"合法 drop → commit"测试目的）；`testInvalidDropRejected` → `testDropBackOnOwnCellYieldsNoOp`（源自身格不再 .invalid，落回自身 = no-op）。
- Tests/AppGridUITests/DragUISessionCoordinatorTests.swift（同上授权解释）：2 处 drop 点 (90,40)→(155,40)（旧缝带点新几何 no-op；保留 commit-seam/move-out 测试目的）。全 18 tests 绿。
- Tests/PagingUITests/DragUIIntegrationTests.swift：**未修改**（9/9 全绿）。
- 其余测试文件：零改动。

## 3. 测试证据（§6，真实执行）

- `swift test`：**exit 0；Executed 1022 tests, with 0 failures (0 unexpected)**（Task Pack 标注基线 1012：1022 = 1012 − 3 删除 + 10 新增 + 3 差额；观测值以本次实际执行为准，基线未在本会话重测，差额 3 个与 SwiftPM 既有套件计数快照相异未深究——全部套件真实执行且零失败，非 exit0+executed0 的 INVALID_TEST_EXECUTION）。
  - Bug6DropZoneGeometryTests：Executed 10, 0 failures。
  - DragDropTests：36（原 39，−3 zone 表构造测试）；DragUISessionCoordinatorTests 18 全绿；DragUIIntegrationTests 9 全绿。
- `swift build`（debug，随 test）：exit 0。`swift build -c release`：exit 0。

## 4. 行数核算（§6 净判据）与不得不加的说明

- Sources（本波三文件）：DropIntent 210→239（+29）、Engine 58→81（+23）、FolderOverlay 不变 → **净 +52（净增，非净减少）**。Tests：DragDropTests −29；新增 §2d 测试文件 +254（显式授权新增）。
- **为什么不得不加**（§6 解释）：① zone 表（字段 2 个 + AppCenterZone + 三段构建循环，≈75 行）已全删；但 §2b 规定的替代纯函数（命中查询、中心/半区分区、阅读行中点计数插入位——miss 情形需覆盖缝隙/边距/空白的行划分算法）+ §2a 全表行行为本身就是 §0 未逐项计的算法内容，复杂度高于 rect 循环；② §2c 强制同波 engine 换算（方案 i）+23 行；③ §2a/缺陷 4 的 M5 落点可达性纯函数（+11——见注 3，pack §0 未预计）；④ 注释按仓库纪律保留关键决策记录并已压缩一轮（-21）。zone 表删除判据（非"保留旁边加逻辑"）已满足。
- 若 Main/Reviewer 裁定必须严格净减少：可继续砍注释约 20 行，但 §2b/§2c 行为语义行数无法再降。

## 5. 验收映射（§7）

- 缺陷 3（B 右侧）：Bug6DropZoneGeometryTests `testDragARightHalfOfBInsertsAfterB`（insertion(2)→commit [B,A,C]）+ 控制器 (155,40) 落点 commit 全链 ✓；左半 `testDragALeftHalfOfBInsertsBeforeB`（意图 insertion(1)，A 已在 B 前 → 引擎 no-op，行为表第 1 行成立）✓。
- 缺陷 4（folder 成员）：`testFolderMemberCenterDegradesToInsertionNotInvalid`（中心 → .insertion，非 .invalid）+ DragDropTests 降级锁 ✓；实际机脚本 5/6 由 armed/armed-less 分类器路径 + coordinator 全绿支撑（代码级）。
- 2a 行为表 4/5 行（缝隙/空白/边距 → 最近插入位）：死区回归锁 3×2 九宫格+缝隙+页边距全采样零 `.invalid` ✓。
- 死区回归锁：存在且全绿 ✓。off-by-one 双方向：`testOffByOneFrontToBackARightOfBYieldsBAC` / `testOffByOneBackToFrontCLeftOfBYieldsACB` + folder 内双方向 ✓。净行数：见 §4 说明。方案 i 选择已声明（此处）✓。

## 5. 风险与注记

1. **零尺寸帧行并合**（`insertionIndex` 行划分 `minY <= bottom`）：集成测试台 pageView/overlay 在无窗口用例中从未 layout，帧全零；旧 zone 表的 0 高末带恰好兜住 y=0 指针。`<=` 使退化帧并入单一阅读行（恢复旧兜底语义）；真实网格行间有间隙（spacing 16），不受影响。此为**测试台潜在缺陷的暴露**（修复需布局调用，超出本波写范围）——已如实记录供 Main 存档。
2. **源自身格不再 .invalid**：拖拽掠过自身格现在产生 insertion 意图（引擎 no-op），视觉层将显示近身插入条（DragUIVisuals 按 DropIntent 消费，行为一致）；这是 §2a 无死区规定的直接后果。
3. **M5 armed 落点可达性**：integration 试验发现 armed + 指针深入顶层条目内部（旧 landing 带不含条目内部）在旧代码下不触发 move-out；本波以 `isTopLevelLanding`（行带内 + 非顶层条目内部）恢复该语义，避免把 folder 内拖动误判为移出（folder 被误 dissolve → 文件夹记录消失）。此纯函数为 pack §2b 的落点语义补全，建议 Chief 记入 Memory。
4. 集成测试夹具（Tests/PagingUITests）零帧实验室工件的根因证据已探明（probe：cellCenter=(0,0)、frames 全零）；修复属于测试支持层（本波禁改范围），报 Main 裁定是否另开修复项。
5. `DropZoneBuilder.zones` 的 `containerWidth` 参数保留（仅文档说明不再使用），因调用点 DragSessionController.swift 不在本波写范围。

## 6. Memory candidates（供 Chief/Main）

- BUG6 wave-a 模式：zone 表（rect 字典）作为几何编码是缺陷本体 → 纯函数化（命中/分区/中点计数）后同型缺陷不再可复发；建议沉淀"几何决策用纯函数、不用预计算 zone 表"。
- engine remove-then-insert 槽位换算规则（源在槽位左侧 → -1）与 `moveOutOfFolder` 不换算的边界，是 wave-b（createFolder 成员序）与 wave-c 复用的不变量。
- 无窗口 SwiftPM UI 测试的"零帧实验室工件"（surface/pageView/overlay layout 需显式驱动）值得作为测试台修复项登记。

## 7. 写范围遵守

改写：DropIntent.swift、DragMutationEngine.swift；测试三类（新建/授权更新）。DragParameters/LayoutMutation/DragUISessionCoordinator/AppDelegate/冻结树/Docs/PROVENANCE 零写入；无 git 操作；无真实身份数据进入任何文件。