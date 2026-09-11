// AppGridUI — AppGridCellView（真实内容 cell：app 名同步文本 + 图标异步写回；
// Phase 1E 增加 folder cell 模式：中性符号 + 标题 + 成员计数）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）+ T-1E-C（Phase 1E folder cell）。
// BUG9 wave-a（T-1F-B9-wave-a）：hitTest 漏斗（icon/标签/背景点击统一路由 cell 自身
// mouseDown；唯一库内先例 FolderOverlayView.swift:297-303）+ cell 层 census s10/s11。
// AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// §6.4/§9：复用 cell 必须“清空 → 新内容 → 图标到达”，绝不短暂暴露旧 app 名/旧图标；
// 图标异步写回前做七字段 token 全匹配校验（stale apply = 0）；
// placeholder → icon 切换不造成布局跳动（图标 frame 固定）。
// 无障碍：cell accessibilityLabel = 完整 app 名（截断不影响辅助技术读取）。
//
// folder cell（T-1E-C）：中性独立视觉（SF Symbol "folder" + 标题 + 成员计数），
// 非 app-icon collage；与 app cell 可区分（isFolderCell）。folder cell 绝不请求 app 图标
// （applyIconIfValid 对 folder cell 恒拒绝）。复用清空同时清空 folder 符号/成员计数/焦点。

import AppKit

/// 单个 app 网格 cell（或 folder cell）。
public final class AppGridCellView: NSView {

    /// 图标区边长（pt）。固定 frame → 图标到达不引起布局跳动。
    public static let iconSide: CGFloat = 48

    /// 名称标签（同步文本；截断显示，完整名进 accessibility + toolTip）。
    public let nameLabel = NSTextField(labelWithString: "")
    /// 图标视图（异步写回目标；清空时同步置 nil）。
    public let iconView = NSImageView()

    /// 当前绑定 token（七字段）；nil = 已清空/未绑定。
    public private(set) var bindingToken: ItemBindingToken?

    /// 当前绑定的 app 显示名（清空 = ""）。
    public private(set) var boundName: String = ""

    /// 是否为 folder cell（中性符号 + 标题 + 成员计数；非 app-icon collage）。
    public private(set) var isFolderCell = false

    /// folder cell 的中性符号视图（SF Symbol "folder"；app cell 隐藏）。
    private let folderSymbolView = NSImageView()
    /// folder cell 的成员计数标签（如 "35 items"；app cell 隐藏）。
    private let memberCountLabel = NSTextField(labelWithString: "")

    /// folder cell 点击识别器（仅 isFolderCell 时触发 onFolderClick；app cell 恒 no-op）。
    private let folderClickRecognizer = NSClickGestureRecognizer()

    /// folder cell 的成员计数文本（测试/诊断；app cell 返回 ""）。
    public var memberCountText: String { memberCountLabel.stringValue }
    /// folder cell 的中性符号是否可见（测试/诊断；app cell 恒 false）。
    public var isFolderSymbolVisible: Bool { !folderSymbolView.isHidden }

    /// folder cell 点击回调（仅 folder cell 触发；app cell 恒不触发）。
    /// 回调收到从 binding token 身份读取的 FolderID（与渲染器同一来源）。
    /// 与 AppLaunchController 表面识别器可同时触发（预期）；本回调对 app cell 无操作。
    public var onFolderClick: ((FolderID) -> Void)?

    /// Phase 1F（T-1F-D1）：拖拽协调器（装配层注入；nil = 无 drag 仲裁 → 既有点击路径不变）。
    /// 生产经 `DragUISessionCoordinator.shared` 兜底（cell 由渲染器懒创建，无法逐 cell 注入）；
    /// 测试直接注入实例。
    public weak var dragCoordinator: DragUISessionCoordinator?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        iconView.frame = NSRect(x: 0, y: 0, width: Self.iconSide, height: Self.iconSide)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.imageAlignment = .alignCenter
        addSubview(iconView)

