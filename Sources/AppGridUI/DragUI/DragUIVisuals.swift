// AppGridUI — DragUI.DragUIVisuals（Phase 1F §5.6 / ADR-010）
// 实现：T-1F-D1（Worker）。
//
// 中性拖拽视觉（不复制任何被禁来源；无真实 app 截图）：
// - drag preview：中性圆角胶囊 + 条目标题文本（与 cell 同源文本；无图标/截图）。
// - insertion 指示：细竖条（顶层/成员间插入带）。
// - folder 高亮：目标 folder cell 圆角描边。
// - create-folder 指示：虚线圆角框 + "+" 徽标（与 insertion 竖条形状可区分，非仅颜色）。
// - Reduce Motion：禁缩放/飞行动画（仅透明度过渡或零动画）。
//
// 隐私：视觉视图不携带任何身份原文进 telemetry/日志/报告；preview 文本与 cell 同源。

import AppKit

/// Phase 1F：中性拖拽视觉（T-1F-D1）。
@MainActor
public final class DragUIVisuals {

    private weak var host: NSView?
    private let reduceMotionProvider: () -> Bool

    private let previewView = NSView()
    private let previewIconView = NSImageView()
    private let previewNameLabel = NSTextField(labelWithString: "")
    private let insertionIndicator = NSView()
    private let folderHighlight = NSView()
    private let createFolderIndicator = NSView()
    private let createFolderBadge = NSTextField(labelWithString: "+")

    // MARK: - 可观测状态（测试/诊断）

    public var isPreviewVisible: Bool { !previewView.isHidden }
    public var isInsertionIndicatorVisible: Bool { !insertionIndicator.isHidden }
    public var isFolderHighlightVisible: Bool { !folderHighlight.isHidden }
    public var isCreateFolderIndicatorVisible: Bool { !createFolderIndicator.isHidden }
    /// preview 迷你 cell 的图标（测试/诊断；源 cell 无图标时为 nil）。
    public var previewIconImage: NSImage? { previewIconView.image }
    /// preview 迷你 cell 的名称文本（测试/诊断）。
    public var previewNameText: String { previewNameLabel.stringValue }
    /// preview 容器 frame（host 坐标系；测试/诊断）。
    public var previewFrame: NSRect { previewView.frame }
    /// insertion 竖条 frame（host 坐标系；测试/诊断，BUG8 wave-v）。
    public var insertionIndicatorFrame: NSRect { insertionIndicator.frame }
    /// 四视觉视图当前挂载父视图（测试/诊断；BUG10 宿主切换迁移与 teardown 零残留断言）。
    /// 顺序：[preview, insertionIndicator, folderHighlight, createFolderIndicator]。
    public var visualViewSuperviews: [NSView?] {
        [previewView, insertionIndicator, folderHighlight, createFolderIndicator].map { $0.superview }
    }
    public var reduceMotion: Bool { reduceMotionProvider() }

    /// pointer-aware seam 调用次数（模块内测试观测；不构成 public API）。
    /// 用于锁住 coordinator 的刷新预算：create-folder/folder-highlight 等
    /// 非 insertion 视觉不得在 intent 未变时逐帧重建。
    var pointerAwareRefreshCountForTesting: Int { pointerAwareRefreshCount }
    private var pointerAwareRefreshCount = 0
    /// move-out 折叠会隐藏源 cell；preview 必须持有独立图标副本，不能继续读 hidden cell。
    private var cachedPreviewIcon: NSImage?
    private var cachedPreviewName: String = ""
    /// preview 已抬到 window.contentView（盖过 overlay）时，setHost 不得再把它拽回 surface。
    private var previewElevatedAboveOverlay = false

    public init(host: NSView?, reduceMotionProvider: @escaping () -> Bool) {
        self.host = host
        self.reduceMotionProvider = reduceMotionProvider
        configureViews()
    }

    // MARK: - 宿主切换（BUG10 缺陷 B，方案 B1）

