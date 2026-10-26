import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

final class WorkspaceAppReferenceResolverTests: XCTestCase {
    private let firstFolderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!)
    private let secondFolderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!)
    private let missing = PersistentAppReference.canonicalPath("/syntheticapps/missing.app")

    private func record(_ name: String = "Alpha",
                        bundleID: String? = "fixture.resolver.alpha",
                        path: String = "/SyntheticApps/Alpha.app") -> AppRecord {
        let url = URL(fileURLWithPath: path)
        let id: AppID
        if let bundleID, !bundleID.isEmpty {
            id = .bundleIdentifier(bundleID)
        } else {
            id = .canonicalURLFallback(url)
        }
        return AppRecord(id: id, displayName: name, bundleIdentifier: bundleID,
                         canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }

    private func pathReference(_ record: AppRecord) -> PersistentAppReference {
        .canonicalPath(PersistentAppReference.normalizedPath(record.canonicalURL))
    }

    private func layout(_ entries: [WorkspaceTopLevelEntry],
                        folders: [PersistentFolderRecord] = []) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: LayoutGeneration(9), topLevelOrder: entries, folders: folders)
    }

    private func project(_ layout: PersistentWorkspaceLayout,
                         records: [AppRecord]) -> VisibleWorkspaceProjection {
        VisibleWorkspaceProjection.project(layout: layout,
            catalog: CatalogSnapshot(revision: CatalogRevision(7), records: records))
    }

    private func visibleRecords(_ projection: VisibleWorkspaceProjection) -> [AppRecord] {
        projection.topLevel.flatMap { entry -> [AppRecord] in
            switch entry {
            case .app(let record): return [record]
            case .folder(let folder): return folder.availableMembers
            }
        }
    }

    private func assertReference(_ expected: PersistentAppReference?,
                                 for record: AppRecord, in layout: PersistentWorkspaceLayout,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(WorkspaceAppReferenceResolver.reference(for: record, in: layout),
                       expected, file: file, line: line)
        XCTAssertEqual(WorkspaceAppReferenceResolver(layout: layout).reference(for: record),
                       expected, file: file, line: line)
    }

    func testBundledRecordWithSavedPathMemberAndLatentSurvivorHasOneOccurrenceAndNoTail() {
        let live = record(path: "/SyntheticApps/ALPHA.app/")
        let path = pathReference(live)
        let saved = layout([.folder(firstFolderID)], folders: [
            .init(id: firstFolderID, title: "Fixture group", members: [path, missing])
        ])
        let original = saved
        XCTAssertTrue(WorkspaceLayoutValidator.validate(saved).isEmpty)
        XCTAssertTrue(path.matches(record: live))
        XCTAssertNotEqual(path, PersistentAppReference.from(record: live))

        assertReference(path, for: live, in: saved)
        let projection = project(saved, records: [live])
        XCTAssertEqual(projection.topLevel, [.app(live)])
        XCTAssertEqual(visibleRecords(projection).filter { $0 == live }.count, 1)
        XCTAssertTrue(projection.unorchestratedAppRecords.isEmpty)
        XCTAssertEqual(projection.latentAppReferences, [missing])
        XCTAssertEqual(projection.layoutGeneration, saved.generation)
        XCTAssertEqual(projection.catalogRevision, CatalogRevision(7))
        XCTAssertEqual(saved, original)
        XCTAssertEqual(saved.folders[0].members, [path, missing])
    }

    func testTopLevelSavedPathForBundledRecordHasOneOccurrenceAndNoTail() {
        let live = record()
        let path = pathReference(live)
        let saved = layout([.app(missing), .app(path)])
        assertReference(path, for: live, in: saved)
        let projection = project(saved, records: [live])
        XCTAssertEqual(projection.topLevel, [.app(live)])
        XCTAssertEqual(projection.latentAppReferences, [missing])
        XCTAssertTrue(projection.unorchestratedAppRecords.isEmpty)
        XCTAssertEqual(saved.topLevelOrder, [.app(missing), .app(path)])
    }

    func testMissingMemberReturnsAtOriginalPositionWithoutRewritingPathReference() {
        let live = record()
        let restored = record("Missing", bundleID: "fixture.resolver.restored",
                              path: "/SyntheticApps/Missing.app")
        let path = pathReference(live)
        let saved = layout([.folder(firstFolderID)], folders: [
            .init(id: firstFolderID, title: "Fixture group", members: [missing, path])
        ])
        let absent = project(saved, records: [live])
        XCTAssertEqual(absent.latentAppReferences, [missing])
        let returned = project(saved, records: [live, restored])
        XCTAssertEqual(returned.topLevel, [.folder(.init(id: firstFolderID, title: "Fixture group",
            availableMembers: [restored, live], latentMemberCount: 0))])
        XCTAssertTrue(returned.unorchestratedAppRecords.isEmpty)
        XCTAssertTrue(returned.latentAppReferences.isEmpty)
        assertReference(missing, for: restored, in: saved)
        XCTAssertEqual(saved.folders[0].members, [missing, path])
    }

    func testTopLevelAppsTakePriorityOverEarlierFolderEntriesForEitherIdentityKind() {
        let live = record()
        let path = pathReference(live)
        let bundle = PersistentAppReference.from(record: live)
        for (topLevel, member) in [(path, bundle), (bundle, path)] {
            let saved = layout([.folder(firstFolderID), .app(topLevel)], folders: [
                .init(id: firstFolderID, title: "Fixture group", members: [member, missing])
            ])
            XCTAssertTrue(WorkspaceLayoutValidator.validate(saved).isEmpty)
            assertReference(topLevel, for: live, in: saved)
        }
    }

    func testFirstTopLevelMatchingReferenceWinsWithoutBundlePreference() {
        let live = record()
        let path = pathReference(live)
        let bundle = PersistentAppReference.from(record: live)
        assertReference(path, for: live, in: layout([.app(path), .app(bundle)]))
        assertReference(bundle, for: live, in: layout([.app(bundle), .app(path)]))
    }

    func testFoldersFollowCanonicalTopLevelOrderRatherThanFolderRecordArrayOrder() {
        let live = record()
        let path = pathReference(live)
        let bundle = PersistentAppReference.from(record: live)
        let folders: [PersistentFolderRecord] = [
            .init(id: secondFolderID, title: "Second", members: [bundle, missing]),
            .init(id: firstFolderID, title: "First", members: [path, .bundleID("fixture.resolver.latent")])
        ]
        let pathFirst = layout([.folder(firstFolderID), .folder(secondFolderID)], folders: folders)
        let bundleFirst = layout([.folder(secondFolderID), .folder(firstFolderID)], folders: folders)
        XCTAssertTrue(WorkspaceLayoutValidator.validate(pathFirst).isEmpty)
        assertReference(path, for: live, in: pathFirst)
        assertReference(bundle, for: live, in: bundleFirst)
    }

    func testFirstMatchingMemberWinsWithoutBundlePreference() {
        let live = record()
        let path = pathReference(live)
        let bundle = PersistentAppReference.from(record: live)
        for members in [[path, bundle], [bundle, path]] {
            let saved = layout([.folder(firstFolderID)], folders: [
                .init(id: firstFolderID, title: "Fixture group", members: members)
            ])
            assertReference(members[0], for: live, in: saved)
        }
    }

    func testProjectionBundleAndPathCatalogMatchesAreIndependentAndFirstMatchWins() {
        let first = record("First", path: "/SyntheticApps/First.app")
        let second = record("Second", path: "/SyntheticApps/Second.app")
        let path = pathReference(second)
        let bundle = PersistentAppReference.from(record: first)
        let saved = layout([.app(path), .app(bundle), .app(missing)])
        let resolver = WorkspaceAppReferenceResolver(layout: saved)
        XCTAssertEqual(resolver.reference(for: first), bundle)
        XCTAssertEqual(resolver.reference(for: second), path)
        let projection = project(saved, records: [first, second])
        XCTAssertEqual(projection.topLevel, [.app(second), .app(first)])
        XCTAssertEqual(projection.latentAppReferences, [missing])
        XCTAssertTrue(projection.unorchestratedAppRecords.isEmpty)
    }

    func testPureBundleAndPurePathReferencesKeepExistingMatchingSemantics() {
        let bundled = record()
        let pathOnly = record("Beta", bundleID: nil, path: "/SyntheticApps/Beta.app")
        let bundle = PersistentAppReference.from(record: bundled)
        let path = pathReference(pathOnly)
        let saved = layout([.app(path), .app(bundle)])
        assertReference(bundle, for: bundled, in: saved)
        assertReference(path, for: pathOnly, in: saved)
        let projection = project(saved, records: [bundled, pathOnly])
        XCTAssertEqual(visibleRecords(projection), [pathOnly, bundled])
        XCTAssertTrue(projection.unorchestratedAppRecords.isEmpty)
    }

    func testProjectionUsesFirstNormalizedPathMatchWithoutChangingIndependentBundleMatch() {
        let first = record("First", bundleID: "fixture.resolver.first", path: "/SyntheticApps/ALPHA.app")
        let second = record("Second", bundleID: "fixture.resolver.second", path: "/SyntheticApps/alpha.app")
        let path = pathReference(first)
        let bundle = PersistentAppReference.from(record: second)
        XCTAssertTrue(path.matches(record: first))
        XCTAssertTrue(path.matches(record: second))
        let saved = layout([.app(bundle), .app(path)])
        let projection = project(saved, records: [first, second])
        XCTAssertEqual(projection.topLevel, [.app(second), .app(first)])
        XCTAssertTrue(projection.unorchestratedAppRecords.isEmpty)
        assertReference(path, for: first, in: saved)
        assertReference(bundle, for: second, in: saved)
    }

    func testEmptyBundleIdentifierMatchesStoredEmptyBundleButNilDoesNot() {
        let emptyBundle = record(bundleID: "")
        let noBundle = record(bundleID: nil)
        let reference = PersistentAppReference.bundleID("")
        let saved = layout([.app(reference)])
        XCTAssertTrue(reference.matches(record: emptyBundle))
        XCTAssertFalse(reference.matches(record: noBundle))
        assertReference(reference, for: emptyBundle, in: saved)
        assertReference(nil, for: noBundle, in: saved)
        XCTAssertTrue(project(saved, records: [emptyBundle]).unorchestratedAppRecords.isEmpty)
    }

    func testStoredPathsAreNotSilentlyNormalizedAndBundleCaseRemainsExact() {
        let live = record()
        let nonmatching: [PersistentAppReference] = [
            .canonicalPath("/SyntheticApps/Alpha.app"),
            .bundleID("FIXTURE.RESOLVER.ALPHA")
        ]
        for reference in nonmatching {
            XCTAssertFalse(reference.matches(record: live))
            let saved = layout([.app(reference)])
            assertReference(nil, for: live, in: saved)
            let projection = project(saved, records: [live])
            XCTAssertEqual(projection.unorchestratedAppRecords, [live])
            XCTAssertEqual(projection.latentAppReferences, [reference])
        }
    }

    func testOnlyGenuinelyUnrepresentedRecordsEnterTailInCatalogOrder() {
        let represented = record()
        let beta = record("Beta", bundleID: "fixture.resolver.beta", path: "/SyntheticApps/Beta.app")
        let gamma = record("Gamma", bundleID: nil, path: "/SyntheticApps/Gamma.app")
        let saved = layout([.app(pathReference(represented)), .app(missing)])
        let projection = project(saved, records: [gamma, represented, beta])
        XCTAssertEqual(projection.unorchestratedAppRecords, [gamma, beta])
        XCTAssertEqual(visibleRecords(projection), [represented, gamma, beta])
        XCTAssertEqual(projection.latentAppReferences, [missing])
        assertReference(nil, for: beta, in: saved)
        assertReference(nil, for: represented, in: .empty())
    }
}
