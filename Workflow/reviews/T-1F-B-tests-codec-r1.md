# Review T-1F-B-tests-codec-r1 — LayoutStoreCodec 测试编写

Reviewer: independent Reviewer（只读验证，未修改任何代码/测试）
Reviewed: 2026-08-31

## Verdict: PASS

## 验证证据（项目根目录串行执行）

1. `swift build -c debug` → `Build complete! (0.39s)`，exit 0
2. `swift test` → `Executed 871 tests, with 0 failures (0 unexpected) in 13.477 (13.531) seconds`，exit 0（871 = 基线 837 + 新增 34；非 0-executed 空跑）
3. `swift build -c release` → `Build complete! (0.24s)`，exit 0

## 交付物核验

- 测试文件 `Tests/AppGridUITests/LayoutStoreCodecTests.swift`：34 个测试方法（grep 计数 34），与结果文件声明一致。
- 8 点矩阵全覆盖，断言有意义（非同义反复）：
  1. 往返：2 测试（app-only 双枚举分支 + 空布局），断言 decoded.layout 相等 + writeGeneration 相等
  2. 确定性：两次 encode 逐字节相等
  3. 校验和篡改：payload 中部字节翻转 → `.corrupt`
  4. 结构校验：11 测试，JSONEncoder 手构 envelope + 合法 SHA-256 校验和（绕过 encode 域校验，符合任务建议）；覆盖 FolderID 重复（记录间/顶层条目间）、app ref 重复（顶层/顶层+成员/跨 folder）、成员重复、顶层条目 app+folder 同时非 nil/同时 nil、未知枚举 case、空 value、非法 UUID
  5. 上限：5 测试（>1 MiB → decode `.overLimit`；513 folders decode + encode 抛 `.overLimit`；10,001 app refs；2,049 members/folder encode 抛 `.overLimit`）
  6. 未知未来版本：v2/v99 → `.unknownFutureVersion(2/99)`（guard case 断言绝不 `.valid`）；v0 → `.corrupt`
  7. 域不变量：6 测试（title 65 grapheme、单成员/空 folder、成员同时顶层、顶层 folder 无记录、孤立记录 → encode 抛错）
  8. 垃圾数据：5 测试（随机字节/空 Data/截断 JSON/非 envelope JSON/缺校验和 → `.corrupt`）
- 隐私红线：全部 fixture 为中性假数据（"com.example.appN" / "Group N" / "/Applications/Example.app" / 合成 UUID），无真实 app 名/bundleID/路径。
- 写范围：仅 `Tests/AppGridUITests/LayoutStoreCodecTests.swift`。mtime 核验：测试文件 2026-08-31 08:10:19 为全树最新；Sources/ 最新文件 05:15:14（LayoutStoreCodec.swift、EdgePagingScheduler.swift）早于测试文件；冻结树 PagingCore（最新 08-30 11:46）/AppCatalogCore（08-28 20:50）/MacAppCatalog（08-28 21:01）/AppIconPipeline（08-29 00:22）/PagingTelemetry（08-28 21:09）/PagingUI（08-30 15:15）/Package.swift（08-28 20:42）/AppLaunchController.swift（08-28 21:46）全部未动。

## 缺陷报告佐证（独立确认，属实）

`Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` `validateStructure`（L205-233）：`seenFolderIDs`（L206）被顶层 folder 条目（L216 `seenFolderIDs.insert(folderID)`）与 folder 记录（L224 `seenFolderIDs.insert(record.id)`）**共用同一集合**。合法含 folder 布局的 FolderID 必然同时出现在 topLevelOrder 与 folders 记录中 → 第二次 insert 返回 false → `validateStructure` 返回 false → decode 返回 `.corrupt`。即任何含 folder 的布局无法往返（app-only/空布局正常）。报告准确；按任务约束未改源码，建议后续任务修复（顶层条目与记录分集合去重，或仅对记录集合查重）。测试套件往返项用 app-only 布局规避该缺陷，已在结果文件中如实说明。

## MINOR 备注

1. 域不变量 6 测试用裸 `XCTAssertThrowsError`，未断言具体错误类型（`.invalidLayout` vs `.overLimit`）；任务仅要求"抛错"，可接受，但断言错误类型更严谨。
2. 任务包 API 摘要写 `.loaded(DecodedLayout)`，源码实为 `.valid(DecodedLayout)`；测试以源码为准使用 `.valid`，正确。
3. 矩阵第 1 项（往返）未覆盖含 folder 布局——因源码缺陷所致，属合理规避且缺陷已上报，不构成 FAIL。
