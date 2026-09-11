//
//  LaunchAtLoginServiceTests.swift
//  PagingUITests
//
//  Phase 1H T-1H-C：LaunchAtLoginServicing Fake 验收。
//  仅 Fake；覆盖 enable/disable/failure/requiresApproval；断言永不触达真实 SMAppService。
//

import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {

    // MARK: - Default off / Fake isolation

    func testDefaultStatusIsDisabled() {
        let service = FakeLaunchAtLoginService()
        XCTAssertEqual(service.currentStatus(), .disabled)
        XCTAssertFalse(service.usesRealLoginItemRegistration,
                       "Fake must never touch real SMAppService login-item registration")
    }

    func testFakeNeverUsesRealLoginItemRegistrationAcrossMutations() {
        let service = FakeLaunchAtLoginService()
        _ = service.setEnabled(true)
        _ = service.setEnabled(false)
        service.nextForcedStatus = .failure(message: "forced")
        _ = service.setEnabled(true)
        service.nextForcedStatus = .requiresApproval
        _ = service.setEnabled(true)
        service.nextForcedStatus = .unavailable
        _ = service.setEnabled(true)

        XCTAssertFalse(service.usesRealLoginItemRegistration,
                       "Fake mutations must not flip usesRealLoginItemRegistration")
        XCTAssertGreaterThanOrEqual(service.setEnabledCallCount, 5)
    }

    // MARK: - Enable / disable

    func testEnableSetsEnabled() {
        let service = FakeLaunchAtLoginService()
        let status = service.setEnabled(true)
        XCTAssertEqual(status, .enabled)
        XCTAssertEqual(service.currentStatus(), .enabled)
        XCTAssertEqual(service.lastRequestedEnabled, true)
        XCTAssertEqual(service.setEnabledCallCount, 1)
    }

    func testDisableSetsDisabled() {
        let service = FakeLaunchAtLoginService(initialStatus: .enabled)
        let status = service.setEnabled(false)
        XCTAssertEqual(status, .disabled)
        XCTAssertEqual(service.currentStatus(), .disabled)
        XCTAssertEqual(service.lastRequestedEnabled, false)
    }

    func testDisableFromRequiresApprovalReturnsDisabled() {
        let service = FakeLaunchAtLoginService(initialStatus: .requiresApproval)
        XCTAssertEqual(service.setEnabled(false), .disabled)
        XCTAssertEqual(service.currentStatus(), .disabled)
    }

    // MARK: - requiresApproval mapping

    func testEnableCanMapToRequiresApproval() {
        let service = FakeLaunchAtLoginService()
        service.enableSuccessStatus = .requiresApproval
        let status = service.setEnabled(true)
        XCTAssertEqual(status, .requiresApproval)
        XCTAssertEqual(service.currentStatus(), .requiresApproval)
    }

    func testForcedRequiresApprovalOnEnable() {
        let service = FakeLaunchAtLoginService()
        service.nextForcedStatus = .requiresApproval
        XCTAssertEqual(service.setEnabled(true), .requiresApproval)
        // Forced outcome is one-shot.
        XCTAssertNil(service.nextForcedStatus)
        XCTAssertEqual(service.setEnabled(true), .enabled)
    }

    // MARK: - failure / unavailable

    func testForcedFailurePreservesFailureStatus() {
        let service = FakeLaunchAtLoginService()
        let message = "Unable to enable Launch at Login."
        service.nextForcedStatus = .failure(message: message)
        let status = service.setEnabled(true)
        XCTAssertEqual(status, .failure(message: message))
        XCTAssertEqual(service.currentStatus(), .failure(message: message))
        // Neutral message: no path / secret markers.
        if case let .failure(msg) = status {
            XCTAssertFalse(msg.contains("/"))
            XCTAssertFalse(msg.lowercased().contains("password"))
            XCTAssertFalse(msg.lowercased().contains("token"))
        } else {
            XCTFail("expected failure")
        }
    }

    func testForcedUnavailable() {
        let service = FakeLaunchAtLoginService()
        service.nextForcedStatus = .unavailable
        XCTAssertEqual(service.setEnabled(true), .unavailable)
        XCTAssertEqual(service.currentStatus(), .unavailable)
    }

    // MARK: - Production status mapping (pure; no register/unregister)

    func testMapStatusCoversAllKnownSMAppServiceCases() {
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.mapStatus(.notRegistered), .disabled)
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.mapStatus(.enabled), .enabled)
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.mapStatus(.requiresApproval), .requiresApproval)
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.mapStatus(.notFound), .unavailable)
    }

    func testNeutralFailureMessageHasNoSecrets() {
        struct ProbeError: Error {}
        let enableMsg = SMAppServiceLaunchAtLoginService.neutralFailureMessage(
            for: ProbeError(), enabling: true
        )
        let disableMsg = SMAppServiceLaunchAtLoginService.neutralFailureMessage(
            for: ProbeError(), enabling: false
        )
        XCTAssertEqual(enableMsg, "Unable to enable Launch at Login.")
        XCTAssertEqual(disableMsg, "Unable to disable Launch at Login.")
        for msg in [enableMsg, disableMsg] {
            XCTAssertFalse(msg.contains("/"))
            XCTAssertFalse(msg.contains("file://"))
            XCTAssertFalse(msg.lowercased().contains("password"))
            XCTAssertFalse(msg.lowercased().contains("secret"))
        }
    }

    func testProductionAdapterDeclaresRealRegistration() {
        // Construct only — do NOT call setEnabled (would touch real login items).
        let adapter = SMAppServiceLaunchAtLoginService()
        XCTAssertTrue(adapter.usesRealLoginItemRegistration)
    }
}
