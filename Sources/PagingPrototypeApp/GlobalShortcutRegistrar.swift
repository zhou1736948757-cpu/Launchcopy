//
//  GlobalShortcutRegistrar.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-D：全局快捷键窄协议 + fake + Carbon/HIToolbox 生产适配。
//  ADR-012 Q2：公开 RegisterEventHotKey / UnregisterEventHotKey；只接收已注册组合，
//  不读一般 keyDown 流；禁止 global NSEvent monitor / CGEvent tap / Accessibility。
//  默认 Off（调用方未 register 则零注册）；冲突/失败 → configured/conflict/unavailable；
//  reconfigure 失败保留旧注册（ShortcutRegistration rollback）；key repeat 经 debounce 抑制；
//  teardown 解除注册。不记录真实快捷键文本。
//

import Carbon
import Foundation

// MARK: - Protocol

/// 全局快捷键注册窄面（生产 = Carbon；测试 = Fake）。
public protocol GlobalShortcutRegistering: AnyObject {
    /// 当前注册状态（含 rollback 语义快照）。
    var registration: ShortcutRegistration { get }

    /// 热键触发回调（中性信号；调用方映射为 coordinator toggle/show）。
    /// 不携带按键文本/修饰键描述。
    var onFired: (() -> Void)? { get set }

