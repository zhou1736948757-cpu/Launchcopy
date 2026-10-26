import AppKit
import LauncherLocalization

/// A passive catalog status overlay. The owner supplies the served semantic state
/// and an immutable displayed-language snapshot; this view never loads resources.
public final class AppGridStatusView: NSView {
    public static let compactPresentationHeight: CGFloat = 20
    public private(set) var isCompactPresentation = false
    /// The latest semantic state, updated synchronously without presentation work.
    public private(set) var state: AppGridUIState = .loading

    /// The last committed presentation, which may lag state until the next main turn.
    public var statusText: String { label.stringValue }
    public var onPresentationApplied: (() -> Void)?

    private let label = NSTextField(wrappingLabelWithString: "")
    private let spinner = NSProgressIndicator()
    private let warningIcon = NSImageView()
    private var displayedStrings: LocalizedStrings?
    private var renderedState: AppGridUIState?
    private var lifecycleGeneration: UInt64 = 0
    private var presentationScheduled = false
    private var isTornDown = false

    /// Counts actual static-string renders, including English fallback renders.
    /// The same rendered value serves the visible label and accessibility label.
    internal private(set) var languageFormattingCount = 0

    /// Keeps existing native callers source-compatible with an IO-free fallback.
    public override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, strings: nil)
    }

    /// Pass an already-resolved snapshot, or nil for the key-specific English fallback.
    /// Construction schedules presentation rather than formatting on the caller's stack.
    public init(frame frameRect: NSRect, strings: LocalizedStrings?) {
        displayedStrings = strings
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 15)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.isSelectable = false
        label.setAccessibilityElement(false)
        addSubview(label)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        spinner.appearance = NSAppearance(named: .darkAqua)
        spinner.style = .spinning
        spinner.isDisplayedWhenStopped = false
        spinner.controlSize = .regular
        spinner.isHidden = true
        spinner.setAccessibilityElement(false)
        addSubview(spinner)
        warningIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        warningIcon.contentTintColor = .systemYellow
        warningIcon.imageScaling = .scaleProportionallyDown
        warningIcon.isHidden = true
        warningIcon.setAccessibilityElement(false)
        addSubview(warningIcon)

        isHidden = true
        setAccessibilityRole(.staticText)
        setAccessibilityElement(false)
        queuePresentation()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Only stage data here: production callbacks may originate in a frame stack.
    public func update(state: AppGridUIState) {
        guard !isTornDown, state != self.state else { return }
        self.state = state
        queuePresentation()
    }

    /// Layout selects a style, but static text/typography still render on the deferred turn.
    public func setCompactPresentation(_ compact: Bool) {
        guard !isTornDown, compact != isCompactPresentation else { return }
        isCompactPresentation = compact
        queuePresentation()
    }

    /// Matches the launcher's photo-backed chrome without changing semantic state or text.
    public func applyMaterialPolicy(reduceTransparency: Bool, increaseContrast: Bool) {
        guard !isTornDown else { return }
        layer?.backgroundColor = NSColor.black.withAlphaComponent(reduceTransparency ? 1 : 0.7).cgColor
        layer?.borderWidth = increaseContrast ? 1 : 0
        layer?.borderColor = increaseContrast ? NSColor.white.cgColor : nil
    }

    /// Equal semantic state still rerenders against the new displayed snapshot.
    public func relabel(strings: LocalizedStrings) {
        guard !isTornDown else { return }
        displayedStrings = strings
        queuePresentation()
    }

    /// Terminal lifecycle hook. The owner calls this outside frame callbacks before
    /// releasing the overlay; an externally retained view cannot accept later work.
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        lifecycleGeneration &+= 1
        presentationScheduled = false
        displayedStrings = nil
        onPresentationApplied = nil
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        warningIcon.isHidden = true
        toolTip = nil
        isHidden = true
        setAccessibilityElement(false)
    }

    private func queuePresentation() {
        guard !presentationScheduled else { return }
        presentationScheduled = true
        let generation = lifecycleGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isTornDown, generation == self.lifecycleGeneration else { return }
            self.presentationScheduled = false
            self.renderPresentation()
        }
    }

    /// Reads the latest staged pair exactly once, so earlier queued states/languages
    /// cannot overwrite a newer completion. Resource lookup and IO are absent.
    private func renderPresentation() {
        let key = state.catalogTextKey
        languageFormattingCount += 1
        let text = displayedStrings?.catalogText(key) ?? key.englishFallback
        label.stringValue = text
        label.font = .systemFont(ofSize: isCompactPresentation ? 11 : 15)
        label.maximumNumberOfLines = isCompactPresentation ? 1 : 0
        label.lineBreakMode = isCompactPresentation ? .byTruncatingTail : .byWordWrapping
        layer?.cornerRadius = isCompactPresentation ? Self.compactPresentationHeight / 2 : 8
        toolTip = isCompactPresentation ? text : nil
        setAccessibilityLabel(text)
        renderedState = state

        if state.isBusy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
        spinner.isHidden = !state.isBusy
        warningIcon.isHidden = !isCompactPresentation || state != .partialFailure
        isHidden = state == .ready
        setAccessibilityElement(!isHidden)
        needsLayout = true
        onPresentationApplied?()
    }

    /// Uses already-rendered text only. Owners call outside frame stacks to reserve full lines.
    public func requiredPresentationHeight(forWidth width: CGFloat) -> CGFloat {
        if isCompactPresentation { return Self.compactPresentationHeight }
        let textWidth = max(width - 16, 0)
        let measured = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: textWidth,
            height: CGFloat.greatestFiniteMagnitude)).height ?? 20
        let busy = (renderedState ?? state).isBusy
        return ceil(max(measured, 20)) + 16 + (busy ? 30 : 0)
    }

    public override var acceptsFirstResponder: Bool { false }

    public override func becomeFirstResponder() -> Bool { false }

    /// Includes native label/spinner descendants: blank clicks reach the container.
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func layout() {
        super.layout()
        if isCompactPresentation {
            let inset = min(6, max(bounds.width, 0) / 2)
            let content = bounds.insetBy(dx: inset, dy: min(2, max(bounds.height, 0) / 2))
            let hasGlyph = renderedState?.isBusy == true || renderedState == .partialFailure
            let side = hasGlyph ? min(12, max(0, min(content.width, content.height))) : 0
            let glyphFrame = NSRect(x: content.minX, y: content.midY - side / 2, width: side, height: side)
            spinner.frame = glyphFrame
            warningIcon.frame = glyphFrame
            let gap: CGFloat = hasGlyph && content.width > side ? min(4, content.width - side) : 0
            label.frame = NSRect(x: content.minX + side + gap, y: content.minY,
                                 width: max(content.width - side - gap, 0), height: max(content.height, 0))
            label.isHidden = label.frame.width < 16 || label.frame.height < 13
            return
        }
        label.isHidden = false
        let width = max(bounds.width, 0)
        let height = max(bounds.height, 0)
        let horizontalInset = min(8, width / 2)
        let verticalInset = min(8, height / 2)
        let textWidth = max(width - 2 * horizontalInset, 0)
        let contentHeight = max(height - 2 * verticalInset, 0)
        let busy = renderedState?.isBusy == true
        let spinnerSide = busy ? min(20, min(textWidth, contentHeight)) : 0
        let gap = busy ? min(10, max(contentHeight - spinnerSide, 0)) : 0
        let textCapacity = max(contentHeight - spinnerSide - gap, 0)
        let measurementBounds = NSRect(x: 0, y: 0, width: textWidth,
                                       height: CGFloat.greatestFiniteMagnitude)
        let measuredHeight = textWidth > 0
            ? ceil(label.cell?.cellSize(forBounds: measurementBounds).height ?? 0) : 0
        let textHeight = min(max(measuredHeight, 0), textCapacity)
        let totalHeight = textHeight + gap + spinnerSide
        let bottom = bounds.minY + (height - totalHeight) / 2
        label.frame = NSRect(x: bounds.minX + horizontalInset, y: bottom,
                             width: textWidth, height: textHeight)
        spinner.frame = NSRect(x: bounds.minX + (width - spinnerSide) / 2,
                               y: bottom + textHeight + gap,
                               width: spinnerSide, height: spinnerSide)
    }
}
