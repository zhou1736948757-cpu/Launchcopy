import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization

/// Lazy native Library presentation. The owner supplies already-filtered snapshots
/// and validates all immutable requests; this view performs no catalog or file I/O.
@MainActor
final class AppLibraryView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var onBack: (() -> Void)?
    var onQueryChange: ((String) -> Void)?
    var onCategoryChange: ((AppLibraryCategory?) -> Void)?
    var onActivitySectionChange: ((LaunchActivitySection?) -> Void)?
    var onOpen: ((AppLibraryActionRequest) -> Void)?
    var onReveal: ((AppLibraryActionRequest) -> Void)?
    var onEditAlias: ((AppLibraryActionRequest) -> Void)?
    var onSetHidden: ((AppLibraryActionRequest, Bool) -> Void)?
    var onSetCategory: ((AppLibraryActionRequest, AppLibraryCategory?) -> Void)?
    var onFolderAssignment: ((AppLibraryActionRequest) -> Void)? {
        didSet { folderButton?.isHidden = onFolderAssignment == nil }
    }
    var onMoveToTrash: ((AppLibraryActionRequest) -> Void)? {
        didSet { removalButton?.isHidden = onMoveToTrash == nil || !allowsApplicationRemoval }
    }
    var onPresentationOwnershipChange: (() -> Void)?

    private(set) var query = ""
    private(set) var selectedCategory: AppLibraryCategory?
    private(set) var selectedActivitySection: LaunchActivitySection?
    private(set) var activitySectionsEnabled = false
    private(set) var detailsOpen = false
    private var strings: LocalizedStrings
    private let iconPipeline: IconPipeline?
    private var snapshot: AppLibrarySnapshot?
    private var actionGeneration: UInt64 = 0
    private var presentationGeneration: UInt64 = 0
    private var selectedID: AppID?
    /// Identity-only refresh continuity; never retains an executable record/token.
    private var pendingSelection: (id: AppID, detailsOpen: Bool)?
    private var categoryDraft: (id: AppID, value: AppLibraryCategory?, dirty: Bool, submitted: Bool)?
    private var acceptedCategoryReceipt = false
    private var categorySaveResult: AppLibrarySaveResult?
    private(set) var categorySaveStatusLabel: NSTextField?
    private var isLoading = false
    private var appActionsBlocked = false
    var allowsExternalApplicationActions = true {
        didSet {
            galleryView.applicationLaunchEnabled = allowsExternalApplicationActions
            setDetailActionsEnabled(selectedEntry != nil && !isLoading)
        }
    }
    var allowsApplicationRemoval = true {
        didSet { setDetailActionsEnabled(selectedEntry != nil && !isLoading) }
    }
    private var catalogIsEmpty = false
    private var updatingSelection = false
    private var observations: [NSObjectProtocol] = []
    private let cells = NSHashTable<LibraryResultCell>.weakObjects()

    // Internal native controls also allow isolated, mounted-control unit tests.
    var entryProfile: LibraryEntryProfile? {
        didSet { galleryView.entryProfile = entryProfile }
    }
    let searchField = LibrarySearchField(frame: .zero)
    let categoriesTable = NSTableView(frame: .zero)
    let resultsTable = LibraryResultsTable(frame: .zero)
    let backButton = NSButton(title: "", target: nil, action: nil)
    let detailsButton = NSButton(title: "", target: nil, action: nil)
    let compactCategoryPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let categoriesScroll = LibraryScrollView(frame: .zero)
    private let resultsScroll = LibraryScrollView(frame: .zero)
    let galleryView = AppLibraryGalleryView(frame: .zero)
    private var browsingAllResults = false
    var showsGallery: Bool { query.isEmpty && selectedCategory == nil && selectedActivitySection == nil && !detailsOpen && !browsingAllResults }
    private var detailScroll: LibraryScrollView?
    private var detailHeading: NSTextField?
    private var detailLabels: [LibraryTextKey: NSTextField] = [:]
    private(set) var detailValues: [LibraryTextKey: NSTextField] = [:]
    private(set) var categoryPicker: NSPopUpButton?
    private(set) var saveCategoryButton: NSButton?
    private(set) var restoreAutomaticButton: NSButton?
    private(set) var openButton: NSButton?
    private(set) var revealButton: NSButton?
    private(set) var aliasButton: NSButton?
    private(set) var hideButton: NSButton?
    private(set) var folderButton: NSButton?
    private(set) var removalButton: NSButton?
    private var closeDetailsButton: NSButton?

    override var isFlipped: Bool { true }

    init(frame: NSRect, strings: LocalizedStrings, iconPipeline: IconPipeline? = nil) {
        self.strings = strings
        self.iconPipeline = iconPipeline
        super.init(frame: frame)
        identifier = NSUserInterfaceItemIdentifier("library")
        setAccessibilityIdentifier("library")
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.recentsAutosaveName = nil
        searchField.maximumRecents = 0
        identify(searchField, "library.search")
        identify(categoriesTable, "library.categories")
        identify(resultsTable, "library.results")
        identify(backButton, "library.back")
        identify(detailsButton, "library.details.toggle")
        identify(compactCategoryPicker, "library.categories.compact")
        backButton.target = self
        backButton.action = #selector(back(_:))
        detailsButton.target = self
        detailsButton.action = #selector(showDetails(_:))
        compactCategoryPicker.target = self
        compactCategoryPicker.action = #selector(compactCategoryChanged(_:))
        for (table, scroll, columnID) in [
            (categoriesTable, categoriesScroll, "category"),
            (resultsTable as NSTableView, resultsScroll, "result")
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnID))
            column.resizingMask = .autoresizingMask
            table.addTableColumn(column)
            table.headerView = nil
            table.rowHeight = table === resultsTable ? 52 : 30
            table.intercellSpacing = NSSize(width: 0, height: 2)
            table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
            table.allowsMultipleSelection = false
            table.allowsEmptySelection = true
            table.usesAlternatingRowBackgroundColors = false
            table.backgroundColor = .clear
            scroll.drawsBackground = false
            scroll.contentView.drawsBackground = false
            table.dataSource = self
            table.delegate = self
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            scroll.autohidesScrollers = true
            scroll.documentView = table
            addSubview(scroll)
        }
        addSubview(galleryView)
        galleryView.onOpen = { [weak self] id in self?.activateGalleryApp(id, details: false) }
        galleryView.onDetails = { [weak self] id in self?.activateGalleryApp(id, details: true) }
        resultsTable.target = self
        resultsTable.action = #selector(showDetails(_:))
        resultsTable.doubleAction = #selector(openSelection(_:))
        resultsTable.onReturn = { [weak self] in self?.openSelection(nil) }
        resultsTable.onEscape = { [weak self] in self?.handleEscape() ?? false }
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        for view in [backButton, searchField, detailsButton, compactCategoryPicker, statusLabel] as [NSView] {
            addSubview(view)
        }
        resultsScroll.contentView.postsBoundsChangedNotifications = true
        observe(NSView.boundsDidChangeNotification, object: resultsScroll.contentView)
        observe(NSWindow.didUpdateNotification, object: nil)
        relabel(strings: strings)
        refreshStatus()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        for observation in observations { NotificationCenter.default.removeObserver(observation) }
    }

    private func observe(_ name: Notification.Name, object: Any?) {
        observations.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) {
            [weak self] notification in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let eventWindow = notification.object as? NSWindow, eventWindow !== self.window { return }
                self.synchronizeVisibleIcons()
            }
        })
    }

    private func identify(_ view: NSView, _ value: String) {
        view.identifier = NSUserInterfaceItemIdentifier(value)
        view.setAccessibilityIdentifier(value)
    }

    /// The logical Library owns this field, but the window hosts it beside the
    /// moving body so native text/field-editor rendering never rides a page layer.
    func mountSearchHeader(in host: NSView, frame: NSRect) {
        setSearchHeaderVisible(false)
        searchField.frame = frame
        host.addSubview(searchField, positioned: .above, relativeTo: self)
    }

    func setSearchHeaderVisible(_ visible: Bool) {
        searchField.isHidden = !visible
        searchField.setAccessibilityHidden(!visible)
    }

    func unmountSearchHeader() {
        setSearchHeaderVisible(false)
        searchField.removeFromSuperview()
        addSubview(searchField)
    }

    /// Respect the current Library responder, including its window-owned field editor.
    var preferredFirstResponder: NSResponder {
        if let responder = window?.firstResponder, owns(responder) { return responder }
        return searchField
    }

    var hasPresentationOwnership: Bool {
        guard let editor = window?.firstResponder as? NSTextView else { return false }
        return owns(editor)
    }

    private func owns(_ responder: NSResponder) -> Bool {
        if let editor = responder as? NSTextView {
            if searchField.currentEditor() === editor { return true }
            if let control = editor.delegate as? NSView,
               control === searchField || control.isDescendant(of: self) { return true }
        }
        return (responder as? NSView).map { $0 === searchField || $0 === self || $0.isDescendant(of: self) } ?? false
    }

    func apply(snapshot: AppLibrarySnapshot?, isLoading: Bool, catalogIsEmpty: Bool,
               actionGeneration: UInt64) {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.viewApply, since: profileStart, count: snapshot?.entries.count ?? 0) } }
        let retainedID = selectedID ?? pendingSelection?.id
        let wasOpen = selectedID != nil ? detailsOpen : pendingSelection?.detailsOpen ?? false
        if snapshot == nil, isLoading, let retainedID {
            pendingSelection = (retainedID, wasOpen)
        } else {
            pendingSelection = nil
        }
        self.snapshot = snapshot
        self.isLoading = isLoading
        self.catalogIsEmpty = catalogIsEmpty
        self.actionGeneration = actionGeneration
        presentationGeneration &+= 1
        cancelIcons()
        updatingSelection = true
        categoriesTable.reloadData()
        selectCategoryControl()
        resultsTable.reloadData()
        if let retainedID, let index = snapshot?.entries.firstIndex(where: { $0.record.id == retainedID }) {
            selectedID = retainedID
            resultsTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            detailsOpen = wasOpen
            if wasOpen { renderDetails() }
        } else {
            selectedID = nil
            resultsTable.deselectAll(nil)
            closeDetails()
            clearDetailValues()
            if !isLoading { categoryDraft = nil; acceptedCategoryReceipt = false }
        }
        updatingSelection = false
        rebuildGallery()
        refreshStatus()
        needsLayout = true
        synchronizeVisibleIcons()
    }

    func reset() {
        galleryView.discardPreparation()
        categoryDraft = nil
        acceptedCategoryReceipt = false
        categorySaveResult = nil
        if hasPresentationOwnership { window?.endEditing(for: nil) }
        presentationGeneration &+= 1
        cancelIcons()
        snapshot = nil
        galleryView.apply(entries: [], strings: strings, generation: presentationGeneration, pipeline: iconPipeline)
        actionGeneration = 0
        selectedID = nil
        pendingSelection = nil
        query = ""
        browsingAllResults = false
        selectedCategory = nil
        selectedActivitySection = nil
        searchField.stringValue = ""
        isLoading = false
        catalogIsEmpty = false
        updatingSelection = true
        resultsTable.reloadData()
        resultsTable.deselectAll(nil)
        categoriesTable.reloadData()
        selectCategoryControl()
        closeDetails()
        clearDetailValues()
        updatingSelection = false
        // These belong to the old session, not the retained native shell.
        setAppActionsBlocked(false)
        renderCategorySaveStatus()
        refreshStatus()
        needsLayout = true
        onPresentationOwnershipChange?()
    }

    func focusSearch() {
        let profile = entryProfile
        let start = profile?.begin()
        defer { if let start { profile?.end(.viewFocus, since: start) } }
        window?.makeFirstResponder(searchField)
    }

    @discardableResult
    func handleEscape() -> Bool {
        if let editor = window?.firstResponder as? NSTextView, owns(editor), editor.hasMarkedText() {
            // Consume this Escape at the composition layer; never navigate during IME composition.
            editor.inputContext?.discardMarkedText()
            return true
        }
        if detailsOpen { closeDetails(discardDraft: true); return true }
        if !query.isEmpty {
            searchField.stringValue = ""
            searchField.currentEditor()?.string = ""
            changeQuery("")
            focusSearch()
            return true
        }
        if selectedCategory != nil || selectedActivitySection != nil || browsingAllResults {
            returnToGallery()
            return true
        }
        guard let onBack else { return false }
        onBack()
        return true
    }

    override func cancelOperation(_ sender: Any?) { _ = handleEscape() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHiddenOrHasHiddenAncestor, bounds.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point) ?? self
    }

    // Deliberately terminate scroll bubbling within the Library, including at list edges.
    override func scrollWheel(with event: NSEvent) {}

    override var isHidden: Bool {
        didSet {
            if isHidden { cancelIcons() }
            else { needsLayout = true }
        }
    }

    override func viewDidHide() {
        super.viewDidHide()
        cancelIcons()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        needsLayout = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { cancelIcons() }
        else { needsLayout = true }
    }

    override func layout() {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.viewLayout, since: profileStart) } }
        // Hiding a focused control can synchronously resign it to the window.
        // Capture ownership before changing category or results visibility.
        let categoryTableWasFocused = window?.firstResponder === categoriesTable
        let categoryPickerWasFocused = window?.firstResponder === compactCategoryPicker
        let resultsTableWasFocused = window?.firstResponder === resultsTable
        super.layout()
        let horizontal = LibraryHorizontalLayout(boundsWidth: bounds.width, showsGallery: showsGallery)
        let margin = LibraryHorizontalLayout.margin
        let width = horizontal.availableWidth
        let compact = horizontal.isCompact
        if searchField.superview === self {
            searchField.frame = LauncherSearchHeader.frame(in: bounds, flipped: true)
        }
        let headerFrame = convert(searchField.bounds, from: searchField)
        let backWidth = min(CGFloat(84), width / 3)
        let detailWidth = min(CGFloat(120), width / 3)
        let detailX = margin + width - detailWidth
        let controlsNeedRow = !showsGallery && (compact || headerFrame.minX < margin + backWidth + 12
            || headerFrame.maxX > detailX - 12)
        let controlsY = controlsNeedRow ? headerFrame.maxY + 8 : headerFrame.minY
        let headerHeight: CGFloat = controlsNeedRow ? 104 : 64
        backButton.frame = NSRect(x: margin, y: controlsY, width: backWidth, height: 28)
        detailsButton.frame = NSRect(x: detailX, y: controlsY, width: detailWidth, height: 28)
        detailsButton.isHidden = showsGallery
        refreshBackButtonVisibility()
        let categoryHeight: CGFloat = (showsGallery ? activitySectionsEnabled : compact) ? 34 : 0
        compactCategoryPicker.isHidden = showsGallery ? !activitySectionsEnabled : !compact
        compactCategoryPicker.frame = NSRect(x: margin, y: margin + headerHeight, width: width, height: 28)
        let top = margin + headerHeight + categoryHeight
        let height = max(0, bounds.height - top - margin)
        let sidebarWidth = horizontal.sidebarWidth
        categoriesScroll.isHidden = compact || showsGallery
        categoriesScroll.frame = NSRect(x: margin, y: top, width: sidebarWidth, height: height)
        // Move only the displaced category focus to its visible equivalent;
        // search composition and result focus are not owned by this transition.
        if showsGallery, categoryTableWasFocused || categoryPickerWasFocused {
            window?.makeFirstResponder(searchField)
        } else if compact, categoryTableWasFocused {
            window?.makeFirstResponder(compactCategoryPicker)
        } else if !compact, categoryPickerWasFocused {
            window?.makeFirstResponder(categoriesTable)
        }
        let contentX = horizontal.contentX
        let contentWidth = horizontal.contentWidth
        let sideBySide = horizontal.showsResultsBesideDetails(detailsOpen: detailsOpen)
        let detailWidthActual = sideBySide ? min(340, contentWidth * 0.48) : contentWidth
        galleryView.isHidden = !showsGallery
        galleryView.frame = NSRect(x: margin, y: top, width: width, height: height)
        resultsScroll.isHidden = showsGallery || (detailsOpen && !sideBySide)
        resultsScroll.frame = NSRect(x: contentX, y: top,
                                    width: sideBySide ? contentWidth - detailWidthActual - 12 : contentWidth,
                                    height: height)
        detailScroll?.isHidden = !detailsOpen
        detailScroll?.frame = NSRect(x: sideBySide ? resultsScroll.frame.maxX + 12 : contentX,
                                    y: top, width: detailWidthActual, height: height)
        if showsGallery, resultsTableWasFocused {
            window?.makeFirstResponder(searchField)
        } else if resultsScroll.isHidden, resultsTableWasFocused {
            window?.makeFirstResponder(closeDetailsButton)
        }
        statusLabel.frame = NSRect(x: contentX + 8, y: top + 12, width: max(0, contentWidth - 16), height: 64)
        statusLabel.isHidden = detailsOpen || (snapshot?.entries.isEmpty == false && !isLoading)
        synchronizeVisibleIcons()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === categoriesTable ? AppLibraryCategory.allCases.count + 1 + activityRowCount : snapshot?.entries.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === categoriesTable {
            let reuse = NSUserInterfaceItemIdentifier("library.category.cell")
            let cell = (tableView.makeView(withIdentifier: reuse, owner: self) as? AppLibraryCategoryCell)
                ?? AppLibraryCategoryCell(frame: .zero)
            cell.identifier = reuse
            if let section = activitySection(at: row) {
                let title = strings.launchActivityText(section == .recent ? .recent : .frequent)
                let label = NSTextField(labelWithString: title)
                label.lineBreakMode = .byTruncatingTail
                label.setAccessibilityLabel(title)
                return label
            }
            let category = category(at: row)
            let count = category.map { snapshot?.counts[$0] ?? 0 } ?? snapshot?.counts.values.reduce(0, +) ?? 0
            let title = AppLibraryCategoryLabels.title(for: category, strings: strings)
            cell.bind(title: title, count: count)
            return cell
        }
        guard let entry = snapshot?.entries[safe: row] else { return nil }
        let reuse = NSUserInterfaceItemIdentifier("library.result.cell")
        let cell = (tableView.makeView(withIdentifier: reuse, owner: self) as? LibraryResultCell) ?? LibraryResultCell(frame: .zero)
        cell.identifier = reuse
        cells.add(cell)
        cell.bind(entry: entry, subtitle: AppLibraryCategoryLabels.title(for: entry.category, strings: strings))
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !updatingSelection, let table = notification.object as? NSTableView else { return }
        if table === categoriesTable {
            let row = table.selectedRow
            guard row >= 0 else { return }
            selectNavigationRow(row)
        } else {
            let previousID = selectedID
            selectedID = snapshot?.entries[safe: table.selectedRow]?.record.id
            if selectedID != previousID { categoryDraft = nil; acceptedCategoryReceipt = false }
            if selectedID != nil, !isLoading, detailsOpen { renderDetails() }
            else if selectedID == nil { closeDetails() }
            refreshStatus()
        }
    }

    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        guard tableView === resultsTable else { return }
        (rowView.view(atColumn: 0) as? LibraryResultCell)?.cancelIcon()
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        onPresentationOwnershipChange?()
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        onPresentationOwnershipChange?()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard (notification.object as? NSSearchField) === searchField else { return }
        changeQuery(searchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField else { return false }
        if textView.hasMarkedText() { return false }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.moveDown(_:)) {
            selectFirstResult()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { return handleEscape() }
        return false // Native Tab, Shift-Tab and text navigation remain AppKit-owned.
    }

    private func selectFirstResult() {
        guard !isLoading, snapshot?.entries.isEmpty == false else { return }
        browsingAllResults = true
        needsLayout = true
        resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        selectedID = snapshot?.entries.first?.record.id
        resultsTable.scrollRowToVisible(0)
        // In drawer mode, keep the result table visible so its Return can launch.
        closeDetails()
        window?.makeFirstResponder(resultsTable)
        refreshStatus()
    }

    private func invalidateActions() {
        if let selectedID { pendingSelection = (selectedID, detailsOpen) }
        isLoading = true
        presentationGeneration &+= 1
        cancelIcons()
        selectedID = nil
        updatingSelection = true
        resultsTable.deselectAll(nil)
        updatingSelection = false
        closeDetails()
        clearDetailValues()
        refreshStatus()
    }

    private func changeQuery(_ value: String) {
        guard query != value else { return }
        query = value
        browsingAllResults = false
        invalidateActions()
        onQueryChange?(value)
    }

    private func changeCategory(_ category: AppLibraryCategory?) {
        guard selectedCategory != category || selectedActivitySection != nil else { return }
        selectedActivitySection = nil
        selectedCategory = category
        selectCategoryControl()
        invalidateActions()
        onCategoryChange?(category)
    }

    private func selectCategoryControl() {
        let index: Int
        if let section = selectedActivitySection, activitySectionsEnabled {
            index = section == .recent ? 1 : 2
        } else {
            index = selectedCategory.flatMap { AppLibraryCategory.allCases.firstIndex(of: $0).map { $0 + 1 + activityRowCount } } ?? 0
        }
        let previous = updatingSelection
        updatingSelection = true
        categoriesTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        compactCategoryPicker.selectItem(at: index)
        updatingSelection = previous
    }

    @objc func compactCategoryChanged(_ sender: Any?) {
        let index = compactCategoryPicker.indexOfSelectedItem
        selectNavigationRow(index)
    }

    private var activityRowCount: Int { activitySectionsEnabled ? 2 : 0 }

    private func activitySection(at row: Int) -> LaunchActivitySection? {
        guard activitySectionsEnabled else { return nil }
        return row == 1 ? .recent : row == 2 ? .frequent : nil
    }

    private func category(at row: Int) -> AppLibraryCategory? {
        guard row > activityRowCount else { return nil }
        return AppLibraryCategory.allCases[safe: row - 1 - activityRowCount]
    }

    private func selectNavigationRow(_ row: Int) {
        guard row >= 0, row < AppLibraryCategory.allCases.count + 1 + activityRowCount else { return }
        guard let section = activitySection(at: row) else { changeCategory(category(at: row)); return }
        guard selectedActivitySection != section else { return }
        selectedActivitySection = section
        selectedCategory = nil
        selectCategoryControl()
        invalidateActions()
        onActivitySectionChange?(section)
    }

    func setActivitySectionsEnabled(_ enabled: Bool) {
        guard enabled != activitySectionsEnabled else { return }
        activitySectionsEnabled = enabled
        if !enabled { selectedActivitySection = nil }
        relabel(strings: strings)
        // The owner invalidates/reprojects actions in the same transaction.
    }

    private var selectedEntry: AppLibraryEntry? {
        guard let selectedID else { return nil }
        return snapshot?.entries.first { $0.record.id == selectedID }
    }

    private func request() -> AppLibraryActionRequest? {
        guard !isLoading, !isHiddenOrHasHiddenAncestor, let snapshot, let entry = selectedEntry else { return nil }
        return AppLibraryActionRequest(record: entry.record, catalogRevision: snapshot.revision, generation: actionGeneration)
    }

    @objc func back(_ sender: Any?) {
        if selectedCategory != nil || selectedActivitySection != nil || browsingAllResults {
            returnToGallery()
        } else { onBack?() }
    }

    private func returnToGallery() {
        browsingAllResults = false
        selectedActivitySection = nil
        selectedCategory = nil
        selectCategoryControl()
        invalidateActions()
        onCategoryChange?(nil)
        needsLayout = true
        focusSearch()
    }

    private func rebuildGallery() {
        galleryView.apply(entries: isLoading ? [] : snapshot?.entries ?? [], strings: strings,
                          generation: presentationGeneration, pipeline: iconPipeline)
    }

    private func activateGalleryApp(_ id: AppID, details: Bool) {
        guard showsGallery, !isLoading, !appActionsBlocked, !isHiddenOrHasHiddenAncestor,
              let snapshot, let row = snapshot.entries.firstIndex(where: { $0.record.id == id }) else { return }
        let entry = snapshot.entries[row]
        if details {
            selectedID = id
            resultsTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            showDetails(nil)
        } else {
            onOpen?(AppLibraryActionRequest(record: entry.record, catalogRevision: snapshot.revision,
                                            generation: actionGeneration))
        }
    }
    @objc func openSelection(_ sender: Any?) { if allowsExternalApplicationActions, let request = request() { onOpen?(request) } }
    @objc func revealSelection(_ sender: Any?) { if allowsExternalApplicationActions, let request = request() { onReveal?(request) } }
    @objc func editAlias(_ sender: Any?) { if let request = request() { onEditAlias?(request) } }
    @objc func hideSelection(_ sender: Any?) { if let request = request() { onSetHidden?(request, true) } }
    @objc func assignFolder(_ sender: Any?) { if let request = request() { onFolderAssignment?(request) } }
    @objc func moveSelectionToTrash(_ sender: Any?) { if allowsExternalApplicationActions, allowsApplicationRemoval, let request = request() { onMoveToTrash?(request) } }
    @objc func saveCategory(_ sender: Any?) {
        guard let request = request(), let picker = categoryPicker else { return }
        let index = picker.indexOfSelectedItem
        guard index >= 0, index <= AppLibraryCategory.allCases.count else { return }
        categoryDraftChanged(picker)
        categoryDraft?.submitted = true
        onSetCategory?(request, index == 0 ? nil : AppLibraryCategory.allCases[index - 1])
    }
    @objc func restoreAutomatic(_ sender: Any?) {
        if let request = request(), let entry = selectedEntry {
            categoryDraft = (entry.record.id, nil, true, true)
            onSetCategory?(request, nil)
        }
    }
    @objc func dismissDetails(_ sender: Any?) { closeDetails(discardDraft: true) }

    @objc func showDetails(_ sender: Any?) {
        guard selectedEntry != nil, !isLoading else { return }
        browsingAllResults = true
        detailsOpen = true
        if detailScroll == nil { buildDetails() }
        renderDetails()
        refreshStatus()
        needsLayout = true
    }

    private func closeDetails(discardDraft: Bool = false) {
        if discardDraft { categoryDraft = nil; acceptedCategoryReceipt = false }
        resultsScroll.isHidden = false
        let responder = window?.firstResponder as? NSView
        let editingControl = (responder as? NSTextView)?.delegate as? NSView
        if let detailScroll,
           responder?.isDescendant(of: detailScroll) == true || editingControl?.isDescendant(of: detailScroll) == true {
            window?.makeFirstResponder(resultsTable)
        }
        detailsOpen = false
        detailScroll?.isHidden = true
        needsLayout = true
    }

    private func clearDetailValues() {
        for field in detailValues.values { field.stringValue = ""; field.setAccessibilityLabel(nil) }
        categoryPicker?.selectItem(at: 0)
        setDetailActionsEnabled(false)
    }

    private func buildDetails() {
        let scroll = LibraryScrollView(frame: .zero)
        identify(scroll, "library.details")
        scroll.setAccessibilityLabel(strings.libraryText(.details))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let document = LibraryFlippedView(frame: .zero)
        document.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scroll.documentView = document
        addSubview(scroll)
        detailScroll = scroll
        let heading = NSTextField(wrappingLabelWithString: strings.libraryText(.details))
        heading.font = .boldSystemFont(ofSize: 16)
        stack.addArrangedSubview(heading)
        heading.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        detailHeading = heading
        closeDetailsButton = detailButton("library.details.close", #selector(dismissDetails(_:)), in: stack)
        for key in [LibraryTextKey.originalName, .alias, .category, .automaticCategory, .manualCategory,
                    .bundleIdentifier, .location, .version, .build] {
            let label = NSTextField(wrappingLabelWithString: strings.libraryText(key))
            label.font = .boldSystemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            let value = NSTextField(wrappingLabelWithString: "")
            value.isSelectable = true
            value.delegate = self
            identify(value, "library.details." + key.rawValue.replacingOccurrences(of: "library.", with: ""))
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            stack.addArrangedSubview(value)
            value.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            detailLabels[key] = label
            detailValues[key] = value
        }
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        identify(picker, "library.details.categoryPicker")
        stack.addArrangedSubview(picker)
        picker.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        categoryPicker = picker
        picker.target = self
        picker.action = #selector(categoryDraftChanged(_:))
        let saveStatus = NSTextField(wrappingLabelWithString: "")
        identify(saveStatus, "library.details.saveStatus")
        stack.addArrangedSubview(saveStatus)
        saveStatus.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        categorySaveStatusLabel = saveStatus
        renderCategorySaveStatus()
        saveCategoryButton = detailButton("library.details.saveCategory", #selector(saveCategory(_:)), in: stack)
        restoreAutomaticButton = detailButton("library.details.restoreAutomatic", #selector(restoreAutomatic(_:)), in: stack)
        openButton = detailButton("library.details.open", #selector(openSelection(_:)), in: stack)
        revealButton = detailButton("library.details.reveal", #selector(revealSelection(_:)), in: stack)
        aliasButton = detailButton("library.details.editAlias", #selector(editAlias(_:)), in: stack)
        hideButton = detailButton("library.details.hide", #selector(hideSelection(_:)), in: stack)
        folderButton = detailButton("library.details.folderAssignment", #selector(assignFolder(_:)), in: stack)
        removalButton = detailButton("library.details.moveToTrash", #selector(moveSelectionToTrash(_:)), in: stack)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -12)
        ])
        relabelDetails()
    }

    private func detailButton(_ identifier: String, _ action: Selector, in stack: NSStackView) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.bezelStyle = .rounded
        identify(button, identifier)
        stack.addArrangedSubview(button)
        button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        (button.cell as? NSButtonCell)?.lineBreakMode = .byTruncatingTail
        return button
    }

    private func renderDetails() {
        guard let entry = selectedEntry else { return }
        let unknown = strings.libraryText(.unknown)
        func factual(_ value: String?) -> String { value.flatMap { $0.isEmpty ? nil : $0 } ?? unknown }
        let values: [LibraryTextKey: String] = [
            .originalName: factual(entry.record.displayName),
            .alias: entry.displayName == entry.record.displayName ? unknown : factual(entry.displayName),
            .category: AppLibraryCategoryLabels.title(for: entry.category, strings: strings),
            .automaticCategory: AppLibraryCategoryLabels.title(for: AppLibraryCategory(
                declaredIdentifier: entry.record.bundleMetadata.declaredCategoryIdentifier), strings: strings),
            .manualCategory: entry.manualCategory.map { AppLibraryCategoryLabels.title(for: $0, strings: strings) } ?? strings.libraryText(.automatic),
            .bundleIdentifier: factual(entry.record.bundleIdentifier),
            .location: factual(entry.record.canonicalURL.path),
            .version: factual(entry.record.bundleMetadata.version),
            .build: factual(entry.record.bundleMetadata.build)
        ]
        for (key, value) in values {
            detailValues[key]?.stringValue = value
            detailValues[key]?.setAccessibilityLabel(strings.libraryText(key) + ": " + value)
        }
        if categoryDraft?.id != entry.record.id || acceptedCategoryReceipt {
            categoryDraft = (entry.record.id, entry.manualCategory, false, false)
            acceptedCategoryReceipt = false
        } else if categoryDraft?.dirty != true, categoryDraft?.submitted != true {
            categoryDraft?.value = entry.manualCategory
        }
        let index = categoryDraft?.value.flatMap { AppLibraryCategory.allCases.firstIndex(of: $0).map { $0 + 1 } } ?? 0
        categoryPicker?.selectItem(at: index)
        setDetailActionsEnabled(!isLoading)
    }

    @objc func categoryDraftChanged(_ sender: Any?) {
        guard let entry = selectedEntry, let picker = categoryPicker else { return }
        let index = picker.indexOfSelectedItem
        let value = index > 0 ? AppLibraryCategory.allCases[safe: index - 1] : nil
        categoryDraft = (entry.record.id, value, value != entry.manualCategory, false)
    }

    func categorySaveDidComplete(_ result: AppLibrarySaveResult) {
        categorySaveResult = result
        if result == .saved { acceptedCategoryReceipt = true }
        else { categoryDraft?.submitted = false }
        renderCategorySaveStatus()
    }

    private func renderCategorySaveStatus() {
        let failed = categorySaveResult != nil && categorySaveResult != .saved
        categorySaveStatusLabel?.stringValue = failed ? strings.libraryText(.saveFailed) : ""
        categorySaveStatusLabel?.setAccessibilityLabel(failed ? strings.libraryText(.saveFailed) : nil)
        categorySaveStatusLabel?.isHidden = !failed
    }

    private func setDetailActionsEnabled(_ enabled: Bool) {
        for control in [categoryPicker as NSControl?, saveCategoryButton, restoreAutomaticButton,
                        openButton, revealButton, aliasButton, hideButton, folderButton, removalButton].compactMap({ $0 }) {
            control.isEnabled = enabled && !appActionsBlocked
        }
        if !allowsExternalApplicationActions {
            for control in [openButton, revealButton, removalButton] { control?.isEnabled = false }
        }
        removalButton?.isHidden = onMoveToTrash == nil || !allowsApplicationRemoval
        if !allowsApplicationRemoval { removalButton?.isEnabled = false }
        if let categorySaveResult, [AppLibrarySaveResult.protectedPayload, .unavailable, .recoveryRequired].contains(categorySaveResult) {
            categoryPicker?.isEnabled = false
            saveCategoryButton?.isEnabled = false
            restoreAutomaticButton?.isEnabled = false
        }
    }

    func setAppActionsBlocked(_ blocked: Bool) {
        appActionsBlocked = blocked
        galleryView.setBlocked(blocked)
        backButton.isEnabled = !blocked
        setDetailActionsEnabled(selectedEntry != nil && !isLoading)
    }

    private func refreshBackButtonVisibility() {
        let hidden = showsGallery
        // A keyboard-selected nested Back must not remain focused when its
        // destination overview removes that control from the header.
        if hidden, window?.firstResponder === backButton { focusSearch() }
        backButton.isHidden = hidden
        backButton.setAccessibilityHidden(hidden)
    }

    private func refreshStatus() {
        refreshBackButtonVisibility()
        if !isLoading, !detailsOpen, snapshot?.entries.isEmpty == true, let section = selectedActivitySection {
            statusLabel.stringValue = strings.launchActivityText(section == .recent ? .emptyRecent : .emptyFrequent)
            statusLabel.setAccessibilityLabel(statusLabel.stringValue)
            statusLabel.isHidden = false
            return
        }
        let key: LibraryTextKey = isLoading ? .loading : snapshot == nil ? .unavailable : catalogIsEmpty ? .empty : .noResults
        statusLabel.stringValue = strings.libraryText(key)
        statusLabel.setAccessibilityLabel(statusLabel.stringValue)
        statusLabel.isHidden = detailsOpen || (snapshot?.entries.isEmpty == false && !isLoading)
        detailsButton.isEnabled = selectedEntry != nil && !isLoading
        setDetailActionsEnabled(selectedEntry != nil && !isLoading)
    }

    func relabel(strings: LocalizedStrings) {
        self.strings = strings
        renderCategorySaveStatus()
        setAccessibilityLabel(strings.libraryText(.title))
        searchField.placeholderString = strings.text(.searchPlaceholder)
        searchField.setAccessibilityLabel(strings.libraryText(.searchPlaceholder))
        backButton.title = strings.libraryText(.back)
        backButton.setAccessibilityLabel(backButton.title)
        detailsButton.title = strings.libraryText(.details)
        detailsButton.setAccessibilityLabel(detailsButton.title)
        categoriesTable.setAccessibilityLabel(strings.libraryText(.category))
        resultsTable.setAccessibilityLabel(strings.libraryText(.title))
        let prior = updatingSelection
        updatingSelection = true
        categoriesTable.reloadData()
        compactCategoryPicker.removeAllItems()
        compactCategoryPicker.addItem(withTitle: strings.libraryText(.all))
        if activitySectionsEnabled {
            compactCategoryPicker.addItem(withTitle: strings.launchActivityText(.recent))
            compactCategoryPicker.addItem(withTitle: strings.launchActivityText(.frequent))
        }
        for category in AppLibraryCategory.allCases {
            compactCategoryPicker.addItem(withTitle: AppLibraryCategoryLabels.title(for: category, strings: strings))
        }
        compactCategoryPicker.setAccessibilityLabel(strings.libraryText(.category))
        selectCategoryControl()
        updatingSelection = prior
        for cell in cells.allObjects {
            if let id = cell.appID, let entry = snapshot?.entries.first(where: { $0.record.id == id }) {
                cell.relabel(subtitle: AppLibraryCategoryLabels.title(for: entry.category, strings: strings))
            }
        }
        rebuildGallery()
        let pickerIndex = categoryPicker?.indexOfSelectedItem
        relabelDetails()
        if detailsOpen { renderDetails() }
        if let pickerIndex { categoryPicker?.selectItem(at: pickerIndex) }
        refreshStatus()
    }

    private func relabelDetails() {
        detailScroll?.setAccessibilityLabel(strings.libraryText(.details))
        detailHeading?.stringValue = strings.libraryText(.details)
        for (key, label) in detailLabels { label.stringValue = strings.libraryText(key) }
        for (button, key) in [(closeDetailsButton, LibraryTextKey.back), (saveCategoryButton, .saveCategory),
                              (restoreAutomaticButton, .restoreAutomatic), (openButton, .open), (revealButton, .reveal)] {
            button?.title = strings.libraryText(key)
            button?.setAccessibilityLabel(button?.title)
        }
        for (button, key) in [(aliasButton, MenuTextKey.setAlias), (hideButton, .hideApp), (folderButton, .organizeApps)] {
            button?.title = strings.menuText(key)
            button?.setAccessibilityLabel(button?.title)
        }
        folderButton?.isHidden = onFolderAssignment == nil
        removalButton?.title = strings.removalText(.moveToTrash)
        removalButton?.setAccessibilityLabel(strings.removalText(.moveToTrash))
        removalButton?.isHidden = onMoveToTrash == nil || !allowsApplicationRemoval
        categoryPicker?.removeAllItems()
        categoryPicker?.addItem(withTitle: strings.libraryText(.automatic))
        for category in AppLibraryCategory.allCases {
            categoryPicker?.addItem(withTitle: AppLibraryCategoryLabels.title(for: category, strings: strings))
        }
        categoryPicker?.setAccessibilityLabel(strings.libraryText(.category))
    }

    private func cancelIcons() {
        for cell in cells.allObjects { cell.cancelIcon() }
        galleryView.cancelIcons()
    }

    /// Presentation intent can change before layout updates the scroll view's
    /// hidden flag (for example, closeDetails temporarily exposes the results).
    private var resultsPresentationAllowsIcons: Bool {
        LibraryHorizontalLayout(boundsWidth: bounds.width, showsGallery: showsGallery)
            .allowsResultIcons(detailsOpen: detailsOpen)
    }

    private func synchronizeVisibleIcons() {
        galleryView.synchronizeIcons()
        guard resultsPresentationAllowsIcons, window?.isVisible == true,
              !resultsTable.isHiddenOrHasHiddenAncestor,
              !isLoading, let snapshot, let iconPipeline else {
            for cell in cells.allObjects { cell.cancelIcon() }
            return
        }
        let range = resultsTable.rows(in: resultsTable.visibleRect)
        let generation = presentationGeneration
        for cell in cells.allObjects {
            let row = resultsTable.row(for: cell)
            guard range.location != NSNotFound, row >= range.location, row < NSMaxRange(range),
                  let entry = snapshot.entries[safe: row], entry.record.id == cell.appID else {
                cell.cancelIcon()
                continue
            }
            let key = IconKey(identity: entry.record.iconIdentity, pointSize: 32,
                              displayScale: Double(window?.backingScaleFactor ?? 1))
            cell.requestIcon(key: key, generation: generation, pipeline: iconPipeline) { [weak self, weak cell] in
                guard let self, let cell else { return false }
                let currentRow = self.resultsTable.row(for: cell)
                let visible = self.resultsTable.rows(in: self.resultsTable.visibleRect)
                return self.presentationGeneration == generation && !self.isLoading
                    && self.resultsPresentationAllowsIcons && self.window?.isVisible == true
                    && !self.resultsTable.isHiddenOrHasHiddenAncestor && visible.location != NSNotFound
                    && currentRow >= visible.location && currentRow < NSMaxRange(visible)
                    && self.snapshot?.entries[safe: currentRow]?.record.id == entry.record.id
            }
        }
    }
}

@MainActor
final class LibraryResultsTable: NSTableView {
    var onReturn: (() -> Void)?
    var onEscape: (() -> Bool)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { onReturn?(); return }
        if event.keyCode == 53, onEscape?() == true { return }
        super.keyDown(with: event)
    }
}

@MainActor
private final class LibraryScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // The superclass scrolls this document; any edge bubbling terminates at Library root.
        super.scrollWheel(with: event)
    }
}

@MainActor
private final class LibraryFlippedView: NSView { override var isFlipped: Bool { true } }

@MainActor
private final class LibraryResultCell: NSTableCellView {
    private(set) var appID: AppID?
    private let subtitle = NSTextField(labelWithString: "")
    private var handle: IconRequestHandle?
    private var iconKey: IconKey?
    private var iconGeneration: UInt64?
    private var reuseGeneration: UInt64 = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        let icon = NSImageView(frame: .zero)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        imageView = icon
        textField = label
        for view in [icon, label, subtitle] as [NSView] { addSubview(view) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { handle?.cancel() }

    override func layout() {
        super.layout()
        imageView?.frame = NSRect(x: 8, y: 10, width: 32, height: 32)
        textField?.frame = NSRect(x: 50, y: 27, width: max(0, bounds.width - 58), height: 20)
        subtitle.frame = NSRect(x: 50, y: 8, width: max(0, bounds.width - 58), height: 17)
    }

    func bind(entry: AppLibraryEntry, subtitle: String) {
        cancelIcon()
        appID = entry.record.id
        textField?.stringValue = entry.displayName
        relabel(subtitle: subtitle)
    }

    func relabel(subtitle: String) {
        self.subtitle.stringValue = subtitle
        setAccessibilityLabel((textField?.stringValue ?? "") + ", " + subtitle)
    }

    func cancelIcon() {
        reuseGeneration &+= 1
        handle?.cancel()
        handle = nil
        iconKey = nil
        iconGeneration = nil
        imageView?.image = nil
    }

    func requestIcon(key: IconKey, generation: UInt64, pipeline: IconPipeline,
                     isCurrent: @escaping @MainActor @Sendable () -> Bool) {
        guard iconKey != key || iconGeneration != generation else { return }
        cancelIcon()
        iconKey = key
        iconGeneration = generation
        let reuse = reuseGeneration
        handle = pipeline.request(key: key, generation: generation) { [weak self] deliveredKey, deliveredGeneration, result in
            guard let self, self.reuseGeneration == reuse, self.iconKey == deliveredKey,
                  self.iconGeneration == deliveredGeneration, isCurrent() else { return }
            if case .success(let image) = result { self.imageView?.image = image }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
