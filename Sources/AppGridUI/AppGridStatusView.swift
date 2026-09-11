// AppGridUI — AppGridStatusView（§3.1.11 中性 UI 状态视图）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 中性状态展示：loading / 空目录 / 部分失败 / 刷新中 / ready。
// 文本与可访问描述全部中性（不含 app 名 / bundle ID / 路径，§3.3 红线）。
// 装配层（Wave 3）将此视图置于网格之上；网格为空目录/失败时可见。

import AppKit

/// 中性状态视图（状态文本 + 忙碌 spinner）。
public final class AppGridStatusView: NSView {

    /// 当前展示状态。
    public private(set) var state: AppGridUIState = .loading

    /// 当前渲染的状态文本（= state.accessibilityDescription）。
    public var statusText: String { label.stringValue }

    private let label = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        addSubview(label)

        spinner.style = .spinning
        spinner.isDisplayedWhenStopped = false
        spinner.controlSize = .regular
        addSubview(spinner)

        setAccessibilityRole(.staticText)
        updateView(state: .loading)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 更新状态：文本 + spinner + 可访问描述（§9）。
    public func update(state: AppGridUIState) {
        guard state != self.state else { return }
        updateView(state: state)
    }

    private func updateView(state: AppGridUIState) {
        self.state = state
        label.stringValue = state.accessibilityDescription
        setAccessibilityLabel(state.accessibilityDescription)
        let busy = state.isBusy
        if busy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
        spinner.isHidden = !busy
        needsLayout = true
    }

    public override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height
        let textHeight: CGFloat = 20
        let spinnerSide: CGFloat = 20
        if state.isBusy {
            let totalHeight = textHeight + 10 + spinnerSide
            spinner.frame = NSRect(x: (width - spinnerSide) / 2,
                                   y: height - (height - totalHeight) / 2 - spinnerSide,
                                   width: spinnerSide, height: spinnerSide)
            label.frame = NSRect(x: 8, y: spinner.frame.minY - 10 - textHeight,
                                 width: max(width - 16, 0), height: textHeight)
        } else {
            label.frame = NSRect(x: 8, y: (height - textHeight) / 2,
                                 width: max(width - 16, 0), height: textHeight)
        }
    }
}
