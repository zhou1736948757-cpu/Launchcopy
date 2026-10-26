import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization

/// Presentation-only desktop geometry. Cards never change the application's page model.
struct LibraryGalleryGeometry {
    let columns: Int
    let cardSide: CGFloat
    let frames: [NSRect]
    let documentSize: NSSize

    init(width: CGFloat, height: CGFloat, count: Int) {
        let available = max(0, width - 32)
        columns = max(1, min(max(1, count), 4, Int((available + 28) / 248)))
        cardSide = max(0, min(248, (available - CGFloat(columns - 1) * 28) / CGFloat(columns)))
        let columns = self.columns
        let cardSide = self.cardSide
        let total = CGFloat(columns) * cardSide + CGFloat(columns - 1) * 28
        let x = max(0, (width - total) / 2)
        frames = (0..<max(0, count)).map { index in
            NSRect(x: x + CGFloat(index % columns) * (cardSide + 28),
                   y: 16 + CGFloat(index / columns) * (cardSide + 52),
                   width: cardSide, height: cardSide + 32)
        }
        documentSize = NSSize(width: max(0, width), height: max(height, (frames.last?.maxY ?? 0) + 20))
    }
}

/// One small set of category cards; icon work is limited to the visible viewport.
/// Uses the owner's filtered immutable snapshot, never a scanner or a second store.
@MainActor
final class AppLibraryGalleryView: NSView {
    var entryProfile: LibraryEntryProfile?
    var onOpen: ((AppID) -> Void)?
    var onDetails: ((AppID) -> Void)?
    private let scroll = NSScrollView(frame: .zero)
    private let document = GalleryDocumentView(frame: .zero)
    private(set) var cards: [LibraryCategoryCard] = []
    private var observation: NSObjectProtocol?
    private var workspaceObservation: NSObjectProtocol?
    private var generation: UInt64 = 0
    private var bindingRevision: UInt64 = 0
    private struct PreparedCards {
        let entries: [AppLibraryEntry]
        let language: InterfaceLanguage
        let cards: [LibraryCategoryCard]
    }
    private var preparedCards: PreparedCards?
    private var preparationGeneration: UInt64 = 0
    private var pipeline: IconPipeline?
    private var blocked = false
    var applicationLaunchEnabled = true {
        didSet { for card in cards { card.setApplicationLaunchEnabled(applicationLaunchEnabled) } }
    }
    var hasPreparedCards: Bool { preparedCards != nil }
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = .init("library.gallery")
        setAccessibilityIdentifier("library.gallery")
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = document
        addSubview(scroll)
        scroll.contentView.postsBoundsChangedNotifications = true
        observation = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: scroll.contentView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.synchronizeIcons() }
            }
        workspaceObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.synchronizeIcons() }
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit {
        if let observation { NotificationCenter.default.removeObserver(observation) }
        if let workspaceObservation { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObservation) }
    }

    /// Invalidates both a completed pool and any locally held work suspended at a yield.
    /// The owner calls this explicitly for reset, source invalidation and teardown.
    func discardPreparation() {
        preparationGeneration &+= 1
        if let preparedCards { for card in preparedCards.cards { card.cancelIcons() } }
        preparedCards = nil
    }

    /// Only fresh, never-presented cards may enter this pool. No session, callbacks,
    /// icon pipeline or document attachment is acquired until a matching normal apply.
    func prepareCards(entries: [AppLibraryEntry], strings: LocalizedStrings,
                      shouldContinue: @MainActor () -> Bool) async -> Bool {
        discardPreparation()
        let token = preparationGeneration
        guard !entries.isEmpty, preparationAllowed(token: token, shouldContinue: shouldContinue) else { return false }
        let groups = Dictionary(grouping: entries, by: \.category)
        // This pool is detached: ordinary gallery layout cannot see its cards.
        // Warm native geometry now, rather than on the first tracking frame.
        scroll.frame = bounds
        let geometry = LibraryGalleryGeometry(width: scroll.contentSize.width,
            height: scroll.contentSize.height, count: groups.count)
        var localCards: [LibraryCategoryCard] = []
        // A stale task cleans up only its local objects, never a newer published pool.
        defer { for card in localCards { card.cancelIcons() } }
        for category in AppLibraryCategory.allCases {
            guard let members = groups[category], !members.isEmpty else { continue }
            guard preparationAllowed(token: token, shouldContinue: shouldContinue) else { return false }
            await Task.yield()
            guard preparationAllowed(token: token, shouldContinue: shouldContinue) else { return false }
            let card = makeCard(category: category, entries: members, strings: strings)
            card.setBlocked(true)
            card.setAccessibilityHidden(true)
            card.applyMaterial(visible: false)
            card.frame = geometry.frames[localCards.count]
            card.layoutSubtreeIfNeeded()
            localCards.append(card)
        }
        guard preparationAllowed(token: token, shouldContinue: shouldContinue) else { return false }
        preparedCards = PreparedCards(entries: entries, language: strings.language, cards: localCards)
        entryProfile?.mark(.preparedCardsReady, count: localCards.count)
        localCards.removeAll()
        return true
    }

    /// Optional CPU-side pre-display only. No pool is attached, activated or
    /// consumed here; normal live projection still supplies all action bindings.
    func prepareDisplay(using warmer: LibraryIdleDisplayWarmup, pipeline: IconPipeline?,
                        displayScale: Double, appearance: NSAppearance? = nil,
                        shouldContinue: @escaping @MainActor () -> Bool) async -> Bool {
        let token = preparationGeneration
        guard let pool = preparedCards, preparationAllowed(token: token, shouldContinue: shouldContinue) else { return false }
        scroll.frame = bounds
        let viewport = NSRect(origin: .zero, size: scroll.contentSize)
        let geometry = LibraryGalleryGeometry(width: viewport.width, height: viewport.height, count: pool.cards.count)
        var items: [LibraryIdleDisplayWarmup.Item] = []
        for (card, frame) in zip(pool.cards, geometry.frames).filter({ $0.1.intersects(viewport) }).prefix(8) {
            await Task.yield()
            guard preparationAllowed(token: token, shouldContinue: shouldContinue) else { return false }
            card.appearance = appearance // Pool cards have no parent from which to inherit.
            card.frame = frame
            card.layoutSubtreeIfNeeded()
            items += card.idleDisplayItems(displayScale: displayScale)
        }
        let completed = await warmer.prepare(items: items, pipeline: pipeline, displayScale: displayScale,
            profile: entryProfile) { [weak self] in
                guard let self else { return false }
                return self.preparationAllowed(token: token, shouldContinue: shouldContinue)
            }
        return completed && preparationAllowed(token: token, shouldContinue: shouldContinue)
    }

    private func preparationAllowed(token: UInt64, shouldContinue: @MainActor () -> Bool) -> Bool {
        guard token == preparationGeneration, !Task.isCancelled, window == nil, cards.isEmpty else { return false }
        guard shouldContinue() else { return false }
        // The admission callback may synchronously invalidate or attach the gallery.
        return token == preparationGeneration && !Task.isCancelled && window == nil && cards.isEmpty
    }

    private func makeCard(category: AppLibraryCategory, entries: [AppLibraryEntry],
                          strings: LocalizedStrings) -> LibraryCategoryCard {
        LibraryCategoryCard(category: category, entries: entries,
            title: AppLibraryCategoryLabels.title(for: category, strings: strings),
            detailsTitle: strings.libraryText(.details))
    }

    func apply(entries: [AppLibraryEntry], strings: LocalizedStrings, generation: UInt64, pipeline: IconPipeline?) {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.galleryApply, since: profileStart, count: entries.count) } }
        // Even an empty loading apply invalidates suspended work. A completed,
        // detached pool may survive loading, but is never installed for it.
        preparationGeneration &+= 1
        self.generation = generation
        bindingRevision &+= 1
        let revision = bindingRevision
        self.pipeline = pipeline
        for card in cards {
            card.retire()
            card.removeFromSuperview()
        }
        if !entries.isEmpty, let preparedCards,
           preparedCards.entries == entries, preparedCards.language == strings.language {
            cards = preparedCards.cards
            entryProfile?.mark(.preparedCardsConsumed, count: cards.count)
            self.preparedCards = nil // Transfer ownership once; presented cards never return to the pool.
        } else {
            if !entries.isEmpty { discardPreparation() }
            let groups = Dictionary(grouping: entries, by: \.category)
            cards = AppLibraryCategory.allCases.compactMap { category in
                guard let members = groups[category], !members.isEmpty else { return nil }
                return makeCard(category: category, entries: members, strings: strings)
            }
        }
        for card in cards {
            card.appearance = nil // Live controls inherit the current host, including later changes.
            card.onOpen = { [weak self] id in
                guard let self, self.bindingRevision == revision, !self.blocked,
                      self.applicationLaunchEnabled, !self.isHiddenOrHasHiddenAncestor else { return }
                self.onOpen?(id)
            }
            card.onDetails = { [weak self] id in
                guard let self, self.bindingRevision == revision, !self.blocked, !self.isHiddenOrHasHiddenAncestor else { return }
                self.onDetails?(id)
            }
            card.entryProfile = entryProfile
            card.setAccessibilityHidden(false)
            card.setApplicationLaunchEnabled(applicationLaunchEnabled)
            card.setBlocked(blocked)
            document.addSubview(card)
        }
        needsLayout = true
    }

    func setBlocked(_ value: Bool) {
        blocked = value
        for card in cards { card.setBlocked(value) }
    }

    override func layout() {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.galleryLayout, since: profileStart) } }
        super.layout()
        scroll.frame = bounds
        let viewport = scroll.contentSize
        let geometry = LibraryGalleryGeometry(width: viewport.width, height: viewport.height, count: cards.count)
        document.setFrameSize(geometry.documentSize)
        for (card, frame) in zip(cards, geometry.frames) { card.frame = frame }
        synchronizeIcons()
    }

    func cancelIcons() { for card in cards { card.cancelIcons() } }
    override func viewDidHide() { super.viewDidHide(); cancelIcons() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); synchronizeIcons() }

    func synchronizeIcons() {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.galleryIcons, since: profileStart, count: cards.count) } }
        let allowed = window?.isVisible == true && !isHiddenOrHasHiddenAncestor
        for card in cards {
            let visible = allowed && card.frame.intersects(document.visibleRect)
            card.applyMaterial(visible: visible)
            if visible, let pipeline {
                card.requestIcons(pipeline: pipeline, generation: generation,
                    displayScale: Double(window?.backingScaleFactor ?? 1))
            } else { card.cancelIcons() }
        }
    }
}

