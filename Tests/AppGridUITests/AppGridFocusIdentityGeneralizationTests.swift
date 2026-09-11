// AppGridUITests — AppGridFocusIdentityGeneralizationTests（Phase 1E 焦点身份泛化；T-1E-A）
// 实现：T-1E-A（Worker A）。
//
// 覆盖：appID 构造向后兼容、中性条目身份构造（app/folder/占位）、appID 计算属性、
// Hashable/Equatable、presentationID 派生一致性。

import XCTest
@testable import AppGridUI
import AppCatalogCore
import PagingUI

final class AppGridFocusIdentityGeneralizationTests: XCTestCase {

    func testAppIDInitBackwardCompatible() {
        let appID = makeAppID("com.example.alpha")
        let identity = AppGridFocusIdentity(catalogRevision: 3, pageIndex: 1, slotIndex: 2, appID: appID)
        XCTAssertEqual(identity.appID, appID)
        XCTAssertEqual(identity.entryIdentity, .app(appID))
        XCTAssertEqual(identity.catalogRevision, 3)
        XCTAssertEqual(identity.pageIndex, 1)
        XCTAssertEqual(identity.slotIndex, 2)
        XCTAssertEqual(identity.presentationID, PagePresentationID(revision: 3, pageIndex: 1))
    }

    func testAppIDInitNilPlaceholder() {
        let identity = AppGridFocusIdentity(catalogRevision: 3, pageIndex: 0, slotIndex: 0, appID: nil)
        XCTAssertNil(identity.appID)
        XCTAssertNil(identity.entryIdentity)
    }

    func testEntryIdentityAppInit() {
        let appID = makeAppID("com.example.alpha")
        let identity = AppGridFocusIdentity(catalogRevision: 5, pageIndex: 2, slotIndex: 0,
                                            entryIdentity: .app(appID))
        XCTAssertEqual(identity.entryIdentity, .app(appID))
        XCTAssertEqual(identity.appID, appID) // 计算属性向后兼容
    }

    func testEntryIdentityFolderInit() {
        let folderID = FolderID()
        let identity = AppGridFocusIdentity(catalogRevision: 5, pageIndex: 2, slotIndex: 0,
                                            entryIdentity: .folder(folderID))
        XCTAssertEqual(identity.entryIdentity, .folder(folderID))
        // folder 身份 → appID 为 nil（app 启动路径的 as? AppID 拒绝它）。
        XCTAssertNil(identity.appID)
    }

    func testEntryIdentityNilPlaceholder() {
        let identity = AppGridFocusIdentity(catalogRevision: 5, pageIndex: 0, slotIndex: 0,
                                            entryIdentity: nil)
        XCTAssertNil(identity.entryIdentity)
        XCTAssertNil(identity.appID)
    }

    func testEqualityAndHash() {
        let appID = makeAppID("com.example.alpha")
        let a = AppGridFocusIdentity(catalogRevision: 3, pageIndex: 1, slotIndex: 2, appID: appID)
        let b = AppGridFocusIdentity(catalogRevision: 3, pageIndex: 1, slotIndex: 2, appID: appID)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)

        let c = AppGridFocusIdentity(catalogRevision: 4, pageIndex: 1, slotIndex: 2, appID: appID)
        XCTAssertNotEqual(a, c)
    }

    func testFolderIdentityDistinctFromAppIdentity() {
        let appID = makeAppID("com.example.alpha")
        let folderID = FolderID()
        let appIdentity = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0,
                                               entryIdentity: .app(appID))
        let folderIdentity = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0,
                                                  entryIdentity: .folder(folderID))
        XCTAssertNotEqual(appIdentity, folderIdentity)
        XCTAssertNotEqual(appIdentity.appID, folderIdentity.appID)
    }
}
