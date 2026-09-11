//
//  PagingTelemetryBridge.swift
//  PagingPrototypeApp
//
//  telemetry 接线（T-worker-d 最终接线责任）：
//  - Core events（transition.begin/commit/stale_rejected/interruption.began/state.changed）
//  - PagingSurface hooks（gesture.* / layout / page.prepare|reuse / frame / resize）
//  - teardown 完成后写 teardown.complete；teardownCallbackCount 恒为 0（D7：teardown 后零回调）
//
//  PagingUI 不依赖 PagingTelemetry：本桥接层位于 App 层，职责单一。
//

import AppGridUI
import AppIconPipeline
import Foundation
import PagingCore
import PagingTelemetry
import PagingUI

/// PagingSurface ↔ TelemetrySession 接线。
public final class PagingTelemetryBridge {

    public private(set) var session: TelemetrySession
    private weak var surface: PagingSurface?

    public init(surface: PagingSurface, session: TelemetrySession) {
        self.surface = surface
        self.session = session
        wire()
    }

    private func wire() {
        guard let surface else { return }

        var appEvents = PagingCoreEvents()

        appEvents.onStateChange = { [weak self] state in
            guard let self else { return }
            var event = TelemetryEvent(phase: TelemetryPhase.stateChanged)
            event.semanticCurrentPage = state == .settling
                ? (surface.core.activeTransition?.targetPage ?? -1)
                : surface.core.committedPage
            event.visualOffset = surface.core.visualOffset
            self.session.record(event)
        }

        appEvents.onTransitionBegin = { [weak self] context in
            guard let self else { return }
            var event = TelemetryEvent(phase: TelemetryPhase.transitionBegin)
            event.transitionID = context.token
            event.transitionToken = context.token
            event.proposedTarget = context.targetPage
            event.visualOffset = context.fromOffset
            self.session.record(event)
        }

        appEvents.onCommit = { [weak self] context in
            guard let self else { return }
            var event = TelemetryEvent(phase: TelemetryPhase.transitionCommit)
            event.transitionID = context.token
            event.transitionToken = context.token
            event.committedPage = context.targetPage
            self.session.record(event)
        }

        appEvents.onStaleRejection = { [weak self] token in
            guard let self else { return }
            self.session.registerStaleRejection()
            var event = TelemetryEvent(phase: TelemetryPhase.transitionStaleRejected)
            event.transitionToken = token
            self.session.record(event)
        }

        appEvents.onInterruption = { [weak self] info in
            guard let self else { return }
            self.session.registerInterruption()
            var event = TelemetryEvent(phase: TelemetryPhase.interruptionBegan)
            event.transitionToken = info.abandonedToken
            event.proposedTarget = info.abandonedTargetPage ?? -1
            event.interruptSourceOffset = info.takeoverOffset
            self.session.record(event)
        }

        surface.appEvents = appEvents

        surface.onGestureEvent = { [weak self] phase, delta, gestureID, offset in
            guard let self, let surface = self.surface else { return }
            var event = TelemetryEvent(phase: Self.telemetryPhase(for: phase))
            event.gestureID = gestureID
            event.inputDelta = surface.core.pageWidth > 0 ? delta / surface.core.pageWidth : 0
            event.visualOffset = offset
            self.session.record(event)
        }

        surface.onLayoutPerformed = { [weak self] hostCount in
            guard let self else { return }
            self.session.registerLayout()
            var event = TelemetryEvent(phase: TelemetryPhase.layout)
            event.pageHostViewCount = hostCount
            self.session.record(event)
        }

        surface.onPagePrepared = { [weak self] index, reused in
            guard let self else { return }
            if reused {
                // Phase 1B：cell/host 复用会话累计（盖章到后续事件 cell_reuse_count）。
                self.session.registerCellReuse()
            }
            var event = TelemetryEvent(phase: reused ? TelemetryPhase.pageReuse : TelemetryPhase.pagePrepare)
            event.semanticCurrentPage = index
            event.pagePrepareCache = reused ? .hit : .miss
            self.session.record(event)
        }

        surface.onAnimationFrame = { [weak self] interval in
            guard let self else { return }
            var event = TelemetryEvent(phase: TelemetryPhase.frame)
            event.frameInterval = interval
            self.session.record(event)
        }

        surface.onResize = { [weak self] in
            guard let self else { return }
            let event = TelemetryEvent(phase: TelemetryPhase.resize)
            self.session.record(event)
        }

        surface.onTeardown = { [weak self] in
            guard let self else { return }
            var event = TelemetryEvent(phase: TelemetryPhase.teardownComplete)
            event.visualOffset = self.surface?.core.visualOffset ?? 0
            self.session.record(event)
            self.session.end()
        }
    }

    /// GesturePhase → telemetry 阶段名。
    public static func telemetryPhase(for phase: GesturePhase) -> String {
        switch phase {
        case .began: return TelemetryPhase.gestureBegan
        case .changed: return TelemetryPhase.gestureChanged
        case .ended: return TelemetryPhase.gestureEnded
        case .cancelled: return TelemetryPhase.gestureCancelled
        case .momentumBegan, .momentumChanged, .momentumEnded: return TelemetryPhase.gestureMomentum
        }
    }

    // MARK: - Phase 1B 内容 telemetry（Wave 3 装配接线；全部匿名数值/枚举，红线不越）

    /// catalog 呈现提交（idle 边界 anchor remap 后）：snapshot_revision +
    /// catalog_scan_duration_ms + refresh_duration_ms（Explorer C 建议字段）。
    /// 无 app 名/bundle ID/路径/图标数据/启动 URL（§3.3 + Explorer C 红线）。
    public func recordCatalogPresentation(_ update: AppGridPresentationUpdate, assembly: AppCatalogAssembly) {
        var event = TelemetryEvent(phase: "catalog.presentation")
        event.snapshotRevision = Int(update.plan.snapshotRevision.value)
        event.catalogScanDurationMS = assembly.dataSource.lastScanDurationMS
        event.refreshDurationMS = assembly.dataSource.lastRefreshDurationMS
        session.record(event)
    }

    /// 图标异步 apply 结果 → icon_async_state（中性枚举；无 key/字节/路径）。
    /// teardown 后结果（ignoredAfterTeardown）不记录（视图已销毁，无观测意义）。
    public func recordIconAsyncState(_ result: AppGridIconApplyResult) {
        let state: IconAsyncState
        switch result {
        case .applied: state = .completed
        case .rejectedStale: state = .staleRejected
        case .failed: state = .failed
        case .cancelled: state = .cancelled
        case .ignoredAfterTeardown: return
        }
        var event = TelemetryEvent(phase: "icon.async")
        event.iconAsyncState = state
        session.record(event)
    }
}
