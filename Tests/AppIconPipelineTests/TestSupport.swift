// AppIconPipelineTests — TestSupport（§10.4：程序生成图像 + fake loader）
// 绝不触碰真实 /Applications 图标、绝不读取真实 app；无第三方图标写入 test artifacts。

import AppCatalogCore
import AppKit
@testable import AppIconPipeline
import XCTest

// MARK: - 程序生成图像（位图内存填充，零文件系统/零真实资源）

func makeIconImage(pixelWidth: Int, pixelHeight: Int,
                   r: UInt8 = 70, g: UInt8 = 110, b: UInt8 = 190) -> NSImage {
    precondition(pixelWidth > 0 && pixelHeight > 0)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixelWidth,
                               pixelsHigh: pixelHeight,
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)!
    if let data = rep.bitmapData {
        for y in 0..<pixelHeight {
            for x in 0..<pixelWidth {
                let offset = (y * pixelWidth + x) * 4
                data[offset] = r
                data[offset + 1] = g
                data[offset + 2] = b
                data[offset + 3] = 255
            }
        }
    }
    let image = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))
    image.addRepresentation(rep)
    return image
}

// MARK: - 测试身份与 key 工厂

func makeIdentity(_ n: Int) -> IconIdentity {
    IconIdentity.from(appID: CatalogFixture.appID("icon.fixture.\(n)"))
}

func makeKey(_ n: Int, pointSize: Double = 32, scale: Double = 2,
             appearance: AppearanceVariant = .system) -> IconKey {
    IconKey(identity: makeIdentity(n), pointSize: pointSize, displayScale: scale,
            appearance: appearance)
}

// MARK: - 回调捕获盒（避免 @Sendable 闭包捕获 var 的并发警告）

/// 线程安全计数盒。
final class CallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
}

/// 线程安全单值盒。
final class ValueBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) {
        _value = value
    }
    func set(_ value: T) {
        lock.lock()
        _value = value
        lock.unlock()
    }
    var value: T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

/// memory warning 通知名：macOS 26 SDK 已移除 NSApplication 常量，用稳定运行时字符串
///（与生产实现同一字符串；测试直接 post 触发清理路径）。
let memoryWarningNotificationName = Notification.Name("NSApplicationDidReceiveMemoryWarningNotification")

// MARK: - Fake loader（可注入延迟/失败；观测调用数与并发峰值）

enum FakeLoaderError: Error {
    case injected
}

final class FakeLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var _loadCount = 0
    private var _activeCount = 0
    private var _maxActiveCount = 0

    let delay: TimeInterval
    let image: NSImage
    let failingKeys: Set<IconKey>

    init(delay: TimeInterval = 0, image: NSImage? = nil, failingKeys: Set<IconKey> = []) {
        self.delay = delay
        self.image = image ?? makeIconImage(pixelWidth: 64, pixelHeight: 64)
        self.failingKeys = failingKeys
    }

    var loadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _loadCount
    }

    /// 并发观测峰值（load 同时进行中的最大数量）。
    var maxActiveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _maxActiveCount
    }

    func load(key: IconKey) async throws -> NSImage {
        let (count, active, shouldFail) = beginLoad(key: key)
        _ = count
        _ = active
        defer { endLoad() }
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldFail {
            throw FakeLoaderError.injected
        }
        return image
    }

    /// 同步锁段（规避 async 上下文中 NSLock 的不可用标注）。
    private func beginLoad(key: IconKey) -> (Int, Int, Bool) {
        lock.lock()
        defer { lock.unlock() }
        _loadCount += 1
        _activeCount += 1
        _maxActiveCount = max(_maxActiveCount, _activeCount)
        return (_loadCount, _activeCount, failingKeys.contains(key))
    }

    private func endLoad() {
        lock.lock()
        defer { lock.unlock() }
        _activeCount -= 1
    }
}
