import AppCatalogCore
import AppGridUI
import Foundation
import XCTest
@testable import MacAppCatalog
@testable import PagingPrototypeApp

/// Exercises repository/admission/idle-commit wiring using only synthetic temporary roots.
/// No AppDelegate, preferences, watcher, window, or production filesystem inputs.
@MainActor
final class AppSourcesCatalogIntegrationTests: XCTestCase {
    func testDelayedOldScanCannotCacheOrPublishAfterRootReplacement() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        let alpha = try fixture.makeApp("Alpha", in: fixture.fixed)
        let beta = try fixture.makeApp("Beta", in: fixture.custom)
        let scanner = SourcesCatalogIntegrationScanGate()
        let admission = SourcesCatalogIntegrationAdmissionFake()
        let assembly = AppCatalogAssembly(roots: [fixture.fixed, fixture.custom],
                                          scanning: scanner, loader: RecordingIconLoader())
        defer { assembly.teardown(); scanner.close(); admission.close() }
        replace(assembly, roots: [fixture.fixed, fixture.custom], fixture: fixture, admission: admission)
        assembly.begin()
        try await requireEventually { scanner.requests.count == 1 }
        scanner.finish(0, records: [alpha, beta])
        try await requireEventually { assembly.provider.hasPendingSnapshot }
        let firstCommit = try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        let served = try XCTUnwrap(assembly.provider.servedSnapshot)
        let scanDuration = assembly.dataSource.lastScanDurationMS
        let refreshDuration = assembly.dataSource.lastRefreshDurationMS
        var commits: [AppGridPresentationUpdate] = []
        assembly.searchPresentation.onPresentationUpdate = { commits.append($0) }

        assembly.refreshNow()
        try await requireEventually { scanner.requests.count == 2 }
        replace(assembly, roots: [fixture.fixed], fixture: fixture, admission: admission)
        XCTAssertNil(assembly.dataSource.currentSnapshot)
        XCTAssertEqual(assembly.provider.servedSnapshot, served)
        // No newer repository refresh exists yet: the data-source generation guard,
        // rather than repository latest-wins cancellation, must reject this success.
        XCTAssertFalse(scanner.requests[1].task.isCancelled)
        scanner.finish(1, records: [beta])
        try await requireEventually { assembly.refreshController.lastOutcome?.cancelled == true }
        XCTAssertEqual(assembly.refreshController.lastOutcome,
                       AppGridRefreshOutcome(succeeded: false, appCount: 0, failureCount: 0, cancelled: true))
        XCTAssertNil(assembly.dataSource.currentSnapshot)
        XCTAssertEqual(assembly.dataSource.lastScanDurationMS, scanDuration)
        XCTAssertEqual(assembly.dataSource.lastRefreshDurationMS, refreshDuration)
        XCTAssertNil(assembly.provider.pendingSnapshot)
        XCTAssertNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(assembly.provider.servedSnapshot, served)
        XCTAssertTrue(commits.isEmpty)

