// AppGridUI — DragSession.DropIntent（Phase 1F §3.3/§5.3 / ADR-010 Q4/Q5）
// 实现：T-1F-C；BUG6 wave-a 重写（T-1F-B6）。AccessDeclaration: NO_PRIOR_EXPOSURE.
// 分类输出为决策 enum（视觉在 D 层）；判定先于 commit（Q5）。BUG6（缺陷 3+4）：
// 删除 zone 表（insertion 带 / 全宽 appCenter strip / 顶层落点带——zone 表即 bug
// 本体），改为纯函数：命中查询 + 中心/半区分区意图 + 阅读行中点计数插入位；
// 任何落点都有明确 intent（无死区），顶层与 folder 内同一套规则。

import Foundation

/// drop 意图（ADR-010 Q5）。
public enum DropIntent: Equatable, Sendable {
    /// 条目间插入槽（槽位 i = 插到第 i 个条目之前；count = 末条目后）。
    /// 顶层 M1/M2、folder 内重排共用；引擎 remove-then-insert 换算（wave-a §2c）。
    case insertion(index: Int)
    /// app 条目中心内缩区 → 新建 folder（M3；目标+源为初始成员，先目标后源）。
    case createFolder(target: PersistentAppReference)
    /// folder cell 目标区 → 加入 folder（M4；含跨 folder 原子 move）。
    case intoFolder(target: FolderID, at: FolderInsertionPosition)
    /// move-out 落点（M5）：成员拖到顶层插入槽（源不在顶层序 → 无换算）。
    case topLevelTarget(index: Int)
    /// 无效（folder-on-folder / folder-on-app：不嵌套不合并，Q14）。
    case invalid
}

/// folder cell 目标区（move-into 候选；语义正确，保留）。
public struct FolderCellZone: Equatable, Sendable {
    public let folderID: FolderID
    public let rect: DragRect

    public init(folderID: FolderID, rect: DragRect) {
        self.folderID = folderID
        self.rect = rect
    }
}

/// 命中条目的局部意图分区（图标 / 中心 / 两侧三区）。
public enum DragItemHitZone: Equatable, Sendable {
    /// 中心内缩正方区（create-folder 候选）。
    case center
    /// 左半区 → 插到该条目之前。
    case leftHalf
    /// 右半区 → 插到该条目之后。
    case rightHalf
}

/// drop 几何纯函数（§2b；无状态）。
public enum DropZoneGeometry {
    /// 命中查询：指针 → 所落条目（首个包含者；nil = 未命中任何条目）。
    public static func hitItem(pointer: DragPoint,
                               frames: [DragItemFrame]) -> (index: Int, frame: DragItemFrame)? {
        for (index, frame) in frames.enumerated() where frame.frame.contains(pointer) {
            return (index, frame)
        }
        return nil
    }

    /// 中心 = 条目框内缩 margin 后的正中区（边长 = 内缩区短边 1/3，不新增参数）；
    /// 其余按左右半区分（中线归右）。
    public static func hitZone(pointer: DragPoint,
                               frame: DragRect,
                               margin: Double) -> DragItemHitZone {
        let base = frame.insetBy(dx: margin, dy: margin)
        let side = min(base.width, base.height) / 3
        if side > 0 {
            let square = DragRect(x: base.minX + (base.width - side) / 2,
                                  y: base.minY + (base.height - side) / 2,
                                  width: side, height: side)
            if square.contains(pointer) { return .center }
        }
        return pointer.x < frame.minX + frame.width / 2 ? .leftHalf : .rightHalf
    }

    /// 顶层落点可达性（M5；与旧 landing 带覆盖一致）：指针竖直位于任一顶层条目的
    /// 行带内，且不在任何顶层条目的横向内部（内缩 margin 后仅覆盖条目内部）——
    /// 缝隙 / 左右页边距可落，深入条目内部不可落（→ inner 插入）。
    /// 零尺寸帧（测试台退化输入）行带为 y=0，竖直判定仍成立。
    public static func isTopLevelLanding(pointer: DragPoint,
                                         frames: [DragItemFrame],
                                         margin: Double) -> Bool {
        guard frames.contains(where: { pointer.y >= $0.frame.minY && pointer.y <= $0.frame.maxY }) else {
            return false
        }
        return !frames.contains(where: { $0.frame.insetBy(dx: margin, dy: 0).contains(pointer) })
    }

