# PagingPrototype — Phase 1A + Phase 1B

macOS AppKit 分页滑动性能原型（Phase 1A + Phase 1B）。Phase 1A 验证分页交互引擎与页面承载方式；Phase 1B 接入真实应用内容（应用目录扫描 + 运行时图标 + 异步缓存/取消 + 快照一致性 + 真实内容性能复测）。不是完整 Launchpad 产品，不复刻任何旧项目视觉。

> 来源纪律：需求驱动、全新代码、独立状态模型与参数实验。实现 worker 使用不继承旧逆向上下文的 fresh context。详见 `PROVENANCE/` 与 `Docs/`。

## 状态

- **阶段**：Phase 1A 完成（Step 0–8；60Hz 物理门 PASS 2026-08-28 用户实机）；**Phase 1B 完成**（真实内容 60Hz 物理门 PASS 2026-08-28 用户实机，主观 4/4/4/4/3.6，阈值 0.43/0.36）；**后续调参 0.42/0.35**（2026-08-29 用户确认"挺好的"）；120Hz = BLOCKED_BY_HARDWARE
- **自动化验证**：清洁构建 Debug/Release PASS；`swift test` **414 tests 0 failures**（Phase 1B 全量，2026-08-28 真实执行）；性能 baseline 自动可测指标全部达标（`Docs/VALIDATION_RESULTS.md`）
- **工作流**：chef-worker-reviewer-workflow v1.4（`Workflow/PLAN.md`、`Workflow/STATE.json`）；Reviewer A/B/C/D 独立审查 **PASS**（`Workflow/results/`）；最终报告 `PHASE1B_REPORT.md`

## 目录结构

```text
PagingPrototype/
├── Package.swift          （Main 独占）
├── Docs/                  （规格、ADR、参数、验证、日志）
├── PROVENANCE/            （访问声明、组件清单、污染日志）
├── Sources/
│   ├── PagingCore/        （纯逻辑状态机）
│   ├── PagingTelemetry/   （JSONL telemetry）
│   ├── PagingUI/          （AppKit 视图 + 内容承载 seam）
│   ├── AppCatalogCore/    （应用目录快照/差异/规划）
│   ├── MacAppCatalog/     （受限根扫描 + CatalogRepository）
│   ├── AppIconPipeline/   （运行时图标异步管道）
│   ├── AppGridUI/         （真实内容网格 UI）
│   └── PagingPrototypeApp/（App 入口 + 装配）
├── Tests/                 （Core/Telemetry/UI/Catalog/Icon/Grid 测试）
└── Workflow/              （工作流工件，非产品代码）
```

## 构建与运行

```bash
# 构建（Debug / Release）
swift build -c debug
swift build -c release

# 全量测试（414 tests，Phase 1B 全量）
swift test

# 运行原型（无参数即可打开窗口；默认真实内容目录扫描）
swift run

# 常用参数
swift run PagingPrototypeApp --page-count 10 --items-per-page 35
swift run PagingPrototypeApp --paging-telemetry --run-id my-run-01   # 开启 telemetry（输出路径会打印）
swift run PagingPrototypeApp --page-hosting live                     # live（默认；composited 保留未实现）
swift run PagingPrototypeApp --reduce-motion-override on|off|system  # Reduce Motion 覆盖
swift run PagingPrototypeApp --paging-lab                            # 诊断模式
swift run PagingPrototypeApp --catalog-root /path/to/apps            # 追加扫描根（可重复；默认 4 受限根）
swift run PagingPrototypeApp --neutral-content                       # Phase 1A 中性内容回归模式
swift run PagingPrototypeApp --frame-driver runloop|displaylink|auto # 帧源选择（默认 runloop）
swift run PagingPrototypeApp --help                                  # 参数帮助
```

- 参数错误会打印帮助且不崩溃（exit 2）。
- telemetry 输出：`/tmp/launch-copy-paging-prototype-<run-id>.jsonl`（默认关闭）。
- 交互约定（产品决策）：手指左移 → 下一页；滚轮向右 → 下一页。

## 物理验收（Phase 1A Step 8 + Phase 1B，已完成）

真实触控板验收步骤、环境证据模板与手势矩阵见 `Docs/MANUAL_TEST_STEPS.md`。Phase 1A 60Hz 物理门 = **PASS**（2026-08-28 用户实机，主观 4/4/4/4/4，全屏基准）；**Phase 1B 真实内容 60Hz 物理门 = PASS**（2026-08-28 用户实机，主观 4/4/4/4/3.6，阈值 0.43/0.36）；**后续调参 0.42/0.35**（2026-08-29 用户确认"挺好的"）；120Hz = **BLOCKED_BY_HARDWARE**（60.0Hz 面板）。

## 验证状态

`Docs/VALIDATION_RESULTS.md`：BUILD_DEBUG / BUILD_RELEASE / AUTOMATED_TESTS / CODE_REVIEWED / SOURCE_REVIEWED / VISUAL_NEUTRALITY_REVIEWED = PASS（自动/审查）；AUTOMATED_TESTS_1B / BUILD_1B / APP_LAUNCH_SMOKE_1B = PASS；MANUAL_PHYSICAL_GATE_60HZ + MANUAL_PHYSICAL_GATE_60HZ_REAL_CONTENT = PASS（用户实机证据引用）；MANUAL_PHYSICAL_GATE_120HZ = BLOCKED_BY_HARDWARE。
