import AppGridUI
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class WorkspaceQuitCoordinatorTests: XCTestCase {
    private func waitForDecision(_ coordinator: WorkspaceQuitCoordinator) async {
        for _ in 0..<1000 { if coordinator.phase != .draining { return }; await Task.yield() }
        XCTFail("Quit drain did not complete")
    }

    func testSuccessApprovesOnceAndDuplicateRequestsDoNotRepeatDrain() async {
        for result in [LayoutStoreFlushResult.nothingPending, .persisted(writeGeneration: 4)] {
            let coordinator = WorkspaceQuitCoordinator()
            var drains = 0, replies: [Bool] = [], prompts = 0
            let drain: () async -> LayoutStoreFlushResult = { drains += 1; return result }
            coordinator.request(drain: drain, chooseOnFailure: { _, _ in prompts += 1 }, reply: { replies.append($0) })
            coordinator.request(drain: drain, chooseOnFailure: { _, _ in prompts += 1 }, reply: { replies.append($0) })
            XCTAssertTrue(coordinator.isPending)
            await waitForDecision(coordinator)
            XCTAssertEqual(coordinator.phase, .approved)
            XCTAssertEqual(replies, [true]); XCTAssertEqual(drains, 1); XCTAssertEqual(prompts, 0)
        }
    }

    func testEveryUnsuccessfulOutcomeWaitsForExplicitChoiceAndCancelAllowsRetry() async throws {
        for result in [LayoutStoreFlushResult.failed, .timedOut, .readOnly, .staleRejected, .rejectedOverLimit] {
            let coordinator = WorkspaceQuitCoordinator()
            var replies: [Bool] = [], decision: ((Bool) -> Void)?
            coordinator.request(drain: { result }, chooseOnFailure: { value, callback in
                XCTAssertEqual(value, result); decision = callback
            }, reply: { replies.append($0) })
            await waitForDecision(coordinator)
            XCTAssertEqual(coordinator.phase, .awaitingDecision); XCTAssertTrue(replies.isEmpty)
            let choose = try XCTUnwrap(decision)
            choose(false); choose(true)
            XCTAssertEqual(replies, [false]); XCTAssertEqual(coordinator.phase, .idle)
            coordinator.request(drain: { .nothingPending }, chooseOnFailure: { _, _ in XCTFail() },
                                reply: { replies.append($0) })
            await waitForDecision(coordinator)
            XCTAssertEqual(replies, [false, true])
        }
    }

    func testQuitAnywayIsExplicitAndLateOldDialogCannotDecideNewAttempt() async throws {
        let coordinator = WorkspaceQuitCoordinator()
        var oldDecision: ((Bool) -> Void)?, newDecision: ((Bool) -> Void)?, replies: [Bool] = []
        coordinator.request(drain: { .failed }, chooseOnFailure: { _, choice in oldDecision = choice },
                            reply: { replies.append($0) })
        await waitForDecision(coordinator)
        coordinator.cancelPending()
        coordinator.request(drain: { .timedOut }, chooseOnFailure: { _, choice in newDecision = choice },
                            reply: { replies.append($0) })
        await waitForDecision(coordinator)
        try XCTUnwrap(oldDecision)(true)
        XCTAssertEqual(replies, [false]); XCTAssertEqual(coordinator.phase, .awaitingDecision)
        try XCTUnwrap(newDecision)(true)
        XCTAssertEqual(replies, [false, true]); XCTAssertEqual(coordinator.phase, .approved)
    }

    func testTeardownInvalidatesPendingDrainWithoutReplyOrPrompt() async {
        let coordinator = WorkspaceQuitCoordinator()
        var release: CheckedContinuation<LayoutStoreFlushResult, Never>?, replies = 0, prompts = 0
        coordinator.request(drain: { await withCheckedContinuation { release = $0 } },
                            chooseOnFailure: { _, _ in prompts += 1 }, reply: { _ in replies += 1 })
        for _ in 0..<1000 { if release != nil { break }; await Task.yield() }
        XCTAssertNotNil(release)
        coordinator.cancelPending(replyCancellation: false)
        release?.resume(returning: .failed)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(replies, 0); XCTAssertEqual(prompts, 0); XCTAssertEqual(coordinator.phase, .idle)
    }
}
