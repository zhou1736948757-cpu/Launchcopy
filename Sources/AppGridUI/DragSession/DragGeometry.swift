// AppGridUI — DragSession.DragGeometry（Phase 1F §3.7 / ADR-010 Q3/Q5）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯几何值类型（无 AppKit）：pointer 点、条目 frame、当前 scope 的可见条目帧与
// 顶层帧（move-out 落点用）。D 层（T-1F-D）把视图几何映射为这些中性值；
// 本层只做纯逻辑 hit-test / 分类 / 调度，绝不触碰视图。
//
// 隐私：本文件无任何输出；身份值（PersistentAppReference/FolderID）仅进程内参与
// 判定，绝不进 telemetry/日志/报告。

import Foundation

/// 拖拽指针点（纯逻辑坐标；D 层由 NSPoint 转换）。
public struct DragPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// 欧氏距离（按下阈值仲裁用）。
    public func distance(to other: DragPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// 纯逻辑矩形（条目 frame / drop zone）。
public struct DragRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }

    public func contains(_ point: DragPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    public func insetBy(dx: Double, dy: Double) -> DragRect {
        DragRect(x: x + dx, y: y + dy, width: max(0, width - 2 * dx), height: max(0, height - 2 * dy))
    }

    /// 垂直方向并集（相邻条目间 insertion 带用）。
    public func verticalUnion(with other: DragRect) -> DragRect {
        let top = min(minY, other.minY)
        let bottom = max(maxY, other.maxY)
        return DragRect(x: x, y: top, width: width, height: bottom - top)
    }
}

/// 可见条目身份（顶层 app/folder 或 folder 成员 app）。
public enum DragItemIdentity: Equatable, Sendable {
    case app(PersistentAppReference)
    case folder(FolderID)
}

/// 可见条目帧（D 层按阅读序传入；本层据此计算 drop zones）。
public struct DragItemFrame: Equatable, Sendable {
    public let identity: DragItemIdentity
    public let frame: DragRect
    /// 分页换算注记（BUG7 wave-b）：该帧所属的顶层页号（0-based）。
    /// nil = 页内下标即全局下标（page 0 / folder 成员帧 / 既有夹具构造）。
    /// 仅 D 层 makeDragGeometry 为顶层当前页帧注入；folder 成员帧绝不标注
    /// （folder 内 insertion 不乘外层 itemsPerPage 的结构性回归锁）。
    public let pageIndex: Int?
    /// 分页换算注记（BUG7 wave-b）：呈现每页条目数（与 pageIndex 成对注入）。
    public let itemsPerPage: Int?
    /// Optional expected-layout index when invisible references create displayed gaps.
    /// Nil preserves the existing page/local-index contract.
    public let logicalIndex: Int?
    /// Actual displayed app icon in the same host coordinates as `frame`.
    /// Nil retains legacy geometry-only callers; an explicit empty frame never groups.
    public let appGroupingFrame: DragRect?

    public init(identity: DragItemIdentity,
                frame: DragRect,
                pageIndex: Int? = nil,
                itemsPerPage: Int? = nil,
                logicalIndex: Int? = nil,
                appGroupingFrame: DragRect? = nil) {
        self.identity = identity
        self.frame = frame
        self.pageIndex = pageIndex
        self.itemsPerPage = itemsPerPage
        self.logicalIndex = logicalIndex
        self.appGroupingFrame = appGroupingFrame
    }

    /// 注记副本（D 层 makeDragGeometry 为顶层当前页帧标注分页换算信息；
    /// 公式 globalIndex = page * itemsPerPage + localIndex 在 intent 产出边界消费）。
    public func annotated(pageIndex: Int, itemsPerPage: Int) -> DragItemFrame {
        DragItemFrame(identity: identity, frame: frame,
                      pageIndex: pageIndex, itemsPerPage: itemsPerPage, logicalIndex: logicalIndex,
                      appGroupingFrame: appGroupingFrame)
    }

    public func mapped(toLogicalIndex index: Int) -> DragItemFrame {
        DragItemFrame(identity: identity, frame: frame, pageIndex: pageIndex,
                      itemsPerPage: itemsPerPage, logicalIndex: index, appGroupingFrame: appGroupingFrame)
    }
}

/// 一次 pointer 更新的几何上下文（D 层每帧提供）。
public struct DragGeometry: Equatable, Sendable {
    /// 当前 scope 的可见条目帧（顶层 scope = 顶层条目；folder scope = 成员）。
    public let itemFrames: [DragItemFrame]
    /// 顶层条目帧（move-out 落点 / 跨 folder 目标区用；缺省 = itemFrames）。
    public let topLevelFrames: [DragItemFrame]
    /// 容器宽度（edge zone 计算用）。
    public let containerWidth: Double
    /// 当前页（0-based）与总页数（edge first/last 边界用）。
    public let page: Int
    public let pageCount: Int
    /// 呈现每页条目数（BUG7 wave-b；0 = 未提供）。随几何下发的换算元数据；
    /// 页内→全局换算在 intent 产出边界（DropIntent.swift）执行，本字段不参与
    /// engine/resolver 消费。默认值兼容既有构造点（coordinator click 路径空
    /// geometry 与既有测试构造不在本波写范围，无法全量更新）。
    public let itemsPerPage: Int
    /// Non-nil only after the member panel has collapsed. In this presentation,
    /// the canonical source is still a folder member, but landing belongs to the
    /// visible main-grid viewport, never to hidden member rows.
    public let topLevelMoveOutBounds: DragRect?

    public init(itemFrames: [DragItemFrame],
                topLevelFrames: [DragItemFrame]? = nil,
                containerWidth: Double,
                page: Int,
                pageCount: Int,
                itemsPerPage: Int = 0,
                topLevelMoveOutBounds: DragRect? = nil) {
        self.itemFrames = itemFrames
        self.topLevelFrames = topLevelFrames ?? itemFrames
        self.containerWidth = containerWidth
        self.page = page
        self.pageCount = pageCount
        self.itemsPerPage = itemsPerPage
        self.topLevelMoveOutBounds = topLevelMoveOutBounds
    }
}
