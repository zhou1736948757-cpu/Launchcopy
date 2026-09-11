# T-worker-b-overshoot2 — 过冲 0.20 + CLI（--momentum-overshoot）

**Worker**: B/D 同人（PagingCore + App）
**来源**: 物理调参第 6 轮，用户指令：过冲上限"最多冲到第二页加 1/5 页"；惯性时长 5 帧 → 3 帧
（`--momentum-glide-frames 3` 走既有 CLI，**零代码改动**）。
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingParameters.swift`、`Sources/PagingPrototypeApp/`（AppArguments + AppParameters + AppDelegate + AppMain）、`Tests/PagingCoreTests/`、`Tests/PagingUITests/`、`Workflow/results/T-worker-b-overshoot2.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 改动

1. **PagingParameters**：`momentumMaxOvershoot` 默认 **0.35 → 0.20**（注释同步：第 6 轮用户定
   "最多冲到第二页加 1/5 页"；PRODUCT_DECISION；物理调参中）。
2. **CLI `--momentum-overshoot <0.05–1.0>`**（Double? 缺省 nil）：解析/越界 exit 2/帮助文本，
   风格与 --momentum-decay / --momentum-glide-frames 一致（AppArguments + AppMain）；
   AppParameters.make 三旋钮并列（momentumDecay / glideFrames / overshoot）→ AppDelegate 接线。

## 测试（+4：Core 1、AppArguments 2、AppParameters 1）

| 测试 | 断言 |
|---|---|
| `testMomentumOvershootClampedFastFling`（更新） | 峰值 **3.35 → 3.20**（= committed+1+0.20）、拉回 **0.20 ≤ 0.20**；其余断言不变 |
| `testMomentumOvershootCustomValueApplied`（新） | 自定义 0.1 → 峰值 3.10、拉回 0.10（CLI 可调路径验证） |
| `testMomentumOvershootParsed` / `testMomentumOvershootOutOfRangeFails`（新） | 0.2 / 边界 0.05、1.0 合法；1.1 / 0.04 / abc / "0,2" / 缺值 失败；缺省 nil |
| `testMomentumOvershootOverrideApplied` + 既有 4 测试（更新签名） | 接线 0.2/0.05/1.0 生效；nil → Core 默认 0.20 |

慢甩/边界（4.1575 / −0.105）/RM/glide 截断测试断言不变，全部通过。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **172 tests, 0 failures**（168 → +4），exit 0 |
| `--help \| grep momentum-overshoot` | 命中帮助行 |
| `--momentum-overshoot 1.1` / `0.04` | **exit 2** |
| `--momentum-glide-frames 3 --momentum-overshoot 0.2`（复测组合） | 窗口正常打开 |

## Changed Files

- `Sources/PagingCore/PagingParameters.swift`（默认 0.20 + 注释）
- `Sources/PagingPrototypeApp/AppArguments.swift`（+`--momentum-overshoot` 解析/错误/帮助）
- `Sources/PagingPrototypeApp/AppParameters.swift`（make 三参）
- `Sources/PagingPrototypeApp/AppDelegate.swift`（接线）
- `Sources/PagingPrototypeApp/AppMain.swift`（invalidMomentumOvershoot → exit 2）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（+1 自定义钳制；快甩断言 3.20/0.20）
- `Tests/PagingUITests/AppArgumentsTests.swift`（+2）
- `Tests/PagingUITests/AppParametersTests.swift`（签名 + 覆盖）
- `Workflow/results/T-worker-b-overshoot2.md`（本文件）

## Deviations

1. 惯性 5→3 帧：`--momentum-glide-frames 3` 既有 CLI 直接可用，未改代码（含帮助文本，范围 0–10 已含 3）。
2. Docs 参数表行（momentumMaxOvershoot 0.20 试值）回填留 Main（本波禁写 Docs）。

## Memory Candidates

- momentum 三旋钮（decay / glideFrames / overshoot）均已 CLI 化 + 接线测试 → 后续微调纯参数级，
  零 Core 代码改动。
- 复测组合 `--momentum-glide-frames 3 --momentum-overshoot 0.2`：截断 3 帧（6 事件）+ 过冲 0.20 页。
