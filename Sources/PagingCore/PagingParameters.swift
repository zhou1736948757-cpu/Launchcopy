//
//  PagingParameters.swift
//  PagingCore
//
//  Phase 1A — 参数集中配置。
//  与 Docs/PARAMETER_RATIONALE.md 的 23 项参数一一对应（默认值/合法范围/来源类别）。
//  来源类别仅限：PRODUCT_DECISION / PLATFORM_REQUIREMENT / ACCESSIBILITY_REQUIREMENT /
//  INDEPENDENT_EXPERIMENT / PUBLIC_DOCUMENTATION。
//  禁止：REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN。
//  数值为初始建议；标 TUNING_REQUIRED 的参数需经 Step 6 实验或物理门后回填验证结果。
//

import Foundation

/// Reduce Motion 变化处理方式（PARAMETER_RATIONALE §2）。
public enum ReduceMotionChangeHandling: String, Sendable, Equatable {
    /// 运行时响应系统通知（accessibilityDisplayOptionsDidChangeNotification），非启动时读一次。
    case dynamic
    /// 仅启动时读取（不使用；保留为参数表完整性）。
    case startupOnly
}

/// 自然滚动方向（PARAMETER_RATIONALE §3）。
public enum NaturalScrollDirection: String, Sendable, Equatable {
    /// 遵循系统自然滚动方向，不硬编码。
    case system
}

/// 手势 phase 处理模式（PARAMETER_RATIONALE §3；ADR-001 D5）。
public enum GesturePhaseHandling: String, Sendable, Equatable {
    /// 处理完整 phase 序列（began/changed/ended/cancelled/momentum）+ 异常序列防御。
    case full
}

/// 交互/无障碍/平台/性能目标参数的集中配置结构（PHASE1_SPEC §7）。
public struct PagingParameters: Equatable, Sendable {

    // MARK: - §1 交互参数（Interaction）

    /// 触控板位移 → 页面位移映射比例（1:1 自然跟随）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.5–2.0。
    public var inputSensitivity: Double = 1.0

    /// 边界外位移阻尼系数（实际越界位移 = 原始越界 × 该系数）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.1–0.6。
    public var boundaryResistance: Double = 0.35

    /// 释放时翻页的位移阈值（页宽比例）。位移超过 pageWidth × 阈值 → 翻页，否则回弹。
    /// 来源：PRODUCT_DECISION；第 10 轮用户决策——全屏（1470pt 宽）为调参基准（窗口 1000pt
    /// 只是测试形态，1.47× 页宽差导致页比例类参数在全屏下更"沉"）；0.5 → 0.48；
    /// 第 12 轮用户决策：0.48 → 0.46（"改成前进0.46，回退0.4"）；
    /// 第 13 轮（Phase 1B 物理调参）用户决策：0.46 → 0.45（"把前进改成45，回退改成38"）；
    /// 第 14 轮（Phase 1B 物理调参）用户决策：0.45 → 0.43（phys1b-03 实测后"前进改成0.43，回退改成0.36"）；
    /// 第 15 轮（Phase 1B 物理调参）用户决策：0.43 → 0.42（"前进阈值改成0.42，回退系数改成0.35"）。
    /// TUNING_REQUIRED；合法范围 0.25–0.75。
    public var displacementThreshold: Double = 0.42

    /// 回退方向（direction == -1，手指右滑/上一页）位移阈值系数：回退判定阈值 =
    /// displacementThreshold × 本系数（35/42 ≈ 0.833333 → 0.42×35/42 = 0.35 页精确；
    /// 第 15 轮（Phase 1B 物理调参）全屏基准下用户目标：前进 0.42、回退 0.35——补偿生理不对称，
    /// 往回滑行程天然短）。
    /// 前进方向保持原阈值；速度强制路径（absVelocity >= velocityThreshold）不受影响。
    /// 来源：PRODUCT_DECISION；物理调参中；合法范围 0.7–1.0。
    public var retreatDisplacementFactor: Double = 35.0 / 42.0

