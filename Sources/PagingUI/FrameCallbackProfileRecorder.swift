//
//  FrameCallbackProfileRecorder.swift
//  PagingUI
//
//  Opt-in Timer callback-boundary diagnostics for RunLoopFrameDriver.
//
//  Measured boundaries, in order:
//    timer_generation_arm.arm_ns
//    frame_callback.entry_ns
//    frame_callback.exit_ns          // post-advanceFrame, NOT closure return
//    frame_callback.pre_return_ns    // closure-return-adjacent marker
//
//  Application code cannot record a true closure return.
//

import Foundation

/// Records the complete entry / post-advanceFrame / pre-return boundary of
/// RunLoopFrameDriver Timer callbacks, plus generation arm markers.
///
/// The recorder is disabled by default. An inactive instance does not sample
/// clocks, allocate a writer, create a file, or accept records. Active callback
/// paths only read clocks/mode, build an in-memory JSON line, and optionally
/// enqueue a batch to the existing asynchronous writer; filesystem I/O never
/// runs in the callback.
public final class FrameCallbackProfileRecorder {

    public typealias Clock = DiagnosticMonotonicClock

    public private(set) var isActive: Bool
    public let fileURL: URL
    public private(set) var recordCount = 0
    /// JSONL lines dropped because the in-memory buffer exceeded capacity.
    public private(set) var droppedRecordCount = 0
    /// Completed callbacks that never received a matching `markPreReturn`.
    public private(set) var incompleteDropCount = 0

    /// Number of asynchronous writer batches that failed.
    public var writeFailureCount: Int {
        writer?.failureCount ?? 0
    }

    public var bufferCapacity = 20_000
    public var flushThreshold = 512

    /// Opaque entry token retained by RunLoopFrameDriver until the Timer closure
    /// reaches its pre-return marker.
    struct CallbackBoundary {
        fileprivate let callbackSequence: UInt64
        fileprivate let driverGeneration: UInt64
        fileprivate let scheduledNS: UInt64
        fileprivate let intervalNS: UInt64
        fileprivate let entryNS: UInt64
        fileprivate let threadCPUEntryNS: UInt64
        fileprivate let firstTick: Bool
        fileprivate let rawCallbackIntervalNS: UInt64?
        fileprivate let mode: String
    }

    /// Pure schedule calculation shared by the recorder and RunLoopFrameDriver.
    struct ScheduleMetrics: Equatable {
        let latenessNS: Int64
        let missedPeriods: UInt64
        let nextNominalDeadlineNS: UInt64
    }

    private struct PendingCallbackRecord {
        let boundary: CallbackBoundary
        let exitNS: UInt64
        let threadCPUExitNS: UInt64
        let simulationDTNS: UInt64?
    }

    private let clock: Clock
    private let modeProvider: () -> String?
    private var buffer: [String] = []
    private var writer: BufferedJSONLWriter?
    private var nextCallbackSequence: UInt64 = 1
    private var lastDriverGeneration: UInt64?
    private var lastEntryNS: UInt64?
    private var pending: PendingCallbackRecord?

    public convenience init(
        runID: String,
        fileURL: URL? = nil,
        active: Bool = false,
        clock: Clock = .system
    ) {
        self.init(
            runID: runID,
            fileURL: fileURL,
            active: active,
            clock: clock,
            modeProvider: Self.currentRawRunLoopMode,
            writer: nil
        )
    }

    /// Internal injection seam for deterministic clock, mode, and writer tests.
    init(
        runID: String,
        fileURL: URL? = nil,
        active: Bool,
        clock: Clock,
        modeProvider: @escaping () -> String?,
        writer: BufferedJSONLWriter? = nil
    ) {
        let sanitized = Self.sanitizedRunID(runID)
        self.fileURL = fileURL
            ?? URL(fileURLWithPath: "/tmp/launch-copy-paging-prototype-\(sanitized)-callback.jsonl")
        self.isActive = active
        self.clock = clock
        self.modeProvider = modeProvider
        self.writer = writer
    }

