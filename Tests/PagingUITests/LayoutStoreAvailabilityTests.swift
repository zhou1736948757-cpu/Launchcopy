import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LayoutStoreAvailabilityTests: XCTestCase {
    private enum ResolutionError: Error { case unavailable }
    private struct ThrowingDirectory: LayoutStoreDirectoryProviding {
        func resolveStoreDirectory() throws -> URL { throw ResolutionError.unavailable }
    }
    private struct FixedDirectory: LayoutStoreDirectoryProviding {
        let url: URL
        func resolveStoreDirectory() throws -> URL { url }
    }
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-layout-availability-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func layout() -> PersistentWorkspaceLayout {
        .init(generation: LayoutGeneration(1), topLevelOrder: [], folders: [])
    }
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath,
                           line: UInt = #line) async throws {
        let clock = ContinuousClock(), deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), clock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    func testFailedProductionResolutionHasNoJournalBackendAndPreservesOwnedSentinels() async throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("another-program.tmp")
        let directory = root.appendingPathComponent("another-program-directory.tmp")
        try Data("sentinel".utf8).write(to: file)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let before = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let store = owner.makeLayoutStore(directoryProvider: ThrowingDirectory())
        XCTAssertTrue(store is UnavailableLayoutStore)
        XCTAssertNotEqual(store.storeDirectory, FileManager.default.temporaryDirectory)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .readOnlyProtection(.storageUnavailable))
        await store.enqueue(layout())
        let flushed = await store.flush(), reset = await store.reset(defaultLayout: layout())
        let state = await store.currentState(), mode = await store.lockMode()
        XCTAssertEqual(flushed, .readOnly)
        XCTAssertEqual(reset, .failed)
        XCTAssertEqual(state, .readOnlyProtection(.storageUnavailable))
        XCTAssertEqual(mode, .unavailable)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), before)
        XCTAssertEqual(try Data(contentsOf: file), Data("sentinel".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func testInstalledUnavailableStorePublishesReadOnlyStateWithoutClaimingHealthy() async throws {
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let store = owner.makeLayoutStore(directoryProvider: ThrowingDirectory())
        owner.installLayoutStore(store)
        try await waitUntil { !owner.isRestoringLayout }
        XCTAssertEqual(owner.layoutPersistenceState, .readOnlyProtection(.storageUnavailable))
        XCTAssertFalse(owner.canCommitWorkspaceLayout)
        let result = await store.flush()
        XCTAssertEqual(result, .readOnly)
    }

    func testResolvedDedicatedStoreStillPersistsAndReopens() async throws {
        let root = try temporaryRoot(), destination = root.appendingPathComponent("DedicatedLayout")
        let owner = AppDelegate(options: try AppArguments.parse([]).get())
        let store = owner.makeLayoutStore(directoryProvider: FixedDirectory(url: destination))
        XCTAssertTrue(store is LayoutStoreActor)
        XCTAssertEqual(store.storeDirectory, destination)
        _ = await store.load()
        await store.enqueue(layout())
        let result = await store.flush()
        // The owned writer can finish before flush starts; nothingPending is
        // valid only together with the independent durable reopen assertion below.
        switch result {
        case .persisted, .nothingPending: break
        default: return XCTFail("Dedicated store did not persist: \(result)")
        }
        let reopened = LayoutStoreActor(storeDirectory: destination)
        let loaded = await reopened.load()
        guard case .loaded(let actual, _) = loaded else { return XCTFail("Dedicated store did not restore") }
        XCTAssertEqual(actual, layout())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["DedicatedLayout"])
    }

    func testConfiguredTestProfileNeverUsesProductionResolver() async throws {
        let root = try temporaryRoot(), bundle = root.appendingPathComponent(".build/candidates/owned/LaunchcopyUITest.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let options = try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "storage"]).get()
        let owner = AppDelegate(options: options)
        try owner.configureUITestProfile(bundleURL: bundle)
        let profile = try XCTUnwrap(owner.uiTestProfile)
        let store = owner.makeLayoutStore(directoryProvider: ThrowingDirectory())
        XCTAssertTrue(store is LayoutStoreActor)
        XCTAssertEqual(store.storeDirectory, profile.layoutDirectoryURL)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .firstLaunch)
    }

    func testUnconfiguredIsolatedRequestNeverFallsBackToAProductionDirectory() async throws {
        let root = try temporaryRoot(), destination = root.appendingPathComponent("MustNotOpen")
        let options = try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "storage"]).get()
        let owner = AppDelegate(options: options)
        let store = owner.makeLayoutStore(directoryProvider: FixedDirectory(url: destination))
        XCTAssertTrue(store is UnavailableLayoutStore)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .readOnlyProtection(.storageUnavailable))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testUnavailableFlushKeepsQuitDecisionExplicitAndCancellationWins() async throws {
        let store = UnavailableLayoutStore(), coordinator = WorkspaceQuitCoordinator()
        var result: LayoutStoreFlushResult?, choose: ((Bool) -> Void)?, replies: [Bool] = []
        coordinator.request(drain: { await store.flush() }, chooseOnFailure: { value, decision in
            result = value; choose = decision
        }, reply: { replies.append($0) })
        try await waitUntil { coordinator.phase == .awaitingDecision }
        XCTAssertEqual(result, .readOnly)
        XCTAssertTrue(replies.isEmpty)
        let cancel = try XCTUnwrap(choose)
        cancel(false)
        XCTAssertEqual(replies, [false])
        XCTAssertEqual(coordinator.phase, .idle)
    }
}
