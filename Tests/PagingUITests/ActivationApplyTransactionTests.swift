//
//  ActivationApplyTransactionTests.swift
//  PagingUITests
//
//  Phase 1H T-1H-B/F：Apply 事务执行（校验 / 持久化 / Fake login 回滚）。
//

import XCTest
@testable import PagingPrototypeApp

@MainActor
final class ActivationApplyTransactionTests: XCTestCase {

    func testInvalidDraftDoesNotPersistOrTouchLogin() {
        let store = InMemoryActivationPreferencesStore()
        let login = FakeLaunchAtLoginService()
        var appliedCount = 0
        let context = ActivationApplyTransactionContext(
            applyPreferences: { _ in appliedCount += 1 },
            loginService: login,
            persist: { store.save($0) }
        )
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.hotCornerEnabled = true
        draft.selectedCorner = nil

        let outcome = ActivationApplyTransaction.run(
            committed: ActivationPreferences(),
            draft: draft,
            context: context
        )
        XCTAssertEqual(outcome, .invalid([.hotCornerMissingSelectedCorner]))
        XCTAssertEqual(appliedCount, 0)
        XCTAssertEqual(login.setEnabledCallCount, 0)
        XCTAssertFalse(login.usesRealLoginItemRegistration)
    }

    func testNoOpWhenUnchanged() {
        let login = FakeLaunchAtLoginService()
        let committed = ActivationPreferences()
        let context = ActivationApplyTransactionContext(
            applyPreferences: { _ in XCTFail("no-op 不应 apply") },
            loginService: login,
            persist: { _ in
                XCTFail("no-op 不应 persist")
                return .saved
            }
        )
        let outcome = ActivationApplyTransaction.run(
            committed: committed,
            draft: ActivationPreferencesDraft(committed: committed),
            context: context
        )
        XCTAssertEqual(outcome, .noOp(committed))
        XCTAssertFalse(login.usesRealLoginItemRegistration)
    }

    func testLoginFailureRollsBackPreferenceBit() {
        let store = InMemoryActivationPreferencesStore()
        let login = FakeLaunchAtLoginService()
        login.nextForcedStatus = .failure(message: "Unable to enable Launch at Login.")
        var lastApplied: ActivationPreferences?
        let context = ActivationApplyTransactionContext(
            applyPreferences: { lastApplied = $0 },
            loginService: login,
            persist: { store.save($0) }
        )
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.launchAtLoginEnabled = true

        let outcome = ActivationApplyTransaction.run(
            committed: ActivationPreferences(),
            draft: draft,
            context: context
        )
        guard case .loginNotAccepted(let accepted, let status) = outcome else {
            return XCTFail("failure 必须 loginNotAccepted，得到 \(outcome)")
        }
        XCTAssertEqual(status, .failure(message: "Unable to enable Launch at Login."))
        XCTAssertFalse(accepted.settings.launchAtLoginEnabled)
        XCTAssertFalse(lastApplied?.settings.launchAtLoginEnabled ?? true)
        XCTAssertFalse(login.usesRealLoginItemRegistration)
    }

    func testIsLoginStatusAcceptableMatrix() {
        XCTAssertTrue(ActivationApplyTransaction.isLoginStatusAcceptable(.enabled, requestedEnabled: true))
        XCTAssertTrue(ActivationApplyTransaction.isLoginStatusAcceptable(.disabled, requestedEnabled: false))
        XCTAssertFalse(ActivationApplyTransaction.isLoginStatusAcceptable(.requiresApproval, requestedEnabled: true))
        XCTAssertFalse(ActivationApplyTransaction.isLoginStatusAcceptable(.unavailable, requestedEnabled: true))
        XCTAssertFalse(ActivationApplyTransaction.isLoginStatusAcceptable(
            .failure(message: "x"), requestedEnabled: true
        ))
    }
}
