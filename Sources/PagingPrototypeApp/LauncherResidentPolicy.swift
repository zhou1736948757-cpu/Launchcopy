//
//  LauncherResidentPolicy.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-E：驻留启动器进程策略常量（可测、无 AppKit 副作用）。
//  ADR-011 Q5/Q6：blank/ESC/launch/close → hide；仅 Quit → terminate。
//

import Foundation

/// 驻留 launcher 进程策略（AppDelegate 与集成测试共用）。
public enum LauncherResidentPolicy {
    /// `applicationShouldTerminateAfterLastWindowClosed` 必须为 false（hide ≠ quit）。
    public static let terminateAfterLastWindowClosed: Bool = false
}
