import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

/// Public-provider regression coverage; fixtures perform no filesystem or window work.
/// Keep these tests source-compatible with the baseline that used hash ordering.
final class MixedAnchorRemappingTests: XCTestCase {
    private let capacity = 2

    private struct Item {
        let entry: WorkspaceTopLevelEntry
        let identity: TopLevelEntryIdentity
        let records: [AppRecord]
        let folder: PersistentFolderRecord?
    }

    private func app(_ key: String, fallback: Bool = false) -> Item {
        let variant = fallback ? "fallback" : "bundle"
        let url = URL(fileURLWithPath: "/SyntheticApps/MixedAnchor/\(variant)/\(key).app")
        let bundleID = fallback ? nil : "fixture.mixed.\(key)"
        let id = bundleID.map { AppID.bundleIdentifier($0) } ?? .canonicalURLFallback(url)
        let record = AppRecord(id: id, displayName: "Fixture \(key)", bundleIdentifier: bundleID,
                               canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0)
        return Item(entry: .app(.from(record: record)), identity: .app(id), records: [record], folder: nil)
    }

    private func folder(_ suffix: String) -> Item {
        let id = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(suffix)")!)
        let members = [app("member-\(suffix)-a"), app("member-\(suffix)-b")]
        let record = PersistentFolderRecord(id: id, title: "Fixture group", members: members.map {
            PersistentAppReference.from(record: $0.records[0])
        })
        return Item(entry: .folder(id), identity: .folder(id),
                    records: members.flatMap(\.records), folder: record)
    }

