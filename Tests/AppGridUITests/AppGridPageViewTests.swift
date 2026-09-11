// AppGridUITests — AppGridPageView（§10.5：真实网格渲染；复用无旧名/旧图标；
// 图标乱序到达只落最新 generation；stale async UI apply = 0；冷/暖 cache；
// 失败 → 中性 placeholder；teardown 后零写回；accessibility）
//
// 全部 @MainActor：视图主线程受限；IconPipeline 保证 onApply 在 MainActor 投递。
// fake loader（GatedIconLoader）控制到达顺序；程序生成图像；绝不触碰真实 /Applications。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class AppGridPageViewTests: XCTestCase {

    private func makePage(loader: GatedIconLoader) -> (AppGridPageView, IconPipeline) {
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        return (page, pipeline)
    }

    /// 观察钩子：记录 + 按结果 fulfill 期望。
    private func attach(_ page: AppGridPageView, _ recorder: ApplyRecorder,
                        applied: XCTestExpectation? = nil,
                        rejected: XCTestExpectation? = nil,
                        failed: XCTestExpectation? = nil,
                        ignored: XCTestExpectation? = nil) {
        page.onIconApplyResult = { token, result in
            recorder.record(token, result)
            switch result {
            case .applied: applied?.fulfill()
            case .rejectedStale: rejected?.fulfill()
            case .failed: failed?.fulfill()
            case .cancelled: break
            case .ignoredAfterTeardown: ignored?.fulfill()
            }
        }
    }

    // MARK: - 同步文本渲染

    func testRenderShowsNamesSynchronously() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let alphaID = makeAppID("fixture.alpha")
        let betaID = makeAppID("fixture.beta")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0,
                                         titles: ["Alpha", "Beta"],
                                         appIDs: [alphaID, betaID]),
                    pageCount: 3, reuseGeneration: 1)

        // 无任何 await：名称与 cell 立即可见（同步文本）
        XCTAssertEqual(page.cellCount, 2)
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "Alpha")
        XCTAssertEqual(page.cell(at: 1)?.nameLabel.stringValue, "Beta")
        XCTAssertEqual(page.pageLabelText, "Page 1 of 3")
        XCTAssertEqual(page.accessibilityLabel(), "Page 1 of 3")
        // load 任务运行在并发池线程（gate 注册与主线程存在竞态）→ 先等 pending 就位再断言
        // （与同文件其他测试一致的模式；消除偶发 pendingKeyCount == 0 的 flaky）。
        await waitForPendingLoads(loader, count: 2)
        XCTAssertEqual(loader.pendingKeyCount, 2, "图标异步在途（不阻塞渲染）")
    }

    /// identity 为 nil（中性占位 item）→ 只写名称，不请求图标。
    func testNilIdentitySkipsIconRequest() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["NoIcon"]),
                    pageCount: 1, reuseGeneration: 1)
        XCTAssertEqual(page.cellCount, 1)
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "NoIcon")
        XCTAssertEqual(loader.pendingKeyCount, 0, "无 AppID → 无图标请求")
    }

    /// 占位内容 → 无 cell、无图标请求。
    func testPlaceholderContentRendersNoCells() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        page.render(pageIndex: 0, content: makePlaceholderContent(revision: 1, page: 0),
                    pageCount: 1, reuseGeneration: 1)
        XCTAssertEqual(page.cellCount, 0)
        XCTAssertEqual(loader.pendingKeyCount, 0)
    }

    // MARK: - 复用：清空 → 新内容 → 图标到达（无旧名/旧图标残留）

    func testReuseClearsOldContentAndRejectsOldIcons() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let oldRejected = expectation(description: "old icon rejected")
        let newApplied = expectation(description: "new icon applied")
        attach(page, recorder, applied: newApplied, rejected: oldRejected)

        let alphaID = makeAppID("fixture.alpha")
        let betaID = makeAppID("fixture.beta")
        let gammaID = makeAppID("fixture.gamma")
        let keyAlpha = IconKey(identity: IconIdentity.from(appID: alphaID), pointSize: 32, displayScale: 1)

        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha", "Beta"],
                                         appIDs: [alphaID, betaID]),
                    pageCount: 2, reuseGeneration: 1)
        await waitForPendingLoads(loader, count: 2, timeout: 3)
        XCTAssertEqual(loader.pendingKeyCount, 2)

        // 复用路径：clear → 新内容（不同 app）
        page.clearForReuse()
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "", "清空后无旧名")
        XCTAssertNil(page.cell(at: 0)?.iconView.image, "清空后无旧图标")
        XCTAssertNil(page.cell(at: 0)?.bindingToken, "清空后无旧 token")

        page.render(pageIndex: 1,
                    content: makeContent(revision: 1, page: 1, titles: ["Gamma"],
                                         appIDs: [gammaID]),
                    pageCount: 2, reuseGeneration: 2)

        // 新内容立即可见（同步）
        XCTAssertEqual(page.cellCount, 1)
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "Gamma")
        XCTAssertNil(page.cell(at: 0)?.iconView.image, "新内容就位但旧图标不得残留")

        await waitForPendingLoads(loader, count: 2, timeout: 3)
        // 旧请求图标到达 → 门控拒绝（stale），不落 cell
        loader.complete(key: keyAlpha, image: makeIconImage(r: 200, g: 30, b: 30))
        await fulfillment(of: [oldRejected], timeout: 3)
        XCTAssertNil(page.cell(at: 0)?.iconView.image, "旧图标绝不写回新 cell")

        // 新请求图标到达 → 落 cell
        let gammaKey = IconKey(identity: IconIdentity.from(appID: gammaID), pointSize: 32, displayScale: 1)
        loader.complete(key: gammaKey, image: makeIconImage(r: 30, g: 200, b: 30))
        await fulfillment(of: [newApplied], timeout: 3)
        XCTAssertNotNil(page.cell(at: 0)?.iconView.image)

        XCTAssertEqual(recorder.count(.rejectedStale), 1, "旧图标 apply 被拒绝（stale result rejected）")
        XCTAssertEqual(page.staleIconApplyCount, 1)
        XCTAssertEqual(recorder.count(.applied), 1)
    }

    // MARK: - 乱序到达：只落最新 generation

    func testOutOfOrderIconsOnlyLatestGenerationLands() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let appliedTwo = expectation(description: "2 applied")
        appliedTwo.expectedFulfillmentCount = 2
        let rejectedTwo = expectation(description: "2 rejected")
        rejectedTwo.expectedFulfillmentCount = 2
        attach(page, recorder, applied: appliedTwo, rejected: rejectedTwo)

        let alphaID = makeAppID("fixture.alpha")
        let betaID = makeAppID("fixture.beta")
        let gammaID = makeAppID("fixture.gamma")
        let deltaID = makeAppID("fixture.delta")

        // rev1 渲染：[Alpha, Beta]（generation 1）
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha", "Beta"],
                                         appIDs: [alphaID, betaID]),
                    pageCount: 1, reuseGeneration: 1)
        // rev2 渲染：[Gamma, Delta]（generation 2）—— 完全不同 key
        page.render(pageIndex: 0,
                    content: makeContent(revision: 2, page: 0, titles: ["Gamma", "Delta"],
                                         appIDs: [gammaID, deltaID]),
                    pageCount: 1, reuseGeneration: 2)

        let keyAlpha = IconKey(identity: IconIdentity.from(appID: alphaID), pointSize: 32, displayScale: 1)
        let keyBeta = IconKey(identity: IconIdentity.from(appID: betaID), pointSize: 32, displayScale: 1)
        let keyGamma = IconKey(identity: IconIdentity.from(appID: gammaID), pointSize: 32, displayScale: 1)
        let keyDelta = IconKey(identity: IconIdentity.from(appID: deltaID), pointSize: 32, displayScale: 1)

        await waitForPendingLoads(loader, count: 4, timeout: 3)
        // 乱序完成：先旧后新交错 —— 旧的（rev1）全部拒绝，新的（rev2）全部落地
        loader.complete(key: keyAlpha, image: makeIconImage(r: 255, g: 0, b: 0))
        loader.complete(key: keyDelta, image: makeIconImage(r: 0, g: 0, b: 255))
        loader.complete(key: keyBeta, image: makeIconImage(r: 255, g: 0, b: 0))
        loader.complete(key: keyGamma, image: makeIconImage(r: 0, g: 255, b: 0))
        await fulfillment(of: [appliedTwo, rejectedTwo], timeout: 5)

        XCTAssertEqual(recorder.count(.applied), 2)
        XCTAssertEqual(recorder.count(.rejectedStale), 2, "rev1 两个图标 apply 全部拒绝")
        XCTAssertEqual(page.staleIconApplyCount, 2)

        // 只落最新 generation：cell 显示 Gamma/Delta 的图标，绝不显示 Alpha/Beta 的
        let gammaImage = page.cell(at: 0)?.iconView.image
        let deltaImage = page.cell(at: 1)?.iconView.image
        XCTAssertNotNil(gammaImage)
        XCTAssertNotNil(deltaImage)
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "Gamma")
        XCTAssertEqual(page.cell(at: 1)?.nameLabel.stringValue, "Delta")
        // 旧图标颜色（红）不得出现；新图标颜色（绿/蓝）必须出现
        XCTAssertNotEqual(gammaImage?.tiffRepresentation, makeIconImage(r: 255, g: 0, b: 0).tiffRepresentation)
        XCTAssertNotEqual(deltaImage?.tiffRepresentation, makeIconImage(r: 255, g: 0, b: 0).tiffRepresentation)
        XCTAssertEqual(gammaImage?.tiffRepresentation, makeIconImage(r: 0, g: 255, b: 0).tiffRepresentation)
        XCTAssertEqual(deltaImage?.tiffRepresentation, makeIconImage(r: 0, g: 0, b: 255).tiffRepresentation)
    }

    /// 同 key 合并（in-flight merge）：一次底层加载投递两代 consumer；只落当前代。
    func testSameKeyMergeOnlyCurrentGenerationApplies() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let applied = expectation(description: "current gen applied")
        let rejected = expectation(description: "old gen rejected")
        attach(page, recorder, applied: applied, rejected: rejected)

        let alphaID = makeAppID("fixture.alpha")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 1)
        page.render(pageIndex: 0,
                    content: makeContent(revision: 2, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 2)

        let keyAlpha = IconKey(identity: IconIdentity.from(appID: alphaID), pointSize: 32, displayScale: 1)
        await waitForPendingLoads(loader, count: 1, timeout: 3)
        XCTAssertEqual(loader.pendingKeyCount, 1, "同 key 两次请求合并为一次底层加载")

        let image = makeIconImage(r: 10, g: 20, b: 30)
        loader.complete(key: keyAlpha, image: image)
        await fulfillment(of: [applied, rejected], timeout: 3)

        XCTAssertEqual(recorder.count(.applied), 1, "只落当前 generation")
        XCTAssertEqual(recorder.count(.rejectedStale), 1, "旧 generation 的投递被门控拒绝")
        XCTAssertEqual(page.cell(at: 0)?.iconView.image?.tiffRepresentation, image.tiffRepresentation)
    }

    // MARK: - 冷/暖 cache

    func testColdThenWarmIconCacheHit() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let coldApplied = expectation(description: "cold icon applied")
        let warmApplied = expectation(description: "warm icon applied (cache hit)")
        // 单个钩子闭包（attach 会整体替换钩子，故此处手写：第 1 次 applied = 冷，第 2 次 = 暖）
        page.onIconApplyResult = { token, result in
            recorder.record(token, result)
            if case .applied = result {
                if recorder.count(.applied) == 1 {
                    coldApplied.fulfill()
                } else {
                    warmApplied.fulfill()
                }
            }
        }

        let alphaID = makeAppID("fixture.alpha")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 1)
        let keyAlpha = IconKey(identity: IconIdentity.from(appID: alphaID), pointSize: 32, displayScale: 1)
        await waitForPendingLoads(loader, count: 1, timeout: 3)
        loader.complete(key: keyAlpha)
        await fulfillment(of: [coldApplied], timeout: 3)
        XCTAssertEqual(pipeline.stats.cacheMisses, 1)

        // 暖：同一 key 再次渲染 → cache hit，不触发新加载
        page.render(pageIndex: 0,
                    content: makeContent(revision: 2, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 2)
        await fulfillment(of: [warmApplied], timeout: 3)
        XCTAssertEqual(pipeline.stats.cacheHits, 1)
        XCTAssertEqual(loader.pendingKeyCount, 0)
        XCTAssertEqual(recorder.count(.applied), 2)
        XCTAssertEqual(recorder.count(.rejectedStale), 0, "同态渲染无 stale apply")
        XCTAssertEqual(page.staleIconApplyCount, 0)
    }

    // MARK: - 失败 / 取消 / teardown

    func testIconFailureKeepsNeutralPlaceholder() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let failed = expectation(description: "failed delivered")
        attach(page, recorder, failed: failed)

        let alphaID = makeAppID("fixture.alpha")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 1)
        let keyAlpha = IconKey(identity: IconIdentity.from(appID: alphaID), pointSize: 32, displayScale: 1)
        await waitForPendingLoads(loader, count: 1, timeout: 3)
        loader.fail(key: keyAlpha)
        await fulfillment(of: [failed], timeout: 3)

        XCTAssertEqual(recorder.count(.failed), 1)
        XCTAssertNil(page.cell(at: 0)?.iconView.image, "失败 → 中性 placeholder 保持")
        XCTAssertEqual(recorder.count(.rejectedStale), 0)
        XCTAssertEqual(page.staleIconApplyCount, 0)
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "Alpha", "名称不受图标失败影响")
    }

    func testTeardownZeroApply() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let ignored = expectation(description: "ignored after teardown")
        attach(page, recorder, ignored: ignored)

        let alphaID = makeAppID("fixture.alpha")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 1)
        page.teardown()

        let keyAlpha = IconKey(identity: IconIdentity.from(appID: alphaID), pointSize: 32, displayScale: 1)
        await waitForPendingLoads(loader, count: 1, timeout: 3)
        loader.complete(key: keyAlpha, image: makeIconImage(r: 1, g: 2, b: 3))
        await fulfillment(of: [ignored], timeout: 3)

        XCTAssertEqual(recorder.count(.ignoredAfterTeardown), 1)
        XCTAssertEqual(recorder.count(.applied), 0, "teardown 后零 UI 写回")
        XCTAssertEqual(recorder.count(.rejectedStale), 0)
        XCTAssertEqual(page.staleIconApplyCount, 0)
        XCTAssertEqual(page.cellCount, 0)
    }

    // MARK: - T-1D 水平居中：同 revision 重载（pageCount 缩小 → 部分结果页）后内容保持居中

    /// T-1D-layout-centering-repair：搜索提交（同 revision 重载、pageCount 4→1）后，部分结果页的
    /// 网格行必须水平居中于页面（页 = 全窗口宽）。满行（35 项全页）几何与左对齐原点完全一致，零回归。
    func testSameRevisionReloadPartialResultStaysHorizontallyCentered() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let pageWidth: CGFloat = 1000
        page.frame = NSRect(x: 0, y: 0, width: pageWidth, height: 700)

        // 1) 全目录页（35 项满行）→ 左对齐原点，几何与改造前一致（回归守卫）。
        let fullTitles = (0..<35).map { "App\($0)" }
        let fullIDs = fullTitles.map { makeAppID("fixture.app\($0)") }
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: fullTitles, appIDs: fullIDs),
                    pageCount: 4, reuseGeneration: 1)
        page.layout()
        XCTAssertEqual(page.cellCount, 35)
        guard let fullFirst = page.cell(at: 0) else { return }
        XCTAssertEqual(fullFirst.frame.minX, 24, "满行仍从左侧 inset 原点布局（零回归）")

        // 2) 搜索提交：同 revision 重载，pageCount 4→1，单结果（z → ZCode）→ 该 cell 水平居中。
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["ZCode"],
                                         appIDs: [makeAppID("fixture.zcode")]),
                    pageCount: 1, reuseGeneration: 2)
        page.layout()
        XCTAssertEqual(page.cellCount, 1)
        guard let cell = page.cell(at: 0) else { return }
        // 居中原点：cell 中心 == 页中心（页 = 全窗口宽，故 == 窗口/宿主中心）。
        XCTAssertEqual(cell.frame.midX, page.bounds.midX, accuracy: 0.5,
                       "搜索单结果 cell 水平居中于页（不再被挤到左侧）")
    }

    /// 部分行的居中同样适用于多结果但不足一整页的末行（如 7 项 → 末行 2 项居中）。
    func testPartialRowCenteredForMultiResultLastRow() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        page.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        let titles = (0..<7).map { "App\($0)" }
        let ids = titles.map { makeAppID("fixture.app\($0)") }
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: titles, appIDs: ids),
                    pageCount: 1, reuseGeneration: 1)
        page.layout()
        XCTAssertEqual(page.cellCount, 7)
        // 第 0 行满（5 项）→ 仍从左侧起始；第 6 个 cell（末行 col 1）所在行应整体居中。
        XCTAssertEqual(page.cell(at: 0)?.frame.minX, 24, "满行起始不变（回归守卫）")
        guard let lastRowFirst = page.cell(at: 5), let lastRowSecond = page.cell(at: 6) else { return }
        // 末行 2 项：行内容的几何中心 == 页中心。
        let rowSpan = lastRowSecond.frame.maxX - lastRowFirst.frame.minX
        XCTAssertEqual(lastRowFirst.frame.minX + rowSpan / 2, page.bounds.midX, accuracy: 0.5,
                       "不足一整页的末行整体水平居中")
    }

    // MARK: - accessibility（§9：名称截断不影响辅助技术读取完整名称）

    func testAccessibilityFullName() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let veryLongName = String(repeating: "VeryLongApplicationName", count: 6)
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: [veryLongName],
                                         appIDs: [makeAppID("fixture.long")]),
                    pageCount: 5, reuseGeneration: 1)

        XCTAssertEqual(page.cell(at: 0)?.accessibilityLabel(), veryLongName, "辅助技术读完整名称")
        XCTAssertEqual(page.accessibilityLabel(), "Page 1 of 5")
        // 视觉截断不改变可访问标签
        XCTAssertEqual(page.cell(at: 0)?.nameLabel.lineBreakMode, .byTruncatingTail)
    }

    // MARK: - T-1F-B10-regression-fix §2.1 取证（E6a'：中间层投递观测，纯转发 census）

    /// E6a'：AppGridPageView.mouseDown/mouseUp 纯转发 census（sE6_page_down/up 中性计数；
    /// 转发 super 原样 = 零行为变更）。判别：>0 → 投递目标=AppGridPageView → f 族定罪。
    func testPageViewMouseDownUpForwardingCensus() {
        ClickCensus.resetForTesting()
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let down = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 60, y: 60),
                                      modifierFlags: [], timestamp: 0, windowNumber: 0,
                                      context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: 60, y: 60),
                                    modifierFlags: [], timestamp: 0, windowNumber: 0,
                                    context: nil, eventNumber: 2, clickCount: 1, pressure: 0)!

        page.mouseDown(with: down)
        page.mouseUp(with: up)

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pageViewMouseDown), 1,
                       "E6a' mouseDown 转发计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pageViewMouseUp), 1,
                       "E6a' mouseUp 转发计数 1")
        // 转发 super 不 crash（NSView 默认实现沿响应链上抛；无观察副作用）。
    }

    /// E6a'：sink 名中性断言（仅语义名，无坐标/身份/标题）。
    func testPageViewSinkNamesAreNeutral() {
        XCTAssertEqual(ClickCensus.Sink.pageViewMouseDown, "sE6_page_down")
        XCTAssertEqual(ClickCensus.Sink.pageViewMouseUp, "sE6_page_up")
        for name in [ClickCensus.Sink.pageViewMouseDown, ClickCensus.Sink.pageViewMouseUp] {
            XCTAssertFalse(name.contains("windowNumber"), "sink 名不含窗口号码原文（隐私）：\(name)")
            XCTAssertFalse(name.contains("_win_"), "sink 名不含窗口身份（隐私）：\(name)")
            XCTAssertFalse(name.contains("NSApp"), "sink 名不含 App 身份（隐私）：\(name)")
        }
    }
}
