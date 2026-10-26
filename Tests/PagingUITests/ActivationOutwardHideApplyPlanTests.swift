import XCTest
@testable import PagingPrototypeApp

final class ActivationOutwardHideApplyPlanTests: XCTestCase {
    private func plan(
        from committed: ActivationPreferences, to draft: ActivationPreferencesDraft
    ) throws -> ActivationApplyPlan {
        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            throw PlanningError.invalidPlan
        }
        return plan
    }

    private enum PlanningError: Error { case invalidPlan }

    func testDraftRoundTripKeepsOptionalChoiceEvenWithParentOff() {
        let committed = ActivationPreferences(
            fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true
        )
        let draft = ActivationPreferencesDraft(committed: committed)
        XCTAssertTrue(draft.fourFingerOutwardHideEnabled)
        XCTAssertFalse(draft.fourFingerActivationEnabled)
        XCTAssertEqual(draft.makePreferences(), committed)
        XCTAssertFalse(ActivationPreferencesDraft().fourFingerOutwardHideEnabled)
    }

    func testOutwardOnlyChangesAreReversibleAndNeverNoOpsForEitherParentState() throws {
        for parent in [false, true] {
            for oldChoice in [false, true] {
                let committed = ActivationPreferences(
                    fourFingerActivationEnabled: parent, fourFingerOutwardHideEnabled: oldChoice
                )
                var draft = ActivationPreferencesDraft(committed: committed)
                draft.fourFingerOutwardHideEnabled.toggle()
                let result = try plan(from: committed, to: draft)
                XCTAssertFalse(result.isNoOp)
                XCTAssertEqual(result.steps, [.fourFingerOutwardHide(enabled: !oldChoice)])
                XCTAssertEqual(result.rollbackSteps, [.fourFingerOutwardHide(enabled: oldChoice)])
                XCTAssertEqual(result.steps.map(\.target), [.fourFinger])
                XCTAssertEqual(result.proposed.fourFingerActivationEnabled, parent)
                XCTAssertEqual(result.proposed.fourFingerOutwardHideEnabled, !oldChoice)
            }
        }
    }

    func testUnchangedOptionalChoiceIsNoOpEvenWithParentOff() throws {
        let committed = ActivationPreferences(
            fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true
        )
        let result = try plan(from: committed, to: .init(committed: committed))
        XCTAssertTrue(result.isNoOp)
        XCTAssertEqual(result.proposed, committed)
    }

    func testParentDisableRetainsChoiceWithoutUnnecessaryOutwardStep() throws {
        let committed = ActivationPreferences(fourFingerOutwardHideEnabled: true)
        var draft = ActivationPreferencesDraft(committed: committed)
        draft.fourFingerActivationEnabled = false
        let result = try plan(from: committed, to: draft)
        XCTAssertEqual(result.steps, [.fourFinger(enabled: false)])
        XCTAssertTrue(result.proposed.fourFingerOutwardHideEnabled)
    }

    func testOrderAndFailureMappingDistinguishTwoStepsSharingFourFingerTarget() throws {
        let committed = ActivationPreferences()
        var draft = ActivationPreferencesDraft(committed: committed)
        draft.showStatusItem = false
        draft.fourFingerActivationEnabled = false
        draft.fourFingerOutwardHideEnabled = true
        draft.launchAtLoginEnabled = true
        let result = try plan(from: committed, to: draft)
        XCTAssertEqual(result.steps, [
            .statusItem(show: false), .fourFinger(enabled: false),
            .fourFingerOutwardHide(enabled: true), .launchAtLogin(enabled: true)
        ])
        XCTAssertEqual(result.rollbackSteps, [
            .launchAtLogin(enabled: false), .fourFingerOutwardHide(enabled: false),
            .fourFinger(enabled: true), .statusItem(show: true)
        ])
        let outwardFailure = ActivationApplyPlanner.failureMapping(plan: result, failedAtIndex: 2)
        XCTAssertEqual(outwardFailure.failedStep, .fourFingerOutwardHide(enabled: true))
        XCTAssertEqual(outwardFailure.rollbackSteps, [.fourFinger(enabled: true), .statusItem(show: true)])
        let loginFailure = ActivationApplyPlanner.failureMapping(plan: result, failedAtIndex: 3)
        XCTAssertEqual(loginFailure.rollbackSteps, [
            .fourFingerOutwardHide(enabled: false), .fourFinger(enabled: true), .statusItem(show: true)
        ])
        XCTAssertTrue(loginFailure.restorePreviousAcceptedConfig)
    }


    @MainActor
    func testLoginPartialFailurePreservesAcceptedOutwardChoiceWithParentOff() {
        let committed = ActivationPreferences(fourFingerActivationEnabled: false)
        var draft = ActivationPreferencesDraft(committed: committed)
        draft.fourFingerOutwardHideEnabled = true
        draft.launchAtLoginEnabled = true
        var expected = draft.makePreferences()
        expected.settings.launchAtLoginEnabled = false
        let store = InMemoryActivationPreferencesStore(initial: committed)
        let login = FakeLaunchAtLoginService()
        login.enableSuccessStatus = .requiresApproval
        var applied: [ActivationPreferences] = []
        let result = ActivationApplyTransaction.run(
            committed: committed, draft: draft,
            context: ActivationApplyTransactionContext(
                applyPreferences: { applied.append($0) },
                loginService: login, persist: { store.save($0) }
            )
        )
        XCTAssertEqual(result, .loginNotAccepted(accepted: expected, status: .requiresApproval))
        XCTAssertEqual(store.load(), .loaded(expected))
        XCTAssertEqual(applied, [expected])
        XCTAssertTrue(expected.fourFingerOutwardHideEnabled)
        XCTAssertFalse(expected.fourFingerActivationEnabled)
    }

    @MainActor
    func testOutwardOnlyApplyPersistsWithParentOffAndRefusalRestoresAcceptedChoice() {
        let committed = ActivationPreferences(fourFingerActivationEnabled: false)
        var draft = ActivationPreferencesDraft(committed: committed)
        draft.fourFingerOutwardHideEnabled = true
        let proposed = draft.makePreferences()
        let store = InMemoryActivationPreferencesStore(initial: committed)
        let login = FakeLaunchAtLoginService()
        var applied: [ActivationPreferences] = []
        let context = ActivationApplyTransactionContext(
            applyPreferences: { applied.append($0) },
            loginService: login,
            persist: { store.save($0) }
        )
        XCTAssertEqual(ActivationApplyTransaction.run(committed: committed, draft: draft, context: context),
                       .applied(proposed))
        XCTAssertEqual(applied, [proposed])
        XCTAssertEqual(store.load(), .loaded(proposed))
        XCTAssertEqual(login.setEnabledCallCount, 0)

        applied.removeAll()
        XCTAssertEqual(store.save(committed), .saved)
        store.forcedStoredVersion = 4
        XCTAssertEqual(ActivationApplyTransaction.run(committed: committed, draft: draft, context: context),
                       .persistRefused(storedVersion: 4, acceptedRuntime: committed, runtimeRestored: true))
        XCTAssertEqual(applied, [proposed, committed])
        store.forcedStoredVersion = nil
        XCTAssertEqual(store.load(), .loaded(committed), "Refusal must preserve the stored value")
    }
}
