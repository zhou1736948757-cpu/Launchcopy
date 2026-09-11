// PagingUI — KeyboardPageTurner（Phase 1C §3.3/§4.2 键盘跨页窄 seam）
// 实现：T-1C-B（Worker B）。
//
// 把相邻页切换表达为经既有输入路径的合成归一化手势（handleScrollInput → ScrollInputMapper
// → PagingCore），仅当 core.state == .idle；非 idle（触控板手势/settle 进行中）→ 延迟/忽略，
// 绝不破坏进行中的手势/settle。保留中断/settle/token/stale 不变量，绝不篡改
// visualOffset/committedPage/私有状态。
//
// 隐私：不记录 app 名 / bundle ID / 路径 / URL / 图标数据 / 用户输入。

import AppKit
import PagingCore

/// 键盘跨页方向。
public enum KeyboardPageDirection: Equatable, Sendable {
    case next
    case previous
}

/// 键盘跨页结果。
public enum KeyboardPageTurnResult: Equatable, Sendable {
    /// 已表达翻页（携带目标页）。
    case turned(Int)
    /// 非 idle（触控板手势/settle 进行中）→ 延迟/忽略，不破坏进行中的手势/settle。
    case deferred
    /// 已在首/末页边界，无法再翻。
    case atBoundary
    /// surface 已 teardown → 零副作用。
    case tornDown
}

/// 窄 seam：把相邻页切换表达为合成归一化手势，经既有输入路径驱动 PagingCore。
///
/// 只做"表达一次翻页"；settle 动画由既有帧驱动（PagingSurface.frameDriver）推进，
/// 本 seam 不驱动动画、不篡改 Core 私有状态。
public struct KeyboardPageTurner {
    private weak var surface: PagingSurface?

    public init(surface: PagingSurface) {
        self.surface = surface
    }

    /// 表达一次相邻页切换。
    /// - Parameters:
    ///   - direction: 下一页 / 上一页。
    ///   - timestamp: 合成手势时间戳（与 NSEvent.timestamp 同基；测试可注入）。
    @discardableResult
    public func turn(direction: KeyboardPageDirection, timestamp: TimeInterval) -> KeyboardPageTurnResult {
        guard let surface, !surface.isTearingDown else { return .tornDown }
        // 仅 idle 才允许键盘跨页；非 idle（tracking/settling/interrupted/cancelled）→ 延迟/忽略。
        guard surface.core.state == .idle else { return .deferred }
        let current = surface.core.committedPage
        let target: Int
        switch direction {
        case .next: target = current + 1
        case .previous: target = current - 1
        }
        guard target >= 0, target < surface.core.pageCount else { return .atBoundary }
        synthesizeFling(direction: direction, on: surface, timestamp: timestamp)
        return .turned(target)
    }

    /// 合成一次"甩动"手势（began → changed → ended → finishPendingGesture），
    /// 与真实触控板 fling 走完全相同的 handleScrollInput → ScrollInputMapper → PagingCore 路径。
    /// delta 600px / 0.05s → 速度 12000px/s，远超 velocityThreshold(800)，确定性翻页。
    private func synthesizeFling(direction: KeyboardPageDirection, on surface: PagingSurface, timestamp: TimeInterval) {
        // 自然滚动下：下一页 = 手指左移（scrollingDeltaX < 0）；上一页 = 手指右移（> 0）。
        let deltaX: CGFloat = direction == .next ? -600 : 600
        let changedAt = timestamp + 0.05
        surface.handleScrollInput(phase: .began, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0,
                                  isDirectionInverted: true, timestamp: timestamp)
        surface.handleScrollInput(phase: .changed, momentumPhase: [], scrollingDeltaX: deltaX, scrollingDeltaY: 0,
                                  isDirectionInverted: true, timestamp: changedAt)
        surface.handleScrollInput(phase: .ended, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0,
                                  isDirectionInverted: true, timestamp: changedAt)
        surface.handleScrollInput(phase: [], momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0,
                                  isDirectionInverted: true, timestamp: changedAt)
    }
}
