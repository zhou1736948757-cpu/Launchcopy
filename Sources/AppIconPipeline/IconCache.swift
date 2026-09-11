// AppIconPipeline — 有界内存缓存（wave1-interfaces.md §D）
// 内存 cache only：count/cost 双上界 + LRU 驱逐；无磁盘持久化。
// 线程安全由持有方（IconPipeline 的锁）保证，本类不做内部加锁。

import AppKit
import Foundation

/// 缓存与并发限制。
public struct IconCacheLimits: Sendable, Equatable {
    /// 条目数上界。
    public var maxCount: Int
    /// 估计成本上界（近似解码成本 w×h×4 字节；~64MB 默认）。
    public var maxCost: Int
    /// 底层 loader 最大并发数。
    public var maxConcurrentLoads: Int

    public init(maxCount: Int = 256, maxCost: Int = 64 << 20, maxConcurrentLoads: Int = 4) {
        self.maxCount = maxCount
        self.maxCost = maxCost
        self.maxConcurrentLoads = maxConcurrentLoads
    }
}

/// 内存缓存条目。
final class IconCacheEntry {
    let image: NSImage
    let cost: Int                       // 估计成本 w×h×4（无真实字节/哈希）
    let insertedAt: Date
    var lastAccess: Date
    let sequence: UInt64                // 插入序（驱逐 tie-break，确定性）

    init(image: NSImage, cost: Int, insertedAt: Date, lastAccess: Date, sequence: UInt64) {
        self.image = image
        self.cost = cost
        self.insertedAt = insertedAt
        self.lastAccess = lastAccess
        self.sequence = sequence
    }
}

/// 有界 LRU 内存缓存（无锁；由 IconPipeline 串行持有）。
final class IconCache {
    private(set) var entries: [IconKey: IconCacheEntry] = [:]
    private(set) var totalCost: Int = 0
    private var nextSequence: UInt64 = 0
    let limits: IconCacheLimits

    init(limits: IconCacheLimits) {
        self.limits = limits
    }

    var count: Int { entries.count }

    /// 命中并刷新 lastAccess；未命中返回 nil。
    func value(for key: IconKey, now: Date = Date()) -> IconCacheEntry? {
        guard let entry = entries[key] else { return nil }
        entry.lastAccess = now
        return entry
    }

    /// 插入（同 key 旧条目先移除）；返回由此触发的驱逐数。
    /// 单条目 cost 超过 maxCost 时不入缓存（pass-through）。
    @discardableResult
    func insert(_ image: NSImage, cost: Int, for key: IconKey, now: Date = Date()) -> Int {
        guard cost <= limits.maxCost else { return 0 }
        if let old = entries.removeValue(forKey: key) {
            totalCost -= old.cost
        }
        let entry = IconCacheEntry(image: image, cost: cost, insertedAt: now,
                                   lastAccess: now, sequence: nextSequence)
        nextSequence += 1
        entries[key] = entry
        totalCost += cost
        var evicted = 0
        while entries.count > limits.maxCount || totalCost > limits.maxCost {
            guard let lruKey = leastRecentlyUsedKey else { break }
            remove(lruKey)
            evicted += 1
        }
        return evicted
    }

    @discardableResult
    func remove(_ key: IconKey) -> Bool {
        guard let entry = entries.removeValue(forKey: key) else { return false }
        totalCost -= entry.cost
        return true
    }

    /// 移除全部；返回移除数。
    @discardableResult
    func removeAll() -> Int {
        let removed = entries.count
        entries.removeAll()
        totalCost = 0
        return removed
    }

    /// 移除插入时间早于 before 的条目；返回移除数。
    @discardableResult
    func removeExpired(before date: Date) -> Int {
        let doomed = entries.filter { $0.value.insertedAt < date }.map(\.key)
        for key in doomed {
            remove(key)
        }
        return doomed.count
    }

    /// LRU 键：lastAccess 最旧（同刻按插入序更早）。
    private var leastRecentlyUsedKey: IconKey? {
        entries.min { lhs, rhs in
            if lhs.value.lastAccess != rhs.value.lastAccess {
                return lhs.value.lastAccess < rhs.value.lastAccess
            }
            return lhs.value.sequence < rhs.value.sequence
        }?.key
    }
}
