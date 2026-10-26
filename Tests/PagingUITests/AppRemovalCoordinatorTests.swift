import Foundation
import AppKit
import AppCatalogCore
import XCTest
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

private actor RemovalFilesProbe: AppRemovalFileAccess {
    var inspection: AppRemovalInspection
    var result: AppRemovalTrashResult = .moved
    var holdInspection = false
    var holdMove = false
    var inspectionWaiter: CheckedContinuation<Void, Never>?
    var moveWaiter: CheckedContinuation<Void, Never>?
    private(set) var inspections = 0
    private(set) var moves = 0

    init(_ candidate: AppRemovalCandidate) { inspection = .eligible(candidate) }
    func configure(inspection: AppRemovalInspection? = nil, result: AppRemovalTrashResult? = nil,
                   holdInspection: Bool = false, holdMove: Bool = false) {
        if let inspection { self.inspection = inspection }
        if let result { self.result = result }
        self.holdInspection = holdInspection
        self.holdMove = holdMove
    }
    func inspect(url: URL, allowedTestRoot: URL?, selfBundleURL: URL) async -> AppRemovalInspection {
        inspections += 1
        if holdInspection { await withCheckedContinuation { inspectionWaiter = $0 } }
        return inspection
    }
    func moveToTrash(_ candidate: AppRemovalCandidate, allowedTestRoot: URL?, selfBundleURL: URL) async -> AppRemovalTrashResult {
        moves += 1
        if holdMove { await withCheckedContinuation { moveWaiter = $0 } }
        return result
    }
    func releaseInspection() { holdInspection = false; inspectionWaiter?.resume(); inspectionWaiter = nil }
    func releaseMove() { holdMove = false; moveWaiter?.resume(); moveWaiter = nil }
}

@MainActor
final class AppRemovalCoordinatorTests: XCTestCase {
    private let url = URL(fileURLWithPath: "/SyntheticApps/Disposable.app")
    private var candidate: AppRemovalCandidate {
        .init(url: url, identity: .init(device: 1, inode: 2))
    }
    private func make(_ files: RemovalFilesProbe, running: @escaping (URL) -> Bool = { _ in false }) -> AppRemovalCoordinator {
        .init(files: files, allowedTestRoot: URL(fileURLWithPath: "/SyntheticApps"),
              selfBundleURL: URL(fileURLWithPath: "/SyntheticApps/Launcher.app"), isRunning: running)
    }

    private func observeAsync(_ condition: @escaping () async -> Bool) async -> Bool {
        let clock = ContinuousClock(), deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return await condition()
    }

