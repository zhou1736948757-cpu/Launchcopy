import Foundation

/// Fail-closed persistence with no filesystem adapter, lock, task or write queue.
public struct UnavailableLayoutStore: LayoutStore {
    // Protocol compatibility token, deliberately a non-directory. Never opened.
    public let storeDirectory = URL(fileURLWithPath: "/dev/null", isDirectory: false)
    public init() {}
    public func load() async -> LayoutStoreLoadResult { .readOnlyProtection(.storageUnavailable) }
    public func enqueue(_ layout: PersistentWorkspaceLayout) async {}
    public func flush() async -> LayoutStoreFlushResult { .readOnly }
    public func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult { .failed }
    public func currentState() async -> LayoutStoreState { .readOnlyProtection(.storageUnavailable) }
    public func lockMode() async -> LayoutStoreLockMode { .unavailable }
    public func staleRejectionCount() async -> UInt64 { 0 }
}
