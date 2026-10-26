// AppGridUITests — AppGridStatusView（§3.1.11 中性 UI 状态视图；
// loading/empty/partialFailure/refreshing 状态切换 + 可访问描述 §9）

import AppKit
@testable import AppGridUI
import XCTest

@MainActor
final class AppGridStatusViewTests: XCTestCase {

    private func makeStatusView() -> AppGridStatusView {
        let view = AppGridStatusView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        return view
    }

    func testInitialStateIsLoading() async {
        let view = makeStatusView()
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.state, .loading)
        XCTAssertEqual(view.statusText, AppGridUIState.loading.accessibilityDescription)
        XCTAssertEqual(view.accessibilityLabel(), AppGridUIState.loading.accessibilityDescription)
    }

    func testStateTransitionsUpdateTextAndAccessibility() async {
        let view = makeStatusView()
        await drainDeferredPresentationTurns()
        let cases: [AppGridUIState] = [.ready, .empty, .partialFailure, .refreshing, .loading]
        for state in cases {
            view.update(state: state)
        await drainDeferredPresentationTurns()
            await drainDeferredPresentationTurns()
            XCTAssertEqual(view.state, state)
            XCTAssertEqual(view.statusText, state.accessibilityDescription)
            XCTAssertEqual(view.accessibilityLabel(), state.accessibilityDescription,
                           "§9：状态有可访问描述")
        }
    }

    func testBusyStatesShowSpinner() async {
        let view = makeStatusView()
        await drainDeferredPresentationTurns()
        // loading（初始）→ busy
        let spinner = view.subviews.compactMap { $0 as? NSProgressIndicator }.first
        XCTAssertNotNil(spinner)
        XCTAssertFalse(spinner?.isHidden ?? true, "loading 显示 spinner")

        view.update(state: .empty)
        await drainDeferredPresentationTurns()
        XCTAssertTrue(spinner?.isHidden ?? false, "空目录不显示 spinner")

        view.update(state: .refreshing)
        await drainDeferredPresentationTurns()
        XCTAssertFalse(spinner?.isHidden ?? true, "刷新中显示 spinner")

        view.update(state: .ready)
        await drainDeferredPresentationTurns()
        XCTAssertTrue(spinner?.isHidden ?? false, "ready 不显示 spinner")
    }

    func testNeutralTextContainsNoIdentity() async {
        let view = makeStatusView()
        await drainDeferredPresentationTurns()
        for state in [AppGridUIState.loading, .empty, .partialFailure, .refreshing] {
            view.update(state: state)
        await drainDeferredPresentationTurns()
            await drainDeferredPresentationTurns()
            let text = view.statusText
            XCTAssertFalse(text.contains("fixture"), "状态文本不得含测试 app 名")
            XCTAssertFalse(text.contains("/Applications"), "状态文本不得含路径")
            XCTAssertFalse(text.contains(".app"), "状态文本不得含 bundle 路径")
        }
    }
}
