//
//  PerfBenchmark.swift
//  PagingPrototypeApp
//
//  无头性能探针（PAGING_PROTOTYPE_PERF=1）：T-step6 baseline。
//
//  对 1/2/5/10/20 页预设各跑一次脚本化手势旅程（真实输入路径：
//  surface.handleScrollInput → mapper → Core；advanceFrame → Core.tick），收集：
//   - 纯 Core 处理开销（直接驱动 PagingCore，无视图）
//   - 单帧 update CPU 时间（surface.advanceFrame 含 Core tick + 范围检查 + 可访问性）
//   - 页面 view 数量（live 上界/复用池上界）
//   - layout 调用次数（事件驱动守卫验证）
//   - 预热与缓存（fresh prepare vs 复用池命中）
//   - 长序列内存增长（live+pool 恒有界）
//   - stale completion 零提交
//   - frame miss（>16.7ms）与 hitch（>50ms）计数（回归预警，非物理门）
//
//  每个预设同时写一份 telemetry 日志（/tmp/launch-copy-paging-prototype-perf-cli-p<N>.jsonl，
//  追加模式，多 run 全保留，禁止删除）。
//
//  说明：这是 synthetic 脚本输入，只作回归预警；真实触控板物理门属于 T-step8。
//

import AppKit
import Foundation
import PagingCore
import PagingTelemetry
import PagingUI

enum PerfBenchmark {

    static let presets = [1, 2, 5, 10, 20]
    static let flingsPerPreset = 200
    static let maxFramesPerFling = 600

    /// 入口：全部预设 + 纯 Core 对照，打印表格，返回进程退出码。
    static func run() -> Int32 {
        let withTelemetry = ProcessInfo.processInfo.environment["PAGING_PROTOTYPE_PERF_TELEMETRY"] != "0"
        print("PERF-BENCH begin (\(Date())) telemetry=\(withTelemetry)")

        // 1) 纯 Core 对照（无视图路径）。
        print("--- pure core (direct PagingCore, no views) ---")
        print("pages, flingMeanUs, flingP99Us, flingMaxUs")
        for pageCount in presets {
            let s = measurePureCore(pageCount: pageCount)
            print("\(pageCount), \(fmt(s.mean)), \(fmt(s.p99)), \(fmt(s.max))")
        }

        // 2) 全路径 surface 预设。
        print("--- surface (real input path) ---")
        print("pages, frameCount, frameMeanUs, frameP99Us, frameMaxUs, miss16, hitch50, livePeak, poolPeak, layoutsTotal, layoutsPerFling, freshPrepare, reuseHit, reuseRatio, commits, stales, telemetryEvents")
        for pageCount in presets {
            let row = measureSurfacePreset(pageCount: pageCount, withTelemetry: withTelemetry)
            print("\(row.pageCount), \(row.frameCount), \(fmt(row.frameMeanUs)), \(fmt(row.frameP99Us)), \(fmt(row.frameMaxUs)), \(row.miss16), \(row.hitch50), \(row.livePeak), \(row.poolPeak), \(row.layoutsTotal), \(String(format: "%.2f", row.layoutsPerFling)), \(row.freshPrepare), \(row.reuseHit), \(String(format: "%.3f", row.reuseRatio)), \(row.commits), \(row.stales), \(row.telemetryEvents)")
        }
        print("PERF-BENCH end")
        return 0
    }

    // MARK: - 统计

    private struct Stats {
        let mean: Double
        let p99: Double
        let max: Double
    }

