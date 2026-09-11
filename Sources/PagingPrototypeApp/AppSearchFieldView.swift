// PagingPrototypeApp — AppSearchFieldView（Phase 1D §7.1 中性搜索框）
// 实现：T-1D-D（Worker D）。
//
// 中性 NSSearchField：公开 AppKit 控件、系统字体/颜色、无第三方品牌、无预填/无历史/无持久化。
// 作为空白点击的显式 "interaction zone"（§7.1 / ADR-007 §2.7）：
// 点击 field / field editor / clear button / 子视图不触发空白单击退出。
// 分类 helper 供装配层（Worker E）在 blankClickResolvesToCell 中扩展。
//
// 隐私：不记录 query 原文 / 结果 app 名 / bundle ID / 路径 / URL / 图标数据。

import AppKit

/// 中性搜索框视图：公开 AppKit NSSearchField，无品牌、无预填、无历史、无持久化。
public final class AppSearchFieldView: NSSearchField {

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 中性可访问 label（§7.1）。
        setAccessibilityLabel("Search applications")
        // 中性占位文本（不含任何用户输入/身份信息）。
        placeholderString = "Search applications"
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 空白点击分类 helper（ADR-007 §2.7）：命中视图链（含 field editor / clear button /
    /// 子视图）是否属于搜索框交互区。供装配层在 blankClickResolvesToCell 中扩展。
    ///
    /// 覆盖三种命中：
    /// 1. 视图本身是 AppSearchFieldView；
    /// 2. 视图是 AppSearchFieldView 的子视图（clear button 等，沿 superview 链）；
    /// 3. 视图是 field editor（NSTextView，编辑中 first responder）——其 delegate 是
    ///    NSSearchField（NSSearchFieldCell 把 field editor 的 delegate 设为控件本身）。
    public static func isSearchFieldOrSubview(_ view: NSView?) -> Bool {
        var node = view
        while let current = node {
            if current is AppSearchFieldView { return true }
            if let textView = current as? NSTextView, textView.delegate is NSSearchField {
                return true
            }
            node = current.superview
        }
        return false
    }
}
