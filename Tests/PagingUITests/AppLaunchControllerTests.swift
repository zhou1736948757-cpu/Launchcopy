//
//  AppLaunchControllerTests.swift
//  PagingUITests
//
//  Phase 1B t11（§3.2）：应用启动 smoke —— 单击触发 + stale 拒绝 + 非致命失败 + 红线。
//  全部经 fake launcher / fake .app / 临时目录；绝不启动真实 bundle、不触碰 /Applications。
//

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingTelemetry
@testable import PagingUI

/// 记录启动 URL 的 fake launcher（可编程失败）。
final class RecordingLauncher: AppLaunching, @unchecked Sendable {
    private let lock = NSLock()
    private var _opened: [URL] = []
    var shouldSucceed = true
    var opened: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _opened
    }
    func openApplication(at url: URL) -> Bool {
        lock.lock()
        _opened.append(url)
        lock.unlock()
        return shouldSucceed
    }
}

@MainActor
final class AppLaunchControllerTests: XCTestCase {

    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var launcher: RecordingLauncher!
    private var controller: AppLaunchController!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        launcher = RecordingLauncher()
    }

    override func tearDownWithError() throws {
        controller = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        factory?.removeRoot()
        factory = nil
    }

    /// 装配 + 首扫提交，返回第一个 cell（Alpha）。
    private func readyCell() async throws -> AppGridCellView {
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        guard let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 0) else {
            XCTFail("page 0 应有 cell")
            throw TestError.missingCell
        }
        return cell
    }

    private enum TestError: Error { case missingCell }

    // MARK: - §3.2 全项

    func testSingleClickLaunchesCurrentApp() async throws {
        let apps = try factory.makeApps(names: ["Alpha", "Beta"])
        let cell = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        let outcome = controller.handleCell(cell)
        XCTAssertEqual(outcome, .launched, "当前 catalog 中的 app 单击应启动")
        XCTAssertEqual(launcher.opened, [apps["Alpha"]!], "应启动 Alpha 的 bundle URL")
        XCTAssertEqual(controller.outcomeCounts[.launched], 1)
    }

    func testClickHitPathReachesCell() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        _ = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        // 从 cell 中心换算到 surface 坐标 → hitTest 命中 → 视图链找到 cell → 启动。
        // 先强制页布局（无窗口测试中 cell frame 依赖显式 layout）。
        guard let page = assembly.renderer.pageView(forPage: 0),
              let cell = page.cell(at: 0) else {
            XCTFail("应有 page/cell")
            return
        }
        page.layout()
        let cellFrame = cell.convert(cell.bounds, to: surface)
        let point = NSPoint(x: cellFrame.midX, y: cellFrame.midY)
        let outcome = controller.handleClick(at: point)
        XCTAssertEqual(outcome, .launched, "命中测试路径（与手势识别器同一管线）应启动")
        XCTAssertEqual(launcher.opened.count, 1)
    }

    func testStaleRevisionRejected() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        let cell = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        // 构造 stale cell：catalog revision 落后于已服务 revision（§3.2 stale 拒绝）。
        guard let served = assembly.provider.servedRevision else {
            XCTFail("应有 served revision")
            return
        }
        let staleToken = ItemBindingToken(
            catalogRevision: served - 1,
            pageIdentity: PagePresentationID(revision: served - 1, pageIndex: 0),
            itemSlot: 0,
            appID: cell.bindingToken?.appID,
            reuseGeneration: 1,
            iconKey: nil,
            surfaceGeneration: 1
        )
        let staleCell = AppGridCellView()
        staleCell.bind(name: "Alpha", token: staleToken)
        let outcome = controller.handleCell(staleCell)
        XCTAssertEqual(outcome, .rejectedStaleRevision, "旧 revision cell 必须拒绝")
        XCTAssertTrue(launcher.opened.isEmpty, "stale 拒绝不得启动任何 bundle")
    }

    func testRemovedAppRejected() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        _ = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        guard let served = assembly.provider.servedRevision else {
            XCTFail("应有 served revision")
            return
        }
        // 幽灵 AppID（不在当前 catalog 的 identity→URL 映射）→ 重新确认失败。
        let ghostToken = ItemBindingToken(
            catalogRevision: served,
            pageIdentity: PagePresentationID(revision: served, pageIndex: 0),
            itemSlot: 99,
            appID: AnyHashable(AppID.bundleIdentifier("fixture.ghost")),
            reuseGeneration: 1,
            iconKey: nil,
            surfaceGeneration: 1
        )
        let ghostCell = AppGridCellView()
        ghostCell.bind(name: "Ghost", token: ghostToken)
        let outcome = controller.handleCell(ghostCell)
        XCTAssertEqual(outcome, .rejectedMissingApp, "不在当前 catalog → 拒绝")
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    func testDeletedFileRejected() async throws {
        let apps = try factory.makeApps(names: ["Alpha"])
        let cell = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        // catalog 与磁盘不一致：扫描后删除 bundle（磁盘重新确认失败）。
        try FileManager.default.removeItem(at: apps["Alpha"]!)
        let outcome = controller.handleCell(cell)
        XCTAssertEqual(outcome, .rejectedMissingFile, "bundle 已从磁盘消失 → 拒绝启动")
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    func testLaunchFailureNonFatalAndRecovers() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        let cell = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        launcher.shouldSucceed = false
        let failed = controller.handleCell(cell)
        XCTAssertEqual(failed, .failedToLaunch, "启动失败 → 中性失败结果（非崩溃/非弹窗）")
        // 非致命：随后可正常启动（同会话继续可用）。
        launcher.shouldSucceed = true
        let recovered = controller.handleCell(cell)
        XCTAssertEqual(recovered, .launched, "失败非致命，后续启动恢复")
        XCTAssertEqual(controller.outcomeCounts[.failedToLaunch], 1)
        XCTAssertEqual(controller.outcomeCounts[.launched], 1)
    }

    func testBlankHitRejectedNoBinding() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        _ = try await readyCell()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher
        )
        let outcome = controller.handleClick(at: NSPoint(x: 5, y: 5))
        XCTAssertEqual(outcome, .rejectedNoBinding, "空白处单击 → 中性拒绝")
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    // MARK: - 红线：telemetry 无 URL/身份原文

    func testLaunchTelemetryContainsNoURL() async throws {
        let apps = try factory.makeApps(names: ["Alpha"])
        let cell = try await readyCell()

        let configuration = TelemetryConfiguration(
            enabled: true,
            runID: "launch-redline-001",
            outputDirectory: factory.root.appendingPathComponent("telemetry", isDirectory: true)
        )
        let session = TelemetrySession(configuration: configuration)
        session.begin()
        controller = AppLaunchController(
            surface: surface, assembly: assembly, launcher: launcher, session: session
        )
        XCTAssertEqual(controller.handleCell(cell), .launched)
        session.end()

        let url = factory.root.appendingPathComponent("telemetry/launch-copy-paging-prototype-launch-redline-001.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"event_phase\":\"app.launch\""), "应有 app.launch 中性事件")
        XCTAssertFalse(text.contains("Alpha"), "JSONL 不得含 app 名")
        XCTAssertFalse(text.contains("fixture.alpha"), "JSONL 不得含 bundle ID")
        XCTAssertFalse(text.contains(apps["Alpha"]!.path), "JSONL 不得含启动 URL/路径")
        XCTAssertFalse(text.contains(".app"), "JSONL 不得含 bundle 后缀")
    }
}
