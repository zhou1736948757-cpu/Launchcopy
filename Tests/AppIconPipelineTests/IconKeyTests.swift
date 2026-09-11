// AppIconPipelineTests — IconKey（§D 冻结形状 + Explorer C 隐私约束）

import XCTest
@testable import AppIconPipeline

final class IconKeyTests: XCTestCase {
    func testPixelSizeIsPointSizeTimesScale() {
        XCTAssertEqual(makeKey(1, pointSize: 32, scale: 2).pixelSize, 64)
        XCTAssertEqual(makeKey(1, pointSize: 48, scale: 1).pixelSize, 48)
    }

    func testAppearanceDefaultsToSystem() {
        XCTAssertEqual(makeKey(1).appearance, .system)
    }

    func testEqualityAndHashing() {
        let a = makeKey(7, pointSize: 32, scale: 2)
        XCTAssertEqual(a, makeKey(7, pointSize: 32, scale: 2))
        XCTAssertEqual(a.hashValue, makeKey(7, pointSize: 32, scale: 2).hashValue)

        XCTAssertNotEqual(a, makeKey(8, pointSize: 32, scale: 2))            // identity
        XCTAssertNotEqual(a, makeKey(7, pointSize: 64, scale: 2))            // pointSize
        XCTAssertNotEqual(a, makeKey(7, pointSize: 32, scale: 3))            // scale
    }

    /// 字段形状断言：仅 identity/pointSize/displayScale/appearance ——
    /// 不含 revision、不含 bundle ID 原文、不含路径/哈希（Explorer C 约束）。
    func testKeyFieldsContainNoPrivacyOrRevisionData() {
        let labels = Mirror(reflecting: makeKey(1)).children.compactMap { $0.label }
        XCTAssertEqual(Set(labels),
                       Set(["identity", "pointSize", "displayScale", "appearance"]))
        for label in labels {
            let lower = label.lowercased()
            XCTAssertFalse(lower.contains("revision"), "\(label)")
            XCTAssertFalse(lower.contains("bundle"), "\(label)")
            XCTAssertFalse(lower.contains("path"), "\(label)")
            XCTAssertFalse(lower.contains("hash"), "\(label)")
            XCTAssertFalse(lower.contains("url"), "\(label)")
        }
        // 字符串描述不得泄露测试 bundle ID 原文
        XCTAssertFalse(String(describing: makeKey(1)).contains("icon.fixture.1"))
    }
}
