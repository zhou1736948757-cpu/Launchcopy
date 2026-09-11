// AppGridUITests — ItemBindingToken（§6.4 七字段：任一字段不符 → stale 拒绝；
// 全匹配才允许 apply）

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

final class ItemBindingTokenTests: XCTestCase {

    private let page = PagePresentationID(revision: 1, pageIndex: 0)
    private let appID: AnyHashable? = AnyHashable(makeAppID("fixture.alpha"))
    private let key = IconKey(identity: IconIdentity.from(appID: makeAppID("fixture.alpha")),
                              pointSize: 32, displayScale: 2)

    private func makeToken(catalogRevision: UInt64 = 1,
                           pageIdentity: PagePresentationID? = nil,
                           itemSlot: Int = 0,
                           appID: AnyHashable? = nil,
                           reuseGeneration: UInt64 = 3,
                           iconKey: IconKey? = nil,
                           surfaceGeneration: UInt64 = 7) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: catalogRevision,
                         pageIdentity: pageIdentity ?? page,
                         itemSlot: itemSlot,
                         appID: appID ?? self.appID,
                         reuseGeneration: reuseGeneration,
                         iconKey: iconKey ?? key,
                         surfaceGeneration: surfaceGeneration)
    }

    func testAllSevenFieldsMatch() {
        let token = makeToken()
        XCTAssertTrue(token.matches(token), "同一 token 七字段全匹配")
    }

    func testRejectsStaleRevision() {
        XCTAssertFalse(makeToken().matches(makeToken(catalogRevision: 2)))
    }

    func testRejectsWrongPage() {
        XCTAssertFalse(makeToken().matches(
            makeToken(pageIdentity: PagePresentationID(revision: 1, pageIndex: 1))))
    }

    func testRejectsWrongItemSlot() {
        XCTAssertFalse(makeToken().matches(makeToken(itemSlot: 4)))
    }

    func testRejectsDifferentAppID() {
        let other: AnyHashable? = AnyHashable(makeAppID("fixture.beta"))
        XCTAssertFalse(makeToken().matches(makeToken(appID: other)))
    }

    func testRejectsNilAppID() {
        // 注意：helper 的 `appID ?? self.appID` 会把显式 nil 还原成默认值，故此处直构
        let withNilAppID = ItemBindingToken(catalogRevision: 1,
                                            pageIdentity: page,
                                            itemSlot: 0,
                                            appID: nil,
                                            reuseGeneration: 3,
                                            iconKey: key,
                                            surfaceGeneration: 7)
        XCTAssertFalse(makeToken().matches(withNilAppID))
    }

    func testRejectsStaleReuseGeneration() {
        XCTAssertFalse(makeToken().matches(makeToken(reuseGeneration: 4)))
    }

    func testRejectsDifferentIconKey() {
        let otherKey = IconKey(identity: IconIdentity.from(appID: makeAppID("fixture.beta")),
                               pointSize: 32, displayScale: 2)
        XCTAssertFalse(makeToken().matches(makeToken(iconKey: otherKey)))
    }

    func testRejectsStaleSurfaceGeneration() {
        XCTAssertFalse(makeToken().matches(makeToken(surfaceGeneration: 8)))
    }
}