        assembly.refreshNow()
        try await requireEventually { scanner.requests.count == 3 }
        XCTAssertEqual(scanner.requests[2].roots, [fixture.fixed])
        scanner.finish(2, records: [alpha])
        try await requireEventually { assembly.provider.hasPendingSnapshot }
        XCTAssertEqual(assembly.provider.servedSnapshot, served)
        let replacement = try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertGreaterThan(replacement.newRevision, firstCommit.newRevision)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.map(\.id), [alpha.id])
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(scanner.pendingCount, 0)
    }

    func testReplacementDuringAdmissionSkipsObsoleteScanAndCancellationReleasesGate() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        let alpha = try fixture.makeApp("Alpha", in: fixture.fixed)
        _ = try fixture.makeApp("Beta", in: fixture.custom)
        let scanner = SourcesCatalogIntegrationScannerSpy()
        let admission = SourcesCatalogIntegrationAdmissionFake()
        let source = makeDataSource(scanner: scanner, roots: [fixture.fixed, fixture.custom])
        defer { admission.close() }
        source.replaceRoots([fixture.fixed, fixture.custom], fixedRoots: [fixture.fixed],
                            context: fixture.context, admission: admission)
        admission.hold(fixture.custom)
        let obsolete = Task { await source.refresh() }
        defer { obsolete.cancel() }
        try await waitForAdmissionGate(admission, source: source, request: obsolete)
        source.replaceRoots([fixture.fixed], fixedRoots: [fixture.fixed],
                            context: fixture.context, admission: admission)
        admission.release()
        let obsoleteOutcome = await obsolete.value
        XCTAssertEqual(obsoleteOutcome, .init(cancelled: true))
        XCTAssertTrue(scanner.requests.isEmpty)
        XCTAssertNil(source.currentSnapshot)

        source.replaceRoots([fixture.fixed, fixture.custom], fixedRoots: [fixture.fixed],
                            context: fixture.context, admission: admission)
        admission.hold(fixture.custom)
        let cancelled = Task { await source.refresh() }
        defer { cancelled.cancel() }
        try await waitForAdmissionGate(admission, source: source, request: cancelled)
        // Invalidate before cancelling: the production generation guard also blocks
        // a cancelled admission caller from starting a scan with only fixed roots.
        source.invalidateRequests()
        cancelled.cancel()
        let cancelledOutcome = await cancelled.value
        XCTAssertEqual(cancelledOutcome, .init(cancelled: true))
        XCTAssertEqual(admission.pendingCount, 0)
        XCTAssertTrue(scanner.requests.isEmpty)
        admission.release()

        source.replaceRoots([fixture.fixed], fixedRoots: [fixture.fixed],
                            context: fixture.context, admission: admission)
        let recovered = await source.refresh()
        XCTAssertTrue(recovered.succeeded)
        XCTAssertFalse(recovered.cancelled)
        XCTAssertEqual(source.currentSnapshot?.records.map(\.id), [alpha.id])
        XCTAssertEqual(scanner.requests.map(\.roots), [[fixture.fixed]])
    }

    func testEveryScanReadmitsCustomRootRejectsCanonicalChangesAndRecovers() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        let alpha = try fixture.makeApp("Alpha", in: fixture.fixed)
        let beta = try fixture.makeApp("Beta", in: fixture.custom)
        let substituted = try fixture.directory("Applications/Substituted")
        _ = try fixture.makeApp("Substitute", in: substituted)
        let scanner = SourcesCatalogIntegrationScannerSpy()
        let admission = SourcesCatalogIntegrationAdmissionFake()
        defer { admission.close() }
        let source = makeDataSource(scanner: scanner, roots: [fixture.fixed, fixture.custom])
        source.replaceRoots([fixture.fixed, fixture.custom], fixedRoots: [fixture.fixed],
                            context: fixture.context, admission: admission)

        let first = await source.refresh()
        XCTAssertTrue(first.succeeded)
        XCTAssertEqual(Set(source.currentSnapshot?.records.map(\.id) ?? []), [alpha.id, beta.id])
        admission.set(.rejected(.missing), for: fixture.custom)
        let missing = await source.refresh()
        XCTAssertTrue(missing.succeeded)
        XCTAssertEqual(source.currentSnapshot?.records.map(\.id), [alpha.id])
        admission.set(.accepted(substituted), for: fixture.custom)
        let changed = await source.refresh()
        XCTAssertTrue(changed.succeeded)
        XCTAssertEqual(source.currentSnapshot?.records.map(\.id), [alpha.id])
        admission.set(.alreadyCovered, for: fixture.custom)
        let covered = await source.refresh()
        XCTAssertTrue(covered.succeeded)
        XCTAssertEqual(source.currentSnapshot?.records.map(\.id), [alpha.id])
        admission.set(.accepted(fixture.custom), for: fixture.custom)
        let recovered = await source.refresh()
        XCTAssertTrue(recovered.succeeded)
        XCTAssertEqual(Set(source.currentSnapshot?.records.map(\.id) ?? []), [alpha.id, beta.id])
        XCTAssertEqual(scanner.requests.map(\.roots), [
            [fixture.fixed, fixture.custom], [fixture.fixed], [fixture.fixed],
            [fixture.fixed], [fixture.fixed, fixture.custom]
        ])
        XCTAssertEqual(admission.calls.map(\.root), (0..<5).flatMap { _ in [fixture.fixed, fixture.custom] })
        for call in admission.calls {
            XCTAssertEqual(call.context.requiresExactCanonicalPath, call.root == fixture.fixed)
        }
        for call in admission.calls {
            XCTAssertEqual(call.context.fixedRoots, [fixture.fixed])
            XCTAssertEqual(call.context.homeURL, fixture.context.homeURL)
            XCTAssertEqual(call.context.allowedSyntheticRoot, fixture.context.allowedSyntheticRoot)
        }
        XCTAssertEqual(scanner.requests.map(\.revision.value), [1, 2, 3, 4, 5])
    }

    func testReplaceScanRootsDiscardsAllPendingDiscoveryPresentationAndKeepsServedQuery() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        _ = try fixture.makeApp("Alpha", in: fixture.fixed)
        let scanner = SourcesCatalogIntegrationScannerSpy()
        let admission = SourcesCatalogIntegrationAdmissionFake()
        let assembly = AppCatalogAssembly(roots: [fixture.fixed], scanning: scanner, loader: RecordingIconLoader())
        defer { assembly.teardown(); admission.close() }
        replace(assembly, roots: [fixture.fixed], fixture: fixture, admission: admission)
        _ = try await refreshAndCommit(assembly)
        assembly.searchPresentation.updateQuery(.init(raw: "Alpha"))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let served = assembly.provider.servedSnapshot
        let entries = assembly.provider.presentationEntries
        _ = try fixture.makeApp("Beta", in: fixture.custom)
        replace(assembly, roots: [fixture.fixed, fixture.custom], fixture: fixture, admission: admission)
        try await refreshAndStage(assembly)
        let pending = try XCTUnwrap(assembly.provider.pendingSnapshot)
        assembly.provider.receiveFolderSnapshot(.init(generation: .zero, entries: [
            FolderEntry(id: FolderID(), title: "Pending group", members: pending.records.map(\.id))
        ]))
        assembly.searchPresentation.updateQuery(.init(raw: "Alpha"))
        XCTAssertNotNil(assembly.provider.pendingSnapshot)
        XCTAssertNotNil(assembly.provider.pendingFolderSnapshot)
        XCTAssertNotNil(assembly.provider.pendingSearchResult)

        replace(assembly, roots: [fixture.fixed], fixture: fixture, admission: admission)
        XCTAssertEqual(assembly.scanRoots, [fixture.fixed])
        XCTAssertNil(assembly.dataSource.currentSnapshot)
        XCTAssertNil(assembly.provider.pendingSnapshot)
        XCTAssertNil(assembly.provider.pendingFolderSnapshot)
        XCTAssertNil(assembly.provider.pendingSearchResult)
        XCTAssertEqual(assembly.provider.servedSnapshot, served)
        XCTAssertEqual(assembly.provider.presentationEntries, entries)
        XCTAssertEqual(assembly.provider.activeQuery?.raw, "Alpha")
        XCTAssertEqual(assembly.searchPresentation.currentQuery?.raw, "Alpha")
        XCTAssertNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(assembly.provider.servedSnapshot, served)
    }

    func testTeardownWithQueuedFollowupCannotStartAnotherScanOrPublish() async throws {
        let fixture = try SourcesCatalogIntegrationFixture(); defer { fixture.remove() }
        let alpha = try fixture.makeApp("Alpha", in: fixture.fixed)
        let scanner = SourcesCatalogIntegrationScanGate()
        let assembly = AppCatalogAssembly(roots: [fixture.fixed], scanning: scanner, loader: RecordingIconLoader())
        defer { assembly.teardown(); scanner.close() }
        var callbacks = 0
        assembly.onPresentationUpdate = { _ in callbacks += 1 }
        assembly.begin()
        try await requireEventually { scanner.requests.count == 1 }
        assembly.refreshNow() // In-flight refresh retains a latest-wins follow-up.
        assembly.teardown()
        scanner.finish(0, records: [alpha]) // Deliberately successful stale completion.
        for _ in 0..<1000 { await Task.yield() }
        XCTAssertEqual(scanner.requests.count, 1)
        XCTAssertNil(assembly.dataSource.currentSnapshot)
        XCTAssertNil(assembly.provider.pendingSnapshot); XCTAssertEqual(callbacks, 0)
        let stopped = await assembly.dataSource.refresh()
        XCTAssertTrue(stopped.cancelled); XCTAssertFalse(stopped.succeeded)
        XCTAssertEqual(scanner.requests.count, 1)
    }

    func testAlreadyDeliveredRefreshTaskAfterTeardownCannotReopenDataSource() async throws {
        let fixture = try SourcesCatalogIntegrationFixture(); defer { fixture.remove() }
        let scanner = SourcesCatalogIntegrationScanGate()
        let assembly = AppCatalogAssembly(roots: [fixture.fixed], scanning: scanner, loader: RecordingIconLoader())
        defer { assembly.teardown(); scanner.close() }
        assembly.teardown()
        // Same public controller entry used by an already-converted debounce Main task.
        assembly.refreshController.refreshNow()
        for _ in 0..<1000 { await Task.yield() }
        XCTAssertEqual(scanner.requests.count, 0)
        XCTAssertNil(assembly.dataSource.currentSnapshot); XCTAssertNil(assembly.provider.pendingSnapshot)
        let admission = SourcesCatalogIntegrationAdmissionFake()
        defer { admission.close() }
        // Replacement cannot undo the permanent close, either.
        assembly.dataSource.replaceRoots([fixture.custom], fixedRoots: [fixture.fixed],
            context: .init(homeURL: fixture.root.appendingPathComponent("Home"), fixedRoots: [fixture.fixed]), admission: admission)
        let stopped = await assembly.dataSource.refresh()
        XCTAssertTrue(stopped.cancelled); XCTAssertEqual(scanner.requests.count, 0)
    }

    func testUncommittedLatestQuerySurvivesSourceSwitchWithoutSuccessfulNewCatalog() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        _ = try fixture.makeApp("Alpha", in: fixture.fixed)
        let assembly = AppCatalogAssembly(roots: [fixture.fixed], scanning: SourcesCatalogIntegrationScannerSpy(),
                                          loader: RecordingIconLoader())
        let admission = SourcesCatalogIntegrationAdmissionFake()
        defer { assembly.teardown(); admission.close() }
        replace(assembly, roots: [fixture.fixed], fixture: fixture, admission: admission)
        _ = try await refreshAndCommit(assembly)
        assembly.searchPresentation.updateQuery(.init(raw: "Alpha"))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let served = assembly.provider.servedSnapshot
        assembly.searchPresentation.updateQuery(.init(raw: "Beta")) // Not committed yet.
        replace(assembly, roots: [fixture.fixed, fixture.custom], fixture: fixture, admission: admission)
        XCTAssertEqual(assembly.provider.pendingSearchResult?.baseCatalogRevision, served?.revision)
        XCTAssertEqual(assembly.provider.activeQuery?.raw, "Alpha")
        XCTAssertNil(assembly.dataSource.currentSnapshot)
        // No fresh successful catalog is required to retain the user's latest query.
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(assembly.provider.activeQuery?.raw, "Beta")
        XCTAssertEqual(assembly.provider.presentationRecords.count, 0)
        XCTAssertEqual(assembly.provider.servedSnapshot, served)
    }

    func testSourceRemovalAndReadditionPreserveLayoutHiddenAliasesAndActiveQueryAtIdleCommit() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        let alpha = try fixture.makeApp("Alpha", in: fixture.fixed)
        let beta = try fixture.makeApp("Beta", in: fixture.custom)
        let hidden = try fixture.makeApp("Hidden", in: fixture.custom)
        let scanner = SourcesCatalogIntegrationScannerSpy()
        let admission = SourcesCatalogIntegrationAdmissionFake()
        let assembly = AppCatalogAssembly(roots: [fixture.fixed, fixture.custom],
                                          scanning: scanner, loader: RecordingIconLoader())
        defer { assembly.teardown(); admission.close() }
        replace(assembly, roots: [fixture.fixed, fixture.custom], fixture: fixture, admission: admission)
        _ = try await refreshAndCommit(assembly)
        let folderID = FolderID()
        let layout = PersistentWorkspaceLayout(generation: LayoutGeneration(9),
            topLevelOrder: [.app(.from(record: beta)), .folder(folderID)], folders: [
                PersistentFolderRecord(id: folderID, title: "Saved group",
                                       members: [.from(record: hidden), .from(record: alpha)])
            ])
        let preferences = try XCTUnwrap(AppManagementPreferences.default
            .settingHidden(true, for: hidden).settingAlias("Shortcut", for: beta))
        assembly.provider.receiveExpectedLayout(layout)
        assembly.provider.receiveManagementPreferences(preferences)
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let canonicalEntries = assembly.provider.canonicalPresentationEntries
        assembly.searchPresentation.updateQuery(.init(raw: "Shortcut"))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.id), [beta.id])
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.displayName), ["Shortcut"])
        let initial = try XCTUnwrap(assembly.provider.servedSnapshot)

        replace(assembly, roots: [fixture.fixed], fixture: fixture, admission: admission)
        XCTAssertNil(assembly.dataSource.currentSnapshot)
        XCTAssertEqual(assembly.provider.servedSnapshot, initial)
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.id), [beta.id])
        try await refreshAndStage(assembly)
        XCTAssertEqual(assembly.provider.servedSnapshot, initial)
        let removal = try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertGreaterThan(removal.newRevision, initial.revision.value)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.map(\.id), [alpha.id])
        XCTAssertTrue(assembly.provider.presentationRecords.isEmpty)
        XCTAssertEqual(assembly.provider.expectedLayout, layout)
        XCTAssertEqual(assembly.provider.managementPreferences, preferences)
        XCTAssertEqual(assembly.provider.activeQuery?.raw, "Shortcut")
        XCTAssertEqual(assembly.searchPresentation.currentQuery?.raw, "Shortcut")
        XCTAssertTrue(FileManager.default.fileExists(atPath: beta.canonicalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: hidden.canonicalURL.path))

        replace(assembly, roots: [fixture.fixed, fixture.custom], fixture: fixture, admission: admission)
        try await refreshAndStage(assembly)
        XCTAssertEqual(assembly.provider.servedRevision, removal.newRevision)
        XCTAssertTrue(assembly.provider.presentationRecords.isEmpty)
        let readdition = try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertGreaterThan(readdition.newRevision, removal.newRevision)
        XCTAssertEqual(assembly.provider.expectedLayout, layout)
        XCTAssertEqual(assembly.provider.canonicalPresentationEntries, canonicalEntries)
        XCTAssertEqual(assembly.provider.managementPreferences, preferences)
        XCTAssertTrue(assembly.provider.isHidden(hidden.id))
        XCTAssertEqual(assembly.provider.activeQuery?.raw, "Shortcut")
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.id), [beta.id])
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.displayName), ["Shortcut"])
        XCTAssertEqual(assembly.bundleURL(for: beta.id), beta.canonicalURL)
        assembly.searchPresentation.clearQuery()
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.id), [beta.id])
        XCTAssertEqual(assembly.provider.presentationEntries.map(\.identity), [.app(beta.id), .folder(folderID)])
        XCTAssertEqual(assembly.provider.servedFolderSnapshot?.entry(for: folderID)?.members, [alpha.id])
        XCTAssertEqual(assembly.provider.expectedLayout?.folders, layout.folders)
    }

    func testNestedInstallAndRemovalScanStopsAtBundlesAndSkipsDirectorySymlinks() async throws {
        let fixture = try SourcesCatalogIntegrationFixture()
        defer { fixture.remove() }
        let nested = try fixture.directory("Applications/Custom/Vendor/Tools")
        let outer = try fixture.makeApp("Outer", in: nested)
        let helpers = outer.canonicalURL.appendingPathComponent("Contents/Helpers", isDirectory: true)
        _ = try fixture.makeApp("Embedded", in: helpers)
        let unselected = try fixture.directory("Unselected")
        let linked = try fixture.makeApp("Linked", in: unselected)
        try FileManager.default.createSymbolicLink(at: fixture.custom.appendingPathComponent("LinkedDirectory"),
                                                  withDestinationURL: unselected)
        try FileManager.default.createSymbolicLink(at: fixture.custom.appendingPathComponent("LinkedBundle.app"),
                                                  withDestinationURL: linked.canonicalURL)
        let scanner = SourcesCatalogIntegrationScannerSpy()
        let admission = SourcesCatalogIntegrationAdmissionFake()
        let assembly = AppCatalogAssembly(roots: [fixture.fixed, fixture.custom],
                                          scanning: scanner, loader: RecordingIconLoader())
        defer { assembly.teardown(); admission.close() }
        replace(assembly, roots: [fixture.fixed, fixture.custom], fixture: fixture, admission: admission)
        let initial = try await refreshAndCommit(assembly)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.map(\.id), [outer.id])

        let installed = try fixture.makeApp("Installed", in: nested)
        try await refreshAndStage(assembly)
        XCTAssertEqual(assembly.provider.servedRevision, initial.newRevision)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.map(\.id), [outer.id])
        let installation = try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(Set(assembly.provider.servedSnapshot?.records.map(\.id) ?? []), [outer.id, installed.id])
        try FileManager.default.removeItem(at: installed.canonicalURL)
        try await refreshAndStage(assembly)
        XCTAssertEqual(assembly.provider.servedRevision, installation.newRevision)
        XCTAssertTrue(assembly.provider.servedSnapshot?.records.contains(where: { $0.id == installed.id }) == true)
        let removal = try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertGreaterThan(removal.newRevision, installation.newRevision)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.map(\.id), [outer.id])
        XCTAssertEqual(admission.calls.count, 6) // Fixed profile + custom revalidation for each scan.
        XCTAssertEqual(scanner.requests.count, 3)
        for request in scanner.requests {
            XCTAssertEqual(request.roots, [fixture.fixed, fixture.custom])
            XCTAssertTrue(request.stopAtAppBundle)
            XCTAssertFalse(request.followDirectorySymlinks)
        }
    }

    private func replace(_ assembly: AppCatalogAssembly, roots: [URL],
                         fixture: SourcesCatalogIntegrationFixture,
                         admission: SourcesCatalogIntegrationAdmissionFake) {
        assembly.replaceScanRoots(roots, fixedRoots: [fixture.fixed], context: fixture.context, admission: admission)
    }

    private func makeDataSource(scanner: any CatalogScanning, roots: [URL]) -> CatalogRepositoryDataSource {
        CatalogRepositoryDataSource(repository: CatalogRepository(policy: .init(), scanning: scanner),
                                    configuration: ScanConfiguration(roots: roots))
    }

    private func refreshAndStage(_ assembly: AppCatalogAssembly) async throws {
        XCTAssertNil(assembly.provider.pendingSnapshot, "Each request starts after the previous idle commit")
        assembly.refreshNow()
        try await requireEventually { assembly.provider.hasPendingSnapshot }
        XCTAssertTrue(assembly.refreshController.lastOutcome?.succeeded == true)
        XCTAssertFalse(assembly.refreshController.lastOutcome?.cancelled ?? true)
    }

    private func refreshAndCommit(_ assembly: AppCatalogAssembly) async throws -> AppGridPresentationUpdate {
        try await refreshAndStage(assembly)
        return try XCTUnwrap(assembly.commitPendingAtIdleBoundary(currentPage: 0))
    }

    private func waitForAdmissionGate(_ admission: SourcesCatalogIntegrationAdmissionFake,
                                      source: CatalogRepositoryDataSource,
                                      request: Task<AppGridRefreshOutcome, Never>) async throws {
        do {
            try await requireEventually { admission.pendingCount == 1 }
        } catch {
            source.invalidateRequests()
            request.cancel()
            admission.close()
            _ = await request.value
            throw error
        }
    }

    private func requireEventually(_ condition: @escaping () -> Bool,
                                   file: StaticString = #filePath, line: UInt = #line) async throws {
        guard await waitUntil(condition, timeout: 3, file: file, line: line) else {
            throw SourcesCatalogIntegrationWaitError.timedOut
        }
    }
}

