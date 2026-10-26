import Foundation

/// Live intent and synchronous preference acknowledgments have independent ownership.
/// A single cancellable debounce retains only the newest requested value.
@MainActor
final class LiveAppearanceSettingsCoordinator {
    typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> (() -> Void)
    let persistence: AppearanceSettingsCoordinator
    private(set) var requested: AppearancePreferences
    private(set) var state: LiveSettingsSaveState = .idle
    private(set) var needsSave = false
    private(set) var isFlushing = false
    var onPreview: ((AppearancePreferences) -> Void)?
    var onChange: (() -> Void)?
    var requiresQuitProtection: Bool { needsSave }
    private let schedule: Scheduler
    private var cancelScheduled: (() -> Void)?
    private var generation: UInt64 = 0
    private var isActive = true
    private var admittedRecovery = false

    init(persistence: AppearanceSettingsCoordinator, schedule: Scheduler? = nil) {
        self.persistence = persistence
        self.requested = persistence.committed
        self.schedule = schedule ?? { Self.debounced($0) }
        switch persistence.loadResult {
        case .futureVersion: state = .protected
        case .corrupt: state = .recoveryRequired
        case .loaded: break
        }
    }

    /// Timer uses common modes so live native slider tracking does not starve saving.
    static func debounced(_ callback: @escaping @MainActor () -> Void) -> (() -> Void) {
        let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
            MainActor.assumeIsolated { callback() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }

    @discardableResult
    func submit(_ value: AppearancePreferences, recovering: Bool = false) -> Bool {
        guard isActive, value.isValid else { return false }
        switch persistence.inspectLoadResult() {
        case .futureVersion: state = .protected; onChange?(); return false
        case .corrupt where !recovering: state = .recoveryRequired; onChange?(); return false
        default: break
        }
        if value == requested, needsSave, state == .pending { return true }
        if value == requested, !needsSave, value == persistence.committed,
           case .loaded(let current) = persistence.inspectLoadResult(), current == value {
            onChange?() // Clear a view's optimistic Saving state without a redundant write.
            return true
        }
        generation &+= 1
        let epoch = generation
        requested = value
        admittedRecovery = recovering
        needsSave = true
        state = .pending
        cancelScheduled?(); cancelScheduled = nil
        // Publish before calling arbitrary owner code, which can invalidate or submit again.
        onChange?()
        guard isActive, generation == epoch else { return true }
        onPreview?(value)
        guard isActive, generation == epoch else { return true }
        let cancel = schedule { [weak self] in
            guard let self, self.isActive, self.generation == epoch else { return }
            self.flush()
        }
        if isActive, generation == epoch, needsSave { cancelScheduled = cancel }
        else { cancel() }
        return true
    }

    /// Flush admitted work even during Quit; presentation readiness is a different owner.
    @discardableResult
    func flush() -> AppearancePreferencesSaveResult {
        // A nested flush has no receipt for the newer intention. In particular,
        // do not cancel its already-armed debounce while the previous save is active.
        guard !isFlushing else { return .encodingFailed }
        cancelScheduled?(); cancelScheduled = nil
        guard needsSave else { return .saved }
        let value = requested, epoch = generation
        if case .corrupt = persistence.inspectLoadResult(), !admittedRecovery {
            state = .recoveryRequired
            onChange?()
            return .encodingFailed
        }
        isFlushing = true
        let result = persistence.apply(value)
        isFlushing = false
        guard isActive, generation == epoch else { return result }
        switch result {
        case .saved: needsSave = false; admittedRecovery = false; state = .saved
        case .futureVersion: state = .protected
        case .invalidPreferences, .encodingFailed: state = .failed
        }
        onChange?()
        return result
    }

    func retry(_ value: AppearancePreferences) -> AppearancePreferencesSaveResult {
        guard submit(value, recovering: true) else {
            if case .futureVersion(let version) = persistence.inspectLoadResult() { return .futureVersion(version) }
            return .encodingFailed
        }
        return flush()
    }

    /// A successful current explicit command is newer than any pending live edit.
    /// Live-owned flush callbacks are suppressed by the composition root.
    func acceptPersistenceCommand(_ value: AppearancePreferences) {
        guard isActive, !isFlushing, value.isValid else { return }
        generation &+= 1
        let epoch = generation
        cancelScheduled?(); cancelScheduled = nil
        requested = value
        needsSave = false
        admittedRecovery = false
        state = .saved
        onChange?()
        guard isActive, generation == epoch else { return }
        onPreview?(value)
    }

    func invalidate() {
        // Pending preferences use a synchronous existing store API: flush, never discard.
        _ = flush()
        isActive = false
        generation &+= 1
        cancelScheduled?(); cancelScheduled = nil
        onPreview = nil; onChange = nil
    }
}
