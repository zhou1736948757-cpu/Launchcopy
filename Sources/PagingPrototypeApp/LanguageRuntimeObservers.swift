import AppKit

/// Process-local AppKit notifications only. No global input or text is recorded.
@MainActor
final class LanguageRuntimeObservers {
    private let center: NotificationCenter
    private weak var owner: LanguagePresentationController?
    private let retry: () -> Void
    private var observations: [NSObjectProtocol] = []
    private var isTornDown = false
    private var menuLeases: [ObjectIdentifier: [LanguageInteractionToken]] = [:]

    init(center: NotificationCenter, owner: LanguagePresentationController,
         retry: @escaping () -> Void) {
        self.center = center
        self.owner = owner
        self.retry = retry
        observe(NSMenu.didBeginTrackingNotification) { [weak self] note in
            guard let self, let menu = note.object as? NSMenu, let owner = self.owner else { return }
            self.menuLeases[ObjectIdentifier(menu), default: []].append(owner.acquire(.menuTracking))
        }
        observe(NSMenu.didEndTrackingNotification) { [weak self] note in
            guard let self, let menu = note.object as? NSMenu else { return }
            let identity = ObjectIdentifier(menu)
            if let token = self.menuLeases[identity]?.popLast() { self.owner?.release(token) }
            if self.menuLeases[identity]?.isEmpty == true { self.menuLeases.removeValue(forKey: identity) }
            self.retry()
        }
        for name in [NSWindow.didEndSheetNotification, NSWindow.didResignKeyNotification,
                     NSWindow.didBecomeKeyNotification, NSControl.textDidEndEditingNotification,
                     NSControl.textDidChangeNotification, NSText.didChangeNotification,
                     NSText.didEndEditingNotification] {
            observe(name) { [weak self] _ in self?.retry() }
        }
    }

    func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        for observation in observations { center.removeObserver(observation) }
        observations.removeAll()
        for tokens in menuLeases.values { for token in tokens { owner?.release(token) } }
        menuLeases.removeAll()
        owner = nil
    }

    private func observe(_ name: Notification.Name, handler: @escaping @MainActor (Notification) -> Void) {
        observations.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, !self.isTornDown else { return }
                handler(note)
            }
        })
    }
}
