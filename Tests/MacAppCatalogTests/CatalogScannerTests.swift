//
//  CatalogScannerTests.swift
//  MacAppCatalogTests
//
//  Phase 1B — 受限根枚举 / 失败分类 / 取消（§10.3；wave1-interfaces.md §C）。
//  全部用例只使用临时目录 + 程序生成 fake .app；绝不触碰真实 /Applications。
//

import XCTest
import Darwin
import AppCatalogCore
@testable import MacAppCatalog

final class CatalogScannerTests: XCTestCase {

    // MARK: 工具

    private func scan(_ configuration: ScanConfiguration,
                      scanner: CatalogScanner = CatalogScanner(),
                      revision: CatalogRevision = .init(1)) -> CatalogScanResult {
        let expectation = XCTestExpectation(description: "scan completion")
        let box = ResultBox()
        let task = scanner.scan(configuration: configuration, revision: revision) { result in
            box.value = result
            expectation.fulfill()
        }
        XCTAssertFalse(task.isCancelled)
        wait(for: [expectation], timeout: 10)
        return XCTUnwrapOrFail(box.value)
    }

    private func XCTUnwrapOrFail<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("expected non-nil value", file: file, line: line)
            fatalError("unreachable after XCTFail")
        }
        return value
    }

    // MARK: 枚举

    func testEnumeratesTopLevelApps() throws {
        let factory = try FakeAppFactory()
        try factory.makeApp(named: "One", bundleID: "com.example.one")
        try factory.makeApp(named: "Two", bundleID: "com.example.two")
        try factory.makeFile(named: "readme.txt")          // 普通文件 → 忽略
        try factory.makeDirectory("PlainDir")              // 无 app 的目录 → 空

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertFalse(result.cancelled)
        XCTAssertNotNil(result.snapshot)
        XCTAssertEqual(result.snapshot?.records.count, 2)
        XCTAssertEqual(result.report.appCount, 2)
        XCTAssertTrue(result.report.failureCounts.isEmpty)
    }

    func testRecordsCarryBundleMetadata() throws {
        let factory = try FakeAppFactory()
        try factory.makeApp(named: "Alpha", bundleID: "com.example.alpha", bundleName: "Alpha Display")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        let record = try XCTUnwrap(result.snapshot?.records.first)
        XCTAssertEqual(record.displayName, "Alpha Display")
        XCTAssertEqual(record.bundleIdentifier, "com.example.alpha")
        XCTAssertEqual(record.id, AppID.bundleIdentifier("com.example.alpha"))
        XCTAssertEqual(record.canonicalURL.path, factory.root.appendingPathComponent("Alpha.app").path)
        XCTAssertEqual(record.sourceRootPriority, 0)
    }

    func testDisplayNameFallsBackToFilenameStem() throws {
        let factory = try FakeAppFactory()
        try factory.makeApp(named: "NoName", bundleID: "com.example.noname")   // 无 CFBundleName

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.snapshot?.records.first?.displayName, "NoName")
    }

    func testRecursesIntoPlainDirectories() throws {
        let factory = try FakeAppFactory()
        let tools = try factory.makeDirectory("Tools")
        try factory.makeApp(named: "Deep", in: tools, bundleID: "com.example.deep")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.snapshot?.records.count, 1)
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.deep")
    }

    // MARK: stopAtAppBundle（§10.3：.app 内嵌 helper 不被当顶层 app）

    func testHelperAppInsideBundleIsNotEnumeratedByDefault() throws {
        let factory = try FakeAppFactory()
        let main = try factory.makeApp(named: "Main", bundleID: "com.example.main")
        try factory.makeHelperApp(named: "Helper", inside: main)

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.snapshot?.records.count, 1)          // 只有 Main
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.main")
    }

    func testStopAtAppBundleFalseEntersBundle() throws {
        let factory = try FakeAppFactory()
        let main = try factory.makeApp(named: "Main", bundleID: "com.example.main")
        try factory.makeHelperApp(named: "Helper", inside: main)

        let result = scan(ScanConfiguration(roots: [factory.root], stopAtAppBundle: false))
        XCTAssertEqual(result.snapshot?.records.count, 2)          // 显式放弃默认安全行为
    }

    // MARK: 缺 bundle ID（软失败：fallback 身份入册 + 计数）

    func testMissingBundleIdentifierUsesURLFallbackAndCounts() throws {
        let factory = try FakeAppFactory()
        try factory.makeAppWithoutBundleID(named: "NoID", bundleName: "No ID App")
        try factory.makeApp(named: "WithID", bundleID: "com.example.withid")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.snapshot?.records.count, 2)          // 缺 ID 者也入册（规则 4）
        XCTAssertEqual(result.report.failureCounts[.missingBundleIdentifier], 1)
        XCTAssertEqual(result.report.failureCounts[.corruptedBundle], nil)
        let noIDRecord = result.snapshot?.records.first { $0.bundleIdentifier == nil }
        XCTAssertNotNil(noIDRecord)
        XCTAssertEqual(noIDRecord?.displayName, "No ID App")
        // fallback 身份 = canonicalURLFallback（displayName 不作身份）
        let canonical = URLNormalizer.canonicalize(
            factory.root.appendingPathComponent("NoID.app"), under: factory.root)
        XCTAssertEqual(noIDRecord?.id, AppID.canonicalURLFallback(XCTUnwrapOrFail(canonical)))
    }

    // MARK: 损坏 / 无效 bundle 分类

    func testCorruptedPlistClassifiedAndExcluded() throws {
        let factory = try FakeAppFactory()
        try factory.makeCorruptedApp(named: "Bad")
        try factory.makeApp(named: "Good", bundleID: "com.example.good")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.report.failureCounts[.corruptedBundle], 1)
        XCTAssertEqual(result.snapshot?.records.count, 1)          // 损坏者不入册
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.good")
    }

    func testInvalidAppBundleClassifiedAndExcluded() throws {
        let factory = try FakeAppFactory()
        try factory.makeInvalidApp(named: "Empty")
        try factory.makeApp(named: "Good", bundleID: "com.example.good")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.report.failureCounts[.invalidAppBundle], 1)
        XCTAssertEqual(result.snapshot?.records.count, 1)
    }

    // MARK: 不可读目录（若平台允许稳定模拟）

    func testUnreadableDirectoryClassified() throws {
        let factory = try FakeAppFactory()
        let locked = try factory.makeDirectory("Locked")
        try factory.makeApp(named: "Inner", in: locked, bundleID: "com.example.inner")
        try factory.makeApp(named: "Visible", bundleID: "com.example.visible")

        factory.root.withUnsafeFileSystemRepresentation { path in
            guard let path else { return }
            chmod(path, 0o755)
        }
        locked.withUnsafeFileSystemRepresentation { path in
            guard let path else { return }
            chmod(path, 0o000)
        }
        defer {
            locked.withUnsafeFileSystemRepresentation { path in
                guard let path else { return }
                chmod(path, 0o755)
            }
        }
        try XCTSkipIf(FileManager.default.isReadableFile(atPath: locked.path),
                      "以提升权限运行：无法稳定模拟不可读目录")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.report.failureCounts[.unreadableDirectory], 1)
        XCTAssertEqual(result.snapshot?.records.count, 1)          // 只有可见者
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.visible")
    }

    // MARK: symlink 策略与 cycle

    func testSymlinkedAppNotFollowedByDefault() throws {
        let factory = try FakeAppFactory()
        let real = try factory.makeApp(named: "Real", bundleID: "com.example.real")
        try factory.makeSymlink(named: "Linked.app", to: real)     // symlink 指向 bundle

        let result = scan(ScanConfiguration(roots: [factory.root]))  // follow=false（默认）
        XCTAssertEqual(result.snapshot?.records.count, 1)          // Linked.app 被跳过
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.real")
    }

    func testSymlinkedAppFollowedWhenEnabled() throws {
        let factory = try FakeAppFactory()
        let real = try factory.makeApp(named: "Real", bundleID: "com.example.real")
        try factory.makeSymlink(named: "Linked.app", to: real)

        let result = scan(ScanConfiguration(roots: [factory.root], followDirectorySymlinks: true))
        XCTAssertEqual(result.snapshot?.records.count, 2)          // 真实路径 + symlink 路径各一条
    }

    func testSymlinkCycleDetectedAndTerminates() throws {
        let factory = try FakeAppFactory()
        let dirA = try factory.makeDirectory("DirA")
        try factory.makeApp(named: "Solo", bundleID: "com.example.solo")
        try factory.makeSymlink(named: "loop", in: dirA, to: dirA)  // A/loop → A 自环

        let result = scan(ScanConfiguration(roots: [factory.root], followDirectorySymlinks: true))
        XCTAssertEqual(result.report.failureCounts[.symlinkCycleDetected], 1)
        XCTAssertEqual(result.snapshot?.records.count, 1)          // 不挂起、不入环
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.solo")
    }

    func testDiamondSymlinkDoesNotDuplicateOrCycle() throws {
        let factory = try FakeAppFactory()
        let dirA = try factory.makeDirectory("DirA")
        try factory.makeApp(named: "Shared", in: dirA, bundleID: "com.example.shared")
        let dirB = try factory.makeDirectory("DirB")
        try factory.makeSymlink(named: "aliasToA", in: dirB, to: dirA)

        let result = scan(ScanConfiguration(roots: [factory.root], followDirectorySymlinks: true))
        XCTAssertEqual(result.report.failureCounts[.symlinkCycleDetected], nil)  // 非回边
        XCTAssertEqual(result.snapshot?.records.count, 1)          // visited 去重：同一目录只遍历一次
    }

    // MARK: 重叠根去重

    func testOverlappingRootsDeduped() throws {
        let factory = try FakeAppFactory()
        let base = try factory.makeDirectory("Base")
        let sub = try factory.makeDirectory("Sub", in: base)
        try factory.makeApp(named: "BaseApp", in: base, bundleID: "com.example.base")
        try factory.makeApp(named: "SubApp", in: sub, bundleID: "com.example.sub")

        // 开启去重：Sub ⊂ Base → Sub 根被移除 → 每个 app 恰好一条。
        let deduped = scan(ScanConfiguration(roots: [base, sub]))
        XCTAssertEqual(deduped.snapshot?.records.count, 2)
        XCTAssertEqual(Set(deduped.snapshot?.records.compactMap(\.bundleIdentifier) ?? []),
                       ["com.example.base", "com.example.sub"])

        // 关闭去重：Sub 被 Base 递归 + 独立根各枚举一次 → 3 条原始记录。
        let raw = scan(ScanConfiguration(roots: [base, sub], dedupeOverlappingRoots: false))
        XCTAssertEqual(raw.snapshot?.records.count, 3)
    }

    // MARK: 多根优先级

    func testRootPriorityAssignedInOrder() throws {
        let factory = try FakeAppFactory()
        let first = try factory.makeDirectory("First")
        let second = try factory.makeDirectory("Second")
        try factory.makeApp(named: "A", in: first, bundleID: "com.example.a")
        try factory.makeApp(named: "B", in: second, bundleID: "com.example.b")

        let result = scan(ScanConfiguration(roots: [first, second]))
        let byID = Dictionary(uniqueKeysWithValues:
            (result.snapshot?.records ?? []).map { ($0.bundleIdentifier ?? "", $0) })
        XCTAssertEqual(byID["com.example.a"]?.sourceRootPriority, 0)   // 0 = 最高优先级根
        XCTAssertEqual(byID["com.example.b"]?.sourceRootPriority, 1)
    }

    // MARK: 隐藏文件

    func testHiddenAppsSkipped() throws {
        let factory = try FakeAppFactory()
        try factory.makeApp(named: ".Secret", bundleID: "com.example.secret")
        try factory.makeApp(named: "Visible", bundleID: "com.example.visible")

        let result = scan(ScanConfiguration(roots: [factory.root]))
        XCTAssertEqual(result.snapshot?.records.count, 1)
        XCTAssertEqual(result.snapshot?.records.first?.bundleIdentifier, "com.example.visible")
    }

    // MARK: 失败分类不携带原文（隐私边界，§10.3 / Explorer C）

    func testFailureReportContainsNoPathNameOrIDOriginals() throws {
        let factory = try FakeAppFactory()
        try factory.makeCorruptedApp(named: "SecretCorrupt")
        try factory.makeAppWithoutBundleID(named: "SecretNoID")
        try factory.makeInvalidApp(named: "SecretEmpty")
        let secretRoot = try factory.makeDirectory("SecretRootWithLongName")
        try factory.makeApp(named: "Ok", in: secretRoot, bundleID: "com.example.ok")
        try factory.makeSymlink(named: "loop", in: secretRoot, to: secretRoot)

        let config = ScanConfiguration(roots: [factory.root], followDirectorySymlinks: true)
        let result = scan(config)
        let report = result.report

        // 1) 分类键必须是冻结枚举（无扩展分类通道）。
        XCTAssertTrue(report.failureCounts.keys.allSatisfy { ScanFailureKind.allCases.contains($0) })
        // 2) 序列化整个报告不得含路径分隔符、bundle 扩展名或 bundle ID 原文。
        let serialized = String(describing: report)
        XCTAssertFalse(serialized.contains("/"), "报告泄漏了路径原文: \(serialized)")
        XCTAssertFalse(serialized.contains(".app"), "报告泄漏了 bundle 扩展名: \(serialized)")
        XCTAssertFalse(serialized.contains("com.example"), "报告泄漏了 bundle ID 原文: \(serialized)")
        XCTAssertFalse(serialized.contains("Secret"), "报告泄漏了名称原文: \(serialized)")
        // 3) 计数类型为整数（只计数）。
        XCTAssertEqual(report.failureCounts[.corruptedBundle], 1)
        XCTAssertEqual(report.failureCounts[.missingBundleIdentifier], 1)
        XCTAssertEqual(report.failureCounts[.invalidAppBundle], 1)
        XCTAssertEqual(report.failureCounts[.symlinkCycleDetected], 1)
        XCTAssertEqual(report.appCount, 2)   // SecretNoID（fallback 入册）+ Ok
    }

    // MARK: 取消（中途取消 → 部分结果丢弃）

    func testCancelImmediatelyAfterStartDropsPartialResult() throws {
        let factory = try FakeAppFactory()
        for index in 0..<300 {
            try factory.makeApp(named: "Bulk\(index)", bundleID: "com.example.bulk\(index)")
        }
        let expectation = XCTestExpectation(description: "scan completion")
        let box = ResultBox()
        let scanner = CatalogScanner()
        let task = scanner.scan(configuration: ScanConfiguration(roots: [factory.root]),
                                revision: .init(1)) { result in
            box.value = result
            expectation.fulfill()
        }
        task.cancel()   // 立即取消：扫描尚未完成
        wait(for: [expectation], timeout: 10)

        let result = XCTUnwrapOrFail(box.value)
        XCTAssertTrue(result.cancelled)
        XCTAssertNil(result.snapshot)                       // 部分结果整体丢弃
        XCTAssertLessThan(result.report.appCount, 300)      // 只回报已完成部分的计数
    }

    func testDeterministicMidScanCancellationDropsPartialResult() throws {
        let factory = try FakeAppFactory()
        for index in 0..<40 {
            try factory.makeApp(named: "Mid\(index)", bundleID: "com.example.mid\(index)")
        }
        let expectation = XCTestExpectation(description: "scan completion")
        let box = ResultBox()
        let taskBox = CancellingTaskBox()
        let reader = CancellingAfterNReader(limit: 10) { [taskBox] in taskBox.cancel() }
        let scanner = CatalogScanner(metadataReader: reader)
        let task = scanner.scan(configuration: ScanConfiguration(roots: [factory.root]),
                                revision: .init(7)) { result in
            box.value = result
            expectation.fulfill()
        }
        taskBox.set(task)   // 第 10 次 bundle 读取时取消
        wait(for: [expectation], timeout: 10)

        let result = XCTUnwrapOrFail(box.value)
        XCTAssertTrue(result.cancelled)
        XCTAssertNil(result.snapshot)                       // 条目间检查 → 部分结果丢弃
        XCTAssertEqual(result.report.appCount, 10)          // 恰处理 10 个后中止
        XCTAssertLessThan(result.report.appCount, 40)
    }
}