    /// 插入位 = 指针左侧水平中点计数：指针所在阅读行内、水平中点位于指针左侧的
    /// 条目数 + 位于更早行的全部条目。命中条目时与「左半 = 命中位 / 右半 = 命中位+1」
    /// 一致，故命中/未命中共用本函数，不为缝隙/空白/边距各写 rect。
    /// 行 = 竖直区间互相重叠的连续段（坐标系无关：不假设 y 增长方向，方向由帧
    /// 自身竖直区间给出；帧按阅读序传入，行序即阅读序）。
    public static func insertionIndex(pointer: DragPoint,
                                      frames: [DragItemFrame]) -> Int {
        guard !frames.isEmpty else { return 0 }
        var rowRanges: [Range<Int>] = []
        var rowStart = 0
        while rowStart < frames.count {
            // 当前行竖直区间 = 已并入帧的 minY...maxY 并集；后续帧与区间重叠 → 同行。
            var top = frames[rowStart].frame.minY
            var bottom = frames[rowStart].frame.maxY
            var end = rowStart + 1
            // 零尺寸帧（测试台退化输入）并入当前行（区间重叠判定含边界）；
            // 真实网格行间有间隙不受影响。
            while end < frames.count,
                  frames[end].frame.minY <= bottom,
                  frames[end].frame.maxY >= top {
                top = min(top, frames[end].frame.minY)
                bottom = max(bottom, frames[end].frame.maxY)
                end += 1
            }
            rowRanges.append(rowStart..<end)
            rowStart = end
        }
        // 最近行：行带内 0 距，带外竖距，平距取先（更早行）。
        var nearest = 0
        var nearestDistance = Double.infinity
        for (row, range) in rowRanges.enumerated() {
            let band = frames[range]
            let top = band.map { $0.frame.minY }.min() ?? 0
            let bottom = band.map { $0.frame.maxY }.max() ?? 0
            let distance = pointer.y < top ? top - pointer.y
                            : (pointer.y > bottom ? pointer.y - bottom : 0)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = row
            }
        }
        let range = rowRanges[nearest]
        let inRowCount = frames[range].filter {
            $0.frame.minX + $0.frame.width / 2 < pointer.x
        }.count
        return range.lowerBound + inRowCount
    }
}

/// drop 分类输入（D 层几何 → 分类；无 zone 表）。
public struct DropZones: Equatable, Sendable {
    /// 当前 scope 的可见条目（顶层条目或 folder 成员；阅读序）。
    public var itemFrames: [DragItemFrame]
    /// 顶层条目帧（move-out 落点 / 跨 folder 目标区；缺省 = itemFrames）。
    public var topLevelFrames: [DragItemFrame]
    /// folder cell 目标区（move-into 候选）。
    public var folderCellZones: [FolderCellZone]
    /// move-out 显式 arm（M5 coordinator 状态）——仅 armed 时产出顶层落点。
    public var moveOutArmed: Bool
    /// 中心区判定余量（dropZoneMarginsPT；无新增参数）。
    public var marginPT: Double
    /// Explicit visible-main presentation; nil preserves open-folder row priority.
    public var topLevelMoveOutBounds: DragRect?

    public init(itemFrames: [DragItemFrame] = [],
                topLevelFrames: [DragItemFrame]? = nil,
                folderCellZones: [FolderCellZone] = [],
                moveOutArmed: Bool = false,
                marginPT: Double = 0,
                topLevelMoveOutBounds: DragRect? = nil) {
        self.itemFrames = itemFrames
        self.topLevelFrames = topLevelFrames ?? itemFrames
        self.folderCellZones = folderCellZones
        self.moveOutArmed = moveOutArmed
        self.marginPT = marginPT
        self.topLevelMoveOutBounds = topLevelMoveOutBounds
    }
}

