# T-1F-B10-regression — wave-b 合并后主页面点击全死（回归诊断）

- 状态：READY（待 Chief 诊断）
- 角色：Main 记录 → Chief 诊断 → Worker 实现 → Reviewer 审查
- 创建：2026-09-02（Main）
- 关联：T-1F-B10-wave-a-forensics（已合并，基线 1083/0）

## 背景

用户实机复测（6 步取证脚本）时发现：**主页面点击软件打不开**。census 日志
`/tmp/bug10_forensics_run.log` 显示冷启动即全死，与 BUG9 修复后验证态（run2：
s10×5、sA×3 正常）相比为严重回归。

## 证据（census 日志实况，8 次点击）

| sink | 计数 | 含义 |
|---|---|---|
| s8e_window_key_state_key1_active1 | 8 | 窗口全程 key/active（排除 R5） |
| s17_blankhit_chain_has_overlay_ov0 | 7 | 命中链恒不含 FolderOverlayView |
| s8d_window_cell_passthrough | 7 | 窗口层判 cell 放行 super |
| s8_window_blank_unclassified | 1 | 空白命中 |
| s8c_window_blank_terminate | 1 | 空白点击退出 app |
| **s10_cell_mousedown_fired** | **0** | **cell.mouseDown 从未触发** |
| **sA_launch_accepted** | **0** | **零启动** |
| s14（overlay hitTest） | 0 | overlay 从未参与 hitTest |
| s16（closeFolder） | 0 | closeFolder 从未运行 |
| s4a/s4d | 0 | 无 folder 交互 |

## 分析要点（Main 初步，供 Chief 参考）

- 7 次点击落在 cell 上（s8d + s17_ov0 证实），窗口放行（super.sendEvent 已走），
  但事件在 window.sendEvent 与 cell.mouseDown 之间消失。
- 冷启动即全死、无任何 folder 参与 → 不匹配判别表任何一行（overlay 残留行要求
  s14 参与，此处 s14=0）。
- 首要嫌疑：wave-b 改动（refreshFolderOverlay 宿主切换驱动 / setVisualHost /
  setHost）。wave-b 合并前 run2 正常（s10×5、sA×3）。
- 已排除：R5（s8e key1 为主）、窗口层吞事件（s8d 放行计数在）。

## 约束

- 冻结树零触碰（Sources/PagingCore、AppCatalogCore、MacAppCatalog、
  AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、
  AppLaunchController.swift）。
- 隐私红线：census sink 只允许中性名+计数+布尔状态位。
- Main/Chief 不写业务代码；实现 → Worker → 独立 Reviewer PASS → 合并。
- 无 git 操作。

## 交付物

- Chief 诊断报告（根因定位，含证据链）
- 任务包（修复波次，若需）
- Worker 实现 + Reviewer PASS + 合并
- 用户实机复验
