//
//  AppIDIdentityTests.swift
//  AppCatalogCoreTests
//
//  §10.2：稳定身份——bundleID 主身份 / 无 ID → canonicalURL fallback / displayName 不参与；
//  redactedDescription 不含原文。
//

import XCTest
import AppCatalogCore

final class AppIDIdentityTests: XCTestCase {

    func testBundleIDIsPrimaryIdentity() {
        XCTAssertEqual(AppID.bundleIdentifier("com.example.foo"),
                       AppID.bundleIdentifier("com.example.foo"))
        XCTAssertNotEqual(AppID.bundleIdentifier("com.example.foo"),
                          AppID.bundleIdentifier("com.example.bar"))
    }

    func testNoBundleIDFallsBackToCanonicalURL() {
        let a = AppID.canonicalURLFallback(URL(fileURLWithPath: "/Applications/Notes.app"))
        let b = AppID.canonicalURLFallback(URL(fileURLWithPath: "/Applications/Notes.app"))
        XCTAssertEqual(a, b)
        // 规范化：/Applications/./Notes.app 与 /Applications/Notes.app 同一对象
        let dotted = AppID.canonicalURLFallback(URL(fileURLWithPath: "/Applications/./Notes.app"))
        XCTAssertEqual(a, dotted)
        // 不同路径 → 不同身份
        XCTAssertNotEqual(a, AppID.canonicalURLFallback(URL(fileURLWithPath: "/Applications/Mail.app")))
        // fallback 身份 ≠ bundleID 身份
        XCTAssertNotEqual(a, AppID.bundleIdentifier("com.example.Notes"))
    }

    func testDisplayNameNeverIdentity() throws {
        // 相同 displayName、不同 URL/ID → 不同 AppID
        let one = TestSupport.makeRecord("com.example.one", displayName: "Notes", url: "/Applications/Notes.app")
        let two = TestSupport.makeRecord("com.example.two", displayName: "Notes", url: "/Applications/Notes2.app")
        XCTAssertNotEqual(one.id, two.id)
        // 无 bundleID 时 displayName 也不参与：同 displayName 不同路径 → 不同 fallback 身份
        let c = TestSupport.makeRecord(nil, displayName: "Notes", url: "/Applications/Notes.app")
        let d = TestSupport.makeRecord(nil, displayName: "Notes", url: "/System/Applications/Notes.app")
        XCTAssertNotEqual(c.id, d.id)
        // 构建后同 displayName 的两条记录都保留（displayName 不参与身份 → 不互相去重）
        let snapshot = try TestSupport.snapshot([one, two])
        XCTAssertEqual(snapshot.records.count, 2)
    }

    func testRedactedDescriptionHidesBundleID() {
        let id = AppID.bundleIdentifier("com.example.secret-app-42")
        let redacted = id.redactedDescription
        XCTAssertFalse(redacted.contains("com.example.secret-app-42"), "redactedDescription 泄漏 bundleID 原文")
        XCTAssertFalse(redacted.contains("secret"))
        XCTAssertTrue(redacted.contains("redacted"))
    }

    func testRedactedDescriptionHidesCanonicalURLPath() {
        let id = AppID.canonicalURLFallback(URL(fileURLWithPath: "/Applications/SecretApp.app"))
        let redacted = id.redactedDescription
        XCTAssertFalse(redacted.contains("SecretApp"), "redactedDescription 泄漏路径原文")
        XCTAssertFalse(redacted.contains("/Applications"))
        XCTAssertTrue(redacted.contains("redacted"))
    }

    func testIconIdentityDerivedFromAppID() {
        let a = AppID.bundleIdentifier("com.example.foo")
        XCTAssertEqual(IconIdentity.from(appID: a), IconIdentity.from(appID: a))
        XCTAssertNotEqual(IconIdentity.from(appID: a),
                          IconIdentity.from(appID: AppID.bundleIdentifier("com.example.bar")))
        XCTAssertNotEqual(IconIdentity.from(appID: a),
                          IconIdentity.from(appID: AppID.canonicalURLFallback(URL(fileURLWithPath: "/Applications/foo.app"))))
    }
}
