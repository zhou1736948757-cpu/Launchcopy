//
//  AppParameters.swift
//  PagingPrototypeApp
//
//  App 参数 → PagingParameters 接线（T-worker-b-tune/-glide/-overshoot2：momentum 三旋钮调参）。
//  - 缺省保持 PagingParameters 默认值（momentumDecay 0.95 / glideFrames nil / overshoot 0.20），
//    不修改 PagingCore 默认；
//  - 调参确认后再把试值固化为 Core 默认（届时改 PagingParameters.swift 一处）。
//

import PagingCore

/// App 层参数构造（可单测；AppDelegate 使用同一路径）。
enum AppParameters {

    /// 由解析后的 App 选项构造 PagingParameters。
    static func make(momentumDecay: Double?, momentumGlideFrames: Int?, momentumOvershoot: Double?) -> PagingParameters {
        var parameters = PagingParameters()
        if let momentumDecay {
            parameters.momentumDecay = momentumDecay
        }
        if let momentumGlideFrames {
            parameters.momentumGlideFrames = momentumGlideFrames
        }
        if let momentumOvershoot {
            parameters.momentumMaxOvershoot = momentumOvershoot
        }
        return parameters
    }
}
