//
//  AppArgumentsTests.swift
//  PagingUITests
//
//  App 入口命令行参数（§10）：全部参数可用、默认值、错误处理（打印帮助不崩溃）、
//  telemetry 参数委托、--page-hosting composited 保留提示路径。
//

import XCTest
@testable import PagingPrototypeApp

final class AppArgumentsTests: XCTestCase {

    private func parse(_ arguments: [String]) throws -> AppArguments.Options {
        try AppArguments.parse(arguments).get()
    }

    func testNoArgumentsDefaults() throws {
        let options = try parse([])
        XCTAssertFalse(options.pagingLab)
        XCTAssertNil(options.pageCount)
        XCTAssertNil(options.itemsPerPage)
        XCTAssertEqual(options.pageHosting, .live)
        XCTAssertEqual(options.reduceMotionOverride, .system)
        XCTAssertFalse(options.fullscreen)
        XCTAssertFalse(options.uiTestWindowed)
        XCTAssertNil(options.uiTestProfile)
        XCTAssertNil(options.frameTimerToleranceMS)
        XCTAssertFalse(options.frameProfile)
        XCTAssertFalse(options.frameCallbackProfile)
        XCTAssertFalse(options.runLoopProfile)
        XCTAssertFalse(options.disableTelemetryBridge)
        XCTAssertFalse(options.telemetryEnabled)
        XCTAssertNil(options.runID)
        XCTAssertFalse(options.helpRequested)
    }

    func testAllArgumentsParsed() throws {
        let options = try parse([
            "--paging-lab",
            "--page-count", "12",
            "--items-per-page", "40",
            "--page-hosting", "live",
            "--reduce-motion-override", "on",
            "--fullscreen",
            "--paging-telemetry",
            "--run-id", "smoke-001",
        ])
        XCTAssertTrue(options.pagingLab)
        XCTAssertEqual(options.pageCount, 12)
        XCTAssertEqual(options.itemsPerPage, 40)
        XCTAssertEqual(options.pageHosting, .live)
        XCTAssertEqual(options.reduceMotionOverride, .on)
        XCTAssertTrue(options.fullscreen)
        XCTAssertTrue(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "smoke-001")
    }

    func testBackgroundUIWindowIsExplicitlyOptIn() throws {
        let windowed = try parse(["--ui-test-windowed"])
        XCTAssertTrue(windowed.uiTestWindowed)
        XCTAssertNil(windowed.uiTestProfile, "Window policy alone does not select isolated storage")
        let combined = try parse(["--fullscreen", "--ui-test-windowed"])
        XCTAssertTrue(combined.uiTestWindowed)
        XCTAssertTrue(combined.fullscreen, "Application assembly gives test mode precedence")
    }

    func testUITestProfileParsesWithWindowedInEitherOrder() throws {
        for arguments in [
            ["--ui-test-windowed", "--ui-test-profile", "rename-01"],
            ["--ui-test-profile", "rename-01", "--ui-test-windowed"],
        ] {
            let options = try parse(arguments)
            XCTAssertEqual(options.uiTestProfile, "rename-01")
            XCTAssertTrue(options.uiTestWindowed)
            XCTAssertFalse(options.telemetryEnabled)
            XCTAssertTrue(options.catalogRoots.isEmpty)
        }
    }

    func testUITestProfileAcceptsExactIdentifierBounds() throws {
        for id in ["a", "0", "a-", "a--b", String(repeating: "z", count: 48)] {
            let options = try parse(["--ui-test-windowed", "--ui-test-profile", id])
            XCTAssertEqual(options.uiTestProfile, id)
        }
    }

    func testUITestProfileInvalidIdentifiersNeverFallBack() {
        for id in ["", "-a", "A", "a_b", "a.b", "../a", "/tmp/a", "a/b", "a\\b",
                   " a", "a ", "a\n", "a\0", "é", "测试", "ａ", String(repeating: "a", count: 49)] {
            assertParseError(["--ui-test-windowed", "--ui-test-profile", id], .invalidUITestProfile)
        }
    }

