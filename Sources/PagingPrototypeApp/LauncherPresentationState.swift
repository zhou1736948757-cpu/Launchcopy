//
//  LauncherPresentationState.swift
//  PagingPrototypeApp
//
//  Phase 1G 纯 presentation 状态模型（T-1G-A）：
//  单一 LauncherPresentationCoordinator 拥有 presentation state 与 request generation
//  （PLAN §9 不变量 1-3；PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.1）。
//  纯 Foundation，无 AppKit。全部类型为中性 enum/值（PLAN §11 隐私红线允许记录）。
//

import Foundation

/// 屏幕中性标识：当前屏幕列表中的序号（非 display UUID/名称/序列号，永不持久化）。
public struct ScreenID: Hashable, Equatable, Sendable {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }
}

/// 激活入口（中性 enum，允许记录）。
public enum LauncherActivationSource: Equatable, Sendable, CaseIterable {
    case initialLaunch
    case dockReopen
    case statusItem
    case globalShortcut
    case hotCorner
    /// 四指捏合（T-G-P4：只发 show，永不 hide/quit——PLAN §9 不变量 3）。
    case fourFingerPinch
    case testHarness
}

/// 命令（入口 → coordinator）。
public enum LauncherCommand: Equatable, Sendable {
    case show
    case hide
    case toggle
    case quit
}

/// 关闭原因（中性 enum，允许记录）。
public enum DismissReason: Equatable, Sendable {
    case backgroundClick
    case escape
    case appLaunched
    case statusItem
    case globalShortcut
    case screenConfigurationChanged
    case sessionResigned
    case explicitQuit
}

/// 挂起原因（sleep / session inactive / 屏幕重配）。
public enum LauncherSuspensionReason: Equatable, Sendable {
    case sleep
    case sessionInactive
    case screenConfigurationChanged
}

/// committed presentation state（PLAN §9 不变量 1：一进程最多一个有效 transition）。
public enum LauncherPresentationState: Equatable, Sendable {
    case hidden
    case presenting(requestID: UInt64, targetScreen: ScreenID)
    case visible(screenID: ScreenID)
    case dismissing(requestID: UInt64, reason: DismissReason)
    case suspended(reason: LauncherSuspensionReason)
    case terminating
}

/// coordinator 输出给 UI 层的效果（UI 层执行窗口行为；本模块纯逻辑，不触碰 AppKit）。
public enum LauncherPresentationEffect: Equatable, Sendable {
    case none
    case present(requestID: UInt64, targetScreen: ScreenID, source: LauncherActivationSource)
    case dismiss(requestID: UInt64, reason: DismissReason, source: LauncherActivationSource)
    case suspend(reason: LauncherSuspensionReason)
    case terminate
    case teardown
}
