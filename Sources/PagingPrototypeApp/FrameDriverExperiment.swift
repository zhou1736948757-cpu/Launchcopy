//
//  FrameDriverExperiment.swift
//  PagingPrototypeApp
//
//  Phase 1B §8 可选帧源实验（独立文件 + 独立测试范围；--frame-driver runloop|displaylink|auto）。
//  实现：worker-integration（deepseek-v4-flash:0731, max）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
//  实验纪律（§8）：
//  - 只使用 macOS 公开 API：CADisplayLink 经 `NSScreen.displayLink(target:selector:)`
//    创建（macOS 14+；`CADisplayLink.displayLinkWithTarget:` 在 macOS 不可用，SDK 头指引
//    走 NSView/NSWindow/NSScreen 的 displayLink(withTarget:selector:)）；
//  - 经既有 PagingFrameDriving seam 替换，不改写 Core 状态机（PagingCore 零改动）；
//  - **帧源恒为 RunLoopFrameDriver**（Phase 1A 稳定 60Hz 路径，始终可用）：display link
//    在本实验中只作**观测探针**（记录真实 callback 到达与 observed interval）。这样
//    display-link 实验失败从构造上不破坏 60Hz 路径（§8「display-link 实验失败不得破坏
//    已通过的 60Hz RunLoop 路径」），也不存在冻结窗口；
//  - 探测窗口内零回调 → 停探针 + 记录 fallback reason（帧源本来就在 RunLoop 上）；
//  - 周期回调 ≠ vsync 对齐：证据只记录 observed interval，不宣称 vsync；
//  - 证据（callback count / observed interval / fallback reason）经 evidenceHandler 输出
//    （stdout + AppDelegate 保留），并如实写入 T-worker-b-integration.md；
//    telemetry 事件模型无帧源字段（PagingTelemetry 冻结，不越权新增），证据走 stdout/结果文件。
//
//  Phase 1A 真机证据（PagingFrameDriver.swift 头注）：本环境 display link 全程零回调
//  （疑似虚拟显示/无 vsync 对齐）→ 本实验预期同样零回调；如实记录，不标 PASS（§8）。

import AppKit
import Foundation
import PagingUI
import QuartzCore

// MARK: - display link 抽象（内部协议：真实 CADisplayLink + 测试 fake）

/// 可注入的 display link 提供者（真实实现 = NSScreen.displayLink；测试 = 可编程 fake）。
protocol DisplayLinkProviding: AnyObject {
    var isRunning: Bool { get }
    /// 每帧回调（参数 = 距上一帧的间隔秒；首帧为 0）。
    var onTick: ((TimeInterval) -> Void)? { get set }
    func start(on runLoop: RunLoop)
    func stop()
}

/// 真实 CADisplayLink 包装（macOS 14+ 公开 API：NSScreen.displayLink(target:selector:)）。
final class CADisplayLinkProvider: DisplayLinkProviding {

    private final class Proxy: NSObject {
        weak var provider: CADisplayLinkProvider?
        @objc func tick() {
            provider?.handleTick()
        }
    }

    private let proxy = Proxy()
    private var link: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0

    var onTick: ((TimeInterval) -> Void)?
    private(set) var isRunning = false

    init() {
        proxy.provider = self
    }

    func start(on runLoop: RunLoop) {
        guard link == nil else { return }
        // macOS 公开创建路径（SDK 头：For macOS, see NSView/NSWindow/NSScreen.
        // displayLink(withTarget:selector:)）。NSScreen.main 为 nil（无屏幕）→ 不启动，
        // 探测自然以零回调回退（证据如实记录）。
        guard let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: proxy, selector: #selector(Proxy.tick))
        lastTimestamp = 0
        link.add(to: runLoop, forMode: .common)
        self.link = link
        isRunning = true
    }

    func stop() {
        link?.invalidate()
        link = nil
        isRunning = false
    }

    private func handleTick() {
        let now = ProcessInfo.processInfo.systemUptime
        let interval: TimeInterval = lastTimestamp == 0 ? 0 : now - lastTimestamp
        lastTimestamp = now
        onTick?(interval)
    }
}

// MARK: - 观测探针式帧驱动（displaylink/auto；帧源恒为 RunLoop，display link 仅观测）

/// §8 实验帧驱动：`runloop` = Phase 1A 稳定路径（surface 默认驱动，不经本类）；
/// `displaylink` / `auto` = 本类 —— 帧源恒为 RunLoopFrameDriver，display link 只作
/// 观测探针（记录 callback 到达 + observed interval；零回调 → 记录 fallback reason）。
/// 结论如实记录：真实帧源 = RunLoopFrameDriver（非 vsync；§8「周期回调≠vsync 对齐」）。
public final class DisplayLinkFrameDriver: PagingFrameDriving {