    deinit {
        flush()
    }

    /// Records the actual Timer generation arm and returns the first nominal
    /// deadline. Inactive diagnostics stay entirely cold.
    func recordGenerationArm(
        driverGeneration: UInt64,
        intervalNS: UInt64,
        toleranceNS: UInt64
    ) -> UInt64 {
        guard isActive else { return 0 }
        let armNS = clock.wallNowNS()
        let (deadline, overflow) = armNS.addingReportingOverflow(intervalNS)
        let nominalFirstDeadlineNS = overflow ? UInt64.max : deadline
        let line = "{\"arm_ns\":\(armNS),\"driver_generation\":\(driverGeneration),\"interval_ns\":\(intervalNS),\"kind\":\"timer_generation_arm\",\"nominal_first_deadline_ns\":\(nominalFirstDeadlineNS),\"tolerance_ns\":\(toleranceNS)}"
        appendLine(line)
        return nominalFirstDeadlineNS
    }

    /// Returns the first nominal deadline after arming a Timer generation
    /// without emitting an arm record. Prefer `recordGenerationArm` in the
    /// production driver. Clock is sampled only for an active recorder.
    func initialNominalDeadlineNS(intervalNS: UInt64) -> UInt64 {
        guard isActive else { return 0 }
        let now = clock.wallNowNS()
        let (deadline, overflow) = now.addingReportingOverflow(intervalNS)
        return overflow ? UInt64.max : deadline
    }

    /// Computes the next nominal deadline after the callback represented by `boundary`.
    func nextNominalDeadlineNS(after boundary: CallbackBoundary) -> UInt64 {
        Self.nextNominalDeadlineNS(
            scheduledNS: boundary.scheduledNS,
            entryNS: boundary.entryNS,
            intervalNS: boundary.intervalNS
        )
    }

    /// Captures the Timer closure entry boundary. Inactive recorders return nil
    /// before reading any clock or mode provider.
    func beginCallback(
        driverGeneration: UInt64,
        scheduledNS: UInt64,
        intervalNS: UInt64
    ) -> CallbackBoundary? {
        guard isActive else { return nil }

        let entryNS = clock.wallNowNS()
        let threadCPUEntryNS = clock.threadCPUNowNS()
        let firstTick = lastDriverGeneration != driverGeneration || lastEntryNS == nil
        let rawCallbackIntervalNS = firstTick ? nil : lastEntryNS.map { Self.nonnegativeDelta(from: $0, to: entryNS) }
        let sequence = nextCallbackSequence

        if nextCallbackSequence < UInt64.max {
            nextCallbackSequence += 1
        }
        lastDriverGeneration = driverGeneration
        lastEntryNS = entryNS

        return CallbackBoundary(
            callbackSequence: sequence,
            driverGeneration: driverGeneration,
            scheduledNS: scheduledNS,
            intervalNS: intervalNS,
            entryNS: entryNS,
            threadCPUEntryNS: threadCPUEntryNS,
            firstTick: firstTick,
            rawCallbackIntervalNS: rawCallbackIntervalNS,
            mode: Self.modeCategory(rawMode: modeProvider())
        )
    }

    /// Samples the post-advanceFrame marker. This is not a closure return and
    /// does not emit JSON until `markPreReturn`.
    func endCallback(_ boundary: CallbackBoundary?, simulationDTNS: UInt64?) {
        guard isActive, let boundary else { return }

        let exitNS = clock.wallNowNS()
        let threadCPUExitNS = clock.threadCPUNowNS()
        if pending != nil {
            incompleteDropCount += 1
        }
        pending = PendingCallbackRecord(
            boundary: boundary,
            exitNS: exitNS,
            threadCPUExitNS: threadCPUExitNS,
            simulationDTNS: simulationDTNS
        )
    }

