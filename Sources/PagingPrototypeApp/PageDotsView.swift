import AppKit
import LauncherLocalization

/// Bounded launcher chrome. The owner supplies committed state and arbitrates requests.
@MainActor
public final class PageDotsView: NSView {
    public var onRequestPage: ((Int) -> Void)?

    private struct Presentation: Equatable {
        let pageCount: Int
        let committedPage: Int
        let isEnabled: Bool
    }

    private static let windowSize = 9
    private static let buttonSide: CGFloat = 24
    private static let spacing: CGFloat = 4
    private static let inset: CGFloat = 8
    private static let stripHeight: CGFloat = 32

    private var presentation = Presentation(pageCount: 0, committedPage: 0, isEnabled: false)
    private var windowStart = 0
    private var displayedStrings: LocalizedStrings?
    private var textUpdateGeneration: UInt64 = 0
    private var textUpdateScheduled = false
    private var isTornDown = false
    internal private(set) var languageFormattingCount = 0

    /// Updates only AX/help text; browsed windows, tags, selection and actions survive.
    public func relabel(strings: LocalizedStrings) {
        guard !isTornDown else { return }
        displayedStrings = strings
        queueAccessibilityText()
    }

    /// The owner calls this when the chrome is permanently discarded.
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        textUpdateGeneration &+= 1
        textUpdateScheduled = false
    }

    private func gridText(_ key: GridTextKey) -> String {
        displayedStrings?.gridText(key) ?? key.englishFallback
    }

    private func queueAccessibilityText() {
        guard !isTornDown, !textUpdateScheduled else { return }
        textUpdateScheduled = true
        let generation = textUpdateGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isTornDown, generation == self.textUpdateGeneration else { return }
            self.textUpdateScheduled = false
            self.refreshAccessibilityText()
        }
    }

    private func pageText(_ page: Int) -> String {
        languageFormattingCount += 1
        return displayedStrings?.page(page + 1, total: presentation.pageCount)
            ?? "Page \(page + 1) of \(presentation.pageCount)"
    }

    private func refreshAccessibilityText() {
        setAccessibilityLabel(gridText(.pageNavigation))
        let previous = gridText(.previousPageWindow)
        let next = gridText(.nextPageWindow)
        previousWindowButton.setAccessibilityLabel(previous)
        previousWindowButton.toolTip = previous
        nextWindowButton.setAccessibilityLabel(next)
        nextWindowButton.toolTip = next
        setAccessibilityValue(presentation.pageCount > 0
            ? pageText(presentation.committedPage) : gridText(.noPages))
        for button in pageButtons {
            guard !button.isHidden else {
                button.toolTip = nil
                button.setAccessibilityLabel(nil)
                button.setAccessibilityValue(nil)
                continue
            }
            let selected = button.tag == presentation.committedPage
            let label = pageText(button.tag) + (selected ? gridText(.currentPageSuffix) : "")
            button.toolTip = label
            button.setAccessibilityLabel(label)
            button.setAccessibilityValue(gridText(selected ? .currentPage : .unselectedPage))
        }
    }
    private var materialPolicy = LaunchcopyMaterialPolicy(
        reduceTransparency: false, increaseContrast: false, reduceMotion: false
    )
    private var pageButtons: [NSButton] = []
    private let previousWindowButton = PageDotButton(frame: .zero)
    private let nextWindowButton = PageDotButton(frame: .zero)
    private let dotImage = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 7, weight: .regular))

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = NSUserInterfaceItemIdentifier("launchcopy.chrome.page-dots")
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(GridTextKey.pageNavigation.englishFallback)
        wantsLayer = true
        layer?.cornerRadius = LaunchcopyVisualTokens.chromeCornerRadius
        isHidden = true

        for _ in 0..<Self.windowSize {
            let button = PageDotButton(frame: .zero)
            configure(button)
            // Native target/action toggles first; the action restores committed selection.
            button.setButtonType(.pushOnPushOff)
            button.image = dotImage
            button.action = #selector(requestPage(_:))
            pageButtons.append(button)
            addSubview(button)
        }
        configureWindowButton(previousWindowButton, symbol: "chevron.left",
                              identifier: "launchcopy.chrome.page-window.previous",
                              label: GridTextKey.previousPageWindow.englishFallback, action: #selector(showPreviousWindow(_:)))
        configureWindowButton(nextWindowButton, symbol: "chevron.right",
                              identifier: "launchcopy.chrome.page-window.next",
                              label: GridTextKey.nextPageWindow.englishFallback, action: #selector(showNextWindow(_:)))
        refreshControls()
        refreshMaterial()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Call for discrete presentation changes, never with an animated page offset.
    public func update(pageCount: Int, committedPage: Int, isEnabled: Bool) {
        let count = max(0, pageCount)
        let committed = count == 0 ? 0 : min(max(0, committedPage), count - 1)
        let next = Presentation(pageCount: count, committedPage: committed, isEnabled: isEnabled)
        guard next != presentation else { return }
        let pagesChanged = count != presentation.pageCount || committed != presentation.committedPage
        presentation = next
        windowStart = min(windowStart, maximumWindowStart)
        // Preserve a manually browsed window on equal updates and enablement changes.
        if pagesChanged && (committed < windowStart || committed - windowStart >= visiblePageCount) {
            windowStart = min(max(0, committed - Self.windowSize / 2), maximumWindowStart)
        }
        isHidden = count <= 1
        refreshControls()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    public func applyMaterialPolicy(reduceTransparency: Bool, increaseContrast: Bool) {
        guard reduceTransparency != materialPolicy.reduceTransparency
                || increaseContrast != materialPolicy.increaseContrast else { return }
        materialPolicy = LaunchcopyMaterialPolicy(
            reduceTransparency: reduceTransparency, increaseContrast: increaseContrast, reduceMotion: false
        )
        refreshMaterial()
        refreshSelection()
    }

    public override var intrinsicContentSize: NSSize {
        guard presentation.pageCount > 1 else { return .zero }
        let controlCount = visiblePageCount + (hasWindowControls ? 2 : 0)
        return NSSize(width: Self.inset * 2 + CGFloat(controlCount) * Self.buttonSide
                      + CGFloat(controlCount - 1) * Self.spacing, height: Self.stripHeight)
    }

    public override func layout() {
        super.layout()
        guard !isHidden else { return }
        var controls: [NSButton] = []
        if hasWindowControls { controls.append(previousWindowButton) }
        controls.append(contentsOf: pageButtons.prefix(visiblePageCount))
        if hasWindowControls { controls.append(nextWindowButton) }
        let scale = min(1, max(0, bounds.width) / intrinsicContentSize.width)
        let side = min(Self.buttonSide * scale, max(0, bounds.height))
        let gap = Self.spacing * scale
        let width = CGFloat(controls.count) * side + CGFloat(controls.count - 1) * gap
        var x = bounds.midX - width / 2
        for button in controls {
            button.frame = NSRect(x: x, y: bounds.midY - side / 2, width: side, height: side)
            x += side + gap
        }
    }

    private var visiblePageCount: Int { min(Self.windowSize, presentation.pageCount) }
    private var maximumWindowStart: Int { max(0, presentation.pageCount - Self.windowSize) }
    private var hasWindowControls: Bool { presentation.pageCount > Self.windowSize }

    private func configure(_ button: NSButton) {
        button.title = ""
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.focusRingType = .none
        // Pointer chrome must not steal the search field's first responder.
        button.refusesFirstResponder = true
        button.target = self
        button.isEnabled = false
        button.isHidden = true
    }

    private func configureWindowButton(_ button: NSButton, symbol: String, identifier: String,
                                       label: String, action: Selector) {
        configure(button)
        button.setButtonType(.momentaryPushIn)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.contentTintColor = .white
        button.action = action
        addSubview(button)
    }

    private func refreshControls() {
        for (slot, button) in pageButtons.enumerated() {
            let visible = presentation.pageCount > 1 && slot < visiblePageCount
            button.isHidden = !visible
            button.isEnabled = visible && presentation.isEnabled
            button.setAccessibilityElement(visible)
            button.tag = visible ? windowStart + slot : -1
            button.identifier = visible
                ? NSUserInterfaceItemIdentifier("launchcopy.chrome.page-dot.\(button.tag)") : nil
        }
        previousWindowButton.isHidden = !hasWindowControls
        nextWindowButton.isHidden = !hasWindowControls
        previousWindowButton.isEnabled = presentation.isEnabled && windowStart > 0
        nextWindowButton.isEnabled = presentation.isEnabled && windowStart < maximumWindowStart
        previousWindowButton.setAccessibilityElement(hasWindowControls)
        nextWindowButton.setAccessibilityElement(hasWindowControls)
        queueAccessibilityText()
        refreshSelection()
    }

    private func refreshSelection() {
        for button in pageButtons {
            let selected = !button.isHidden && button.tag == presentation.committedPage
            button.state = selected ? .on : .off
            button.contentTintColor = selected ? .white
                : NSColor.white.withAlphaComponent(materialPolicy.increaseContrast ? 0.8 : 0.5)
        }
        queueAccessibilityText()
    }

    private func refreshMaterial() {
        layer?.backgroundColor = LaunchcopyVisualTokens.chromeFill(policy: materialPolicy).cgColor
        layer?.isOpaque = materialPolicy.prefersOpaqueChrome
        layer?.borderWidth = materialPolicy.emphasizesBorders ? 2 : 0
        layer?.borderColor = (materialPolicy.emphasizesBorders ? NSColor.white : NSColor.clear).cgColor
    }

    @objc private func requestPage(_ sender: NSButton) {
        guard presentation.isEnabled, presentation.pageCount > 1, !isHidden,
              !sender.isHidden, sender.isEnabled, pageButtons.contains(where: { $0 === sender }) else { return }
        // Clamp again at dispatch, against the latest discrete count, including stale targets.
        let target = min(max(0, sender.tag), presentation.pageCount - 1)
        refreshControls()
        // Do not filter the selected page: Core may need to return to it during a settle.
        onRequestPage?(target)
    }

    @objc private func showPreviousWindow(_ sender: NSButton) {
        guard presentation.isEnabled, !isHidden, sender === previousWindowButton,
              sender.isEnabled, hasWindowControls else { return }
        windowStart = max(0, windowStart - Self.windowSize)
        refreshControls()
    }

    @objc private func showNextWindow(_ sender: NSButton) {
        guard presentation.isEnabled, !isHidden, sender === nextWindowButton,
              sender.isEnabled, hasWindowControls else { return }
        // Difference-first arithmetic stays bounded even for Int.max pages.
        windowStart += min(Self.windowSize, maximumWindowStart - windowStart)
        refreshControls()
    }
}

/// AXPress reports handling, not a transient toggle value: committed selection may
/// remain unchanged until the requested asynchronous navigation finishes.
private final class PageDotButton: NSButton {
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, !isHiddenOrHasHiddenAncestor else { return false }
        performClick(nil)
        return true
    }
}
