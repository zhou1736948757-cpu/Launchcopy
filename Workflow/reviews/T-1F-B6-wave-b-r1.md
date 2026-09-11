# T-1F-B6-wave-b — Reviewer 独立审查 r1

Reviewer：Reviewer（独立只读审查）| 声明模型 glm-5.3-flash:cloud | 审查对象：Wave B Worker 结果（deepseek-v4-flash:0731）
任务包：`Workflow/tasks/T-1F-B6-wave-b.md` | 结果：`Workflow/results/T-1F-B6-wave-b.md`

## 0. 唯一判定

# **PASS**

无 BLOCKER / MAJOR。以下 Findings 均为 MINOR（叙述性/预存在/披露级别），不阻断合并。

## 1. 分焦点裁决表

| # | 焦点 | 裁决 | 证据 |
|---|---|---|---|
| ① | 落点语义 = target 原位 + 下标移位 | PASS | LayoutMutation.swift:124-127 逐行核算（见 §2） |
| ② | §2.1 内部矛盾裁决 | PASS（裁决正确） | 手算 (a)(b)(c) 三组，见 §3 |
| ③ | 注释三处与实现逐字一致；契约块其余未动 | PASS | :14-16 / :92-94 / :120-123 同义一致；:1-13、:17-24 契约内容完整；`grep "min 原\|区间内"` 在 Sources+两个 touched 测试文件 0 命中 |
| ④ | 成员序锁 [target, source] | PASS | :117 未动；新测试 ①②③ 均断言 [r_target, r_source] |
| ⑤ | 拒绝路径不回归 | PASS | 新测试④ 覆盖 .duplicateReference/.nestedFolder/.invalidTarget 且断言布局与 generation 原值；既有 32 测全绿 |
| ⑥ | 写范围（mtime 取证） | PASS | 确定性扫描：> 2026-08-31 23:55 全仓仅 3 文件变动（00:01:02 / 00:01:10 / 00:01:54），与披露一致；冻结树（Package.swift 8/28、AppLaunchController 8/28）、ADR-010（8/31 01:52）、Wave A/C 文件（23:0x-23:5x）均在窗外；"CreateFolderBug6/BUG6 wave-b" 标记泄漏扫描仅命中所授权 3 文件 |
| ⑦ | 验证真实性 | PASS | 独立实跑：`swift build -c debug` exit 0、`-c release` exit 0、`swift test` = **Executed 1026 tests, 0 failures**（exit 0，1022+4 严格吻合）；LayoutDomainMutationTests **32/32**；新类恰 4 个 test 方法全绿 |
| ⑧ | 红线与隐私 | PASS | 结果与测试文件均声明 NO_PRIOR_EXPOSURE；夹具 Alpha/Beta/Gamma/Delta + "fixture.…" 合成 bundleID；无真实身份原值 |

## 2. 焦点①：实现逐行核算（独立手算）

实现（LayoutMutation.swift:119-127）顺序为：**先算** `insertion = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex`（:124）→ **再删**两项且按大 index 先删（:125 max、:126 min——删除大下标不使小 index 失真；两次 remove 均无任何 firstIndex 中间态查询）→ **再 clamp** `min(insertion, ordered.count)`（:127）。与任务包 §2 "先算后删再 clamp" 完全一致。

- (a) 相邻左 `[A,B,C]`（t=B idx1, s=A idx0）：insertion=1−1=0；删 idx1→[A,C]、删 idx0→[C]；插 0 → **[F,C]**。旧 min(0,1)=0 → **[F,C]**。同值成立 ✓
- (b) 非相邻 `[A,X,B,C]`（t=B idx2, s=A idx0）：insertion=2−1=1；删 idx2(B)→[A,X,C]、删 idx0(A)→[X,C]；插 1 → **[X,F,C]**。旧 min(0,2)=0 → **[F,X,C]**。**判别成立**：旧实现下新测试③ `testBug6NonAdjacentSourceLeftFolderLandsAtTargetSlotNotSourceSlot` 必 FAIL ✓
- 附（右相邻）`[B,A,C]`（t idx0, s idx1）：insertion=0 → [F,C]；旧 min=0 → 同值 ✓
- 附（target 居左非相邻）`[X,A,Y,B]`（t idx3, s idx1）：insertion=3（else 分支）→ 删后 [X,Y] 插 2 → [X,Y,F]，B 原锚点保持 ✓；clamp 兜底在最坏位（target 倒数第二 + source 末位）下恰为 append，冗余且无害。

边界核查：source==target 已被 :105 前置拒绝；:125/126 删序（先大后小）保证第二次 remove 的下标不被移位破坏。

## 3. 焦点②：任务包 §2.1 内部矛盾裁决——裁定 Worker 裁决正确

