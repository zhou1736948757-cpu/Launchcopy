import Foundation
import LauncherLocalization

public enum LanguagePresentationState: Equatable, Sendable {
    case applied, queued, unavailable
}

/// Instances, rather than Boolean owner flags, permit overlapping sheets/menus.
public enum LanguageInteractionOwner: Hashable, Sendable {
    case pointer, paging, folderTransition, titleEditor, shortcutRecording
    case markedText, menuTracking, modal, restore, quit
}

public struct LanguageInteractionToken: Hashable, Sendable {
    fileprivate let id: UUID
}

/// One latest language snapshot, presented outside event/frame callback stacks.
/// Production assembly must supply actual readiness and owner-release events.
@MainActor
public final class LanguagePresentationController {
    public typealias Scheduler = (@escaping @MainActor () -> Void) -> Void
    public private(set) var acceptedPreference: InterfaceLanguagePreference
    public private(set) var displayedLanguage: InterfaceLanguage
    public private(set) var pendingLanguage: InterfaceLanguage?
    public var onPresent: ((InterfaceLanguage) -> Void)?
    public var onStateChange: ((LanguagePresentationState) -> Void)?
    private let preferredLanguages: () -> [String]
    private let isReady: () -> Bool
    private let schedule: Scheduler
    private var owners: [LanguageInteractionToken: LanguageInteractionOwner] = [:]
    private var retryScheduled = false
    private var isPresenting = false
    private var generation: UInt64 = 0
    private var isTornDown = false
    private var notifiedState = LanguagePresentationState.applied

    public init(preference: InterfaceLanguagePreference,
                preferredLanguages: @escaping () -> [String],
                isReady: @escaping () -> Bool,
                schedule: @escaping Scheduler = { callback in
                    DispatchQueue.main.async { callback() }
                }) {
        self.acceptedPreference = preference
        self.preferredLanguages = preferredLanguages
        self.isReady = isReady
        self.schedule = schedule
        displayedLanguage = preference.resolve(preferredLanguages: preferredLanguages())
    }

    /// Read-only shared presentation ownership; never releases another owner's lease.
    var hasInteractionOwners: Bool { !owners.isEmpty }

    public var state: LanguagePresentationState {
        if isTornDown { return .unavailable }
        return pendingLanguage == nil ? .applied : .queued
    }

    public func request(_ preference: InterfaceLanguagePreference) {
        guard !isTornDown else { return }
        acceptedPreference = preference
        let desired = preference.resolve(preferredLanguages: preferredLanguages())
        pendingLanguage = desired == displayedLanguage ? nil : desired
        notifyStateIfChanged()
        scheduleIfNeeded()
    }

    public func refreshAcceptedResolution() { request(acceptedPreference) }

    @discardableResult
    public func acquire(_ owner: LanguageInteractionOwner) -> LanguageInteractionToken {
        let token = LanguageInteractionToken(id: UUID())
        guard !isTornDown else { return token }
        owners[token] = owner
        return token
    }

    public func release(_ token: LanguageInteractionToken) {
        guard !isTornDown, owners.removeValue(forKey: token) != nil else { return }
        scheduleIfNeeded()
    }

    /// Call on actual external readiness changes, not from a polling timer.
    public func readinessDidChange() { scheduleIfNeeded() }

    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        generation &+= 1
        pendingLanguage = nil
        owners.removeAll()
        retryScheduled = false
        notifyStateIfChanged()
        onPresent = nil
        onStateChange = nil
    }

    private func scheduleIfNeeded() {
        guard !isTornDown, pendingLanguage != nil, !retryScheduled, !isPresenting,
              owners.isEmpty, isReady() else { return }
        retryScheduled = true
        let epoch = generation
        schedule { [weak self] in
            guard let self, !self.isTornDown, self.generation == epoch else { return }
            self.retryScheduled = false
            self.presentPendingIfReady()
        }
    }

    private func presentPendingIfReady() {
        guard !isTornDown, !isPresenting, owners.isEmpty, isReady(),
              let language = pendingLanguage else { return }
        pendingLanguage = nil
        displayedLanguage = language
        isPresenting = true
        onPresent?(language)
        isPresenting = false
        notifyStateIfChanged()
        scheduleIfNeeded()
    }

    private func notifyStateIfChanged() {
        let current = state
        guard current != notifiedState else { return }
        notifiedState = current
        onStateChange?(current)
    }
}
