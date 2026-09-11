//
//  NeutralPageRenderer.swift
//  PagingUI
//
//  中性占位页面渲染器（Phase 1A 中性 tile 网格/调色板迁入，行为逐字迁移 → 零回归）。
//  - 渲染目标：init 绑定的承载视图（tile 子视图挂进目标层级；目标视图 layout() 时调用
//    layoutItems(in:) 完成布局）；
//  - 内容：page label（"Page X of M"）+ item 圆角 tile；item.title 非空显示标题，
//    否则画 slot+1 序号（Phase 1A 行为）；
//  - 调色板：确定性中性蓝灰系（无品牌色），索引 (page×7+item) % 6，alpha 0.85 —— 与
//    Phase 1A PageHostView.tileColor 完全一致；
//  - clearForReuse：清空全部 tile 子视图 + 隐藏 page label（复用路径不显示任何旧内容）。
//

import AppKit

/// 中性占位页面渲染器。
public final class NeutralPageRenderer: PagingPageRendering {

    /// 网格列数（中性布局常量，非旧产品常量）。
    private static let columns = 5
    private static let tileSpacing: CGFloat = 16
    private static let pageLabelHeight: CGFloat = 28
    private static let horizontalInset: CGFloat = 24
    private static let topInset: CGFloat = 96
    private static let maxTileHeight: CGFloat = 64

    /// 渲染目标承载视图（弱引用：宿主持有渲染器，避免环）。
    private weak var targetView: NSView?

    private let pageLabel = NSTextField(labelWithString: "")
    private var itemViews: [NSView] = []
    private var itemLabels: [NSTextField] = []

    /// 绑定渲染目标（承载视图）。
    public init(targetView: NSView) {
        self.targetView = targetView
        pageLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        pageLabel.textColor = .secondaryLabelColor
        pageLabel.alignment = .center
        pageLabel.lineBreakMode = .byTruncatingTail
        pageLabel.isHidden = true
    }

    // MARK: - PagingPageRendering

    /// 渲染一页中性内容：清空旧 tile 后按 content.items 重建（绝不显示旧内容）。
    public func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        removeAllItems()
        guard let targetView else { return }
        pageLabel.stringValue = "Page \(pageIndex + 1) of \(pageCount)"
        pageLabel.isHidden = false
        targetView.addSubview(pageLabel)

        for (index, item) in content.items.enumerated() {
            let tile = NSView()
            tile.wantsLayer = true
            tile.layer?.cornerRadius = 10
            tile.layer?.backgroundColor = Self.tileColor(page: pageIndex, item: index).cgColor
            let text: String
            if let title = item.title, !title.isEmpty {
                text = title
            } else {
                text = "\(item.slot + 1)"
            }
            let number = NSTextField(labelWithString: text)
            number.font = .systemFont(ofSize: 12)
            number.textColor = .labelColor
            number.alignment = .center
            number.lineBreakMode = .byTruncatingTail
            tile.addSubview(number)
            targetView.addSubview(tile)
            itemViews.append(tile)
            itemLabels.append(number)
        }
        targetView.needsLayout = true
    }

    /// 进入复用池前的清理：清空全部 tile（clearForReuse 后不显示任何旧内容）。
    public func clearForReuse() {
        removeAllItems()
        pageLabel.stringValue = ""
        pageLabel.isHidden = true
    }

    /// 当前 tile 数量（测试断言用）。
    internal var itemCount: Int { itemViews.count }

    private func removeAllItems() {
        for view in itemViews { view.removeFromSuperview() }
        itemViews.removeAll()
        itemLabels.removeAll()
    }

    // MARK: - 布局（Phase 1A PageHostView.layout 数学逐字迁移）

    /// 目标视图 layout() 时调用：对齐 page label 与 tile 网格。
    internal func layoutItems(in target: NSView) {
        guard targetView === target else { return }
        let width = target.bounds.width
        let height = target.bounds.height
        guard width > 0, height > 0 else { return }
        pageLabel.frame = CGRect(
            x: 0,
            y: max(height - Self.pageLabelHeight - 24, 0),
            width: width,
            height: Self.pageLabelHeight
        )

        let inset = Self.horizontalInset
        let topInset = Self.topInset
        let columns = Self.columns
        let spacing = Self.tileSpacing
        let rows = max(1, Int(ceil(Double(itemViews.count) / Double(columns))))
        let area = CGRect(
            x: inset, y: inset,
            width: max(width - inset * 2, 0), height: max(height - topInset - inset, 0)
        )
        guard area.width > 0, area.height > 0 else { return }
        let tileWidth = (area.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let tileHeight = min(Self.maxTileHeight, (area.height - CGFloat(rows - 1) * spacing) / CGFloat(rows))

        for (index, tile) in itemViews.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = area.minX + CGFloat(column) * (tileWidth + spacing)
            let y = area.maxY - CGFloat(row + 1) * (tileHeight + spacing)
            tile.frame = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
            if index < itemLabels.count {
                itemLabels[index].frame = tile.bounds
            }
        }
    }

    /// 确定性中性调色板（系统蓝灰系，无品牌色）——Phase 1A 逐字迁移。
    private static func tileColor(page: Int, item: Int) -> NSColor {
        let palette: [NSColor] = [
            .systemGray,
            .systemBlue,
            .systemIndigo,
            .systemTeal,
            .systemCyan,
            .systemPurple,
        ]
        let index = (page * 7 + item) % palette.count
        return palette[index].withAlphaComponent(0.85)
    }
}
