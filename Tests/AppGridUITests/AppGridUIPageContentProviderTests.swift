// AppGridUITests — AppGridUIPageContentProvider（§10.5：real provider 页内容正确；
// snapshot idle apply / tracking defer / 多次 refresh latest-wins / page count shrink；
// §6.3 anchor remap 五级降级）

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

final class AppGridUIPageContentProviderTests: XCTestCase {

    // MARK: - 快照 → 页内容映射

    func testContentMapsSnapshotToPageSlots() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0),
                                       itemsPerPage: 35)

        XCTAssertFalse(content.isPlaceholder)
        XCTAssertEqual(content.presentationID, PagePresentationID(revision: 1, pageIndex: 0))
        XCTAssertEqual(content.items.count, 3)
        XCTAssertEqual(content.items[0].slot, 0)
        XCTAssertEqual(content.items[0].title, "Alpha")
        XCTAssertEqual(content.items[1].slot, 1)
        XCTAssertEqual(content.items[1].title, "Beta")
        XCTAssertEqual(content.items[2].slot, 2)
        XCTAssertEqual(content.items[2].title, "Gamma")
        // identity 承载 AppID（AnyHashable）
        let appID = content.items[0].identity as? AppID
        XCTAssertEqual(appID, makeAppID("fixture.alpha"))
    }

    /// 页边界：35 条 = 1 页、36 条 = 2 页（与 PagingSurface 默认对齐，§B 要点 ③）。
    func testItemsPerPageBoundary() throws {
        let thirtyFive = try makeSnapshot(titles: (0..<35).map { "App\($0)" }, revision: 1)
        let thirtySix = try makeSnapshot(titles: (0..<36).map { "App\($0)" }, revision: 2)

        let provider = AppGridUIPageContentProvider(snapshot: thirtyFive)
        XCTAssertEqual(provider.servedPageCount, 1)
        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(content.items.count, 35)
        XCTAssertTrue(provider.content(for: PagePresentationID(revision: 1, pageIndex: 1),
                                      itemsPerPage: 35).isPlaceholder, "越界页 → 占位")

        provider.receive(thirtySix)
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(update?.plan.pageCount, 2)
        let page1 = provider.content(for: PagePresentationID(revision: 2, pageIndex: 1), itemsPerPage: 35)
        XCTAssertFalse(page1.isPlaceholder)
        XCTAssertEqual(page1.items.count, 1, "尾页只有 1 条")
        XCTAssertEqual(page1.items[0].slot, 35, "全局槽位 = page * itemsPerPage + 页内序号")
    }

    /// 未就绪（无 served 快照）→ 全部占位。
    func testNoSnapshotServesPlaceholder() {
        let provider = AppGridUIPageContentProvider()
        XCTAssertNil(provider.servedRevision)
        let content = provider.content(for: PagePresentationID(revision: 0, pageIndex: 0), itemsPerPage: 35)
        XCTAssertTrue(content.isPlaceholder)
        XCTAssertTrue(content.items.isEmpty)
    }

    /// revision 不匹配 → 占位（§6.1：一页所有 item 必须同一 presentation revision；
    /// 混合 revision 请求一律拒绝）。
    func testRevisionMismatchServesPlaceholder() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 3)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let content = provider.content(for: PagePresentationID(revision: 2, pageIndex: 0), itemsPerPage: 35)
        XCTAssertTrue(content.isPlaceholder)
    }

    // MARK: - pending latest-wins（§6.2 tracking/settling 期间 defer）

    func testReceiveLatestWinsPending() throws {
        let provider = AppGridUIPageContentProvider()
        let rev1 = try makeSnapshot(titles: ["A"], revision: 1)
        let rev2 = try makeSnapshot(titles: ["A", "B"], revision: 2)
        let rev3 = try makeSnapshot(titles: ["A", "B", "C"], revision: 3)

        provider.receive(rev1)
        provider.receive(rev2)
        provider.receive(rev3)

        XCTAssertNil(provider.servedSnapshot, "手势期间不得替换 served")
        XCTAssertEqual(provider.pendingRevision, 3, "连续刷新只保留最新 revision")
        XCTAssertEqual(provider.hasPendingSnapshot, true)

        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.plan.snapshotRevision.value, 3)
        XCTAssertEqual(provider.servedRevision, 3)
        XCTAssertNil(provider.pendingSnapshot)
    }

    /// 无 pending → applyPending 无操作（nil）。
    func testApplyPendingNoOpWithoutPending() throws {
        let provider = AppGridUIPageContentProvider(snapshot: try makeSnapshot(titles: ["A"], revision: 1))
        XCTAssertNil(provider.applyPending(atCurrentPage: 0))
        XCTAssertEqual(provider.servedRevision, 1)
    }

    /// discardPending 丢弃未提交快照。
    func testDiscardPending() throws {
        let provider = AppGridUIPageContentProvider()
        provider.receive(try makeSnapshot(titles: ["A"], revision: 1))
        provider.discardPending()
        XCTAssertFalse(provider.hasPendingSnapshot)
        XCTAssertNil(provider.applyPending(atCurrentPage: 0))
    }

    // MARK: - anchor remap 五级降级（§6.3 规则 1–5；ADR-004 冻结）

    /// 规则 1：anchor 仍存在 → .located（新页）。
    func testRemapLocated() throws {
        let old = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: old)
        let anchor = provider.anchorCandidate(nearPage: 0)
        XCTAssertEqual(anchor, makeAppID("fixture.alpha"))

        let new = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 2)
        provider.receive(new)
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(update?.outcome, .located(pageIndex: 0))
        XCTAssertEqual(update?.anchor, anchor)
        XCTAssertEqual(update?.previousRevision, 1)
        XCTAssertEqual(update?.newRevision, 2)
    }

    /// 规则 2：anchor 消失 → 稳定排序后继所在页。
    func testRemapSuccessor() throws {
        // 40 条 → 页 1 首位 = App35（fixture.app35）
        let old = try makeSnapshot(titles: (0..<40).map { String(format: "App%02d", $0) }, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: old)
        let anchor = try XCTUnwrap(provider.anchorCandidate(nearPage: 1))
        XCTAssertEqual(anchor, makeAppID("fixture.app35"))

        // 新快照：anchor 消失，仅剩排序后于 anchor 的记录 → successor = 首个后继所在页
        let new = try makeSnapshot(titles: ["App36", "App37"], revision: 2)
        provider.receive(new)
        let update = provider.applyPending(atCurrentPage: 1)
        guard case .successor(let page) = update?.outcome else {
            return XCTFail("期望 successor，got \(String(describing: update?.outcome))")
        }
        XCTAssertEqual(page, 0, "后继 fixture.app36 在第 1 位 → 页 0")
    }

    /// 规则 3：无后继 → 前驱。
    func testRemapPredecessor() throws {
        let old = try makeSnapshot(titles: (0..<40).map { String(format: "App%02d", $0) }, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: old)
        let anchor = try XCTUnwrap(provider.anchorCandidate(nearPage: 1))
        XCTAssertEqual(anchor, makeAppID("fixture.app35"))

        // 新快照：只剩排序先于 anchor 的记录（无后继）→ 前驱 = 最后一个前驱所在页
        let new = try makeSnapshot(titles: ["App00", "App34"], revision: 2)
        provider.receive(new)
        let update = provider.applyPending(atCurrentPage: 1)
        guard case .predecessor(let page) = update?.outcome else {
            return XCTFail("期望 predecessor，got \(String(describing: update?.outcome))")
        }
        XCTAssertEqual(page, 0, "前驱 fixture.app34 在第 2 位 → 页 0")
    }

    /// 规则 4：都无 → clamped 合法页。
    func testRemapClamped() throws {
        let provider = AppGridUIPageContentProvider()   // 无 served → anchor nil
        let new = try makeSnapshot(titles: ["Alpha"], revision: 1)
        provider.receive(new)
        let update = provider.applyPending(atCurrentPage: 3)
        XCTAssertEqual(update?.outcome, .clamped(pageIndex: 0))
    }

    /// 规则 5：空 catalog → .emptyCatalog（pageCount 0 合法空态）。
    func testRemapEmptyCatalog() throws {
        let old = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: old)
        provider.receive(try makeSnapshot(titles: [], revision: 2))
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(update?.outcome, .emptyCatalog)
        XCTAssertEqual(update?.plan.pageCount, 0)
        // 空 catalog 下任何页请求 → 占位
        XCTAssertTrue(provider.content(for: PagePresentationID(revision: 2, pageIndex: 0),
                                       itemsPerPage: 35).isPlaceholder)
    }

    /// 规则 6：remap 绝不沿用旧数组 index —— 结果完全由新快照 + anchor 推导
    /// （签名不含旧快照/旧页；此测试证明跨页重排后 anchor 落点只依赖新快照）。
    func testRemapNeverUsesOldIndex() throws {
        let old = try makeSnapshot(titles: (0..<40).map { String(format: "App%02d", $0) }, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: old)
        let anchor = try XCTUnwrap(provider.anchorCandidate(nearPage: 1), "页 1 首位 = App35")
        XCTAssertEqual(anchor, makeAppID("fixture.app35"))

        // 新快照：App36…App39 之外全部移除 → App35 升到第 2 位（页 0）
        let new = try makeSnapshot(titles: ["App0", "App35", "App36", "App37", "App38", "App39"], revision: 2)
        provider.receive(new)
        let update = provider.applyPending(atCurrentPage: 1)
        guard case .located(let page) = update?.outcome else {
            return XCTFail("期望 located，got \(String(describing: update?.outcome))")
        }
        XCTAssertEqual(page, 0, "anchor 新位置第 2 位 → 页 0；旧 index 35（页 1）绝不被沿用")
    }

    // MARK: - page count shrink（§10.5）

    func testPageCountShrink() throws {
        let wide = try makeSnapshot(titles: (0..<70).map { String(format: "App%02d", $0) }, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: wide)
        XCTAssertEqual(provider.servedPageCount, 2)

        provider.receive(try makeSnapshot(titles: ["Only"], revision: 2))
        let update = provider.applyPending(atCurrentPage: 1)
        XCTAssertEqual(update?.plan.pageCount, 1, "70 → 1 条：页数收缩")
        XCTAssertEqual(update?.plan.itemCount, 1)
        // 收缩后越界页 → 占位（不崩溃）
        XCTAssertTrue(provider.content(for: PagePresentationID(revision: 2, pageIndex: 1),
                                       itemsPerPage: 35).isPlaceholder)
    }

    // MARK: - servedPageCount 用实例 itemsPerPage（T-1E-H2 repair）

    /// 非默认 itemsPerPage：70 条 + itemsPerPage=20 → servedPageCount == 4（非硬编码 35 的 2）。
    func testServedPageCountUsesInstanceItemsPerPage() throws {
        let snapshot = try makeSnapshot(titles: (0..<70).map { String(format: "App%02d", $0) }, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.itemsPerPage = 20
        XCTAssertEqual(provider.servedPageCount, 4, "70 条 / 20 每页 = 4 页（非硬编码 35 的 2 页）")
    }

    /// 默认 itemsPerPage=35 行为不变：35 → 1 页、36 → 2 页。
    func testServedPageCountDefaultItemsPerPageUnchanged() throws {
        let thirtyFive = try makeSnapshot(titles: (0..<35).map { "App\($0)" }, revision: 1)
        let thirtySix = try makeSnapshot(titles: (0..<36).map { "App\($0)" }, revision: 2)
        let provider35 = AppGridUIPageContentProvider(snapshot: thirtyFive)
        XCTAssertEqual(provider35.servedPageCount, 1, "35 条默认 → 1 页")
        let provider36 = AppGridUIPageContentProvider(snapshot: thirtySix)
        XCTAssertEqual(provider36.servedPageCount, 2, "36 条默认 → 2 页")
    }
}
