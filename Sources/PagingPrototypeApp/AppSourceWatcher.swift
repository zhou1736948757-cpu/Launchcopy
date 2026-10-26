import CoreServices
import Dispatch
import Foundation

@MainActor
public protocol AppSourceWatching: AnyObject {
    func replaceRoots(
        _ roots: [URL],
        onChange: @escaping @MainActor () -> Void
    ) async -> AppSourceWatchStatus
    func stop()
}

public enum AppSourceWatchStatus: Equatable, Sendable {
    case active
    case disabled
    case unavailable
    case degraded
}

/// Watches only already-admitted roots. Admission and catalog scanning belong to the consumer.
/// A change is a neutral invalidation: the consumer should call its existing scheduleRescan.
@MainActor
public final class FSEventsAppSourceWatcher: AppSourceWatching {
    private let backend: AppSourceWatchStreamBackend
    private let utility: AppSourceWatchUtilityScheduling
    private let deliveryGate: AppSourceWatchDeliveryGate
    private let rootIsUsable: @Sendable (URL) -> Bool
    private var session: AppSourceWatchSession?
    private var generation: UInt64 = 0
    private var onChange: (@MainActor () -> Void)?
    // Main may consume the mailbox before the asynchronous setup continuation installs
    // its session. Retain one neutral invalidation across that readiness transition.
    private var pendingStartupChange = false

    public convenience init() {
        self.init(
            backend: NativeAppSourceWatchBackend(),
            enqueueMain: { delivery in enqueueAppSourceWatchMainDelivery(delivery) },
            rootIsUsable: { root in appSourceWatchRootIsUsable(root) }
        )
    }

    /// Test-only composition seam: no production stream or filesystem probe is required.
    init(
        backend: AppSourceWatchStreamBackend,
        enqueueMain: @escaping AppSourceWatchEnqueueMain,
        rootIsUsable: @escaping @Sendable (URL) -> Bool,
        utility: AppSourceWatchUtilityScheduling = AppSourceWatchUtilityExecutor()
    ) {
        self.backend = backend
        self.deliveryGate = AppSourceWatchDeliveryGate(enqueueMain: enqueueMain)
        self.rootIsUsable = rootIsUsable
        self.utility = utility
    }

    /// Status describes startup coverage, not an inventory of filesystem changes.
    /// Missing/unreadable roots are attempted at their exact admitted paths but are degraded:
    /// their reappearance is not guaranteed. Manual refresh can retry replaceRoots.
    public func replaceRoots(
        _ roots: [URL],
        onChange: @escaping @MainActor () -> Void
    ) async -> AppSourceWatchStatus {
        stop()
        guard !roots.isEmpty else { return .disabled }
        guard roots.allSatisfy({ $0.isFileURL }) else { return .unavailable }

        let currentGeneration = generation
        self.onChange = onChange
        deliveryGate.activate(currentGeneration)
        let gate = deliveryGate
        let deliver: @MainActor @Sendable (UInt64) -> Void = { [weak self] generation in
            self?.deliverChange(for: generation)
        }
        let backend = self.backend
        let utility = self.utility
        let rootIsUsable = self.rootIsUsable
        let configuration = AppSourceWatchStreamConfiguration(roots: roots)

        // Metadata and native setup run on utility. Main suspends instead of waiting on IO.
        let setup: (AppSourceWatchSession?, AppSourceWatchStatus) = await utility.perform {
            let coverageGuaranteed = roots.allSatisfy(rootIsUsable)
            guard let stream = backend.makeStream(configuration: configuration, onChange: {
                gate.signal(currentGeneration, deliver: deliver)
            }) else {
                return (nil, .unavailable)
            }
            stream.schedule(on: utility.queue)
            let started = stream.start()
            let session = AppSourceWatchSession(stream: stream, started: started, utility: utility)
            guard started else {
                session.close()
                return (nil, .unavailable)
            }
            return (session, coverageGuaranteed ? .active : .degraded)
        }
        // Another replace/stop may have run while setup was suspended. Never clear its gate
        // or install the old stream, even when the old setup failed or its Task was cancelled.
        guard generation == currentGeneration else {
            setup.0?.close()
            return .disabled
        }
        guard !Task.isCancelled else {
            stop()
            setup.0?.close()
            return .disabled
        }
        guard let session = setup.0 else {
            deliveryGate.invalidate()
            self.onChange = nil
            pendingStartupChange = false
            return setup.1
        }
        self.session = session
        if pendingStartupChange {
            pendingStartupChange = false
            onChange()
        }
        return setup.1
    }

