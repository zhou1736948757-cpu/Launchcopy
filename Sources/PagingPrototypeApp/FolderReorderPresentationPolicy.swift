import AppGridUI

/// Certifies an unchanged main-grid drawing, not layout admission or persistence.
/// All comparisons are local values; identity keys never leave this transaction.
enum FolderReorderPresentationPolicy {
    static func isPureMemberPermutation(from previous: PersistentWorkspaceLayout,
                                        to proposed: PersistentWorkspaceLayout,
                                        folderID: FolderID) -> Bool {
        guard previous.topLevelOrder == proposed.topLevelOrder,
              previous.folders.count == proposed.folders.count,
              Set(previous.folders.map(\.id)).count == previous.folders.count,
              previous.topLevelOrder.filter({ $0 == .folder(folderID) }).count == 1 else { return false }
        var found = false
        for (old, new) in zip(previous.folders, proposed.folders) {
            guard old.id == folderID else {
                guard old == new else { return false }
                continue
            }
            guard !found, new.id == old.id, new.title == old.title,
                  old.members.count > 1, old.members.count == new.members.count,
                  old.members != new.members else { return false }
            let oldKeys = Set(old.members.map(\.comparisonKey))
            let newKeys = Set(new.members.map(\.comparisonKey))
            guard oldKeys.count == old.members.count,
                  newKeys.count == new.members.count, oldKeys == newKeys else { return false }
            found = true
        }
        return found
    }

    static func hasUnchangedMainContent(from previous: [TopLevelEntry],
                                        to proposed: [TopLevelEntry],
                                        folderID: FolderID) -> Bool {
        guard previous.count == proposed.count else { return false }
        var found = false
        for (old, new) in zip(previous, proposed) {
            if case .folder(let oldFolder) = old, oldFolder.id == folderID {
                guard !found, case .folder(let newFolder) = new,
                      newFolder.id == oldFolder.id, newFolder.title == oldFolder.title,
                      oldFolder.members.count == newFolder.members.count else { return false }
                let oldMembers = Set(oldFolder.members)
                let newMembers = Set(newFolder.members)
                guard oldMembers.count == oldFolder.members.count,
                      newMembers.count == newFolder.members.count,
                      oldMembers == newMembers else { return false }
                found = true
            } else if old != new { return false }
        }
        return found
    }
}
