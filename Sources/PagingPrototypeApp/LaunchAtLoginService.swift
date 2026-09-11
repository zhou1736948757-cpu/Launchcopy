//
//  LaunchAtLoginService.swift
//  PagingPrototypeApp
//
//  Phase 1H T-1H-C：Launch at Login 窄协议 + Fake + SMAppService 生产适配。
//  Gate 0 D4：公开 SMAppService；默认 Off；真实机启用需单独宣布的可逆授权。
//  测试只走 Fake，永不注册真实 login item。失败文案中性，不含路径/密钥/PII。
//

import Foundation
import ServiceManagement

// MARK: - Status

/// Launch at Login 产品态（中性 enum；允许记录）。
/// `failure` 的 message 必须中性：无路径、bundle id 原文以外的敏感细节、密钥、PII。
public enum LaunchAtLoginStatus: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
    case failure(message: String)
}

// MARK: - Protocol

/// Launch at Login 窄面（生产 = SMAppService.mainApp；测试 = Fake）。
@MainActor
public protocol LaunchAtLoginServicing: AnyObject {
    /// 当前系统/内存状态映射为产品态。
    func currentStatus() -> LaunchAtLoginStatus

    /// 启用或关闭 Launch at Login。
    /// 返回操作后的真实产品态（含 requiresApproval / failure）；不抛出带秘密的底层错误。
    @discardableResult
    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus

    /// 是否会触达真实 `SMAppService` 注册。Fake 恒为 `false`；生产适配器为 `true`。
    var usesRealLoginItemRegistration: Bool { get }
}

// MARK: - Fake (tests)

/// 测试用 in-memory Launch at Login：永不调用 `SMAppService` / 不改真实 login item。
@MainActor
public final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    public private(set) var status: LaunchAtLoginStatus
    public private(set) var setEnabledCallCount = 0
    public private(set) var currentStatusCallCount = 0
    public private(set) var lastRequestedEnabled: Bool?

    /// 若非 nil，下一次 `setEnabled` 强制返回该态（成功后自动清空）。
    public var nextForcedStatus: LaunchAtLoginStatus?

    /// `setEnabled(true)` 时写入的成功态（默认 `.enabled`；可改为 `.requiresApproval`）。
    public var enableSuccessStatus: LaunchAtLoginStatus = .enabled

    public let usesRealLoginItemRegistration: Bool = false

    public init(initialStatus: LaunchAtLoginStatus = .disabled) {
        self.status = initialStatus
    }

    public func currentStatus() -> LaunchAtLoginStatus {
        currentStatusCallCount += 1
        return status
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus {
        setEnabledCallCount += 1
        lastRequestedEnabled = enabled

        if let forced = nextForcedStatus {
            nextForcedStatus = nil
            status = forced
            return status
        }

        if enabled {
            status = enableSuccessStatus
        } else {
            // 关闭：即便先前 requiresApproval / failure，Fake 也回到 disabled（可测卸载路径）。
            status = .disabled
        }
        return status
    }
}

// MARK: - Production adapter

/// 生产适配：`SMAppService.mainApp`。
///
/// **服务类型选择**：主可执行体打成标准 `.app` 后，login item 即主应用本身，
/// 对应公开 API `SMAppService.mainApp`（无需 helper / LoginItems 子 bundle）。
/// 与直接分发的 Launchcopy `.app` 部署模型一致；若未来改为 helper agent，需另开 ADR。
@MainActor
public final class SMAppServiceLaunchAtLoginService: LaunchAtLoginServicing {
    public let usesRealLoginItemRegistration: Bool = true

    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public func currentStatus() -> LaunchAtLoginStatus {
        Self.mapStatus(service.status)
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return Self.mapStatus(service.status)
        } catch {
            // 注册/注销失败后仍读一次真实 status；若已是 requiresApproval 等，优先暴露系统态。
            let mapped = Self.mapStatus(service.status)
            switch mapped {
            case .requiresApproval, .enabled, .disabled, .unavailable:
                // 系统已给出可操作态时，保留该态（truthful displayed state）。
                // 若 register 抛错但 status 仍 notRegistered，则降为中性 failure。
                if enabled, mapped == .disabled {
                    return .failure(message: Self.neutralFailureMessage(for: error, enabling: enabled))
                }
                if !enabled, mapped == .enabled {
                    return .failure(message: Self.neutralFailureMessage(for: error, enabling: enabled))
                }
                return mapped
            case .failure:
                return .failure(message: Self.neutralFailureMessage(for: error, enabling: enabled))
            }
        }
    }

    // MARK: Mapping

    static func mapStatus(_ status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    /// 中性失败文案：不嵌入 NSError userInfo / 路径 / 域名细节。
    static func neutralFailureMessage(for error: Error, enabling: Bool) -> String {
        // 仅用操作方向；不拼接 localizedDescription（可能含路径）。
        _ = error
        return enabling
            ? "Unable to enable Launch at Login."
            : "Unable to disable Launch at Login."
    }
}
