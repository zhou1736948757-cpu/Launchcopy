# T-1F-B10-wave-a-fix — BUG10 缺陷 A 实现（BLOCKED：取证读数前置）

Status: **blocked**
BLOCKED 条件：wave-a-forensics 合并 + 用户实机 6 步复测读数回 Main + 判别表（FIX-PROMPT §4.4 / forensics 包 §7）命中某行后，由 Main 解除并圈定本包写范围。**在证据回填前禁止写任何实现代码**（FIX-PROMPT §0 红线）。
Wave: BUG10-wave-a-fix（解除后与 wave-b 可能共写 AppDelegate/FolderOverlayView——按命中行重新裁决串行/并行）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并

## §1 背景（假设，待取证证实）

census run2 :64-71：空白点击关 folder（s4a+s4d）之后，23 次点击 s8d 全放行而 s10 恒不增。静态假设=closeFolder（AppDelegate.swift:774-782）只 removeFromSuperview、FolderOverlayView.hitTest:297-303 非按钮恒 self → overlay 残留吞事件。候选残留机制（forensics 待证实其一）：refreshFolderOverlay:824 `superview == nil` 判断与 closeFolder 移除竞��；folderOpenState?.close() 与视图移除顺序致某路径重新挂回；或 overlay 未移除仅 clearContent（clearContent 不移除视图，FolderOverlayView.swift:216-226）。

## §2 判别表命中行 → 写范围预案（解除时按实际命中行定死，未命中行不写）

| 命中行 | 写范围 | 修法定性 |
|---|---|---|
| 假设成立（overlay 残留命中） | FolderOverlayView.swift（hitTest 生命周期/superview 契约）+ AppDelegate.swift（closeFolder/refreshFolderOverlay 移除幂等） | 修「移除不彻底/hitTest 吞残留」；closeFolder 语义审计（cancel :775/clearContent :781/removeFromSuperview :782 顺序与幂等） |
| s7b（launchMember 静默 guard） | AppDelegate.swift 仅 launchMember 调用方/合成 cell revision 来源 | 不碰 AppLaunchController |
| sA_launch_rejected_* | AppDelegate.swift 仅 handleCell 调用方（合成 cell revision 重建策略） | AppLaunchController.swift:129-143 **冻结不改**（FIX-PROMPT §5） |
| 步 6 也复现 | 无 | 回 Main 重新定位，本包作废重拆 |

## §3 硬红线（预案也适用）

冻结树全列零触碰（含 Package.swift）；不新增 DragParameters 字段；census sink 中性名+计数+布尔位；禁读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/Ghidra/otool；隐私 A/B/C；无 git；注释与实现不一致 = Reviewer FAIL。修复验收（FIX-PROMPT §6）：建夹 → 开 folder → 关 folder → 顶层点击**能启动**；s10 正常增；BUG9 既有回归（hitTest 漏斗/空白退出）全绿。

## §4 解除程序

1. Main 确认 forensics results 读数 + 判别命中行；2. Main 在本文件 Status 改 ready 并圈定 §2 对应行写范围（其余行删除）；3. Worker 领包；4. Reviewer 独立 PASS；5. Main 合并。**未走 1-2 的任何实现 = 越权，Reviewer 直接 FAIL。**