- **矛盾确凿**：§2.1 左方向字面 "folder 在索引 1" 与同句自写结果 `[folder, C]` 互斥——[A,B,C] 移除 A、B 后剩 [C]，字面插入 index 1 产出 **[C,F]** ≠ [folder,C]。
- **数学强约束**：§2 权威公式（source 在前 → targetIndex−1=0）+ 收缩后数组 ⇒ 唯一自洽解为 **[F,C]**（folder 下标 0）。故 "索引 1（B 原位）" 只能解读为 **B 的原布局锚点**（folder 取代 B 在 C 前的逻辑位），非最终下标。Worker 拒绝 H2 字面读法正确（H2 会产出 [C,F]，令 C 异常左移，与 §2.1 结果列表直接矛盾）。
- **与用户期望一致**（BUG6-REPORT §1）：folder 形成在"被拖到的 B"处而非"被拖走的 A"处。非相邻构型下新实现 [X,F,C]（folder 在 B 处）vs 旧 [F,X,C]（folder 在 A 处）正是用户可见缺陷的发生条件；相邻两向新旧同值（(a) 与右向均 old=new=0），该处 bug 不可见。
- **测试设计评估正确**：相邻两向（§2.1 ①②）在两语义下同值，故定位为同值回归锁（锁落点/成员序/generation）；target-vs-min 的可观测判别力由补充的非相邻用例③承担——该构型恰是 BUG6 报告缺陷的发生条件（source 与 target 间有间隔条目）。补充 1 条判别用例超出 §2.1 清单但在同文件、同夹具体系内，属合理增益，非语义改动。

## 4. Worker 披露核验（§6 逐条对文件）

1. §2.1 读法裁决 → 与 §3 数学核算一致，成立。
2. 两向同值性 → (a)/右向独立手算 old=new=0，成立；判别用例③已入文件（:79-91）。
3. DragDropTests.swift:336 陈旧注释 → **核实存在**（"新 folder 落在两原位置区间内（min 原 index = 0）"）；断言 `[.folder, app3]` 在新语义同值（target=app2 idx1, source=app1 idx0 → insertion=0=min=0），数值不受影响；该文件属 Wave A 期末（8/31 23:32）mtime，Wave B 未触碰，处置正确。
4. ADR-010 仍写 min 语义 → mtime 8/31 01:52 未动，按 §4 禁写正确，留 Main 合并誊写。

## 5. Findings（分级）

- **MINOR-1（叙述计数不可复现）**：结果 §③ 称 LayoutDomainMutationTests "含 51 处 createFolder 引用逐一核查"；可复现计数为 29 行 / 35 次出现（含注释，忽略大小写）。实质结论（仅 1 件改名、断言同值、其余免改）已被全量 1026 绿验证，不影响判定，但报告数字应修正。
- **MINOR-2（预存在，披露）**：DragDropTests.swift:336 注释沿用 min 框架（断言同值成立）。建议 Main 合并时顺带誊写为新速查措辞。
- **MINOR-3（预存在，披露）**：ADR-010 §Q4 M3 / 实现注记仍写 min 语义，Wave B 禁写正确；Main 合并时修订（可直接采用 :14-16 新速查行）。
- **QUESTION-1（已核，非缺陷）**：§7 "实机脚本 1" Worker 无实机环境未执行，已在结果 ⑦ 声明并给出静态链路（Bug6DropZoneGeometryTests 锁定意图 `.createFolder(target: B)`；engine .createFolder 分支直传 target 未被 Wave A/C 改动）。mutation 层与 domain 层验收已由本审查实跑闭环；实机验收归 Main 合并时执行。风险可接受。
- DBG7 预存在诊断打印在本次实跑中出现且 0 failures，确证非失败信号（Worker 披露⑦一致）。

## 6. 结论理由

实现以"先算后删再 clamp"的单表达式消除 min 落点，注释三处（头速查/doc/实现内）与实现同义一致，契约块其余内容未动；写范围经确定性 mtime 取证恰为授权 3 文件；§2.1 内部矛盾的裁决经独立手算证实为数学上唯一自洽解且与用户可见期望一致；全量 1026/1022+4、debug/release 双配置、LayoutDomainMutationTests 32/32 均由 Reviewer 独立实跑复现。成员序与三条拒绝路径均有测试锁。Findings 全部为 MINOR。**判定 PASS，准予进入 Main 合并**（请 Main 合并时：誊写 ADR-010 M3 与 DragDropTests:336 注释、修正结果文件 MINOR-1 计数、执行实机脚本 1）。

## 6. 独立核验命令与输出摘要（取证）

- mtime（stat）：LayoutMutation.swift 2026-09-01 00:01:02；LayoutDomainMutationTests.swift 00:01:10；LayoutMutationCreateFolderBug6Tests.swift 00:01:54（新建）。`find Sources Tests Docs PROVENANCE -type f -newermt "2026-08-31 23:55"` → 仅上述 3 文件。
- 全量实跑（Reviewer 自行执行）：
  - `swift build -c debug` → Build complete! DEBUG_EXIT=0
  - `swift build -c release` → Build complete! RELEASE_EXIT=0
  - `swift test` → `Executed 1026 tests, with 0 failures (0 unexpected) in 15.9s`，TEST_EXIT=0
  - 逐类行含 `Executed 32 tests, with 0 failures`（既有 LayoutDomainMutationTests）与 4-test 新类。
- 泄漏扫描：`grep -rln "CreateFolderBug6\|BUG6 wave-b" Sources Tests Docs` → 仅授权 3 文件。
- 残留扫描：`grep "min 原\|两原位置区间内" Sources/ + 两 touched 测试文件` → 0 命中（唯一残留在 DragDropTests.swift:336，见 MINOR-2）。