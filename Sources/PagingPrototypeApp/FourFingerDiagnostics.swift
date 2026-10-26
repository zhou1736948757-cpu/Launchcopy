import Foundation

/// Explicit lab-only observation. Never owns a provider or changes activation/UI state.
@MainActor
final class FourFingerDiagnostics {
    typealias Tick = @MainActor @Sendable () -> Void
    typealias TimerFactory = @MainActor (@escaping Tick) -> Timer

    private let enabled: Bool
    private let sink: (String) -> Void
    private let makeTimer: TimerFactory
    private weak var owner: ActivationComposition?
    private var generation: UInt64 = 0
    private(set) var timer: Timer?

    init(enabled: Bool, sink: @escaping (String) -> Void = {
        print($0)
        fflush(stdout)
    }, makeTimer: @escaping TimerFactory = { tick in
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
    }) {
        self.enabled = enabled
        self.sink = sink
        self.makeTimer = makeTimer
    }

    func start(for composition: ActivationComposition) {
        stop()
        guard enabled else { return }
        owner = composition
        let ticket = generation
        composition.onFourFingerDiagnostic = { [weak self, weak composition] message in
            guard let self, let composition, self.owner === composition,
                  self.generation == ticket else { return }
            self.sink(message)
        }
        timer = makeTimer { [weak self] in self?.sample(ticket: ticket) }
    }

    func stop() {
        generation &+= 1
        timer?.invalidate()
        timer = nil
        owner?.onFourFingerDiagnostic = nil
        owner = nil
    }

    private func sample(ticket: UInt64) {
        guard generation == ticket else { return }
        guard let owner, let backend = owner.touchProvider as? MultitouchSupportBackend else {
            stop()
            return
        }
        sink("paging-fourfinger-tick: raw=\(backend.rawCallbackCount) delivered=\(backend.deliveredFrameCount) rejected=\(backend.rejectedFrameCount) state=\(backend.state) started=\(backend.isStarted) detail=\(backend.lastStartDetail)")
        if !backend.isStarted { stop() }
    }

    deinit { timer?.invalidate() }
}
