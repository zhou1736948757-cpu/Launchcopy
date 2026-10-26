import Foundation

/// Pure entry validation before AppKit, stores or diagnostic sessions.
enum AppStartupPlan {
    enum Action {
        case check(AppArguments.Options)
        case performance
        case smoke
        case application(AppArguments.Options, parseError: AppArguments.ParseError?)
        case reject(NativeUITestEntry.Rejection)
        case legacyReject(AppArguments.ParseError)
    }

    static func resolve(arguments: [String], environment: [String: String],
                        bundleIdentifier: String?, bundleURL: URL, metadata: Any?,
                        gestureMetadata: Any? = nil, integratedMetadata: Any? = nil) -> Action {
        let check = environment["LAUNCHCOPY_STARTUP_CHECK"] == "1"
        let performance = environment["PAGING_PROTOTYPE_PERF"] == "1"
        let smoke = environment["PAGING_PROTOTYPE_SMOKE"] == "1"
        let integratedIntent = integratedMetadata != nil || bundleIdentifier == IntegratedPreviewEntry.reservedBundleID
        if integratedIntent {
            switch IntegratedPreviewEntry.resolve(arguments: arguments, bundleIdentifier: bundleIdentifier,
                bundleURL: bundleURL, metadata: integratedMetadata, uiTestMetadata: metadata,
                gestureMetadata: gestureMetadata) {
            case .failure(let error): return .reject(error)
            case .success(let options):
                guard !performance, !smoke, environment["PAGING_PROTOTYPE_GUI_SELFDRIVE"] != "1" else {
                    return .reject(.invalidArguments)
                }
                if check { return .check(options) }
                return .application(options, parseError: nil)
            }
        }
        let gestureIntent = gestureMetadata != nil || bundleIdentifier == GestureValidationEntry.reservedBundleID
        if gestureIntent {
            // Validate the dedicated identity and both markers before any headless bypass.
            switch GestureValidationEntry.resolve(arguments: arguments, bundleIdentifier: bundleIdentifier,
                bundleURL: bundleURL, metadata: gestureMetadata, uiTestMetadata: metadata) {
            case .failure(let error):
                return .reject(error)
            case .success(let options):
                if check { return .check(options) }
                guard !performance, !smoke else { return .reject(.invalidArguments) }
                return .application(options, parseError: nil)
            }
        }
        let testIntent = metadata != nil || bundleIdentifier == NativeUITestEntry.reservedBundleID
            || AppStartupSafety.hasUITestIntent(arguments: arguments)
        // Preserve ordinary pre-existing headless behavior only when no check/test intent.
        if !check, !testIntent {
            if performance { return .performance }
            if smoke { return .smoke }
        }
        let parsed = AppArguments.parse(arguments)
        let entry = NativeUITestEntry.resolve(arguments: arguments, parsed: parsed,
            bundleIdentifier: bundleIdentifier, bundleURL: bundleURL, metadata: metadata)
        guard case .success(let options) = entry else {
            if !check, !testIntent, case .failure(let error) = parsed,
               AppStartupSafety.mustRejectStartup(error: error, arguments: arguments) {
                return .legacyReject(error)
            }
            if case .failure(let error) = entry { return .reject(error) }
            return .reject(.invalidArguments)
        }
        if check { return .check(options) }
        if performance { return .performance }
        if smoke { return .smoke }
        let error: AppArguments.ParseError?
        if case .failure(let value) = parsed { error = value } else { error = nil }
        return .application(options, parseError: error)
    }
}
