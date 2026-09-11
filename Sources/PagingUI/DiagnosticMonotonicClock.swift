//
//  DiagnosticMonotonicClock.swift
//  PagingUI
//
//  Shared diagnostic clock domain for callback, closure-tail, generation-arm,
//  and RunLoop observer records. Production uses CLOCK_MONOTONIC_RAW plus
//  CLOCK_THREAD_CPUTIME_ID. Tests inject a fake clock.
//
//  This type is a join key. Date, wall-clock, ProcessInfo.systemUptime, and
//  ContinuousClock must not be mixed into the same correlation arithmetic.
//

import Darwin
import Foundation

/// Injectable monotonic nanosecond clock used only by opt-in profilers.
public struct DiagnosticMonotonicClock {

    public let wallNowNS: () -> UInt64
    public let threadCPUNowNS: () -> UInt64

    public init(wallNowNS: @escaping () -> UInt64, threadCPUNowNS: @escaping () -> UInt64) {
        self.wallNowNS = wallNowNS
        self.threadCPUNowNS = threadCPUNowNS
    }

    public static let system = DiagnosticMonotonicClock(
        wallNowNS: { nanoseconds(CLOCK_MONOTONIC_RAW) },
        threadCPUNowNS: { nanoseconds(CLOCK_THREAD_CPUTIME_ID) }
    )

    public static func nanoseconds(_ clockID: clockid_t) -> UInt64 {
        var value = timespec()
        guard clock_gettime(clockID, &value) == 0, value.tv_sec >= 0, value.tv_nsec >= 0 else {
            return 0
        }

        let seconds = UInt64(value.tv_sec)
        let nanoseconds = UInt64(value.tv_nsec)
        let (scaledSeconds, multiplyOverflow) = seconds.multipliedReportingOverflow(by: 1_000_000_000)
        guard !multiplyOverflow else { return UInt64.max }
        let (result, addOverflow) = scaledSeconds.addingReportingOverflow(nanoseconds)
        return addOverflow ? UInt64.max : result
    }
}