private enum SourcesCatalogIntegrationWaitError: Error { case timedOut }

/// Matches FakeAppFactory's tiny Info.plist convention, with nested synthetic source roots.
private final class SourcesCatalogIntegrationFixture {
    private let factory: FakeAppFactory
    let root: URL
    let fixed: URL
    let custom: URL
    var context: AppSourceRootAdmissionContext {
        .init(homeURL: root.appendingPathComponent("Home", isDirectory: true), fixedRoots: [fixed],
              allowedSyntheticRoot: root.appendingPathComponent("Applications", isDirectory: true))
    }

    init() throws {
        factory = try FakeAppFactory(prefix: "paging-sources-catalog-integration")
        root = factory.root.resolvingSymlinksInPath().standardizedFileURL
        fixed = root.appendingPathComponent("Applications/Fixed", isDirectory: true)
        custom = root.appendingPathComponent("Applications/Custom", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: fixed, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
        } catch {
            factory.removeRoot()
            throw error
        }
    }

    func directory(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func makeApp(_ name: String, in directory: URL) throws -> AppRecord {
        let url = directory.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let bundleID = "fixture.sources.integration.\(name.lowercased())"
        let data = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": bundleID, "CFBundleName": name, "CFBundlePackageType": "APPL"
        ], format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        let id = AppID.bundleIdentifier(bundleID)
        return AppRecord(id: id, displayName: name, bundleIdentifier: bundleID, canonicalURL: url,
                         iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }

    func remove() { factory.removeRoot() }
}

private struct SourcesCatalogIntegrationScanRequest {
    let roots: [URL]
    let revision: CatalogRevision
    let stopAtAppBundle: Bool
    let followDirectorySymlinks: Bool
    let task: ScanTask
}

private final class SourcesCatalogIntegrationScannerSpy: CatalogScanning, @unchecked Sendable {
    private let lock = NSLock()
    private let scanner = CatalogScanner()
    private var recorded: [SourcesCatalogIntegrationScanRequest] = []
    var requests: [SourcesCatalogIntegrationScanRequest] {
        lock.lock(); defer { lock.unlock() }; return recorded
    }
    func scan(configuration: ScanConfiguration, revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        let task = scanner.scan(configuration: configuration, revision: revision, completion: completion)
        lock.lock()
        recorded.append(.init(roots: configuration.roots, revision: revision,
                              stopAtAppBundle: configuration.stopAtAppBundle,
                              followDirectorySymlinks: configuration.followDirectorySymlinks, task: task))
        lock.unlock()
        return task
    }
}

/// Deliberately allows late successful callbacks, even if a consumer cancelled a task.
/// close() completes every held callback exactly once and also handles late registrations.
private final class SourcesCatalogIntegrationScanGate: CatalogScanning, @unchecked Sendable {
    private struct Pending {
        let revision: CatalogRevision
        let task: ScanTask
        let completion: @Sendable (CatalogScanResult) -> Void
    }
    private let lock = NSLock()
    private var recorded: [SourcesCatalogIntegrationScanRequest] = []
    private var pending: [Int: Pending] = [:]
    private var closed = false
    var requests: [SourcesCatalogIntegrationScanRequest] {
        lock.lock(); defer { lock.unlock() }; return recorded
    }
    var pendingCount: Int { lock.lock(); defer { lock.unlock() }; return pending.count }