    private static func stats(_ values: [Double]) -> Stats {
        guard !values.isEmpty else { return Stats(mean: 0, p99: 0, max: 0) }
        let sorted = values.sorted()
        let mean = values.reduce(0, +) / Double(values.count)
        let idx99 = min(sorted.count - 1, Int(Double(sorted.count) * 0.99))
        return Stats(mean: mean, p99: sorted[idx99], max: sorted[sorted.count - 1])
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // MARK: - 纯 Core 对照

    private static func measurePureCore(pageCount: Int) -> Stats {
        let core = PagingCore(pageCount: pageCount, pageWidth: 1000)
        var times: [Double] = []
        for i in 0..<flingsPerPreset {
            let forward = i % 4 != 3
            let t = Double(i) * 10
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = core.handleGesturePhase(.began, timestamp: t)
            _ = core.handleGesturePhase(.changed, delta: forward ? 500 : -500, timestamp: t + 0.5)
            _ = core.handleGesturePhase(.ended, timestamp: t + 0.5)
            _ = core.finishGesture(timestamp: t + 0.5)
            var frames = 0
            while core.isAnimating, frames < maxFramesPerFling {
                _ = core.tick(deltaTime: 1.0 / 60.0)
                frames += 1
            }
            times.append((CFAbsoluteTimeGetCurrent() - t0) * 1e6)
        }
        return stats(times)
    }

    // MARK: - surface 全路径预设

    private struct Row {
        let pageCount: Int
        let frameCount: Int
        let frameMeanUs: Double
        let frameP99Us: Double
        let frameMaxUs: Double
        let miss16: Int
        let hitch50: Int
        let livePeak: Int
        let poolPeak: Int
        let layoutsTotal: Int
        let layoutsPerFling: Double
        let freshPrepare: Int
        let reuseHit: Int
        let reuseRatio: Double
        let commits: Int
        let stales: Int
        let telemetryEvents: Int
    }

    private static func measureSurfacePreset(pageCount: Int, withTelemetry: Bool) -> Row {
        let surface = PagingSurface(pageCount: pageCount, itemsPerPage: 35)
        surface.frameDriver = nil
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()

        // telemetry：真实 bridge 接线，事件进日志（追加，保留）；
        // withTelemetry=false 用于隔离 telemetry 每帧写盘对热路径的扰动。
        let session = TelemetrySession(configuration: TelemetryConfiguration(enabled: withTelemetry, runID: "perf-cli-p\(pageCount)"))
        session.begin()
        let bridge = PagingTelemetryBridge(surface: surface, session: session)
        _ = bridge

        var frameTimes: [Double] = []
        var peakLive = 0
        var peakPool = 0
        var freshPrepare = 0
        var reuseHit = 0
        surface.onPagePrepared = { _, reused in
            if reused { reuseHit += 1 } else { freshPrepare += 1 }
        }

        for i in 0..<flingsPerPreset {
            let forward = i % 4 != 3
            let t = Double(i) * 10
            surface.simulateScrollInput(phase: .began, momentumPhase: [], scrollingDeltaX: forward ? -500 : 500, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t)
            surface.simulateScrollInput(phase: .changed, momentumPhase: [], scrollingDeltaX: forward ? -500 : 500, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t + 0.5)
            surface.simulateScrollInput(phase: .ended, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t + 0.5)
            surface.simulateScrollInput(phase: [], momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t + 0.5)

            var frames = 0
            while surface.core.isAnimating, frames < maxFramesPerFling {
                let f0 = CFAbsoluteTimeGetCurrent()
                surface.simulateFrame(deltaTime: 1.0 / 60.0)
                frameTimes.append((CFAbsoluteTimeGetCurrent() - f0) * 1e6)
                frames += 1
            }
            peakLive = max(peakLive, surface.liveHostCount)
            peakPool = max(peakPool, surface.poolHostCount)
        }

        let frameStats = stats(frameTimes)
        let miss16 = frameTimes.filter { $0 > 16_700 }.count
        let hitch50 = frameTimes.filter { $0 > 50_000 }.count
        let totalPrepares = freshPrepare + reuseHit
        let reuseRatio = totalPrepares > 0 ? Double(reuseHit) / Double(totalPrepares) : 0
        let layoutsPerFling = Double(surface.layoutPerformedCount) / Double(flingsPerPreset)
        let row = Row(
            pageCount: pageCount,
            frameCount: frameTimes.count,
            frameMeanUs: frameStats.mean,
            frameP99Us: frameStats.p99,
            frameMaxUs: frameStats.max,
            miss16: miss16,
            hitch50: hitch50,
            livePeak: peakLive,
            poolPeak: peakPool,
            layoutsTotal: surface.layoutPerformedCount,
            layoutsPerFling: layoutsPerFling,
            freshPrepare: freshPrepare,
            reuseHit: reuseHit,
            reuseRatio: reuseRatio,
            commits: Int(surface.core.commitCount),
            stales: Int(surface.core.staleRejectionCount),
            telemetryEvents: session.recordedEventCount
        )
        session.end()
        return row
    }
}