// MARK: - 测试注入工具

/// 完成回调结果盒：规避 @Sendable 闭包内 var 捕获警告（Swift 5 模式警告 / Swift 6 错误）。
private final class ResultBox: @unchecked Sendable {
    var value: CatalogScanResult?
}

/// 线程安全的任务盒：metadata reader 在扫描队列上取消，测试线程先设置任务。
private final class CancellingTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: ScanTask?
    func set(_ value: ScanTask) {
        lock.lock()
        task = value
        lock.unlock()
    }
    func cancel() {
        lock.lock()
        task?.cancel()
        lock.unlock()
    }
}

/// 读到第 N 个 bundle 时触发取消回调（随后委托真实读取）——确定性中途取消。
private final class CancellingAfterNReader: BundleMetadataReading, @unchecked Sendable {
    private let limit: Int
    private let onThreshold: () -> Void
    private let lock = NSLock()
    private var count = 0
    private let inner = BundleMetadataReader()

    init(limit: Int, onThreshold: @escaping () -> Void) {
        self.limit = limit
        self.onThreshold = onThreshold
    }

    func readBundleMetadata(at url: URL, fileManager: FileManager) -> BundleMetadataResult {
        lock.lock()
        count += 1
        let current = count
        lock.unlock()
        if current == limit { onThreshold() }
        return inner.readBundleMetadata(at: url, fileManager: fileManager)
    }
}