@MainActor
private final class GalleryDocumentView: NSView { override var isFlipped: Bool { true } }

@MainActor
final class LibraryCategoryCard: NSView {
    var entryProfile: LibraryEntryProfile?
    let category: AppLibraryCategory
    let entries: [AppLibraryEntry]
    var onOpen: ((AppID) -> Void)?
    var onDetails: ((AppID) -> Void)?
    private let material = NSVisualEffectView(frame: .zero)
    private let panel = GalleryDocumentView(frame: .zero)
    private let caption = NSTextField(labelWithString: "")
    private(set) var iconButtons: [LibraryGalleryIconButton] = []
    private struct MaterialPolicy: Equatable {
        let solid: Bool
        let backgroundColor: CGColor
        let borderWidth: CGFloat
        let borderColor: CGColor
    }
    private var appliedMaterialPolicy: MaterialPolicy?
    private var appliedMaterialVisibility: Bool?
    override var isFlipped: Bool { true }

    init(category: AppLibraryCategory, entries: [AppLibraryEntry], title: String, detailsTitle: String) {
        self.category = category
        self.entries = entries
        super.init(frame: .zero)
        identifier = .init("library.card.\(category.rawValue)")
        setAccessibilityIdentifier(identifier?.rawValue)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("\(title), \(entries.count)")
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 32
        panel.layer?.masksToBounds = true
        material.material = .popover
        material.blendingMode = .withinWindow
        material.state = .active
        panel.addSubview(material)
        addSubview(panel)
        caption.stringValue = title
        caption.alignment = .center
        caption.font = .systemFont(ofSize: 15, weight: .medium)
        caption.textColor = .labelColor
        caption.lineBreakMode = .byTruncatingTail
        caption.setAccessibilityElement(false)
        addSubview(caption)
        for (index, entry) in entries.prefix(7).enumerated() {
            let button = LibraryGalleryIconButton(entry: entry, detailsTitle: detailsTitle)
            button.isMiniature = entries.count > 4 && index >= 3
            button.setAccessibilityIdentifier("library.card.\(category.rawValue).app.\(index)")
            button.onActivate = { [weak self] in
                guard let self, !self.blocked, self.applicationLaunchEnabled else { return }
                self.onOpen?(entry.record.id)
            }
            button.onDetails = { [weak self] in
                guard let self, !self.blocked, self.applicationLaunchEnabled else { return }
                self.onDetails?(entry.record.id)
            }
            panel.addSubview(button)
            iconButtons.append(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var blocked = false
    private var applicationLaunchEnabled = true
    func setApplicationLaunchEnabled(_ enabled: Bool) {
        applicationLaunchEnabled = enabled
        setBlocked(blocked)
    }
    func setBlocked(_ blocked: Bool) {
        self.blocked = blocked
        for button in iconButtons { button.isEnabled = !blocked && applicationLaunchEnabled }
    }

    /// A presented card never returns to the preparation pool. Revoke retained
    /// controls as well as their gallery binding before releasing the hierarchy.
    func retire() {
        setBlocked(true)
        setAccessibilityHidden(true)
        onOpen = nil
        onDetails = nil
        cancelIcons()
    }

    /// The material/panel is deliberately excluded: no detached bitmap can
    /// pre-compose a within-window backdrop. Warm only text and app controls.
    func idleDisplayItems(displayScale: Double) -> [LibraryIdleDisplayWarmup.Item] {
        [.init(view: caption, iconKey: nil)] + iconButtons.map { button in
            .init(view: button, iconKey: IconKey(identity: button.entry.record.iconIdentity,
                pointSize: button.isMiniature ? 40 : 88, displayScale: displayScale))
        }
    }

    override func layout() {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.cardLayout, since: profileStart, count: iconButtons.count) } }
        super.layout()
        let side = max(0, bounds.width)
        panel.frame = NSRect(x: 0, y: 0, width: side, height: side)
        material.frame = panel.bounds
        caption.frame = NSRect(x: 0, y: side + 8, width: side, height: 24)
        let inset = side * 0.09
        let gap = side * 0.08
        let iconSide = max(0, (side - inset * 2 - gap) / 2)
        for (index, button) in iconButtons.enumerated() {
            if !button.isMiniature {
                button.frame = NSRect(x: inset + CGFloat(index % 2) * (iconSide + gap),
                    y: inset + CGFloat(index / 2) * (iconSide + gap), width: iconSide, height: iconSide)
            } else {
                let mini = (iconSide - gap * 0.4) / 2
                let slot = index - 3
                button.frame = NSRect(x: inset + iconSide + gap + CGFloat(slot % 2) * (mini + gap * 0.4),
                    y: inset + iconSide + gap + CGFloat(slot / 2) * (mini + gap * 0.4), width: mini, height: mini)
            }
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyMaterial(visible: appliedMaterialVisibility ?? false)
    }

    func applyMaterial(visible: Bool) {
        applyMaterial(visible: visible,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }

    /// Explicit inputs also allow isolated coverage without changing system settings.
    func applyMaterial(visible: Bool, reduceTransparency: Bool, increaseContrast: Bool) {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.materialPolicy, since: profileStart, count: 0) } }
        // Appearance callbacks may arrive before initialization creates the layer.
        guard let panelLayer = panel.layer else { return }
        let solid = reduceTransparency || increaseContrast
        var backgroundColor = NSColor.clear.cgColor
        var borderColor = NSColor.clear.cgColor
        // Resolve dynamic colors in this card's appearance, not the caller's.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            backgroundColor = solid ? NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
            borderColor = NSColor.labelColor.withAlphaComponent(solid ? 0.6 : 0.12).cgColor
        }
        let policy = MaterialPolicy(solid: solid, backgroundColor: backgroundColor,
            borderWidth: increaseContrast ? 2 : 0.5, borderColor: borderColor)
        if appliedMaterialPolicy?.solid != policy.solid { material.isHidden = policy.solid }
        if appliedMaterialPolicy?.backgroundColor != policy.backgroundColor {
            panelLayer.backgroundColor = policy.backgroundColor
        }
        if appliedMaterialPolicy?.borderWidth != policy.borderWidth { panelLayer.borderWidth = policy.borderWidth }
        if appliedMaterialPolicy?.borderColor != policy.borderColor { panelLayer.borderColor = policy.borderColor }
        appliedMaterialPolicy = policy
        if appliedMaterialVisibility != visible {
            material.state = visible ? .active : .inactive
            appliedMaterialVisibility = visible
        }
    }

    func cancelIcons() { for button in iconButtons { button.cancelIcon() } }
    func requestIcons(pipeline: IconPipeline, generation: UInt64, displayScale: Double) {
        for button in iconButtons {
            button.entryProfile = entryProfile
            button.requestIcon(pipeline: pipeline, generation: generation, displayScale: displayScale)
        }
    }
}

