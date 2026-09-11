# T-1F-B6-wave-c2 — BUG6 Wave C 第二层：拆 recognizer 双通路（缺陷 2 根治）【BLOCKED】

Status: blocked
Wave: BUG6 C2（独立于本次三波；不写入可执行范围。派发前置条件 = Wave A/B/C 全部 Reviewer PASS + 用户实机确认四缺陷消失，且第 3 节解冻评估出结论并由 Main/Chief 拍板）
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees) — 当前被 §3 BLOCKED 条件禁止开工实现

## 1. Root cause (verified — 固化自 BUG6-FIX-PROMPT §4.2)

抑制机制本身冗余：
- `AppLaunchController.install()`（`AppLaunchController.swift:93-98`）在 surface 挂 `NSClickGestureRecognizer`；而 `AppGridCellView.mouseDown`(:184-187) 已把事件路由给 coordinator，其 `.pressed → .clicked` 判据（`DragSessionController.swift:177-180`）派发到**同一条** `AppLaunchController.handleCell` 校验管线。
- 两条通路做同一件事，才需要 `clickRecognitionSuppressor` / `setClickRecognitionEnabled` / `isSuppressingClickRecognition` 整套状态机让它们互斥。拆掉 recognizer，整套抑制状态机随之删除，缺陷 2 这类泄漏在**结构上**不可能再发生。
- 同理 `AppGridCellView.folderClickRecognizer`（:43, :94-96）冗余 —— folder 点击已走 `handleDragCellClick` 的 `cell.isFolderCell` 分支（`AppDelegate.swift:641-646`）。
- `AppLaunchController.handleClick(at:)` 是测试入口，**保留**；删的只是 `install()` 里的 recognizer 挂载。

## 2. Fix spec（前置评估 → 二选一分支）
- **Step 0（评估，不写码）**：核实 `install()` 的调用方（装配链 `AppCatalogAssembly.swift` / AppDelegate）；评估** AppDelegate 侧不调用 `install()`** 是否等效（单通路后 click 全走 coordinator → handleCell；确认无其他调用方依赖 recognizer 存在）。
- **分支 1（可行，首选，不解冻）**：写范围 = `AppDelegate.swift`（去掉 `install()` 调用）+ `AppGridCellView.swift`（删 folderClickRecognizer）+ `DragUISessionCoordinator.swift`（自删整套抑制状态机）+ 测试。此时**不需要解冻任何冻结文件**。
- **分支 2（不可行）**：Worker 报 Main → Main/Chief 向用户申请解冻 `AppLaunchController.swift`（仅删 `install()` 内 recognizer 挂载、保留 `handleClick(at:)`），拿到 Main/Chief **书面解冻记录**后才可动该文件。
- 实施前置：**先跑全量测试**，确认没有测试依赖 recognizer 的存在；有则改测试直接调 `handleClick(at:)`（测试入口保留是前提）。
- 删除后回归：缺陷 2 的 suppressor 断言/配平测试（wave-c §2.2）改写为"无抑制通路存在"的结构断言或直接移除，保持矩阵完整。

## 3. BLOCKED 条件（现状即 blocked 的原因）
- `Sources/PagingPrototypeApp/AppLaunchController.swift` 在冻结树内（BUG6-FIX-PROMPT §5）。
- **任何情形 Worker 不得自行修改冻结文件**；分支 2 必须先取得 Main/Chief 书面解冻，否则本包不可执行任何产品代码写入。
- 分支 1 若成立则无需解冻，但派发时机仍由 Chief 在用户实机确认四缺陷消失后决定。

## 4. Write scope（条件性；当前因 §3 不可执行）
- 分支 1：`Sources/PagingPrototypeApp/AppDelegate.swift`、`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（抑制状态机自删）、`Sources/AppGridUI/AppGridCellView.swift`、对应测试
- 分支 2（需解冻）：以上 + `Sources/PagingPrototypeApp/AppLaunchController.swift`（仅 install() 内 recognizer 挂载；handleClick(at:) 保留）

## 5. Forbidden writes
- 未解冻前：全部冻结树照旧（含 AppLaunchController.swift）；Docs/、PROVENANCE/；Workflow/results/ 只允许本任务结果文件（评估记录除外）
- 禁新增任何第 2 套点击识别或抑制机制（本波是净删，不是替换）

## 6. Required reading (minimal, ≤4 files)
1. Sources/PagingPrototypeApp/AppLaunchController.swift — install()(:93-98)、handleGesture(:102+)、handleClick(at:)（只读）
2. Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift — 抑制状态机触点（beginArbitration/endSession/setClickRecognitionEnabled 调用点）
3. Sources/PagingPrototypeApp/AppDelegate.swift — installDragUI(:534-604) 与 handleDragCellClick(:640-654)
4. Sources/AppGridUI/AppGridCellView.swift — mouseDown(:184-187)、folderClickRecognizer(:43, :94-96)

## 7. Verification / Acceptance（解冻或分支 1 放行后）
- 全量测试 ≥1012 真实执行；debug/release exit 0。
- 结构验收：`clickRecognitionSuppressor` / `setClickRecognitionEnabled` / `isSuppressingClickRecognition` 全套消失（grep 归零）；单一点击通路；BUG6-FIX-PROMPT §6 检查清单全过。
- 实机：脚本 1-7 全过（尤其 4：建夹后点击能启动、空白能退出；7：交替 20 次）。

## 8. Output discipline
- 在被解除 BLOCKED 之前，只允许写 `Workflow/results/T-1F-B6-wave-c2-evaluation.md` 记录 Step 0 评估结论（install() 调用方、等效性论证、推荐分支）。
- 解除后按 T-1F-D1-fix-ui.md 样板纪律执行；回复 <250 词；不贴大代码块；中性夹具；无 git 操作。