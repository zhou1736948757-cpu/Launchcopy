# MANUAL_TEST_STEPS.md — Step 8 真实物理验收手册（等待用户执行）

- **创建**：2026-08-28（T-step8 准备，Main）
- **性质**：自动化全部通过后的**人工**验收步骤。本文件不是 PASS 声明——任何执行结果须由用户（或经用户授权）在真实 GUI + 触控板上完成并回填 `Docs/VALIDATION_RESULTS.md`。
- **纪律**：60Hz/120Hz 物理门**未执行 = NOT_RUN**；无 120Hz 证据 = BLOCKED，不写 PASS；禁止用 synthetic probe（合成事件/runloop 帧泵）代替真实触控板；禁止删除异常 run。

## 0. 运行准备

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
swift run PagingPrototypeApp --page-count 5 --items-per-page 35          # 常规验收负载
swift run PagingPrototypeApp --page-count 20 --items-per-page 35        # 压力模式
swift run PagingPrototypeApp --paging-telemetry --run-id phys-60hz-01   # 正式 run：开 telemetry
```

- telemetry 日志：`/tmp/launch-copy-paging-prototype-<run-id>.jsonl`（每次正式 run 独立文件，保留勿删）。
- Debug/Release 二选一并在环境证据中记录；建议正式验收用 `swift run -c release`。
- 参数帮助：`swift run PagingPrototypeApp --help`；`--reduce-motion-override on|off|system` 覆盖 Reduce Motion。

## 1. 环境证据（每组正式测试前记录，11 项，Prompt §8.1）

```text
Mac 型号：
macOS 版本：
显示器：
分辨率与缩放：
实际刷新率（系统设置显示-刷新率 或等效证据）：
触控板类型（内置/外接，型号）：
Reduce Motion 状态（系统设置-辅助功能-显示）：
Debug 或 Release：
commit/hash（当前无提交，记录 .build 产物 SHA-256 或源码快照）：
是否接电：
是否有明显后台负载：
```

## 2. 页面矩阵（§8.2，至少）

```text
1 页 / 2 页 / 5 页 / 10 页 / 20 页压力模式
```

每个预设至少跑一次完整手势矩阵（见 §3）。

## 3. 手势矩阵（§8.3，每个关键配置至少测试）

```text
1.  慢速拖动后回弹
2.  慢速拖动后翻页
3.  快速甩动
4.  小幅快速输入
5.  settle 中同向接管
6.  settle 中反向接管
7.  连续快速来回
8.  首页向外拉
9.  末页向外拉
10. 滑动时 resize（拖动窗口宽度）
11. 滑动时关闭窗口
12. Reduce Motion（系统开启 + --reduce-motion-override on）
```

## 4. 正确性硬门（§8.4，出现任何一项即不能 PASS）

```text
跳回旧位置 / 一次手势 commit 多次 / 旧 completion 改写新页 /
空白、重复或错页 / 越界 / resize 后错位 / 关闭后仍有 callback（旋转风扇/日志持续）/
崩溃 / telemetry 无法对应 gesture 和 transition / 删除异常 run 美化结论
```

## 5. 主观评分（§8.6，每个正式 run 保存原始分与备注，保留低分/异常 run）

```text
跟手性：1–5
中断连续性：1–5
settle 自然度：1–5
边界反馈：1–5
总体丝滑度：1–5
备注（自由文本）：
```

## 6. 60Hz 目标（§8.5；自动探针已 PASS 的项在此复核）

- 正式 run 无无法解释的 >50ms 主线程 hitch（telemetry frame interval 可辅助）
- 手势热路径无可见同步卡顿（同步重资源加载不存在——热路径只做几何变换）
- 中断时无可见跳变
- 主观"跟手、连续、settle"三项中位数均 ≥ 4/5

## 7. 120Hz（§8.5）

- **仅当**能证明实际 120Hz 刷新率（显示器+系统设置证据）才执行并标记；
- 不使用 60Hz 结果推断；不使用 synthetic probe；
- 目标：frame miss ≤ 2%、无 >33ms 不可解释 hitch、主观三项 ≥ 4/5；
- 无 120Hz 设备或无法证明 → `MANUAL_PHYSICAL_GATE_120HZ = BLOCKED`（不写 PASS）。

## 8. 结果回填（用户/授权执行后由 Main 登记）

每完成一组正式 run：把环境证据、各矩阵结果、主观原始分、异常 run 观察追加到 `Docs/VALIDATION_RESULTS.md`，更新：

```text
MANUAL_PHYSICAL_GATE_60HZ  = PASS / FAIL / BLOCKED / NOT_RUN
MANUAL_PHYSICAL_GATE_120HZ = PASS / FAIL / BLOCKED / NOT_RUN
```

并同步 `Docs/IMPLEMENTATION_LOG.md`（Step 8 记录：文件/证据/未完成项）。
