import XCTest
@testable import AppGridUI

@MainActor
final class PointerInputDiagnosticsTests: XCTestCase {
    private typealias Diagnostics = PointerInputDiagnostics
    private typealias Event = PointerInputDiagnostics.Event

    // Independent, sorted contract: additions, omissions, and renamed labels must be explicit.
    private let expectedLabels = [
        "b1Down",
        "b1Dragged",
        "b1Up",
        "blankHit",
        "cancelCatalogRefresh",
        "cancelEscape",
        "cancelLayoutChanged",
        "cancelOverlayClosed",
        "cancelSearchActivated",
        "cancelSecondDrag",
        "cancelTeardown",
        "cancelTitleEditBegan",
        "cancelWindowResign",
        "clickOnly",
        "clicked",
        "committed",
        "coordinatorDown",
        "dragBegan",
        "dragGateDenied",
        "folderNativeDown",
        "geometryMissing",
        "interactionControl",
        "layoutCommitDenied",
        "layoutMissing",
        "leadingLibraryConsumed",
        "libraryConsumed",
        "movementProcessed",
        "noOp",
        "overlayBlank",
        "overlayDown",
        "overlayMember",
        "overlayNonMember",
        "overlayTransitionDenied",
        "overlayUnavailableDenied",
        "pointerDragged",
        "pointerUp",
        "pressed",
        "rejected",
        "releaseDisplaced",
        "releaseWhilePressed",
        "releaseWithoutTransaction",
        "searchActiveDenied",
        "sourceMissing",
        "sourceStale",
        "titleDismissed",
        "titleEditingDenied",
        "visualHostMissing",
        "windowDown",
        "windowDragged",
        "windowKeyActive",
        "windowKeyInactive",
        "windowNotKeyActive",
        "windowNotKeyInactive",
        "windowUp",
    ]

    func testDefaultIsDisabledAndRecordingDoesNotAccumulate() {
        // Check the actual default before changing the setting in this test.
        defer {
            Diagnostics.setEnabled(false)
            Diagnostics.reset()
        }
        XCTAssertFalse(Diagnostics.isEnabled)
        for event in Event.allCases {
            Diagnostics.record(event)
            XCTAssertEqual(Diagnostics.count(event), 0)
        }
        for reason in DragCancelReason.allCases {
            Diagnostics.recordCancellation(reason)
        }
        XCTAssertFalse(Diagnostics.isEnabled)
        XCTAssertEqual(Diagnostics.report(), expectedReport(enabled: false, total: 0))
    }

    func testRecordingChangesOnlySelectedCounters() {
        withEnabledDiagnostics {
            Diagnostics.record(.windowDown)
            Diagnostics.record(.windowDown)
            Diagnostics.record(.pointerDragged)

            XCTAssertEqual(Diagnostics.count(.windowDown), 2)
            XCTAssertEqual(Diagnostics.count(.pointerDragged), 1)
            XCTAssertEqual(Diagnostics.count(.windowUp), 0)
            XCTAssertEqual(Diagnostics.report(), expectedReport(
                enabled: true, total: 3, counts: [.windowDown: 2, .pointerDragged: 1]
            ))
        }
    }

    func testResetClearsEveryCounterAndPreservesOptIn() {
        withEnabledDiagnostics {
            for event in Event.allCases {
                Diagnostics.record(event)
            }
            Diagnostics.reset()

            XCTAssertTrue(Diagnostics.isEnabled)
            for event in Event.allCases {
                XCTAssertEqual(Diagnostics.count(event), 0)
            }
            XCTAssertEqual(Diagnostics.report(), expectedReport(enabled: true, total: 0))

            Diagnostics.record(.pressed)
            XCTAssertEqual(Diagnostics.count(.pressed), 1)
        }
    }

    func testResetWhileDisabledPreservesDisabledState() {
        Diagnostics.setEnabled(false)
        Diagnostics.reset()
        XCTAssertFalse(Diagnostics.isEnabled)
        Diagnostics.record(.windowDown)
        XCTAssertEqual(Diagnostics.report(), expectedReport(enabled: false, total: 0))
    }

    func testBothToggleDirectionsClearCountersAndDisabledRecordingIsIgnored() {
        withEnabledDiagnostics {
            for event in Event.allCases {
                Diagnostics.record(event)
            }
            Diagnostics.setEnabled(false)
            XCTAssertFalse(Diagnostics.isEnabled)
            for event in Event.allCases {
                XCTAssertEqual(Diagnostics.count(event), 0)
                Diagnostics.record(event)
            }
            for reason in DragCancelReason.allCases {
                Diagnostics.recordCancellation(reason)
            }
            XCTAssertEqual(Diagnostics.report(), expectedReport(enabled: false, total: 0))

            Diagnostics.setEnabled(true)
            XCTAssertTrue(Diagnostics.isEnabled)
            XCTAssertEqual(Diagnostics.report(), expectedReport(enabled: true, total: 0))
            Diagnostics.record(.pointerUp)
            XCTAssertEqual(Diagnostics.count(.pointerUp), 1)
        }
    }

    func testReapplyingCurrentSettingDoesNotDiscardCounters() {
        withEnabledDiagnostics {
            Diagnostics.record(.dragBegan)
            let enabledReport = Diagnostics.report()
            Diagnostics.setEnabled(true)
            XCTAssertEqual(Diagnostics.count(.dragBegan), 1)
            XCTAssertEqual(Diagnostics.report(), enabledReport)

            Diagnostics.setEnabled(false)
            let disabledReport = Diagnostics.report()
            Diagnostics.setEnabled(false)
            XCTAssertEqual(Diagnostics.report(), disabledReport)
        }
    }