    private func layout(_ items: [Item]) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: LayoutGeneration(7), topLevelOrder: items.map(\.entry),
                                  folders: items.compactMap(\.folder))
    }

    private func catalog(_ items: [Item], revision: UInt64) -> CatalogSnapshot {
        CatalogSnapshot(revision: CatalogRevision(revision), records: items.flatMap(\.records))
    }

    private func provider(_ items: [Item]) throws -> AppGridUIPageContentProvider {
        let provider = AppGridUIPageContentProvider(snapshot: catalog(items, revision: 1))
        provider.itemsPerPage = capacity
        let saved = layout(items)
        XCTAssertNotNil(provider.applyCommittedLayout(saved, atCurrentPage: 0, itemsPerPage: capacity))
        assertState(provider, layout: saved, visible: items)
        return provider
    }

    private func assertState(_ provider: AppGridUIPageContentProvider,
                             layout saved: PersistentWorkspaceLayout, visible: [Item],
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(provider.expectedLayout, saved, file: file, line: line)
        XCTAssertEqual(provider.presentationEntries.map(\.identity), visible.map { Optional($0.identity) },
                       file: file, line: line)
        XCTAssertEqual(provider.canonicalPresentationEntries.map(\.identity),
                       visible.map { Optional($0.identity) }, file: file, line: line)
        let visibleApps = visible.filter { $0.folder == nil }.flatMap(\.records).map(\.id)
        XCTAssertEqual(provider.presentationRecords.map(\.id), visibleApps,
                       file: file, line: line)
        XCTAssertEqual(provider.servedPageCount, (visible.count + capacity - 1) / capacity,
                       file: file, line: line)
        for item in visible {
            if let folder = item.folder {
                XCTAssertEqual(provider.servedFolderSnapshot?.entry(for: folder.id)?.members,
                               item.records.map(\.id), file: file, line: line)
                XCTAssertGreaterThanOrEqual(item.records.count, 2, file: file, line: line)
            }
        }
    }

    @discardableResult
    private func remove(_ anchor: Item, leaving survivors: [Item], expecting outcome: AnchorOutcome,
                        file: StaticString = #filePath, line: UInt = #line) throws -> AppGridPresentationUpdate {
        let original = [anchor] + survivors
        let saved = layout(original)
        let provider = try provider(original)
        XCTAssertEqual(provider.topLevelAnchorCandidate(nearPage: 0, itemsPerPage: capacity), anchor.identity,
                       file: file, line: line)
        // Actually remove the app, or both folder members, from the catalog.
        // Merely omitting a layout reference would append the anchor as an unarranged app.
        provider.receive(catalog(survivors, revision: 2))
        assertState(provider, layout: saved, visible: original, file: file, line: line)
        let update = try XCTUnwrap(provider.applyPending(atCurrentPage: 0, itemsPerPage: capacity),
                                   file: file, line: line)
        XCTAssertEqual(update.topLevelAnchor, anchor.identity, file: file, line: line)
        XCTAssertEqual(update.outcome, outcome, file: file, line: line)
        XCTAssertNil(provider.topLevelPageIndex(of: anchor.identity, itemsPerPage: capacity),
                     file: file, line: line)
        XCTAssertEqual(update.plan.itemCount, survivors.count, file: file, line: line)
        XCTAssertEqual(update.plan.pageCount, (survivors.count + capacity - 1) / capacity,
                       file: file, line: line)
        XCTAssertEqual(update.previousRevision, 1, file: file, line: line)
        XCTAssertEqual(update.newRevision, 2, file: file, line: line)
        assertState(provider, layout: saved, visible: survivors, file: file, line: line)
        XCTAssertNil(provider.applyPending(atCurrentPage: 0, itemsPerPage: capacity), file: file, line: line)
        return update
    }

    func testMissingBundleAnchorUsesFirstGreaterInUnsortedComposition() throws {
        // Four lower identities precede the late successor. Semantic minimum "n"
        // is on page 3; current-composition first greater "z" is on page 2.
        try remove(app("m"), leaving: [app("d"), app("b"), app("a"), app("c"),
                                       app("z"), folder("80"), app("n")],
                   expecting: .successor(pageIndex: 2))
    }

    func testMissingPathAnchorUsesLexicalPathAndFirstGreater() throws {
        try remove(app("m", fallback: true),
                   leaving: [app("zzzz"), app("d", fallback: true), app("a", fallback: true),
                             app("b", fallback: true), app("z", fallback: true), folder("80"),
                             app("n", fallback: true)],
                   expecting: .successor(pageIndex: 2))
    }

    func testBundleVariantPrecedesCanonicalPathVariant() throws {
        // The fallback path begins with "a", yet every bundle-ID variant ranks below it.
        try remove(app("zzzz"), leaving: [app("d"), app("b"), app("a"), app("c"),
                                          app("a", fallback: true), folder("80"),
                                          app("z", fallback: true)],
                   expecting: .successor(pageIndex: 2))
    }

    func testMissingFolderUsesCanonicalUUIDAndFirstGreaterInComposition() throws {
        // Apps rank below every folder. F0 precedes the smaller successor A0 in
        // presentation, and their exact pages differ (3 versus 4).
        try remove(folder("80"),
                   leaving: [app("x"), folder("30"), folder("10"), app("y"),
                             folder("20"), folder("40"), folder("F0"), app("z"), folder("A0")],
                   expecting: .successor(pageIndex: 3))
    }

    func testMissingFolderUsesLastLowerRatherThanSemanticMaximum() throws {
        // 40 is the greatest surviving UUID, but 20 is the last lower entry.
        try remove(folder("FF"),
                   leaving: [folder("40"), app("a"), folder("10"), app("b"),
                             folder("30"), app("c"), folder("20")],
                   expecting: .predecessor(pageIndex: 3))
    }

    func testMissingAppUsesLateFolderSuccessorAfterAllLowerApps() throws {
        try remove(app("zzzz"), leaving: [app("d"), app("b"), app("a"), app("c"), folder("10")],
                   expecting: .successor(pageIndex: 2))
    }

    func testSurvivingAppAndFolderAnchorsLocateTheirDisplacedPages() throws {
        for anchor in [app("m"), folder("80")] {
            let others = [app("d"), folder("10"), app("a"), app("c")]
            let original = [anchor] + others
            let provider = try provider(original)
            let reordered = others + [anchor]
            let saved = layout(reordered)
            provider.receiveExpectedLayout(saved)
            provider.receive(catalog(original, revision: 2))
            let update = try XCTUnwrap(provider.applyPending(atCurrentPage: 0, itemsPerPage: capacity))
            XCTAssertEqual(update.topLevelAnchor, anchor.identity)
            XCTAssertEqual(update.outcome, .located(pageIndex: 2))
            XCTAssertEqual(update.plan.pageCount, 3)
            assertState(provider, layout: saved, visible: reordered)
        }
    }

    func testNilAnchorClampsMixedCompositionAndEmptyCompositionWins() throws {
        let items = [app("d"), folder("10"), app("a"), app("c"), folder("20")]
        let saved = layout(items)
        let fresh = AppGridUIPageContentProvider()
        fresh.itemsPerPage = capacity
        fresh.receiveExpectedLayout(saved)
        fresh.receive(catalog(items, revision: 1))
        let initial = try XCTUnwrap(fresh.applyPending(atCurrentPage: 0, itemsPerPage: capacity))
        XCTAssertNil(initial.topLevelAnchor)
        XCTAssertEqual(initial.outcome, .clamped(pageIndex: 0))
        XCTAssertEqual(initial.plan.pageCount, 3)
        assertState(fresh, layout: saved, visible: items)

        fresh.receive(catalog([], revision: 2))
        let empty = try XCTUnwrap(fresh.applyPending(atCurrentPage: 0, itemsPerPage: capacity))
        XCTAssertEqual(empty.topLevelAnchor, items[0].identity)
        XCTAssertEqual(empty.outcome, .emptyCatalog)
        XCTAssertEqual(empty.plan.pageCount, 0)
        assertState(fresh, layout: saved, visible: [])

        fresh.receive(catalog([], revision: 3))
        let stillEmpty = try XCTUnwrap(fresh.applyPending(atCurrentPage: 0, itemsPerPage: capacity))
        XCTAssertNil(stillEmpty.topLevelAnchor)
        XCTAssertEqual(stillEmpty.outcome, .emptyCatalog)
        XCTAssertEqual(stillEmpty.plan.itemCount, 0)
        assertState(fresh, layout: saved, visible: [])
    }

    func testAppOnlyRemovalExactlyDelegatesToCatalogPlanner() throws {
        let cases: [(Item, [Item], AnchorOutcome)] = [
            (app("m"), [app("d"), app("b"), app("a"), app("c"), app("z"), app("e"), app("n")],
             .successor(pageIndex: 2)),
            (app("zzzz"), [app("d"), app("b"), app("a"), app("c"), app("e"), app("f"), app("g")],
             .predecessor(pageIndex: 3))
        ]
        for (anchor, survivors, expected) in cases {
            let update = try remove(anchor, leaving: survivors, expecting: expected)
            let snapshot = catalog(survivors, revision: 2)
            let (plan, outcome) = CatalogPlanner().remap(snapshot: snapshot, anchor: anchor.records[0].id,
                                                       itemsPerPage: capacity)
            XCTAssertEqual(update.outcome, outcome)
            XCTAssertEqual(update.plan.snapshotRevision, plan.snapshotRevision)
            XCTAssertEqual(update.plan.itemsPerPage, plan.itemsPerPage)
            XCTAssertEqual(update.plan.itemCount, plan.itemCount)
            XCTAssertEqual(update.plan.pageCount, plan.pageCount)
            XCTAssertEqual(update.anchor, anchor.records[0].id)
        }
    }

    func testLastFolderRemovalDelegatesWithProjectedNilAppAnchor() throws {
        let survivors = [app("z"), app("b"), app("a"), app("c"), app("d")]
        let update = try remove(folder("80"), leaving: survivors, expecting: .clamped(pageIndex: 0))
        XCTAssertNil(update.anchor)
        let (plan, outcome) = CatalogPlanner().remap(snapshot: catalog(survivors, revision: 2), anchor: nil,
                                                   itemsPerPage: capacity)
        XCTAssertEqual(update.outcome, outcome)
        XCTAssertEqual(update.plan.snapshotRevision, plan.snapshotRevision)
        XCTAssertEqual(update.plan.itemsPerPage, plan.itemsPerPage)
        XCTAssertEqual(update.plan.itemCount, plan.itemCount)
        XCTAssertEqual(update.plan.pageCount, plan.pageCount)
    }
}
