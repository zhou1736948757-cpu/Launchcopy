//
//  ScreenGeometrySnapshot.swift
//  PagingPrototypeApp
//
//  Phase 1G 纯多屏几何值模型（T-1G-A）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.8：支持负坐标、上下/左右排列、不同
//  scale/分辨率；共享边/拼接处不可到达的"内角"有确定规则；屏幕变化原子替换并取消旧 dwell；
//  不持久化 display UUID/名称/几何（PLAN §11 隐私红线）。
//  纯 Foundation（自含 Point/Rect 值类型），无 AppKit/CoreGraphics。
//

import Foundation

/// 全局坐标点（pt；与 NSScreen frame 同坐标系：原点左下，可为负）。
public struct LauncherPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 尺寸（pt）。
public struct LauncherSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// 矩形（全局坐标）。
public struct LauncherRect: Equatable, Sendable {
    public var origin: LauncherPoint
    public var size: LauncherSize

    public init(origin: LauncherPoint, size: LauncherSize) {
        self.origin = origin
        self.size = size
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }

    /// 含边界：指针恰在边界上视为在内（§9.7 项 5）。
    public func contains(_ point: LauncherPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

/// 屏幕几何快照（值类型；生产 adapter 才接触 NSScreen，本模型纯几何）。
public struct ScreenGeometrySnapshot: Equatable, Sendable {
    public struct Screen: Equatable, Sendable {
        /// 中性序号标识（非 display UUID/名称/序列号）。
        public let id: ScreenID
        /// 全局坐标 frame（pt）。
        public let frame: LauncherRect
        /// 缩放（保留供 adapter/未来使用；纯几何判定不依赖它）。
        public let scale: Double

        public init(id: ScreenID, frame: LauncherRect, scale: Double) {
            self.id = id
            self.frame = frame
            self.scale = scale
        }
    }

    public let screens: [Screen]

    public init(screens: [Screen]) {
        self.screens = screens
    }

    // MARK: - 查询

    /// 包含该点的屏幕（确定性：列表序第一个；共享边上的点归第一个）。
    public func screen(containing point: LauncherPoint) -> ScreenID? {
        for screen in screens where screen.frame.contains(point) {
            return screen.id
        }
        return nil
    }

    /// 屏幕某角的全局坐标点。
    public func cornerPoint(corner: HotCorner, screen: Screen) -> LauncherPoint {
        switch corner {
        case .topLeft:
            return LauncherPoint(x: screen.frame.minX, y: screen.frame.maxY)
        case .topRight:
            return LauncherPoint(x: screen.frame.maxX, y: screen.frame.maxY)
        case .bottomLeft:
            return LauncherPoint(x: screen.frame.minX, y: screen.frame.minY)
        case .bottomRight:
            return LauncherPoint(x: screen.frame.maxX, y: screen.frame.minY)
        }
    }

    /// 内角规则：角点落在另一屏幕 frame 内（含边界）→ 该角不可达（internal），不是有效热角。
    /// 覆盖共享边/拼接处（含不等高/不等宽屏幕）的确定性规则。
    public func isValidOuterCorner(corner: HotCorner, screen: Screen) -> Bool {
        let point = cornerPoint(corner: corner, screen: screen)
        for other in screens where other.id != screen.id {
            if other.frame.contains(point) {
                return false
            }
        }
        return true
    }

    /// 全部有效热角（中性：corner + screenID）。
    public var validCorners: [(corner: HotCorner, screenID: ScreenID)] {
        var result: [(corner: HotCorner, screenID: ScreenID)] = []
        for screen in screens {
            for corner in HotCorner.allCases where isValidOuterCorner(corner: corner, screen: screen) {
                result.append((corner: corner, screenID: screen.id))
            }
        }
        return result
    }

    /// 点是否落在某有效热角的热区内（zoneSize = 热区边长，从角点向内延伸）。
    /// 确定性：列表序第一个命中；内角永不命中。
    public func cornerZone(at point: LauncherPoint, zoneSize: Double) -> (corner: HotCorner, screenID: ScreenID)? {
        for screen in screens {
            for corner in HotCorner.allCases where isValidOuterCorner(corner: corner, screen: screen) {
                if cornerZoneRect(corner: corner, screen: screen, zoneSize: zoneSize).contains(point) {
                    return (corner: corner, screenID: screen.id)
                }
            }
        }
        return nil
    }

    /// 热区矩形（从角点向内延伸 zoneSize）。
    public func cornerZoneRect(corner: HotCorner, screen: Screen, zoneSize: Double) -> LauncherRect {
        let frame = screen.frame
        switch corner {
        case .topLeft:
            return LauncherRect(
                origin: LauncherPoint(x: frame.minX, y: frame.maxY - zoneSize),
                size: LauncherSize(width: zoneSize, height: zoneSize)
            )
        case .topRight:
            return LauncherRect(
                origin: LauncherPoint(x: frame.maxX - zoneSize, y: frame.maxY - zoneSize),
                size: LauncherSize(width: zoneSize, height: zoneSize)
            )
        case .bottomLeft:
            return LauncherRect(
                origin: LauncherPoint(x: frame.minX, y: frame.minY),
                size: LauncherSize(width: zoneSize, height: zoneSize)
            )
        case .bottomRight:
            return LauncherRect(
                origin: LauncherPoint(x: frame.maxX - zoneSize, y: frame.minY),
                size: LauncherSize(width: zoneSize, height: zoneSize)
            )
        }
    }

    /// re-arm 判定：zoneSize + hysteresis 的扩展区（离开该区才允许再次触发）。
    public func isInsideReArmZone(
        pointer: LauncherPoint,
        corner: HotCorner,
        screenID: ScreenID,
        zoneSize: Double,
        hysteresis: Double
    ) -> Bool {
        guard let screen = screens.first(where: { $0.id == screenID }) else { return false }
        let zone = cornerZoneRect(corner: corner, screen: screen, zoneSize: zoneSize + hysteresis)
        return zone.contains(pointer)
    }
}