/// 由条目帧构建分类输入（纯几何；阅读序相邻假设）。
public enum DropZoneBuilder {
    /// - `itemFrames`：当前 scope 的可见条目（顶层条目或 folder 成员）。
    /// - `topLevelFrames`：顶层条目帧（move-out 落点 / 跨 folder 目标区）。
    /// - `moveOutArmed`：仅 armed 时 classifier 产出顶层落点意图。
    /// - `containerWidth`：保留以维持既有调用点签名（几何已由帧现算，不需容器宽）。
    public static func zones(itemFrames: [DragItemFrame],
                             topLevelFrames: [DragItemFrame],
                             containerWidth: Double,
                             moveOutArmed: Bool,
                             parameters: DragParameters,
                             topLevelMoveOutBounds: DragRect? = nil) -> DropZones {
        let margin = parameters.dropZoneMarginsPT
        var zones = DropZones(itemFrames: itemFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: moveOutArmed, marginPT: margin,
                              topLevelMoveOutBounds: topLevelMoveOutBounds)
        for frame in itemFrames + topLevelFrames {
            if case .folder(let id) = frame.identity {
                zones.folderCellZones.append(FolderCellZone(
                    folderID: id, rect: frame.frame.insetBy(dx: margin, dy: margin)))
            }
        }
        return zones
    }
}

/// drop intent 分类（Q5；§2a 行为表：任何落点都有明确 intent，无死区）。
public enum DropZoneClassifier {
    public static func classify(pointer: DragPoint,
                                source: DragSourceIdentity,
                                zones: DropZones) -> DropIntent {
        if let bounds = zones.topLevelMoveOutBounds {
            guard zones.moveOutArmed, bounds.x.isFinite, bounds.y.isFinite,
                  bounds.maxX.isFinite, bounds.maxY.isFinite,
                  bounds.width > 0, bounds.height > 0,
                  bounds.contains(pointer) else { return .invalid }
        }
        // folder cell → move into（含跨 folder；移入自身 folder 由引擎 no-op）。
        if let cell = zones.folderCellZones.first(where: { $0.rect.contains(pointer) }) {
            if case .topLevelFolder = source { return .invalid }
            return .intoFolder(target: cell.folderID, at: .tail)
        }
        switch source {
        case .topLevelFolder:
            // Folder sources cannot merge with an app grouping target; elsewhere they reorder.
            if groupingAppIdentity(pointer: pointer, zones: zones) != nil { return .invalid }
            return insertionIntent(pointer: pointer, zones: zones)

        case .topLevelApp(let ref):
            // Another app icon groups; a self drop falls back to ordering (engine no-op).
            if let target = groupingAppIdentity(pointer: pointer, zones: zones), target != ref {
                return .createFolder(target: target)
            }
            return insertionIntent(pointer: pointer, zones: zones)

        case .folderMember:
            if zones.topLevelMoveOutBounds != nil {
                guard zones.moveOutArmed else { return .invalid }
                var visibleZones = zones
                visibleZones.itemFrames = zones.topLevelFrames
                guard case .insertion(let index) = insertionIntent(pointer: pointer, zones: visibleZones) else {
                    return .invalid
                }
                return .topLevelTarget(index: index)
            }
            // 成员无建夹语义：命中中心 → 降级半区插入（缺陷 4 修复，不再 .invalid）。
            //
            // 重要：folder overlay 与顶层网格常共用同一窗口坐标系。moveOutArmed 后若
            // 仍优先 isTopLevelLanding，则「贴着成员 / 成员缝隙 / 蓝条」也会被当成
            // 顶层落点 → moveOut → 两成员 folder 剩 1 → 解散（用户实机：贴着 APP
            // 松手 folder 解散；蓝条区无反应）。因此：**只要指针仍在成员行带内，
            // 一律内部插入**；只有离开成员行带后，才允许 move-out 顶层落点。
            if isInItemRowBand(pointer: pointer, frames: zones.itemFrames) {
                return insertionIntent(pointer: pointer, zones: zones)
            }
            if zones.moveOutArmed,
               DropZoneGeometry.isTopLevelLanding(pointer: pointer, frames: zones.topLevelFrames,
                                                  margin: zones.marginPT) {
                // BUG7 wave-b：topLevelFrames 为顶层当前页帧（带分页注记）→ 换算
                // globalIndex = page * itemsPerPage + localIndex。页号由注记显式
                // 携带（D 层注入顶层 committedPage，绝不复用 folder scope 的
                // geometry.page = innerPage）。
                return .topLevelTarget(index: globalIndex(
                    localIndex: DropZoneGeometry.insertionIndex(
                        pointer: pointer, frames: zones.topLevelFrames),
                    frames: zones.topLevelFrames))
            }
            // 已离开成员行带，又不是合法顶层缝隙/边距落点：
            // 不得回退到成员 nearest-row 插入（会把蓝条「卡」在某行某格）。
            return .invalid
        }
    }

