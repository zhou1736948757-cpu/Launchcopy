//
//  TestSupport.swift
//  AppCatalogCoreTests
//
//  Phase 1B — AppCatalogCore 测试共用构造工具（§10.2；测试资源隔离：全部走临时路径，
//  不触碰真实 /Applications）。
//

import Foundation
import AppCatalogCore

enum TestSupport {
    /// bundleID 优先身份；nil → canonical URL fallback。
    static func makeRecord(_ bundleID: String?, displayName: String, url: String, root: Int = 0) -> AppRecord {
        let u = URL(fileURLWithPath: url)
        let id = bundleID.map { AppID.bundleIdentifier($0) }
            ?? AppID.canonicalURLFallback(u.standardizedFileURL)
        return CatalogFixture.record(id: id, displayName: displayName, bundleID: bundleID,
                                     url: u, icon: IconIdentity.from(appID: id), rootPriority: root)
    }

    static func snapshot(_ records: [AppRecord], revision: UInt64 = 1,
                         policy: CatalogPolicy = .init()) throws -> CatalogSnapshot {
        try CatalogFixture.snapshot(records: records, revision: CatalogRevision(revision), policy: policy)
    }
}
