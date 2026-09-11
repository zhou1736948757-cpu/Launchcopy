//
//  FakeAppFactory.swift
//  MacAppCatalogTests
//
//  Phase 1B — 测试资源隔离（§10.3 / §3.3 / §14.C）：
//  只用系统临时目录 + 程序生成的 fake .app bundle（Info.plist 合法/缺字段/损坏/symlink 变体），
//  绝不扫描真实 /Applications、绝不复制真实 app 或图标进 fixture。
//

import Foundation

/// 在独立临时目录中程序化构建 fake `.app` bundle 树。
/// 每个实例一个唯一根目录，deinit 时整体清理。
final class FakeAppFactory {
    /// 唯一临时根目录（`$TMPDIR/MacAppCatalogTests-<uuid>`）。
    let root: URL
    private let fileManager = FileManager.default
    private var counter = 0

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacAppCatalogTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: root)
    }

    // MARK: 目录

    /// 在 parent（缺省根）下创建目录。
    @discardableResult
    func makeDirectory(_ name: String, in parent: URL? = nil) throws -> URL {
        let directory = (parent ?? root).appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 生成唯一前缀名（避免同名冲突）。
    func uniqueName(_ prefix: String = "App") -> String {
        counter += 1
        return "\(prefix)\(counter)"
    }

    // MARK: fake .app 变体（§10.3：合法 / 缺字段 / 损坏 / 无效）

    /// 合法 bundle：`Contents/Info.plist` 含 CFBundleIdentifier（可空）+ CFBundleName（可空）。
    @discardableResult
    func makeApp(named name: String, in parent: URL? = nil,
                 bundleID: String? = nil, bundleName: String? = nil) throws -> URL {
        let appURL = (parent ?? root).appendingPathComponent("\(name).app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
        var plist: [String: Any] = [:]
        if let bundleID { plist["CFBundleIdentifier"] = bundleID }
        if let bundleName { plist["CFBundleName"] = bundleName }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }

    /// 合法 plist 但**缺 CFBundleIdentifier**（软失败变体）。
    @discardableResult
    func makeAppWithoutBundleID(named name: String, in parent: URL? = nil,
                                bundleName: String? = nil) throws -> URL {
        try makeApp(named: name, in: parent, bundleID: nil, bundleName: bundleName)
    }

    /// **损坏** plist（二进制垃圾，PropertyListSerialization 无法解析）。
    @discardableResult
    func makeCorruptedApp(named name: String, in parent: URL? = nil) throws -> URL {
        let appURL = (parent ?? root).appendingPathComponent("\(name).app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
        var garbage = Data([0x00, 0x01, 0xFF, 0xFE, 0x7F])
        garbage.append(Data("<?xml corrupt \u{0}\u{1}".utf8))
        try garbage.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }

    /// **无效** bundle：`.app` 目录但无 `Contents/Info.plist`。
    @discardableResult
    func makeInvalidApp(named name: String, in parent: URL? = nil) throws -> URL {
        let appURL = (parent ?? root).appendingPathComponent("\(name).app", isDirectory: true)
        try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        return appURL
    }

    /// 在已有 bundle 内部放置内嵌 helper（`Contents/Helpers/`）——不得被当作顶层 app（§10.3）。
    @discardableResult
    func makeHelperApp(named name: String, inside appURL: URL) throws -> URL {
        let helpers = appURL.appendingPathComponent("Contents/Helpers", isDirectory: true)
        try fileManager.createDirectory(at: helpers, withIntermediateDirectories: true)
        return try makeApp(named: name, in: helpers)
    }

    /// 普通文件（非 app）。
    @discardableResult
    func makeFile(named name: String, in parent: URL? = nil) throws -> URL {
        let fileURL = (parent ?? root).appendingPathComponent(name)
        try Data("not an app".utf8).write(to: fileURL)
        return fileURL
    }

    /// symlink（目录或文件）。
    @discardableResult
    func makeSymlink(named name: String, in parent: URL? = nil, to target: URL) throws -> URL {
        let linkURL = (parent ?? root).appendingPathComponent(name)
        try fileManager.createSymbolicLink(at: linkURL, withDestinationURL: target)
        return linkURL
    }
}
