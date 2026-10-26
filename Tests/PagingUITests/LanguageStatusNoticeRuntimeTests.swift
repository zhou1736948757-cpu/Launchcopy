import AppKit
import AppCatalogCore
import LauncherLocalization
import XCTest
@testable import AppGridUI
@testable import PagingUI
@testable import PagingPrototypeApp

@MainActor
private final class StatusNoticeLanguageStore: LanguagePreferencesPersisting {
    var preferences = LanguagePreferences(language: .english)
    func load() -> LanguagePreferencesLoadResult { .loaded(preferences) }
    func save(_ value: LanguagePreferences) -> LanguagePreferencesSaveResult { preferences = value; return .saved }
}

private actor StatusNoticeCapacityStore: MainGridCapacityPersisting {
    private var capacity = MainGridCapacity.default
    func load() -> MainGridCapacityLoadResult { .loaded(capacity) }
    func save(_ capacity: MainGridCapacity, recoveringCorruptPayload: Bool) -> MainGridCapacitySaveResult {
        self.capacity = capacity
        return .saved
    }
}

@MainActor
final class LanguageStatusNoticeRuntimeTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = AppDelegate(options: .default)
        let store = StatusNoticeLanguageStore()
        let center = NotificationCenter()
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticStatus")], loader: RecordingIconLoader())
        init() {
            _ = NSApplication.shared
            host.surface = surface; host.container = root; host.assembly = assembly
            root.addSubview(surface); surface.frame = root.bounds
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            host.installLanguagePreferences(store: store, preferredLanguages: { ["en"] }, center: center)
            host.installCatalogPresentationCallbacks(assembly: assembly, surface: surface)
            host.installCatalogStatus(in: root)
        }
        func records(_ count: Int) -> [AppRecord] {
            (0..<count).map { number in
                let id = CatalogFixture.appID("fixture.status.\(number)")
                return CatalogFixture.record(id: id, displayName: "Synthetic \(number)", bundleID: "fixture.status.\(number)",
                    url: CatalogFixture.tempURL(named: "Status\(number).app"), icon: .from(appID: id), rootPriority: 0)
            }
        }
        func receive(_ records: [AppRecord], revision: UInt64) {
            assembly.provider.receive(.init(revision: CatalogRevision(revision), records: records))
            host.applyPendingAtIdleBoundary()
        }
        func teardown() {
            host.mainGridCapacityCoordinator?.invalidate()
            host.teardownCatalogStatus(); host.teardownLanguagePresentation()
            surface.teardown(); assembly.teardown()
        }
    }
    private func drain() async {
        for _ in 0..<10 { await drainDeferredPresentationTurns() }
    }

    func testActualMountedStatusShowsLoadingEmptyAndNoResultsAndHidesReady() async throws {
        let f = Fixture(); defer { f.teardown() }
        let status = try XCTUnwrap(f.host.catalogStatusView)
        XCTAssertTrue(status.superview === f.root)
        await drain()
        XCTAssertEqual(status.state, .loading)
        XCTAssertFalse(status.isHidden)
        f.receive([], revision: 1); await drain()
        XCTAssertEqual(status.state, .empty)
        f.receive(f.records(2), revision: 2); await drain()
        XCTAssertEqual(status.state, .ready); XCTAssertTrue(status.isHidden)
        f.assembly.searchPresentation.updateQuery(AppSearchQuery(raw: "no synthetic match"))
        f.host.applyPendingAtIdleBoundary(); await drain()
        XCTAssertEqual(status.state, .noResults); XCTAssertFalse(status.isHidden)
        XCTAssertEqual(status.statusText, LocalizedStrings(language: .english).catalogText(.noResults))
        XCTAssertNil(status.hitTest(NSPoint(x: 5, y: 5)))
    }

    func testOnlyCommittedQueryDeterminesStatusUntilActualIdleCommit() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.receive(f.records(105), revision: 1); await drain()
        f.assembly.searchPresentation.updateQuery(AppSearchQuery(raw: "no match"))
        f.host.applyPendingAtIdleBoundary(); await drain()
        XCTAssertEqual(f.host.displayedCatalogStatus, .noResults)
        f.assembly.searchPresentation.clearQuery()
        XCTAssertEqual(f.host.displayedCatalogStatus, .noResults, "Pending clear cannot relabel the served empty search as ready")
        f.host.applyPendingAtIdleBoundary(); await drain()
        XCTAssertEqual(f.host.displayedCatalogStatus, .ready)
    }

    func testActualTerminalFrameCatalogCommitDoesNotRenderStatusTextUntilQueue() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.receive(f.records(105), revision: 1); await drain()
        let status = try XCTUnwrap(f.host.catalogStatusView)
        gestureBegan(f.surface, at: 0); gestureChanged(f.surface, deltaX: 400, at: 0.5)
        gestureEnded(f.surface, at: 0.5); finishPendingGesture(f.surface, at: 0.5)
        XCTAssertTrue(f.surface.core.isAnimating)
        f.assembly.provider.receive(.init(revision: CatalogRevision(2), records: []))
        let renders = status.languageFormattingCount
        for _ in 0..<120 where f.surface.core.isAnimating {
            f.surface.advanceFrame(deltaTime: 1.0 / 60.0)
            XCTAssertEqual(status.languageFormattingCount, renders)
        }
        XCTAssertEqual(f.assembly.provider.servedRevision, 2)
        await drain()
        XCTAssertGreaterThan(status.languageFormattingCount, renders)
        XCTAssertEqual(status.state, .empty)
    }

    func testSameStateLocalePresentationKeepsQueryRevisionPageIconsAndStatusInstance() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.receive(f.records(2), revision: 1)
        f.assembly.searchPresentation.updateQuery(AppSearchQuery(raw: "no match")); f.host.applyPendingAtIdleBoundary(); await drain()
        let status = try XCTUnwrap(f.host.catalogStatusView), revision = f.assembly.provider.servedRevision
        let query = f.assembly.provider.activeQuery, page = f.surface.core.committedPage
        let requests = f.assembly.iconPipeline.stats.requests
        XCTAssertEqual(f.host.languageSettingsCoordinator?.apply(.init(language: .japanese)), .saved)
        await drain()
        XCTAssertTrue(status === f.host.catalogStatusView)
        XCTAssertEqual(status.state, .noResults)
        XCTAssertEqual(status.statusText, LocalizedStrings(language: .japanese).catalogText(.noResults))
        XCTAssertEqual(f.assembly.provider.activeQuery, query); XCTAssertEqual(f.assembly.provider.servedRevision, revision)
        XCTAssertEqual(f.surface.core.committedPage, page); XCTAssertEqual(f.assembly.iconPipeline.stats.requests, requests)
    }

    func testStatusReplacementAndTeardownCancelOldQueuedRendering() async throws {
        let f = Fixture(); defer { f.teardown() }
        let old = try XCTUnwrap(f.host.catalogStatusView)
        f.host.installCatalogStatus(in: f.root)
        await drain()
        XCTAssertNil(old.superview); XCTAssertEqual(old.languageFormattingCount, 0)
        let current = try XCTUnwrap(f.host.catalogStatusView), count = current.languageFormattingCount
        f.host.scheduleCatalogStatusRefresh(); f.host.teardownCatalogStatus(); await drain()
        XCTAssertEqual(current.languageFormattingCount, count); XCTAssertNil(current.superview)
    }

    func testAllRefreshPolicyStatesStaySemanticAndDoNotDependOnPendingInput() {
        for refresh in [AppGridUIState.loading, .ready, .empty, .noResults] {
            XCTAssertEqual(CatalogStatusPresentation.resolve(refresh: refresh, hasSnapshot: false, hasVisibleApps: false,
                hasCommittedQuery: false, committedResultIsEmpty: true), .loading)
            XCTAssertEqual(CatalogStatusPresentation.resolve(refresh: refresh, hasSnapshot: true, hasVisibleApps: false,
                hasCommittedQuery: true, committedResultIsEmpty: true), .empty)
            XCTAssertEqual(CatalogStatusPresentation.resolve(refresh: refresh, hasSnapshot: true, hasVisibleApps: true,
                hasCommittedQuery: true, committedResultIsEmpty: true), .noResults)
            XCTAssertEqual(CatalogStatusPresentation.resolve(refresh: refresh, hasSnapshot: true, hasVisibleApps: true,
                hasCommittedQuery: false, committedResultIsEmpty: true), .ready)
        }
        for refresh in [AppGridUIState.refreshing, .partialFailure] {
            XCTAssertEqual(CatalogStatusPresentation.resolve(refresh: refresh, hasSnapshot: false, hasVisibleApps: false,
                hasCommittedQuery: false, committedResultIsEmpty: true), refresh)
        }
    }

    func testNativeAliasAndErrorBuildersUseAllLanguagesAndKeepDraftLiteral() throws {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language), data = "Literal {count} %s 日本語"
            let (alias, field) = LauncherNoticePresentation.aliasEditor(strings: strings, alias: data)
            XCTAssertEqual(field.stringValue, data); XCTAssertTrue(alias.accessoryView === field)
            XCTAssertEqual(alias.messageText, strings.noticeText(.aliasEditorTitle))
            XCTAssertEqual(alias.buttons.map(\.title), [strings.noticeText(.save), strings.text(.cancel)])
            let assignment = try XCTUnwrap(LauncherNoticePresentation.assignmentError(.cancelled, strings: strings))
            XCTAssertEqual(assignment.informativeText, strings.noticeText(.organizationErrorHelp))
            for result in [AppManagementSaveResult.invalidPreferences, .futureVersion(2), .failed] {
                let alert = try XCTUnwrap(LauncherNoticePresentation.managementError(result, strings: strings))
                XCTAssertEqual(alert.messageText, strings.noticeText(.managementErrorTitle))
                XCTAssertEqual(alert.buttons.first?.title, strings.noticeText(.okay))
            }
            XCTAssertNil(LauncherNoticePresentation.managementError(.saved, strings: strings))
        }
    }

    func testQuitBuilderKeepsCancelDefaultAndExplicitQuitAnywayInAllLanguages() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let alert = AppDelegate.makeQuitSaveFailureAlert(strings: strings)
            XCTAssertEqual(alert.messageText, strings.noticeText(.quitSaveTitle))
            XCTAssertEqual(alert.buttons.map(\.title), [strings.noticeText(.cancelQuit), strings.noticeText(.quitAnyway)])
            XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
            XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
        }
    }

    func testRetainedWorkspaceNoticeRerendersTypedOutcomeWithoutRevivingHiddenSuccess() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.host.handleWorkspacePersistenceOutcome(.readOnly)
        let notice = try XCTUnwrap(f.host.workspaceSaveNotice)
        XCTAssertEqual(notice.stringValue, LocalizedStrings(language: .english).noticeText(.workspaceProtectedMessage))
        XCTAssertEqual(f.host.languageSettingsCoordinator?.apply(.init(language: .japanese)), .saved); await drain()
        XCTAssertTrue(notice === f.host.workspaceSaveNotice)
        XCTAssertFalse(notice.isHidden)
        XCTAssertEqual(notice.stringValue, LocalizedStrings(language: .japanese).noticeText(.workspaceProtectedMessage))
        f.host.handleWorkspacePersistenceOutcome(.persisted(writeGeneration: 1))
        XCTAssertTrue(notice.isHidden)
        XCTAssertEqual(f.host.languageSettingsCoordinator?.apply(.init(language: .simplifiedChinese)), .saved); await drain()
        XCTAssertTrue(notice.isHidden)
        XCTAssertEqual(f.host.lastWorkspacePersistenceOutcome, .persisted(writeGeneration: 1))
    }

    func testRealSheetRoutingLeaseQueuesLanguageUntilAllCompletionsAndIgnoresDuplicate() async throws {
        let f = Fixture(); defer { f.teardown() }
        let window = NSWindow(contentRect: f.root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        f.host.window = window
        var callbacks: [(NSApplication.ModalResponse) -> Void] = [], applied = 0
        f.host.applicationSheetPresenter = { _, _, finish in callbacks.append(finish) }
        f.host.presentApplicationSheet(NSAlert(), for: window) { _ in applied += 1 }
        f.host.presentApplicationSheet(NSAlert(), for: window) { _ in applied += 1 }
        XCTAssertTrue(f.host.languagePresentationController?.hasInteractionOwners == true)
        XCTAssertEqual(f.host.languageSettingsCoordinator?.apply(.init(language: .japanese)), .saved); await drain()
        XCTAssertEqual(f.host.languageStrings?.language, .english)
        callbacks[0](.cancel); callbacks[0](.alertFirstButtonReturn); await drain()
        XCTAssertEqual(applied, 1); XCTAssertEqual(f.host.languageStrings?.language, .english)
        callbacks[1](.alertFirstButtonReturn); await drain()
        XCTAssertEqual(applied, 2); XCTAssertEqual(f.host.languageStrings?.language, .japanese)
    }

    func testNamespaceReplacementRejectsLateSheetEditsAndStillReleasesOldOwner() async throws {
        let f = Fixture(); defer { f.teardown() }
        let window = NSWindow(contentRect: f.root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        f.host.window = window
        var callback: ((NSApplication.ModalResponse) -> Void)?, applied = 0
        f.host.applicationSheetPresenter = { _, _, finish in callback = finish }
        f.host.presentApplicationSheet(NSAlert(), for: window) { _ in applied += 1 }
        let oldOwner = f.host.languagePresentationController
        f.host.installLanguagePreferences(store: StatusNoticeLanguageStore(), preferredLanguages: { ["en"] }, center: f.center)
        try XCTUnwrap(callback)(.alertFirstButtonReturn); await drain()
        XCTAssertEqual(applied, 0)
        XCTAssertFalse(oldOwner?.hasInteractionOwners == true)
    }
    func testActualQueryOnlyCommitCallbackClearsNoticeWithoutCatalogIdleOrLocaleEvent() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.receive(f.records(3), revision: 1); await drain()
        let status = try XCTUnwrap(f.host.catalogStatusView)
        let revision = f.assembly.provider.servedRevision
        f.assembly.searchPresentation.updateQuery(AppSearchQuery(raw: "no match"))
        _ = f.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        await drain()
        XCTAssertEqual(status.state, .noResults)
        f.assembly.searchPresentation.clearQuery()
        _ = f.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        await drain()
        XCTAssertEqual(status.state, .ready); XCTAssertTrue(status.isHidden)
        XCTAssertEqual(f.assembly.provider.servedRevision, revision)
    }

    func testMeasuredMountedBusyChipReservesCompleteTextAndSpinnerInAllLanguages() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.receive(f.records(105), revision: 1); await drain()
        let status = try XCTUnwrap(f.host.catalogStatusView)
        for language in InterfaceLanguage.allCases {
            status.relabel(strings: LocalizedStrings(language: language)); status.update(state: .refreshing)
            await drain(); f.host.layoutCatalogStatus(); status.layoutSubtreeIfNeeded()
            let label = try XCTUnwrap(status.subviews.compactMap { $0 as? NSTextField }.first)
            let measured = try XCTUnwrap(label.cell).cellSize(forBounds: NSRect(x: 0, y: 0,
                width: label.frame.width, height: CGFloat.greatestFiniteMagnitude)).height
            XCTAssertGreaterThanOrEqual(label.frame.height, measured)
            XCTAssertGreaterThanOrEqual(label.frame.height, 15)
            XCTAssertGreaterThanOrEqual(status.frame.height, status.requiredPresentationHeight(forWidth: status.frame.width))
        }
    }

    func testMountedCatalogWarningDoesNotCoverBottomRowOrPageDots() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.receive(f.records(105), revision: 1); await drain()
        f.host.installPageDots(in: f.root)
        let status = try XCTUnwrap(f.host.catalogStatusView)
        status.update(state: .partialFailure)
        await drain(); f.host.layoutCatalogStatus(); status.layoutSubtreeIfNeeded()
        f.surface.layoutSubtreeIfNeeded()
        let page = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0))
        page.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(page.cellCount, 0)
        for index in 0..<page.cellCount {
            let cell = try XCTUnwrap(page.cell(at: index))
            XCTAssertFalse(status.frame.intersects(cell.convert(cell.bounds, to: f.root)),
                           "Status must remain outside every application cell")
        }
        let dots = try XCTUnwrap(f.host.pageDotsView)
        XCTAssertFalse(status.frame.intersects(dots.frame))
        XCTAssertTrue(f.root.bounds.contains(status.frame))
        XCTAssertLessThanOrEqual(status.frame.height, 20)
    }

    func testUnchangedWarningRelayoutsAfterEqualProductCapacityCommitWithoutRootResize() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.root.setFrameSize(NSSize(width: 1200, height: 900))
        f.surface.frame = f.root.bounds
        f.receive(f.records(24), revision: 1); await drain()
        f.host.installPageDots(in: f.root)
        f.host.installMainGridCapacityPreferences(store: StatusNoticeCapacityStore())
        let coordinator = try XCTUnwrap(f.host.mainGridCapacityCoordinator)
        await coordinator.loadIfNeeded(); await drain()
        let initial = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 3))
        XCTAssertTrue(coordinator.submit(initial))
        _ = await coordinator.drain(); f.host.flushPendingMainGridCapacityIfReady(); await drain()
        XCTAssertEqual(f.host.mainGridCapacity, initial)
        let status = try XCTUnwrap(f.host.catalogStatusView)
        status.update(state: .partialFailure); await drain()
        try assertMountedStatusAvoidsContent(f)
        let frame = status.frame, rootBounds = f.root.bounds, pageCount = f.surface.core.pageCount
        let formats = status.languageFormattingCount, revision = f.assembly.provider.servedRevision
        let queryGeneration = f.assembly.searchPresentation.latestGeneration

        let changed = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 8))
        XCTAssertTrue(coordinator.submit(changed))
        _ = await coordinator.drain(); f.host.flushPendingMainGridCapacityIfReady()
        XCTAssertEqual(status.languageFormattingCount, formats)
        await drain()
        XCTAssertEqual(f.host.mainGridCapacity, changed)
        XCTAssertNotEqual(status.frame, frame, "The admitted commit must invalidate the sibling status geometry")
        XCTAssertEqual(f.root.bounds, rootBounds)
        XCTAssertEqual(f.surface.core.pageCount, pageCount)
        XCTAssertEqual(f.assembly.provider.servedRevision, revision)
        XCTAssertEqual(f.assembly.searchPresentation.latestGeneration, queryGeneration)
        XCTAssertEqual(status.languageFormattingCount, formats)
        try assertMountedStatusAvoidsContent(f)
    }

    func testUnchangedWarningRelayoutsAfterAppearanceOnlyCommitWithoutRootResize() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.root.setFrameSize(NSSize(width: 1200, height: 900))
        f.surface.frame = f.root.bounds
        f.receive(f.records(25), revision: 1); await drain()
        f.host.installPageDots(in: f.root)
        f.host.installMainGridCapacityPreferences(store: StatusNoticeCapacityStore())
        let coordinator = try XCTUnwrap(f.host.mainGridCapacityCoordinator)
        await coordinator.loadIfNeeded(); await drain()
        let capacity = try XCTUnwrap(MainGridCapacity(columns: 5, rows: 5))
        XCTAssertTrue(coordinator.submit(capacity))
        _ = await coordinator.drain(); f.host.flushPendingMainGridCapacityIfReady(); await drain()
        var appearance = f.host.appearancePreferences
        appearance.mainPreferredIconSide = 48
        f.host.applyAppearancePreferences(appearance); await drain()
        let status = try XCTUnwrap(f.host.catalogStatusView)
        status.update(state: .partialFailure); await drain()
        try assertMountedStatusAvoidsContent(f)
        let frame = status.frame, rootBounds = f.root.bounds
        let formats = status.languageFormattingCount, revision = f.assembly.provider.servedRevision
        let queryGeneration = f.assembly.searchPresentation.latestGeneration

        appearance.mainPreferredIconSide = 96
        f.host.applyAppearancePreferences(appearance)
        XCTAssertEqual(f.host.appearancePreferences, appearance)
        XCTAssertEqual(status.languageFormattingCount, formats)
        await drain()
        XCTAssertNotEqual(status.frame, frame, "Appearance metrics must also invalidate the status frame")
        XCTAssertEqual(f.root.bounds, rootBounds)
        XCTAssertEqual(f.host.mainGridCapacity, capacity)
        XCTAssertEqual(f.assembly.provider.servedRevision, revision)
        XCTAssertEqual(f.assembly.searchPresentation.latestGeneration, queryGeneration)
        XCTAssertEqual(status.languageFormattingCount, formats)
        try assertMountedStatusAvoidsContent(f)
    }

    private func assertMountedStatusAvoidsContent(_ fixture: Fixture,
                                                file: StaticString = #filePath, line: UInt = #line) throws {
        fixture.surface.layoutSubtreeIfNeeded()
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0), file: file, line: line)
        page.layoutSubtreeIfNeeded()
        let status = try XCTUnwrap(fixture.host.catalogStatusView, file: file, line: line)
        XCTAssertEqual(status.state, .partialFailure, file: file, line: line)
        XCTAssertFalse(status.isHidden, file: file, line: line)
        XCTAssertTrue(status.isCompactPresentation, file: file, line: line)
        XCTAssertGreaterThan(page.cellCount, 0, file: file, line: line)
        for index in 0..<page.cellCount {
            let cell = try XCTUnwrap(page.cell(at: index), file: file, line: line)
            XCTAssertFalse(status.frame.intersects(cell.convert(cell.bounds, to: fixture.root)),
                           "The unchanged warning must stay outside every changed application cell", file: file, line: line)
        }
        let dots = try XCTUnwrap(fixture.host.pageDotsView, file: file, line: line)
        XCTAssertFalse(status.frame.intersects(dots.frame), file: file, line: line)
        XCTAssertTrue(fixture.root.bounds.contains(status.frame), file: file, line: line)
        XCTAssertLessThanOrEqual(status.frame.height, 20, file: file, line: line)
    }

    func testReplacedWindowRejectsOldSheetSuccessButReleasesLease() async throws {
        let f = Fixture(); defer { f.teardown() }
        let old = NSWindow(contentRect: f.root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        old.isReleasedWhenClosed = false; f.host.window = old
        var finish: ((NSApplication.ModalResponse) -> Void)?, applied = 0
        f.host.applicationSheetPresenter = { _, _, callback in finish = callback }
        f.host.presentApplicationSheet(NSAlert(), for: old) { _ in applied += 1 }
        let replacement = NSWindow(contentRect: f.root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        replacement.isReleasedWhenClosed = false; f.host.window = replacement
        try XCTUnwrap(finish)(.alertFirstButtonReturn); await drain()
        XCTAssertEqual(applied, 0)
        XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
    }

    func testActualSettingsAlertAndPickerPathsCountLeasesAndReleaseOnCancelReplacementAndDuplicates() async throws {
        let f = Fixture(); defer { f.teardown() }
        let controller = ActivationSettingsWindowController(draft: .init(committed: .init()), strings: f.host.languageStrings)
        f.host.configureLanguageSettings(controller)
        defer { controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        var alertFinish: (() -> Void)?, pickerFinish: ((NSApplication.ModalResponse) -> Void)?
        controller.alertPresenter = { _, _, finish in alertFinish = finish }
        controller.appSourcesView.panelPresenter = { _, _, finish in pickerFinish = finish }
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        tabs.selectTabViewItem(at: 3)
        controller.appSourcesView.addButton.performClick(nil)
        XCTAssertNotNil(pickerFinish)
        controller.presentAlert(title: "Synthetic failure", message: "Synthetic error")
        XCTAssertTrue(f.host.languagePresentationController?.hasInteractionOwners == true)
        XCTAssertEqual(f.host.languageSettingsCoordinator?.apply(.init(language: .japanese)), .saved); await drain()
        XCTAssertEqual(f.host.languageStrings?.language, .english)
        try XCTUnwrap(alertFinish)(); try XCTUnwrap(alertFinish)(); await drain()
        XCTAssertEqual(f.host.languageStrings?.language, .english, "Picker owns the remaining lease")
        controller.appSourcesView.cancelPendingOperations()
        try XCTUnwrap(pickerFinish)(.cancel); try XCTUnwrap(pickerFinish)(.OK); await drain()
        XCTAssertFalse(controller.appSourcesView.hasPresentationOwnership)
        XCTAssertFalse(f.host.languagePresentationController?.hasInteractionOwners == true)
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
    }

}
