import Foundation

/// The app packaging contract names one exact resource bundle. The development
/// accessor is lazy and is never evaluated for an .app, even when resources fail.
public enum LocalizationResourceBundleLocator {
    public static let resourceBundleName = "PagingPrototype_LauncherLocalization.bundle"

    public static func resourceBundleURL(
        mainBundleURL: URL,
        mainResourceURL: URL?,
        swiftPackageBundleURL: () -> URL
    ) -> URL {
        if mainBundleURL.pathExtension.lowercased() == "app" {
            let resources = mainResourceURL ?? mainBundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
            return resources.appendingPathComponent(resourceBundleName, isDirectory: true)
        }
        return swiftPackageBundleURL()
    }
}

/// Returns actual .strings table bytes. Providers are used only while creating a
/// snapshot or explicitly validating resources, never during text rendering.
public protocol LocalizationResourceProviding: Sendable {
    func localizableStringsData(for language: InterfaceLanguage) -> Data?
}

public struct BundleLocalizationResourceProvider: LocalizationResourceProviding {
    public let resourceBundleURL: URL

    public init(resourceBundleURL: URL = LocalizedStrings.resourceBundleURL) {
        self.resourceBundleURL = resourceBundleURL
    }

    public init(mainBundleURL: URL, mainResourceURL: URL?, swiftPackageBundleURL: () -> URL) {
        resourceBundleURL = LocalizationResourceBundleLocator.resourceBundleURL(
            mainBundleURL: mainBundleURL,
            mainResourceURL: mainResourceURL,
            swiftPackageBundleURL: swiftPackageBundleURL
        )
    }

    public func localizableStringsData(for language: InterfaceLanguage) -> Data? {
        // Do not use Bundle's OS-language negotiation for a manual app selection.
        let url = resourceBundleURL
            .appendingPathComponent(language.rawValue.lowercased() + ".lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings", isDirectory: false)
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            // Read one extra byte to detect oversized resources without loading them all.
            return try handle.read(upToCount: ResourceTable.maximumByteCount + 1)
        } catch {
            return nil
        }
    }
}

public enum LocalizationResourceIssueKind: String, Sendable {
    case missingResource
    case invalidTable
    case unexpectedKeys
    case missingKey
    case invalidValue
    case invalidPlaceholderSignature
}

/// Diagnostic metadata contains only supported language IDs, known schema keys,
/// and stable issue kinds. Resource values, unknown keys, paths and errors are omitted.
public struct LocalizationResourceIssue: Equatable, Sendable {
    public let language: InterfaceLanguage
    public let key: String?
    public let kind: LocalizationResourceIssueKind
}

public struct LocalizationResourceValidation: Equatable, Sendable {
    public let issues: [LocalizationResourceIssue]
    public var isValid: Bool { issues.isEmpty }
}

internal enum ResourceKey {
    case text(LocalizedTextKey)
    case settingsText(SettingsTextKey)
    case activationText(ActivationTextKey)
    case activationStatusText(ActivationStatusTextKey)
    case gridText(GridTextKey)
    case menuText(MenuTextKey)
    case catalogText(CatalogTextKey)
    case noticeText(NoticeTextKey)
    case actionFeedbackText(ActionFeedbackTextKey)
    case libraryText(LibraryTextKey)
    case mainGridCapacityText(MainGridCapacityTextKey)
    case liveAppearanceText(LiveAppearanceTextKey)
    case launchActivityText(LaunchActivityTextKey)
    case removalText(AppRemovalTextKey)
    case folderHelpOne
    case folderHelpOther
    case activationKeyCode
    case activationFutureVersion
    case languageFutureVersion
    case page
    case memberCountOne
    case memberCountOther
    case hiddenReferenceCountOne
    case hiddenReferenceCountOther

    static var all: [ResourceKey] {
        LocalizedTextKey.allCases.map { .text($0) } +
            [.languageFutureVersion, .page, .memberCountOne, .memberCountOther] +
            SettingsTextKey.allCases.map { .settingsText($0) } +
            [.hiddenReferenceCountOne, .hiddenReferenceCountOther, .folderHelpOne, .folderHelpOther, .activationFutureVersion, .activationKeyCode] +
            ActivationTextKey.allCases.map { .activationText($0) } +
            ActivationStatusTextKey.allCases.map { .activationStatusText($0) } +
            GridTextKey.allCases.map { .gridText($0) } +
            MenuTextKey.allCases.map { .menuText($0) } +
            CatalogTextKey.allCases.map { .catalogText($0) } +
            NoticeTextKey.allCases.map { .noticeText($0) } +
            ActionFeedbackTextKey.allCases.map { .actionFeedbackText($0) } +
            LibraryTextKey.allCases.map { .libraryText($0) } +
            MainGridCapacityTextKey.allCases.map { .mainGridCapacityText($0) } +
            LiveAppearanceTextKey.allCases.map { .liveAppearanceText($0) } +
            LaunchActivityTextKey.allCases.map { .launchActivityText($0) } +
            AppRemovalTextKey.allCases.map { .removalText($0) }
    }