    /// 切换视觉宿主（folder scope → overlay；topLevel → surface）。weak 语义保持。
    /// 切换时旧宿主上**已挂载**的视觉视图立即迁移（AppKit addSubview 自动从旧父移除；
    /// attach 的 `view.superview !== host` 短路保证同一视图绝不挂两父/漂移）；
    /// 未挂载（含 teardown 后）不重新挂载。同值重复调用幂等。
    /// 生产唯一驱动点：`DragUISessionCoordinator.setVisualHost`（AppDelegate
    /// refreshFolderOverlay 调用）——preview 坐标系与指针坐标系必须同源。
    public func setHost(_ newHost: NSView?) {
        host = newHost
        guard let newHost else { return }
        for view in [previewView, insertionIndicator, folderHighlight, createFolderIndicator] {
            if view === previewView, previewElevatedAboveOverlay { continue }
            if view.superview != nil, view.superview !== newHost {
                newHost.addSubview(view)
            }
        }
    }

    // MARK: - Preview

    /// 显示 drag preview（host 坐标系；pointer 上方 24pt 居中）：源 cell 的迷你视觉副本
    /// （图标 + 名称，布局与 AppGridCellView 一致：图标上、名称下）。
    /// 内容与源 cell 同源（cell 自身图标/名称）——无新隐私暴露。
    public func showPreview(sourceCell: AppGridCellView?, at point: NSPoint) {
        guard host != nil else { return }
        capturePreview(from: sourceCell)
        applyCachedPreviewContent()
        placePreview(at: point)
        attach(previewView)
        bringPreviewToFront()
        previewView.isHidden = false
        // 不用淡入动画：move-out 立刻切宿主会打断 animator，alpha 可能卡在 0。
        previewView.alphaValue = 1
    }

    /// 跟随 pointer（host 坐标系）。
    public func movePreview(to point: NSPoint) {
        guard !previewView.isHidden else { return }
        placePreview(at: point)
    }

    /// 在 panel 折叠前调用：强制从源 cell 再抓一份位图（比读 image 属性更稳）。
    public func capturePreview(from sourceCell: AppGridCellView?) {
        cachedPreviewName = sourceCell?.boundName ?? cachedPreviewName
        if let snap = Self.snapshotImage(of: sourceCell?.iconView)
            ?? Self.snapshotImage(of: sourceCell)
            ?? durableImage(sourceCell?.iconView.image) {
            cachedPreviewIcon = snap
        }
        applyCachedPreviewContent()
    }

    /// move-out 切宿主后重申 preview：缓存图标 + 置顶 + 强制不透明。
    public func reaffirmPreview(at point: NSPoint) {
        guard host != nil else { return }
        applyCachedPreviewContent()
        placePreview(at: point)
        attach(previewView)
        bringPreviewToFront()
        previewView.isHidden = false
        previewView.alphaValue = 1
    }

    /// 把 preview 挂到 `above` 之上的窗口 contentView（盖过 folder overlay）。
    public func elevatePreviewAbove(_ sibling: NSView, at point: NSPoint) {
        guard let content = sibling.window?.contentView else {
            reaffirmPreview(at: point)
            return
        }
        previewElevatedAboveOverlay = true
        // 注意：不改 self.host——几何/蓝条仍跟 visualHost；仅 preview 抬层。
        applyCachedPreviewContent()
        placePreview(at: point)
        content.addSubview(previewView, positioned: .above, relativeTo: sibling)
        previewView.isHidden = false
        previewView.alphaValue = 1
    }

    // MARK: - Intent 指示

    /// 按 drop intent 更新指示（host 坐标系 frames）。
    /// 跨行 index 在没有 pointer 的兼容调用中使用前帧右缘这一确定性 fallback；
    /// coordinator 通过下面的 pointer-aware seam 选择当前/最近行。
    public func updateIntent(_ intent: DropIntent, geometry: DragGeometry) {
        updateIntent(intent, geometry: geometry, pointer: nil)
    }

    /// 按 drop intent 更新指示，并用当前 pointer 选择跨行插入槽的视觉锚点。
    ///
    /// 这是 coordinator 使用的 module-internal seam；保留上面的 public 入口以兼容
    /// 既有调用方。同行槽位仍使用相邻帧中点，只有跨行槽位读取 pointer 的行距离。
    func updateIntent(_ intent: DropIntent, geometry: DragGeometry, pointer: DragPoint) {
        pointerAwareRefreshCount += 1
        updateIntent(intent, geometry: geometry, pointer: Optional(pointer))
    }

