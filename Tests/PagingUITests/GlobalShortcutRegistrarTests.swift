//
//  GlobalShortcutRegistrarTests.swift
//  PagingUITests
//
//  Phase 1G T-1G-D：GlobalShortcutRegistering fake 验收。
//  register success/conflict/rollback；unregister；reconfigure 失败保留旧注册；
//  key repeat / debounce 不 spam；无修饰键 → unavailable；不抢真实系统快捷键。
//

import XCTest
@testable import PagingPrototypeApp

final class GlobalShortcutRegistrarTests: XCTestCase {

    private let specA = ShortcutSpec(keyCode: 49, modifiers: [.command, .option]) // Space-ish code, neutral
    private let specB = ShortcutSpec(keyCode: 8, modifiers: [.command, .control])
    private let bareKey = ShortcutSpec(keyCode: 0, modifiers: [])

    private func makeRegistrar(now: TimeInterval = 100) -> FakeGlobalShortcutRegistrar {
        let registrar = FakeGlobalShortcutRegistrar(nowProvider: { now })
        registrar.fireDebounce = 0.25
        return registrar
    }

    // MARK: Register success

    func testRegisterSuccessConfigured() {
        let registrar = makeRegistrar()
        var fired = 0
        registrar.onFired = { fired += 1 }

        let outcome = registrar.register(specA)
        XCTAssertEqual(outcome, .configured)
        XCTAssertTrue(registrar.registration.isConfigured)
        XCTAssertEqual(registrar.registration.spec, specA)
        XCTAssertEqual(registrar.registration.outcome, .configured)

        registrar.simulateFire()
        XCTAssertEqual(fired, 1)
        XCTAssertEqual(registrar.fireDeliveryCount, 1)
    }

    // MARK: Conflict

    func testRegisterConflictKeepsUnconfigured() {
        let registrar = makeRegistrar()
        registrar.conflictingSpecs = [specA]

        let outcome = registrar.register(specA)
        XCTAssertEqual(outcome, .conflict)
        XCTAssertFalse(registrar.registration.isConfigured)
        XCTAssertNil(registrar.registration.spec)
    }

    // MARK: Rollback on reconfigure failure

    func testReconfigureConflictRollsBackToOldSpec() {
        let registrar = makeRegistrar()
        XCTAssertEqual(registrar.register(specA), .configured)

        registrar.conflictingSpecs = [specB]
        let outcome = registrar.reconfigure(specB)
        XCTAssertEqual(outcome, .conflict)
        // 旧注册保留
        XCTAssertEqual(registrar.registration.spec, specA)
        XCTAssertEqual(registrar.registration.outcome, .configured)
        XCTAssertTrue(registrar.registration.isConfigured)
    }

    func testReconfigureUnavailableViaForcedOutcomeRollsBack() {
        let registrar = makeRegistrar()
        XCTAssertEqual(registrar.register(specA), .configured)

        registrar.nextForcedOutcome = .unavailable
        let outcome = registrar.reconfigure(specB)
        XCTAssertEqual(outcome, .unavailable)
        XCTAssertEqual(registrar.registration.spec, specA)
        XCTAssertEqual(registrar.registration.outcome, .configured)
    }

    func testReconfigureSuccessReplacesSpec() {
        let registrar = makeRegistrar()
        XCTAssertEqual(registrar.register(specA), .configured)
        XCTAssertEqual(registrar.reconfigure(specB), .configured)
        XCTAssertEqual(registrar.registration.spec, specB)
        XCTAssertEqual(registrar.registration.outcome, .configured)
    }

    // MARK: Unregister

    func testUnregisterClearsRegistration() {
        let registrar = makeRegistrar()
        XCTAssertEqual(registrar.register(specA), .configured)
        registrar.unregister()
        XCTAssertFalse(registrar.registration.isConfigured)
        XCTAssertNil(registrar.registration.spec)
        XCTAssertNil(registrar.registration.outcome)

        var fired = 0
        registrar.onFired = { fired += 1 }
        registrar.simulateFire()
        XCTAssertEqual(fired, 0, "unregister 后不投递")
    }

    // MARK: Bare key / validation

    func testBareKeyUnavailable() {
        let registrar = makeRegistrar()
        XCTAssertEqual(registrar.register(bareKey), .unavailable)
        XCTAssertFalse(ShortcutSpecValidator.isRegisterable(bareKey))
        XCTAssertTrue(ShortcutSpecValidator.isRegisterable(specA))
    }

    // MARK: Debounce / repeat

    func testKeyRepeatSuppressed() {
        let registrar = makeRegistrar()
        XCTAssertEqual(registrar.register(specA), .configured)
        var fired = 0
        registrar.onFired = { fired += 1 }

        registrar.simulateFire(isRepeat: false)
        registrar.simulateFire(isRepeat: true)
        registrar.simulateFire(isRepeat: true)
        XCTAssertEqual(fired, 1)
        XCTAssertEqual(registrar.suppressedRepeatCount, 2)
    }

    func testDebounceSuppressesRapidFires() {
        var t: TimeInterval = 100
        let registrar = FakeGlobalShortcutRegistrar(nowProvider: { t })
        registrar.fireDebounce = 0.25
        XCTAssertEqual(registrar.register(specA), .configured)
        var fired = 0
        registrar.onFired = { fired += 1 }

        registrar.simulateFire()
        t += 0.1
        registrar.simulateFire()
        XCTAssertEqual(fired, 1)
        XCTAssertEqual(registrar.suppressedRepeatCount, 1)

        t += 0.25
        registrar.simulateFire()
        XCTAssertEqual(fired, 2)
    }

    // MARK: Default Off / no steal

    func testDefaultOffZeroRegistration() {
        let registrar = makeRegistrar()
        XCTAssertFalse(registrar.registration.isConfigured)
        XCTAssertEqual(registrar.registerCallCount, 0)
    }
}