    var name: String {
        switch self {
        case .text(let key): return key.rawValue
        case .settingsText(let key): return key.rawValue
        case .activationText(let key): return key.rawValue
        case .activationStatusText(let key): return key.rawValue
        case .gridText(let key): return key.rawValue
        case .menuText(let key): return key.rawValue
        case .catalogText(let key): return key.rawValue
        case .noticeText(let key): return key.rawValue
        case .actionFeedbackText(let key): return key.rawValue
        case .libraryText(let key): return key.rawValue
        case .mainGridCapacityText(let key): return key.rawValue
        case .liveAppearanceText(let key): return key.rawValue
        case .launchActivityText(let key): return key.rawValue
        case .removalText(let key): return key.rawValue
        case .folderHelpOne: return "folderHelpOne"
        case .folderHelpOther: return "folderHelpOther"
        case .activationKeyCode: return "activation.keyCode"
        case .activationFutureVersion: return "activationFutureVersion"
        case .languageFutureVersion: return "languageFutureVersion"
        case .page: return "page"
        case .memberCountOne: return "memberCountOne"
        case .memberCountOther: return "memberCountOther"
        case .hiddenReferenceCountOne: return "hiddenReferenceCountOne"
        case .hiddenReferenceCountOther: return "hiddenReferenceCountOther"
        }
    }

    var placeholders: [String] {
        switch self {
        case .text, .settingsText, .activationText, .activationStatusText, .gridText, .menuText, .catalogText, .noticeText, .actionFeedbackText, .libraryText, .mainGridCapacityText, .liveAppearanceText, .launchActivityText, .removalText: return []
        case .folderHelpOne, .folderHelpOther: return ["count"]
        case .activationKeyCode: return ["keyCode"]
        case .activationFutureVersion: return ["version"]
        case .languageFutureVersion: return ["version"]
        case .page: return ["page", "total"]
        case .memberCountOne, .memberCountOther, .hiddenReferenceCountOne, .hiddenReferenceCountOther: return ["count"]
        }
    }
}

internal struct ResourceTable: Sendable {
    static let maximumByteCount = 64 * 1024
    let templates: [String: ValidatedTemplate]
    let issues: [LocalizationResourceIssue]

    init(language: InterfaceLanguage, data: Data?) {
        guard let data else {
            templates = [:]
            issues = [.init(language: language, key: nil, kind: .missingResource)]
            return
        }
        guard data.count <= Self.maximumByteCount,
              let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let table = propertyList as? [String: String] else {
            templates = [:]
            issues = [.init(language: language, key: nil, kind: .invalidTable)]
            return
        }

        var parsed: [String: ValidatedTemplate] = [:]
        var problems: [LocalizationResourceIssue] = []
        let required = Set(ResourceKey.all.map(\.name))
        if table.keys.contains(where: { !required.contains($0) }) {
            problems.append(.init(language: language, key: nil, kind: .unexpectedKeys))
        }
        for key in ResourceKey.all {
            guard let value = table[key.name] else {
                problems.append(.init(language: language, key: key.name, kind: .missingKey))
                continue
            }
            guard Self.isSafeValue(value, key: key.name) else {
                problems.append(.init(language: language, key: key.name, kind: .invalidValue))
                continue
            }
            guard let template = ValidatedTemplate(value, placeholders: key.placeholders) else {
                problems.append(.init(language: language, key: key.name, kind: .invalidPlaceholderSignature))
                continue
            }
            parsed[key.name] = template
        }
        templates = parsed
        issues = problems
    }

    private static func isSafeValue(_ value: String, key: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != key && value.utf8.count <= 4096 &&
            !value.unicodeScalars.contains(where: {
                ($0.value < 32 && $0.value != 9 && $0.value != 10 && $0.value != 13) || $0.value == 127
            })
    }
}

/// Only named integer tokens are recognized. Percent signs and escaped resource
/// characters remain literal text; no resource ever becomes a printf format string.
internal struct ValidatedTemplate: Sendable {
    private enum Segment: Sendable {
        case literal(String)
        case integer(String)
    }

    private let segments: [Segment]
    private let placeholders: [String]

    init?(_ value: String, placeholders expected: [String]) {
        var parsed: [Segment] = []
        var found: [String] = []
        var cursor = value.startIndex
        var literalStart = cursor
        while cursor < value.endIndex {
            switch value[cursor] {
            case "{":
                if literalStart < cursor {
                    parsed.append(.literal(String(value[literalStart..<cursor])))
                }
                let tokenStart = value.index(after: cursor)
                guard let end = value[tokenStart...].firstIndex(of: "}") else { return nil }
                let token = String(value[tokenStart..<end])
                guard expected.contains(token) else { return nil }
                parsed.append(.integer(token))
                found.append(token)
                cursor = value.index(after: end)
                literalStart = cursor
            case "}":
                return nil
            default:
                cursor = value.index(after: cursor)
            }
        }
        guard found.sorted() == expected.sorted() else { return nil }
        if literalStart < value.endIndex {
            parsed.append(.literal(String(value[literalStart...])))
        }
        segments = parsed
        placeholders = expected
    }

    func render(_ arguments: [String: Int] = [:]) -> String? {
        guard arguments.keys.sorted() == placeholders.sorted() else { return nil }
        var output = ""
        for segment in segments {
            switch segment {
            case .literal(let text): output += text
            case .integer(let name):
                guard let value = arguments[name] else { return nil }
                // Int conversion is deterministic and independent of Locale.current.
                output += String(value)
            }
        }
        return output
    }
}
