// AppGridUITests — AppSearchQueryTests（Phase 1D 纯搜索域；§16.1 搜索域测试）
// 实现：T-1D-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 覆盖：空/纯空白/换行 query、trim、case/diacritic/width folding、固定 Locale 确定性。

import Foundation
import XCTest
@testable import AppGridUI

final class AppSearchQueryTests: XCTestCase {

    private let posix = Locale(identifier: "en_US_POSIX")

    // MARK: - 空 / 纯空白 / 换行 query → 无过滤

    func testEmptyQueryIsEmpty() {
        XCTAssertTrue(AppSearchQuery(raw: "", locale: posix).isEmpty)
        XCTAssertEqual(AppSearchQuery(raw: "", locale: posix).normalized, "")
    }

    func testWhitespaceOnlyQueryIsEmpty() {
        XCTAssertTrue(AppSearchQuery(raw: "   ", locale: posix).isEmpty)
        XCTAssertTrue(AppSearchQuery(raw: "\t \t", locale: posix).isEmpty)
        XCTAssertEqual(AppSearchQuery(raw: "   ", locale: posix).normalized, "")
    }

    func testNewlineQueryIsEmpty() {
        XCTAssertTrue(AppSearchQuery(raw: "\n", locale: posix).isEmpty)
        XCTAssertTrue(AppSearchQuery(raw: " \n \r\n ", locale: posix).isEmpty)
        XCTAssertEqual(AppSearchQuery(raw: "\n\n", locale: posix).normalized, "")
    }

    // MARK: - trim

    func testTrimLeadingTrailingWhitespace() {
        let q = AppSearchQuery(raw: "  Calculator  ", locale: posix)
        XCTAssertEqual(q.trimmed, "Calculator")
        XCTAssertEqual(q.normalized, "calculator")
    }

    func testTrimNewlines() {
        let q = AppSearchQuery(raw: "\nCalculator\n", locale: posix)
        XCTAssertEqual(q.trimmed, "Calculator")
    }

    // MARK: - folding

    func testCaseInsensitiveFolding() {
        XCTAssertEqual(AppSearchQuery(raw: "CALCULATOR", locale: posix).normalized, "calculator")
        XCTAssertEqual(AppSearchQuery(raw: "Calculator", locale: posix).normalized, "calculator")
    }

    func testDiacriticInsensitiveFolding() {
        XCTAssertEqual(AppSearchQuery(raw: "Café", locale: posix).normalized, "cafe")
        XCTAssertEqual(AppSearchQuery(raw: "café", locale: posix).normalized, "cafe")
    }

    func testWidthInsensitiveFolding() {
        // 全角 Ａｐｐ（U+FF21/U+FF50/U+FF50）→ 半角 app
        XCTAssertEqual(AppSearchQuery(raw: "Ａｐｐ", locale: posix).normalized, "app")
    }

    // MARK: - 固定 Locale 确定性

    func testDeterministicUnderFixedLocale() {
        let inputs = ["  Calculator  ", "Café", "Ａｐｐ", "Photoshop", "中文"]
        for input in inputs {
            let a = AppSearchQuery(raw: input, locale: posix).normalized
            let b = AppSearchQuery(raw: input, locale: posix).normalized
            XCTAssertEqual(a, b, "normalized 在固定 Locale 下应确定：\(input)")
        }
    }
}
