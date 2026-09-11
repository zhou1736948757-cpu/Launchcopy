# T-1F-B7-wave-a — BUG7 Wave A′: createFolder 落点重定（folder 顶替 B 原格，缺陷 1）

Status: ready
Wave: BUG7 A′（无依赖，可立即派发；与 Wave B′ 写范围不相交，可并行 — Main 记 `concurrency_check`）
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified — 带行号已对照源码实测)

- 用户期望（字面）：拖 A 到 B 上建夹 → folder 出现在 **B（drop 目标）的格子**。BUG6 Wave B 按"相对锚点"裁决（索引 1 = B 原布局锚点），用户实机否定 —— 语义必须按**格子位置**（BUG7-REPORT §6.1 教训）。
- 现状公式（BUG6 wave-b 引入，BUG7-REPORT §1 定位，已实测一致）：`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:124`
  `let insertion = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex`
  后随 :125-126（先删 max 再删 min）、:127（`min(insertion, ordered.count)` clamp）。
- 手算（Main 核验，Chief 复核）：`[A,B,C]` A→B（source=0,target=1）→ insertion=0 → `[F,C]`，folder 在 **A 的格子** —— 与修 BUG6 前现象逐字相同（相邻时 targetIndex-1 == min）。`[B,A,C]` A→B → `[F,C]` 碰巧正确。`[A,X,B,C]` A→B（target=2）→ `[X,F,C]`，比 B 原格**左偏一格**。
- 成员序 `[target, source]`（:117）正确，**不动**。
- 注释同带旧语义（注释与实现不一致 = Reviewer FAIL，Wave B 教训）：文件头速查 :14-16、createFolder doc :92-94、函数内注释 :120-123，三处均写"source 在 target 前时 targetIndex-1"。

## 2. Fix spec

公式（**已定案，不改**）：

```text
let insertion = targetIndex
ordered.remove(at: max(targetIndex, sourceIndex))
ordered.remove(at: min(targetIndex, sourceIndex))
ordered.insert(.folder(id), at: min(insertion, ordered.count))
```

- 落点 = target 的**原 index**（folder 顶替 B 原格）；clamp 兜底、先删 max 再删 min 均不变。
- 验收表（Main 手算确认）：`[A,B,C]` A→B ⇒ `[C,F]`（folder 在 index 1 = B 原格）；`[B,A,C]` A→B ⇒ `[F,C]`；`[A,X,B,C]` A→B ⇒ `[X,C,F]`（folder 在 index 2 = B 原格）。
- 成员序锁：新 folder record members == `[target, source]`（即 `[B,A]`）不变，加断言锁住。
- **验证优先 mandate**：先读 `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift` 现有断言，再重写期望——左方向 `[C,F]`（现可能写 `[F,C]`）、右方向 `[F,C]`、非相邻 `[X,C,F]`（现可能写 `[X,F,C]`）；成员序 `[B,A]` 锁；拒绝路径（`.duplicateReference`/`.nestedFolder`/`.invalidTarget`/`.staleGeneration`）断言保持不回归。
- 注释同步（三处）：:14-16 头速查行、:92-94 doc、:120-123 函数内注释 → 全部改为"落点 = drop 目标 target 原 index（格子位置语义；不做 targetIndex-1）"。
- **ADR-010 M3 誊写由 Main 在合并时做；Worker/Chief 不碰 `Docs/`**（红线）。

## 3. Write scope

- `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift`（仅 createFolder 落点行 :124 + :14-16/:92-94/:120-123 注释同步）
- `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift`（重写期望）

## 4. Forbidden writes

- 冻结树全列：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`；`Sources/AppGridUI/DragSession/` 全部；`Sources/AppGridUI/DragParameters.swift`
- **`Docs/`**（ADR-010 归 Main）、`PROVENANCE/`；`Workflow/results/` 仅本任务结果文件

## 5. Required reading (minimal, ≤4 files)

1. `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift` — 头速查 :12-21、doc :89-96、实现 :119-127
2. `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift` — 现有期望（待重写对象）
3. `Workflow/BUG7-FIX-PLAN.md` §2（验收表与"不 revert 到 min"边界）
4. `Sources/AppGridUI/DragSession/DragMutationEngine.swift` :49-54（.createFolder 调用点，只读确认不受影响）

## 6. Verification

- `swift build -c debug` → exit 0
- `swift test`（全量）：基线 1026 + 重写测试全绿；范围外失败只报告不修
- `swift build -c release` → exit 0

## 7. Acceptance（缺陷 1 映射）

- 三构型两方向 + 非相邻全部按**格子位置**通过：`[C,F]` / `[F,C]` / `[X,C,F]`；成员序 `[B,A]` 锁在。
- 用户验收一句话：把 A 拖到 B 上 → folder 出现在 **B 原来的格子**，C 补到左边。

## 8. Output discipline

- 先写 `Workflow/results/T-1F-B7-wave-a.md` 为 in-progress；终版含改动清单、验收映射、测试证据（exit code + executed tests 数）。
- 回复 <250 词；无大代码块；隐私中性 A/B/C；无 git；声明 AccessDeclaration。