    func testUITestProfileRequiresWindowedEvenWithHelpOrFullscreen() {
        for suffix in [[], ["--fullscreen"], ["--help"], ["-h"]] {
            assertParseError(["--ui-test-profile", "rename-01"] + suffix, .uiTestProfileRequiresWindowed)
        }
    }

    func testUITestProfileMissingValuesAndRepeatedFlagReject() {
        assertParseError(["--ui-test-windowed", "--ui-test-profile"], .missingValue("--ui-test-profile"))
        assertParseError(["--ui-test-profile", "--ui-test-windowed"], .missingValue("--ui-test-profile"))
        assertParseError([
            "--ui-test-windowed", "--ui-test-profile", "one", "--ui-test-profile", "two",
        ], .duplicateUITestProfile)
        assertParseError([
            "--ui-test-windowed", "--ui-test-profile", "../bad", "--ui-test-profile", "valid",
        ], .invalidUITestProfile)
        assertParseError(["--ui-test-windowed", "--ui-test-profile=one"], .unknownArgument("--ui-test-profile=one"))
    }

    func testUITestProfileCoexistsWithExistingFlags() throws {
        let options = try parse([
            "/tmp/Launchcopy.app/Contents/MacOS/PagingPrototypeApp",
            "--ui-test-profile", "appearance-1", "--ui-test-windowed", "--fullscreen",
            "--catalog-root", "/tmp/synthetic-apps", "--folder-lab", "--paging-telemetry",
            "--run-id", "isolated-run", "--page-count", "3",
        ])
        XCTAssertEqual(options.uiTestProfile, "appearance-1")
        XCTAssertTrue(options.uiTestWindowed)
        XCTAssertTrue(options.fullscreen, "Assembly gives windowed mode precedence")
        XCTAssertTrue(options.folderLab)
        XCTAssertTrue(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "isolated-run")
        XCTAssertEqual(options.pageCount, 3)
        XCTAssertEqual(options.catalogRoots, [URL(fileURLWithPath: "/tmp/synthetic-apps")])
    }

    private func assertParseError(
        _ arguments: [String], _ expected: AppArguments.ParseError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(try parse(arguments), file: file, line: line) { error in
            XCTAssertEqual(error as? AppArguments.ParseError, expected, file: file, line: line)
        }
    }

    func testFullscreenFlagParsed() throws {
        // T-worker-b-fullscreen：--fullscreen 布尔可选；缺省 false（窗口形态）。
        XCTAssertTrue(try parse(["--fullscreen"]).fullscreen)
        XCTAssertFalse(try parse([]).fullscreen)
        XCTAssertFalse(try parse(["--paging-lab"]).fullscreen)
        XCTAssertTrue(try parse(["--fullscreen", "--paging-lab"]).fullscreen)
    }

    func testPageHostingCompositedAcceptedButNotImplemented() throws {
        let options = try parse(["--page-hosting", "composited"])
        XCTAssertEqual(options.pageHosting, .composited)
        // AppMain 对 composited 打印"保留未实现，按 live 运行"提示（见 AppMain.swift）。
    }

    func testReduceMotionOff() throws {
        let options = try parse(["--reduce-motion-override", "off"])
        XCTAssertEqual(options.reduceMotionOverride, .off)
    }

    func testHelpRequested() throws {
        XCTAssertTrue(try parse(["--help"]).helpRequested)
        XCTAssertTrue(try parse(["-h"]).helpRequested)
    }

    // MARK: - --momentum-decay（T-worker-b-tune 物理调参）

