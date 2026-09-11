// AppGridUI — AppGridFocusModel（Phase 1C §3.2 焦点状态模型）
// 实现：T-1C-A（Worker A）。纯逻辑，无 AppKit 依赖。
//
// 状态：当前焦点身份（或 .none 空态）。确定性初始焦点 + 迁移规则
// （successor → predecessor → clamped → empty；旧 revision 永不夺回焦点）。

import AppCatalogCore
import Foundation
import PagingUI

/// 迁移结果（镜像 `CatalogPlanner.remap` 五级降级 + 防御性 unchanged）。
public enum AppGridFocusMigration: Equatable, Sendable {
    case located(AppGridFocusIdentity)
    case successor(AppGridFocusIdentity)
    case predecessor(AppGridFocusIdentity)
    case clamped(AppGridFocusIdentity)
    case empty
    case unchanged(AppGridFocusIdentity)   // 布局 revision 不新于当前 → 保持现状（旧 revision 永不夺回）
}

/// 键盘焦点状态模型。
public struct AppGridFocusModel: Equatable, Sendable {
    public private(set) var current: AppGridFocusIdentity?
    public private(set) var lastMigration: AppGridFocusMigration?

    public init(current: AppGridFocusIdentity? = nil) {
        self.current = current
    }

    /// 确定性初始焦点：page 0 第一个有效 cell；空 catalog → nil。
    public static func initialFocus(in layout: AppGridFocusLayout) -> AppGridFocusIdentity? {
        layout.firstValidIdentity()
    }

    /// 应用新布局（新 revision）：迁移当前焦点；无当前焦点 → 确定性初始。
    @discardableResult
    public mutating func apply(layout: AppGridFocusLayout) -> AppGridFocusMigration {
        let outcome: AppGridFocusMigration
        if let current {
            outcome = layout.migrate(identity: current)
        } else if let target = AppGridFocusModel.initialFocus(in: layout) {
            outcome = .clamped(target)
        } else {
            outcome = .empty
        }
        switch outcome {
        case .located(let id), .successor(let id), .predecessor(let id),
             .clamped(let id), .unchanged(let id):
            current = id
        case .empty:
            current = nil
        }
        lastMigration = outcome
        return outcome
    }
}
