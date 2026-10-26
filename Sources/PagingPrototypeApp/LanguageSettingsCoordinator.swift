import LauncherLocalization

/// Scalar persistence acknowledgement and presentation requests are separate.
/// A saved result is not a claim that UserDefaults has flushed to disk.
@MainActor
public final class LanguageSettingsCoordinator {
    public private(set) var committed: LanguagePreferences
    public private(set) var loadResult: LanguagePreferencesLoadResult
    private var isActive = true
    private let store: any LanguagePreferencesPersisting
    private let requestPresentation: (InterfaceLanguagePreference) -> Void

    public init(store: any LanguagePreferencesPersisting,
                requestPresentation: @escaping (InterfaceLanguagePreference) -> Void) {
        self.store = store
        self.requestPresentation = requestPresentation
        loadResult = store.load()
        committed = loadResult.preferences
    }

    @discardableResult
    public func apply(_ draft: LanguagePreferences) -> LanguagePreferencesSaveResult {
        guard isActive else { return .unavailable }
        let fresh = store.load()
        let result: LanguagePreferencesSaveResult
        switch fresh {
        case .futureVersion(let version): result = .futureVersion(version)
        case .futureVersionUnrepresentable: result = .futureVersionUnrepresentable
        case .oversized: result = .oversized
        case .unavailable: result = .unavailable
        case .loaded(let preferences) where preferences == draft: result = .saved
        default: result = store.save(draft)
        }
        guard result == .saved else {
            loadResult = fresh
            return result
        }
        committed = draft
        loadResult = .loaded(draft)
        // Equal Follow System preferences can resolve to a changed effective
        // language. The presentation owner, not preference equality, decides.
        requestPresentation(draft.language)
        return .saved
    }

    /// Refreshes accepted language only; never accepts or rewrites a view draft.
    public func refreshAcceptedPresentation() {
        guard isActive else { return }
        requestPresentation(committed.language)
    }

    /// Retain accepted preferences, but refuse new work from an obsolete UI binding.
    public func invalidate() { isActive = false }
}
