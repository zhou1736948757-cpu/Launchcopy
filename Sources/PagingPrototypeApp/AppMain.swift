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
        let plan = AppStartupPlan.resolve(arguments: arguments,
            environment: ProcessInfo.processInfo.environment,
            bundleIdentifier: Bundle.main.bundleIdentifier, bundleURL: Bundle.main.bundleURL,
            metadata: Bundle.main.object(forInfoDictionaryKey: NativeUITestEntry.metadataKey),
            gestureMetadata: Bundle.main.object(forInfoDictionaryKey: GestureValidationEntry.metadataKey),
            integratedMetadata: Bundle.main.object(forInfoDictionaryKey: IntegratedPreviewEntry.metadataKey))
        switch plan {
        case .reject:
            fputs("paging-ui-test: startup configuration rejected\n", stderr)
            exit(2)
        case .legacyReject(let error):
            fputs("paging-prototype: 参数错误：\(error)\n", stderr)
            fputs(AppArguments.helpText(), stderr)
            exit(2)
        case .check(let options):
            // Neutral resolver-only observation: no help/raw errors/diagnostic sessions.
            print("startup-check: isolated=\(options.uiTestProfile != nil) windowed=\(options.uiTestWindowed) folderLab=\(options.folderLab)")
            exit(0)
        case .performance:
            exit(PerfBenchmark.run())
        case .smoke:
            runSmoke(arguments: arguments)
            exit(0)
        case .application(let options, let parseError):
            if let parseError {
                fputs("paging-prototype: 参数错误：\(parseError)\n", stderr)
                fputs(AppArguments.helpText(), stderr)
            }
            if options.helpRequested {
                print(AppArguments.helpText())
                exit(0)
            }
            if options.pageHosting == .composited {
                print("paging-prototype: --page-hosting composited 保留未实现（ADR-002 方案 1 先行），本次以 live 运行")
            }
            let app = NSApplication.shared
            let delegate = AppDelegate(options: options)
            app.delegate = delegate
            app.setActivationPolicy(.regular)
            app.run()
        }
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
