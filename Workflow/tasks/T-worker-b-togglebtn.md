# Task Packet: T-worker-b-togglebtn（全屏/窗口切换按钮 + 快捷键）

- **Task ID**: T-worker-b-togglebtn
- **Role**: Worker（PagingPrototypeApp + 必要时 PagingUI 最小改动）
- **来源**: T-step8 物理调参第 10 轮补充（用户要求；t20 遗漏项）
- **日期**: 2026-08-28

## 用户反馈（原话）

"在这个软件里面，你应该给一个就是全屏和窗口切换的一个按钮，按一下就可以切换，这样方便我来回测。"

## 任务

1. **窗口内切换按钮**：软件界面里加一个**全屏 ↔ 窗口切换按钮**（位置自选：窗口右上角/标题栏 accessory/页面角落浮钮均可——选实现最稳、不遮挡分页区域的方案）。按一下切换全屏/窗口（`toggleFullScreen(nil)`，复用 t20 已验证的延迟调用模式或同步调用——全屏**退出**路径需实测确认稳定，若同步 toggle 在退出方向有问题则同样延迟/写理由）。
2. **快捷键**：同功能键盘快捷键（`Ctrl+Cmd+F` 或 `F`，macOS 惯例优先 Ctrl+Cmd+F）。
3. 状态正确性：全屏 ↔ 窗口来回切换 ≥2 轮不闪退、不丢窗口（复用 t20 冒烟方法验证 bounds/styleMask）。
4. `--fullscreen` CLI 与按钮共存（按钮可在全屏态继续切回窗口）。
5. 测试：按钮存在性/点击触发（若可自动化；否则冒烟记录）+ AppArguments 回归；全量 swift test 0 failures（180+）；`swift build` exit 0（0 warning）。

## 注意（惯性 3→1 帧——不需要代码改动）

momentumGlideFrames 走 CLI 试值（--momentum-glide-frames 1），默认 nil 保持；本任务**不含** glide 默认值改动。

## Write Scope

- `Sources/PagingPrototypeApp/`（按钮 + 快捷键注册）
- `Sources/PagingUI/`（**仅当按钮必须放 Surface 层时**，最小改动；优先 App 层）
- `Tests/` 相关
- `Workflow/results/T-worker-b-togglebtn.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingCore/`、`Sources/PagingTelemetry/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- 冒烟：窗口启动 → 按钮点击（或快捷键）→ 全屏 bounds 1470×923 → 再切回窗口 → 窗口 bounds 1000×732；全程无闪退（记录数字）
- 心跳 role Worker, task-id T-worker-b-togglebtn, ACTIVE

## Status

- 2026-08-28：Main 记录 t20 遗漏；Worker 补做。