    /// Samples the closure-return-adjacent marker and emits one complete
    /// `frame_callback` record. This is still not a true closure return.
    func markPreReturn(_ boundary: CallbackBoundary?) {
        guard isActive, let boundary else { return }
        guard let pending,
              pending.boundary.callbackSequence == boundary.callbackSequence,
              pending.boundary.driverGeneration == boundary.driverGeneration else {
            return
        }

        let preReturnNS = clock.wallNowNS()
        let threadCPUPreReturnNS = clock.threadCPUNowNS()
        emitCallbackRecord(pending, preReturnNS: preReturnNS, threadCPUPreReturnNS: threadCPUPreReturnNS)
        self.pending = nil
    }

    /// Enqueues the current in-memory batch and waits for all previously accepted
    /// asynchronous writes. Intended for teardown/tests, never the Timer hot path.
    public func flush() {
        if pending != nil {
            incompleteDropCount += 1
            pending = nil
        }
        enqueueBufferedLines()
        writer?.flush()
    }

    /// Signed entry lateness with saturation instead of integer overflow.
    static func latenessNanoseconds(scheduledNS: UInt64, entryNS: UInt64) -> Int64 {
        if entryNS >= scheduledNS {
            let delta = entryNS - scheduledNS
            return delta > UInt64(Int64.max) ? Int64.max : Int64(delta)
        }

        let delta = scheduledNS - entryNS
        return delta > UInt64(Int64.max) ? Int64.min : -Int64(delta)
    }

    /// Every complete interval after the nominal scheduled deadline counts as one
    /// missed period. Partial lateness does not.
    static func missedPeriods(scheduledNS: UInt64, entryNS: UInt64, intervalNS: UInt64) -> UInt64 {
        guard intervalNS > 0, entryNS > scheduledNS else { return 0 }
        return (entryNS - scheduledNS) / intervalNS
    }

    /// Returns the first nominal period strictly after `entryNS`. Arithmetic
    /// saturates at UInt64.max so pathological inputs cannot trap the callback.
    static func nextNominalDeadlineNS(
        scheduledNS: UInt64,
        entryNS: UInt64,
        intervalNS: UInt64
    ) -> UInt64 {
        guard intervalNS > 0 else { return UInt64.max }

        // If the callback arrived before its due time, the current scheduled
        // deadline is already the first nominal period after entry.
        guard entryNS < scheduledNS else {
            let completedPeriods = (entryNS - scheduledNS) / intervalNS
            guard completedPeriods < UInt64.max else { return UInt64.max }

            let periodsToAdvance = completedPeriods + 1
            let (advance, multiplyOverflow) = intervalNS.multipliedReportingOverflow(by: periodsToAdvance)
            guard !multiplyOverflow else { return UInt64.max }
            let (deadline, addOverflow) = scheduledNS.addingReportingOverflow(advance)
            return addOverflow ? UInt64.max : deadline
        }
        return scheduledNS
    }

    static func scheduleMetrics(
        scheduledNS: UInt64,
        entryNS: UInt64,
        intervalNS: UInt64
    ) -> ScheduleMetrics {
        ScheduleMetrics(
            latenessNS: latenessNanoseconds(scheduledNS: scheduledNS, entryNS: entryNS),
            missedPeriods: missedPeriods(scheduledNS: scheduledNS, entryNS: entryNS, intervalNS: intervalNS),
            nextNominalDeadlineNS: nextNominalDeadlineNS(
                scheduledNS: scheduledNS,
                entryNS: entryNS,
                intervalNS: intervalNS
            )
        )
    }

    /// Maps a raw run-loop mode to a fixed anonymous vocabulary. Raw mode text is
    /// never retained in a boundary token or emitted to JSONL.
    static func modeCategory(rawMode: String?) -> String {
        guard let rawMode else { return "none" }
        if rawMode.contains("kCFRunLoopDefaultMode") || rawMode.contains("NSDefaultRunLoopMode") {
            return "default"
        }
        if rawMode.contains("NSEventTrackingRunLoopMode") {
            return "eventTracking"
        }
        if rawMode.contains("NSModalPanelRunLoopMode") {
            return "modalPanel"
        }
        return "other"
    }

