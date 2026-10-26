// AppGridUITests — AppGridCellFocusReuseTests（Reviewer F2 MINOR：复用路径焦点视觉重置）
//
// 覆盖：聚焦 cell 被 clearContent / clearForReuse 回收后，焦点视觉
// （layer border/background + accessibility focus）被重置，不残留到下一个 app
// （Prompt §4.3：焦点视觉不能因 cell 复用残留在错误的 app 上）。
// 键盘路径（显式 unhighlight）不回归：clearContent 只清焦点视觉，不改焦点模型/导航。
//
// 全部 @MainActor：视图主线程受限；fake loader（GatedIconLoader）；程序生成图像；
// 绝不触碰真实 /Applications。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class AppGridCellFocusReuseTests: XCTestCase {

    // MARK: - clearContent 重置焦点视觉

    func testClearContentResetsFocusVisual() {
        let cell = AppGridCellView()
        XCTAssertFalse(cell.isFocused, "初始无焦点视觉")

        cell.setFocused(true)
        XCTAssertTrue(cell.isFocused, "setFocused(true) 应设置焦点视觉（layer border）")
        XCTAssertEqual(cell.layer?.backgroundColor, NSColor.selectedControlColor.cgColor,
                       "setFocused(true) 应设置选中背景")

        cell.clearContent()
        XCTAssertFalse(cell.isFocused, "clearContent 后不得残留焦点视觉（layer border）")
        XCTAssertNil(cell.layer?.backgroundColor,
                     "Clearing focus restores the transparent idle backdrop, not an opaque tile")
        // accessibility focus 由 setFocused(false) 内的 setAccessibilityFocused(false) 清空
        // （AppGridCellFocus.swift；NSView 无 Swift 可见的 accessibilityFocused() getter，故以视觉状态断言）
    }

    // MARK: - clearForReuse 路径无残留焦点视觉

    func testClearForReuseResetsFocusedCell() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        defer { pipeline.shutdown() }

        let alphaID = makeAppID("fixture.alpha")
        let betaID = makeAppID("fixture.beta")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha", "Beta"],
                                         appIDs: [alphaID, betaID]),
                    pageCount: 2, reuseGeneration: 1)

        let cell = try XCTUnwrap(page.cell(at: 0))
        cell.setFocused(true)
        XCTAssertTrue(cell.isFocused, "聚焦 cell 应处于焦点视觉状态")

        // 非键盘页面切换（trackpad fling / refresh）→ clearForReuse 回收
        page.clearForReuse()
        XCTAssertFalse(cell.isFocused, "clearForReuse 后聚焦 cell 不得残留焦点视觉")
        XCTAssertNil(cell.layer?.backgroundColor,
                     "Recycling restores the transparent idle backdrop without residual focus fill")
    }

    // MARK: - 复用后新内容不继承旧焦点视觉

    func testReuseThenRebindHasNoResidualFocus() async throws {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        defer { pipeline.shutdown() }

        let alphaID = makeAppID("fixture.alpha")
        let gammaID = makeAppID("fixture.gamma")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"],
                                         appIDs: [alphaID]),
                    pageCount: 2, reuseGeneration: 1)
        let cell = try XCTUnwrap(page.cell(at: 0))
        cell.setFocused(true)
        XCTAssertTrue(cell.isFocused)

        // 复用：clear → 新内容（不同 app）
        page.clearForReuse()
        page.render(pageIndex: 1,
                    content: makeContent(revision: 1, page: 1, titles: ["Gamma"],
                                         appIDs: [gammaID]),
                    pageCount: 2, reuseGeneration: 2)

        XCTAssertEqual(page.cell(at: 0)?.nameLabel.stringValue, "Gamma")
        XCTAssertFalse(cell.isFocused, "复用后绑定新 app 的 cell 不得残留旧焦点视觉")
        XCTAssertNil(cell.layer?.backgroundColor,
                     "Rebinding keeps the new transparent idle backdrop without old focus fill")
    }
}