    /// 注册组合。已有注册时走 reconfigure 语义。
    @discardableResult
    func register(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome

    /// 注销（用户关闭 / teardown）。幂等。
    func unregister()

    /// 重配：新组合注册失败时保留旧注册（rollback）。
    @discardableResult
    func reconfigure(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome
}

// MARK: - Timing defaults

/// 快捷键触发防抖（PRODUCT_DECISION；抑制 key repeat 抖动）。
public enum GlobalShortcutTiming {
    /// 连续触发最短间隔（s）。
    public static let fireDebounce: TimeInterval = 0.25
}

// MARK: - Validation (pure)

/// 快捷键规格校验（无修饰键 → unavailable；不读系统私有偏好）。
public enum ShortcutSpecValidator {
    /// 至少需要一个修饰键（禁止裸键冒充全局快捷键）。
    public static func isRegisterable(_ spec: ShortcutSpec) -> Bool {
        !spec.modifiers.isEmpty
    }
}

// MARK: - Modifier bridge

enum CarbonShortcutModifiers {
    static func from(_ modifiers: ShortcutModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

// MARK: - Fake (tests)

/// 测试用 fake registrar：不抢占真实系统快捷键；可强制 outcome / 模拟触发。
public final class FakeGlobalShortcutRegistrar: GlobalShortcutRegistering {
    public private(set) var registration = ShortcutRegistration()
    public var onFired: (() -> Void)?

    /// 若非 nil，下一次 register/reconfigure 强制返回该 outcome（成功后自动清空）。
    public var nextForcedOutcome: ShortcutRegistrationOutcome?

    /// 视为“系统已占用”的组合（返回 .conflict）。
    public var conflictingSpecs: [ShortcutSpec] = []

    /// 触发防抖间隔（测试可缩短）。
    public var fireDebounce: TimeInterval = GlobalShortcutTiming.fireDebounce

    public private(set) var registerCallCount = 0
    public private(set) var unregisterCallCount = 0
    public private(set) var reconfigureCallCount = 0
    public private(set) var fireDeliveryCount = 0
    public private(set) var suppressedRepeatCount = 0

    private var lastFireMonotonic: TimeInterval?
    private let nowProvider: () -> TimeInterval

    public init(nowProvider: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.nowProvider = nowProvider
    }

    @discardableResult
    public func register(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome {
        registerCallCount += 1
        if registration.isConfigured {
            return reconfigure(spec)
        }
        let outcome = evaluate(spec)
        registration = registration.applying(outcome, for: spec)
        return outcome
    }

    public func unregister() {
        unregisterCallCount += 1
        registration = registration.unregistered()
        lastFireMonotonic = nil
    }

    @discardableResult
    public func reconfigure(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome {
        reconfigureCallCount += 1
        let outcome = evaluate(spec)
        // 失败时 applying 保留旧注册；成功时替换。
        registration = registration.applying(outcome, for: spec)
        return outcome
    }

    /// 模拟热键触发。`isRepeat == true` 时一律抑制（等价 key repeat）。
    public func simulateFire(isRepeat: Bool = false) {
        guard registration.isConfigured else { return }
        if isRepeat {
            suppressedRepeatCount += 1
            return
        }
        let now = nowProvider()
        if let last = lastFireMonotonic, now - last < fireDebounce {
            suppressedRepeatCount += 1
            return
        }
        lastFireMonotonic = now
        fireDeliveryCount += 1
        onFired?()
    }

    private func evaluate(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome {
        if let forced = nextForcedOutcome {
            nextForcedOutcome = nil
            return forced
        }
        guard ShortcutSpecValidator.isRegisterable(spec) else {
            return .unavailable
        }
        if conflictingSpecs.contains(spec) {
            return .conflict
        }
        return .configured
    }
}

// MARK: - Production (Carbon / HIToolbox)

/// 生产适配：公开 `RegisterEventHotKey` 路径（无需 Package.swift linkerSettings；SDK 可直接 import Carbon）。
/// 全部注册/注销须在主线程（应用 Event Target）执行。
public final class CarbonGlobalShortcutRegistrar: GlobalShortcutRegistering {
    public private(set) var registration = ShortcutRegistration()
    public var onFired: (() -> Void)?

    public var fireDebounce: TimeInterval = GlobalShortcutTiming.fireDebounce

    /// 应用签名（四字符码；中性，非用户数据）。
    private let hotKeySignature: OSType
    private let primaryHotKeyID: UInt32 = 1
    private let pendingHotKeyID: UInt32 = 2

    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var pendingHotKeyRef: EventHotKeyRef?
    private var lastFireMonotonic: TimeInterval?
    private let nowProvider: () -> TimeInterval
    private var isTornDown = false

    public init(
        signature: OSType = OSType(0x50475041), // 'PGPA'
        nowProvider: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.hotKeySignature = signature
        self.nowProvider = nowProvider
    }

    deinit {
        // Best-effort；正式 teardown 应由调用方显式 unregister。
        if let pendingHotKeyRef {
            UnregisterEventHotKey(pendingHotKeyRef)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    @discardableResult
    public func register(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome {
        precondition(Thread.isMainThread, "CarbonGlobalShortcutRegistrar requires main thread")
        guard !isTornDown else { return .unavailable }
        if registration.isConfigured {
            return reconfigure(spec)
        }
        ensureHandlerInstalled()
        let outcome = install(spec, intoPrimary: true)
        registration = registration.applying(outcome, for: spec)
        return outcome
    }

    public func unregister() {
        precondition(Thread.isMainThread, "CarbonGlobalShortcutRegistrar requires main thread")
        clearPending()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        registration = registration.unregistered()
        lastFireMonotonic = nil
    }

    @discardableResult
    public func reconfigure(_ spec: ShortcutSpec) -> ShortcutRegistrationOutcome {
        precondition(Thread.isMainThread, "CarbonGlobalShortcutRegistrar requires main thread")
        guard !isTornDown else { return .unavailable }
        ensureHandlerInstalled()

        // 先尝试以 pending ID 注册新组合；失败则保留旧注册。
        clearPending()
        let outcome = install(spec, intoPrimary: false)
        switch outcome {
        case .configured:
            // 成功：卸旧、把 pending 提升为 primary。
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
            hotKeyRef = pendingHotKeyRef
            pendingHotKeyRef = nil
            registration = ShortcutRegistration(spec: spec, outcome: .configured)
            return .configured
        case .conflict, .unavailable:
            clearPending()
            registration = registration.applying(outcome, for: spec)
            return outcome
        }
    }

    /// 显式 teardown：注销 + 移除 handler（幂等）。
    public func teardown() {
        precondition(Thread.isMainThread, "CarbonGlobalShortcutRegistrar requires main thread")
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        isTornDown = true
    }

    // MARK: Private

    private func install(_ spec: ShortcutSpec, intoPrimary: Bool) -> ShortcutRegistrationOutcome {
        guard ShortcutSpecValidator.isRegisterable(spec) else {
            return .unavailable
        }
        var ref: EventHotKeyRef?
        let id = intoPrimary ? primaryHotKeyID : pendingHotKeyID
        let status = RegisterEventHotKey(
            spec.keyCode,
            CarbonShortcutModifiers.from(spec.modifiers),
            EventHotKeyID(signature: hotKeySignature, id: id),
            GetApplicationEventTarget(),
            OptionBits(0),
            &ref
        )
        if status == noErr, let ref {
            if intoPrimary {
                hotKeyRef = ref
            } else {
                pendingHotKeyRef = ref
            }
            return .configured
        }
        // eventHotKeyExistsErr (-9878) → conflict；其余 → unavailable。
        if status == OSStatus(eventHotKeyExistsErr) {
            return .conflict
        }
        return .unavailable
    }

    private func clearPending() {
        if let pendingHotKeyRef {
            UnregisterEventHotKey(pendingHotKeyRef)
            self.pendingHotKeyRef = nil
        }
    }

    private func ensureHandlerInstalled() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            context,
            &handlerRef
        )
        if status != noErr {
            handlerRef = nil
        }
    }

    private func handleHotKeyPressed(_ event: EventRef?) {
        guard registration.isConfigured else { return }
        // 校验事件属于本 registrar 的 signature（忽略他者）。
        if let event {
            var hotKeyID = EventHotKeyID()
            let size = MemoryLayout<EventHotKeyID>.size
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                size,
                nil,
                &hotKeyID
            )
            if status == noErr, hotKeyID.signature != hotKeySignature {
                return
            }
        }

        let now = nowProvider()
        if let last = lastFireMonotonic, now - last < fireDebounce {
            return // key repeat / 抖动抑制
        }
        lastFireMonotonic = now
        onFired?()
    }

    /// C 约定事件处理（经 userData 回传实例；无捕获）。
    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let userData else { return noErr }
        let registrar = Unmanaged<CarbonGlobalShortcutRegistrar>.fromOpaque(userData).takeUnretainedValue()
        registrar.handleHotKeyPressed(event)
        return noErr
    }
}