@MainActor
final class LibraryGalleryIconButton: NSButton {
    var entryProfile: LibraryEntryProfile?
    let entry: AppLibraryEntry
    var isMiniature = false
    var onActivate: (() -> Void)?
    var onDetails: (() -> Void)?
    private var handle: IconRequestHandle?
    private var key: IconKey?
    private var generation: UInt64 = 0
    private var requestSerial: UInt64 = 0
    private let detailsTitle: String

    init(entry: AppLibraryEntry, detailsTitle: String) {
        self.entry = entry
        self.detailsTitle = detailsTitle
        super.init(frame: .zero)
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyUpOrDown
        title = ""
        refusesFirstResponder = false
        image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(entry.displayName)
        setAccessibilityIdentifier("library.app")
        toolTip = entry.displayName
        target = self
        action = #selector(activate(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { handle?.cancel() }
    @objc private func activate(_ sender: Any?) { guard isEnabled else { return }; onActivate?() }
    @objc private func showDetails(_ sender: Any?) { guard isEnabled else { return }; onDetails?() }
    override func menu(for event: NSEvent) -> NSMenu? {
        guard isEnabled else { return nil }
        let menu = NSMenu()
        let item = menu.addItem(withTitle: detailsTitle, action: #selector(showDetails(_:)), keyEquivalent: "")
        item.target = self
        return menu
    }

    func cancelIcon() {
        guard key != nil || handle != nil else { return }
        requestSerial &+= 1
        handle?.cancel()
        handle = nil
        key = nil
        image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
    }

    func requestIcon(pipeline: IconPipeline, generation: UInt64, displayScale: Double) {
        let requested = IconKey(identity: entry.record.iconIdentity, pointSize: isMiniature ? 40 : 88,
                                displayScale: displayScale)
        guard key != requested || self.generation != generation else { return }
        cancelIcon()
        key = requested
        self.generation = generation
        let serial = requestSerial
        handle = pipeline.request(key: requested, generation: generation) { [weak self] delivered, generation, result in
            guard let self, self.requestSerial == serial, self.key == delivered,
                  self.generation == generation, !self.isHiddenOrHasHiddenAncestor,
                  self.window?.isVisible == true else { return }
            let profile = self.entryProfile
            let start = profile?.begin()
            defer { if let start { profile?.end(.iconDelivery, since: start) } }
            if case .success(let image) = result { self.image = image }
            else { self.key = nil; self.handle = nil }
        }
    }
}
