# Codex handoff — Launchcopy layout + Folder motion (Phase 1J slice)

Copy this block to Codex:

```text
Read and follow:

/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1J_CHECKPOINT.md

Especially §4 (NEW WORK FOR CODEX) and §3 (user A–D checklist — do not invent PASS).

Also read:
- ~/.agents/skills/skills/skills/apple-design/SKILL.md
- ~/.agents/skills/skills/skills/emil-design-eng/SKILL.md
- ~/.agents/skills/skills/skills/animate/SKILL.md

Mission:
1) Tune grid size & placement (reduce bottom empty/black slab; Launchpad-like vertical centering / safe margins; tokenize metrics).
2) Wire Folder open/close to small origin-aware scale+opacity animation using existing FolderOverlayView.MotionParams; Reduce Motion = fade only; no scale(0); transform+opacity only; ≤250ms; symmetric close.
3) Do NOT change paging physics / Timer.tolerance / reopen T-WALLPAPER-CELL-FILL / sign / notarize / publish.
4) Write Docs/PHASE1J_LAYOUT_MOTION_PLAN.md first, then implement; new candidate via Scripts/package-app.sh into a NEW .build/candidates/ id; keep full suite green.

Communicate with user in Chinese; engineering docs in English.
```

## Quick现状 (for humans)

| 现状 | 问题 | 建议 |
|---|---|---|
| 网格 `topInset=96` + 固定 cell 88 | 内容偏上；**截图底黑是 Dock，不是应用 bug（已撤回 A3）** | 可用区内垂直居中 / 按高度分配 pitch（可选 polish，勿“修 Dock”） |
| Folder `MotionParams` 已定义 | **未接线**，开关几乎瞬切 | 从源 Folder cell 放大淡入，关闭原路返回 |
| 启动器全屏覆盖 | 可保留 | 改的是**内容**放置，不是改回窗口化 |
| 黑框修复 | 已用户验收 | 保持；与底部黑带分开看 |