    /// Invalidates callbacks immediately; native cleanup is queued without blocking Main.
    public func stop() {
        generation &+= 1
        deliveryGate.invalidate()
        onChange = nil
        pendingStartupChange = false
        let oldSession = session
        session = nil
        oldSession?.close()
    }

    private func deliverChange(for generation: UInt64) {
        guard generation == self.generation, onChange != nil else { return }
        guard session != nil else {
            pendingStartupChange = true
            return
        }
        onChange?()
    }

    deinit {
        // These helpers are non-actor-isolated and synchronize their own state. Neither a
        // native context nor a queued delivery retains the watcher, so deinit is reachable.
        deliveryGate.invalidate()
        session?.close()
    }
}

// MARK: - Injected stream and delivery seams

struct AppSourceWatchStreamConfiguration: Equatable, Sendable {
    let roots: [URL]
    let sinceWhen = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    let latency: CFTimeInterval = 0.5
    // FSEvents is recursive by default. WatchRoot adds disappearance/rename invalidations.
    // Deliberately omit FileEvents, NoDefer, IgnoreSelf and extended event data.
    let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)
}

/// Methods execute exclusively on the watcher's serial utility executor.
protocol AppSourceWatchStreamBackend: Sendable {
    func makeStream(
        configuration: AppSourceWatchStreamConfiguration,
        onChange: @escaping @Sendable () -> Void
    ) -> AppSourceWatchStream?
}

/// A created stream is scheduled before start, then invalidated while scheduled and released.
/// Stop is valid only after successful start. The session enforces this lifecycle.
protocol AppSourceWatchStream: AnyObject, Sendable {
    func schedule(on queue: DispatchQueue)
    func start() -> Bool
    func stop()
    func invalidate()
    func release()
}

typealias AppSourceWatchMainDelivery = @MainActor @Sendable () -> Void
typealias AppSourceWatchEnqueueMain = @Sendable (@escaping AppSourceWatchMainDelivery) -> Void

private func enqueueAppSourceWatchMainDelivery(_ delivery: @escaping AppSourceWatchMainDelivery) {
    Task { @MainActor in delivery() }
}

/// One mailbox for the entire watcher, including replacements. Lock-protected mutable state
/// justifies unchecked Sendable; no lock is held while scheduling or invoking user code.
private final class AppSourceWatchDeliveryGate: @unchecked Sendable {
    private let lock = NSLock()
    private let enqueueMain: AppSourceWatchEnqueueMain
    private var generation: UInt64?
    private var dirtyGeneration: UInt64?
    private var deliveryPending = false

    init(enqueueMain: @escaping AppSourceWatchEnqueueMain) {
        self.enqueueMain = enqueueMain
    }

    func activate(_ generation: UInt64) {
        lock.lock()
        self.generation = generation
        dirtyGeneration = nil
        // Keep any scheduled slot: new-generation events may reuse it instead of adding tasks.
        lock.unlock()
    }

    func invalidate() {
        lock.lock()
        generation = nil
        dirtyGeneration = nil
        lock.unlock()
    }

    func signal(_ generation: UInt64, deliver: @escaping @MainActor @Sendable (UInt64) -> Void) {
        lock.lock()
        guard self.generation == generation else {
            lock.unlock()
            return
        }
        dirtyGeneration = generation
        guard !deliveryPending else {
            lock.unlock()
            return
        }
        deliveryPending = true
        lock.unlock()

        enqueueMain { [self] in
            if let generation = takePendingGeneration() {
                deliver(generation)
            }
        }
    }

    private func takePendingGeneration() -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        deliveryPending = false
        let pending = dirtyGeneration
        dirtyGeneration = nil
        return pending == generation ? pending : nil
    }
}

/// Injection allows tests to hold setup/cleanup jobs at precise lifecycle boundaries.
protocol AppSourceWatchUtilityScheduling: AnyObject, Sendable {
    var queue: DispatchQueue { get }
    func enqueue(_ operation: @escaping @Sendable () -> Void)
}