    private func updateIntent(_ intent: DropIntent, geometry: DragGeometry, pointer: DragPoint?) {
        switch intent {
        case .insertion(let index):
            showInsertionBar(at: index, frames: geometry.itemFrames, pointer: pointer)
            hide(folderHighlight, createFolderIndicator)
        case .topLevelTarget(let index):
            showInsertionBar(at: index, frames: geometry.topLevelFrames, pointer: pointer)
            hide(folderHighlight, createFolderIndicator)
        case .intoFolder(let target, _):
            if let frame = frame(for: .folder(target), in: geometry) {
                showFolderHighlight(frame)
            } else {
                hide(folderHighlight)
            }
            hide(insertionIndicator, createFolderIndicator)
        case .createFolder(let target):
            if let frame = frame(for: .app(target), in: geometry) {
                showCreateFolderIndicator(frame)
            } else {
                hide(createFolderIndicator)
            }
            hide(insertionIndicator, folderHighlight)
        case .invalid:
            // 只清落点指示，绝不拆跟手 preview。
            // move-out 离开成员行、尚未命中顶层缝隙时 intent=.invalid；
            // 若 clearAll() 会把灰底胶囊一并干掉（用户实机：「连灰底都没有」）。
            hide(insertionIndicator, folderHighlight, createFolderIndicator)
        }
    }

    /// 清空全部指示（会话结束/cancel 路径）。
    public func clearAll() {
        previewView.isHidden = true
        insertionIndicator.isHidden = true
        folderHighlight.isHidden = true
        createFolderIndicator.isHidden = true
        cachedPreviewIcon = nil
        cachedPreviewName = ""
        previewElevatedAboveOverlay = false
        // 若曾抬到 contentView，清掉以免残留在窗口上。
        if previewView.superview != nil, previewView.superview !== host {
            previewView.removeFromSuperview()
        }
    }

    /// teardown：从宿主移除全部视觉视图（幂等）。
    public func teardown() {
        clearAll()
        previewView.removeFromSuperview()
        insertionIndicator.removeFromSuperview()
        folderHighlight.removeFromSuperview()
        createFolderIndicator.removeFromSuperview()
    }

    // MARK: - 私有

    // BUG8 wave-v（T-1F-B8）：intent 携带**全局**下标（DropIntent 产出边界换算
    // globalIndex = page * itemsPerPage + localIndex），而 frames 是**页内**帧列表
    // → 入口先做 global→local 回减，覆盖 .insertion 与 .topLevelTarget 两条路径。
    private func showInsertionBar(at globalIndex: Int,
                                  frames: [DragItemFrame],
                                  pointer: DragPoint?) {
        let index = localInsertionIndex(fromGlobal: globalIndex, frames: frames)
        guard let rect = insertionRect(for: index, frames: frames, pointer: pointer) else {
            hide(insertionIndicator)
            return
        }
        attach(insertionIndicator)
        insertionIndicator.frame = NSRect(x: CGFloat(rect.x), y: CGFloat(rect.y),
                                          width: CGFloat(rect.width), height: CGFloat(rect.height))
        insertionIndicator.isHidden = false
    }

    /// global→local 回减（BUG8 wave-v，BUG8-REPORT §1 定案修法）：读**帧注记**
    /// （首帧 pageIndex/itemsPerPage；同一帧列表属同一页，帧间注记一致——与
    /// DropIntent.globalIndex 同契约）。`local = global − pageIndex × itemsPerPage`，
    /// clamp 到 [0, frames.count]（防全局公式与注记页号不一致时越界；
    /// local == count = 页末右缘是正确位）。
    /// 注记 nil → 原样返回（page 0 / folder 成员帧 / 夹具直构向后兼容，
    /// 兼收 T-1F-B7-wave-b r1 MINOR-3 语义）。
    /// 绝不使用 geometry.page（folder scope 下 = innerPage，页号陷阱）；只信帧注记。
    private func localInsertionIndex(fromGlobal globalIndex: Int, frames: [DragItemFrame]) -> Int {
        guard let first = frames.first,
              let pageIndex = first.pageIndex,
              let itemsPerPage = first.itemsPerPage else { return globalIndex }
        let local = globalIndex - pageIndex * itemsPerPage
        return min(max(local, 0), frames.count)
    }

