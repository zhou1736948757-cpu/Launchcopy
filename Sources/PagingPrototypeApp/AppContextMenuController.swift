import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization

/// Menu items hold immutable binding expectations; actions never trust a cached index/URL.
@MainActor
public final class AppContextMenuController: NSObject {
    /// Main supplies the currently displayed immutable snapshot, once per menu build.
    public var interfaceStringsProvider: () -> LocalizedStrings? = { nil }
    public var recordProvider: (AppID) -> AppRecord?
    public var revisionProvider: () -> UInt64?
    public var hiddenProvider: (AppRecord) -> Bool
    public var isReadOnlyProvider: () -> Bool = { false }
    public var actionsAreBusyProvider: () -> Bool = { false }
    /// Rechecked for the actual originating cell at build and action time.
    /// Shared folder/main menu owners must not use a global outer-grid mask.
    public var bindingIsAvailable: ((AppGridCellView) -> Bool)?
    public var onLaunch: ((AppID) -> Void)?
    public var onHide: ((AppRecord) -> Void)?
    public var onAlias: ((AppRecord) -> Void)?
    public var onClearAlias: ((AppRecord) -> Void)?
    public var onReveal: ((AppRecord) -> Void)?
    public var onMoveToTrash: ((AppRecord, @escaping () -> Bool) -> Void)?
    /// Optional organization submenu supplied by the independently owned layout consumer.
    public var organizationMenuProvider: ((AppGridCellView, AppRecord, UInt64) -> NSMenu?)?
    private final class Binding: NSObject {
        weak var cell: AppGridCellView?
        let token: ItemBindingToken
        let revision: UInt64
        let record: AppRecord
        let action: String
        init(cell: AppGridCellView, token: ItemBindingToken, revision: UInt64, record: AppRecord, action: String) {
            self.cell = cell; self.token = token; self.revision = revision; self.record = record; self.action = action
        }
    }

    public init(recordProvider: @escaping (AppID) -> AppRecord?, revisionProvider: @escaping () -> UInt64?,
                hiddenProvider: @escaping (AppRecord) -> Bool) {
        self.recordProvider = recordProvider
        self.revisionProvider = revisionProvider
        self.hiddenProvider = hiddenProvider
        super.init()
    }

    public func menu(for cell: AppGridCellView) -> NSMenu? {
        guard !actionsAreBusyProvider(), !cell.isHiddenOrHasHiddenAncestor,
              bindingIsAvailable?(cell) != false,
              let token = cell.bindingToken, let id = token.appID as? AppID,
              let revision = revisionProvider(), token.catalogRevision == revision,
              let record = recordProvider(id), !hiddenProvider(record) else { return nil }
        let strings = interfaceStringsProvider()
        let menu = NSMenu()
        menu.autoenablesItems = false
        let actions: [(String, MenuTextKey, String)] = [
            ("launch", .launch, "打开"), ("alias", .setAlias, "设置别名…"),
            ("clearAlias", .restoreOriginalName, "恢复原名"), ("hide", .hideApp, "隐藏应用"),
            ("reveal", .revealInFinder, "在 Finder 中显示")
        ]
        for (action, key, legacyTitle) in actions {
            let title = strings?.menuText(key) ?? legacyTitle
            let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
            item.setAccessibilityLabel(title)
            item.identifier = NSUserInterfaceItemIdentifier("management.\(action)")
            item.target = self
            item.isEnabled = !isReadOnlyProvider() || action == "launch" || action == "reveal"
            item.representedObject = Binding(cell: cell, token: token, revision: revision, record: record, action: action)
            menu.addItem(item)
        }
        if onMoveToTrash != nil {
            let title = strings?.removalText(.moveToTrash) ?? AppRemovalTextKey.moveToTrash.englishFallback
            let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
            item.setAccessibilityLabel(title)
            item.identifier = .init("management.moveToTrash")
            item.target = self
            item.isEnabled = !isReadOnlyProvider()
            item.representedObject = Binding(cell: cell, token: token, revision: revision, record: record, action: "moveToTrash")
            menu.addItem(item)
        }
        if let submenu = organizationMenuProvider?(cell, record, revision) {
            let title = strings?.menuText(.organizeApps) ?? "整理应用"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.setAccessibilityLabel(title)
            item.identifier = NSUserInterfaceItemIdentifier("management.organization")
            item.submenu = submenu
            menu.addItem(item)
        }
        return menu
    }

    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        guard !actionsAreBusyProvider(), let binding = sender.representedObject as? Binding,
              let cell = binding.cell, !cell.isHiddenOrHasHiddenAncestor, cell.bindingToken == binding.token,
              bindingIsAvailable?(cell) != false,
              revisionProvider() == binding.revision,
              let record = recordProvider(binding.record.id),
              record.canonicalURL == binding.record.canonicalURL, !hiddenProvider(record) else { return }
        guard !isReadOnlyProvider() || binding.action == "launch" || binding.action == "reveal" else { return }
        switch binding.action {
        case "launch": onLaunch?(record.id)
        case "hide": onHide?(record)
        case "alias": onAlias?(record)
        case "clearAlias": onClearAlias?(record)
        case "reveal": onReveal?(record)
        case "moveToTrash":
            onMoveToTrash?(record, { [weak self] in
                guard let self, let cell = binding.cell, !cell.isHiddenOrHasHiddenAncestor,
                      cell.bindingToken == binding.token, self.bindingIsAvailable?(cell) != false,
                      self.revisionProvider() == binding.revision,
                      let current = self.recordProvider(binding.record.id),
                      current.canonicalURL == binding.record.canonicalURL,
                      !self.hiddenProvider(current), !self.isReadOnlyProvider() else { return false }
                return true
            })
        default: break
        }
    }
}
