import AppKit
import AppCatalogCore
import LauncherLocalization
import XCTest
@testable import AppGridUI
@testable import PagingUI
@testable import PagingPrototypeApp

@MainActor
private final class ActionFeedbackLanguageStore: LanguagePreferencesPersisting {
    var value = LanguagePreferences(language: .english)
    func load() -> LanguagePreferencesLoadResult { .loaded(value) }
    func save(_ value: LanguagePreferences) -> LanguagePreferencesSaveResult { self.value = value; return .saved }
}

@MainActor
final class ApplicationActionFeedbackRuntimeTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 2, itemsPerPage: 35)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let store = ActionFeedbackLanguageStore()
        let factory: FakeAppFactory
        let assembly: AppCatalogAssembly
        let record: AppRecord
        let launcher = RecordingLauncher()
        let launch: AppLaunchController
        init() throws {
            _ = NSApplication.shared
            factory = try FakeAppFactory()
            let url = try XCTUnwrap(factory.makeApps(names: ["Synthetic Action"]).values.first)
            let id = CatalogFixture.appID("fixture.action.feedback")
            record = CatalogFixture.record(id: id, displayName: "Synthetic Action", bundleID: "fixture.action.feedback",
                url: url, icon: .from(appID: id), rootPriority: 0)
            assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
            launch = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
            host.surface = surface; host.assembly = assembly; host.container = root
            root.addSubview(surface); surface.frame = root.bounds
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            host.installLanguagePreferences(store: store, preferredLanguages: { ["en"] }, center: NotificationCenter())
            assembly.provider.receive(.init(revision: CatalogRevision(1), records: [record]))
            _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            host.installActionFeedback(in: root)
            host.installLaunchAttemptFeedback(launch, assembly: assembly)
        }
        func cell(revision: UInt64 = 1) -> AppGridCellView {
            AppCatalogAssembly.makeMemberLaunchCell(appID: record.id, servedRevision: revision)
        }
        func teardown() {
            host.teardownActionFeedback(); host.teardownLanguagePresentation()
            surface.teardown(); assembly.teardown(); factory.removeRoot()
        }
    }
    private func drain() async { for _ in 0..<5 { await drainDeferredPresentationTurns() } }

    func testRealSharedLaunchPipelineShowsFailureAndClearsOnlyOnAcceptedSuccess() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let view = try XCTUnwrap(f.host.actionFeedbackView)
        XCTAssertTrue(view.superview === f.root)
        f.launcher.shouldSucceed = false
        XCTAssertEqual(f.launch.handleCell(f.cell()), .failedToLaunch)
        await drain()
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(f.launch.lastOutcome, .failedToLaunch)
        XCTAssertEqual(f.launcher.opened, [f.record.canonicalURL])
        f.launcher.shouldSucceed = true
        XCTAssertEqual(f.launch.handleCell(f.cell()), .launched)
        await drain()
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(f.launcher.opened.count, 2)
    }

    func testStaleRealLaunchRefusalNeverCallsWorkspaceAndShowsNeutralMessage() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let view = try XCTUnwrap(f.host.actionFeedbackView)
        XCTAssertEqual(f.launch.handleCell(f.cell(revision: 0)), .rejectedStaleRevision)
        await drain()
        XCTAssertFalse(view.isHidden); XCTAssertTrue(f.launcher.opened.isEmpty)
        XCTAssertEqual(f.assembly.provider.servedRevision, 1)
    }

    func testNoBindingRemainsSilentAndDoesNotReviveHiddenFeedback() async throws {
        let f = try Fixture(); defer { f.teardown() }
        XCTAssertEqual(f.launch.handleCell(AppGridCellView(frame: .zero)), .rejectedNoBinding)
        await drain()
        XCTAssertTrue(f.host.actionFeedbackView?.isHidden == true)
        XCTAssertTrue(f.launcher.opened.isEmpty)
    }

    func testFinderMissingAndCanonicalRefusalsNeverDispatchButRequestedIsNotOSProof() async throws {
        let f = try Fixture(); defer { f.teardown() }
        var requests: [URL] = []
        f.host.fileRevealRequester = { requests.append($0) }
        f.host.actionFileExists = { _ in false }
        XCTAssertEqual(f.host.handleFinderReveal(f.record), .rejectedMissingFile)
        await drain()
        XCTAssertTrue(requests.isEmpty); XCTAssertFalse(f.host.actionFeedbackView?.isHidden ?? true)
        f.host.actionFileExists = { _ in true }
        XCTAssertEqual(f.host.handleFinderReveal(f.record), .requested)
        await drain()
        XCTAssertEqual(requests, [f.record.canonicalURL]); XCTAssertTrue(f.host.actionFeedbackView?.isHidden == true)
        let changed = CatalogFixture.record(id: f.record.id, displayName: "Changed", bundleID: "fixture.action.feedback",
            url: URL(fileURLWithPath: "/Synthetic/Changed.app"), icon: .from(appID: f.record.id), rootPriority: 0)
        XCTAssertEqual(f.host.handleFinderReveal(changed), .rejectedUnavailable)
        await drain()
        XCTAssertEqual(requests.count, 1)
    }

    func testActualFinderMenuCallbackUsesSharedFailureNoticeWithoutLaunchingAnything() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.host.installAppContextMenu(assembly: f.assembly)
        f.host.actionFileExists = { _ in false }
        var requested = false; f.host.fileRevealRequester = { _ in requested = true }
        // Main installs the same factory on the actual renderer; use its real retained page.
        f.surface.refreshPresentation()
        f.surface.layoutSubtreeIfNeeded()
        let actual = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let menu = try XCTUnwrap(actual.appContextMenuProvider?(actual))
        let item = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.reveal" })
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
        await drain()
        XCTAssertFalse(requested); XCTAssertTrue(f.launcher.opened.isEmpty)
        XCTAssertFalse(f.host.actionFeedbackView?.isHidden ?? true)
    }

    func testNamespaceReplacementHideAndRootReplacementDropPendingFeedback() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.launcher.shouldSucceed = false; _ = f.launch.handleCell(f.cell())
        let old = try XCTUnwrap(f.host.actionFeedbackView)
        f.host.installActionFeedback(in: f.root); await drain()
        XCTAssertNil(old.superview); XCTAssertTrue(old.isHidden)
        _ = f.launch.handleCell(f.cell())
        f.host.teardownLanguagePresentation(); await drain()
        XCTAssertTrue(f.host.actionFeedbackView?.isHidden == true)
    }

    func testObsoleteControllerCallbackCannotRenderIntoNewRootOrDomain() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let oldCallback = try XCTUnwrap(f.launch.onLaunchAttempt)
        let replacement = AppLaunchController(surface: f.surface, assembly: f.assembly, launcher: f.launcher)
        f.host.installLaunchAttemptFeedback(replacement, assembly: f.assembly)
        oldCallback(.failedToLaunch); await drain()
        XCTAssertTrue(f.host.actionFeedbackView?.isHidden == true)
    }

    func testNeutralActionReasonPolicyCoversEveryLaunchAndFinderOutcome() {
        XCTAssertNil(ApplicationActionFeedback.launchReason(.launched))
        XCTAssertNil(ApplicationActionFeedback.launchReason(.rejectedNoBinding))
        for outcome in [AppLaunchOutcome.rejectedMissingApp, .rejectedMissingFile] {
            XCTAssertEqual(ApplicationActionFeedback.launchReason(outcome), .launchMissing)
        }
        for outcome in [AppLaunchOutcome.rejectedStaleRevision, .rejectedHiddenApp] {
            XCTAssertEqual(ApplicationActionFeedback.launchReason(outcome), .launchUnavailable)
        }
        XCTAssertEqual(ApplicationActionFeedback.launchReason(.failedToLaunch), .launchFailed)
        XCTAssertNil(ApplicationActionFeedback.finderReason(.requested))
        XCTAssertEqual(ApplicationActionFeedback.finderReason(.rejectedMissingFile), .finderMissing)
        XCTAssertEqual(ApplicationActionFeedback.finderReason(.rejectedUnavailable), .finderUnavailable)
    }
    func testDisplayedLanguageRelabelPreservesErrorDeadlineRecordsAndRequests() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.launcher.shouldSucceed = false; _ = f.launch.handleCell(f.cell()); await drain()
        let view = try XCTUnwrap(f.host.actionFeedbackView), deadline = view.expirationDeadline
        let revision = f.assembly.provider.servedRevision, requests = f.assembly.iconPipeline.stats.requests
        XCTAssertEqual(f.host.languageSettingsCoordinator?.apply(.init(language: .japanese)), .saved); await drain()
        XCTAssertEqual(view.reason, .launchFailed)
        XCTAssertEqual(view.statusText, LocalizedStrings(language: .japanese).actionFeedbackText(.launchFailed))
        XCTAssertEqual(view.expirationDeadline, deadline)
        XCTAssertEqual(f.assembly.provider.servedRevision, revision)
        XCTAssertEqual(f.assembly.iconPipeline.stats.requests, requests)
        XCTAssertEqual(f.launcher.opened.count, 1)
        XCTAssertEqual(f.record.displayName, "Synthetic Action")
    }

    func testNormalHideDropsFeedbackWithoutTeardownOrPreferenceWrites() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.launcher.shouldSucceed = false; _ = f.launch.handleCell(f.cell()); await drain()
        let view = try XCTUnwrap(f.host.actionFeedbackView)
        f.host.prepareTransientCancellationForHide(); await drain()
        XCTAssertTrue(view.isHidden); XCTAssertNil(view.reason)
        XCTAssertFalse(f.surface.isTearingDown)
    }

    func testOldRootCallbackCannotClearNewErrorAndCurrentControllerStillReportsGenuineActions() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let oldCallback = try XCTUnwrap(f.launch.onLaunchAttempt)
        let replacement = NSView(frame: f.root.bounds)
        f.host.container = replacement
        f.host.installActionFeedback(in: replacement)
        f.launcher.shouldSucceed = false
        XCTAssertEqual(f.launch.handleCell(f.cell()), .failedToLaunch); await drain()
        let view = try XCTUnwrap(f.host.actionFeedbackView), deadline = view.expirationDeadline
        oldCallback(.launched); oldCallback(.failedToLaunch); await drain()
        XCTAssertEqual(view.reason, .launchFailed); XCTAssertEqual(view.expirationDeadline, deadline)
        f.launcher.shouldSucceed = true
        XCTAssertEqual(f.launch.handleCell(f.cell()), .launched); await drain()
        XCTAssertTrue(view.isHidden)
    }

    func testOldLanguageRealmLaunchAndFinderCallbacksCannotAffectReplacementButNewActionsWork() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.host.installAppContextMenu(assembly: f.assembly)
        f.surface.refreshPresentation(); f.surface.layoutSubtreeIfNeeded()
        let cell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let menu = try XCTUnwrap(cell.appContextMenuProvider?(cell))
        let reveal = try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.reveal" })
        let controller = try XCTUnwrap(reveal.target as? AppContextMenuController)
        let oldReveal = try XCTUnwrap(controller.onReveal), oldLaunch = try XCTUnwrap(f.launch.onLaunchAttempt)
        f.host.installLanguagePreferences(store: ActionFeedbackLanguageStore(), preferredLanguages: { ["en"] }, center: NotificationCenter())
        f.host.actionFileExists = { _ in false }
        oldReveal(f.record); oldLaunch(.failedToLaunch); await drain()
        XCTAssertTrue(f.host.actionFeedbackView?.isHidden == true)
        f.launcher.shouldSucceed = false; _ = f.launch.handleCell(f.cell()); await drain()
        let view = try XCTUnwrap(f.host.actionFeedbackView), deadline = view.expirationDeadline
        oldLaunch(.launched); oldReveal(f.record); await drain()
        XCTAssertEqual(view.reason, .launchFailed); XCTAssertEqual(view.expirationDeadline, deadline)
    }

    func testActualHideCallbackClearsQueuedAndVisibleFeedbackAndAllowsFreshFailure() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.launcher.shouldSucceed = false
        for drainBeforeHide in [false, true] {
            _ = f.launch.handleCell(f.cell())
            if drainBeforeHide { await drain(); XCTAssertFalse(f.host.actionFeedbackView?.isHidden ?? true) }
            f.host.launcherDidHideHandler()(); await drain()
            XCTAssertTrue(f.host.actionFeedbackView?.isHidden == true)
            XCTAssertNil(f.host.actionFeedbackView?.reason)
            XCTAssertFalse(f.surface.isTearingDown)
            XCTAssertEqual(f.store.value.language, .english)
        }
        _ = f.launch.handleCell(f.cell()); await drain()
        XCTAssertFalse(f.host.actionFeedbackView?.isHidden ?? true)
    }

    func testActualFolderMountKeepsExistingNoticeAboveOpaqueAndTransparentBackdropWithoutRenewing() async throws {
        let f = try Fixture(); defer { f.teardown() }
        let secondID = CatalogFixture.appID("fixture.action.second")
        let second = CatalogFixture.record(id: secondID, displayName: "Second", bundleID: "fixture.action.second",
            url: CatalogFixture.tempURL(named: "Second.app"), icon: .from(appID: secondID), rootPriority: 0)
        let catalog = CatalogSnapshot(revision: CatalogRevision(2), records: [f.record, second])
        f.assembly.provider.receive(catalog)
        let folders = FolderSnapshot(generation: .zero, entries: [FolderEntryBuilder.make(
            id: FolderID(), title: "Synthetic Folder", members: [f.record.id, secondID])])
        f.assembly.folderSnapshotGenerator = { _ in folders }
        _ = f.assembly.commitPendingAtIdleBoundary(currentPage: 0)
        f.surface.refreshPresentation(); f.surface.layoutSubtreeIfNeeded()
        let keyboard = KeyboardFocusController(columns: 5)
        f.host.installFolderWiring(assembly: f.assembly, surface: f.surface, keyboard: keyboard, launch: f.launch)
        let folderID = try XCTUnwrap(f.assembly.provider.servedFolderSnapshot?.entries.first?.id)
        f.launcher.shouldSucceed = false
        _ = f.launch.handleCell(f.cell(revision: 2)); await drain()
        let notice = try XCTUnwrap(f.host.actionFeedbackView), deadline = notice.expirationDeadline
        f.host.openFolder(folderID: folderID)
        let overlay = try XCTUnwrap(f.host.folderOverlay)
        for reduced in [false, true] {
            overlay.applyMaterialPolicy(reduceTransparency: reduced, increaseContrast: false)
            await drain()
            let noticeIndex = try XCTUnwrap(f.root.subviews.firstIndex { $0 === notice })
            let overlayIndex = try XCTUnwrap(f.root.subviews.firstIndex { $0 === overlay })
            XCTAssertGreaterThan(noticeIndex, overlayIndex)
            XCTAssertEqual(notice.reason, .launchFailed); XCTAssertEqual(notice.expirationDeadline, deadline)
            XCTAssertNil(notice.hitTest(NSPoint(x: 1, y: 1)))
        }
    }

    func testOldMenuLaunchIngressCannotDispatchIntoReboundRootOrRealmAndNewMenuRemainsLive() async throws {
        let f = try Fixture(); defer { f.teardown() }
        f.host.installAppContextMenu(assembly: f.assembly)
        f.surface.refreshPresentation(); f.surface.layoutSubtreeIfNeeded()
        let cell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        func launchItem() throws -> NSMenuItem {
            let menu = try XCTUnwrap(cell.appContextMenuProvider?(cell))
            return try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == "management.launch" })
        }
        let oldRootItem = try launchItem()
        let rootController = try XCTUnwrap(oldRootItem.target as? AppContextMenuController)
        let oldRootCallback = try XCTUnwrap(rootController.onLaunch)
        let replacement = NSView(frame: f.root.bounds)
        f.host.container = replacement; f.host.installActionFeedback(in: replacement)
        f.launcher.shouldSucceed = false
        _ = f.launch.handleCell(f.cell()); await drain()
        let view = try XCTUnwrap(f.host.actionFeedbackView), deadline = view.expirationDeadline
        let requests = f.launcher.opened.count
        oldRootCallback(f.record.id)
        _ = NSApp.sendAction(try XCTUnwrap(oldRootItem.action), to: oldRootItem.target, from: oldRootItem)
        await drain()
        XCTAssertEqual(f.launcher.opened.count, requests)
        XCTAssertEqual(view.expirationDeadline, deadline); XCTAssertEqual(view.reason, .launchFailed)
        let oldRealmItem = try launchItem()
        let realmController = try XCTUnwrap(oldRealmItem.target as? AppContextMenuController)
        f.host.installLanguagePreferences(store: ActionFeedbackLanguageStore(), preferredLanguages: { ["en"] }, center: NotificationCenter())
        let current = try launchItem()
        _ = NSApp.sendAction(try XCTUnwrap(oldRealmItem.action), to: realmController, from: oldRealmItem)
        await drain()
        XCTAssertEqual(f.launcher.opened.count, requests)
        XCTAssertTrue(view.isHidden)
        _ = NSApp.sendAction(try XCTUnwrap(current.action), to: current.target, from: current)
        await drain()
        XCTAssertEqual(f.launcher.opened.count, requests + 1)
        XCTAssertFalse(view.isHidden)
    }

}
