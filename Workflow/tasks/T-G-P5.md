# T-G-P5 — 四指轨整体独立评审

## Objective
1. **跨任务接口契约一致性**：对已 PASSED 的四指轨链路做整体独立评审——`PinchRecognizer`（T-G-P1）→ `TouchProvider`/`MockTouchProvider`（T-G-P2）→ `FourFingerActivationState`/`ActivationServicePlan`/`ActivationPreferences`（T-G-P3）→ `FourFingerActivationCoordinator`（T-G-P4）→ `LauncherPresentationCoordinator`/`LauncherPresentationState`（T-1G-A）。逐层核对：类型签名、事件语义（PinchEvent.showRequested(token:)/onFrame/onStateChange）、状态枚举对齐（TouchProviderState 七态 vs FourFingerActivationState 七态 1:1）、generation/sessionID 传递、单调时间域（禁墙钟）、去重与幂等契约。
2. **PLAN §10 验收标准核对**：FOUR_FINGER_RECOGNIZER_TESTS / FOUR_FINGER_PROVIDER_MOCK_TESTS / PREFERENCES_TESTS / FULL_SWIFT_TESTS / BUILD_DEBUG / BUILD_RELEASE / PRIVACY_AND_PROVENANCE_REDLINE 逐项对照实际证据（测试计数、构建 exit code、红线扫描结果），指出任何虚标或证据缺口。
3. **隐私红线整体静态扫描**：对四指轨全部新增/修改源码（Sources/PagingPrototypeApp/ 下 PinchRecognizer.swift、TouchProvider.swift、MockTouchProvider.swift、ActivationPreferences.swift、ActivationServicePlan.swift、FourFingerActivationState.swift、FourFingerActivationCoordinator.swift、LauncherPresentationState.swift 及 Tests/PagingUITests/ 新增测试）做红线扫描：`addGlobalMonitorForEvents`、`CGEvent.tapCreate`、`AXIsProcessTrusted`、`IOHID`、private API selector strings、`LaunchBetter`、`Buho`、pointer coordinate logging、`frontmostApplication`；确认无墙钟（Date/timeIntervalSinceNow）、无 UserDefaults 标准域污染（专用 suite com.pagingprototype.activation）、无触点数据持久化。
4. **挂账项复核**：逐项复核 Workflow/decisions/2026-09-05-pending-questions-1g.md 中四指轨挂账——Q-2 静默恢复 re-arm（PinchRecognizer.swift L374-383，合同 8 vs 12 张力）、Q-3 慢速连续捏合（advanceCandidate re-anchor L508-513）、Q-4 冷却跨设备（L251-252/L537）、MINOR-1 resume() 不清 pendingShowTokens（FourFingerActivationCoordinator.swift L151-155）、QUESTION-1 flush 调用点、QUESTION-2 生产路径恒为 process()——给出评审意见（保留/升级/关闭），不修改代码。
5. **独立重跑**：`swift test --filter` 四指轨相关套件（PinchRecognizerTests/PinchRecognizerLifecycleTests/TouchProviderLifecycleTests/MockTouchProviderTests/TouchProviderIntegrationTests/ActivationPreferencesTests/ActivationServicePlanTests/FourFingerActivationStateTests/FourFingerActivationCoordinatorTests）+ 全量 `swift test`，记录 executed/failures/exit code；`swift build` 与 `swift build -c release` exit code。
6. 输出评审报告 `Workflow/reviews/T-G-P5-r1.md`（Verdict: PASS/FAIL + BLOCKER/MAJOR/MINOR/QUESTION/INFO 分级 + 独立重跑计数 + 合规核验 + 逐项验收）。

## Expected / Allowed Write Scope
- 仅 `Workflow/reviews/T-G-P5-r1.md`（评审报告）
- 只读：Sources/、Tests/、Docs/、Workflow/、PROVENANCE/
- 禁止：修改任何产品/测试/文档文件；不 commit/push/tag

## 验收
- 评审报告含独立重跑计数（filter + 全量 + build + release build）
- 红线扫描结果逐项列出
- 挂账项逐项给出意见
- 不修改任何产品文件（写集核验：评审期间 Sources/Tests 零 mtime 变化）