extension AppSourceWatchUtilityScheduling {
    func perform<Value: Sendable>(_ operation: @escaping @Sendable () -> Value) async -> Value {
        await withCheckedContinuation { continuation in
            enqueue {
                continuation.resume(returning: operation())
            }
        }
    }
}

/// One utility serial queue orders native setup, callbacks, and eventual cleanup. Enqueue
/// always returns immediately, including when called by a session's deinit or failed setup.
final class AppSourceWatchUtilityExecutor: AppSourceWatchUtilityScheduling, Sendable {
    let queue = DispatchQueue(label: "PagingPrototype.AppSources.FSEvents", qos: .utility)

    func enqueue(_ operation: @escaping @Sendable () -> Void) {
        queue.async(execute: operation)
    }
}

/// Detach the handle under a lock before cleanup; repeated stop/deinit cannot double release.
private final class AppSourceWatchSession: @unchecked Sendable {
    private let lock = NSLock()
    private var stream: AppSourceWatchStream?
    private let started: Bool
    private let utility: AppSourceWatchUtilityScheduling

    init(stream: AppSourceWatchStream, started: Bool, utility: AppSourceWatchUtilityScheduling) {
        self.stream = stream
        self.started = started
        self.utility = utility
    }

    func close() {
        lock.lock()
        let stream = self.stream
        self.stream = nil
        lock.unlock()
        guard let stream else { return }
        let started = self.started
        utility.enqueue {
            if started { stream.stop() }
            // Apple requires invalidation while the dispatch queue is still attached.
            stream.invalidate()
            stream.release()
        }
    }

    deinit { close() }
}

// MARK: - Public FSEvents adapter

private func appSourceWatchRootIsUsable(_ root: URL) -> Bool {
    guard let values = try? root.resourceValues(forKeys: [.isDirectoryKey]),
          values.isDirectory == true else { return false }
    return FileManager.default.isReadableFile(atPath: root.path)
}

private struct NativeAppSourceWatchBackend: AppSourceWatchStreamBackend {
    func makeStream(
        configuration: AppSourceWatchStreamConfiguration,
        onChange: @escaping @Sendable () -> Void
    ) -> AppSourceWatchStream? {
        // Own a temporary retain throughout creation. The CF retain/release callbacks give
        // the stream its own independent retain, including in-flight callback lifetime.
        let owner = Unmanaged.passRetained(AppSourceWatchCallbackContext(onChange: onChange))
        defer { owner.release() }
        var context = FSEventStreamContext(
            version: 0,
            info: owner.toOpaque(),
            retain: { info in
                guard let info else { return nil }
                return UnsafeRawPointer(Unmanaged<AppSourceWatchCallbackContext>.fromOpaque(info).retain().toOpaque())
            },
            release: { info in
                guard let info else { return }
                Unmanaged<AppSourceWatchCallbackContext>.fromOpaque(info).release()
            },
            copyDescription: nil
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, count, _, _, _ in
                guard count > 0, let info else { return }
                // Paths, flags and IDs are neither inspected, copied, forwarded nor logged.
                let context = Unmanaged<AppSourceWatchCallbackContext>.fromOpaque(info).takeUnretainedValue()
                context.onChange()
            },
            &context,
            configuration.roots.map(\.path) as CFArray,
            configuration.sinceWhen,
            configuration.latency,
            configuration.flags
        ) else { return nil }
        return NativeAppSourceWatchStream(stream: stream)
    }
}

private final class AppSourceWatchCallbackContext: Sendable {
    let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }
}

/// The session serializes every operation on utility; the C reference never escapes it.
private final class NativeAppSourceWatchStream: AppSourceWatchStream, @unchecked Sendable {
    private let stream: FSEventStreamRef

    init(stream: FSEventStreamRef) { self.stream = stream }
    func schedule(on queue: DispatchQueue) { FSEventStreamSetDispatchQueue(stream, queue) }
    func start() -> Bool { FSEventStreamStart(stream) }
    func stop() { FSEventStreamStop(stream) }
    func invalidate() { FSEventStreamInvalidate(stream) }
    func release() { FSEventStreamRelease(stream) }
}
