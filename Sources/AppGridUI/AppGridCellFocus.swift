// AppGridUI — AppGridCellFocus（Phase 1C §4.2/§4.3 焦点视觉 + accessibility）
// 实现：T-1C-B（Worker B）。
//
// AppGridCellView 扩展：setFocused(_:) 增量设置焦点视觉状态（layer border/background）
// + accessibility focus。视觉焦点、accessibility 焦点与实际启动对象保持一致
// （调用方保证 cell 绑定与焦点身份匹配）。
//
// 隐私：不记录 app 名 / bundle ID / 路径 / URL / 图标数据 / 用户输入。

import AppKit

public extension AppGridCellView {
    /// 当前是否处于键盘焦点视觉状态（layer borderWidth > 0）。
    var isFocused: Bool {
        (layer?.borderWidth ?? 0) > 0
    }

    /// 增量设置焦点视觉状态（layer border/background）+ accessibility focus。
    /// - Parameter focused: true = 高亮（border + 选中背景 + accessibility focus）；
    ///   false = 取消高亮（还原默认背景 + 清除 accessibility focus）。
    func setFocused(_ focused: Bool) {
        if focused {
            layer?.borderWidth = 3
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.selectedControlColor.cgColor
            setAccessibilityFocused(true)
        } else {
            layer?.borderWidth = 0
            layer?.borderColor = NSColor.clear.cgColor
            layer?.backgroundColor = nil
            setAccessibilityFocused(false)
        }
    }
}