    private func showFolderHighlight(_ frame: DragRect) {
        attach(folderHighlight)
        folderHighlight.frame = NSRect(x: CGFloat(frame.x), y: CGFloat(frame.y),
                                       width: CGFloat(frame.width), height: CGFloat(frame.height))
        folderHighlight.isHidden = false
    }

    private func showCreateFolderIndicator(_ frame: DragRect) {
        attach(createFolderIndicator)
        createFolderIndicator.frame = NSRect(x: CGFloat(frame.x), y: CGFloat(frame.y),
                                             width: CGFloat(frame.width), height: CGFloat(frame.height))
        // 虚线圆角描边（与 insertion 竖条形状可区分，非仅颜色）。
        let shape = CAShapeLayer()
        shape.path = CGPath(roundedRect: createFolderIndicator.bounds,
                            cornerWidth: 10, cornerHeight: 10, transform: nil)
        shape.strokeColor = NSColor.controlAccentColor.cgColor
        shape.fillColor = NSColor.clear.cgColor
        shape.lineWidth = 2
        shape.lineDashPattern = [6, 4]
        createFolderIndicator.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        createFolderIndicator.layer?.addSublayer(shape)
        createFolderIndicator.isHidden = false
    }

    /// 插入带位置：index 0 → 首条目左侧；index == count → 末条目右侧；同行槽位
    /// 使用相邻条目中点；跨行槽位按 pointer 选择前一行右缘或后一行左缘。
    private func insertionRect(for index: Int,
                               frames: [DragItemFrame],
                               pointer: DragPoint?) -> DragRect? {
        guard !frames.isEmpty else { return nil }
        let barWidth = 3.0
        if index <= 0 {
            let f = frames[0].frame
            return DragRect(x: max(0, f.minX - 4), y: f.minY, width: barWidth, height: f.height)
        }
        if index >= frames.count {
            let f = frames[frames.count - 1].frame
            return DragRect(x: f.maxX - barWidth, y: f.minY, width: barWidth, height: f.height)
        }
        let a = frames[index - 1].frame
        let b = frames[index].frame
        if !verticalIntervalsOverlap(a, b) {
            // 无 pointer 的兼容入口仍不得回到跨行中点这一错误位置；以阅读序
            // 较早的前帧右缘作为确定性 canonical fallback。coordinator 的
            // pointer-aware seam 会在同一 index 的下一行左半命中时改选后帧。
            if let pointer {
                let previousDistance = verticalDistance(from: pointer.y, to: a)
                let nextDistance = verticalDistance(from: pointer.y, to: b)
                if previousDistance > nextDistance {
                    return DragRect(x: max(0, b.minX - 4), y: b.minY,
                                    width: barWidth, height: b.height)
                }
            }
            return DragRect(x: a.maxX - barWidth, y: a.minY,
                            width: barWidth, height: a.height)
        }
        let x = (a.maxX + b.minX) / 2 - barWidth / 2
        return DragRect(x: x, y: min(a.minY, b.minY), width: barWidth, height: max(a.height, b.height))
    }

    /// 只有竖直区间真正分离时才是跨行槽；接触边界仍视为重叠，和逻辑层闭区间一致。
    private func verticalIntervalsOverlap(_ a: DragRect, _ b: DragRect) -> Bool {
        a.minY <= b.maxY && b.minY <= a.maxY
    }

    /// pointer 到帧竖直区间的距离；区间内为 0，适配 y-up 与 y-down。
    private func verticalDistance(from y: Double, to frame: DragRect) -> Double {
        if y < frame.minY { return frame.minY - y }
        if y > frame.maxY { return y - frame.maxY }
        return 0
    }

    private func frame(for identity: DragItemIdentity, in geometry: DragGeometry) -> DragRect? {
        (geometry.itemFrames + geometry.topLevelFrames)
            .first { $0.identity == identity }?
            .frame
    }

