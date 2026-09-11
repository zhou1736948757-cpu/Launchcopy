# T-1F-B6-wave-a Review r1 — BUG6 Wave A（缺陷 3+4：drop-zone 几何重写 + insertion off-by-one）

Reviewer: chef-worker-reviewer-workflow v1.4.1 / 独立只读审查（声明模型 glm-5.3-flash:cloud）
审查对象: Workflow/results/T-1F-B6-wave-a.md（Worker: deepseek-v4-flash:0731, Status: done）

## 唯一判定

# **PASS**

（可合并；附 3 条 MINOR 与 2 条 QUESTION，均不构成 BLOCKER/MAJOR）

## 独立核验记录（非转录，本人实跑/实读）

- **实跑**：`swift build -c debug` exit 0；`swift build -c release` exit 0；`swift test` 全量 **Executed 1022 tests, 0 failures (0 unexpected)，exit 0**（真实执行，非 exit0+executed0）。
- **实跑分套件**（--filter）：DragDropTests **36**/0；DragSessionControllerTests **22**/0；DragUISessionCoordinatorTests **18**/0（含 MARK-12 ×3 全绿）；Bug6DropZoneGeometryTests **10**/0（86 = 36+22+18+10 交叉印证）。
- **实读**：DropIntent.swift（239 行全文）、DragMutationEngine.swift（81 行全文）、FolderOverlayView.swift（452 行，`memberDragItemFrames`:106-116 原样）、Bug6DropZoneGeometryTests.swift（254 行全文）、DragDropTests/ControllerTests/CoordinatorTests 结构 grep、DragUIIntegrationTests 抽读。
- **Mtime 取证**（git 仓库无历史提交，无法 diff；以 mtime 圈定 wave-a 窗口 ≈23:28–23:52）：窗口内仅 DropIntent.swift(23:52)、DragMutationEngine.swift(23:52)、Bug6 新增(23:48)、DragDropTests(23:32)、DragUISessionCoordinatorTests(23:39)、DragSessionControllerTests(23:28)。FolderOverlayView(09:29)、DragParameters(01:57)、LayoutMutation(00:34)、DragSessionController(02:13)、DropResolver(02:13)、AppDelegate(15:39)、DragUISessionCoordinator(23:09→Wave C)、Package.swift(08-28)、冻结树 PagingCore/AppCatalogCore(08-28/30) 均在窗口外，**零 wave-a 写入**。

## 审查焦点逐条判定

| # | 焦点 | 判定 | 证据（行号） |
|---|---|---|---|
| ① | zone 表删除而非旁置 | **PASS** | `grep -r "insertionZones\|appCenterZones\|topLevelLandingZones\|AppCenterZone" Sources/` 零命中；`DropZones` 重构为 itemFrames/topLevelFrames/folderCellZones/moveOutArmed/marginPT（DropIntent.swift:129-152）；纯函数 hitItem(:49-55)、hitZone(:59-71)、insertionIndex(:90-125) 按 §2b 语义实现；folderCellZones 构建保留(:168-173) |
| ② | 无死区 | **PASS** | `classify`(:180-215) 任何指针必有产出：仅两条 .invalid 路径均为规格化拒绝（folderCell×topLevelFolder :185、app 中心×topLevelFolder :191=Q14），其余全产 .insertion/.createFolder/.intoFolder/.topLevelTarget；空帧 insertionIndex→0(:92)。死区锁测试真实：3×2 网格 6×9=54 九宫格点+列缝/行缝+页边距/角点（Bug6:109-159），源=顶层 app，断言零 .invalid |
| ③ | off-by-one | **PASS** | `reorderAdjustedIndex`（DragMutationEngine.swift:77-80）：源在槽位左侧 → −1；三类 reorder 源全部经换算(:30-32,:37-39,:44-46)；`moveOutOfFolder` 不换算合理（成员不在顶层序，:.68 直接透传，:76 注释固化）；双方向锁真实存在并经实跑：Bug6:163-185（A→B右=[B,A,C]；C→B左=[A,C,B]）、:187-212（folder 内双方向） |
| ④ | folder 内降级 | **PASS** | classify `.folderMember` 分支(:201-213) 中心降级半区插入（中线归右，hitZone :70）；正向锁 testFolderMemberCenterDegradesToInsertionNotInvalid（Bug6:97-105，断言非 .invalid 且 =.insertion(2)）+ DragDropTests:265 + 集成级 DragUIIntegrationTests:434-460 实测 [Beta,Alpha] commit |
| ⑤ | 净增 +52 理由 | **PASS（有理由的净增）** | 删除属实（②grep 零残留），无"旧逻辑旁置"（DropZones 无遗留字段）。+52 = DropIntent +29 + Engine +23：§2b 强制的纯函数算法（行划分+最近行+中点计数，覆盖 miss 全情形）与 §2c 强制的 engine 换算是规格本身要求的内容，非 scope creep。§6 判据为"净增必须说明理由否则 FAIL"——Worker 结果 §4 已完整说明并给出可再降方案 → 不触发 FAIL |
| ⑥ | 写范围 | **PASS** | Sources 层仅 §3 授权两文件（mtime 圈定）；ControllerTests/CoordinatorTests 的预期更新属授权条款："允许更新现有 DropZone/DropIntent 相关测试中编码旧几何语义的预期"——(90,40) 旧缝带点在新几何为自身格左半 no-op， relocation (155,40)=B 右半保留"合法 drop→commit"测试目的，判定合规。**Wave C 共存**：MARK-12 三用例在位（CoordinatorTests:519/551/580）且 18/18 实跑全绿，无互相覆盖丢失。禁写清单全部 mtime 窗口外 |
| ⑦ | 验证真实性 | **PASS** | 本人实跑复现：总 1022/0/exit0，与审查提示预估**1022 = 1015(Wave C 基线)+10−3 精确吻合**；debug/release exit 0；各分套件计数见上 |
| ⑧ | 红线 | **PASS** | NO_PRIOR_EXPOSURE 声明；夹具中性（fixture.appN/mN、App%02d、固定 UUID 00000000-…-001）；Review 全程零 git 写操作；未发现真实身份数据 |

