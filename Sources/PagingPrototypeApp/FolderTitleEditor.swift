// PagingPrototypeApp — FolderTitleEditor（Phase 1E §3.1D 标题编辑 first responder；ADR-008 §3 Q11）
// 实现：T-1E-D（Worker D）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 打开层内的标题编辑 first responder（NSTextField）：
// - Enter 提交（规范化：trim / 空白回退 / 64-Character 上限 / Unicode 安全，经 FolderTitle.normalized）；
// - Escape 取消（不提交）；
// - focus-loss 确定性提交（与 Enter 一致）；
// - 编辑中箭头/Return 不启动 app（本视图为 first responder，吞掉编辑键；Tab 等交 AppKit）；
// - 无磁盘写入、无 telemetry/JSONL/stdout/signpost/profile/report（标题文本绝不外泄）。
//
// 隐私硬边界：标题文本绝不进入 telemetry/JSONL/stdout/signpost/profile/report，绝不落盘。

import AppGridUI
import AppKit

/// 标题编辑 first responder：Enter 提交 / Escape 取消 / focus-loss 确定性提交。
@MainActor
public final class FolderTitleEditor: NSTextField, NSTextFieldDelegate {

    /// 提交回调（携带规范化后的标题；T-1E-E 接线到装配层）。
    public var onCommit: ((String) -> Void)?
    /// 取消回调（T-1E-E 接线到装配层）。
    public var onCancel: (() -> Void)?
    /// 空白标题回退（中性；缺省 "Folder"）。
    public var fallbackTitle: String = "Folder"

    /// 是否已结束（Enter/Escape/focus-loss 后置位，防重复提交/取消）。
    private var didFinish = false

    public init() {
        super.init(frame: .zero)
        self.delegate = self
        self.isEditable = true
        self.isSelectable = true
        self.isBordered = true
        self.bezelStyle = .roundedBezel
        self.placeholderString = "Folder name"
        self.maximumNumberOfLines = 1
        self.cell?.isScrollable = true
        self.cell?.wraps = false
        self.setAccessibilityLabel("Folder name")
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override var acceptsFirstResponder: Bool { true }

    // MARK: - 命令处理（Enter / Escape / Tab）

    public func control(_ control: NSControl, textView: NSTextView,
                        doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            commit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            cancel()
            return true
        default:
            return false // Tab 等 → AppKit responder chain，不非法吞键
        }
    }

    // MARK: - focus-loss 确定性提交

    public func controlTextDidEndEditing(_ obj: Notification) {
        // focus-loss → 确定性提交（与 Enter 一致）。
        commit()
    }

    // MARK: - 提交 / 取消

    /// 提交：规范化标题（空白回退 / 长度上限 / Unicode 安全）后回调；幂等。
    public func commit() {
        guard !didFinish else { return }
        didFinish = true
        let normalized = FolderTitle.normalized(stringValue, fallback: fallbackTitle)
        onCommit?(normalized)
    }

    /// 取消：不提交；幂等。
    public func cancel() {
        guard !didFinish else { return }
        didFinish = true
        onCancel?()
    }
}