    private func attach(_ view: NSView) {
        guard let host, view.superview !== host else { return }
        host.addSubview(view)
    }

    private func hide(_ views: NSView...) {
        for view in views { view.isHidden = true }
    }

    private func applyCachedPreviewContent() {
        previewIconView.image = cachedPreviewIcon
        previewNameLabel.stringValue = cachedPreviewName
        layoutPreviewContent()
    }

    private func placePreview(at point: NSPoint) {
        let size = NSSize(width: 96, height: 88)
        // 坐标相对当前 preview 父视图（可能是 host，也可能是抬升后的 contentView）。
        let space = previewView.superview ?? host
        let flipped = space?.isFlipped ?? false
        let y = flipped ? point.y - size.height - 12 : point.y + 24
        previewView.frame = NSRect(x: point.x - size.width / 2, y: y,
                                   width: size.width, height: size.height)
    }

    private func bringPreviewToFront() {
        guard let host, previewView.superview === host else { return }
        host.addSubview(previewView, positioned: .above, relativeTo: nil)
    }

    private func durableImage(_ image: NSImage?) -> NSImage? {
        guard let image else { return nil }
        if let tiff = image.tiffRepresentation, let copy = NSImage(data: tiff) {
            return copy
        }
        return image.copy() as? NSImage ?? image
    }

    /// 把 NSView 当前像素内容打成独立 NSImage（不依赖 image 属性是否仍挂着）。
    private static func snapshotImage(of view: NSView?) -> NSImage? {
        guard let view else { return nil }
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// 迷你 cell 内容布局（与 AppGridCellView.layout 一致：图标上、名称下）。
    private func layoutPreviewContent() {
        let bounds = previewView.bounds
        let iconSide = AppGridCellView.iconSide
        let iconX = (bounds.width - iconSide) / 2
        previewIconView.frame = NSRect(x: iconX, y: bounds.height - iconSide - 12,
                                       width: iconSide, height: iconSide)
        previewNameLabel.frame = NSRect(x: 2, y: 0, width: max(bounds.width - 4, 0), height: 14)
    }

    private func configureViews() {
        previewView.wantsLayer = true
        previewView.layer?.cornerRadius = 12
        previewView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        previewView.layer?.borderWidth = 1
        previewView.layer?.borderColor = NSColor.separatorColor.cgColor
        previewView.layer?.shadowColor = NSColor.black.cgColor
        previewView.layer?.shadowOpacity = 0.25
        previewView.layer?.shadowRadius = 6
        previewView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        previewIconView.imageScaling = .scaleProportionallyUpOrDown
        previewIconView.imageAlignment = .alignCenter
        previewNameLabel.font = .systemFont(ofSize: 11)
        previewNameLabel.textColor = .labelColor
        previewNameLabel.alignment = .center
        previewNameLabel.lineBreakMode = .byTruncatingTail
        previewNameLabel.maximumNumberOfLines = 1
        previewView.addSubview(previewIconView)
        previewView.addSubview(previewNameLabel)

        insertionIndicator.wantsLayer = true
        insertionIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        insertionIndicator.layer?.cornerRadius = 1.5

        folderHighlight.wantsLayer = true
        folderHighlight.layer?.cornerRadius = 10
        folderHighlight.layer?.borderWidth = 2
        folderHighlight.layer?.borderColor = NSColor.controlAccentColor.cgColor

        createFolderIndicator.wantsLayer = true
        createFolderIndicator.layer?.cornerRadius = 10
        createFolderBadge.font = .systemFont(ofSize: 14, weight: .bold)
        createFolderBadge.textColor = .controlAccentColor
        createFolderBadge.alignment = .center
        createFolderBadge.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        createFolderBadge.autoresizingMask = [.minXMargin, .maxYMargin]
        createFolderIndicator.addSubview(createFolderBadge)

        // 初始隐藏全部指示视图（NSView isHidden 默认 false；isPreviewVisible 等须从 false 起步）。
        hide(previewView, insertionIndicator, folderHighlight, createFolderIndicator)
    }
}