    /// 速度对翻页决策的权重（0 = 纯位移，1 = 纯速度）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.0–0.5。
    public var velocityContribution: Double = 0.3

    /// 超过此速度强制翻页（px/s；方向由符号决定）。
    /// 第 16 轮（2026-08-30）用户决策：强制翻页速度门槛 800 → 700
    /// （"滑了没翻页被回弹太频繁，降低强制翻页速度门槛"）。
    /// 来源：INDEPENDENT_EXPERIMENT；TUNING_REQUIRED；合法范围 200–2000。
    public var velocityThreshold: Double = 700

    /// overscroll 最大距离（页宽比例），防视觉断裂。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.0–0.5。
    public var maximumOverscroll: Double = 0.25

    /// settle 动画时长（秒）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.15–0.4。
    public var settleDuration: TimeInterval = 0.250

    /// settle spring 阻尼比（0.85 近临界：轻微弹动不振荡）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.7–0.95。
    public var settleSpringDamping: Double = 0.85

    /// momentum 每帧速度衰减系数（惯性滑行模拟用）。
    /// 来源：INDEPENDENT_EXPERIMENT；物理门固化（第 2 轮用户决策）：0.95 → 0.55——
    /// N=1 截断下 glide 段极短，衰减保持一致（滑行模拟仍由 Core tick 驱动）。
    /// 合法范围 0.8–0.99（固化值 0.55 为物理门调参结果，超出原标注范围，注释同步）。
    public var momentumDecay: Double = 0.55

    /// momentum 系统流截断（T-worker-b-glide；真实触控板松手后系统仍发大量 momentum 事件，
    /// Core 跟随整个系统流 = 用户感知的"滑行太长"主因；本参数截断该跟随）：
    /// - nil：跟随完整系统 momentum 流（显式传 nil 保留此语义）；
    /// - 0：momentum 一开始即释放决策（=RM 降级效果：不做惯性滑行，直接回弹/翻页/吸住）；
    /// - N（1–10）：最多跟随 2N 个 momentumChanged 事件后释放决策（1 帧 ≈ 2 事件 @~120Hz）。
    /// 默认 **1**（物理门固化，第 11 轮用户决策："手往左滑一下，然后它要惯性滑好久才会停"——
    /// 松手后最多跟 2 个惯性事件 → 立即决策 → settle 吸住；settle 动画保持）。
    /// 截断点决策复用 momentumEnded 决策路径（当前速度，无跳变）；截断后系统后续 momentum
    /// 事件按 D3/D5 防御拒绝，commit 至多 1 次。
    /// 来源：PRODUCT_DECISION；物理门固化；RM 下强制 0（D8 既有降级不变，参数不生效）。
    public var momentumGlideFrames: Int? = 1

    /// momentum 跟随阶段过冲软阻尼（T-worker-b-overshoot/-softdamp；系统惯性事件 delta 大，
    /// offset 会被推远超"一页一翻"决策目标 → settle 长距离拉回 = "飞越再拉回"视觉；原硬钳制
    /// 顶死 offset 产生静止帧"顿一下再吸"，第 7 轮改软阻尼）：
    /// momentum 阶段展示 offset 越过 `committedPage + 1 + momentumMaxOvershoot`（正向）/
    /// `committedPage - 1 - momentumMaxOvershoot`（负向，T-worker-b-symdamp 对称化：
    /// 阻尼线 = 目标页 ± overshoot）后，越限部分按 0.2 透传（每事件仍前进，
    /// 无静止帧；峰值 = 上限 + 0.2×越界峰值）；边界页由既有 overscroll 阻尼（applyingBoundary）
    /// 约束，本软阻尼不介入。只限展示 offset：速度估算基于样本真实 delta/dt（recordDelta），
    /// 不受影响 → 截断点翻页判定仍以真实事件速度为据。
    /// 来源：PRODUCT_DECISION；物理调参中；默认 0.20（页；第 6 轮用户定"最多冲到第二页加 1/5 页"）。
    public var momentumMaxOvershoot: Double = 0.20

