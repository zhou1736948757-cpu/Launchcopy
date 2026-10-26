import Foundation
import XCTest
import LauncherLocalization

final class LocalizationResourceBundleTests: XCTestCase {
    func testAppLocatorUsesOnlyExactPackagedBundleAndNeverEvaluatesDevelopmentAccessor() {
        let app = URL(fileURLWithPath: "/synthetic/Launchcopy.app", isDirectory: true)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        let result = LocalizationResourceBundleLocator.resourceBundleURL(
            mainBundleURL: app, mainResourceURL: resources,
            swiftPackageBundleURL: {
                XCTFail("An app must not inspect SwiftPM development resources")
                return URL(fileURLWithPath: "/synthetic/development.bundle")
            }
        )
        XCTAssertEqual(result, resources.appendingPathComponent("PagingPrototype_LauncherLocalization.bundle", isDirectory: true))
        XCTAssertEqual(LocalizationResourceBundleLocator.resourceBundleName, "PagingPrototype_LauncherLocalization.bundle")
    }

    func testMissingAppResourceURLStillLocatesOnlyPackagedPath() {
        let app = URL(fileURLWithPath: "/synthetic/Launchcopy.APP", isDirectory: true)
        let result = LocalizationResourceBundleLocator.resourceBundleURL(
            mainBundleURL: app, mainResourceURL: nil,
            swiftPackageBundleURL: {
                XCTFail("Missing app resources cannot enable development fallback")
                return URL(fileURLWithPath: "/synthetic/development.bundle")
            }
        )
        XCTAssertEqual(result, app.appendingPathComponent("Contents/Resources/PagingPrototype_LauncherLocalization.bundle", isDirectory: true))
    }

    func testNonAppSwiftPMTestOrCLIUsesModuleAccessorLazily() {
        let expected = URL(fileURLWithPath: "/synthetic/package.bundle", isDirectory: true)
        var requests = 0
        for component in ["tool", "Tests.xctest", "folder.app.backup"] {
            let result = LocalizationResourceBundleLocator.resourceBundleURL(
                mainBundleURL: URL(fileURLWithPath: "/synthetic/\(component)"), mainResourceURL: nil,
                swiftPackageBundleURL: { requests += 1; return expected }
            )
            XCTAssertEqual(result, expected)
        }
        XCTAssertEqual(requests, 3)
    }

    func testMissingPackagedBundleReturnsSafeEnglishWithoutConsultingDevelopmentBundle() {
        let app = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("absent-localization-\(UUID().uuidString).app", isDirectory: true)
        let provider = BundleLocalizationResourceProvider(
            mainBundleURL: app, mainResourceURL: nil,
            swiftPackageBundleURL: {
                XCTFail("Even a valid development bundle must never rescue an app")
                return LocalizedStrings.resourceBundleURL
            }
        )
        XCTAssertEqual(provider.resourceBundleURL, app.appendingPathComponent("Contents/Resources/PagingPrototype_LauncherLocalization.bundle", isDirectory: true))
        XCTAssertTrue(LocalizedStrings.validateResources(resourceProvider: provider).issues.allSatisfy { $0.kind == .missingResource })
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        XCTAssertEqual(strings.text(.apply), "Apply")
        XCTAssertEqual(strings.memberCount(1), "1 item")
        XCTAssertEqual(strings.page(2, total: 4), "Page 2 of 4")
        XCTAssertEqual(strings.settingsText(.appearanceTabTitle), "Appearance")
        XCTAssertEqual(strings.hiddenReferenceCount(1), "1 hidden reference (including apps not currently installed)")
    }

    func testPackagedAppResourceLayoutLoadsActualTablesWithoutDevelopmentAccessor() throws {
        let fixture = try makePackagedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let provider = BundleLocalizationResourceProvider(
            mainBundleURL: fixture.app, mainResourceURL: fixture.resources,
            swiftPackageBundleURL: {
                XCTFail("The app resource layout must stand alone")
                return LocalizedStrings.resourceBundleURL
            }
        )
        XCTAssertEqual(provider.resourceBundleURL, fixture.bundle)
        XCTAssertTrue(LocalizedStrings.validateResources(resourceProvider: provider).isValid)
        XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).text(.apply), "適用")
        XCTAssertEqual(LocalizedStrings(language: .simplifiedChinese, resourceProvider: provider).text(.apply), "应用")
        for language in InterfaceLanguage.allCases {
            let table = try LocalizationTestResources.table(language)
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in SettingsTextKey.allCases {
                XCTAssertEqual(strings.settingsText(key), table[key.rawValue], "\(language.rawValue):\(key.rawValue)")
            }
        }
        XCTAssertEqual(LocalizedStrings(language: .simplifiedChinese, resourceProvider: provider).hiddenReferenceCount(2),
                       "2 个隐藏引用（含暂未安装的应用）")
        XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).hiddenReferenceCount(2),
                       "非表示の参照 2 件（現在インストールされていないアプリを含む）")
    }

    func testInvalidPackagedTablesDoNotFallBackToDevelopmentBundle() throws {
        let fixture = try makePackagedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        for language in InterfaceLanguage.allCases {
            let url = fixture.bundle.appendingPathComponent("\(language.rawValue.lowercased()).lproj/Localizable.strings")
            try Data("invalid resource bytes".utf8).write(to: url)
        }
        let provider = BundleLocalizationResourceProvider(
            mainBundleURL: fixture.app, mainResourceURL: fixture.resources,
            swiftPackageBundleURL: {
                XCTFail("Invalid app tables cannot enable development fallback")
                return LocalizedStrings.resourceBundleURL
            }
        )
        let report = LocalizedStrings.validateResources(resourceProvider: provider)
        XCTAssertEqual(report.issues.count, 3)
        XCTAssertTrue(report.issues.allSatisfy { $0.kind == .invalidTable })
        XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).text(.apply), "Apply")
    }

    func testEffectiveURLReportsCurrentLocator() {
        let expected = LocalizationResourceBundleLocator.resourceBundleURL(
            mainBundleURL: Bundle.main.bundleURL, mainResourceURL: Bundle.main.resourceURL,
            swiftPackageBundleURL: { LocalizedStrings.resourceBundleURL }
        )
        XCTAssertEqual(LocalizedStrings.resourceBundleURL, expected)
    }

    private func makePackagedFixture() throws -> (root: URL, app: URL, resources: URL, bundle: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("localization-fixture-\(UUID().uuidString)", isDirectory: true)
        let app = root.appendingPathComponent("Launchcopy.app", isDirectory: true)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        let bundle = resources.appendingPathComponent(LocalizationResourceBundleLocator.resourceBundleName, isDirectory: true)
        do {
            for language in InterfaceLanguage.allCases {
                let directory = bundle.appendingPathComponent("\(language.rawValue.lowercased()).lproj", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try XCTUnwrap(BundleLocalizationResourceProvider().localizableStringsData(for: language))
                try data.write(to: directory.appendingPathComponent("Localizable.strings"))
            }
            return (root, app, resources, bundle)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}