    func testMomentumDecayParsed() throws {
        XCTAssertEqual(try parse(["--momentum-decay", "0.85"]).momentumDecay, 0.85)
        XCTAssertEqual(try parse(["--momentum-decay", "0.50"]).momentumDecay, 0.50) // 下界（tune2 扩展）
        XCTAssertEqual(try parse(["--momentum-decay", "0.99"]).momentumDecay, 0.99) // 上界
        XCTAssertNil(try parse([]).momentumDecay, "缺省 = nil（用 PagingParameters 默认）")
    }

    func testMomentumDecayOutOfRangeFails() throws {
        // 越界/非数字 → 显式失败（AppMain 打印帮助后 exit 2，不静默回退默认）。
        // 注意：0.79/0.5 在 0.50–0.99 扩展范围内（tune2），已是合法值；越界用 0.49。
        XCTAssertThrowsError(try parse(["--momentum-decay", "1.5"]))
        XCTAssertThrowsError(try parse(["--momentum-decay", "0.49"])) // 新下界之下
        XCTAssertThrowsError(try parse(["--momentum-decay", "1.0"]))
        XCTAssertThrowsError(try parse(["--momentum-decay", "abc"]))
        XCTAssertThrowsError(try parse(["--momentum-decay"])) // 缺值
        XCTAssertThrowsError(try parse(["--momentum-decay", "0,85"])) // 本地化小数分隔符不认
        // 原 0.79/0.5 越界用例：扩展后为合法值，转为正向断言。
        XCTAssertEqual(try parse(["--momentum-decay", "0.79"]).momentumDecay, 0.79)
        XCTAssertEqual(try parse(["--momentum-decay", "0.5"]).momentumDecay, 0.5)
    }

    // MARK: - --momentum-glide-frames（T-worker-b-glide 系统流截断调参）

    func testMomentumGlideFramesParsed() throws {
        XCTAssertEqual(try parse(["--momentum-glide-frames", "0"]).momentumGlideFrames, 0) // 直接决策
        XCTAssertEqual(try parse(["--momentum-glide-frames", "1"]).momentumGlideFrames, 1) // 试值
        XCTAssertEqual(try parse(["--momentum-glide-frames", "10"]).momentumGlideFrames, 10) // 上界
        XCTAssertNil(try parse([]).momentumGlideFrames, "CLI 缺省 = nil（用 PagingParameters 默认 1）")
    }

    func testMomentumGlideFramesOutOfRangeFails() {
        XCTAssertThrowsError(try parse(["--momentum-glide-frames", "11"])) // 上界之上
        XCTAssertThrowsError(try parse(["--momentum-glide-frames", "-1"]))
        XCTAssertThrowsError(try parse(["--momentum-glide-frames", "abc"]))
        XCTAssertThrowsError(try parse(["--momentum-glide-frames", "1.5"])) // 非整数
        XCTAssertThrowsError(try parse(["--momentum-glide-frames"])) // 缺值
    }

    // MARK: - --momentum-overshoot（T-worker-b-overshoot2 过冲钳制调参）

    func testMomentumOvershootParsed() throws {
        XCTAssertEqual(try parse(["--momentum-overshoot", "0.2"]).momentumOvershoot, 0.2) // 试值
        XCTAssertEqual(try parse(["--momentum-overshoot", "0.05"]).momentumOvershoot, 0.05) // 下界
        XCTAssertEqual(try parse(["--momentum-overshoot", "1.0"]).momentumOvershoot, 1.0) // 上界
        XCTAssertNil(try parse([]).momentumOvershoot, "缺省 = nil（用 PagingParameters 默认 0.20）")
    }

    func testMomentumOvershootOutOfRangeFails() {
        XCTAssertThrowsError(try parse(["--momentum-overshoot", "1.1"])) // 上界之上
        XCTAssertThrowsError(try parse(["--momentum-overshoot", "0.04"])) // 下界之下
        XCTAssertThrowsError(try parse(["--momentum-overshoot", "abc"]))
        XCTAssertThrowsError(try parse(["--momentum-overshoot", "0,2"])) // 本地化小数分隔符不认
        XCTAssertThrowsError(try parse(["--momentum-overshoot"])) // 缺值
    }

