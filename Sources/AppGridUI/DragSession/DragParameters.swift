// AppGridUI — DragSession.DragParameters（Phase 1F §3.7 / ADR-010 Q3/Q13）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 全部参数独立确定、独立测试、来源类别仅 5 类（PRODUCT_DECISION /
// PLATFORM_REQUIREMENT / ACCESSIBILITY_REQUIREMENT / INDEPENDENT_EXPERIMENT /
// PUBLIC_DOCUMENTATION）；**绝对禁止** REVERSE_ENGINEERING_COPY /
// OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN。初值均为待实验验证的产品决策
// （PARAMETER_RATIONALE 验证结果列初始 TUNING_REQUIRED，物理调参前不得写 PASS）。
// 阈值与 edge 参数独立于 1C 键盘 / 1B 分页参数：互不引用、互不调参。

import Foundation

/// drag 参数族（集中配置；D 层只读）。
public struct DragParameters: Equatable, Sendable {
    /// pressed → dragging 最小位移（pt）。PRODUCT_DECISION，初值 6 pt
    /// （与 NSClickGestureRecognizer allowableMovement 默认量级对齐属
    /// PUBLIC_DOCUMENTATION 参考，不复制任何被禁来源）。
    public var dragStartThresholdPT: Double
    /// 边缘区驻留触发一次翻页（ms）。PRODUCT_DECISION，初值 500 ms。
    public var edgeDwellDurationMs: Double
    /// 左右边缘热区宽度（pt）。PRODUCT_DECISION，初值 40 pt。
    public var edgeZoneWidthPT: Double
    /// 离开边缘须回退的距离（pt），防抖动。PRODUCT_DECISION，初值 10 pt。
    public var edgeHysteresisPT: Double
    /// 各 drop zone（insertion 带 / folder-create 区 / folder-cell 区）判定余量（pt）。
    /// PRODUCT_DECISION，初值 8 pt（T-1F-C 独立实验定）。
    public var dropZoneMarginsPT: Double
    /// move-out 模式显式 arm 位移（pt）：folder 成员拖出超过此距离才启用
    /// 顶层落点（ADR-010 Q4 M5 overlayMoveOutArmed）。PRODUCT_DECISION，初值 24 pt。
    public var overlayMoveOutArmThresholdPT: Double
    /// 翻页间最小间隔（ms），防连翻。PRODUCT_DECISION，初值 400 ms。
    public var edgeTurnMinIntervalMs: Double
    /// drag preview 最大缩放（Reduce Motion = 1.0 时禁缩放）。
    /// PLATFORM/ACCESSIBILITY 类，初值 1.0（本阶段仅参数位，视觉在 D 层）。
    public var maxDragPreviewScale: Double

    public init(dragStartThresholdPT: Double,
                edgeDwellDurationMs: Double,
                edgeZoneWidthPT: Double,
                edgeHysteresisPT: Double,
                dropZoneMarginsPT: Double,
                overlayMoveOutArmThresholdPT: Double,
                edgeTurnMinIntervalMs: Double,
                maxDragPreviewScale: Double) {
        self.dragStartThresholdPT = dragStartThresholdPT
        self.edgeDwellDurationMs = edgeDwellDurationMs
        self.edgeZoneWidthPT = edgeZoneWidthPT
        self.edgeHysteresisPT = edgeHysteresisPT
        self.dropZoneMarginsPT = dropZoneMarginsPT
        self.overlayMoveOutArmThresholdPT = overlayMoveOutArmThresholdPT
        self.edgeTurnMinIntervalMs = edgeTurnMinIntervalMs
        self.maxDragPreviewScale = maxDragPreviewScale
    }

    /// 默认参数（全部 PRODUCT_DECISION 初值，TUNING_REQUIRED）。
    public static let `default` = DragParameters(
        dragStartThresholdPT: 6,
        edgeDwellDurationMs: 500,
        edgeZoneWidthPT: 40,
        edgeHysteresisPT: 10,
        dropZoneMarginsPT: 8,
        overlayMoveOutArmThresholdPT: 24,
        edgeTurnMinIntervalMs: 400,
        maxDragPreviewScale: 1.0
    )
}
