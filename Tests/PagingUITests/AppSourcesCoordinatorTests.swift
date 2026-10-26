import AppKit
import XCTest
@testable import PagingPrototypeApp

actor SourcesAdmissionFake: AppSourceRootAdmitting {
    private var results: [String: AppSourceRootAdmissionResult] = [:]
    private(set) var calls: [URL] = []
    func set(_ path: String, _ result: AppSourceRootAdmissionResult) { results[path] = result }
    func admit(_ candidate: URL, context: AppSourceRootAdmissionContext) async -> AppSourceRootAdmissionResult {
        calls.append(candidate)
        return results[candidate.path] ?? .accepted(candidate)
    }
}

@MainActor
final class SourcesWatchFake: AppSourceWatching {
    var status: AppSourceWatchStatus = .active
    var roots: [[URL]] = []
    var callbacks: [@MainActor () -> Void] = []
    var stops = 0
    func replaceRoots(_ roots: [URL], onChange: @escaping @MainActor () -> Void) async -> AppSourceWatchStatus {
        self.roots.append(roots); callbacks.append(onChange); return status
    }
    func stop() { stops += 1 }
}

@MainActor
final class AppSourcesCoordinatorTests: XCTestCase {
    final class Store: AppSourcesPersisting {
        var result: AppSourcesLoadResult = .loaded(.default)
        var saveResult: AppSourcesSaveResult = .saved
        var saves: [AppSourcesPreferences] = []
        func load() -> AppSourcesLoadResult { result }
        func save(_ preferences: AppSourcesPreferences) -> AppSourcesSaveResult {
            saves.append(preferences)
            if saveResult == .saved { result = .loaded(preferences) }
            return saveResult
        }
    }
    private let fixed = URL(fileURLWithPath: "/FixtureApps")
    private let extra = URL(fileURLWithPath: "/ExtraApps")
    private func context() -> AppSourceRootAdmissionContext {
        .init(homeURL: URL(fileURLWithPath: "/FixtureHome"), fixedRoots: [fixed])
    }
    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        XCTFail("Bounded asynchronous consumer did not settle")
    }

    func testActivateDefaultsStartsFixedWatchButDoesNotScanOrSave() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        var replacements: [[URL]] = [], refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { replacements.append($0) },
            requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }
        owner.activate(); owner.activate()
        await settle { owner.watchStatus == .active }
        XCTAssertEqual(replacements, [[fixed]]); XCTAssertEqual(watcher.roots, [[fixed]])
        XCTAssertEqual(refreshes, []); XCTAssertEqual(store.saves, [])
    }

    func testAcceptedAddedRootPersistsBeforeRuntimeAndRefreshesWithoutOtherState() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        var replacements: [[URL]] = [], refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { replacements.append($0) },
            requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }
        owner.activate(); await settle { owner.watchStatus == .active }
        let draft = AppSourcesPreferences(customRootPaths: [extra.path])
        let result = await owner.apply(draft)
        XCTAssertEqual(result, .saved); XCTAssertEqual(owner.committed, draft)
        XCTAssertEqual(store.saves, [draft]); XCTAssertEqual(replacements, [[fixed], [fixed, extra]])
        XCTAssertEqual(refreshes, [true]); await settle { watcher.roots.last == [fixed, extra] }
    }

    func testInvalidNewRootNeverSavesOrReplacesOrRefreshes() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        await admission.set(extra.path, .rejected(.nonLocalVolume))
        var replacements = 0, refreshes = 0
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in replacements += 1 },
            requestRefresh: { _ in refreshes += 1 })
        defer { owner.teardown() }; owner.activate()
        let result = await owner.apply(.init(customRootPaths: [extra.path]))
        XCTAssertEqual(result, .invalidRoot); XCTAssertEqual(store.saves, [])
        XCTAssertEqual(owner.committed, .default); XCTAssertEqual(replacements, 1); XCTAssertEqual(refreshes, 0)
    }

    func testSaveFailureKeepsCommittedRootsAndWatcher() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        store.saveResult = .failed
        var refreshes = 0
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { _ in refreshes += 1 })
        defer { owner.teardown() }; owner.activate(); await settle { owner.watchStatus == .active }
        let result = await owner.apply(.init(customRootPaths: [extra.path]))
        XCTAssertEqual(result, .failed); XCTAssertEqual(owner.committed, .default)
        XCTAssertEqual(watcher.roots, [[fixed]]); XCTAssertEqual(refreshes, 0)
    }

    func testUnavailableSavedRootStaysSavedAndManualRefreshCanRestoreCoverage() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        let saved = AppSourcesPreferences(customRootPaths: [extra.path])
        store.result = .loaded(saved); await admission.set(extra.path, .rejected(.missing))
        var refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }; owner.activate(); await settle { owner.watchStatus == .degraded }
        XCTAssertEqual(watcher.roots, [[fixed]]); XCTAssertEqual(owner.committed, saved)
        XCTAssertEqual(store.saves, [])
        await admission.set(extra.path, .accepted(extra)); owner.refreshNow()
        await settle { owner.watchStatus == .active }
        XCTAssertEqual(watcher.roots.last, [fixed, extra]); XCTAssertEqual(refreshes, [true])
    }

    func testMissingSavedSourceAllowsToggleAndRemovalWithoutReaddingOrDeleting() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        store.result = .loaded(.init(customRootPaths: [extra.path]))
        await admission.set(extra.path, .rejected(.missing))
        var replacements: [[URL]] = [], refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { replacements.append($0) },
            requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }; owner.activate(); await settle { owner.watchStatus == .degraded }
        let toggle = await owner.apply(.init(customRootPaths: [extra.path], automaticRefreshEnabled: false))
        XCTAssertEqual(toggle, .saved); XCTAssertEqual(owner.committed.customRootPaths, [extra.path])
        XCTAssertEqual(owner.watchStatus, .disabled); XCTAssertEqual(refreshes, [])
        let removal = await owner.apply(.init(automaticRefreshEnabled: false))
        XCTAssertEqual(removal, .saved); XCTAssertEqual(replacements.last, [fixed]); XCTAssertEqual(refreshes, [true])
    }

    func testCanonicalSubstitutionCannotBecomeNewWatchedRoot() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        store.result = .loaded(.init(customRootPaths: [extra.path]))
        await admission.set(extra.path, .accepted(URL(fileURLWithPath: "/DifferentApps")))
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { _ in })
        defer { owner.teardown() }; owner.activate(); await settle { owner.watchStatus == .degraded }
        XCTAssertEqual(watcher.roots, [[fixed]]); XCTAssertEqual(owner.committed.customRootPaths, [extra.path])
    }

    func testFutureSchemaReadOnlyAndCorruptStartupNeverRepairsBytes() async {
        for load in [AppSourcesLoadResult.futureVersion(8), .corrupt] {
            let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
            store.result = load
            let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
                fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { _ in })
            owner.activate(); await settle { owner.watchStatus == .active }
            XCTAssertEqual(store.saves, [])
            if case .futureVersion = load {
                let result = await owner.apply(.default); XCTAssertEqual(result, .futureVersion)
                XCTAssertEqual(store.saves, [])
            }
            owner.teardown()
        }
    }

    func testWatchCallbackUsesExistingDebouncedRouteAndStopsAfterDisableOrTeardown() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        var refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { refreshes.append($0) })
        owner.activate(); await settle { owner.watchStatus == .active }
        let callback = watcher.callbacks[0]; callback()
        XCTAssertEqual(refreshes, [false])
        _ = await owner.apply(.init(automaticRefreshEnabled: false)); callback()
        owner.teardown(); owner.teardown(); callback()
        XCTAssertEqual(refreshes, [false]); XCTAssertEqual(owner.watchStatus, .disabled)
    }
    private actor AdmissionGate: AppSourceRootAdmitting {
        private var waiting: CheckedContinuation<AppSourceRootAdmissionResult, Never>?
        private(set) var started = false
        func admit(_ candidate: URL, context: AppSourceRootAdmissionContext) async -> AppSourceRootAdmissionResult {
            started = true
            return await withCheckedContinuation { waiting = $0 }
        }
        func release(_ result: AppSourceRootAdmissionResult) { waiting?.resume(returning: result); waiting = nil }
    }
    func testNewerApplySupersedesOldValidationBeforeAnyOldSave() async {
        let store = Store(), gate = AdmissionGate(), watcher = SourcesWatchFake()
        let owner = AppSourcesCoordinator(store: store, admission: gate, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { _ in })
        defer { owner.teardown() }
        let old = Task { await owner.apply(.init(customRootPaths: [extra.path])) }
        for _ in 0..<1000 { if await gate.started { break }; await Task.yield() }
        let latest = AppSourcesPreferences(automaticRefreshEnabled: false)
        let newer = await owner.apply(latest); XCTAssertEqual(newer, .saved)
        await gate.release(.accepted(extra))
        let result = await old.value; XCTAssertEqual(result, .superseded)
        XCTAssertEqual(store.saves, [latest]); XCTAssertEqual(owner.committed, latest)
    }
    func testTeardownDuringValidationPreventsSaveAndRuntimeCallbacks() async {
        let store = Store(), gate = AdmissionGate(), watcher = SourcesWatchFake()
        let owner = AppSourcesCoordinator(store: store, admission: gate, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in XCTFail("No activation") },
            requestRefresh: { _ in XCTFail("No refresh") })
        let task = Task { await owner.apply(.init(customRootPaths: [extra.path])) }
        for _ in 0..<1000 { if await gate.started { break }; await Task.yield() }
        owner.teardown(); await gate.release(.accepted(extra))
        let result = await task.value; XCTAssertEqual(result, .superseded); XCTAssertEqual(store.saves, [])
    }
    func testPreviousSourceCallbackCannotRefreshAfterRootTransaction() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        var refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }; owner.activate(); await settle { owner.watchStatus == .active }
        let old = watcher.callbacks[0]
        _ = await owner.apply(.init(customRootPaths: [extra.path]))
        old(); XCTAssertEqual(refreshes, [true])
        await settle { watcher.callbacks.count == 2 }
        watcher.callbacks[1](); XCTAssertEqual(refreshes, [true, false])
    }

    func testBackendDegradationDoesNotRecreateNativeStreamOnEveryInvalidation() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        watcher.status = .degraded
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { _ in })
        defer { owner.teardown() }; owner.activate(); await settle { owner.watchStatus == .degraded }
        watcher.callbacks[0]()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(watcher.roots.count, 1); XCTAssertEqual(owner.watchStatus, .degraded)
        watcher.status = .active; owner.refreshNow()
        await settle { owner.watchStatus == .active }; XCTAssertEqual(watcher.roots.count, 2)
    }

    func testFixedRootLossDegradesExistingCoverageUntilExplicitRetryWithoutDeletingReferences() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = SourcesAdmissionFake()
        var replacements: [[URL]] = [], refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { replacements.append($0) },
            requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }
        owner.activate(); await settle { owner.watchStatus == .active }
        let callback = watcher.callbacks[0]
        await admission.set(fixed.path, .rejected(.missing))
        callback()
        await settle { owner.watchStatus == .degraded }
        XCTAssertEqual(watcher.roots, [[fixed]], "An ordinary invalidation must not restart streams")
        XCTAssertEqual(replacements, [[fixed]])
        XCTAssertEqual(owner.committed, .default)
        XCTAssertEqual(store.saves, [])
        XCTAssertEqual(refreshes, [false])

        // Repeated invalidations do not manufacture a new coverage guarantee.
        callback()
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(owner.watchStatus, .degraded)
        XCTAssertEqual(watcher.roots.count, 1)
        await admission.set(fixed.path, .accepted(fixed))
        let previousCalls = await admission.calls.count
        callback()
        for _ in 0..<1000 {
            if await admission.calls.count > previousCalls { break }
            await Task.yield()
        }
        let currentCalls = await admission.calls.count
        XCTAssertGreaterThan(currentCalls, previousCalls, "Returned availability must actually be revalidated")
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(owner.watchStatus, .degraded,
                       "Existence alone does not reattach a lost stream's coverage")
        XCTAssertEqual(watcher.roots.count, 1)

        owner.refreshNow()
        await settle { owner.watchStatus == .active && watcher.roots.count == 2 }
        XCTAssertEqual(watcher.roots, [[fixed], [fixed]])
        XCTAssertEqual(replacements, [[fixed]])
        XCTAssertEqual(store.saves, [])
        XCTAssertEqual(refreshes, [false, false, false, true])
    }

    func testObsoleteFixedRootAvailabilityCannotChangeDisabledCoverage() async {
        let store = Store(), gate = AdmissionGate(), watcher = SourcesWatchFake()
        let owner = AppSourcesCoordinator(store: store, admission: gate, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in }, requestRefresh: { _ in })
        defer { owner.teardown() }
        owner.activate()
        for _ in 0..<1000 { if await gate.started { break }; await Task.yield() }
        let started = await gate.started
        XCTAssertTrue(started, "Fixed-root availability must suspend at the existing admission seam")
        let disabled = AppSourcesPreferences(automaticRefreshEnabled: false)
        let result = await owner.apply(disabled)
        XCTAssertEqual(result, .saved)
        await gate.release(.rejected(.missing))
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(owner.watchStatus, .disabled)
        XCTAssertTrue(watcher.roots.isEmpty, "Obsolete work must not install a stream")
        XCTAssertEqual(owner.committed, disabled)
        XCTAssertEqual(store.saves, [disabled])
    }

    private actor CoverageAdmissionGate: AppSourceRootAdmitting {
        private(set) var calls = 0
        private var result: AppSourceRootAdmissionResult
        private var holdNext = false
        private var waiting: CheckedContinuation<AppSourceRootAdmissionResult, Never>?
        var suspended: Bool { waiting != nil }
        init(root: URL) { result = .accepted(root) }
        func holdNextProbe() { holdNext = true }
        func setResult(_ value: AppSourceRootAdmissionResult) { result = value }
        func release(_ snapshot: AppSourceRootAdmissionResult) {
            let continuation = waiting; waiting = nil
            continuation?.resume(returning: snapshot)
        }
        func admit(_ candidate: URL, context: AppSourceRootAdmissionContext) async -> AppSourceRootAdmissionResult {
            calls += 1
            if holdNext {
                holdNext = false
                return await withCheckedContinuation { waiting = $0 }
            }
            return result
        }
    }

    func testInvalidationDuringCoverageProbeKeepsOneLatestFollowUpWithoutRestartingStream() async {
        let store = Store(), watcher = SourcesWatchFake(), admission = CoverageAdmissionGate(root: fixed)
        var refreshes: [Bool] = []
        let owner = AppSourcesCoordinator(store: store, admission: admission, context: context(),
            fixedRoots: [fixed], watcher: watcher, replaceRoots: { _ in },
            requestRefresh: { refreshes.append($0) })
        defer { owner.teardown() }
        owner.activate(); await settle { owner.watchStatus == .active }
        await admission.holdNextProbe()
        let callback = watcher.callbacks[0]
        callback()
        for _ in 0..<1000 { if await admission.suspended { break }; await Task.yield() }
        let suspended = await admission.suspended
        XCTAssertTrue(suspended)
        await admission.setResult(.rejected(.missing))
        for _ in 0..<8 { callback() }
        // Finish the earlier probe with its stale, formerly valid snapshot.
        await admission.release(.accepted(fixed))
        await settle { owner.watchStatus == .degraded }
        XCTAssertEqual(watcher.roots, [[fixed]])
        let probes = await admission.calls
        XCTAssertEqual(probes, 3, "Startup, held probe, and one coalesced follow-up")
        XCTAssertEqual(store.saves, [])
        XCTAssertEqual(refreshes, Array(repeating: false, count: 9))
    }

}