        folderSymbolView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        folderSymbolView.imageScaling = .scaleProportionallyUpOrDown
        folderSymbolView.imageAlignment = .alignCenter
        folderSymbolView.isHidden = true
        addSubview(folderSymbolView)

        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        addSubview(nameLabel)

        memberCountLabel.font = .systemFont(ofSize: 10)
        memberCountLabel.textColor = .secondaryLabelColor
        memberCountLabel.alignment = .center
        memberCountLabel.lineBreakMode = .byTruncatingTail
        memberCountLabel.maximumNumberOfLines = 1
        memberCountLabel.isHidden = true
        addSubview(memberCountLabel)

        setAccessibilityRole(.group)

        folderClickRecognizer.target = self
        folderClickRecognizer.action = #selector(handleFolderClick(_:))
        addGestureRecognizer(folderClickRecognizer)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 绑定新内容（app cell）：先同步清空（防旧名/旧图标残留）→ 写名称 → 记录 token。
    /// 图标由页面视图异步请求，到达后经 applyIconIfValid 门控写回。
    public func bind(name: String?, token: ItemBindingToken) {
        clearContent()
        bindingToken = token
        boundName = name ?? ""
        nameLabel.stringValue = boundName
        nameLabel.toolTip = boundName.isEmpty ? nil : boundName
        setAccessibilityRole(.group)
        setAccessibilityLabel(boundName.isEmpty ? nil : boundName)
        needsLayout = true
    }

    /// 绑定 folder cell：中性符号 + 标题 + 成员计数（非 app-icon collage）。
    /// 与 app cell 可区分（isFolderCell = true）；绝不请求/写回 app 图标。
    /// 无障碍：role = .button（可激活）、label = 标题、help = 成员计数描述。
    public func bindFolder(title: String?, memberCount: Int, token: ItemBindingToken) {
        clearContent()
        bindingToken = token
        isFolderCell = true
        boundName = title ?? ""
        nameLabel.stringValue = boundName
        nameLabel.toolTip = boundName.isEmpty ? nil : boundName
        memberCountLabel.stringValue = "\(memberCount) items"
        memberCountLabel.isHidden = false
        folderSymbolView.isHidden = false
        setAccessibilityRole(.button)
        setAccessibilityLabel(boundName.isEmpty ? nil : boundName)
        setAccessibilityHelp("Folder with \(memberCount) items")
        needsLayout = true
    }

    /// 同步清空（复用路径）：token、名称、图标、folder 符号/成员计数全部清空；绝不显示旧内容。
    /// 同时重置焦点视觉（layer border/background + accessibility focus），
    /// 使被非键盘页面切换（trackpad fling、refresh）回收的聚焦 cell 不残留旧焦点边框
    /// （Prompt §4.3：焦点视觉不能因 cell 复用残留在错误的 app 上）。
    public func clearContent() {
        bindingToken = nil
        boundName = ""
        nameLabel.stringValue = ""
        nameLabel.toolTip = nil
        iconView.image = nil
        isFolderCell = false
        folderSymbolView.isHidden = true
        memberCountLabel.stringValue = ""
        memberCountLabel.isHidden = true
        setAccessibilityRole(.group)
        setAccessibilityLabel(nil)
        setAccessibilityHelp(nil)
        setFocused(false)
    }

    /// 图标异步写回：七字段全匹配且 view 仍有效才 apply；否则 stale（返回 false）。
    /// folder cell 恒拒绝（folder cell 绝不显示 app 图标）。
    @discardableResult
    public func applyIconIfValid(_ image: NSImage, token: ItemBindingToken) -> Bool {
        guard !isFolderCell else { return false }
        guard let binding = bindingToken, binding == token else { return false }
        iconView.image = image
        return true
    }

    /// folder cell 点击处理：仅 isFolderCell 时触发 onFolderClick（app cell 恒 no-op）。
    /// FolderID 从 binding token 身份读取（bindingToken.appID as? FolderID），与渲染器同一来源。
    @objc internal func handleFolderClick(_ sender: NSClickGestureRecognizer) {
        guard isFolderCell else { return }
        guard let folderID = bindingToken?.appID as? FolderID else { return }
        onFolderClick?(folderID)
    }

