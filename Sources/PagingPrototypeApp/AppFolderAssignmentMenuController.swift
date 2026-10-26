import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization

/// Destination identity is independent of menu text, aliases and local ordinals.
public enum FolderAssignmentAction: Equatable, Sendable {
    case moveToFolder(FolderID)
    case moveToTopLevel
}

/// Pure organization policy. The application owns committing successful results.
public enum FolderAssignmentPolicy {
    public static func apply(action: FolderAssignmentAction, record: AppRecord,
                             expectedLayout: PersistentWorkspaceLayout,
                             currentLayout: PersistentWorkspaceLayout) -> LayoutMutationResult {
        guard expectedLayout == currentLayout else {
            return snapshotRejection(expected: expectedLayout, current: currentLayout)
        }
        guard let reference = WorkspaceAppReferenceResolver.reference(for: record, in: currentLayout) else {
            return .rejected(.invalidTarget)
        }
        let mutation = LayoutMutation(expectedGeneration: expectedLayout.generation)
        switch action {
        case .moveToFolder(let id):
            guard currentLayout.folder(id: id) != nil else {
                return .rejected(.folderDoesNotExist(id))
            }
            guard currentLayout.topLevelOrder.contains(.folder(id)) else {
                return .rejected(.invalidTarget)
            }
            return mutation.addToFolder(in: currentLayout, app: reference, folderID: id, at: .tail)
        case .moveToTopLevel:
            if currentLayout.topLevelOrder.contains(.app(reference)) {
                return .noOp(currentLayout)
            }
            guard let owner = currentLayout.folders.first(where: { $0.members.contains(reference) }),
                  let index = currentLayout.topLevelOrder.firstIndex(of: .folder(owner.id)) else {
                return .rejected(.invalidTarget)
            }
            // Dissolution replaces the source folder at its existing index, so the
            // departing member still follows it (or its surviving member).
            return mutation.moveOutOfFolder(in: currentLayout, folderID: owner.id,
                                            member: reference, toIndex: index + 1)
        }
    }

    fileprivate static func snapshotRejection(expected: PersistentWorkspaceLayout,
                                              current: PersistentWorkspaceLayout) -> LayoutMutationResult {
        if expected.generation != current.generation {
            return .rejected(.staleGeneration(expected: expected.generation, current: current.generation))
        }
        // The existing domain has no separate same-generation snapshot rejection.
        return .rejected(.invalidTarget)
    }
}

/// Canonical destination policy shared by grid menus and non-cell Library sheets.
/// Titles are presentation only; mutation always retains the canonical FolderID.
struct FolderAssignmentChoices {
    struct Destination {
        let id: FolderID
        let title: String
    }

    let destinations: [Destination]
    let canMoveOut: Bool

    init?(record: AppRecord, layout: PersistentWorkspaceLayout) {
        guard let reference = WorkspaceAppReferenceResolver.reference(for: record, in: layout) else { return nil }
        let owner = layout.folders.first { $0.members.contains(reference) }
        guard layout.topLevelOrder.contains(.app(reference)) || owner != nil else { return nil }
        let folders = layout.topLevelOrder.compactMap { entry -> PersistentFolderRecord? in
            guard case .folder(let id) = entry, id != owner?.id else { return nil }
            return layout.folder(id: id)
        }
        destinations = zip(folders, Self.destinationTitles(folders)).map { folder, title in
            Destination(id: folder.id, title: title)
        }
        canMoveOut = owner.map { layout.topLevelOrder.contains(.folder($0.id)) } ?? false
    }

    private static func destinationTitles(_ folders: [PersistentFolderRecord]) -> [String] {
        let counts = folders.reduce(into: [String: Int]()) { $0[$1.title, default: 0] += 1 }
        let reserved = Set(folders.map(\.title))
        var ordinals: [String: Int] = [:]
        var used = Set<String>()
        return folders.map { folder in
            guard counts[folder.title, default: 0] > 1 else { return folder.title }
            var ordinal = ordinals[folder.title, default: 0] + 1
            var title = "\(folder.title) (\(ordinal))"
            // A user's literal title may itself look like an ordinal suffix.
            while reserved.contains(title) || used.contains(title) {
                ordinal += 1
                title = "\(folder.title) (\(ordinal))"
            }
            ordinals[folder.title] = ordinal
            used.insert(title)
            return title
        }
    }

}

/// Produces only the assignment submenu; it does not own layout or persistence.
@MainActor
public final class AppFolderAssignmentMenuController: NSObject {
    public var bindingIsAvailable: ((AppGridCellView) -> Bool)?
    /// Main supplies the currently displayed immutable snapshot, once per submenu build.
    public var interfaceStringsProvider: () -> LocalizedStrings? = { nil }
    public var currentLayoutProvider: () -> PersistentWorkspaceLayout?
    public var recordProvider: (AppID) -> AppRecord?
    public var revisionProvider: () -> UInt64?
    public var hiddenProvider: (AppRecord) -> Bool
    /// Supply layout-store protection, independently of app-management schema protection.
    public var isReadOnlyProvider: () -> Bool = { false }
    /// Supply active drag, title edit and teardown protection.
    public var canApplyProvider: () -> Bool = { true }
    /// Revalidate protection and apply the policy, then commit only `.success` through
    /// the application's shared drag/menu commit method. Keep this synchronous.
    public var onApply: ((AppRecord, FolderAssignmentAction, PersistentWorkspaceLayout, () -> Bool) -> LayoutMutationResult)?
    /// Neutral local feedback only; never log identities, titles or membership.
    public var onRejected: ((LayoutMutationResult) -> Void)?

