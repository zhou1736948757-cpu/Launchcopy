# T-1F-B7-wave-a — Result

Status: completed
Worker: fresh context, AccessDeclaration: NO_PRIOR_EXPOSURE（未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何 Ghidra/otool dump）。无 git 操作。

## Main 授权追加收尾（repair_created 后；写范围临时扩展 = DragDropTests.swift 该测试）

- `Tests/AppGridUITests/DragDropTests.swift` `testEngineM3CreateFolderTargetThenSource`（:325-337）期望同步为格子位置语义：
  guard 从 `topLevelOrder.first`（folder 在头）改为 `topLevelOrder[1]`（folder 在 drop 目标 app2 原格）；
  期望 `[.folder, .app(app3)]` → `[.app(app3), .folder(folderID)]`；
  注释由 "source 在 target 前：targetIndex − 1 = 0" 改为 "落在 drop 目标 target 原位（格子位置语义；不做 targetIndex-1；BUG7 wave-a）"。
  该文件其余测试零改动。

## Changes（写范围 = 2 文件 + 上列授权文件，find 自查无越界）

1. `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift`
   - :124（现 :124）`let insertion = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex` → `let insertion = targetIndex`（先删 max/min 与 clamp 不变）。
   - 注释三处同步为"落点 = drop 目标 target 原 index（格子位置语义；不做 targetIndex-1）"：文件头速查（原 :14-16）、createFolder doc（原 :92-94）、函数内注释（原 :120-123）。
2. `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift`（重写期望；文件名/类名保持）
   - 左方向 [A,B,C] A→B ⇒ `[C,F]`；右方向 [B,A,C] ⇒ `[F,C]`；非相邻 [A,X,B,C] ⇒ `[X,C,F]`。
   - 成员序锁 `[B,A]` 在三条成功用例全断言；generation=1、validator 零 issue。
   - 拒绝路径 `.duplicateReference`/`.nestedFolder`/`.invalidTarget`/`.staleGeneration`（补齐第 4 条断言，见 deviation）。

## Verification evidence（真实执行；追加收尾后终版）

- `swift build -c debug` → exit 0
- `swift test`（全量，无管道取权威 exit）→ **exit 0；executed 1026，0 failures**；testEngineM3CreateFolderTargetThenSource passed
- `swift build -c release` → exit 0

（首次验证历史证据：debug exit 0；swift test exit 1 / executed 1026 / 1 failure（范围外 DragDropTests 旧语义断言，已按上节授权同步）；release exit 0。）

## Acceptance 映射（任务包 §7）

| 项 | 用例 | 结果 |
|---|---|---|
| `[A,B,C]` A→B ⇒ `[C,F]`（folder index 1 = B 原格） | testBug6LeftDirectionFolderLandsAtTargetSlot | PASS |
| `[B,A,C]` A→B ⇒ `[F,C]` | testBug6RightDirectionFolderLandsAtTargetSlot | PASS |
| `[A,X,B,C]` A→B ⇒ `[X,C,F]`（folder index 2 = B 原格） | testBug6NonAdjacentSourceLeftFolderLandsAtTargetSlotNotSourceSlot | PASS |
| 成员序 `[target,source]=[B,A]` 锁 | 三条成功用例内断言 | PASS |
| 拒绝路径 4 条不回归 + 无半提交 | testBug6RejectionPathsUnchanged | PASS |
| 注释/实现一致（三处） | Reviewer 可 diff :14-16/:92-94/:120-123 | 已同步 |

## Out-of-scope failure（首次验证时报告，已按 Main 授权收尾）

`Tests/AppGridUITests/DragDropTests.swift` `testEngineM3CreateFolderTargetThenSource`（:325-337）曾断言**旧 wave-b 语义**：[app1,app2,app3] app1→app2 期望 `[F, app3]`（folder 在头，注释明写 "targetIndex − 1 = 0"）。修复后实际 `[app3, F]` → 首次全量 1 failure。Main 授权后已按"Main 授权追加收尾"节同步（guard 改 `topLevelOrder[1]` + 期望 `[app3, F]` + 注释），该用例现已 passed，全量 0 failures。其余 createFolder 调用点（LayoutDomainMutationTests/WorkspaceLayoutInvariantTests/PagingUITests/Provider 测试）均为 target 在 source 左（两公式同值）或预构建布局，不受影响，全绿。

## Deviation

1. 拒绝路径测试补断言 `.staleGeneration`（任务包 §2 列出 4 条"保持不回归"，原文件只有 3 条；在写范围内补齐，未改语义）。
2. 范围外 1 failure 首次验证时只报告不修，随后按 Main 授权同步（见"Main 授权追加收尾"节）。
3. DragDropTests 期望同步时发现 `topLevelOrder[1]` 非可选（数组下标），guard 模式去 `?` 后编译通过——仅该测试内语法适配。

## 其他

- 隐私：夹具中性（Alpha/Beta/Gamma… → fixture.* 合成 ID），无真实应用名/bundleID/路径。
- DragMutationEngine.swift :49-54 只读确认：`.createFolder` 调用点不传 index，不受影响。