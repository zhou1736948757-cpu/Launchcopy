# PHASE1B_SPEC.md — Phase 1B 规格（真实应用内容接入）

- **日期**：2026-08-28（Main，Wave 0 后整理）
- **源**：PHASE1B_REAL_APP_CONTENT_PROMPT.md（SHA-256 `2b164b3f3a54be948e469296e2f39bc94eb3666d4614a7cb8ccd4d43442e83b3`）
- **状态**：实现完成（Wave 1–3）；验证与物理复验收口中

## 1. 范围（§3）

**必须实现**：受限根 .app 枚举；纯模型 catalog domain；稳定身份/排序/去重/过滤；不可变 snapshot + revision；分页计划/页数推导/锚点重映射；PagingUI 内容 provider/renderer 抽象；中性 placeholder 回归模式；真实 app 名 + 运行时系统图标网格；异步图标（合并/取消/有界缓存/防串图）；loading/空/部分失败/刷新中性 UI；手动 refresh + 可取消 debounced rescan；snapshot 一致性；匿名 telemetry（不记录 app 名/bundle ID/路径/图标数据）；真实内容性能回归 + 60Hz 物理复验；可选帧源实验（RunLoop fallback 保留）；完整 provenance review。

**受控附加**：APP_LAUNCH_SMOKE（§3.2，独立 sub-gate；结果 = PASS，键盘层延 Phase 1C）。

**明确禁止**（§3.3）：搜索/拼音、文件夹/分组、拖拽重排/跨页移动、Hot Corner/全局监听/辅助功能权限、Launchpad/Dock 私有库读写、系统布局写入、持久化布局/SQLite、全磁盘/Home/网络卷扫描、磁盘图标缓存、LaunchBetter 视觉/品牌、复制第三方图标进 repo/发布包、安装/签名/公证/发布、自动 commit/push/tag/release。

## 2. 冻结不变量（§4，零改动）

- 参数：displacementThreshold 0.46 / retreat 0.40 / momentumGlideFrames 1 / momentumDecay 0.55 / momentumMaxOvershoot 0.20
- PagingCore 纯逻辑（无 AppKit/catalog/icon/FS 依赖）；visualOffset Core 独占；committedPage 语义；token 三防线；中断接管；resize/pageCount/Reduce Motion/cancel/teardown 防 stale；手指左移=下一页；vertical-dominant 不进入横向分页；telemetry 默认关闭；live view + reuse pool 基线；中性 placeholder 持续可运行可测试。

## 3. 模块与依赖（§5，ADR-004 冻结）

```
AppCatalogCore（Foundation-only）
MacAppCatalog → AppCatalogCore
AppIconPipeline → AppCatalogCore
AppGridUI → AppCatalogCore + AppIconPipeline + PagingUI（不依赖 MacAppCatalog）
PagingPrototypeApp → 全部
```

## 4. 一致性纪律（§6）

- idle：latest-wins 应用；tracking/settling/interrupted：冻结当前 presentation revision（surface 显式 pin）；更新在 idle 边界经 anchor 重映射（五级降级，绝不沿用旧 index）。
- binding token 七字段（catalogRevision/page/itemSlot/AppID/IconKey/reuseGeneration/surfaceGeneration）全字段校验；stale async apply = 0。

## 5. 关键决策

- ADR-004：AppID 不透明；DuplicateResolution 默认 rootPriorityFirst；validate 以 canonicalURL 判身份；revision 唯一拥有者 = CatalogRepository。
- 隐私：telemetry 四层红线冻结（28 键白名单/属性表面/类型表面/哨兵缺席）；scan root 上界 4 受限根；无 FDA/TCC/全局监听。
- 帧源：默认 RunLoopFrameDriver（Phase 1A 冻结）；§8 实验记录 display link 本环境 ~60Hz 回调证据（未标 PASS、未宣称 vsync、帧源未改）。

## 6. 验收状态（§15 对应）

| 项 | 状态 |
|---|---|
| Gate 0 基线 | PASS（181 tests 冻结，manifest 117 文件） |
| Wave 1–3 实现 | PASS（414 tests 0 failures，release exit 0 零警告） |
| Reviewer A/B/C | PASS（无 BLOCKER/MAJOR，4 MINOR 已处理/标注） |
| APP_LAUNCH_SMOKE | PASS（键盘层延 Phase 1C） |
| 60Hz 真实内容物理门 | 用户复验中 |
| 120Hz | BLOCKED_BY_HARDWARE（60Hz 面板） |
