//
//  AppLaunchController.swift
//  PagingPrototypeApp
//
//  Phase 1B t11（§3.2 受控附加项：应用启动 smoke）—— 单击触发 + stale 拒绝 + 非致命失败。
//  实现：worker-integration（deepseek-v4-flash:0731, max）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
//  触发方式（本项目独立决定并记录）：**单击** cell 启动（NSClickGestureRecognizer 挂在
//  PagingSurface 上，命中测试沿视图链找 AppGridCellView）。双击/Return 不接线：键盘焦点
//  模型（§9「支持键盘焦点移动的基础能力，或在文档中明确本阶段只完成哪一层并标记后续 gate」）
//  留 Phase 1C —— cell 需 acceptsFirstResponder 才能成为 key view（AppGridUI 范围），
//  App 层无法在不越权的情况下安全接线 Return。
//
// 启动安全（§3.2 全项）：
//  - 只允许启动当前 catalog 中仍存在且经重新确认的 bundle URL：
//    ① token.catalogRevision == provider.servedRevision（stale revision 拒绝）；
//    ② AppID 仍在当前快照的 identity→URL 映射中（重新确认存在）；
//    ③ 磁盘 fileExists 重新确认（catalog 与磁盘不一致 → 拒绝）；
//  - 启动失败非致命（.failedToLaunch 中性结果，不崩溃、不弹窗）；
//  - 无进程管理/最近使用统计/自动重启/隐藏退出其他 App；
//  - 不把真实 bundle URL 写入 telemetry：只记中性 phase 事件（app.launch），
//    结果计数保留在内存（outcomeCounts），不进日志。

import AppCatalogCore
import AppGridUI
import AppKit
import Foundation
import PagingTelemetry
import PagingUI

/// 启动执行器抽象（测试注入 fake；生产 = NSWorkspace 公开 API）。
public protocol AppLaunching: Sendable {
    func openApplication(at url: URL) -> Bool
}

/// 默认实现：只经公开 NSWorkspace API 启动（§3.2「使用当前 SDK 支持的公开 NSWorkspace API」）。
public struct NSWorkspaceAppLauncher: AppLaunching {
    public init() {}
    public func openApplication(at url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

/// 中性启动结果（不含 URL/路径/名称/身份原文）。
public enum AppLaunchOutcome: Equatable, Sendable {
    /// 校验通过并成功启动。
    case launched
    /// cell 捕获的 catalog revision 已过期（stale revision，§3.2）。
    case rejectedStaleRevision
    /// AppID 不在当前 catalog（identity→URL 映射无此 app）。
    case rejectedMissingApp
    /// bundle URL 在 catalog 中但磁盘重新确认失败（文件已不存在）。
    case rejectedMissingFile
    /// 点击处无绑定 cell（空白/占位 cell/无 bindingToken）。
    case rejectedNoBinding
    /// 启动失败（非致命；中性错误状态，不崩溃）。
    case failedToLaunch
}

/// 单击启动控制器（@MainActor：视图/命中测试/快照读取同线程）。
@MainActor
public final class AppLaunchController: NSObject {

    /// 最近一次启动结果（中性）。
    public private(set) var lastOutcome: AppLaunchOutcome?
    /// 结果计数（中性；诊断/测试；不进 telemetry）。
    public private(set) var outcomeCounts: [AppLaunchOutcome: Int] = [:]

    /// 启动尝试回调（中性；AppDelegate 可观察）。
    public var onLaunchAttempt: ((AppLaunchOutcome) -> Void)?

    private weak var surface: PagingSurface?
    private let assembly: AppCatalogAssembly
    private let launcher: any AppLaunching
    private let fileManager: FileManager
    private weak var session: TelemetrySession?
    private var recognizer: NSClickGestureRecognizer?

    public init(surface: PagingSurface,
                assembly: AppCatalogAssembly,
                launcher: any AppLaunching = NSWorkspaceAppLauncher(),
                fileManager: FileManager = .default,
                session: TelemetrySession? = nil) {
        self.surface = surface
        self.assembly = assembly
        self.launcher = launcher
        self.fileManager = fileManager
        self.session = session
        super.init()
    }

    /// 把单击手势识别器挂到 surface（点击子视图（cell）经祖先识别器接收）。
    public func install() {
        guard recognizer == nil, let surface else { return }
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        surface.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
    }

    // MARK: - 触发入口

    @objc private func handleGesture(_ recognizer: NSClickGestureRecognizer) {
        let point = recognizer.location(in: recognizer.view)
        handleClick(at: point)
    }

    /// 公开测试入口：与手势识别器同一路径（hitTest → cell → 校验 → 启动）。
    @discardableResult
    public func handleClick(at point: NSPoint) -> AppLaunchOutcome {
        let hit = surface?.hitTest(point)
        var current = hit
        while let candidate = current {
            if let cell = candidate as? AppGridCellView {
                return handleCell(cell)
            }
            current = candidate.superview
        }
        return record(.rejectedNoBinding)
    }

    /// 直接 cell 入口（测试用；与命中路径同一校验管线）。
    @discardableResult
    public func handleCell(_ cell: AppGridCellView) -> AppLaunchOutcome {
        record(launch(from: cell))
    }

    // MARK: - 校验管线（§3.2 全项）

    private func launch(from cell: AppGridCellView) -> AppLaunchOutcome {
        guard let token = cell.bindingToken else { return .rejectedNoBinding }
        guard let appID = token.appID as? AppID else { return .rejectedNoBinding }

        // ① stale revision 拒绝：cell 捕获的 catalog revision ≠ 当前已服务 revision。
        guard let served = assembly.provider.servedRevision, token.catalogRevision == served else {
            return .rejectedStaleRevision
        }
        // ② 当前 catalog 重新确认存在（映射随每次提交重建；旧 identity 立即失效）。
        guard let url = assembly.bundleURL(for: appID) else { return .rejectedMissingApp }
        // ③ 磁盘重新确认（catalog 与磁盘不一致 → 拒绝，绝不启动已消失的 bundle）。
        guard fileManager.fileExists(atPath: url.path) else { return .rejectedMissingFile }
        // ④ 启动（公开 NSWorkspace API；失败非致命）。
        return launcher.openApplication(at: url) ? .launched : .failedToLaunch
    }

    @discardableResult
    private func record(_ outcome: AppLaunchOutcome) -> AppLaunchOutcome {
        lastOutcome = outcome
        outcomeCounts[outcome, default: 0] += 1
        onLaunchAttempt?(outcome)
        // telemetry：只记中性 phase 事件（无 URL/路径/名称/身份原文 —— §3.2 红线）。
        session?.record(TelemetryEvent(phase: "app.launch"))
        return outcome
    }
}
