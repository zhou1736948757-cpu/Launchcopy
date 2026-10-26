import Foundation

// Resource-only smoke: no AppKit, app executable, preferences or development fallback.
// Accept exactly the packaged .bundle path; read no other resource location.
guard CommandLine.arguments.count == 2 else {
    fputs("localization-smoke: expected one packaged bundle path\n", stderr)
    exit(2)
}
let bundleURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard let bundle = Bundle(url: bundleURL) else {
    fputs("localization-smoke: invalid packaged bundle\n", stderr)
    exit(1)
}
let languages = ["en", "zh-Hans", "ja"]
// Independent removal-key and signature contracts; parity alone can hide omissions.
let removalKeys: Set<String> = [
    "appRemoval.moveToTrash", "appRemoval.confirmTitle", "appRemoval.confirmMessage",
    "appRemoval.cancel", "appRemoval.confirmMove", "appRemoval.inspecting",
    "appRemoval.moving", "appRemoval.moved", "appRemoval.unavailable",
    "appRemoval.running", "appRemoval.failed", "appRemoval.changed",
    "appRemoval.quitTitle", "appRemoval.quitMessage"
]
let expectedSignatures = [
    "languageFutureVersion": ["version"], "page": ["page", "total"],
    "memberCountOne": ["count"], "memberCountOther": ["count"],
    "hiddenReferenceCountOne": ["count"], "hiddenReferenceCountOther": ["count"],
    "folderHelpOne": ["count"], "folderHelpOther": ["count"],
    "activationFutureVersion": ["version"], "activation.keyCode": ["keyCode"]
]
let tokenExpression = try NSRegularExpression(pattern: #"\{([^{}]*)\}"#)
var baselineKeys: Set<String>?
var checked = 0
for language in languages {
    guard let path = bundle.path(forResource: language.lowercased(), ofType: "lproj"),
          let localizedBundle = Bundle(path: path),
          let tableURL = localizedBundle.url(forResource: "Localizable", withExtension: "strings"),
          let data = try? Data(contentsOf: tableURL),
          let property = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
          let table = property as? [String: String], !table.isEmpty else {
        fputs("localization-smoke: incomplete packaged language resources\n", stderr)
        exit(1)
    }
    let keys = Set(table.keys)
    guard keys.count == 369,
          keys.contains("activation.fourFingerOutwardHideEnable"),
          keys.contains("activation.fourFingerOutwardHideHelp"),
          keys.contains("grid.newFolderFallbackTitle"),
          keys.contains("grid.newFolderNameJoiner"),
          Set(keys.filter { $0.hasPrefix("appRemoval.") }) == removalKeys else {
        fputs("localization-smoke: required key count or removal key contract invalid\n", stderr)
        exit(1)
    }
    if let baselineKeys, baselineKeys != keys {
        fputs("localization-smoke: mismatched language key sets\n", stderr)
        exit(1)
    }
    baselineKeys = keys
    for (key, expected) in table {
        let source = expected as NSString
        let matches = tokenExpression.matches(in: expected, range: NSRange(location: 0, length: source.length))
        let tokens = matches.map { source.substring(with: $0.range(at: 1)) }.sorted()
        let literal = tokenExpression.stringByReplacingMatches(
            in: expected, range: NSRange(location: 0, length: source.length), withTemplate: ""
        )
        guard tokens == (expectedSignatures[key] ?? []).sorted(),
              !literal.contains("{"), !literal.contains("}"),
              !removalKeys.contains(key) || !expected.contains("%") else {
            fputs("localization-smoke: packaged placeholder signature invalid\n", stderr)
            exit(1)
        }
        guard !expected.isEmpty,
              localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable") == expected else {
            fputs("localization-smoke: explicit packaged lookup failed\n", stderr)
            exit(1)
        }
        checked += 1
    }
}
print("localization-smoke: verified \(languages.count) packaged languages / 369 required keys and signatures / \(checked) entries without build-directory resource fallback")
