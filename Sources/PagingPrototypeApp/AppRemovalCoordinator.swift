import AppGridUI
import Foundation

/// One explicit, confirmed operation. No history, scanning, or frame callback work.
@MainActor
final class AppRemovalCoordinator {
    enum Phase: Equatable { case idle, inspecting, confirming, moving }
    enum Outcome: Equatable { case cancelled, moved, unavailable, running, changed, failed }
    typealias Confirmation = (AppRemovalCandidate, @escaping (Bool) -> Void) -> Void

    private(set) var phase: Phase = .idle
    private(set) var lastOutcome: Outcome?
    var onChange: (() -> Void)?
    var onComplete: ((Outcome) -> Void)?
    var isBusy: Bool { phase != .idle }
    var requiresQuitProtection: Bool { isBusy || hasUnacknowledgedFailure }

    private let files: any AppRemovalFileAccess
    private let allowedTestRoot: URL?
    private let selfBundleURL: URL
    private let isRunning: (URL) async -> Bool
    private var task: Task<Void, Never>?
    private var token: UUID?
    private var intentIsValid = false
    private var isActive = true
    private var hasUnacknowledgedFailure = false

    init(files: any AppRemovalFileAccess, allowedTestRoot: URL?, selfBundleURL: URL,
         isRunning: @escaping (URL) async -> Bool) {
        self.files = files
        self.allowedTestRoot = allowedTestRoot
        self.selfBundleURL = selfBundleURL
        self.isRunning = isRunning
    }

    @discardableResult
    func request(url: URL, validate: @escaping () -> Bool, confirm: @escaping Confirmation) -> Bool {
        guard isActive, !isBusy, !hasUnacknowledgedFailure, validate() else { return false }
        let id = UUID()
        token = id
        intentIsValid = true
        hasUnacknowledgedFailure = false
        lastOutcome = nil
        setPhase(.inspecting)
        task = Task { [weak self] in
            guard let self else { return }
            let inspection = await self.files.inspect(url: url, allowedTestRoot: self.allowedTestRoot,
                                                       selfBundleURL: self.selfBundleURL)
            guard self.isCurrent(id, validate: validate) else { self.task = nil; self.finish(.cancelled); return }
            guard case .eligible(let candidate) = inspection else { self.task = nil; self.finish(.unavailable); return }
            let running = await self.isRunning(candidate.url)
            self.task = nil
            guard self.isCurrent(id, validate: validate) else { self.finish(.cancelled); return }
            guard !running else { self.finish(.running); return }
            self.setPhase(.confirming)
            confirm(candidate) { [weak self] accepted in
                guard let self, self.token == id, self.phase == .confirming else { return }
                guard accepted, self.isCurrent(id, validate: validate) else { self.finish(.cancelled); return }
                self.perform(candidate, id: id, validate: validate)
            }
        }
        return true
    }

    private func perform(_ candidate: AppRemovalCandidate, id: UUID, validate: @escaping () -> Bool) {
        setPhase(.inspecting)
        task = Task { [weak self] in
            guard let self else { return }
            let fresh = await self.files.inspect(url: candidate.url, allowedTestRoot: self.allowedTestRoot,
                                                 selfBundleURL: self.selfBundleURL)
            guard self.isCurrent(id, validate: validate) else { self.task = nil; self.finish(.cancelled); return }
            guard case .eligible(let current) = fresh, current == candidate else {
                self.task = nil; self.finish(.changed); return
            }
            let running = await self.isRunning(current.url)
            guard self.isCurrent(id, validate: validate) else { self.task = nil; self.finish(.cancelled); return }
            guard !running else { self.task = nil; self.finish(.running); return }
            self.setPhase(.moving)
            // Once admitted to the platform, an operation cannot be cancelled by
            // hiding a window. Its actual receipt still protects orderly Quit.
            let result = await self.files.moveToTrash(current, allowedTestRoot: self.allowedTestRoot,
                                                     selfBundleURL: self.selfBundleURL)
            self.task = nil
            switch result {
            case .moved: self.finish(.moved)
            case .rejected: self.finish(.changed)
            case .failed: self.finish(.failed)
            }
        }
    }

    private func isCurrent(_ id: UUID, validate: () -> Bool) -> Bool {
        isActive && token == id && intentIsValid && validate()
    }

    /// Revoke only unaccepted intent. Retain an in-flight inspection until it
    /// returns, avoiding replacement work accumulating behind cancelled handles.
    func cancelUnaccepted() {
        guard phase != .moving else { return }
        intentIsValid = false
        if phase == .confirming { finish(.cancelled) }
    }

    func acknowledgeResult() {
        guard !isBusy else { return }
        hasUnacknowledgedFailure = false
    }

    func drain(timeout: Duration) async -> LayoutStoreFlushResult {
        cancelUnaccepted()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: max(.zero, timeout))
        while isBusy {
            guard clock.now < deadline else { return .timedOut }
            do { try await Task.sleep(for: .milliseconds(10)) }
            catch { return .timedOut }
        }
        return hasUnacknowledgedFailure ? .failed : .nothingPending
    }

    func teardown() {
        isActive = false
        cancelUnaccepted()
        onChange = nil
        onComplete = nil
    }

    private func finish(_ outcome: Outcome) {
        token = nil
        intentIsValid = false
        lastOutcome = outcome
        hasUnacknowledgedFailure = outcome == .failed
        phase = .idle
        if isActive { onChange?(); onComplete?(outcome) }
    }

    private func setPhase(_ phase: Phase) {
        self.phase = phase
        if isActive { onChange?() }
    }
}
