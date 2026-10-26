import AppGridUI
import Foundation

/// A cancellable, exactly-once termination decision. It never owns disk I/O or
/// terminates the process; AppKit and the persistence queue remain separate seams.
@MainActor
final class WorkspaceQuitCoordinator {
    enum Phase: Equatable { case idle, draining, awaitingDecision, approved }
    private(set) var phase: Phase = .idle
    var onPhaseChange: (() -> Void)?
    private var generation: UInt64 = 0
    private var task: Task<Void, Never>?
    private var pendingReply: ((Bool) -> Void)?
    var isPending: Bool { phase == .draining || phase == .awaitingDecision }

    func request(drain: @escaping () async -> LayoutStoreFlushResult,
                 chooseOnFailure: @escaping (LayoutStoreFlushResult, @escaping (Bool) -> Void) -> Void,
                 reply: @escaping (Bool) -> Void) {
        guard phase == .idle else { return }
        generation &+= 1
        let token = generation
        pendingReply = reply
        setPhase(.draining)
        task = Task { [weak self] in
            let result = await drain()
            guard let self, self.generation == token, self.phase == .draining,
                  !Task.isCancelled else { return }
            self.task = nil
            switch result {
            case .persisted, .nothingPending: self.finish(approve: true)
            case .failed, .timedOut, .readOnly, .staleRejected, .rejectedOverLimit:
                self.setPhase(.awaitingDecision)
                chooseOnFailure(result) { [weak self] approve in
                    guard let self, self.generation == token, self.phase == .awaitingDecision else { return }
                    self.finish(approve: approve)
                }
            }
        }
    }

    /// Store replacement invalidates the old reply; teardown does not create a
    /// new termination request. Late dialog or drain completions are harmless.
    func cancelPending(replyCancellation: Bool = true) {
        guard isPending else { return }
        generation &+= 1
        task?.cancel(); task = nil
        let reply = pendingReply; pendingReply = nil
        setPhase(.idle)
        if replyCancellation { reply?(false) }
    }

    private func finish(approve: Bool) {
        let reply = pendingReply; pendingReply = nil
        setPhase(approve ? .approved : .idle)
        reply?(approve)
    }

    private func setPhase(_ value: Phase) {
        phase = value
        onPhaseChange?()
    }
}
