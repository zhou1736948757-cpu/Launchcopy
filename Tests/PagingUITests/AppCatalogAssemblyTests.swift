//
//  AppCatalogAssemblyTests.swift
//  PagingUITests
//
//  Phase 1B t10：真实内容装配集成冒烟。
//  - 装配 → 首扫 → idle 提交 → surface 呈现真实 app 名/图标（fake .app，临时目录）；
//  - 多页翻转（36 apps → 2 页）跨 live host 的每页实例包装（seam 单实例缺陷修复验证）；
//  - --neutral-content 回归决策（AppRuntimeFactory → nil = Phase 1A 行为）；
//  - 红线：telemetry JSONL 无 app 名/bundle ID/路径/图标字节/启动 URL。
//

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import MacAppCatalog
@testable import PagingPrototypeApp
@testable import PagingTelemetry
@testable import PagingUI

@MainActor
final class AppCatalogAssemblyTests: XCTestCase {

    private var factory: FakeAppFactory!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
    }

    override func tearDownWithError() throws {
        factory?.removeRoot()
        factory = nil
    }

    // MARK: - 装配冒烟：真实内容上屏

    func testAssemblyScansFakeAppsAndRendersNamesAndIcons() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let loader = RecordingIconLoader()
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: loader)
        wireAssembly(assembly, to: surface)
        assembly.begin()

        // 首扫完成 → 非 busy → surface idle → 提交（启动首扫路径）。
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed, "首扫应在超时内提交快照")
        XCTAssertEqual(assembly.provider.servedRevision, 1)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.count, 6)

        // surface 采纳真实内容：page 0 六个 cell（扫描顺序非字母序 → 集合比较），名 = fixture 名。
        XCTAssertEqual(surface.core.pageCount, 1)
        let page = assembly.renderer.pageView(forPage: 0)
        XCTAssertNotNil(page, "每页实例包装器应创建 page 0 实例")
        let names = Set((0..<6).compactMap { page?.cell(at: $0)?.boundName })
        XCTAssertEqual(names, Set(["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"]))

        // 图标异步流：loader 被请求 + cell 图标最终就位（generation 门控写回）。
        // 集成发现（见 T-worker-b-integration.md）：呈现提交 = relayout 渲染 + refreshLiveHostContent
        // 再渲染两 pass（PagingUI 冻结行为）；首批请求在第二 pass 后被拒为 stale，
        // 次批同 key 请求（各 consumer 独立 generation）正常 apply → 图标最终一致。
        // 故 stale 数 = cell 数（首批每 cell 一个），非零且非缺陷（图标已全部就位）。
        let iconsSettled = await waitUntil {
            (0..<6).allSatisfy { page?.cell(at: $0)?.iconView.image != nil }
        }
        XCTAssertTrue(iconsSettled, "图标应在超时内全部异步就位（次批 apply）")
        XCTAssertGreaterThan(loader.requestedCount, 0, "图标管道应请求 loader")
        XCTAssertEqual(page?.staleIconApplyCount, 6, "提交双渲染 → 首批 6 个 stale 拒绝（次批 apply 兜底，图标一致）")

        assembly.teardown()
        surface.teardown()
    }

    // MARK: - 多页翻转：每页独立实例跨 host（seam 单实例缺陷修复验证）

    func testMultiPageFlipKeepsPerPageInstancesAcrossLiveHosts() async throws {
        // 36 apps @ 35/页 → 2 页（§10.6 边界：35 恰好满页 + 1 溢出页）。
        let names = (1...36).map { "App\($0)" }
        _ = try factory.makeApps(names: names)
        let surface = makeSurface(pageCount: 5, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.begin()

        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        XCTAssertEqual(surface.core.pageCount, 2, "36 apps @35/页 → 2 页")
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.cellCount, 35)
        XCTAssertEqual(assembly.renderer.pageView(forPage: 1)?.cellCount, 1)
        // 实例总数 = 2 页实例（初始 placeholder 渲染不创建实例；提交双渲染原地复用同实例）。
        let instancesAfterCommit = assembly.renderer.totalInstancesCreated
        XCTAssertEqual(instancesAfterCommit, 2)

        // 翻到 page 1：page 0/1 两个 live host 各自承载自己的页实例。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)

        let page0 = assembly.renderer.pageView(forPage: 0)
        let page1 = assembly.renderer.pageView(forPage: 1)
        XCTAssertNotNil(page0)
        XCTAssertNotNil(page1)
        // 扫描顺序非字母序 → page 1 末位 app 名取自已提交快照最后一条记录。
        let lastRecordName = assembly.provider.servedSnapshot?.records.last?.displayName
        XCTAssertEqual(page1?.cell(at: 0)?.boundName, lastRecordName, "page 1 = 快照最后一条记录")
        // 缺陷修复核心断言：page 0 实例仍在 page 0 host 层级（单实例共享渲染器会
        // 被移动到最后渲染的 host，page 0 将空白 —— 见 T-worker-b-integration.md）。
        if let page0, let host0 = surface.hostForPage(0) {
            XCTAssertTrue(page0.superview === host0, "page 0 实例必须留在 page 0 host 层级")
        }
        if let page1, let host1 = surface.hostForPage(1) {
            XCTAssertTrue(page1.superview === host1, "page 1 实例必须挂在 page 1 host 层级")
        }
        XCTAssertEqual(assembly.renderer.livePageInstanceCount, 2)

        // 翻回 page 0 → 实例复用（池），实例总数不增长（live 页数不变 → 零新建）。
        gestureBegan(surface, at: 1)
        gestureChanged(surface, deltaX: -600, at: 1.5)
        gestureEnded(surface, at: 1.5)
        finishPendingGesture(surface, at: 1.5)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.cellCount, 35)
        XCTAssertEqual(assembly.renderer.livePageInstanceCount, 2, "live 实例数 = live host 数")
        XCTAssertEqual(assembly.renderer.totalInstancesCreated, instancesAfterCommit,
                       "翻页往返零新建实例（池化复用）")

        assembly.teardown()
        surface.teardown()
    }

    // MARK: - 中性回归决策（Phase 1A）

    func testNeutralContentReturnsNilAssembly() {
        let options = AppArguments.Options.default
        var neutral = options
        neutral.neutralContent = true
        XCTAssertNil(AppRuntimeFactory.makeAssembly(options: neutral), "--neutral-content → 不装配（Phase 1A 回归）")
        XCTAssertNotNil(AppRuntimeFactory.makeAssembly(options: options))
    }

    func testEmptyRootsFallBackToRestrictedDefaults() {
        // 只断言扫描根选择（不 begin —— 空根缺省会扫真实 /Applications，测试隔离禁止）。
        let assembly = AppCatalogAssembly(roots: [])
        XCTAssertEqual(assembly.scanRoots, CatalogRoots.defaults, "空 --catalog-root → 4 受限根（§5.2 上界）")
        XCTAssertEqual(CatalogRoots.defaults.count, 4)
    }

    func testRendererLayoutModeTracksOnlyCommittedSearchQuery() {
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 700))
        assembly.renderer.renderTarget = host
        let appID = CatalogFixture.appID("fixture.alpha")
        let record = CatalogFixture.record(id: appID, displayName: "Alpha", bundleID: "fixture.alpha",
                                           url: CatalogFixture.tempURL(named: "alpha.app"),
                                           icon: IconIdentity.from(appID: appID), rootPriority: 0)
        assembly.provider.receive(CatalogSnapshot(revision: CatalogRevision(1), records: [record]))
        _ = assembly.provider.applyPending(atCurrentPage: 0)
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(appID),
                                          title: "Alpha")],
            isPlaceholder: false)

        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 1)
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.layoutMode, .ordinary)

        let query = AppSearchQuery(raw: "alp")
        assembly.provider.stageSearchResult(AppSearchResultSet(
            baseCatalogRevision: CatalogRevision(1), queryGeneration: AppSearchGeneration(1),
            records: [record]))
        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 2)
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.layoutMode, .ordinary,
                       "pending input must not change geometry")

        XCTAssertTrue(assembly.provider.commitPendingSearchResult(query: query))
        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 3)
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.layoutMode, .search)
        assembly.teardown()
    }

    func testRendererResolvesOnlyLiveFolderCellFrame() {
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        let host = NSView(frame: NSRect(x: 20, y: 30, width: 700, height: 700))
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 800))
        container.addSubview(host)
        assembly.renderer.committedPageProvider = { 0 }
        assembly.renderer.renderTarget = host
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000001A")!)
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID),
                                          title: "Group")],
            isPlaceholder: false)

        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1,
                                 reuseGeneration: 1)
        host.layoutSubtreeIfNeeded()
        let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 0)
        XCTAssertEqual(assembly.renderer.liveFolderFrame(for: folderID, convertedTo: container),
                       cell.map { $0.convert($0.bounds, to: container) })
        XCTAssertNil(assembly.renderer.liveFolderFrame(for: FolderID(), convertedTo: container),
                     "an unrelated or off-screen folder must not provide a motion anchor")
        assembly.teardown()
    }

    func testRendererUsesCommittedPageWhenAttachedPagesShareFolderID() {
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1_400, height: 800))
        let host0 = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 700))
        let host1 = NSView(frame: NSRect(x: 700, y: 0, width: 600, height: 700))
        container.addSubview(host0)
        container.addSubview(host1)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000001B")!)
        let content0 = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID), title: "Group 0")],
            isPlaceholder: false)
        let content1 = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 1),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID), title: "Group 1")],
            isPlaceholder: false)

        var committedPage = 1
        assembly.renderer.committedPageProvider = { committedPage }
        assembly.renderer.renderTarget = host0
        assembly.renderer.render(pageIndex: 0, content: content0, pageCount: 2, reuseGeneration: 1)
        assembly.renderer.renderTarget = host1
        assembly.renderer.render(pageIndex: 1, content: content1, pageCount: 2, reuseGeneration: 1)
        container.layoutSubtreeIfNeeded()
        assembly.renderer.pageView(forPage: 0)?.layoutSubtreeIfNeeded()
        assembly.renderer.pageView(forPage: 1)?.layoutSubtreeIfNeeded()

        let frame0 = try! XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
            .convert(try! XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0)).bounds, to: container)
        let frame1 = try! XCTUnwrap(assembly.renderer.pageView(forPage: 1)?.cell(at: 0))
            .convert(try! XCTUnwrap(assembly.renderer.pageView(forPage: 1)?.cell(at: 0)).bounds, to: container)
        XCTAssertEqual(assembly.renderer.liveFolderFrame(for: folderID, convertedTo: container), frame1)

        committedPage = 0
        XCTAssertEqual(assembly.renderer.liveFolderFrame(for: folderID, convertedTo: container), frame0)

        assembly.renderer.committedPageProvider = nil
        XCTAssertNil(assembly.renderer.liveFolderFrame(for: folderID, convertedTo: container),
                     "An anchor is unsafe when committed-page ownership is not wired")
        assembly.teardown()
    }

    func testRendererConvertsActualFolderGlyphIntoFlippedHostCoordinates() throws {
        let fixture = try makeFolderIconFixture(flippedDestination: true)
        defer { fixture.assembly.teardown() }
        let symbol = try XCTUnwrap(fixture.cell.subviews.compactMap { $0 as? NSImageView }
            .first { $0 !== fixture.cell.iconView })
        symbol.frame = symbol.frame.insetBy(dx: 3, dy: 5).offsetBy(dx: 1, dy: -1)
        let glyph = try XCTUnwrap(fixture.cell.folderMotionSourceFrame)
        let inRoot = fixture.cell.convert(glyph, to: fixture.root)
        let destination = fixture.destination
        let expected = NSRect(
            x: inRoot.minX - destination.frame.minX + destination.bounds.minX,
            y: destination.bounds.maxY - (inRoot.maxY - destination.frame.minY),
            width: inRoot.width, height: inRoot.height)
        let actual = try XCTUnwrap(fixture.assembly.renderer.liveFolderIconFrame(
            for: fixture.folderID, convertedTo: destination))
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.0001)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.0001)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.0001)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.0001)
        let fullCell = try XCTUnwrap(fixture.assembly.renderer.liveFolderFrame(
            for: fixture.folderID, convertedTo: destination))
        XCTAssertLessThan(actual.width, fullCell.width)
        XCTAssertLessThan(actual.height, fullCell.height)

        // A destination coordinate system need not contain the source glyph.
        destination.frame.size = NSSize(width: 20, height: 20)
        XCTAssertNotNil(fixture.assembly.renderer.liveFolderIconFrame(
            for: fixture.folderID, convertedTo: destination))
        XCTAssertNil(fixture.assembly.renderer.liveFolderIconFrame(
            for: fixture.folderID, convertedTo: NSView(frame: fixture.root.bounds)),
            "An unrelated hierarchy cannot supply a coordinate conversion")
    }

    func testRendererGlyphSourceUsesOnlyCurrentCommittedPage() throws {
        let fixture = try makeFolderIconFixture()
        defer { fixture.assembly.teardown() }
        let renderer = fixture.assembly.renderer
        let adjacentHost = NSView(frame: NSRect(x: 760, y: 50, width: 700, height: 700))
        fixture.root.addSubview(adjacentHost)
        let adjacentOnlyID = FolderID()
        renderer.renderTarget = adjacentHost
        renderer.render(pageIndex: 1, content: PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 1),
            items: [PagingPageContentItem(slot: 35, identity: AnyHashable(fixture.folderID), title: "Duplicate"),
                    PagingPageContentItem(slot: 36, identity: AnyHashable(adjacentOnlyID), title: "Adjacent only")],
            isPlaceholder: false), pageCount: 2, reuseGeneration: 2)
        let page1 = try XCTUnwrap(renderer.pageView(forPage: 1))
        adjacentHost.layoutSubtreeIfNeeded()
        let cell1 = try XCTUnwrap(page1.cell(at: 0))
        let glyph1 = try XCTUnwrap(cell1.folderMotionSourceFrame)
        var committedPage = 0
        renderer.committedPageProvider = { committedPage }
        XCTAssertEqual(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root),
                       fixture.cell.convert(try XCTUnwrap(fixture.cell.folderMotionSourceFrame), to: fixture.root))
        XCTAssertNil(renderer.liveFolderIconFrame(for: adjacentOnlyID, convertedTo: fixture.root))
        committedPage = 1
        XCTAssertEqual(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root),
                       cell1.convert(glyph1, to: fixture.root))
        // The requested destination does not clip a valid source on its committed page.
        XCTAssertNotNil(renderer.liveFolderIconFrame(for: adjacentOnlyID, convertedTo: fixture.destination))
        committedPage = 2
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))
        renderer.committedPageProvider = nil
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))
    }

    func testRendererGlyphSourceRejectsHiddenDetachedOffscreenAndClearedSources() throws {
        let fixture = try makeFolderIconFixture()
        defer { fixture.assembly.teardown() }
        let renderer = fixture.assembly.renderer
        func source() -> NSRect? {
            renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.destination)
        }
        XCTAssertNotNil(source())
        XCTAssertNil(renderer.liveFolderIconFrame(for: FolderID(), convertedTo: fixture.destination))
        fixture.cell.isHidden = true
        XCTAssertNil(source())
        fixture.cell.isHidden = false
        fixture.page.isHidden = true
        XCTAssertNil(source())
        fixture.page.isHidden = false
        fixture.pageHost.isHidden = true
        XCTAssertNil(source())
        fixture.pageHost.isHidden = false
        let originalFrame = fixture.cell.frame
        fixture.cell.frame.origin.x = fixture.page.bounds.maxX + 100
        XCTAssertNil(source(), "A wholly offscreen glyph must not provide an anchor")
        fixture.cell.frame = originalFrame
        fixture.cell.removeFromSuperview()
        XCTAssertNil(source())
        fixture.page.addSubview(fixture.cell)
        fixture.page.removeFromSuperview()
        XCTAssertNil(source())
        fixture.pageHost.addSubview(fixture.page)
        fixture.pageHost.removeFromSuperview()
        XCTAssertNil(source(), "A retired host is invalid before the renderer sweeps it")
        fixture.root.addSubview(fixture.pageHost)
        XCTAssertNotNil(source())
        fixture.page.clearForReuse()
        XCTAssertNil(source())
    }

    func testRendererGlyphSourceRejectsNonFolderStaleBindingAndReusedHost() throws {
        let fixture = try makeFolderIconFixture()
        defer { fixture.assembly.teardown() }
        let renderer = fixture.assembly.renderer
        let original = try XCTUnwrap(fixture.cell.bindingToken)
        fixture.cell.bind(name: "Not a folder", token: original)
        fixture.cell.layout()
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))
        // The legacy whole-cell API retains its identity-only behavior.
        XCTAssertNotNil(renderer.liveFolderFrame(for: fixture.folderID, convertedTo: fixture.root))
        let stale = ItemBindingToken(catalogRevision: original.catalogRevision,
                                    pageIdentity: original.pageIdentity,
                                    itemSlot: original.itemSlot, appID: original.appID,
                                    reuseGeneration: original.reuseGeneration,
                                    iconKey: nil, surfaceGeneration: original.surfaceGeneration + 1)
        fixture.cell.bindFolder(title: "Stale", memberCount: 0, token: stale)
        fixture.cell.layout()
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))
        let stalePage = ItemBindingToken(catalogRevision: original.catalogRevision,
                                        pageIdentity: PagePresentationID(revision: 1, pageIndex: 1),
                                        itemSlot: original.itemSlot, appID: original.appID,
                                        reuseGeneration: original.reuseGeneration,
                                        iconKey: nil, surfaceGeneration: original.surfaceGeneration)
        fixture.cell.bindFolder(title: "Wrong page", memberCount: 0, token: stalePage)
        fixture.cell.layout()
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))

        let replacementID = FolderID()
        renderer.renderTarget = fixture.pageHost
        renderer.render(pageIndex: 1, content: PagingPageContent(
            presentationID: PagePresentationID(revision: 2, pageIndex: 1),
            items: [PagingPageContentItem(slot: 35, identity: AnyHashable(replacementID), title: "Replacement")],
            isPlaceholder: false), pageCount: 2, reuseGeneration: 2)
        fixture.pageHost.layoutSubtreeIfNeeded()
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))
        XCTAssertNil(renderer.liveFolderIconFrame(for: replacementID, convertedTo: fixture.root),
                     "A reused host must not replace committed-page ownership")
        renderer.committedPageProvider = { 1 }
        XCTAssertNil(renderer.liveFolderIconFrame(for: fixture.folderID, convertedTo: fixture.root))
        XCTAssertNotNil(renderer.liveFolderIconFrame(for: replacementID, convertedTo: fixture.root))
    }

    private struct FolderIconFixture {
        let assembly: AppCatalogAssembly
        let root: NSView
        let pageHost: NSView
        let destination: NSView
        let folderID: FolderID
        let page: AppGridPageView
        let cell: AppGridCellView
    }

    private func makeFolderIconFixture(flippedDestination: Bool = false) throws -> FolderIconFixture {
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1_600, height: 900))
        let pageHost = NSView(frame: NSRect(x: 40, y: 50, width: 700, height: 700))
        let destination: NSView = flippedDestination ? FolderIconFlippedHost() : NSView()
        destination.frame = NSRect(x: 12, y: 18, width: 950, height: 820)
        destination.bounds.origin = NSPoint(x: 17, y: 23)
        root.addSubview(pageHost)
        root.addSubview(destination)
        let folderID = FolderID()
        assembly.renderer.committedPageProvider = { 0 }
        assembly.renderer.renderTarget = pageHost
        assembly.renderer.render(pageIndex: 0, content: PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID), title: "Group")],
            isPlaceholder: false), pageCount: 2, reuseGeneration: 1)
        pageHost.layoutSubtreeIfNeeded()
        let page = try XCTUnwrap(assembly.renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0))
        return FolderIconFixture(assembly: assembly, root: root, pageHost: pageHost,
                                 destination: destination, folderID: folderID, page: page, cell: cell)
    }

    func testCatalogRootOverrideUsed() throws {
        let assembly = AppCatalogAssembly(roots: [factory.root])
        XCTAssertEqual(assembly.scanRoots, [factory.root], "--catalog-root 覆盖默认根")
    }

    // MARK: - 红线：telemetry 无任何身份原文

    func testTelemetryRedLineNoIdentityLeak() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)

        // 生产接线（AppDelegate 同构）：bridge + 呈现/图标 telemetry。
        let configuration = TelemetryConfiguration(
            enabled: true,
            runID: "content-redline-001",
            outputDirectory: factory.root.appendingPathComponent("telemetry", isDirectory: true)
        )
        let session = TelemetrySession(configuration: configuration)
        session.begin()
        let bridge = PagingTelemetryBridge(surface: surface, session: session)
        assembly.onPresentationUpdate = { [weak surface, weak bridge, weak assembly] update in
            guard let surface, let assembly else { return }
            surface.refreshPresentation()
            surface.setPageCount(update.plan.pageCount)
            bridge?.recordCatalogPresentation(update, assembly: assembly)
        }
        assembly.renderer.onIconApplyResult = { [weak bridge] _, result in
            bridge?.recordIconAsyncState(result)
        }
        assembly.begin()

        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)

        // 一次完整手势（cell 复用计数）+ 图标就位 + teardown。
        let iconsSettled = await waitUntil {
            (0..<3).allSatisfy { assembly.renderer.pageView(forPage: 0)?.cell(at: $0)?.iconView.image != nil }
        }
        XCTAssertTrue(iconsSettled)
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        settleFrames(surface)
        surface.teardown()
        assembly.teardown()
        session.end()

        // 读取 JSONL：断言期望字段出现 + 红线字段绝不出现。
        let url = factory.root.appendingPathComponent("telemetry/launch-copy-paging-prototype-content-redline-001.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(text.contains("\"event_phase\":\"catalog.presentation\""), "应有 catalog.presentation 事件")
        XCTAssertTrue(text.contains("\"event_phase\":\"icon.async\""), "应有 icon.async 事件")
        XCTAssertTrue(text.contains("snapshot_revision"), "应有 snapshot_revision 字段")
        XCTAssertTrue(text.contains("catalog_scan_duration_ms"), "应有 catalog_scan_duration_ms 字段")
        XCTAssertTrue(text.contains("refresh_duration_ms"), "应有 refresh_duration_ms 字段")
        XCTAssertTrue(text.contains("icon_async_state"), "应有 icon_async_state 字段")

        // 红线：无 app 名 / bundle ID / 路径 / 启动 URL 原文。
        for forbidden in ["Alpha", "Beta", "Gamma", "fixture.alpha", "fixture.beta", "fixture.gamma", ".app"] {
            XCTAssertFalse(text.contains(forbidden), "JSONL 不得包含身份原文: \(forbidden)")
        }
        XCTAssertFalse(text.contains(factory.root.path), "JSONL 不得包含临时根路径")
    }
}

@MainActor
private final class FolderIconFlippedHost: NSView {
    override var isFlipped: Bool { true }
}
