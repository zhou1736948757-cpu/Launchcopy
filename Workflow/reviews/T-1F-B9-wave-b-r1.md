# T-1F-B9-wave-b-r1 — Reviewer 独立审查（BUG9 取证补盲 Stage 1）

Reviewer: chef-worker-reviewer-workflow 独立 Reviewer（只读门禁，未编辑任何实现文件）
对象: Workflow/results/T-1F-B9-wave-b.md（Stage 1）；任务包 §1-§8；BUG9-REPORT §5
**唯一判定: PASS**

## 独立实跑证据（Reviewer 本机真实执行，2026-09-01 23:0x）

- `swift build -c debug` → `Build complete!`，**exit 0**。
- `swift build -c release` → `Build complete!`，**exit 0**。
- `swift test` 全量原文：`Executed 1062 tests, with 0 failures (0 unexpected) in 29.361 (29.601) seconds`，**exit 0**（与 Worker 1062/0 互证一致；1052 基线 + 3 本波 + 7 wave-a 对账成立）。
- 3 新测试隔离跑：`Executed 3 tests, with 0 failures (0 unexpected)`，exit 0。

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR
1. **key1 翻转断言条件执行**（DragCommitIntegrationTests.swift:958-970）：key 夹具腿的 key1 断言包在 `if window.isKeyWindow` 内，沙箱 key 授权恒拒 → 该断言在 CI/沙箱中恒走 else 分支。属已声明 deviation#2（三份探针脚本佐证、s8e 计数与 key 无关、key1 读数由 Main E 序列回填），补偿控制存在，但 Main 实机回填前 key1 位只有变体名编码测试（test…VariantNames…，硬断言 4 变体互异）在守护。可接受。
2. **「wave-c 既有断言零改动」不可字节级复核**：红线禁 git，Reviewer 无法 diff 基线。间接证据充分：全量 1062/0 绿、wave-c 既有 sink 断言（s8/s8b/s8c/s8d 等）全通过、fixture 仅新增 census 行（:282-292 与生产 :603-615 逐 token 同构）。采信。

### QUESTION
1. DragUISessionCoordinator.swift mtime=22:02:38，早于 wave-b 写窗口（23:00-23:05）；文件内无 wave-b 标记（suppressor 调用点 :488/:495 为 T-1F-D1 原有代码），归因并行 wave-a，非 wave-b 违规。仅记录。

## 焦点逐项核验

- **A 零行为变更**：PASS。s8e（AppDelegate.swift:1069-1074）为 leftMouseDown 分支首行纯计数 + 两 bool 只读，置于 `if let contentView` 之前，无 return/无分支改动；s13（:603-615）census 插入闭包内 for-loop 之前，for-loop 原样。全仓 grep `acceptsFirstMouse`/`windowDidEnterFullScreen` 零命中 → Stage 2 预授权项未偷跑，无「顺手修」。
- **B s8e 正确性**：PASS。每 leftMouseDown 无条件计一次；sink 名携带 `key{n}_active{n}`（:1151-1153，4 变体互异有测试）；仅入内存 snapshot（stderr 仅 `PAGING_CLICK_CENSUS <sink> <n>`，env 门控沿用）；无标题/坐标/应用名。
- **C s13 方向**：PASS。coordinator `beginArbitration→suppressor(false)`（DragUISessionCoordinator.swift:484-489）、`endSession→suppressor(true)`（:491-497）；闭包 `enabled ? s13b_disable : s13a_enable` → false=抑制启用→s13a，true=恢复→s13b，映射正确。deviation#3 所称首版接反在终态（生产+fixture）中均不存在，两处闭包逐 token 同构。
- **D 测试**：PASS。3 新测试断言真实（key0 硬断言+总数==2、4 变体名精确串+互异、两会话 s13a/s13b 2:2 且与 s9b 等值、s9_leak==0）；fixture 走真实 `QuitOnBlankClickWindow`（:546-548），s8e 经 `window.sendEvent` 真实触发。
- **E 写范围**：PASS。mtime 取证：wave-b 窗口内仅 AppDelegate.swift(23:03:12)+DragCommitIntegrationTests.swift(23:05:29)；AppLaunchController.swift(8/28)、FolderOverlayView.swift(8/31)、冻结树各目录、Package.swift 均不在 24h 变更列表；Docs 未触碰。
- **F 独立实跑**：PASS（见上，1062/0 原文互证）。
- **G Stage 2 判定**：PASS（合理）。两项预授权的触发条件均为实机读数（死点击时 !isKeyWindow/!isActive 分布；抑制滞留），单测健康基线（s13a==s13b、s9_leak==0）只是装置健康证据，不构成触发证据；「均不触发、待 Main E1-E5」是任务包 §3「读数触发才动」的正确保守执行，实机 E 序列确为唯一触发依据。
- **H 红线**：PASS。Sources/Tests 无 LaunchBetter/BuhoReverseNotes/buho-launchpad 引用（results 中仅 AccessDeclaration 声明行）；NO_PRIOR_EXPOSURE 已声明；隐私中性；Reviewer 全程无 git 操作。

## 结论

Stage 1 达成任务包 §5/§6 全部要求，零行为变更成立，测试真实且全量绿，写范围干净。放行 Main 合并；Stage 2 维持「均不触发、待实机 E1-E5 读数」判定。