    /// 实验状态（证据，中性）。
    public enum State: Equatable, Sendable {
        case probing
        /// display link 探针保留（observedInterval = 实测平均帧间隔，秒；≠ vsync 声明；
        /// 帧源仍为 RunLoopFrameDriver）。
        case displayLink(observedInterval: TimeInterval)
        /// 探针零回调（reason = fallback reason，证据；帧源保持 RunLoopFrameDriver）。
        case fellBackToRunLoop(reason: String)
    }

    /// 探测期收到的 display link 回调数。
    public private(set) var callbackCount = 0
    /// 当前实验状态。
    public private(set) var state: State = .probing
    /// 是否正在运行。
    public private(set) var isRunning = false
    /// 证据输出（AppDelegate 打印 + 保留；证据文本不含任何身份信息）。
    public var evidenceHandler: ((String) -> Void)?

    private let provider: any DisplayLinkProviding
    private let forceDisplayLink: Bool
    private let probeWindow: TimeInterval
    /// 真实帧源（恒在：探测期即启动 —— display link 失败不破坏 60Hz 路径）。
    private let frameSource: RunLoopFrameDriver
    private var probeTimer: Timer?
    private var lastInterval: TimeInterval = 0
    private var accumulatedInterval: TimeInterval = 0

    init(owner: PagingSurface,
         provider: (any DisplayLinkProviding)? = nil,
         forceDisplayLink: Bool = false,
         probeWindow: TimeInterval = 0.4,
         frameTimerTolerance: TimeInterval = 0,
         callbackProfiler: FrameCallbackProfileRecorder? = nil) {
        self.provider = provider ?? CADisplayLinkProvider()
        self.forceDisplayLink = forceDisplayLink
        self.probeWindow = max(probeWindow, 0.05)
        self.frameSource = RunLoopFrameDriver(
            owner: owner,
            tolerance: frameTimerTolerance,
            callbackProfiler: callbackProfiler
        )
        self.provider.onTick = { [weak self] interval in
            self?.handleTick(interval)
        }
    }

    // MARK: - PagingFrameDriving

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        // 帧源恒为 RunLoop（Phase 1A 稳定路径）；display link 仅观测。
        frameSource.start()
        switch state {
        case .probing:
            if probeTimer == nil {
                // 首次武装探测：清零计数 + 启动观察 + 排定时器。
                callbackCount = 0
                lastInterval = 0
                accumulatedInterval = 0
                provider.start(on: .main)
                scheduleProbe()
            } else {
                // 探测进行中（曾被 stop 打断）：补回观察者；不重置计数、不重复排定时器
                // —— 观察窗口固定（probeWindow，有界），证据在窗口结束如实落定。
                provider.start(on: .main)
            }
        case .displayLink:
            provider.start(on: .main)
        case .fellBackToRunLoop:
            break // 探针已停；帧源已在运行
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        frameSource.stop()
        // 探测期 stop 不清探针：display link 观察窗口固定且有界（probeWindow），
        // stop 只中断帧源（60Hz RunLoop），不中断观察 —— 否则首个动画短于窗口时
        // 证据永不落定（§8 证据完整性）。
        switch state {
        case .probing:
            break
        case .displayLink:
            provider.stop()
        case .fellBackToRunLoop:
            break
        }
    }

    // MARK: - 探测

    private func scheduleProbe() {
        let timer = Timer(timeInterval: probeWindow, repeats: false) { [weak self] _ in
            self?.evaluateProbe()
        }
        timer.tolerance = max(probeWindow / 10, 0.001)
        RunLoop.main.add(timer, forMode: .common)
        probeTimer = timer
    }

    private func evaluateProbe() {
        probeTimer = nil
        if callbackCount > 0 {
            // 首帧间隔为 0（无前帧参照）——平均只算有参照的帧间隔（callbackCount - 1）。
            let samples = max(callbackCount - 1, 1)
            let observed = accumulatedInterval / Double(samples)
            state = .displayLink(observedInterval: observed)
            let evidence = String(
                format: "display link probe retained: callbacks=%d observedInterval=%.5fs (帧源仍为 RunLoopFrameDriver；周期回调≠vsync 对齐，未声明 vsync)",
                callbackCount, observed
            )
            evidenceHandler?(evidence)
        } else {
            provider.stop()
            let reason = "zero display link callbacks within probe window (\(probeWindow)s)"
            state = .fellBackToRunLoop(reason: reason)
            let mode = forceDisplayLink ? "forced displaylink" : "auto displaylink"
            evidenceHandler?("\(mode): \(reason) → 探针停止；帧源保持 RunLoopFrameDriver（60Hz RunLoop 路径不受影响）")
        }
    }

    private func handleTick(_ interval: TimeInterval) {
        callbackCount += 1
        if lastInterval != 0 {
            accumulatedInterval += interval
        }
        lastInterval = interval
        // 不喂帧：帧源是 RunLoopFrameDriver；display link 只记录观测证据。
    }
}