    private final class Binding: NSObject {
        weak var cell: AppGridCellView?
        let token: ItemBindingToken
        let revision: UInt64
        let record: AppRecord
        let reference: PersistentAppReference
        let expectedLayout: PersistentWorkspaceLayout
        let action: FolderAssignmentAction

        init(cell: AppGridCellView, token: ItemBindingToken, revision: UInt64,
             record: AppRecord, expectedLayout: PersistentWorkspaceLayout, action: FolderAssignmentAction) {
            self.cell = cell
            self.token = token
            self.revision = revision
            self.record = record
            self.reference = WorkspaceAppReferenceResolver.reference(for: record, in: expectedLayout) ?? .from(record: record)
            self.expectedLayout = expectedLayout
            self.action = action
        }
    }

    public init(currentLayoutProvider: @escaping () -> PersistentWorkspaceLayout?,
                recordProvider: @escaping (AppID) -> AppRecord?, revisionProvider: @escaping () -> UInt64?,
                hiddenProvider: @escaping (AppRecord) -> Bool) {
        self.currentLayoutProvider = currentLayoutProvider
        self.recordProvider = recordProvider
        self.revisionProvider = revisionProvider
        self.hiddenProvider = hiddenProvider
        super.init()
    }

    /// Returns nil when no existing destination or move-out action is available.
    /// The caller embeds this NSMenu under its own parent context-menu item.
    public func menu(for cell: AppGridCellView, record: AppRecord, revision: UInt64) -> NSMenu? {
        guard bindingIsAvailable?(cell) != false,
              let token = cell.bindingToken, token.appID as? AppID == record.id,
              token.catalogRevision == revision, revisionProvider() == revision,
              let canonical = recordProvider(record.id), canonical.id == record.id,
              canonical.canonicalURL == record.canonicalURL,
              PersistentAppReference.from(record: canonical) == .from(record: record),
              !hiddenProvider(canonical), let layout = currentLayoutProvider() else { return nil }

        guard let choices = FolderAssignmentChoices(record: canonical, layout: layout),
              !choices.destinations.isEmpty || choices.canMoveOut else { return nil }

        let strings = interfaceStringsProvider()
        let menu = NSMenu(title: strings?.menuText(.moveToFolder) ?? "移动到文件夹")
        menu.autoenablesItems = false
        let enabled = !isReadOnlyProvider() && canApplyProvider() && onApply != nil
        for destination in choices.destinations {
            menu.addItem(makeItem(title: destination.title, identifier: "folderAssignment.moveToFolder",
                                  action: .moveToFolder(destination.id), cell: cell, token: token,
                                  revision: revision, record: canonical, layout: layout, enabled: enabled))
        }
        if choices.canMoveOut {
            if !choices.destinations.isEmpty { menu.addItem(.separator()) }
            menu.addItem(makeItem(title: strings?.menuText(.moveToTopLevel) ?? "移到主页面", identifier: "folderAssignment.moveToTopLevel",
                                  action: .moveToTopLevel, cell: cell, token: token,
                                  revision: revision, record: canonical, layout: layout, enabled: enabled))
        }
        return menu
    }

    private func makeItem(title: String, identifier: String, action: FolderAssignmentAction,
                          cell: AppGridCellView, token: ItemBindingToken, revision: UInt64,
                          record: AppRecord, layout: PersistentWorkspaceLayout, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleAssignment(_:)), keyEquivalent: "")
        item.setAccessibilityLabel(title)
        item.identifier = NSUserInterfaceItemIdentifier(identifier)
        item.target = self
        item.isEnabled = enabled
        item.representedObject = Binding(cell: cell, token: token, revision: revision, record: record,
                                         expectedLayout: layout, action: action)
        return item
    }

    @objc private func handleAssignment(_ sender: NSMenuItem) {
        guard let binding = sender.representedObject as? Binding else { return }
        guard let cell = binding.cell, cell.bindingToken == binding.token,
              bindingIsAvailable?(cell) != false,
              revisionProvider() == binding.revision,
              let record = recordProvider(binding.record.id), record.id == binding.record.id,
              record.canonicalURL == binding.record.canonicalURL,
              WorkspaceAppReferenceResolver.reference(for: record, in: binding.expectedLayout) == binding.reference,
              !hiddenProvider(record), let layout = currentLayoutProvider() else {
            onRejected?(.rejected(.invalidTarget))
            return
        }
        guard layout == binding.expectedLayout else {
            onRejected?(FolderAssignmentPolicy.snapshotRejection(expected: binding.expectedLayout, current: layout))
            return
        }
        guard !isReadOnlyProvider(), canApplyProvider(), let apply = onApply else {
            onRejected?(.cancelled)
            return
        }
        // The owner performs the sole mutation and commits only success. A no-op
        // must cause no persistence enqueue or presentation refresh there.
        let validate = { [weak self] in self?.isCurrent(binding) ?? false }
        let result = apply(record, binding.action, binding.expectedLayout, validate)
        reportRejection(result)
    }

    private func isCurrent(_ binding: Binding) -> Bool {
        guard let cell = binding.cell, cell.bindingToken == binding.token,
              bindingIsAvailable?(cell) != false,
              revisionProvider() == binding.revision,
              let record = recordProvider(binding.record.id), record.canonicalURL == binding.record.canonicalURL,
              !hiddenProvider(record), let layout = currentLayoutProvider(), layout == binding.expectedLayout,
              WorkspaceAppReferenceResolver.reference(for: record, in: layout) == binding.reference,
              !isReadOnlyProvider(), canApplyProvider() else { return false }
        return true
    }

    private func reportRejection(_ result: LayoutMutationResult) {
        switch result {
        case .rejected, .cancelled: onRejected?(result)
        case .success, .noOp: break
        }
    }
}
