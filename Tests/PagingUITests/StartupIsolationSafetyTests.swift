import XCTest
@testable import PagingPrototypeApp

/// Exercises only argument parsing and the pure decision before application assembly.
final class StartupIsolationSafetyTests: XCTestCase {
    func testTypedIsolationErrorsRejectEvenWithoutRawArguments() {
        let errors: [AppArguments.ParseError] = [
            .invalidUITestProfile,
            .uiTestProfileRequiresWindowed,
            .duplicateUITestProfile,
        ]

        for error in errors {
            XCTAssertTrue(AppStartupSafety.mustRejectStartup(error: error, arguments: []),
                          "Isolation error must never fall back: \(error)")
        }
    }

    func testActualIsolationParseFailuresRejectStartup() {
        assertParseFailure(["--ui-test-profile", "../invalid"], .invalidUITestProfile)
        assertParseFailure(["--ui-test-profile", "isolated-1"], .uiTestProfileRequiresWindowed)
        assertParseFailure([
            "--ui-test-windowed", "--ui-test-profile", "one", "--ui-test-profile", "two",
        ], .duplicateUITestProfile)
        assertParseFailure(["--ui-test-profile"], .missingValue("--ui-test-profile"))
        assertParseFailure(["--ui-test-profile", "--ui-test-windowed"],
                           .missingValue("--ui-test-profile"))
    }

    func testExactUITestIntentRejectsOtherParseFailuresInEitherOrder() {
        let intents = [
            ["--ui-test-windowed"],
            ["--ui-test-profile", "isolated-1"],
            ["--ui-test-windowed", "--ui-test-profile", "isolated-1"],
        ]
        let failures: [([String], AppArguments.ParseError)] = [
            (["--unknown-startup-option"], .unknownArgument("--unknown-startup-option")),
            (["--page-count", "not-an-integer"], .invalidInteger("--page-count", "not-an-integer")),
            (["--page-hosting", "unsupported"], .invalidHosting("unsupported")),
            (["--reduce-motion-override", "unsupported"], .invalidReduceMotion("unsupported")),
            // Telemetry validation scans the complete array before app-specific parsing.
            (["--run-id", ""], .telemetry(.missingValue("--run-id"))),
        ]

        for intent in intents {
            for (malformed, error) in failures {
                assertParseFailure(malformed + intent, error)
                assertParseFailure(intent + malformed, error)
            }
            assertParseFailure(intent + ["--page-count"], .missingValue("--page-count"))
            assertParseFailure(["--page-count"] + intent,
                               .invalidInteger("--page-count", intent[0]))
            assertParseFailure(intent + ["--run-id"], .telemetry(.missingValue("--run-id")))
            assertParseFailure(["--run-id"] + intent, .telemetry(.missingValue("--run-id")))
        }
    }

    func testUnsupportedEqualsAndCaseVariantsStillRejectStartup() {
        for variant in unsupportedUITestVariants {
            assertParseFailure([variant], .unknownArgument(variant))
        }
    }

    func testUnsupportedIntentCannotBeHiddenByAnotherEarlierOrLaterError() {
        for variant in unsupportedUITestVariants {
            assertParseFailure(["--unknown-startup-option", variant],
                               .unknownArgument("--unknown-startup-option"))
            assertParseFailure([variant, "--unknown-startup-option"], .unknownArgument(variant))
            assertParseFailure(["--page-count", "bad", variant], .invalidInteger("--page-count", "bad"))
            assertParseFailure([variant, "--page-count", "bad"], .unknownArgument(variant))
            assertParseFailure(["--run-id", "", variant], .telemetry(.missingValue("--run-id")))
            assertParseFailure([variant, "--run-id", ""], .telemetry(.missingValue("--run-id")))
        }
    }

    func testAllFourExistingTypedTuningErrorsRemainFatalWithoutUITestIntent() {
        let errors: [AppArguments.ParseError] = [
            .invalidMomentumDecay("bad"),
            .invalidMomentumGlideFrames("bad"),
            .invalidMomentumOvershoot("bad"),
            .invalidFrameTimerTolerance("bad"),
        ]

        for error in errors {
            XCTAssertTrue(AppStartupSafety.mustRejectStartup(error: error, arguments: []),
                          "Existing fatal tuning error must remain fatal: \(error)")
        }
    }

    func testActualTuningParseFailuresRemainFatalWithoutUITestIntent() {
        let failures: [([String], AppArguments.ParseError)] = [
            (["--momentum-decay", "0.49"], .invalidMomentumDecay("0.49")),
            (["--momentum-glide-frames", "11"], .invalidMomentumGlideFrames("11")),
            (["--momentum-overshoot", "0.04"], .invalidMomentumOvershoot("0.04")),
            (["--frame-timer-tolerance-ms", "16.668"], .invalidFrameTimerTolerance("16.668")),
        ]

        for (arguments, error) in failures {
            assertParseFailure(arguments, error)
        }
    }

    func testOrdinaryTypedErrorsPreserveLegacyFallbackWithoutUITestIntent() {
        let errors: [AppArguments.ParseError] = [
            .unknownArgument("--unknown-startup-option"),
            .invalidInteger("--page-count", "bad"),
            .missingValue("--page-count"),
            .invalidFrameDriver("unsupported"),
        ]

        for arguments in [[], ["--fullscreen"], ["--folder-lab"], ["--fullscreen", "--folder-lab"]] {
            for error in errors {
                XCTAssertFalse(AppStartupSafety.mustRejectStartup(error: error, arguments: arguments),
                               "Ordinary flags must not imply UI test intent: \(arguments), \(error)")
            }
        }
    }

    func testActualOrdinaryParseFailuresPreserveLegacyFallback() {
        assertParseFailure(["--frame-driver", "unsupported"], .invalidFrameDriver("unsupported"), mustReject: false)
        for flags in [[], ["--fullscreen"], ["--folder-lab"], ["--fullscreen", "--folder-lab"]] {
            assertParseFailure(flags + ["--unknown-startup-option"],
                               .unknownArgument("--unknown-startup-option"), mustReject: false)
            assertParseFailure(["--unknown-startup-option"] + flags,
                               .unknownArgument("--unknown-startup-option"), mustReject: false)
            assertParseFailure(flags + ["--page-count", "bad"],
                               .invalidInteger("--page-count", "bad"), mustReject: false)
            assertParseFailure(["--page-count", "bad"] + flags,
                               .invalidInteger("--page-count", "bad"), mustReject: false)
            assertParseFailure(flags + ["--page-count"], .missingValue("--page-count"), mustReject: false)
        }
    }

    private var unsupportedUITestVariants: [String] {
        [
            "--ui-test-windowed=true",
            "--ui-test-windowed=false",
            "--ui-test-windowed=",
            "--ui-test-profile=isolated-1",
            "--ui-test-profile=",
            "--UI-TEST-WINDOWED",
            "--UI-TEST-PROFILE",
            "--Ui-Test-Windowed",
            "--Ui-Test-Profile",
            "--UI-TEST-WINDOWED=true",
            "--UI-TEST-PROFILE=isolated-1",
        ]
    }

    private func assertParseFailure(
        _ arguments: [String],
        _ expectedError: AppArguments.ParseError,
        mustReject: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = AppArguments.parse(arguments) else {
            return XCTFail("Expected a parse failure for \(arguments)", file: file, line: line)
        }
        XCTAssertEqual(error, expectedError, "Arguments: \(arguments)", file: file, line: line)
        XCTAssertEqual(AppStartupSafety.mustRejectStartup(error: error, arguments: arguments), mustReject,
                       "Startup decision for \(arguments): \(error)", file: file, line: line)
    }
}
