import AppKit

/// Library row presentation only. Counts keep trailing space independently of
/// the localized title, while accessibility and help retain the full pair.
@MainActor
final class AppLibraryCategoryCell: NSTableCellView {
    private let countLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        countLabel.identifier = NSUserInterfaceItemIdentifier("library.category.count")
        countLabel.lineBreakMode = .byClipping
        countLabel.usesSingleLineMode = true
        countLabel.alignment = .right
        textField = titleLabel
        addSubview(titleLabel)
        addSubview(countLabel)
        // Preserve the native text-cell accessibility topology. Only the new
        // visual count is decorative; the title retains the full spoken label.
        countLabel.setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func bind(title: String, count: Int) {
        textField?.stringValue = title
        countLabel.stringValue = String(count)
        let completeLabel = "\(title)  \(count)"
        setAccessibilityLabel(completeLabel)
        textField?.setAccessibilityLabel(completeLabel)
        toolTip = completeLabel
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 8
        let gap: CGFloat = 8
        let leading = bounds.minX + min(inset, max(0, bounds.width))
        let available = max(0, bounds.width - inset * 2)
        let countWidth = min(available, ceil(countLabel.intrinsicContentSize.width))
        let countX = leading + available - countWidth
        let height = min(20, max(0, bounds.height))
        let y = bounds.minY + max(0, (bounds.height - height) / 2)
        countLabel.frame = NSRect(x: countX, y: y, width: countWidth, height: height)
        textField?.frame = NSRect(x: leading, y: y,
            width: max(0, countX - gap - leading), height: height)
    }
}
