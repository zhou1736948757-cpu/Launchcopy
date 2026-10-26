import AppCatalogCore
import Foundation

/// Build once per canonical layout/catalog change, then map only displayed frames.
public struct DragLogicalIndexMap {
    private enum Key: Hashable { case app(String); case folder(FolderID) }
    private var topIndices: [Key: Int] = [:]
    private var memberIndices: [FolderID: [String: Int]] = [:]
    private var projectedMemberOwners: [String: FolderID] = [:]
    private var representedReferences: [String: PersistentAppReference] = [:]
    public init(layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot? = nil) {
        for (index, entry) in layout.topLevelOrder.enumerated() {
            switch entry {
            case .app(let reference): topIndices[.app(reference.comparisonKey)] = index
            case .folder(let id): topIndices[.folder(id)] = index
            }
        }
        for folder in layout.folders {
            var indices: [String: Int] = [:]
            for (index, reference) in folder.members.enumerated() { indices[reference.comparisonKey] = index }
            memberIndices[folder.id] = indices
            if topIndices[.folder(folder.id)] != nil {
                for reference in folder.members { projectedMemberOwners[reference.comparisonKey] = folder.id }
            }
        }
        if let catalog {
            let resolver = WorkspaceAppReferenceResolver(layout: layout)
            for record in catalog.records {
                if let stored = resolver.reference(for: record) {
                    let key = PersistentAppReference.from(record: record).comparisonKey
                    if representedReferences[key] == nil { representedReferences[key] = stored }
                }
            }
        }
    }
    public func topLevel(_ frames: [DragItemFrame]) -> [DragItemFrame] {
        let representedFolders = Set(frames.compactMap { frame -> FolderID? in
            if case .folder(let id) = frame.identity { return id }; return nil
        })
        return frames.compactMap { original in
            let frame = canonicalFrame(original)
            let key: Key
            switch frame.identity {
            case .app(let reference): key = .app(reference.comparisonKey)
            case .folder(let id): key = .folder(id)
            }
            if let index = topIndices[key] { return frame.mapped(toLogicalIndex: index) }
            if case .app(let reference) = frame.identity,
               let folder = projectedMemberOwners[reference.comparisonKey], !representedFolders.contains(folder),
               let index = topIndices[.folder(folder)] {
                // A visually dissolved singleton represents its still-persisted
                // group. Reorder/drop targets preserve that group's latent members.
                return DragItemFrame(identity: .folder(folder), frame: frame.frame,
                                     pageIndex: frame.pageIndex, itemsPerPage: frame.itemsPerPage, logicalIndex: index,
                                     appGroupingFrame: frame.appGroupingFrame)
            }
            return nil
        }
    }
    public func members(_ frames: [DragItemFrame], folderID: FolderID) -> [DragItemFrame] {
        frames.compactMap { original in
            let frame = canonicalFrame(original)
            guard case .app(let reference) = frame.identity else { return nil }
            return memberIndices[folderID]?[reference.comparisonKey].map { frame.mapped(toLogicalIndex: $0) }
        }
    }
    private func canonicalFrame(_ frame: DragItemFrame) -> DragItemFrame {
        guard case .app(let reference) = frame.identity,
              let stored = representedReferences[reference.comparisonKey], stored != reference else { return frame }
        return .init(identity: .app(stored), frame: frame.frame, pageIndex: frame.pageIndex,
                     itemsPerPage: frame.itemsPerPage, logicalIndex: frame.logicalIndex,
                     appGroupingFrame: frame.appGroupingFrame)
    }
}

/// Identity-based view-to-layout mapping. Hidden apps never turn a displayed index
/// into permission to overwrite an unrelated persistent reference.
public enum DragLogicalIndexMapper {
    public static func topLevel(_ frames: [DragItemFrame], layout: PersistentWorkspaceLayout) -> [DragItemFrame] {
        DragLogicalIndexMap(layout: layout).topLevel(frames)
    }

    public static func members(_ frames: [DragItemFrame], folderID: FolderID,
                               layout: PersistentWorkspaceLayout) -> [DragItemFrame] {
        DragLogicalIndexMap(layout: layout).members(frames, folderID: folderID)
    }
}
