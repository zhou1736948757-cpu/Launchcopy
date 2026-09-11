// PagingPrototypeApp — KeyboardLaunchAdapter（Phase 1C §4.3 键盘启动适配）
// 实现：T-1C-C（Worker C）。
//
// 复用 AppLaunchController 的统一校验管线（revision → AppID → file-existence → NSWorkspace），
// 无并行启动路径。订阅 KeyboardFocusController.onActivate，把焦点身份解析为 cell 后交给
// AppLaunchController.handleCell(_:) —— 与鼠标单击共享同一校验（AC7）。
//
// 键盘路径不得直接从 cell 读 URL 后调用 NSWorkspace：本适配器只做"身份 → cell"解析，
// 启动校验与执行完全委托给 AppLaunchController（stale revision / AppID / 文件存在性 /
// 非致命失败全部由既有管线承担）。
//
// 隐私：不记录 app 名 / bundle ID / 路径 / URL / 用户输入。

import AppGridUI
import AppKit
import PagingUI

/// 键盘启动适配器：把键盘焦点身份接入 AppLaunchController 的统一启动管线。
@MainActor
public final class KeyboardLaunchAdapter {

    private let launchController: AppLaunchController
    private let cellResolver: (AppGridFocusIdentity) -> AppGridCellView?

    /// - Parameters:
    ///   - launchController: 共享启动控制器（与鼠标单击同一实例）。
    ///   - cellResolver: 焦点身份 → cell 解析器（缺省经 surface.renderer 的 AppGridRenderer 解析）。
    public init(launchController: AppLaunchController,
                cellResolver: @escaping (AppGridFocusIdentity) -> AppGridCellView?) {
        self.launchController = launchController
        self.cellResolver = cellResolver
    }

    /// 激活回调（KeyboardFocusController.onActivate 接入）：解析聚焦 cell → 复用 handleCell 校验启动。
    /// 无 cell（空 slot / 越界 / 未渲染）→ 中性 .rejectedNoBinding，不启动。
    @discardableResult
    public func activate(_ identity: AppGridFocusIdentity) -> AppLaunchOutcome {
        guard let cell = cellResolver(identity) else { return .rejectedNoBinding }
        return launchController.handleCell(cell)
    }
}