    func scan(configuration: ScanConfiguration, revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        let task = ScanTask()
        lock.lock()
        let index = recorded.count
        recorded.append(.init(roots: configuration.roots, revision: revision,
                              stopAtAppBundle: configuration.stopAtAppBundle,
                              followDirectorySymlinks: configuration.followDirectorySymlinks, task: task))
        let isClosed = closed
        if !isClosed { pending[index] = Pending(revision: revision, task: task, completion: completion) }
        lock.unlock()
        if isClosed {
            task.cancel()
            completion(Self.cancelledResult)
        }
        return task
    }

    func finish(_ index: Int, records: [AppRecord]) {
        lock.lock()
        let entry = pending.removeValue(forKey: index)
        lock.unlock()
        guard let entry else { return }
        entry.completion(.init(snapshot: CatalogSnapshot(revision: entry.revision, records: records),
                               report: .init(appCount: records.count, failureCounts: [:], scanDuration: 0.125),
                               cancelled: false))
    }

    func close() {
        lock.lock()
        closed = true
        let entries = Array(pending.values)
        pending.removeAll()
        lock.unlock()
        for entry in entries { entry.task.cancel(); entry.completion(Self.cancelledResult) }
    }

    private static var cancelledResult: CatalogScanResult {
        .init(snapshot: nil, report: .init(appCount: 0, failureCounts: [:], scanDuration: 0), cancelled: true)
    }
}

/// File-private name avoids colliding with other concurrently added source-test fakes.
/// Locking covers cancellation before registration, release, and teardown races.
private final class SourcesCatalogIntegrationAdmissionFake: AppSourceRootAdmitting, @unchecked Sendable {
    struct Call { let root: URL; let context: AppSourceRootAdmissionContext }
    private struct Pending {
        let result: AppSourceRootAdmissionResult
        let continuation: CheckedContinuation<AppSourceRootAdmissionResult, Never>
    }
    private let lock = NSLock()
    private var recorded: [Call] = []
    private var decisions: [URL: AppSourceRootAdmissionResult] = [:]
    private var held: Set<URL> = []
    private var pending: [UUID: Pending] = [:]
    private var cancelled: Set<UUID> = []
    private var closed = false
    var calls: [Call] { lock.lock(); defer { lock.unlock() }; return recorded }
    var pendingCount: Int { lock.lock(); defer { lock.unlock() }; return pending.count }