    public static func sanitizedRunID(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            scalars.append(allowed.contains(scalar) ? scalar : "_")
        }
        let sanitized = String(String(scalars).prefix(64))
        return sanitized.isEmpty ? "run" : sanitized
    }

    private static func currentRawRunLoopMode() -> String? {
        CFRunLoopCopyCurrentMode(CFRunLoopGetCurrent()).map { String(describing: $0) }
    }

    private static func nonnegativeDelta(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }

    private static func jsonUInt64OrNull(_ value: UInt64?) -> String {
        value.map(String.init) ?? "null"
    }

    private func emitCallbackRecord(
        _ pending: PendingCallbackRecord,
        preReturnNS: UInt64,
        threadCPUPreReturnNS: UInt64
    ) {
        let boundary = pending.boundary
        let schedule = Self.scheduleMetrics(
            scheduledNS: boundary.scheduledNS,
            entryNS: boundary.entryNS,
            intervalNS: boundary.intervalNS
        )
        let rawInterval = Self.jsonUInt64OrNull(boundary.rawCallbackIntervalNS)
        let simulationDT = Self.jsonUInt64OrNull(pending.simulationDTNS)
        let closureTailWall = preReturnNS >= pending.exitNS
            ? String(preReturnNS - pending.exitNS)
            : "null"
        let closureTailCPU = threadCPUPreReturnNS >= pending.threadCPUExitNS
            ? String(threadCPUPreReturnNS - pending.threadCPUExitNS)
            : "null"
        let line = "{\"callback_cpu_ns\":\(Self.nonnegativeDelta(from: boundary.threadCPUEntryNS, to: pending.threadCPUExitNS)),\"callback_seq\":\(boundary.callbackSequence),\"callback_wall_ns\":\(Self.nonnegativeDelta(from: boundary.entryNS, to: pending.exitNS)),\"closure_tail_cpu_ns\":\(closureTailCPU),\"closure_tail_wall_ns\":\(closureTailWall),\"driver_generation\":\(boundary.driverGeneration),\"entry_ns\":\(boundary.entryNS),\"exit_ns\":\(pending.exitNS),\"first_tick\":\(boundary.firstTick),\"kind\":\"frame_callback\",\"lateness_ns\":\(schedule.latenessNS),\"missed_periods\":\(schedule.missedPeriods),\"mode\":\"\(boundary.mode)\",\"nominal_interval_ns\":\(boundary.intervalNS),\"pre_return_ns\":\(preReturnNS),\"raw_callback_interval_ns\":\(rawInterval),\"scheduled_ns\":\(boundary.scheduledNS),\"simulation_dt_ns\":\(simulationDT),\"thread_cpu_entry_ns\":\(boundary.threadCPUEntryNS),\"thread_cpu_exit_ns\":\(pending.threadCPUExitNS),\"thread_cpu_pre_return_ns\":\(threadCPUPreReturnNS)}"
        appendLine(line)
    }

    private func appendLine(_ line: String) {
        buffer.append(line)
        recordCount += 1

        let capacity = max(bufferCapacity, 0)
        if buffer.count > capacity {
            let overflow = buffer.count - capacity
            buffer.removeFirst(overflow)
            droppedRecordCount += overflow
        }
        if !buffer.isEmpty, buffer.count >= max(flushThreshold, 1) {
            enqueueBufferedLines()
        }
    }

    private func enqueueBufferedLines() {
        guard !buffer.isEmpty else { return }
        let lines = buffer
        buffer.removeAll(keepingCapacity: true)
        let writer = writer ?? BufferedJSONLWriter(fileURL: fileURL)
        self.writer = writer
        writer.enqueue(lines)
    }
}