    // MARK: - 错误处理（帮助不崩溃）

    func testInvalidPageCount() {
        XCTAssertThrowsError(try parse(["--page-count", "abc"]))
        XCTAssertThrowsError(try parse(["--page-count", "0"]))
        XCTAssertThrowsError(try parse(["--page-count", "-3"]))
    }

    func testInvalidItemsPerPage() {
        XCTAssertThrowsError(try parse(["--items-per-page", "0"]))
        XCTAssertThrowsError(try parse(["--items-per-page", "x"]))
    }

    func testInvalidHostingAndReduceMotion() {
        XCTAssertThrowsError(try parse(["--page-hosting", "hybrid"]))
        XCTAssertThrowsError(try parse(["--reduce-motion-override", "sometimes"]))
    }

    func testMissingValues() {
        XCTAssertThrowsError(try parse(["--page-count"]))
        XCTAssertThrowsError(try parse(["--items-per-page"]))
        XCTAssertThrowsError(try parse(["--page-hosting"]))
        XCTAssertThrowsError(try parse(["--reduce-motion-override"]))
    }

    func testUnknownArgument() {
        XCTAssertThrowsError(try parse(["--bogus-flag"]))
    }

    func testTelemetryDelegationError() {
        // --run-id 缺少取值：委托 TelemetryArguments 返回错误。
        XCTAssertThrowsError(try parse(["--run-id"]))
    }

    func testHelpTextIsNonEmpty() {
        XCTAssertFalse(AppArguments.helpText().isEmpty)
        XCTAssertTrue(AppArguments.helpText().contains("--page-count"))
        XCTAssertTrue(AppArguments.helpText().contains("--page-hosting"))
        XCTAssertTrue(AppArguments.helpText().contains("--reduce-motion-override"))
        XCTAssertTrue(AppArguments.helpText().contains("--momentum-decay"))
        XCTAssertTrue(AppArguments.helpText().contains("--momentum-glide-frames"))
        XCTAssertTrue(AppArguments.helpText().contains("--momentum-overshoot"))
        XCTAssertTrue(AppArguments.helpText().contains("--fullscreen"))
        XCTAssertTrue(AppArguments.helpText().contains("--ui-test-windowed"))
        XCTAssertTrue(AppArguments.helpText().contains("--ui-test-profile <id>"))
        XCTAssertTrue(AppArguments.helpText().contains("[a-z0-9][a-z0-9-]{0,47}"))
        XCTAssertTrue(AppArguments.helpText().contains(".build/candidates"))
        XCTAssertTrue(AppArguments.helpText().contains("--catalog-root"))
        XCTAssertTrue(AppArguments.helpText().contains("--neutral-content"))
        XCTAssertTrue(AppArguments.helpText().contains("--frame-driver"))
        XCTAssertTrue(AppArguments.helpText().contains("--frame-timer-tolerance-ms"))
        XCTAssertTrue(AppArguments.helpText().contains("--frame-callback-profile"))
        XCTAssertTrue(AppArguments.helpText().contains("--runloop-profile"))
        XCTAssertTrue(AppArguments.helpText().contains("--disable-telemetry-bridge"))
    }

    // MARK: - Phase 1B Wave 3：--catalog-root / --neutral-content / --frame-driver（t10）

    func testCatalogRootDefaultsToEmpty() throws {
        // 缺省 = 空数组 → AppCatalogAssembly 落到 CatalogRoots.defaults（4 受限根，§5.2 上界）。
        XCTAssertTrue(try parse([]).catalogRoots.isEmpty)
    }