    func set(_ result: AppSourceRootAdmissionResult, for root: URL) {
        lock.lock(); defer { lock.unlock() }; decisions[root] = result
    }
    func hold(_ root: URL) { lock.lock(); defer { lock.unlock() }; held.insert(root) }

    func admit(_ candidate: URL, context: AppSourceRootAdmissionContext) async -> AppSourceRootAdmissionResult {
        let id = UUID()
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                register(id, candidate: candidate, context: context, continuation: continuation)
            }
        }, onCancel: { self.cancel(id) })
    }

    private func register(_ id: UUID, candidate: URL, context: AppSourceRootAdmissionContext,
                          continuation: CheckedContinuation<AppSourceRootAdmissionResult, Never>) {
        lock.lock()
        recorded.append(Call(root: candidate, context: context))
        let result = decisions[candidate] ?? .accepted(candidate)
        if closed || cancelled.remove(id) != nil {
            lock.unlock()
            continuation.resume(returning: .rejected(.metadataUnavailable))
        } else if held.contains(candidate) {
            pending[id] = Pending(result: result, continuation: continuation)
            lock.unlock()
        } else {
            lock.unlock()
            continuation.resume(returning: result)
        }
    }

    private func cancel(_ id: UUID) {
        lock.lock()
        let entry = pending.removeValue(forKey: id)
        if entry == nil { cancelled.insert(id) }
        lock.unlock()
        entry?.continuation.resume(returning: .rejected(.metadataUnavailable))
    }

    func release() { drain(closing: false) }
    func close() { drain(closing: true) }
    private func drain(closing: Bool) {
        lock.lock()
        if closing { closed = true }
        held.removeAll()
        let entries = Array(pending.values)
        pending.removeAll()
        lock.unlock()
        for entry in entries {
            entry.continuation.resume(returning: closing ? .rejected(.metadataUnavailable) : entry.result)
        }
    }
}
