//
//  ShortcutRegistrationOutcome.swift
//  PagingPrototypeApp
//
//  Phase 1G 快捷键注册结果模型（T-1G-A）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.6：报告只用中性 configured/conflict/unavailable；
//  不记录用户按过的其他键；reconfigure 失败时保留旧注册（rollback），不悄悄丢掉旧快捷键。
//  纯 Foundation，无 AppKit。
//

import Foundation

/// 快捷键注册结果（中性 enum，允许记录）。
public enum ShortcutRegistrationOutcome: Equatable, Sendable {
    case configured
    case conflict
    case unavailable
}

/// 修饰键（中性位掩码；不存按键文本）。
public struct ShortcutModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let control = ShortcutModifiers(rawValue: 1 << 2)
    public static let shift = ShortcutModifiers(rawValue: 1 << 3)
}

/// 快捷键中性表示（虚拟键码 + 修饰键；不存真实快捷键文本）。
public struct ShortcutSpec: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// 注册状态 + 回滚语义：新注册失败（conflict/unavailable）时保留旧注册。
public struct ShortcutRegistration: Equatable, Sendable {
    public private(set) var spec: ShortcutSpec?
    public private(set) var outcome: ShortcutRegistrationOutcome?

    public init(spec: ShortcutSpec? = nil, outcome: ShortcutRegistrationOutcome? = nil) {
        self.spec = spec
        self.outcome = outcome
    }

    public var isConfigured: Bool {
        outcome == .configured
    }

    /// 应用一次注册结果；失败时保留旧注册（rollback），成功时替换为新组合。
    public func applying(_ newOutcome: ShortcutRegistrationOutcome, for newSpec: ShortcutSpec) -> ShortcutRegistration {
        switch newOutcome {
        case .configured:
            return ShortcutRegistration(spec: newSpec, outcome: .configured)
        case .conflict, .unavailable:
            return self
        }
    }

    /// 注销（teardown / 用户关闭）。
    public func unregistered() -> ShortcutRegistration {
        ShortcutRegistration(spec: nil, outcome: nil)
    }
}