    func testCatalogRootSingleAndRepeatable() throws {
        let single = try parse(["--catalog-root", "/tmp/fake-apps"])
        XCTAssertEqual(single.catalogRoots, [URL(fileURLWithPath: "/tmp/fake-apps")])
        // 可重复（可多根扫描）。
        let multi = try parse([
            "--catalog-root", "/tmp/fake-apps-a",
            "--catalog-root", "/tmp/fake-apps-b",
        ])
        XCTAssertEqual(multi.catalogRoots, [
            URL(fileURLWithPath: "/tmp/fake-apps-a"),
            URL(fileURLWithPath: "/tmp/fake-apps-b"),
        ])
    }

    func testCatalogRootMissingValueFails() {
        XCTAssertThrowsError(try parse(["--catalog-root"]))
    }

    func testNeutralContentParsed() throws {
        XCTAssertFalse(try parse([]).neutralContent)
        XCTAssertTrue(try parse(["--neutral-content"]).neutralContent)
        // 与既有参数共存。
        XCTAssertTrue(try parse(["--neutral-content", "--paging-lab", "--page-count", "3"]).neutralContent)
    }

    func testFrameDriverParsed() throws {
        XCTAssertEqual(try parse([]).frameDriver, .runloop, "缺省 = runloop（Phase 1A 稳定路径）")
        XCTAssertEqual(try parse(["--frame-driver", "runloop"]).frameDriver, .runloop)
        XCTAssertEqual(try parse(["--frame-driver", "displaylink"]).frameDriver, .displaylink)
        XCTAssertEqual(try parse(["--frame-driver", "auto"]).frameDriver, .auto)
    }

    func testFrameDriverInvalidFails() {
        XCTAssertThrowsError(try parse(["--frame-driver", "vulkan"]))
        XCTAssertThrowsError(try parse(["--frame-driver"])) // 缺值
    }

    func testFrameTimerToleranceParsed() throws {
        XCTAssertNil(try parse([]).frameTimerToleranceMS, "nil = 保留 8.333ms 生产默认")
        XCTAssertEqual(try parse(["--frame-timer-tolerance-ms", "0"]).frameTimerToleranceMS, 0)
        XCTAssertEqual(try parse(["--frame-timer-tolerance-ms", "8.333"]).frameTimerToleranceMS, 8.333)
        XCTAssertEqual(try parse(["--frame-timer-tolerance-ms", "16.667"]).frameTimerToleranceMS, 16.667)
    }

    func testFrameTimerToleranceInvalidFails() {
        XCTAssertThrowsError(try parse(["--frame-timer-tolerance-ms", "-0.1"]))
        XCTAssertThrowsError(try parse(["--frame-timer-tolerance-ms", "16.668"]))
        XCTAssertThrowsError(try parse(["--frame-timer-tolerance-ms", "nan"]))
        XCTAssertThrowsError(try parse(["--frame-timer-tolerance-ms"]))
    }

    func testFrameCallbackProfileParsedIndependently() throws {
        let callbackOnly = try parse(["--frame-callback-profile"])
        XCTAssertTrue(callbackOnly.frameCallbackProfile)
        XCTAssertFalse(callbackOnly.frameProfile)
        XCTAssertFalse(callbackOnly.runLoopProfile)
        XCTAssertFalse(callbackOnly.telemetryEnabled)

        let runLoopOnly = try parse(["--runloop-profile"])
        XCTAssertTrue(runLoopOnly.runLoopProfile)
        XCTAssertFalse(runLoopOnly.frameProfile)
        XCTAssertFalse(runLoopOnly.frameCallbackProfile)

        let allProfiles = try parse(["--frame-profile", "--frame-callback-profile", "--runloop-profile"])
        XCTAssertTrue(allProfiles.frameProfile)
        XCTAssertTrue(allProfiles.frameCallbackProfile)
        XCTAssertTrue(allProfiles.runLoopProfile)
    }

    func testDisableTelemetryBridgeParsedIndependently() throws {
        let options = try parse(["--disable-telemetry-bridge", "--run-id", "callback-control"])
        XCTAssertTrue(options.disableTelemetryBridge)
        XCTAssertFalse(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "callback-control")
    }
}
