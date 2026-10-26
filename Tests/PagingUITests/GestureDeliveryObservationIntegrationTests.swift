import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class GestureDeliveryObservationIntegrationTests: XCTestCase {
    private func owner(_ clock: FakePinchClock) -> ActivationComposition {
        let launcher = LauncherWindowController(coordinator: .init(initialState: .visible(screenID: .init(index: 0))),
                                                reduceMotionProvider: { true })
        let result = ActivationComposition(launcher: launcher, pinchClock: clock)
        result.attachTouchProvider(MockTouchProvider(clock: clock), userEnabled: true)
        result.applyPreferences(.init(fourFingerOutwardHideEnabled: true))
        result.canHideFromFourFinger = { true }
        return result
    }
    func testDefaultOffAndExplicitObservationDoNotChangeHideDecision() throws {
        for enabled in [false, true] {
            let clock = FakePinchClock()
            let observed = owner(clock)
            defer { observed.teardownActivationServices() }
            XCTAssertNil(observed.gestureDeliveryObservation)
            if enabled { observed.startGestureDeliveryObservation() }
            _ = observed.processFourFingerFrame(frame(.init(rawValue: 1), 0, .began, squareContacts(halfSize: 0.2)))
            clock.current = 0.1
            let effects = observed.processFourFingerFrame(frame(.init(rawValue: 1), 0.1, .moved, squareContacts(halfSize: 0.25)))
            XCTAssertEqual(effects.count, 1)
            XCTAssertEqual(observed.launcher.coordinator.state, .hidden)
            XCTAssertNil(observed.launcher.window)
            if enabled {
                let counters = try XCTUnwrap(observed.gestureDeliveryObservation)
                XCTAssertEqual(counters.frames, 2)
                XCTAssertEqual(counters.fourContactFrames, 2)
                XCTAssertEqual(counters.admittedFourContactFrames, 2)
                XCTAssertEqual(counters.hideEvents, 1)
                XCTAssertEqual(counters.acceptedHides, 1)
            } else { XCTAssertNil(observed.gestureDeliveryObservation) }
        }
    }
    func testFutureAndPreModeCutoffAreCountedBeforeTheirExistingRejection() throws {
        let clock = FakePinchClock(); clock.current = 10
        let observed = owner(clock); defer { observed.teardownActivationServices() }
        observed.startGestureDeliveryObservation()
        _ = observed.processFourFingerFrame(frame(.init(rawValue: 1), 9, .began, squareContacts(halfSize: 0.2)))
        _ = observed.processFourFingerFrame(frame(.init(rawValue: 2), 11, .began, squareContacts(halfSize: 0.2)))
        let counts = try XCTUnwrap(observed.gestureDeliveryObservation)
        XCTAssertEqual(counts.frames, 2)
        XCTAssertEqual(counts.preCutoffFrames, 1)
        XCTAssertEqual(counts.futureFrames, 1)
        XCTAssertEqual(counts.hideEvents, 0)
        XCTAssertEqual(observed.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        observed.startGestureDeliveryObservation()
        XCTAssertEqual(observed.gestureDeliveryObservation?.frames, 0)
        observed.stopGestureDeliveryObservation()
        XCTAssertNil(observed.gestureDeliveryObservation)
        observed.startGestureDeliveryObservation()
        observed.teardownActivationServices()
        XCTAssertNil(observed.gestureDeliveryObservation)
        observed.startGestureDeliveryObservation()
        XCTAssertNil(observed.gestureDeliveryObservation)
    }
    func testDiagnosticMenuOnlyExistsInDedicatedGestureEntry() {
        _ = NSApplication.shared
        for dedicated in [false, true] {
            var options = AppArguments.Options.default
            options.gestureValidation = dedicated
            let host = AppDelegate(options: options)
            let menu = NSMenu()
            host.installGestureValidationObservationMenu(in: menu)
            XCTAssertEqual(menu.items.count, dedicated ? 3 : 0)
            if dedicated {
                XCTAssertEqual(menu.items.map { $0.identifier?.rawValue },
                    ["diagnostics.fourFinger.start", "diagnostics.fourFinger.report", "diagnostics.fourFinger.stop"])
            }
        }
    }
}
