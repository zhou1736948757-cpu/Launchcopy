import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LibraryEntryProfileTests: XCTestCase {
    // Decode independently of the recorder's private storage types.
    private struct Snapshot: Decodable, Equatable {
        struct Sample: Decodable, Equatable {
            let tag: String
            let timestampNS: UInt64
            let durationNS: UInt64
            let count: Int
        }
        let schemaVersion: Int
        let sampleLimit: Int
        let droppedSamples: Int
        let samples: [Sample]
    }

    private func snapshot(_ recorder: LibraryEntryProfile) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: recorder.encodedSnapshot())
    }

    func testEmptySnapshotHasExactEnvelopeAndDoesNotReadClock() throws {
        var reads = 0
        let recorder = LibraryEntryProfile(now: { reads += 1; return 100 })
        let data = try recorder.encodedSnapshot()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "sampleLimit", "droppedSamples", "samples"])
        XCTAssertEqual(try snapshot(recorder), Snapshot(
            schemaVersion: 1, sampleLimit: 8192, droppedSamples: 0, samples: []
        ))
        XCTAssertEqual(reads, 1, "Only initialization samples the baseline")
    }

    func testIntervalAndMarkHaveExactRelativeNanosecondsAndCounts() throws {
        var clock: UInt64 = 100
        let recorder = LibraryEntryProfile(now: { clock })
        clock = 130
        let start = recorder.begin()
        XCTAssertEqual(start, 130)
        XCTAssertTrue(try snapshot(recorder).samples.isEmpty)
        clock = 195
        recorder.end(.entry, since: start, count: 7)
        clock = 210
        recorder.mark(.projectionDelivered, count: 4)
        clock = 220
        recorder.mark(.runLoopBeforeWaiting)
        XCTAssertEqual(try snapshot(recorder).samples, [
            .init(tag: "entry", timestampNS: 95, durationNS: 65, count: 7),
            .init(tag: "projectionDelivered", timestampNS: 110, durationNS: 0, count: 4),
            .init(tag: "runLoopBeforeWaiting", timestampNS: 120, durationNS: 0, count: 0)
        ])
    }

    func testFixedTagsRoundTripAndSamplesContainOnlyAllowedFields() throws {
        let expected = [
            "shellConstruction", "entry", "renderProjection", "viewApply", "viewLayout", "viewFocus",
            "galleryApply", "galleryLayout", "cardLayout", "galleryIcons", "parentBegin", "parentInput",
            "parentFrame", "parentRender", "parentCommit", "projectionRequested",
            "projectionDelivered", "materialPolicy", "iconDelivery", "runLoopEntry",
            "runLoopExit", "runLoopBeforeWaiting", "runLoopAfterWaiting",
            "preparedCardsReady", "preparedCardsConsumed", "idleDisplay", "idleDisplayReady", "idleLayerPreparation", "idleControlDisplay", "idleIconPrefetch"
        ]
        XCTAssertEqual(LibraryEntryProfile.Event.allCases.map(\.rawValue), expected)
        let recorder = LibraryEntryProfile(now: { 10 })
        for event in LibraryEntryProfile.Event.allCases {
            let data = try JSONEncoder().encode(event)
            XCTAssertEqual(try JSONDecoder().decode(LibraryEntryProfile.Event.self, from: data), event)
            recorder.mark(event)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(
            LibraryEntryProfile.Event.self, from: Data("\"unknown\"".utf8)
        ))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: recorder.encodedSnapshot()) as? [String: Any]
        )
        let samples = try XCTUnwrap(object["samples"] as? [[String: Any]])
        XCTAssertEqual(samples.count, expected.count)
        for (sample, tag) in zip(samples, expected) {
            // Exact equality rejects additional privacy-bearing fields or nested payloads.
            XCTAssertEqual(sample as NSDictionary, [
                "tag": tag, "timestampNS": 0, "durationNS": 0, "count": 0
            ] as NSDictionary)
        }
    }

    func testCapacityKeepsFirstSamplesAndCountsEveryDroppedEndOrMark() throws {
        var clock: UInt64 = 0
        let recorder = LibraryEntryProfile(capacity: 2, now: { clock })
        let start = recorder.begin()
        clock = 5
        recorder.mark(.shellConstruction)
        clock = 10
        recorder.end(.entry, since: start)
        let accepted = try snapshot(recorder).samples
        for _ in 0..<3 { recorder.mark(.iconDelivery) }
        for _ in 0..<4 { recorder.end(.galleryIcons, since: start) }
        let result = try snapshot(recorder)
        XCTAssertEqual(result.sampleLimit, 2)
        XCTAssertEqual(result.samples, accepted)
        XCTAssertEqual(result.samples.map(\.tag), ["shellConstruction", "entry"])
        XCTAssertEqual(result.droppedSamples, 7)
        XCTAssertEqual(result.samples.count + result.droppedSamples, 9)
    }

    func testDefaultAndOversizedCapacitiesNeverExceed8192() throws {
        let recorders = [
            LibraryEntryProfile(now: { 0 }),
            LibraryEntryProfile(capacity: 8193, now: { 0 }),
            LibraryEntryProfile(capacity: Int.max, now: { 0 })
        ]
        for recorder in recorders {
            for _ in 0..<8195 { recorder.mark(.parentFrame) }
            let result = try snapshot(recorder)
            XCTAssertEqual(result.sampleLimit, 8192)
            XCTAssertEqual(result.samples.count, 8192)
            XCTAssertEqual(result.droppedSamples, 3)
        }
    }

    func testZeroAndNegativeCapacitiesDropEverySampleButNotBegin() throws {
        for capacity in [0, -1, Int.min] {
            let recorder = LibraryEntryProfile(capacity: capacity, now: { 100 })
            let start = recorder.begin()
            XCTAssertEqual(try snapshot(recorder).droppedSamples, 0)
            recorder.mark(.entry)
            recorder.end(.viewLayout, since: start)
            recorder.mark(.iconDelivery)
            let result = try snapshot(recorder)
            XCTAssertEqual(result.sampleLimit, 0)
            XCTAssertTrue(result.samples.isEmpty)
            XCTAssertEqual(result.droppedSamples, 3)
        }
    }

    func testBackwardClockClampsTimestampAndDurationIndependently() throws {
        var clock: UInt64 = 100
        let recorder = LibraryEntryProfile(now: { clock })
        clock = 150
        let start = recorder.begin()
        clock = 120
        recorder.end(.entry, since: start)
        clock = 90
        recorder.end(.viewApply, since: start)
        clock = 80
        recorder.mark(.viewLayout)
        let earlier = recorder.begin()
        clock = 95
        recorder.end(.galleryLayout, since: earlier)
        clock = 160
        recorder.end(.galleryApply, since: start)
        XCTAssertEqual(try snapshot(recorder).samples, [
            .init(tag: "entry", timestampNS: 20, durationNS: 0, count: 0),
            .init(tag: "viewApply", timestampNS: 0, durationNS: 0, count: 0),
            .init(tag: "viewLayout", timestampNS: 0, durationNS: 0, count: 0),
            .init(tag: "galleryLayout", timestampNS: 0, durationNS: 15, count: 0),
            .init(tag: "galleryApply", timestampNS: 60, durationNS: 10, count: 0)
        ])
    }

    func testCountsClampAtZeroAndPreserveLargestPositiveInteger() throws {
        let recorder = LibraryEntryProfile(now: { 10 })
        recorder.mark(.parentInput, count: Int.min)
        recorder.end(.parentRender, since: recorder.begin(), count: -1)
        recorder.mark(.parentCommit, count: Int.max)
        recorder.end(.galleryIcons, since: recorder.begin())
        XCTAssertEqual(try snapshot(recorder).samples.map(\.count), [0, 0, Int.max, 0])
    }

    func testUInt64BoundariesEncodeWithoutOverflowOrPrecisionLoss() throws {
        var clock: UInt64 = 0
        let recorder = LibraryEntryProfile(now: { clock })
        let start = recorder.begin()
        clock = UInt64.max
        recorder.end(.entry, since: start)
        clock = 0
        recorder.end(.parentFrame, since: UInt64.max)
        XCTAssertEqual(try snapshot(recorder).samples, [
            .init(tag: "entry", timestampNS: UInt64.max, durationNS: UInt64.max, count: 0),
            .init(tag: "parentFrame", timestampNS: 0, durationNS: 0, count: 0)
        ])
        let highBaseline = LibraryEntryProfile(now: { UInt64.max })
        highBaseline.mark(.entry)
        XCTAssertEqual(try snapshot(highBaseline).samples.first?.timestampNS, 0)
    }

    func testSnapshotsDoNotDrainSamplesResetDropsOrReadClock() throws {
        var reads = 0
        let recorder = LibraryEntryProfile(capacity: 1, now: { reads += 1; return 100 })
        recorder.mark(.entry)
        recorder.mark(.iconDelivery)
        let first = try snapshot(recorder)
        XCTAssertEqual(try snapshot(recorder), first)
        XCTAssertEqual(reads, 3)
        recorder.mark(.viewApply)
        let later = try snapshot(recorder)
        XCTAssertEqual(later.samples, first.samples)
        XCTAssertEqual(later.droppedSamples, 2)
    }
}