    func testEventLabelsExactlyMatchTheFiniteContract() {
        let labels = Event.allCases.map(\.rawValue)
        XCTAssertEqual(labels.count, 54)
        XCTAssertEqual(Set(labels).count, labels.count)
        XCTAssertEqual(labels.sorted(), expectedLabels)
    }

    func testUnknownLabelsAndPayloadBearingStringsAreNotEvents() {
        for label in ["", "unknown", "cancelUnknown", "windowDown=2", "windowDown\npointerUp"] {
            XCTAssertNil(Event(rawValue: label))
        }
    }

    func testCancellationReasonsHaveExhaustiveFixedMappings() {
        let mappings: [(DragCancelReason, Event)] = [
            (.escape, .cancelEscape),
            (.windowResign, .cancelWindowResign),
            (.catalogRefresh, .cancelCatalogRefresh),
            (.searchActivated, .cancelSearchActivated),
            (.titleEditBegan, .cancelTitleEditBegan),
            (.overlayClosed, .cancelOverlayClosed),
            (.teardown, .cancelTeardown),
            (.secondDrag, .cancelSecondDrag),
            (.layoutChanged, .cancelLayoutChanged),
        ]
        XCTAssertEqual(mappings.map { $0.0 }, DragCancelReason.allCases)

        withEnabledDiagnostics {
            for (reason, event) in mappings {
                Diagnostics.recordCancellation(reason)
                XCTAssertEqual(Diagnostics.count(event), 1)
            }
            let expectedCounts = Dictionary(uniqueKeysWithValues: mappings.map {
                ($0.1, UInt64(1))
            })
            for event in Event.allCases {
                XCTAssertEqual(Diagnostics.count(event), expectedCounts[event, default: 0])
            }
            XCTAssertEqual(Diagnostics.report(), expectedReport(
                enabled: true, total: UInt64(mappings.count), counts: expectedCounts
            ))
        }
    }

    func testReportIsSortedAndContainsOnlyFixedLabelsAndUnsignedIntegers() {
        withEnabledDiagnostics {
            for event in Event.allCases.reversed() {
                Diagnostics.record(event)
                Diagnostics.record(event)
            }
            let expectedCounts = Dictionary(uniqueKeysWithValues: Event.allCases.map {
                ($0, UInt64(2))
            })
            let snapshot = Diagnostics.report()
            XCTAssertEqual(snapshot, expectedReport(
                enabled: true, total: UInt64(expectedLabels.count * 2), counts: expectedCounts
            ))
            XCTAssertEqual(Diagnostics.report(), snapshot)

            let rows = snapshot.split(separator: "\n", omittingEmptySubsequences: false)
            let labels = ["enabled", "total"] + expectedLabels
            XCTAssertEqual(rows.count, labels.count)
            for (row, label) in zip(rows, labels) {
                let parts = row.split(separator: "=", omittingEmptySubsequences: false)
                XCTAssertEqual(parts.count, 2)
                guard parts.count == 2 else { continue }
                XCTAssertEqual(String(parts[0]), label)
                XCTAssertFalse(parts[1].isEmpty)
                XCTAssertTrue(parts[1].utf8.allSatisfy { $0 >= 48 && $0 <= 57 })
                XCTAssertNotNil(UInt64(parts[1]))
            }
            for event in Event.allCases {
                XCTAssertEqual(Diagnostics.count(event), 2)
            }
        }
    }

    func testReportIsAnIndependentValueSnapshot() {
        withEnabledDiagnostics {
            Diagnostics.record(.windowDown)
            let captured = Diagnostics.report()
            let expected = expectedReport(enabled: true, total: 1, counts: [.windowDown: 1])
            XCTAssertEqual(captured, expected)

            Diagnostics.record(.windowDown)
            Diagnostics.recordCancellation(.escape)
            XCTAssertEqual(Diagnostics.count(.windowDown), 2)
            XCTAssertEqual(Diagnostics.count(.cancelEscape), 1)
            XCTAssertNotEqual(Diagnostics.report(), captured)
            XCTAssertEqual(captured, expected)

            Diagnostics.reset()
            Diagnostics.setEnabled(false)
            XCTAssertEqual(captured, expected)
            XCTAssertEqual(Diagnostics.report(), expectedReport(enabled: false, total: 0))
        }
    }

    func testSaturatingArithmeticNeverWrapsOrMutatesDiagnostics() {
        withEnabledDiagnostics {
            Diagnostics.record(.committed)
            let before = Diagnostics.report()
            let cases: [(UInt64, UInt64, UInt64)] = [
                (0, 0, 0),
                (0, 1, 1),
                (41, 1, 42),
                (.max - 1, 1, .max),
                (.max - 1, 2, .max),
                (.max, 0, .max),
                (.max, 1, .max),
                (.max, .max, .max),
            ]
            for (value, increment, expected) in cases {
                XCTAssertEqual(Diagnostics.saturatingAdd(value, increment), expected)
            }
            XCTAssertEqual(Diagnostics.report(), before)
            XCTAssertEqual(Diagnostics.count(.committed), 1)
        }
    }

    private func withEnabledDiagnostics(_ body: () -> Void) {
        Diagnostics.setEnabled(false)
        Diagnostics.reset()
        defer {
            Diagnostics.setEnabled(false)
            Diagnostics.reset()
        }
        Diagnostics.setEnabled(true)
        body()
    }

    private func expectedReport(
        enabled: Bool,
        total: UInt64,
        counts: [Event: UInt64] = [:]
    ) -> String {
        let rows = expectedLabels.map { label in
            let value = counts.first(where: { $0.key.rawValue == label })?.value ?? 0
            return "\(label)=\(value)"
        }
        return (["enabled=\(enabled ? 1 : 0)", "total=\(total)"] + rows).joined(separator: "\n")
    }
}
