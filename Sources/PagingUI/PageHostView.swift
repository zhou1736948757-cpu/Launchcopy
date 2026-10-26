//
//  PageHostView.swift
//  PagingUI
//
//  单个页面承载视图（ADR-002 方案 1：live AppKit view 层级直接承载）。
//  - §E seam 承载侧：实现 PagingPageRendering（render/clearForReuse），
//    PagingSurface.relayoutPages() 内 host.render(...) 为内容承载 seam 单点；
//  - 默认渲染 = NeutralPageRenderer（Phase 1A 中性 tile 网格/调色板迁入，零回归）；
//    也可注入自定义渲染器（PagingSurface.renderer）委托渲染；
//  - render 每次重建全部子视图 —— 绝不显示旧内容（Prompt §3.I）；
//  - clearForReuse 清空内容后进入复用池 + **reuseGeneration bump 作废全部在途异步绑定**
//    （§6.4 防串图）；view 数量上界由 PagingSurface 的 livePageRadius +
//    prewarmDistance 参数化范围控制。
//

import AppKit
import LauncherLocalization

/// 页面承载视图。
public final class PageHostView: NSView, PagingPageRendering {

    // MARK: - §E seam 状态

    /// 复用 generation：每次 clearForReuse 递增；render 携带当前值。
    /// 在途异步绑定（图标加载等）必须以 render 时捕获的 generation 校验：
    /// 到达时 generation 已变 → 作废丢弃（stale apply = 0，§10.5）。
    public private(set) var reuseGeneration: UInt64 = 0

    /// 当前承载的页面索引（未 render 为 -1）。
    public private(set) var pageIndex: Int = -1
    /// render 时的 item 数（布局用）。
    public private(set) var preparedItemsPerPage = 0

    /// 自定义渲染器（PagingSurface.renderer 注入；nil = 中性缺省 NeutralPageRenderer）。
    /// 渲染目标 = 本视图自身（渲染器实现 PagingPageRenderingTargetBinding 可获得绑定）。
    public var customRenderer: PagingPageRendering? {
        didSet {
            if oldValue == nil, customRenderer != nil {
                // Retire only the abandoned neutral content. Clearing the host
                // would bump reuseGeneration and invalidate the incoming bindings.
                neutralRenderer.clearForReuse()
            }
            updateHostAppearance()
        }
    }

    /// 中性缺省渲染器（Phase 1A tile 网格/调色板；惰性创建以绑定 self）。
    private lazy var neutralRenderer = NeutralPageRenderer(targetView: self)
    private var displayedStrings: LocalizedStrings?
    private var textPageCount = 0
    private var textUpdateGeneration: UInt64 = 0
    private var textUpdateScheduled = false
    internal private(set) var languageFormattingCount = 0

    /// Snapshot-only injection is safe even when a pooled host is adopted on a frame.
    public func relabel(strings: LocalizedStrings) {
        displayedStrings = strings
        queuePageText()
    }

    /// Count changes do not require a content rebind or resource lookup on a frame.
    internal func stagePageCount(_ count: Int) {
        guard textPageCount != count else { return }
        textPageCount = count
        queuePageText()
    }

    private func queuePageText() {
        guard !textUpdateScheduled else { return }
        textUpdateScheduled = true
        let generation = textUpdateGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.textUpdateGeneration else { return }
            self.textUpdateScheduled = false
            guard self.pageIndex >= 0 else { return }
            self.languageFormattingCount += 1
            self.setAccessibilityLabel(self.displayedStrings?.page(self.pageIndex + 1, total: self.textPageCount)
                ?? "Page \(self.pageIndex + 1) of \(self.textPageCount)")
        }
    }

    /// A surface drops queued host text before releasing its live or pooled views.
    internal func invalidatePendingLanguageText() {
        textUpdateGeneration &+= 1
        textUpdateScheduled = false
    }

    // MARK: - 初始化

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        updateHostAppearance()
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - PagingPageRendering（seam 单点）

    /// 渲染页面内容：更新承载状态 + 清空旧内容后重建（绝不显示旧内容）。
    /// `reuseGeneration` 参数 = 本次 render 有效 generation（在途异步绑定的作废基线）。
    public func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        self.pageIndex = pageIndex
        self.preparedItemsPerPage = content.items.count
        updateHostAppearance()
        textPageCount = pageCount
        queuePageText()
        if let customRenderer {
            // 自定义渲染器：挂入本视图层级（若是 NSView）→ 绑定承载目标 → 委托渲染。
            if let rendererView = customRenderer as? NSView {
                rendererView.frame = bounds
                if rendererView.superview !== self {
                    addSubview(rendererView)
                }
            }
            (customRenderer as? PagingPageRenderingTargetBinding)?.renderTarget = self
            customRenderer.render(
                pageIndex: pageIndex,
                content: content,
                pageCount: pageCount,
                reuseGeneration: reuseGeneration
            )
        } else {
            neutralRenderer.render(
                pageIndex: pageIndex,
                content: content,
                pageCount: pageCount,
                reuseGeneration: reuseGeneration
            )
        }
        needsLayout = true
    }

    /// 进入复用池前的清理：清空内容 + generation bump（作废全部在途异步绑定）。
    public func clearForReuse() {
        invalidatePendingLanguageText()
        reuseGeneration &+= 1
        pageIndex = -1
        preparedItemsPerPage = 0
        setAccessibilityLabel("")
        neutralRenderer.clearForReuse()
        if let rendererView = customRenderer as? NSView {
            rendererView.removeFromSuperview()
        }
        customRenderer?.clearForReuse()
    }

    /// 在途异步绑定作废守卫：异步回调携带的 generation 与当前不一致 → 丢弃（stale apply = 0）。
    public func isReuseGenerationCurrent(_ generation: UInt64) -> Bool {
        generation == reuseGeneration
    }

    /// Product renderers present content over the window backdrop. The nil renderer is the
    /// neutral laboratory path and retains the original control-background chrome.
    private func updateHostAppearance() {
        layer?.backgroundColor = customRenderer == nil ? NSColor.controlBackgroundColor.cgColor : nil
    }

    // MARK: - Phase 1A 兼容入口（§E 约束④：NeutralContentProvider 路径继续可运行）

    /// Phase 1A `prepare(pageIndex:itemsPerPage:pageCount:)` 兼容包装：按中性占位内容渲染。
    @available(*, deprecated, message: "改用 render(pageIndex:content:pageCount:reuseGeneration:)（§E seam）")
    public func prepare(pageIndex: Int, itemsPerPage: Int, pageCount: Int) {
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: 0, pageIndex: pageIndex),
            items: (0..<itemsPerPage).map { PagingPageContentItem(slot: $0, identity: nil, title: nil) },
            isPlaceholder: true
        )
        render(
            pageIndex: pageIndex,
            content: content,
            pageCount: pageCount,
            reuseGeneration: reuseGeneration
        )
    }

    // MARK: - 布局（默认渲染器委托；自定义渲染器视图自管布局）

    public override func layout() {
        super.layout()
        if let customRenderer {
            if let rendererView = customRenderer as? NSView {
                rendererView.frame = bounds
            }
            // 自定义渲染器的内部布局由 AppKit 驱动（其自身 layout()）。
        } else {
            neutralRenderer.layoutItems(in: self)
        }
    }

    // MARK: - 测试/观察入口

    /// 当前渲染的 tile 数量（默认中性路径；自定义渲染器路径为 0 —— 其内容由自身管理）。
    internal var visibleItemCount: Int {
        customRenderer == nil ? neutralRenderer.itemCount : 0
    }
}
