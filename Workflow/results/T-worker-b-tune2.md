# T-worker-b-tune2 — momentum-decay 范围扩展（0.50–0.99）

**Worker**: B/D 同人
**来源**: 物理调参第 2 轮，用户反馈："滑行时长还是太长，你把滑行时长改到 0.1"。
**日期**: 2026-08-28
**Scope**: `Sources/PagingPrototypeApp/AppArguments.swift` + `Tests/PagingUITests/AppArgumentsTests.swift` + 本结果文件
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingCore / PagingUI / PagingTelemetry
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 背景换算（记录在案）
- momentumDecay 0.85 ≈ 0.33s 滑行（1000px/s 甩速 × 0.85^n ≤ 40px/s 停止阈值 → n≈20 帧 ≈0.33s）；
- 目标 ≈0.1s（6 帧 @60Hz）→ decay ≈ 0.55（0.55^6 ≈ 0.028 ≤ 40/1000=0.04 ✓ 理论达标）；
- 原 CLI 范围 0.80–0.99 装不下 → 下界扩展至 0.50。

## 改动
- `AppArguments.swift`：`--momentum-decay` 合法范围 0.80–0.99 → **0.50–0.99**（头注/解析守卫/帮助文本三处同步）。
- 测试（`AppArgumentsTests.swift`，同文件内调整，无增删测试数）：
  - 下界边界用例 0.80 → 0.50；上界 0.99 保留；
  - 新增越界 0.49（新下界之下）；
  - 原越界用例 0.79 / 0.5 **已落入扩展范围**（0.50–0.99），转为正向断言（0.79→0.79、0.5→0.5）；
  - 保留仍越界：1.5 / 1.0 / abc / 缺值 / "0,85"。
- 不改：PagingCore 默认值（0.95）、glide 机制（停止阈值 40px/s）、其余参数。

## Verification（命令 + 退出码）
| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **156 tests, 0 failures**，exit 0 |
| `.build/release/PagingPrototypeApp --momentum-decay 0.55` | 进程存活 4s（窗口正常打开）→ 手动 kill ✓ |
| `.build/release/PagingPrototypeApp --momentum-decay 0.49` | **exit 2**（打印帮助，不崩溃） |

## Changed Files
- `Sources/PagingPrototypeApp/AppArguments.swift`（范围 0.50–0.99 ×3 处）
- `Tests/PagingUITests/AppArgumentsTests.swift`（边界/越界调整 + 2 正向断言）

## Deviations
1. **0.79/0.5 越界用例语义变化**：任务列"原有越界用例保留"，但扩展后二者已合法——硬保留会制造必然失败的断言；改为正向断言（等价覆盖：合法值可解析）。越界覆盖由 0.49 承担。
2. 未固化默认值：试值 0.55 由 Main 以 `--momentum-decay 0.55` 重启窗口复测；确认后固化 PagingCore 默认（后续波）。
