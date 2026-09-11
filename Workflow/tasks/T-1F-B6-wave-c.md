# T-1F-B6-wave-c — BUG6 Wave C 第一层：抑制状态泄漏堵漏（缺陷 2）

Status: ready
Wave: BUG6 C1（写范围与 wave-a/b 完全不相交，可经 Main `concurrency_check` 与任一波并行；`.build` 全局串行照旧）
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified — 固化自 BUG6-FIX-PROMPT §1 缺陷 2，不要重新诊断)

- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:190-199`：`pointerUp` 的 `clickFallbackCell` 分支派发完 `onCellClick(fallback)` 后**直接 return，不调用 `endSession()`**。而 `endSession()`（:348-364）是恢复 `clickRecognitionSuppressor?(true)` 的唯一位置（其中 setClickRecognitionEnabled(true) + suppressor(true)）。于是 `isSuppressingClickRecognition` 停在 true，surface 上 `NSClickGestureRecognizer` 永久禁用。
- 点击打不开（`onCellClick` → `handleDragCellClick` 通路被抑制闸住）与空白点击退不出，是**同一个残留状态**的两种表现。
- BUG6-REPORT §4 疑点 b"fallback 路径未 beginArbitration，理论上无抑制残留"的推断**是错的**：抑制是上一次真实会话 `beginArbitration` 开的，fallback 路径只是没关它。
- `pointerDragged` 的 fallback 清除分支（:153-161）有同样的漏。
- `pointerDown`（:103-137）：`sourceCell` 在 :124 已赋值；controller 返回 `.cancelled(.secondDrag)`（保持仲裁）且无 `.pressed`、但 `sourcePresent` 失败的路径（:125-135）是否带着"已抑制"状态残留 —— 本波排查，若会则一并堵。

## 2. Fix spec（BUG6-FIX-PROMPT §4.1 全量固化；Chief 两条防过度修复注记）

1. `pointerUp` `clickFallbackCell` 分支（:190-199）：派发前后都要走 `endSession()`。**顺序要求：先 `endSession()`，再 `onCellClick(fallback)`** —— `onCellClick` 触发 `handleDragCellClick` → 可能 `launchController.handleCell` → 可能触发呈现更新 → 重入 `cancel(.catalogRefresh)`；先清干净再派发，避免重入时状态半旧半新。
2. `pointerDragged` fallback 清除分支（:153-161）：过阈值清除后同样调 `endSession()`。
3. `pointerDown` `.cancelled(.secondDrag)` + `sourcePresent` 失败路径（:125-135）：排查 `sourceCell` 残留与抑制状态；若会残留则一并堵。

### 2.1 自查清单（强制性，写进结果文件）
把 `pointerUp` / `pointerDragged` / `pointerDown` 的**每一个提前 `return`** 逐条列出，标注「需要 / 不需要 `endSession()`」+ 一句理由。这个函数族的漏就是这么产生的 —— 不逐条过一遍会再漏。

**Chief 防过度修复注记（违反 = Reviewer FAIL 项）**：
- 会话建立**之前**的 return（`isTornDown` / `dragGate()` false / 无 `visualHost`）：不需要 `endSession()` —— 此时无会话，盲目清可能误伤上一轮仲裁。
- `pointerDown` :112-115 的 surface 级抑制设计为保持到**整个仲裁结束**；`.cancelled(.secondDrag)` 保持仲裁是既有设计 —— 只修 fallback/click 派发后的残留，**不得**顺手把 second-drag 仲裁语义改成结束会话。

本波**不做**第二层（拆 recognizer 双通路 / 删抑制状态机）—— 那是 `T-1F-B6-wave-c2.md`（blocked），见该包。

### 2.2 必须新增的测试（BUG6-FIX-PROMPT §4.4）
- 单测：pointer-down 被 `sourcePresent` 拒 → pointer-up 未过阈值 → **断言 `clickRecognitionSuppressor` 收到 `true`**。直接断言 suppressor 调用，**不要只断言 `isSessionActive == false`** —— 后者为 true 时前者仍可能没被调用，正是本 bug。
- 单测：同一序列重复 20 次，断言无状态累积（suppressor 的 true/false 调用次数**配平**）。
- 实机（脚本 4/7）：建夹后点其他 app 能启动；点空白能退出；拖拽与点击交替 20 次不退化。

## 3. Write scope
- Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift（仅 fallback/endSession 相关小修 + self-check 涉及的路径）
- 对应测试：`Tests/` 下新建 suppressor 配平测试；本包授权更新直接受影响的原 coordinator 测试预期，其余禁改

## 4. Forbidden writes
- 冻结树：Sources/PagingCore/、Sources/AppCatalogCore/、Sources/MacAppCatalog/、Sources/AppIconPipeline/、Sources/PagingTelemetry/、Sources/PagingUI/、Package.swift、**Sources/PagingPrototypeApp/AppLaunchController.swift**
- `AppDelegate.swift` / `AppGridCellView.swift`（第二层范围，见 wave-c2）；`DragSessionController.swift`（其 `.cancelled(.secondDrag)` 保持仲裁的语义照旧）
- Docs/、PROVENANCE/；Workflow/results/ 只允许本任务结果文件

## 5. Required reading (minimal, ≤4 files)
1. Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift — pointerDown(:103-137)、pointerDragged(:140-173)、pointerUp(:176-224)、handleEvents(:264-304)、endSession(:348-364)
2. Sources/AppGridUI/DragSession/DragSessionController.swift — pointerDown(:62-92)、sourcePresent(:263-272)、click 判据(:177-180)（只读，理解 `.cancelled(.secondDrag)` 语义）
3. Sources/PagingPrototypeApp/AppDelegate.swift — installDragUI(:534-604) 中 `clickRecognitionSuppressor` / `onCellClick` / `onOverlayBlankClick` 接线（只读）
4. Tests/ 现有 coordinator 相关测试文件（定位需新增/更新的用例）

## 6. Verification
- swift test 全量：基线 1012 全绿 + suppressor 断言与 20 次配平测试全绿；真实执行标准同前；范围外失败报而不修
- swift build -c debug 与 release 均 exit 0
- 本波是加最小堵漏调用，行数净变化应≈0～微增；结果文件说明行数变化（净删总原则在本波以"不新增机制/状态/字段"为准）

## 7. Acceptance（对用户缺陷 2）
- 直接断言 suppressor 收到 `true`（非仅 `isSessionActive`） + 20 次序列配平。
- 结果文件含 pointerUp/pointerDragged/pointerDown 每 条提前 return 的逐条 endSession 标注清单（2.1）。
- 实机：建夹后点其他 app 能启动；点空白能退出；交替 20 次不退化（脚本 4/7）。

## 8. Output discipline
- 先写 `Workflow/results/T-1F-B6-wave-c.md`（in progress → 终态）；终态附：逐条 return 清单、改动摘要、suppressor 调用次数证据、验收映射。
- 回复 <250 词；不贴大代码块；中性夹具；无 git 操作；事件记录前提 = 本任务包文件已存在。