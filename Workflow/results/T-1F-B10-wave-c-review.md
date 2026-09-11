# Reviewer Verdict — T-1F-B10-wave-c（BUG10 缺陷 C：insertionIndex 坐标系反向 y-up）

- **Reviewer**: glm-5.3-flash:cloud（独立只读门禁，零文件修改）
- **日期**: 2026-09-02
- **结论**: **PASS**（7/7 项核验全过）

## 逐项核验

### 1. 写范围合规 — PASS
- mtime 扫描（`find Sources Tests -newer <task>`）：任务包落盘 16:33:22 后仅 2 文件变更——`DropIntent.swift`（16:39:56）、`Bug6DropZoneGeometryTests.swift`（16:41:24）。
- 冻结树全部早于任务：PagingCore 08-30 / AppCatalogCore 08-28 / MacAppCatalog 08-28 / AppIconPipeline 08-29 / PagingTelemetry 08-28 / PagingUI 08-30 / Package.swift 08-28 / AppLaunchController.swift 08-28。
- 禁写文件零触碰：DragUIVisuals.swift（09-01）、DragParameters.swift（08-31）、DragGeometry.swift（09-01）均早于任务。
- `insertionRect`（DragUIVisuals.swift:191-206）逐行核对：`index >= count` 取末帧右缘分支原样在位；`hitItem`（DropIntent.swift:49-55，调用点 :237/:262）未动；DragParameters 无新字段。

### 2. 坐标系无关实现 — PASS
- 行划分（DropIntent.swift:96-112）为双向重叠判定 `frames[end].frame.minY <= bottom && frames[end].frame.maxY >= top`，并集扩张 `top = min / bottom = max`；无 y 方向硬编码，无单向比较残留（:104 的 `minY <= bottom` 是双向判定的第一半，非残留）。
- 零尺寸帧并入语义保留：边界含等号；独立验证全零帧（y=0, w/h=0）并入单一阅读行。
- 行序 = 阅读序：`range.lowerBound` 作更早行条目总数；[5,5,3] 网格下行 1 首前=5、行 2 首前=10 独立复算一致。

### 3. 注释与实现一致 — PASS
- :86-90 注释「行 = 竖直区间互相重叠的连续段（坐标系无关…方向由帧自身竖直区间给出；帧按阅读序传入，行序即阅读序）」与实现逐句对应。
- :97「当前行竖直区间 = 已并入帧的 minY...maxY 并集；后续帧与区间重叠 → 同行」与 `top/bottom` 并集扩张一致。
- :101-102「零尺寸帧并入当前行（区间重叠判定含边界）」与含等号判定一致。

### 4. 回归锁完整 — PASS
- y-up 夹具（:43-57）镜像生产：`y = maxY - (row+1)*pitch`，maxY=600 / pitch=104 / 5 列 / spacing 16 / cellHeight 88 / 宽 87.2，与 FIX-PROMPT §2.2 几何逐值吻合（x=24.0..436.8，y=496/392）。
- 主症状锁（:279-282）：(530,540) → 5，独立复算 = 5 ✓。
- ≥3 行缝隙锁（:285-296）：[5,5,3] 全部 5 断言独立复算一致（0/5/6/10/1）✓。
- 闭区间边界锁（:299-310）：9×6=54 采样点独立复算 0 越界 ✓。
- 顶层同构锁（:313-323）：5 断言独立复算一致（0/5/5/10/13=count）✓。
- 既有 y-down 断言全部保留（文件 :75-273 原样在位），坐标系无关实现两者皆过——独立复算 y-down 5 断言全 OK。

### 5. 复现证据 — PASS
- 结果文件含修前 `rowRanges=[0..<8]` / `insertionIndex=8` 与修后 `[0..<5, 5..<8]` / `index=5` 读数。
- Reviewer 重跑 `/tmp/bug10c_repro.swift`（逐字抄出修前实现）：`rowRanges = ["0..<8"]`、`insertionIndex = 8`、`>>> index >= count → 末帧右缘`——与结果文件逐字吻合；修后算法同输入独立复算 = 5。

### 6. 测试证据 — PASS
- 结果文件含 `swift test` 全量原文：`Executed 1066 tests, with 0 failures (0 unexpected) in 53.190 (53.587) seconds` + 过滤套件 14/0。
- Reviewer 实测复跑：全量 **1066/0**（60.117s，exit 0）、过滤套件 **14/0**（0.050s，exit 0）——与声明一致。基线 1062 + 新增 4 = 1066 成立。

### 7. 纪律 — PASS
- 无 git 变更操作（仓库零 commit、全 untracked；`git status` 只读自证 + mtime 扫描替代 `git diff --stat`，结果文件已如实说明）。
- 禁读来源仅出现在「未读取」声明（合规披露，非引用）；无大代码块（82 行结果文件，仅 2 行列表续行缩进）；隐私中性（无真实 app 名/bundleID/坐标，夹具几何为 FIX-PROMPT 已发布几何）。

## Deviations / 风险

- **无 FAIL 级 deviation**。唯一说明项：任务包 §6 要求「git diff --stat 自证」，仓库无 commit 无法执行，Worker 以 mtime 扫描替代并披露——可接受，且 Reviewer 独立 mtime 扫描证实改动面 = 声明 2 文件。
- 风险：无。实现为纯函数单点修复，与 hitItem/insertionRect 不同源设计保持（未「顺手统一」），符合 D1/D4 定案。

## 结论

**PASS** — 达到合并标准。可交 Main 合并。
