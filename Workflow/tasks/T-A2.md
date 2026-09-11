# T-A2 — 用户亲手物理 A/B(人手协议)

- 类型: 人手(用户执行,不改代码)
- 依赖: Phase 0 启用(已确认)
- 依据: Docs/FRAME_LAG_FIX_PLAN.md §6
- 目的: 短尾改善是否变成「跟手」;0/4ms 会不会多翻页、少跟手、settle 发硬。

## 环境钉死
- 同一台机器,主屏 60Hz;全屏 1470×923;插电,低电量关;真实目录内容。
- 二进制与 T-A1 同一 SHA。
- 正式 run 不开 System Trace。

## 臂与顺序
- A 生产默认(不传 `--frame-timer-tolerance-ms`)
- B `--frame-timer-tolerance-ms 0`
- C `--frame-timer-tolerance-ms 4`(仅当 T-A1 显示「4ms 足够」或用户愿意多做一轮)
- 顺序: `A1 B1 B2 A2 A3 B3`(有 C 则插入 `… C1 C2`,仍交错)

## 手势协议(每 run 30 组,checklist 打勾)
1. 慢拖不足阈值 → 应回弹(10)
2. 慢拖过阈值 → 应翻页(6)
3. 轻甩(速度过门)→ 应翻页(6)
4. 翻页中反向中断(4)
5. 边界 overscroll(4)
- 方向大致一半前进一半回退。不要「随便滑一会儿」充当 run。

## 主观五项(每 run 结束立刻打分,1–4,可 0.5)
跟手性 / 中断连续性 / settle 自然度 / 边界反馈 / 总体丝滑。
另记: 误 commit(不该翻却翻)、误回弹(该翻却回)、是否感到「一顿一顿」。

## 客观(若该 run 开了 `--frame-callback-profile`)
- 每臂至少 1 个手感-only run(无 profile)+ 至少 1 个诊断 run(`--frame-callback-profile`,不要 runloop observer)。

## PASS 倾向(给 Phase 2 用,不是自动改默认)
候选臂(0 或 4)同时满足: ①主观跟手 ≥ 默认臂,总体不降超过 0.5;②误 commit 不增加;③诊断 run 的 >20ms 率相对默认下降(方向与 T-A1 一致);④用户口头可接受能耗(记「未测/可接受/不可接受」)。任一失败 → 该臂不得推荐为生产默认。

## 产出
- 用户填写结果表(每 run 打分 + 误 commit/误回弹/一顿一顿),Main 汇总入 Docs。
