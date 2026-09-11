# T-1F-B-tests-codec — LayoutStoreCodec 测试编写

Status: PASS

## 产出
- 测试文件：`Tests/AppGridUITests/LayoutStoreCodecTests.swift`（新建，仅此 1 文件；未改任何源码）
- 测试数：34（全绿；基线 837 + 34 = 871）

## 覆盖矩阵
1. 往返：app-only 布局（bundleID + pathFallback 两枚举分支）与空布局 → `.valid`，layout 与 writeGeneration 一致
2. 确定性：同布局同 writeGeneration 两次 encode 逐字节相等
3. 校验和篡改：翻转 payload 中部字节 → `.corrupt`
4. 结构校验（JSONEncoder 手构 envelope + 合法 SHA-256 校验和，绕过 encode 域校验）：FolderID 重复（记录间/顶层条目间）、app ref 重复（顶层/顶层+成员/跨 folder）、folder 成员重复、顶层条目 app+folder 同时非 nil 或同时 nil、未知枚举 case、空 value、非法 UUID → 全部 `.corrupt`
5. 上限：>1 MiB 数据 → decode `.overLimit`；>512 folders（decode 手构 envelope 513 条 + encode 域合法 513×2 布局抛 `.overLimit`）；>10,000 app refs（decode 10,001 顶层条目）→ `.overLimit`；>2,048 members/folder（encode 2,049 成员布局抛 `.overLimit`）
6. 未知未来版本：schemaVersion 2/99 → `.unknownFutureVersion(2/99)`，绝不 `.valid`；schemaVersion 0 → `.corrupt`
7. 域不变量（encode 抛错）：title 65 grapheme、单成员 folder、空 folder、成员同时出现在顶层、顶层 folder 条目无对应记录、孤立 folder 记录
8. 垃圾数据：随机字节 / 空 Data / 截断 JSON / 非 envelope JSON / 缺校验和 → `.corrupt`

## 验证输出（项目根目录串行执行）
1. `swift build -c debug` → Build complete!，exit 0
2. `swift test` → Executed 871 tests, with 0 failures (0 unexpected)，exit 0
3. `swift build -c release` → Build complete!，exit 0

## 发现：源码缺陷（未修复，超出写范围，如实报告）
`Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` `validateStructure` 中 `seenFolderIDs` 集合被顶层 folder 条目与 folder 记录**共用**：合法布局（folder 同时出现在 topLevelOrder 与 folders 记录）的 FolderID 会被判为重复 → decode 返回 `.corrupt`。实证：临时探针测试对含 folder 的合法布局 encode→decode 得到 `corrupt`（期望 `.valid`），已移除探针。即**任何含 folder 的布局无法往返**（app-only/空布局正常）。按任务约束未改源码；建议后续任务修复（如顶层条目与记录分集合去重，或仅对记录集合查重）。本套件往返测试用 app-only 布局覆盖矩阵第 1 项。
