// AppGridUI — DragSession.EdgePagingScheduler（Phase 1F §3.7 / ADR-010 Q6）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// edge paging 纯 seam：edge enter/dwell/turn/leave/cancel/first-last 调度器。
// **只产事件，不碰视图**：page turn 由 D 层经已接受的外层/内层分页入口执行
// （顶层 edge turn 绝不直写 visualOffset；folder scope 只影响 inner page）。
// 每次 turn 后由 D 层以新 page 重新 hit-test + 重验 token/双 generation。

import Foundation

/// 边缘热区。
public enum EdgeZone: Equatable, Sendable {
    case left
    case right
}

/// edge paging 事件（D 层驱动翻页入口与动画）。
public enum EdgePagingEvent: Equatable, Sendable {
    case edgeEntered(EdgeZone)
    /// dwell 计时已武装（D 层按 controller.edgeDwellDeadline 调度真实 timer）。
    case dwellStarted(EdgeZone)
    /// dwell 满 → 一次 page turn（D 层调用已接受的分页入口；随后以新 page 重验）。
    case pageTurnRequested(EdgeZone)
    case edgeLeft(EdgeZone)
    /// 显式取消（ESC/teardown 等统一 cancel 路径）。
    case dwellCancelled
    /// 已在全局首页（左缘不再翻页）。
    case atFirstPage(EdgeZone)
    /// 已在全局末页（右缘不再翻页）。
    case atLastPage(EdgeZone)
}

/// 纯调度器：驻留计时、hysteresis 防抖、首尾边界、翻页最小间隔。
public struct EdgePagingScheduler: Equatable, Sendable {
    public private(set) var currentZone: EdgeZone?
    public private(set) var dwellArmed: Bool
    public private(set) var lastTurnTime: TimeInterval?

    public init() {
        dwellArmed = false
    }

    /// 每次 pointer 移动调用：进入/离开/跨区/hysteresis 判定。
    public mutating func update(pointer: DragPoint,
                                containerWidth: Double,
                                page: Int,
                                pageCount: Int,
                                now: TimeInterval,
                                parameters: DragParameters) -> [EdgePagingEvent] {
        let zone = zoneFor(pointer: pointer, containerWidth: containerWidth, parameters: parameters)

        if zone == currentZone {
            return []   // 仍在同一状态（驻留中或区外），无新事件
        }

        if let old = currentZone, zone == nil {
            // 离开边缘（hysteresis 已回退）。
            currentZone = nil
            dwellArmed = false
            return [.edgeLeft(old)]
        }

        if currentZone == nil, let new = zone {
            // 进入边缘。
            currentZone = new
            return enterEvents(zone: new, page: page, pageCount: pageCount)
        }

        // 跨区（左 → 右 / 右 → 左）：先离开旧区，再进入新区。
        if let old = currentZone, let new = zone {
            currentZone = new
            dwellArmed = false
            return [.edgeLeft(old)] + enterEvents(zone: new, page: page, pageCount: pageCount)
        }

        return []
    }

    /// dwell timer 触发（D 层按 deadline 调用；now 由注入时钟提供）。
    public mutating func dwellElapsed(now: TimeInterval,
                                      page: Int,
                                      pageCount: Int,
                                      parameters: DragParameters) -> [EdgePagingEvent] {
        guard dwellArmed, let zone = currentZone else { return [] }   // 过期 timer
        if atBoundary(zone: zone, page: page, pageCount: pageCount) {
            dwellArmed = false
            return [boundaryEvent(zone: zone)]
        }
        if let last = lastTurnTime, now - last < parameters.edgeTurnMinIntervalMs / 1000 {
            return []   // 翻页最小间隔内；controller 的 deadline 会重新武装
        }
        lastTurnTime = now
        return [.pageTurnRequested(zone)]   // dwell 保持武装，支持连续翻页
    }

    /// 显式取消（统一 cancel 路径；零残留）。
    public mutating func cancel() -> [EdgePagingEvent] {
        let wasArmed = dwellArmed
        currentZone = nil
        dwellArmed = false
        return wasArmed ? [.dwellCancelled] : []
    }

    /// 下一次 dwell timer 的 deadline（nil = 无驻留）。
    public func nextDwellDeadline(after now: TimeInterval,
                                  parameters: DragParameters) -> TimeInterval? {
        guard dwellArmed, currentZone != nil else { return nil }
        let base = now + parameters.edgeDwellDurationMs / 1000
        if let last = lastTurnTime {
            return max(base, last + parameters.edgeTurnMinIntervalMs / 1000)
        }
        return base
    }

    // MARK: - 内部

    /// hysteresis 感知的 zone 判定：进入用窄带（edgeZoneWidth），离开须回退
    /// edgeHysteresis（防边缘抖动反复翻页）。
    private func zoneFor(pointer: DragPoint,
                         containerWidth: Double,
                         parameters: DragParameters) -> EdgeZone? {
        let width = parameters.edgeZoneWidthPT
        let hysteresis = parameters.edgeHysteresisPT
        if pointer.x < width { return .left }
        if pointer.x > containerWidth - width { return .right }
        // 离开回退带（当前区内时保持）。
        if currentZone == .left, pointer.x < width + hysteresis { return .left }
        if currentZone == .right, pointer.x > containerWidth - width - hysteresis { return .right }
        return nil
    }

    private mutating func enterEvents(zone: EdgeZone, page: Int, pageCount: Int) -> [EdgePagingEvent] {
        if atBoundary(zone: zone, page: page, pageCount: pageCount) {
            return [.edgeEntered(zone), boundaryEvent(zone: zone)]   // 首尾不武装 dwell
        }
        dwellArmed = true
        return [.edgeEntered(zone), .dwellStarted(zone)]
    }

    private func atBoundary(zone: EdgeZone, page: Int, pageCount: Int) -> Bool {
        switch zone {
        case .left: return page <= 0
        case .right: return page >= pageCount - 1
        }
    }

    private func boundaryEvent(zone: EdgeZone) -> EdgePagingEvent {
        switch zone {
        case .left: return .atFirstPage(zone)
        case .right: return .atLastPage(zone)
        }
    }
}
