//
//  AppParametersTests.swift
//  PagingUITests
//
//  T-worker-b-tune / -glide / -overshoot2：--momentum-decay / --momentum-glide-frames /
//  --momentum-overshoot 接线覆盖——App 层构造 PagingParameters 时必须把解析值传入
//  （缺省保持 PagingParameters 默认，不改 PagingCore 默认）。
//

import XCTest
@testable import PagingPrototypeApp

final class AppParametersTests: XCTestCase {

    func testMomentumDecayOverrideApplied() {
        let parameters = AppParameters.make(momentumDecay: 0.85, momentumGlideFrames: nil, momentumOvershoot: nil)
        XCTAssertEqual(parameters.momentumDecay, 0.85, "解析值必须覆盖 momentumDecay")
    }

    func testBoundaryValuesApplied() {
        XCTAssertEqual(AppParameters.make(momentumDecay: 0.80, momentumGlideFrames: nil, momentumOvershoot: nil).momentumDecay, 0.80)
        XCTAssertEqual(AppParameters.make(momentumDecay: 0.99, momentumGlideFrames: nil, momentumOvershoot: nil).momentumDecay, 0.99)
    }

    func testNilKeepsCoreDefault() {
        let parameters = AppParameters.make(momentumDecay: nil, momentumGlideFrames: nil, momentumOvershoot: nil)
        XCTAssertEqual(parameters.momentumDecay, 0.55, "缺省 = PagingParameters 默认（物理门固化 0.55）")
        XCTAssertEqual(parameters.momentumGlideFrames, 1, "缺省 = PagingParameters 默认 1（物理门固化：最多跟随 2 个惯性事件）")
        XCTAssertEqual(parameters.momentumMaxOvershoot, 0.20, "缺省 = PagingParameters 默认 0.20")
    }

    func testMomentumGlideFramesOverrideApplied() {
        XCTAssertEqual(AppParameters.make(momentumDecay: nil, momentumGlideFrames: 1, momentumOvershoot: nil).momentumGlideFrames, 1)
        XCTAssertEqual(AppParameters.make(momentumDecay: nil, momentumGlideFrames: 0, momentumOvershoot: nil).momentumGlideFrames, 0)
        XCTAssertEqual(AppParameters.make(momentumDecay: nil, momentumGlideFrames: 10, momentumOvershoot: nil).momentumGlideFrames, 10)
    }

    func testMomentumOvershootOverrideApplied() {
        XCTAssertEqual(AppParameters.make(momentumDecay: nil, momentumGlideFrames: nil, momentumOvershoot: 0.2).momentumMaxOvershoot, 0.2)
        XCTAssertEqual(AppParameters.make(momentumDecay: nil, momentumGlideFrames: nil, momentumOvershoot: 0.05).momentumMaxOvershoot, 0.05)
        XCTAssertEqual(AppParameters.make(momentumDecay: nil, momentumGlideFrames: nil, momentumOvershoot: 1.0).momentumMaxOvershoot, 1.0)
    }
}
