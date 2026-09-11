//
//  FourFingerCaptureStats.swift
//  PagingPrototypeApp
//
//  Phase 1G 采集实验统计逻辑（T-G-P6 交付物 2 的可测部分）。
//  纯 Foundation 值类型：按场景累计帧数/触点计数分布/会话数（began→ended 序列）。
//  中性统计：只记录计数与状态枚举，不记录坐标/序列号/时间戳原始值。
//  会话计数语义：began 开会话；ended/cancelled/零触点 moved 关会话并计 1 会话；
//  未闭合会话不计（实验中断时如实反映）。
//

import Foundation

/// 采集实验统计（按场景分组；工具与测试共用）。
public struct FourFingerCaptureStats: Equatable, Sendable {
    /// 单场景统计。
    public struct ScenarioStats: Equatable, Sendable {
        public var frameCount = 0
        /// 触点计数分布（contacts 数量 → 帧数）。
        public var contactCountDistribution: [Int: Int] = [:]
        /// 会话数（began → ended/cancelled/零触点 moved 闭合序列）。
        public var sessionCount = 0
        public var beganCount = 0
        public var movedCount = 0
        public var endedCount = 0
        public var cancelledCount = 0

        public init() {}
    }

    public private(set) var scenarios: [String: ScenarioStats] = [:]
    private var openSessions: Set<PinchDeviceID> = []

    public init() {}

    /// 记录一帧到指定场景（设备隔离：会话按设备计）。
    public mutating func record(_ frame: PinchFrame, scenario: String) {
        var s = scenarios[scenario] ?? ScenarioStats()
        s.frameCount += 1
        s.contactCountDistribution[frame.contacts.count, default: 0] += 1
        switch frame.phase {
        case .began:
            s.beganCount += 1
            openSessions.insert(frame.deviceID)
        case .moved:
            s.movedCount += 1
            if frame.contacts.isEmpty {
                // 零触点 moved = 结束证据（会话关闭）
                if openSessions.remove(frame.deviceID) != nil {
                    s.sessionCount += 1
                }
            }
        case .ended:
            s.endedCount += 1
            if openSessions.remove(frame.deviceID) != nil {
                s.sessionCount += 1
            }
        case .cancelled:
            s.cancelledCount += 1
            if openSessions.remove(frame.deviceID) != nil {
                s.sessionCount += 1
            }
        }
        scenarios[scenario] = s
    }

    /// 场景名（排序稳定）。
    public var scenarioNames: [String] {
        scenarios.keys.sorted()
    }

    /// 单场景摘要（中性：只含计数与状态枚举）。
    public func summary(for scenario: String) -> String {
        guard let s = scenarios[scenario] else {
            return "scenario=\(scenario) frames=0"
        }
        let dist = s.contactCountDistribution.keys.sorted()
            .map { "\($0):\(s.contactCountDistribution[$0] ?? 0)" }
            .joined(separator: ",")
        return "scenario=\(scenario) frames=\(s.frameCount) contacts={\(dist)} " +
            "sessions=\(s.sessionCount) began=\(s.beganCount) moved=\(s.movedCount) " +
            "ended=\(s.endedCount) cancelled=\(s.cancelledCount)"
    }
}
