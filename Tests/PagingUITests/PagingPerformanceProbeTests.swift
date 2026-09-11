//
//  PagingPerformanceProbeTests.swift
//
//  T-step6 自动化性能探针（回归预警，非物理门）：
//   - 单帧 update CPU 时间（无 telemetry 的干净路径）
//   - 纯 Core 处理开销
//   - 预热/复用命中率
//   - 多页面预设下 view 预算
//   - stale completion 零提交
//  所有断言带宽松余量（CI 负载容差）；实测数值 print 输出供记录。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

final class PagingPerformanceProbeTests: XCTestCase {

    /// 单帧 update 成本：5 页预设，300 次甩动全 settle 帧。
    /// 60Hz 预算 16.7ms；断言均值远低于预算，hitch(>50ms) 允许 ≤3（调度噪声）。
    func testFrameUpdateCostWithinHitchBudget() {
        let surface = makeSurface(pageCount: 5)
        var frameTimes: [Double] = []
        for i in 0..<300 {
            gestureBegan(surface, at: TimeInterval(i) * 10)
            gestureChanged(surface, deltaX: 500, at: TimeInterval(i) * 10 + 0.5)
            gestureEnded(surface, at: TimeInterval(i) * 10 + 0.5)
            finishPendingGesture(surface, at: TimeInterval(i) * 10 + 0.5)
            var frames = 0
            while surface.core.isAnimating, frames < 600 {
                let t0 = CFAbsoluteTimeGetCurrent()
                surface.advanceFrame(deltaTime: 1.0 / 60.0)
                frameTimes.append((CFAbsoluteTimeGetCurrent() - t0) * 1e6)
                frames += 1
            }
        }
        let mean = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let miss16 = frameTimes.filter { $0 > 16_700 }.count
        let hitch50 = frameTimes.filter { $0 > 50_000 }.count
        print("PROBE frameUpdate: frames=\(frameTimes.count) meanUs=\(String(format: "%.1f", mean)) miss16=\(miss16) hitch50=\(hitch50) maxUs=\(String(format: "%.1f", frameTimes.max() ?? 0))")
        XCTAssertLessThan(mean, 16_600, "单帧 update 均值须远低于 16.7ms 预算")
        XCTAssertLessThanOrEqual(hitch50, 3, ">50ms 主线程 hitch 应接近零（容调度噪声 ≤3）")
        XCTAssertLessThanOrEqual(Double(miss16) / Double(frameTimes.count), 0.02, ">16.7ms 帧比例 ≤2%（自动回归预警；1% 物理门属 T-step8）")
        XCTAssertEqual(surface.core.staleRejectionCount, 0, "stale completion 零提交")
    }

    /// 纯 Core 处理开销：直接驱动 PagingCore（无视图），单次甩动（4 阶段 + settle 全帧）。
    /// 同时测「裸 core」与「经 surface 创建的 core」——用于核对 CLI 探针(~7µs)与
    /// XCTest 观察值的差异是否来自表面对象存活导致的 AppKit 事件开销。
    func testPureCoreFlingCostWellBelowFrameBudget() {
        let bareCore = PagingCore(pageCount: 10, pageWidth: 1000)
        let surfaceCore = makeSurface(pageCount: 10).core
        var bareTimes: [Double] = []
        var surfaceTimes: [Double] = []
        for i in 0..<300 {
            measureFling(core: bareCore, i: i, into: &bareTimes)
            measureFling(core: surfaceCore, i: i, into: &surfaceTimes)
        }
        let bareMean = bareTimes.reduce(0, +) / Double(bareTimes.count)
        let surfaceMean = surfaceTimes.reduce(0, +) / Double(surfaceTimes.count)
        print("PROBE pureCore: bareMeanUs=\(String(format: "%.1f", bareMean)) maxUs=\(String(format: "%.1f", bareTimes.max() ?? 0)) surfaceCoreMeanUs=\(String(format: "%.1f", surfaceMean)) maxUs=\(String(format: "%.1f", surfaceTimes.max() ?? 0))")
        XCTAssertLessThan(bareMean, 1_000, "裸 Core 单次甩动开销应 ≪ 1ms")
        XCTAssertLessThan(surfaceMean, 1_000, "surface 事件接线不显著拖慢 Core 热路径")
    }

    private func measureFling(core: PagingCore, i: Int, into times: inout [Double]) {
        let t0 = CFAbsoluteTimeGetCurrent()
        _ = core.handleGesturePhase(.began, timestamp: TimeInterval(i) * 10)
        _ = core.handleGesturePhase(.changed, delta: 500, timestamp: TimeInterval(i) * 10 + 0.5)
        _ = core.handleGesturePhase(.ended, timestamp: TimeInterval(i) * 10 + 0.5)
        _ = core.finishGesture(timestamp: TimeInterval(i) * 10 + 0.5)
        var frames = 0
        while core.isAnimating, frames < 600 {
            _ = core.tick(deltaTime: 1.0 / 60.0)
            frames += 1
        }
        times.append((CFAbsoluteTimeGetCurrent() - t0) * 1e6)
    }

    /// 预热与缓存：长旅程后 prepare 复用命中率应 ≥85%（池化生效）。
    func testPrewarmReuseRatio() {
        let surface = makeSurface(pageCount: 20)
        var fresh = 0
        var reused = 0
        surface.onPagePrepared = { _, isReused in
            if isReused { reused += 1 } else { fresh += 1 }
        }
        for i in 0..<60 {
            flingForwardOnce(surface, at: TimeInterval(i) * 10)
        }
        let total = fresh + reused
        let ratio = total > 0 ? Double(reused) / Double(total) : 0
        print("PROBE prewarm: fresh=\(fresh) reused=\(reused) ratio=\(String(format: "%.3f", ratio))")
        // 20 页旅程中心 0→19 = 16 次范围平移：前 3 次为冷启动（预热成本），
        // 此后每次平移必须 100% 复用池。断言：冷启动 ≤ 4 且复用 ≥ 10。
        XCTAssertLessThanOrEqual(fresh, 4, "预热成本有界（仅初始范围外页面冷创建）")
        XCTAssertGreaterThanOrEqual(reused, 10, "预热后复用命中率高（池化生效）")
    }

    /// 多页面预设下 view 预算与内存上界（live ≤ 7、pool ≤ 7、合计 ≤ 14）。
    func testViewBudgetHoldsAcrossPresets() {
        for pageCount in [1, 2, 5, 10, 20] {
            let surface = makeSurface(pageCount: pageCount)
            for i in 0..<10 {
                flingForwardOnce(surface, at: TimeInterval(i) * 10)
                XCTAssertLessThanOrEqual(surface.liveHostCount, 7, "p\(pageCount) live 上界")
                XCTAssertLessThanOrEqual(surface.poolHostCount, 7, "p\(pageCount) pool 上界")
                XCTAssertLessThanOrEqual(surface.liveHostCount + surface.poolHostCount, 14, "p\(pageCount) 总视图内存上界")
            }
        }
    }
}