    /// 常驻 live view 半径（当前页 ± radius）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0–2（UI 层消费）。
    public var livePageRadius: Int = 1

    /// 距目标 prewarmDistance 页时预热相邻页 view（UI 层消费）。
    /// 来源：PRODUCT_DECISION；TUNING_REQUIRED；合法范围 0.5–3.0。
    public var prewarmDistance: Double = 1.5

    // MARK: - §2 无障碍参数（Accessibility）

    /// 必须响应系统 Reduce Motion（PHASE1_SPEC §3.J；ADR-001 D8）。
    /// 来源：ACCESSIBILITY_REQUIREMENT。
    public var respectSystemReduceMotion: Bool = true

    /// RM 下 settle 时长；0 = 即刻跳转；状态机逻辑不变（ADR-001 D8）。
    /// 来源：ACCESSIBILITY_REQUIREMENT；合法范围 0–0.05。
    public var settleDurationReduceMotion: TimeInterval = 0.0

    /// RM 下最大 overscroll；0 = 无回弹。
    /// 来源：ACCESSIBILITY_REQUIREMENT；合法范围 0.0–0.1。
    public var reduceMotionOverscroll: Double = 0.0

    /// RM 变化处理：运行时动态响应。
    /// 来源：PLATFORM_REQUIREMENT。
    public var reduceMotionChangeHandling: ReduceMotionChangeHandling = .dynamic

    // MARK: - §3 平台参数（Platform）

    /// 遵循系统自然滚动方向。
    /// 来源：PLATFORM_REQUIREMENT。
    public var naturalScrollDirection: NaturalScrollDirection = .system

    /// 完整 phase 序列 + 异常序列防御（ADR-001 D5）。
    /// 来源：PLATFORM_REQUIREMENT。
    public var gesturePhaseHandling: GesturePhaseHandling = .full

    /// teardown 必须停 CVDisplayLink（Apple API 语义；ADR-001 D7，UI 层消费）。
    /// 来源：PLATFORM_REQUIREMENT。
    public var displayLinkStopOnTeardown: Bool = true

    /// 中断必须移除/停掉旧动画（ADR-001 D4，UI 层消费）。
    /// 来源：PLATFORM_REQUIREMENT。
    public var animationRemovalOnInterrupt: Bool = true

    // MARK: - §4 性能目标参数（PHASE1_SPEC §8.5 初始目标，非平台保证）

    /// 60Hz frame miss 比例目标。
    /// 来源：PRODUCT_DECISION；合法范围 0–5%。
    public var frameMissTarget60Hz: Double = 0.01

    /// 120Hz frame miss 比例目标（须先证明刷新率）。
    /// 来源：PRODUCT_DECISION；合法范围 0–5%。
    public var frameMissTarget120Hz: Double = 0.02

    /// 60Hz 不可解释 hitch 阈值（秒）。
    /// 来源：PRODUCT_DECISION。
    public var hitchThreshold60Hz: TimeInterval = 0.050

    /// 120Hz 不可解释 hitch 阈值（秒）。
    /// 来源：PRODUCT_DECISION。
    public var hitchThreshold120Hz: TimeInterval = 0.033

    public init() {}

    /// RM 生效时的实际 overscroll 上限（页宽比例）。
    public func effectiveMaximumOverscroll(reduceMotion: Bool) -> Double {
        reduceMotion ? min(reduceMotionOverscroll, maximumOverscroll) : maximumOverscroll
    }

    /// RM 生效时的实际 settle 时长（秒）。
    public func effectiveSettleDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? settleDurationReduceMotion : settleDuration
    }
}
