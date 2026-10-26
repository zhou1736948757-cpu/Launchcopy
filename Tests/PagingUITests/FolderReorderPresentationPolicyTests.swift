import AppCatalogCore
import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

final class FolderReorderPresentationPolicyTests: XCTestCase {
    private let target = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!)
    private let other = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)
    private let missing = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!)
    private let a = PersistentAppReference.bundleID("fixture.reorder.alpha")
    private let b = PersistentAppReference.canonicalPath("/syntheticapps/beta.app")
    private let c = PersistentAppReference.bundleID("fixture.reorder.gamma")
    private let d = PersistentAppReference.bundleID("fixture.reorder.delta")

    private func layout(generation: UInt64 = 4,
                        topLevel: [WorkspaceTopLevelEntry]? = nil,
                        folders: [PersistentFolderRecord]? = nil) -> PersistentWorkspaceLayout {
        .init(generation: LayoutGeneration(generation),
              topLevelOrder: topLevel ?? [.folder(target), .app(c), .folder(other)],
              folders: folders ?? [.init(id: target, title: "Target", members: [a, b]),
                                   .init(id: other, title: "Other", members: [d, .bundleID("fixture.reorder.echo")])])
    }

    private func permutation() -> PersistentWorkspaceLayout {
        layout(generation: 5, folders: [
            .init(id: target, title: "Target", members: [b, a]), layout().folders[1]
        ])
    }

    func testPersistentPermutationAcceptsOnlyTargetOrderAndGenerationChange() {
        XCTAssertTrue(FolderReorderPresentationPolicy.isPureMemberPermutation(
            from: layout(), to: permutation(), folderID: target))
    }

    func testPersistentPermutationRejectsNoOpAndDuplicateMembersInEitherInput() {
        XCTAssertFalse(FolderReorderPresentationPolicy.isPureMemberPermutation(
            from: layout(), to: layout(), folderID: target))
        XCTAssertFalse(FolderReorderPresentationPolicy.isPureMemberPermutation(
            from: layout(), to: layout(generation: 5), folderID: target), "Generation alone is not a reorder")
        let duplicateBefore = layout(folders: [
            .init(id: target, title: "Target", members: [a, b, a]), layout().folders[1]
        ])
        let duplicateAfter = layout(generation: 5, folders: [
            .init(id: target, title: "Target", members: [b, a, a]), layout().folders[1]
        ])
        for (before, after) in [(layout(), duplicateAfter), (duplicateBefore, permutation()),
                                (duplicateBefore, duplicateAfter)] {
            XCTAssertFalse(FolderReorderPresentationPolicy.isPureMemberPermutation(
                from: before, to: after, folderID: target))
        }
    }

    func testPersistentPermutationRejectsMembershipTitleAndOtherFolderChanges() {
        let reordered = permutation()
        let replacements: [(String, [PersistentFolderRecord])] = [
            ("Member replaced", [.init(id: target, title: "Target", members: [b, c]), reordered.folders[1]]),
            ("Member added", [.init(id: target, title: "Target", members: [b, a, c]), reordered.folders[1]]),
            ("Member removed", [.init(id: target, title: "Target", members: [b]), reordered.folders[1]]),
            ("Target renamed", [.init(id: target, title: "Renamed", members: [b, a]), reordered.folders[1]]),
            ("Other renamed", [reordered.folders[0], .init(id: other, title: "Renamed", members: layout().folders[1].members)]),
            ("Other reordered", [reordered.folders[0], .init(id: other, title: "Other", members: Array(layout().folders[1].members.reversed()))])
        ]
        for (reason, folders) in replacements {
            XCTAssertFalse(FolderReorderPresentationPolicy.isPureMemberPermutation(
                from: layout(), to: layout(generation: 5, folders: folders), folderID: target), reason)
        }
    }

    func testPersistentPermutationRejectsTopLevelFolderCollectionAndIdentityChanges() {
        let reordered = permutation()
        let invalid: [(String, PersistentWorkspaceLayout)] = [
            ("Top-level order", layout(generation: 5, topLevel: Array(reordered.topLevelOrder.reversed()), folders: reordered.folders)),
            ("Top-level member", layout(generation: 5, topLevel: [.folder(target), .app(a), .folder(other)], folders: reordered.folders)),
            ("Folder collection order", layout(generation: 5, folders: Array(reordered.folders.reversed()))),
            ("Folder removed", layout(generation: 5, folders: [reordered.folders[0]])),
            ("Folder added", layout(generation: 5, folders: reordered.folders + [.init(id: missing, title: "Extra", members: [c, d])])),
            ("Folder identity", layout(generation: 5, folders: [.init(id: missing, title: "Target", members: [b, a]), reordered.folders[1]]))
        ]
        for (reason, after) in invalid {
            XCTAssertFalse(FolderReorderPresentationPolicy.isPureMemberPermutation(
                from: layout(), to: after, folderID: target), reason)
        }
        XCTAssertFalse(FolderReorderPresentationPolicy.isPureMemberPermutation(
            from: layout(), to: reordered, folderID: missing))
    }

    private func records() -> [AppRecord] {
        ["Alpha", "Beta", "Gamma"].map { name in
            let bundleID = "fixture.reorder.\(name.lowercased())"
            let id = CatalogFixture.appID(bundleID)
            return CatalogFixture.record(id: id, displayName: name, bundleID: bundleID,
                url: URL(fileURLWithPath: "/SyntheticApps/\(name).app"),
                icon: .from(appID: id), rootPriority: 0)
        }
    }

    func testVisibleProjectionAcceptsTargetPermutationAndUnchangedOtherValues() {
        let records = records(), ids = records.map(\.id)
        let before: [TopLevelEntry] = [.app(records[2]), .folder(.init(id: target, title: "Target", members: Array(ids.prefix(2))))]
        let after: [TopLevelEntry] = [.app(records[2]), .folder(.init(id: target, title: "Target", members: Array(ids.prefix(2).reversed())))]
        XCTAssertTrue(FolderReorderPresentationPolicy.hasUnchangedMainContent(from: before, to: after, folderID: target))
    }

    func testHiddenMemberPermutationCanRetainAnIdenticalVisibleProjection() {
        let hidden = PersistentAppReference.bundleID("fixture.reorder.hidden")
        let before = layout(folders: [
            .init(id: target, title: "Target", members: [a, hidden, b]), layout().folders[1]
        ])
        let after = layout(generation: 5, folders: [
            .init(id: target, title: "Target", members: [a, b, hidden]), layout().folders[1]
        ])
        XCTAssertTrue(FolderReorderPresentationPolicy.isPureMemberPermutation(
            from: before, to: after, folderID: target))
        let ids = Array(records().map(\.id).prefix(2))
        let visible: [TopLevelEntry] = [.folder(.init(id: target, title: "Target", members: ids))]
        XCTAssertTrue(FolderReorderPresentationPolicy.hasUnchangedMainContent(
            from: visible, to: visible, folderID: target))
    }

    func testVisibleProjectionRejectsTargetTitleMembershipCountAndIdentityChanges() {
        let records = records(), ids = records.map(\.id)
        let before: [TopLevelEntry] = [.app(records[2]), .folder(.init(id: target, title: "Target", members: Array(ids.prefix(2))))]
        let invalid: [FolderEntry] = [
            .init(id: target, title: "Renamed", members: [ids[1], ids[0]]),
            .init(id: target, title: "Target", members: [ids[1], ids[2]]),
            .init(id: target, title: "Target", members: [ids[1], ids[0], ids[0]]),
            .init(id: target, title: "Target", members: [ids[1], ids[1]]),
            .init(id: missing, title: "Target", members: [ids[1], ids[0]])
        ]
        for folder in invalid {
            XCTAssertFalse(FolderReorderPresentationPolicy.hasUnchangedMainContent(
                from: before, to: [.app(records[2]), .folder(folder)], folderID: target))
        }
    }

    func testVisibleProjectionRejectsOtherValuesReorderingCountChangesAndMissingTarget() {
        let records = records(), ids = records.map(\.id)
        let folder = TopLevelEntry.folder(.init(id: target, title: "Target", members: [ids[0], ids[1]]))
        let sibling = TopLevelEntry.folder(.init(id: other, title: "Other", members: [ids[1], ids[2]]))
        let before: [TopLevelEntry] = [.app(records[2]), folder, sibling]
        let sameIdentityRenamed = CatalogFixture.record(id: records[2].id, displayName: "New name",
            bundleID: records[2].bundleIdentifier!, url: records[2].canonicalURL,
            icon: .from(appID: records[2].id), rootPriority: 0)
        let invalid: [[TopLevelEntry]] = [
            [.app(sameIdentityRenamed), folder, sibling],
            [.app(records[2]), folder, .folder(.init(id: other, title: "Other", members: [ids[2], ids[1]]))],
            [folder, .app(records[2]), sibling],
            [.app(records[2]), folder],
            before + [.app(records[0])],
            [.app(records[2]), .app(records[0]), sibling]
        ]
        for after in invalid {
            XCTAssertFalse(FolderReorderPresentationPolicy.hasUnchangedMainContent(from: before, to: after, folderID: target))
        }
        XCTAssertFalse(FolderReorderPresentationPolicy.hasUnchangedMainContent(
            from: [.app(records[2])], to: [.app(records[2])], folderID: target))
        XCTAssertFalse(FolderReorderPresentationPolicy.hasUnchangedMainContent(from: [], to: [], folderID: target))
    }
}
