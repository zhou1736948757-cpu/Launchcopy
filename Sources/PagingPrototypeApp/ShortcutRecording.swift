//
//  ShortcutRecording.swift
//  PagingPrototypeApp
//
//  Phase 1H：全局快捷键预设 + 录制辅助（纯映射 / 轻量 AppKit 标志转换）。
//  - keyCode → 可读显示名；未知回退「键码 N」
//  - NSEvent.ModifierFlags → ShortcutModifiers（仅 cmd/opt/ctrl/shift）
//  - 常用预设表（Command+Option+Space 等）
//  不安装全局 NSEvent monitor / CGEvent tap；录制由 Settings 窗本地 monitor 调用本层解释。
//

import AppKit
import Foundation

// MARK: - Display

/// 快捷键可读显示（中性 keyCode + 修饰键 → `⌘⌥Space` 形式）。
public enum ShortcutDisplay {
    /// 已知虚拟键码的短显示名（US ANSI 布局常见键；未知返回 nil）。
    public static func keyName(forKeyCode keyCode: UInt32) -> String? {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 76: return "Enter"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return nil
        }
    }

    /// 修饰键符号串（顺序：⌃⌥⇧⌘，与 macOS 菜单惯例一致）。
    public static func modifierSymbols(_ modifiers: ShortcutModifiers) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    /// 人类可读描述：`⌘⌥Space`；未知键码回退 `⌘⌥·键码 N`。
    public static func description(for spec: ShortcutSpec) -> String {
        let mods = modifierSymbols(spec.modifiers)
        if let name = keyName(forKeyCode: spec.keyCode) {
            return mods.isEmpty ? name : "\(mods)\(name)"
        }
        if mods.isEmpty {
            return "键码 \(spec.keyCode)"
        }
        return "\(mods)·键码 \(spec.keyCode)"
    }
}

// MARK: - Presets

/// Settings「预设」弹出菜单项（tag 与菜单项对应；自定义 = -1）。
public enum ShortcutPreset: Int, CaseIterable, Equatable, Sendable {
    case custom = -1
    case commandOptionSpace = 0
    case controlCommandSpace = 1
    case commandOptionL = 2
    case controlOptionL = 3

    /// 菜单标题（自定义用独立文案；其余用 ShortcutDisplay）。
    public var menuTitle: String {
        switch self {
        case .custom:
            return "自定义…"
        case .commandOptionSpace, .controlCommandSpace, .commandOptionL, .controlOptionL:
            guard let spec else { return "自定义…" }
            return ShortcutDisplay.description(for: spec)
        }
    }

    /// 预设对应 ShortcutSpec；自定义为 nil（保留当前自定义值）。
    public var spec: ShortcutSpec? {
        switch self {
        case .custom:
            return nil
        case .commandOptionSpace:
            return ShortcutSpec(keyCode: 49, modifiers: [.command, .option])
        case .controlCommandSpace:
            return ShortcutSpec(keyCode: 49, modifiers: [.control, .command])
        case .commandOptionL:
            return ShortcutSpec(keyCode: 37, modifiers: [.command, .option])
        case .controlOptionL:
            return ShortcutSpec(keyCode: 37, modifiers: [.control, .option])
        }
    }

    /// 菜单展示顺序（自定义置顶，其余按声明）。
    public static var menuOrder: [ShortcutPreset] {
        [.custom, .commandOptionSpace, .controlCommandSpace, .commandOptionL, .controlOptionL]
    }

    /// 若 spec 精确匹配某个非自定义预设则返回该预设，否则 `.custom`。
    public static func matching(_ spec: ShortcutSpec?) -> ShortcutPreset {
        guard let spec else { return .custom }
        for preset in menuOrder where preset != .custom {
            if preset.spec == spec { return preset }
        }
        return .custom
    }
}

// MARK: - NSEvent flag / keyDown interpretation

/// 录制键解释结果（纯逻辑；由 Settings 本地 monitor 消费）。
public enum ShortcutRecordingInterpretation: Equatable, Sendable {
    /// Escape：取消录制，不改草稿。
    case cancel
    /// 裸键（无修饰）：拒绝，保持录制。
    case rejectBareKey
    /// 合法组合：产出 ShortcutSpec。
    case accept(ShortcutSpec)
}

/// 录制辅助：修饰键标志映射 + keyDown 解释（无 monitor 生命周期）。
public enum ShortcutRecording {
    /// 从 NSEvent.ModifierFlags 提取 ShortcutModifiers（忽略 capsLock / numericPad / function 等）。
    public static func modifiers(from flags: NSEvent.ModifierFlags) -> ShortcutModifiers {
        var result: ShortcutModifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        return result
    }

    /// 解释一次 keyDown（keyCode + flags）。Escape 优先于修饰键检查。
    public static func interpretKeyDown(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ShortcutRecordingInterpretation {
        if keyCode == 53 { // Esc
            return .cancel
        }
        let mods = modifiers(from: modifierFlags)
        if mods.isEmpty {
            return .rejectBareKey
        }
        return .accept(ShortcutSpec(keyCode: UInt32(keyCode), modifiers: mods))
    }
}