    /// 指针是否仍在「当前 scope 条目阅读行带」内（含条目缝隙 / 蓝条锚点区）。
    /// 用于 folder 内场优先于 move-out，避免与顶层行带几何串扰。
    private static func isInItemRowBand(pointer: DragPoint, frames: [DragItemFrame]) -> Bool {
        guard !frames.isEmpty else { return false }
        return frames.contains { pointer.y >= $0.frame.minY && pointer.y <= $0.frame.maxY }
    }

    /// 分区插入意图：命中 → 左半 = 其前 / 右半（含中心降级，中线归右）= 其后；
    /// 未命中 → 阅读行「指针左侧水平中点计数」。
    /// BUG7 wave-b：顶层 scope 的 itemFrames 为顶层当前页帧（带分页注记）→
    /// 产出的页内下标在 intent 产出边界换算为全局下标
    ///（globalIndex = page * itemsPerPage + localIndex）；folder 成员帧不带注记
    /// → 页内下标即成员下标（folder 内重排不乘外层 itemsPerPage）。
    private static func insertionIntent(pointer: DragPoint, zones: DropZones) -> DropIntent {
        if let (index, frame) = DropZoneGeometry.hitItem(pointer: pointer,
                                                         frames: zones.itemFrames) {
            let part = DropZoneGeometry.hitZone(pointer: pointer, frame: frame.frame,
                                                margin: zones.marginPT)
            if let logicalIndex = frame.logicalIndex {
                // The pointer hit owns its side: "after this item" must not jump
                // across hidden successors to the next displayed item's index.
                return .insertion(index: part == .leftHalf ? logicalIndex : logicalIndex + 1)
            }
            let local = part == .leftHalf ? index : index + 1
            return .insertion(index: globalIndex(localIndex: local, frames: zones.itemFrames))
        }
        let local = DropZoneGeometry.insertionIndex(pointer: pointer, frames: zones.itemFrames)
        return .insertion(index: globalIndex(localIndex: local, frames: zones.itemFrames))
    }

    /// 页内→全局换算（BUG7 wave-b，公式已定案）：分类输入帧带分页注记时
    /// `globalIndex = page * itemsPerPage + localIndex`；未注记（page 0 / folder
    /// 成员帧）→ 页内下标即全局。换算仅在 intent 产出边界发生一次；同一帧列表
    /// 属同一页（D 层 makeDragGeometry 契约），取首帧注记为代表。
    private static func globalIndex(localIndex: Int, frames: [DragItemFrame]) -> Int {
        if localIndex >= 0, localIndex < frames.count, let index = frames[localIndex].logicalIndex {
            return index
        }
        if localIndex == frames.count, let index = frames.last?.logicalIndex { return index + 1 }
        guard let first = frames.first,
              let page = first.pageIndex,
              let itemsPerPage = first.itemsPerPage else { return localIndex }
        return page * itemsPerPage + localIndex
    }

    /// Runtime app grouping uses the displayed icon; legacy frames use the cell center.
    private static func groupingAppIdentity(pointer: DragPoint,
                                          zones: DropZones) -> PersistentAppReference? {
        guard let hit = DropZoneGeometry.hitItem(pointer: pointer, frames: zones.itemFrames),
              case .app(let ref) = hit.frame.identity else { return nil }
        if let icon = hit.frame.appGroupingFrame {
            guard icon.x.isFinite, icon.y.isFinite, icon.width.isFinite, icon.height.isFinite,
                  icon.width > 0, icon.height > 0, icon.contains(pointer) else { return nil }
            return ref
        }
        // Legacy neutral geometry has no view-provided icon target.
        guard DropZoneGeometry.hitZone(pointer: pointer, frame: hit.frame.frame,
                                      margin: zones.marginPT) == .center else { return nil }
        return ref
    }
}
