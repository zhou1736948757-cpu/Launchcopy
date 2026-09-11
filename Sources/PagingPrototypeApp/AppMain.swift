//
//  AppMain.swift
//  PagingPrototypeApp
//
//  SwiftPM executable 入口：真实启动 NSApplication（非纯逻辑包）。
//  - 无参数：默认配置正常打开；
//  - 参数错误：打印帮助后继续正常启动（不崩溃）；
//  - --help/-h：打印帮助后退出（不开窗口）；
//  - --page-hosting composited：提示"保留未实现"后按 live 运行（ADR-002 决策）；
//  - PAGING_PROTOTYPE_SMOKE=1：无头 smoke 模式（解析+打印+退出，不开窗口）——测试缝。
//

import AppKit
import Foundation
import PagingTelemetry

@main
struct PagingPrototypeMain {

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        // 无头性能探针（T-step6）：脚本化手势旅程 × 页面预设，打印表格并退出（不开窗口）。
        if ProcessInfo.processInfo.environment["PAGING_PROTOTYPE_PERF"] == "1" {
            exit(PerfBenchmark.run())
        }

        // 无头 smoke 测试缝（不开窗口；用于 CI/无头环境验证真实入口）。
        if ProcessInfo.processInfo.environment["PAGING_PROTOTYPE_SMOKE"] == "1" {
            runSmoke(arguments: arguments)
            exit(0)
        }

        let parsed = AppArguments.parse(arguments)
        switch parsed {
        case .failure(let error):
            fputs("paging-prototype: 参数错误：\(error)\n", stderr)
            fputs(AppArguments.helpText(), stderr)
            if case .invalidMomentumDecay = error {
                // T-worker-b-tune：调参参数非法必须显式失败——静默回退默认值会掩盖错误试值。
                exit(2)
            }
            if case .invalidMomentumGlideFrames = error {
                // T-worker-b-glide：momentum 截断帧数非法 → 显式失败（同上，不静默回退）。
                exit(2)
            }
            if case .invalidMomentumOvershoot = error {
                // T-worker-b-overshoot2：过冲钳制非法 → 显式失败（同上，不静默回退）。
                exit(2)
            }
            if case .invalidFrameTimerTolerance = error {
                // 性能 A/B 配置非法必须显式失败，避免把错误试值静默回退为生产默认。
                exit(2)
            }
        case .success(let options):
            if options.helpRequested {
                print(AppArguments.helpText())
                exit(0)
            }
            if options.pageHosting == .composited {
                print("paging-prototype: --page-hosting composited 保留未实现（ADR-002 方案 1 先行），本次以 live 运行")
            }
        }

        // 参数错误也继续启动（默认配置），绝不崩溃。
        let resolvedOptions = (try? parsed.get()) ?? .default
        let app = NSApplication.shared
        let delegate = AppDelegate(options: resolvedOptions)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    // MARK: - smoke

    private static func runSmoke(arguments: [String]) {
        let parsed = AppArguments.parse(arguments)
        switch parsed {
        case .success(let options):
            print("smoke: parse OK")
            print("smoke: pagingLab=\(options.pagingLab) pageCount=\(options.pageCount ?? 5) itemsPerPage=\(options.itemsPerPage ?? 35) hosting=\(options.pageHosting.rawValue) rmOverride=\(options.reduceMotionOverride.rawValue) telemetry=\(options.telemetryEnabled) runID=\(options.runID ?? "-")")
            let toleranceDescription = options.frameTimerToleranceMS
                .map { String($0) }
                ?? "default"
            print(
                "smoke: catalogRoots=\(options.catalogRoots.count) " +
                "neutralContent=\(options.neutralContent) " +
                "frameDriver=\(options.frameDriver.rawValue) " +
                "frameTimerToleranceMS=\(toleranceDescription) " +
                "frameProfile=\(options.frameProfile) " +
                "frameCallbackProfile=\(options.frameCallbackProfile) " +
                "runLoopProfile=\(options.runLoopProfile) " +
                "disableTelemetryBridge=\(options.disableTelemetryBridge)"
            )
            let session = PagingTelemetry.makeSession(enabled: options.telemetryEnabled, runID: options.runID)
            session.begin()
            print("smoke: telemetry runID=\(session.runID) path=\(session.logPathDescription)")
            session.end()
            print("smoke: OK")
        case .failure(let error):
            print("smoke: parse error: \(error)")
            print("smoke: FAIL")
            exit(2)
        }
    }
}