    // MARK: - Phase 1F：统一输入仲裁（T-1F-D1）

    /// 点击识别抑制：仲裁窗口内禁用本 cell 自身识别器（防 mouse-up 双重派发）。
    /// 由 coordinator 在 pointerDown/会话结束时调用（单一所有者）。
    public func setClickRecognitionEnabled(_ enabled: Bool) {
        folderClickRecognizer.isEnabled = enabled
    }

    /// pointer-down → coordinator 仲裁（pressed / 空白点击候选）。
    /// 不调用 super：事件由仲裁层全权处理；gesture recognizer 独立接收事件不受影响。
    /// census（T-1F-B9-wave-a）：s10 = mouseDown 入口到达（漏斗出口证据）；
    /// s11 = `dragCoordinator ?? shared` 解析为 nil（已到 cell 但无仲裁下游）。
    public override func mouseDown(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.cellMouseDownFired)
        guard let coordinator = dragCoordinator ?? DragUISessionCoordinator.shared else {
            ClickCensus.hit(ClickCensus.Sink.cellLookupNil)
            return
        }
        coordinator.pointerDown(locationInWindow: event.locationInWindow, sourceCell: self, memberFolderID: nil)
    }

    public override func mouseDragged(with event: NSEvent) {
        (dragCoordinator ?? DragUISessionCoordinator.shared)?
            .pointerDragged(locationInWindow: event.locationInWindow)
    }

    public override func mouseUp(with event: NSEvent) {
        (dragCoordinator ?? DragUISessionCoordinator.shared)?
            .pointerUp(locationInWindow: event.locationInWindow)
    }

    /// BUG9 wave-a：子视图被动拦截 → cell 自行承接命中。
    /// 2026-09-11：热区 = **仅图标**（folder 为 folderSymbol 同框）外扩 4pt。
    /// 名称文字 / tile 大块 padding 不当作启动热区，减少点空白误启动。
    /// point 约定与既有路径一致：父视图坐标系（frame.contains 先筛）。
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = superview.map { convert(point, from: $0) } ?? point
        // 图标区：app 用 iconView；folder 用同位置的 folderSymbolView（可见时）。
        let iconFrame = isFolderCell ? folderSymbolView.frame : iconView.frame
        let padded = iconFrame.insetBy(dx: -4, dy: -4)
        return padded.contains(local) ? self : nil
    }

    public override func layout() {
        super.layout()
        let width = bounds.width
        let iconX = (width - Self.iconSide) / 2
        let iconFrame = NSRect(x: iconX, y: bounds.height - Self.iconSide - 12,
                               width: Self.iconSide, height: Self.iconSide)
        iconView.frame = iconFrame
        folderSymbolView.frame = iconFrame
        nameLabel.frame = NSRect(x: 2, y: 0, width: max(width - 4, 0), height: 14)
        memberCountLabel.frame = NSRect(x: 2, y: 14, width: max(width - 4, 0), height: 12)
    }
}

// MARK: - BUG9 wave-a census sinks（T-1F-B9-wave-a：cell 层布点；单文件波，零触碰 coordinator 核心）

extension ClickCensus.Sink {
    /// AppGridCellView.mouseDown 入口到达（「窗口 s8d 放行 → cell.mouseDown」未布点区间的
    /// cell 层证据；s10 有值而 s0-s9 全零 = 断点在 cell → coordinator 之间）。
    public static let cellMouseDownFired = "s10_cell_mousedown_fired"
    /// cell 内 `(dragCoordinator ?? DragUISessionCoordinator.shared)` 解析为 nil
    /// （mouseDown 已到达但无仲裁可用；BUG9-REPORT §2「排除 B」的运行时复核点）。
    public static let cellLookupNil = "s11_cell_lookup_nil"
}