    func testCancelNeverTrashesAndLateConfirmationCannotRevive() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        var decide: ((Bool) -> Void)?
        XCTAssertTrue(owner.request(url: url, validate: { true }) { _, callback in decide = callback })
        let prompted = await waitUntil { decide != nil }; XCTAssertTrue(prompted)
        decide?(false); decide?(true)
        XCTAssertEqual(owner.lastOutcome, .cancelled)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
        XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testAcceptedConfirmationExecutesOnceWithFreshInspection() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        var decide: ((Bool) -> Void)?
        _ = owner.request(url: url, validate: { true }) { _, callback in decide = callback }
        let prompted = await waitUntil { decide != nil }; XCTAssertTrue(prompted)
        decide?(true); decide?(true)
        let finished = await waitUntil { owner.lastOutcome == .moved }; XCTAssertTrue(finished)
        let moves = await files.moves, inspections = await files.inspections
        XCTAssertEqual(moves, 1); XCTAssertEqual(inspections, 2)
        XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testCancelledInspectionRemainsBoundedUntilActualReturn() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        await files.configure(holdInspection: true)
        var prompts = 0
        _ = owner.request(url: url, validate: { true }) { _, _ in prompts += 1 }
        let started = await observeAsync { await files.inspections == 1 }; XCTAssertTrue(started)
        owner.cancelUnaccepted()
        XCTAssertTrue(owner.isBusy)
        XCTAssertFalse(owner.request(url: url, validate: { true }) { _, _ in XCTFail() })
        await files.releaseInspection()
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .cancelled); XCTAssertEqual(prompts, 0)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testChangedBindingAfterPromptCannotExecute() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        var valid = true, decide: ((Bool) -> Void)?
        _ = owner.request(url: url, validate: { valid }) { _, callback in decide = callback }
        let prompted = await waitUntil { decide != nil }; XCTAssertTrue(prompted)
        valid = false; decide?(true)
        XCTAssertEqual(owner.lastOutcome, .cancelled)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testRunningAppRejectedBeforePrompt() async {
        let files = RemovalFilesProbe(candidate), owner = make(files, running: { _ in true })
        _ = owner.request(url: url, validate: { true }) { _, _ in XCTFail("No confirmation for running app") }
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .running)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testAppStartsWhileConfirmationOpenCannotBeRemoved() async {
        let files = RemovalFilesProbe(candidate)
        var running = false, decide: ((Bool) -> Void)?
        let owner = make(files, running: { _ in running })
        _ = owner.request(url: url, validate: { true }) { _, callback in decide = callback }
        let prompted = await waitUntil { decide != nil }; XCTAssertTrue(prompted)
        running = true; decide?(true)
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .running)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testChangedFileIdentityAfterConfirmationRejects() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        var decide: ((Bool) -> Void)?
        _ = owner.request(url: url, validate: { true }) { _, callback in decide = callback }
        let prompted = await waitUntil { decide != nil }; XCTAssertTrue(prompted)
        let changed = AppRemovalCandidate(url: url, identity: .init(device: 1, inode: 3))
        await files.configure(inspection: .eligible(changed))
        decide?(true)
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .changed)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testMovingTimeoutAndLateFailureRetainQuitProtectionUntilAcknowledged() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        await files.configure(result: .failed, holdMove: true)
        _ = owner.request(url: url, validate: { true }) { _, decide in decide(true) }
        let moving = await waitUntil { owner.phase == .moving }; XCTAssertTrue(moving)
        let drain = await owner.drain(timeout: .milliseconds(15)); XCTAssertEqual(drain, .timedOut)
        owner.acknowledgeResult(); XCTAssertTrue(owner.requiresQuitProtection)
        XCTAssertFalse(owner.request(url: url, validate: { true }) { _, _ in XCTFail() })
        await files.releaseMove()
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .failed)
        XCTAssertFalse(owner.request(url: url, validate: { true }) { _, _ in XCTFail("A new attempt cannot erase an unacknowledged unknown result") })
        let failedDrain = await owner.drain(timeout: .zero); XCTAssertEqual(failedDrain, .failed)
        owner.acknowledgeResult(); XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testHideAfterPlatformAdmissionRetainsActualSuccessReceipt() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        await files.configure(holdMove: true)
        var valid = true, completed: [AppRemovalCoordinator.Outcome] = []
        owner.onComplete = { completed.append($0) }
        _ = owner.request(url: url, validate: { valid }) { _, decide in decide(true) }
        let moving = await waitUntil { owner.phase == .moving }; XCTAssertTrue(moving)
        valid = false; owner.cancelUnaccepted()
        XCTAssertTrue(owner.isBusy)
        await files.releaseMove()
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(completed, [.moved]); XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testTeardownRevokesPromptAndLateCallback() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        var decide: ((Bool) -> Void)?
        _ = owner.request(url: url, validate: { true }) { _, callback in decide = callback }
        let prompted = await waitUntil { decide != nil }; XCTAssertTrue(prompted)
        owner.teardown(); decide?(true)
        XCTAssertFalse(owner.isBusy)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testRejectedEligibilityDoesNotShowConfirmationOrTrash() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        await files.configure(inspection: .rejected(.wrongProfile))
        _ = owner.request(url: url, validate: { true }) { _, _ in XCTFail() }
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .unavailable)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }

    func testApplicationQuitWaitsForActualRemovalAndDefaultsToExplicitDecision() async {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        await files.configure(result: .failed, holdMove: true)
        let app = AppDelegate(options: .default)
        app.appRemovalCoordinator = owner
        defer { app.applicationWillTerminate(.init(name: NSApplication.willTerminateNotification)) }
        _ = owner.request(url: url, validate: { true }) { _, decide in decide(true) }
        let moving = await waitUntil { owner.phase == .moving }; XCTAssertTrue(moving)
        var reply: [Bool] = [], choose: ((Bool) -> Void)?, failure: LayoutStoreFlushResult?
        XCTAssertEqual(app.requestWorkspaceQuit(enqueueWait: .milliseconds(10), reply: { reply.append($0) },
            chooseOnFailure: { failure = $0; choose = $1 }), .terminateLater)
        let prompted = await waitUntil { choose != nil }; XCTAssertTrue(prompted)
        XCTAssertEqual(failure, .timedOut); XCTAssertTrue(reply.isEmpty)
        choose?(false); XCTAssertEqual(reply, [false]); XCTAssertTrue(owner.isBusy)
        await files.releaseMove()
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertTrue(owner.requiresQuitProtection)
        owner.acknowledgeResult()
        XCTAssertEqual(app.requestWorkspaceQuit(reply: { _ in XCTFail() }, chooseOnFailure: { _, _ in XCTFail() }), .terminateNow)
    }

    func testSharedNonCellLaunchRouteIsBlockedOnlyWhileRemovalIsBusy() async throws {
        let files = RemovalFilesProbe(candidate), owner = make(files)
        await files.configure(holdMove: true)
        let app = AppDelegate(options: .default)
        app.appRemovalCoordinator = owner
        let factory = try FakeAppFactory()
        _ = try factory.makeApps(names: ["Removal Guard Fixture"])
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        defer { assembly.teardown(); surface.teardown(); factory.removeRoot() }
        wireAssembly(assembly, to: surface); assembly.begin()
        let loaded = await waitUntil { assembly.provider.servedSnapshot != nil }; XCTAssertTrue(loaded)
        let snapshot = try XCTUnwrap(assembly.provider.servedSnapshot), record = try XCTUnwrap(snapshot.records.first)
        let executor = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: executor)
        app.installLaunchAttemptFeedback(controller, assembly: assembly)
        _ = owner.request(url: url, validate: { true }) { _, decide in decide(true) }
        let moving = await waitUntil { owner.phase == .moving }; XCTAssertTrue(moving)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: snapshot.revision,
                                           expectedURL: record.canonicalURL), .rejectedNoBinding)
        XCTAssertTrue(executor.opened.isEmpty)
        await files.releaseMove()
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: snapshot.revision,
                                           expectedURL: record.canonicalURL), .launched)
        XCTAssertEqual(executor.opened, [record.canonicalURL])
        owner.teardown()
    }

    func testHideRevokesOldPresentationButRetainsSuccessAndFailedReceipts() async {
        for result: AppRemovalTrashResult in [.moved, .failed] {
            let files = RemovalFilesProbe(candidate), owner = make(files)
            await files.configure(result: result, holdMove: true)
            let app = AppDelegate(options: .default)
            app.appRemovalCoordinator = owner
            let epoch = app.appRemovalPresentationGeneration
            var receipts: [AppRemovalCoordinator.Outcome] = [], presented: [AppRemovalCoordinator.Outcome] = []
            owner.onComplete = { outcome in
                receipts.append(outcome)
                if app.appRemovalPresentationIsCurrent(epoch) { presented.append(outcome) }
            }
            _ = owner.request(url: url, validate: { true }) { _, decide in decide(true) }
            let moving = await waitUntil { owner.phase == .moving }; XCTAssertTrue(moving)
            app.launcherDidHideHandler()()
            XCTAssertFalse(app.appRemovalPresentationIsCurrent(epoch))
            await files.releaseMove()
            let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
            XCTAssertEqual(receipts, [result == .moved ? .moved : .failed])
            XCTAssertTrue(presented.isEmpty, "Reopening the same view cannot revive this presentation token")
            XCTAssertEqual(owner.requiresQuitProtection, result == .failed)
            app.applicationWillTerminate(.init(name: NSApplication.willTerminateNotification))
        }
    }

    func testCancelledAsynchronousRunningCheckCannotPresentOrRemove() async {
        let files = RemovalFilesProbe(candidate)
        var resume: CheckedContinuation<Bool, Never>?
        let owner = AppRemovalCoordinator(files: files, allowedTestRoot: nil, selfBundleURL: url) { _ in
            await withCheckedContinuation { resume = $0 }
        }
        _ = owner.request(url: url, validate: { true }) { _, _ in XCTFail("Cancelled running query cannot revive UI") }
        let checking = await waitUntil { resume != nil }; XCTAssertTrue(checking)
        owner.cancelUnaccepted()
        XCTAssertTrue(owner.isBusy)
        let timeout = await owner.drain(timeout: .milliseconds(10)); XCTAssertEqual(timeout, .timedOut)
        XCTAssertFalse(owner.request(url: url, validate: { true }) { _, _ in XCTFail() })
        resume?.resume(returning: false)
        let finished = await waitUntil { !owner.isBusy }; XCTAssertTrue(finished)
        XCTAssertEqual(owner.lastOutcome, .cancelled)
        let moves = await files.moves; XCTAssertEqual(moves, 0)
    }
}
