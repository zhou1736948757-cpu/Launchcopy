//
//  ScreenGeometrySnapshotTests.swift
//  PagingUITests
//
//  Phase 1G §9.7 Multi-screen geometry（10 项）：
//  single screen；negative-origin screen；vertical/horizontal arrangement；different
//  scale/resolution；pointer exactly on bounds；shared-edge/internal corner policy；
//  screen removed during dwell（快照级：validCorners 重算）；trigger screen becomes target
//  （机器级见 HotCornerStateMachineTests）；no screen ID persistence/logging；point outside
//  all screens no match。
//

import XCTest
@testable import PagingPrototypeApp

final class ScreenGeometrySnapshotTests: XCTestCase {

    private func screen(_ index: Int, x: Double, y: Double, w: Double, h: Double, scale: Double = 1.0)
        -> ScreenGeometrySnapshot.Screen {
        ScreenGeometrySnapshot.Screen(
            id: ScreenID(index: index),
            frame: LauncherRect(origin: LauncherPoint(x: x, y: y),
                                size: LauncherSize(width: w, height: h)),
            scale: scale
        )
    }

    // MARK: §9.7-1 single screen

    func testSingleScreenFourCorners() {
        let snapshot = ScreenGeometrySnapshot(screens: [screen(0, x: 0, y: 0, w: 1000, h: 800)])
        XCTAssertEqual(snapshot.validCorners.count, 4)

        let zoneSize = 20.0
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 5, y: 795), zoneSize: zoneSize)?.corner, .topLeft)
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 995, y: 795), zoneSize: zoneSize)?.corner, .topRight)
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 5, y: 5), zoneSize: zoneSize)?.corner, .bottomLeft)
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 995, y: 5), zoneSize: zoneSize)?.corner, .bottomRight)
    }

    // MARK: §9.7-2 negative-origin screen

    func testNegativeOriginScreen() {
        // frame (-1920,-1080,1920,1080)：x∈[-1920,0], y∈[-1080,0]
        let snapshot = ScreenGeometrySnapshot(screens: [screen(0, x: -1920, y: -1080, w: 1920, h: 1080)])
        let zoneSize = 20.0
        // topLeft = (minX, maxY) = (-1920, 0)：热区 x∈[-1920,-1900], y∈[-20,0]
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: -1915, y: -5), zoneSize: zoneSize)?.corner, .topLeft)
        // bottomRight = (maxX, minY) = (0, -1080)：热区 x∈[-20,0], y∈[-1080,-1060]
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: -5, y: -1075), zoneSize: zoneSize)?.corner, .bottomRight)
        XCTAssertEqual(snapshot.screen(containing: LauncherPoint(x: -1000, y: -500)), ScreenID(index: 0))
        XCTAssertNil(snapshot.screen(containing: LauncherPoint(x: 10, y: 10)), "负坐标屏外点不命中")
    }

    // MARK: §9.7-3 vertical arrangement

    func testVerticalArrangementInternalCorners() {
        // A 在下 (0,0,1000,800)，B 在上 (0,800,1000,800)
        let snapshot = ScreenGeometrySnapshot(screens: [
            screen(0, x: 0, y: 0, w: 1000, h: 800),
            screen(1, x: 0, y: 800, w: 1000, h: 800),
        ])
        // 内角（共享边）：A.topLeft/A.topRight、B.bottomLeft/B.bottomRight 不可达
        let corners = snapshot.validCorners
        XCTAssertEqual(corners.count, 4)
        XCTAssertTrue(corners.contains { $0.corner == .bottomLeft && $0.screenID == ScreenID(index: 0) })
        XCTAssertTrue(corners.contains { $0.corner == .bottomRight && $0.screenID == ScreenID(index: 0) })
        XCTAssertTrue(corners.contains { $0.corner == .topLeft && $0.screenID == ScreenID(index: 1) })
        XCTAssertTrue(corners.contains { $0.corner == .topRight && $0.screenID == ScreenID(index: 1) })
        XCTAssertFalse(corners.contains { $0.corner == .topLeft && $0.screenID == ScreenID(index: 0) })
        XCTAssertFalse(corners.contains { $0.corner == .topRight && $0.screenID == ScreenID(index: 0) })
        XCTAssertFalse(corners.contains { $0.corner == .bottomLeft && $0.screenID == ScreenID(index: 1) })
        XCTAssertFalse(corners.contains { $0.corner == .bottomRight && $0.screenID == ScreenID(index: 1) })
    }

    // MARK: §9.7-4 horizontal arrangement

    func testHorizontalArrangementInternalCorners() {
        // A 在左 (0,0,1000,800)，B 在右 (1000,0,1000,800)
        let snapshot = ScreenGeometrySnapshot(screens: [
            screen(0, x: 0, y: 0, w: 1000, h: 800),
            screen(1, x: 1000, y: 0, w: 1000, h: 800),
        ])
        let corners = snapshot.validCorners
        XCTAssertEqual(corners.count, 4)
        XCTAssertTrue(corners.contains { $0.corner == .topLeft && $0.screenID == ScreenID(index: 0) })
        XCTAssertTrue(corners.contains { $0.corner == .bottomLeft && $0.screenID == ScreenID(index: 0) })
        XCTAssertTrue(corners.contains { $0.corner == .topRight && $0.screenID == ScreenID(index: 1) })
        XCTAssertTrue(corners.contains { $0.corner == .bottomRight && $0.screenID == ScreenID(index: 1) })
        XCTAssertFalse(corners.contains { $0.corner == .topRight && $0.screenID == ScreenID(index: 0) })
        XCTAssertFalse(corners.contains { $0.corner == .bottomRight && $0.screenID == ScreenID(index: 0) })
        XCTAssertFalse(corners.contains { $0.corner == .topLeft && $0.screenID == ScreenID(index: 1) })
        XCTAssertFalse(corners.contains { $0.corner == .bottomLeft && $0.screenID == ScreenID(index: 1) })
    }

    // MARK: §9.7-5 different scale/resolution

    func testDifferentScalePreserved() {
        // B 的 frame (1000,0,2000,1200)：x∈[1000,3000], y∈[0,1200]
        let snapshot = ScreenGeometrySnapshot(screens: [
            screen(0, x: 0, y: 0, w: 1000, h: 800, scale: 1.0),
            screen(1, x: 1000, y: 0, w: 2000, h: 1200, scale: 2.0),
        ])
        XCTAssertEqual(snapshot.screens[0].scale, 1.0)
        XCTAssertEqual(snapshot.screens[1].scale, 2.0)
        // 几何判定与 scale 无关（frame 已是 pt）；B.topRight = (3000,1200) 是有效外角
        let zoneSize = 20.0
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 2995, y: 1195), zoneSize: zoneSize)?.corner, .topRight)
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 2995, y: 1195), zoneSize: zoneSize)?.screenID,
                       ScreenID(index: 1))
    }

    // MARK: §9.7-6 pointer exactly on bounds

    func testPointerExactlyOnBoundsInclusive() {
        let snapshot = ScreenGeometrySnapshot(screens: [screen(0, x: 0, y: 0, w: 1000, h: 800)])
        // 恰在 frame 边界上 → 视为在内（含边界）
        XCTAssertEqual(snapshot.screen(containing: LauncherPoint(x: 0, y: 0)), ScreenID(index: 0))
        XCTAssertEqual(snapshot.screen(containing: LauncherPoint(x: 1000, y: 800)), ScreenID(index: 0))
        // 恰在热区边界上 → 命中
        let zoneSize = 20.0
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 20, y: 780), zoneSize: zoneSize)?.corner, .topLeft)
        // 边界外一丁点 → 不命中
        XCTAssertNil(snapshot.screen(containing: LauncherPoint(x: 1000.0001, y: 800)))
        XCTAssertNil(snapshot.cornerZone(at: LauncherPoint(x: 20.0001, y: 780), zoneSize: zoneSize))
    }

    // MARK: §9.7-7 shared-edge/internal corner policy（命中侧）

    func testInternalCornerPointNotMatched() {
        // 左右排列：A.topRight 与 B.topLeft 是共享边内角 → 永不命中
        let snapshot = ScreenGeometrySnapshot(screens: [
            screen(0, x: 0, y: 0, w: 1000, h: 800),
            screen(1, x: 1000, y: 0, w: 1000, h: 800),
        ])
        let zoneSize = 20.0
        // 共享边上的点（x=1000）落在 A.topRight 与 B.topLeft 热区 → 内角规则：不命中
        XCTAssertNil(snapshot.cornerZone(at: LauncherPoint(x: 1000, y: 795), zoneSize: zoneSize))
        XCTAssertNil(snapshot.cornerZone(at: LauncherPoint(x: 1000, y: 5), zoneSize: zoneSize))
        // 外角仍正常
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 5, y: 795), zoneSize: zoneSize)?.corner, .topLeft)
        XCTAssertEqual(snapshot.cornerZone(at: LauncherPoint(x: 1995, y: 795), zoneSize: zoneSize)?.corner, .topRight)
    }

    // MARK: §9.7-8 screen removed（快照级：validCorners 重算）

    func testScreenRemovedRecomputesCorners() {
        var snapshot = ScreenGeometrySnapshot(screens: [
            screen(0, x: 0, y: 0, w: 1000, h: 800),
            screen(1, x: 1000, y: 0, w: 1000, h: 800),
        ])
        XCTAssertEqual(snapshot.validCorners.count, 4)

        // 原子替换：移除 B
        snapshot = ScreenGeometrySnapshot(screens: [snapshot.screens[0]])
        XCTAssertEqual(snapshot.validCorners.count, 4, "单屏四角全部有效")
        XCTAssertFalse(snapshot.validCorners.contains { $0.screenID == ScreenID(index: 1) })
        // 已移除屏幕的坐标不再命中
        XCTAssertNil(snapshot.cornerZone(at: LauncherPoint(x: 1995, y: 795), zoneSize: 20.0))
    }

    // MARK: §9.7-9 no screen ID persistence/logging

    func testScreenIDIsNeutralIndexOnly() {
        // ScreenID 只是序号：无 UUID/名称/序列号内容（中性，永不持久化）
        XCTAssertEqual(ScreenID(index: 1), ScreenID(index: 1))
        XCTAssertNotEqual(ScreenID(index: 1), ScreenID(index: 2))
        XCTAssertEqual(ScreenID(index: 1).hashValue, ScreenID(index: 1).hashValue)

        // 快照公开面只有 id/frame/scale（编译期保证无 name/serial 字段）
        let snapshot = ScreenGeometrySnapshot(screens: [screen(0, x: 0, y: 0, w: 1000, h: 800)])
        XCTAssertEqual(snapshot.screens[0].id, ScreenID(index: 0))
        XCTAssertEqual(snapshot.screens[0].frame.size.width, 1000)
        XCTAssertEqual(snapshot.screens[0].scale, 1.0)
    }

    // MARK: §9.7-10 point outside all screens no match

    func testPointOutsideAllScreensNoMatch() {
        // 上下排列留出间隙：A (0,0,1000,800)，B (0,900,1000,800) → 间隙 y∈(800,900)
        let snapshot = ScreenGeometrySnapshot(screens: [
            screen(0, x: 0, y: 0, w: 1000, h: 800),
            screen(1, x: 0, y: 900, w: 1000, h: 800),
        ])
        XCTAssertNil(snapshot.screen(containing: LauncherPoint(x: 500, y: 850)), "间隙中的点不属于任何屏")
        XCTAssertNil(snapshot.cornerZone(at: LauncherPoint(x: 500, y: 850), zoneSize: 20.0))
        // 屏幕外远处
        XCTAssertNil(snapshot.screen(containing: LauncherPoint(x: 5000, y: 5000)))
        XCTAssertNil(snapshot.cornerZone(at: LauncherPoint(x: 5000, y: 5000), zoneSize: 20.0))
    }

    // MARK: 附加：re-arm 区判定

    func testReArmZoneUsesHysteresisExpansion() {
        let snapshot = ScreenGeometrySnapshot(screens: [screen(0, x: 0, y: 0, w: 1000, h: 800)])
        // topLeft re-arm 区 = zone 20 + hysteresis 10 = 30pt
        XCTAssertTrue(snapshot.isInsideReArmZone(pointer: LauncherPoint(x: 25, y: 775),
                                                corner: .topLeft, screenID: ScreenID(index: 0),
                                                zoneSize: 20, hysteresis: 10))
        XCTAssertFalse(snapshot.isInsideReArmZone(pointer: LauncherPoint(x: 35, y: 765),
                                                  corner: .topLeft, screenID: ScreenID(index: 0),
                                                  zoneSize: 20, hysteresis: 10))
        // 未知 screenID → 不在 re-arm 区
        XCTAssertFalse(snapshot.isInsideReArmZone(pointer: LauncherPoint(x: 5, y: 795),
                                                  corner: .topLeft, screenID: ScreenID(index: 9),
                                                  zoneSize: 20, hysteresis: 10))
    }
}
