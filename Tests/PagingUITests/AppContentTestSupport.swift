//
//  AppContentTestSupport.swift
//  PagingUITests
//
//  Phase 1B Wave 3（t10/t11）测试台：fake .app fixture + 程序生成图标 loader + 轮询等待。
//  资源隔离（§10.3/§10.4）：只用系统临时目录；图标程序生成（NSBitmapImageRep 画方块），
//  绝不复制第三方图标进 fixture；测试绝不触碰真实 /Applications。
//

import AppKit
import Foundation
import XCTest
@testable import AppIconPipeline
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

// MARK: - fake .app fixture（临时目录内生成，测试后整目录删除）

/// 在系统临时目录下生成 fake .app bundle（Info.plist 含 CFBundleIdentifier/CFBundleName）。
/// 名字/ID 用 fixture.* 命名空间 —— 红线测试以此断言 JSONL 不含任何身份原文。
final class FakeAppFactory {
    let root: URL
    private let fileManager = FileManager.default
    private var counter = 0

    /// 建工厂即建唯一临时根（测试 tearDown 用 removeRoot 清理）。
    init(prefix: String = "paging-content-tests") throws {
        root = fileManager.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// 生成一个合法 fake .app；返回 bundle URL。name/ID 默认递增（fixture.app1…）。
    @discardableResult
    func makeApp(named name: String? = nil, bundleID: String? = nil) throws -> URL {
        counter += 1
        let appName = name ?? "app\(counter)"
        let appURL = root.appendingPathComponent("\(appName).app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
        var plist: [String: Any] = [
            "CFBundleIdentifier": bundleID ?? "fixture.app\(counter)",
            "CFBundleName": appName,
            "CFBundlePackageType": "APPL",
        ]
        if bundleID == nil { plist["CFBundleIdentifier"] = "fixture.app\(counter)" }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }

    /// 批量生成：返回 [名字: bundleURL]（有序；名如 Alpha, Beta, …）。
    @discardableResult
    func makeApps(names: [String]) throws -> [String: URL] {
        var result: [String: URL] = [:]
        for name in names {
            result[name] = try makeApp(named: name, bundleID: "fixture.\(name.lowercased())")
        }
        return result
    }

    func removeRoot() {
        try? fileManager.removeItem(at: root)
    }
}

// MARK: - 程序生成图标 loader（无第三方图标；红线安全）

/// 立即返回程序生成 NSImage 的 loader：记录请求 key（断言图标流发生），
/// apply 路径与真实 SystemIconLoader 相同（IconPipeline 异步 deliver）。
final class RecordingIconLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var _keys: [IconKey] = []
    /// 已请求的 key（顺序；Identity 不透明 —— 只数不读）。
    var requestedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _keys.count
    }

    func load(key: IconKey) async throws -> NSImage {
        append(key)
        return Self.solidImage()
    }

    private func append(_ key: IconKey) {
        // 同步辅助（async 上下文经它拿锁：NSLock 在 async 函数内直调为 Swift 6 弃用）。
        lock.lock()
        defer { lock.unlock() }
        _keys.append(key)
    }

    /// 程序生成 48×48 纯色方块（NSBitmapImageRep 绘制；无任何真实图标数据）。
    static func solidImage(size: CGFloat = 48) -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        return image
    }
}

// MARK: - 轮询等待（扫描/图标异步完成）

/// 轮询条件（MainActor 睡眠让步；测试驱动与真实 Task 交错）。
func waitUntil(_ condition: @escaping () -> Bool,
               timeout: TimeInterval = 10,
               file: StaticString = #filePath, line: UInt = #line) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline {
            XCTFail("waitUntil 超时（\(timeout)s）", file: file, line: line)
            return false
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return true
}

// MARK: - 装配接线（与 AppDelegate.installContentAssembly 同构；测试内复刻）

/// 按 App 生产路径接线 surface + assembly（provider/renderer/提交回调/idle 提交/首扫提交）。
/// 返回装配实例。调用方须 @MainActor。
@MainActor
func wireAssembly(_ assembly: AppCatalogAssembly, to surface: PagingSurface) {
    surface.contentProvider = assembly.provider
    surface.renderer = assembly.renderer
    assembly.renderer.committedPageProvider = { [weak surface] in
        surface?.core.committedPage ?? 0
    }
    assembly.refreshController.itemsPerPage = surface.itemsPerPage
    assembly.onPresentationUpdate = { [weak surface] update in
        guard let surface else { return }
        surface.refreshPresentation()
        surface.setPageCount(update.plan.pageCount)
    }
    surface.onIdleBoundary = { [weak assembly, weak surface] in
        guard let assembly, let surface else { return }
        MainActor.assumeIsolated {
            _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: surface.core.committedPage)
        }
    }
    assembly.refreshController.onStateChange = { [weak assembly, weak surface] state in
        guard let assembly, let surface, !state.isBusy else { return }
        if surface.core.state == .idle {
            MainActor.assumeIsolated {
                _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: surface.core.committedPage)
            }
        }
    }
}
