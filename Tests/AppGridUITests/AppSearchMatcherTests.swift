// AppGridUITests — AppSearchMatcherTests（Phase 1D 纯搜索域；§16.1 搜索域测试）
// 实现：T-1D-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 覆盖：空/纯空白/换行 query 全目录、case/diacritic/width、substring、不匹配
// bundleID/path/URL/AppID、无拼音/首字母/模糊扩展、结果顺序 = base 子序列、固定 Locale 确定性。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class AppSearchMatcherTests: XCTestCase {

    private let posix = Locale(identifier: "en_US_POSIX")
    private let matcher = AppSearchMatcher()

    // MARK: - 记录工厂（displayName / bundleID / URL 可独立控制）

    private func record(displayName: String, bundleID: String? = nil,
                        urlPath: String = "/Applications/Placeholder.app") -> AppRecord {
        let id = bundleID.map { AppID.bundleIdentifier($0) }
            ?? AppID.canonicalURLFallback(URL(fileURLWithPath: urlPath))
        return CatalogFixture.record(id: id, displayName: displayName, bundleID: bundleID,
                                     url: URL(fileURLWithPath: urlPath),
                                     icon: IconIdentity.from(appID: id), rootPriority: 0)
    }

    // MARK: - 空 / 纯空白 / 换行 query → 全目录

    func testEmptyQueryMatchesAll() {
        let records = [record(displayName: "Alpha"), record(displayName: "Beta")]
        for r in records {
            XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "", locale: posix)))
        }
    }

    func testWhitespaceQueryMatchesAll() {
        let r = record(displayName: "Alpha")
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "   ", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "\t \t", locale: posix)))
    }

    func testNewlineQueryMatchesAll() {
        let r = record(displayName: "Alpha")
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "\n", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: " \n \r\n ", locale: posix)))
    }

    // MARK: - 大小写 / 变音 / 宽度 / 子串

    func testCaseInsensitiveMatch() {
        let r = record(displayName: "Calculator")
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "calculator", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "CALCULATOR", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "Calc", locale: posix)))
    }

    func testDiacriticInsensitiveMatch() {
        let r = record(displayName: "Café")
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "cafe", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "Café", locale: posix)))
    }

    func testWidthInsensitiveMatch() {
        // 全角 displayName Ａｐｐ（U+FF21…）应命中半角 query "app"
        let r = record(displayName: "Ａｐｐ")
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "app", locale: posix)))
        // 半角 displayName 命中全角 query
        let r2 = record(displayName: "App")
        XCTAssertTrue(matcher.matches(r2, query: AppSearchQuery(raw: "Ａｐｐ", locale: posix)))
    }

    func testSubstringMatch() {
        let r = record(displayName: "Photoshop")
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "hotos", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "shop", locale: posix)))
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "hotdog", locale: posix)))
    }

    // MARK: - 不匹配 bundleID / path / URL / AppID

    func testNotMatchingBundleID() {
        let r = record(displayName: "Calculator", bundleID: "com.example.calculator")
        // query 只与 displayName 比较；bundleID 命中不产生匹配
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "com.example", locale: posix)))
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "com.example.calculator", locale: posix)))
        // displayName 命中仍匹配
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "calculator", locale: posix)))
    }

    func testNotMatchingPathURL() {
        let r = record(displayName: "Calculator", urlPath: "/Applications/Calculator.app")
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "/Applications", locale: posix)))
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "Calculator.app", locale: posix)))
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "calculator", locale: posix)))
    }

    func testNotMatchingAppID() {
        // AppID 由 bundleID 派生；query 命中 AppID 原文也不匹配（只读 displayName）
        let r = record(displayName: "Calculator", bundleID: "com.example.calculator")
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "com.example.calculator", locale: posix)))
    }

    // MARK: - 无拼音 / 首字母 / 模糊（编辑距离）扩展

    func testNoPinyinExpansion() {
        let r = record(displayName: "中文")
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "zhongwen", locale: posix)))
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "zhong", locale: posix)))
        // 字面子串仍匹配
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "中文", locale: posix)))
    }

    func testNoInitialExpansion() {
        // 首字母扩展：query "ps" 不应命中 "Photoshop"（"ps" 非字面子串）
        let r = record(displayName: "Photoshop")
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "ps", locale: posix)))
        // 字面子串命中
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "ph", locale: posix)))
    }

    func testNoFuzzyEditDistance() {
        let r = record(displayName: "Calculator")
        // 编辑距离/拼写纠错：typo 非字面子串 → 不匹配
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "Calclator", locale: posix)))
        XCTAssertFalse(matcher.matches(r, query: AppSearchQuery(raw: "Calculater", locale: posix)))
        // 字面子串仍匹配
        XCTAssertTrue(matcher.matches(r, query: AppSearchQuery(raw: "Calc", locale: posix)))
    }

    // MARK: - 结果顺序 = base snapshot 子序列

    func testResultOrderIsBaseSubsequence() {
        let snapshot = try! makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"],
                                         revision: 1)
        let query = AppSearchQuery(raw: "a", locale: posix)
        // 期望 = 对 base 快照做 filter（filter 保持顺序）→ 结果必须是 base 的稳定子序列
        let expected = snapshot.records.filter { matcher.matches($0, query: query) }
        let matched = snapshot.records.filter { matcher.matches($0, query: query) }
        XCTAssertEqual(matched.map(\.id), expected.map(\.id))
        // 相对顺序 = base 顺序：matched 中相邻项的 base 索引严格递增
        let baseIndex = Dictionary(uniqueKeysWithValues: snapshot.records.enumerated().map { ($0.element.id, $0.offset) })
        let matchedIndices = matched.map { baseIndex[$0.id]! }
        XCTAssertEqual(matchedIndices, matchedIndices.sorted())
        XCTAssertEqual(Set(matchedIndices).count, matchedIndices.count)
    }

    // MARK: - 固定 Locale 确定性

    func testDeterministicUnderFixedLocale() {
        let snapshot = try! makeSnapshot(titles: ["Café", "Calculator", "Photoshop", "中文", "Ａｐｐ"],
                                         revision: 1)
        let query = AppSearchQuery(raw: "c", locale: posix)
        let first = snapshot.records.filter { matcher.matches($0, query: query) }.map(\.id)
        let second = snapshot.records.filter { matcher.matches($0, query: query) }.map(\.id)
        XCTAssertEqual(first, second)
    }
}