## Findings

### MINOR
1. **M1** `Tests/PagingUITests/DragUIIntegrationTests.swift`：Worker 报告"未修改，9/9"，但实跑该套件为 **10 tests, 0 failures**，且文件含 10 个 `func test`（:273-573），mtime 23:49 落在 wave-a 窗口内。因无 git 历史无法归因（可能为 Wave C 合并期写入）。**影响**：无（全部通过，内容与 BUG6 语义一致——:434-460 成员重排集成锁反而强化缺陷 4 证据）。**建议**：Main 确认该文件 23:49 状态来源；Worker 报告的执行计数台账需按实际 10 修正。
2. **M2** 结果文件改动计数存在 ±1 台账误差（实 grep ControllerTests：8 处 (50,40)→insertion(1)、5 处 (10,40)→insertion(0)、4 处 (155,40) pointerUp，Worker 报 7/4/3）。同一文件、同一改法，无预存/新增归因手段，不影响范围判定。
3. **M3** Worker 基线计数（1012+3 差额"未深究"）与包预期（1015）不符：本审查实跑 1022 已闭合差额（1015+10−3=1022），Worker 未自证，留此存档。

### QUESTION（报 Main/Chief 裁定，不阻塞）
1. **Q1（M5 deviation 采纳性）**：`isTopLevelLanding`（DropIntent:77-84）为 packet §2b 未明文列出的新增纯函数。判定**可接受**：§2b 只规定"landing 复用插入位函数"，未规定可达性谓词；该函数收敛于旧 landing 带语义（armed+行带内+非条目内部可落，深入条目回退 inner 插入），已测试锁定（Bug6:216-235），并防 armed 成员误触发 folder dissolve。建议 Chief 记 Memory（Worker 已候选）。
2. **Q2**："isTopLevelLanding 与旧 landing 带覆盖一致"的声明无法独立核验（旧代码已重写、无 git 历史）；基于测试+语义自洽采信。若 Main 需要更强证据，可要求 Worker 补提交旧文件快照。

## Worker 风险注记逐条判断（结果 §5）
1. 零帧行并合（`minY <= bottom`，DropIntent:99）：**接受** — 真实网格行距 16pt 无并合；退化仅影响零帧测试台，根因已上报未越权修复（范围纪律正确）。
2. 源自身格不再 .invalid：**接受** — §2a 无死区的直接后果，引擎换算后 no-op（Bug6:62-67 已锁）。
3. M5 新增纯函数：见 Q1，接受。
4. 集成夹具零帧工件：正确上报不修，报Main。
5. containerWidth 保留签名兼容：DragSessionController.swift 未动（mtime 02:13）✓。

## 结论理由
缺陷 3（B 右半 → insertion(2)→[B,A,C]）、缺陷 4（成员中心降级插入）在分类器、引擎、三层测试（纯函数/控制器/集成）均独立验证成立；死区锁与 off-by-one 双方向锁真实且全绿；1022 实跑与包公式精确吻合；写范围经 mtime 取证零越界；Wave C MARK-12 共存无损；净增 +52 的理由按 §6 判据成立。判定 **PASS**。