//
//  AppArguments.swift
//  PagingPrototypeApp
//
//  App 层命令行参数解析（Docs/PHASE1_SPEC.md §5 + 任务包 T-worker-d）：
//    --paging-lab                 诊断模式
//    --page-count <N>             页面数量（默认 5）
//    --items-per-page <N>         每页占位 item 数（默认 35 —— 本项目测试负载选择）
//    --paging-telemetry           开启 telemetry（默认关闭；委托 PagingTelemetry.TelemetryArguments）
//    --run-id <id>                telemetry run ID（委托 PagingTelemetry.TelemetryArguments）
//    --page-hosting live|composited  承载模式（composited 保留未实现，App 层提示后以 live 运行）
//    --reduce-motion-override on|off|system   Reduce Motion 覆盖（默认 system）
//    --momentum-decay <0.50–0.99>  momentum 每帧衰减系数（默认 0.95；T-worker-b-tune 物理调参）
//    --momentum-glide-frames <0–10> momentum 系统流跟随帧数（默认跟随完整系统流；试值如
//                                1 = 最多跟随 2 个惯性事件；T-worker-b-glide）
//    --momentum-overshoot <0.05–1.0> momentum 过冲钳制（页；默认 0.20；T-worker-b-overshoot2）
//    --fullscreen                以全屏 Space 启动（默认窗口形态；T-worker-b-fullscreen 第 10 轮
//                                全屏为调参基准）
//    --catalog-root <path>       Phase 1B：覆盖默认 4 个受限扫描根（可多次；缺省 =
//                                CatalogRoots.defaults；测试/演示用临时目录）
//    --neutral-content           Phase 1B 回归模式：强制 Phase 1A 中性 placeholder
//                                （不装配真实 catalog/图标；--catalog-root 忽略）
//    --folder-lab                Phase 1E：会话内 folder lab/demo 入口（默认关闭）。
//                                开启时按稳定 catalog 顺序每 35 个 app 一组，中性标题
//                                "Group N"（ADR-008 §2.5）。默认产品启动不重排用户应用。
//    --frame-driver runloop|displaylink|auto   Phase 1B §8 可选帧源实验（缺省 runloop =
//                                Phase 1A 稳定路径；displaylink/auto 探测零回调即回退
//                                RunLoop 并记录证据，绝不破坏 60Hz RunLoop 路径）
//    --frame-timer-tolerance-ms <0–16.667>  RunLoop Timer tolerance 单变量实验；缺省
//                                0ms（nil 解析为 0ms），0 = 禁止容差合并
//    --frame-profile             Phase 1B 帧路径耗时探针（默认关闭）：帧回调/输入事件
//                                各阶段耗时（纳秒级）→ 独立 profile 文件
//                                /tmp/launch-copy-paging-prototype-<run-id>-profile.jsonl；
//                                同时开 runloop 级主线程探针（帧回调之外的主线程工作）
//                                → <run-id>-runloop.jsonl（stdout 打印两个文件路径）
//    --frame-callback-profile    Timer callback 边界探针（默认关闭）：deadline、first tick、
//                                callback wall/CPU → <run-id>-callback.jsonl；可独立开启
//    --runloop-profile           独立 RunLoop observer 探针（默认关闭）：与 callback
//                                探针共用 CLOCK_MONOTONIC_RAW；--frame-profile 仍会
//                                同时开启，两者同时出现时只注册一个 observer
//    --disable-telemetry-bridge  诊断对照：完全不安装 telemetry bridge/frame hook；若同时
//                                请求 --paging-telemetry，则本轮明确禁用 telemetry
//    --help / -h                  打印帮助并退出（不打开窗口）
//
//  约定：参数错误 → 返回 .failure（调用方打印帮助后继续正常启动，绝不崩溃；
//         momentum 调参参数非法除外：必须显式失败 exit 2，不静默回退默认值）。
//

import Foundation
import PagingTelemetry

/// App 层参数解析。
public enum AppArguments {

    public enum PageHostingMode: String, Equatable, Sendable {
        case live
        case composited
    }

    public enum ReduceMotionOverride: String, Equatable, Sendable {
        case on
        case off
        case system
    }

    /// Phase 1B §8 可选帧源实验模式。
    public enum FrameDriverMode: String, Equatable, Sendable {
        /// Phase 1A 稳定路径：runloop 60Hz 帧泵（缺省）。
        case runloop
        /// 强制 display link 实验：零回调时仍回退 RunLoop（绝不冻结），证据记录。
        case displaylink
        /// 自动：优先 display link，零回调回退 RunLoop 并记录 fallback reason。
        case auto
    }

    public struct Options: Equatable, Sendable {
        /// --paging-lab 诊断模式。
        public var pagingLab: Bool
        /// --page-count（nil = 使用默认值 5）。
        public var pageCount: Int?
        /// --items-per-page（nil = 使用默认值 35）。
        public var itemsPerPage: Int?
        /// --page-hosting。
        public var pageHosting: PageHostingMode
        /// --reduce-motion-override。
        public var reduceMotionOverride: ReduceMotionOverride
        /// --momentum-decay（nil = 使用 PagingParameters 默认 0.95；T-worker-b-tune 调参）。
        public var momentumDecay: Double?
        /// --momentum-glide-frames（nil = 跟随完整系统流 = 现行为；T-worker-b-glide 调参）。
        public var momentumGlideFrames: Int?
        /// --momentum-overshoot（nil = 使用 PagingParameters 默认 0.20；T-worker-b-overshoot2 调参）。
        public var momentumOvershoot: Double?
        /// --fullscreen（T-worker-b-fullscreen：全屏 Space 启动，默认 false = 窗口形态）。
        public var fullscreen: Bool
        /// Phase 1B：--catalog-root 覆盖的扫描根（可多次；空 = 使用 CatalogRoots.defaults）。
        public var catalogRoots: [URL]
        /// Phase 1B：--neutral-content 回归模式（强制 Phase 1A 中性 placeholder）。
        public var neutralContent: Bool
        /// Phase 1E：--folder-lab 会话内 folder lab/demo 入口（默认关闭；产品启动不重排用户应用）。
        public var folderLab: Bool
        /// Phase 1B §8：--frame-driver 帧源实验模式（缺省 .runloop = Phase 1A 稳定路径）。
        public var frameDriver: FrameDriverMode
        /// RunLoop Timer tolerance 单变量实验（毫秒；nil = 0ms）。
        public var frameTimerToleranceMS: Double?
        /// Phase 1B：--frame-profile 帧路径耗时探针（默认关闭；缺省零测量零文件）。
        public var frameProfile: Bool
        /// Timer callback deadline/first-tick/CPU 边界探针（默认关闭；独立 JSONL）。
        public var frameCallbackProfile: Bool
        /// 独立 RunLoop observer 探针（默认关闭；可与 --frame-callback-profile 同开）。
        public var runLoopProfile: Bool
        /// 诊断对照：完全不安装 PagingTelemetryBridge（默认 false，生产行为不变）。
        public var disableTelemetryBridge: Bool
        /// telemetry 是否开启（TelemetryArguments 解析结果）。
        public var telemetryEnabled: Bool
        /// telemetry run ID（TelemetryArguments 解析结果）。
        public var runID: String?
        /// --help / -h 是否出现。
        public var helpRequested: Bool

        public static let `default` = Options(
            pagingLab: false,
            pageCount: nil,
            itemsPerPage: nil,
            pageHosting: .live,
            reduceMotionOverride: .system,
            momentumDecay: nil,
            momentumGlideFrames: nil,
            momentumOvershoot: nil,
            fullscreen: false,
            catalogRoots: [],
            neutralContent: false,
            folderLab: false,
            frameDriver: .runloop,
            frameTimerToleranceMS: nil,
            frameProfile: false,
            frameCallbackProfile: false,
            runLoopProfile: false,
            disableTelemetryBridge: false,
            telemetryEnabled: false,
            runID: nil,
            helpRequested: false
        )
    }

    public enum ParseError: Error, Equatable, Sendable {
        case unknownArgument(String)
        case missingValue(String)
        case invalidInteger(String, String)
        case invalidHosting(String)
        case invalidReduceMotion(String)
        case invalidMomentumDecay(String)
        case invalidMomentumGlideFrames(String)
        case invalidMomentumOvershoot(String)
        case invalidFrameDriver(String)
        case invalidFrameTimerTolerance(String)
        case telemetry(TelemetryArguments.ParseError)
    }

    /// 解析命令行参数（应传入完整 CommandLine.arguments）。
    public static func parse(_ arguments: [String]) -> Result<Options, ParseError> {
        // telemetry 参数委托 PagingTelemetry（同一数组二次扫描，语义与模块单测一致）。
        let telemetry: TelemetryArguments.Options
        switch TelemetryArguments.parse(arguments) {
        case .success(let options):
            telemetry = options
        case .failure(let error):
            return .failure(.telemetry(error))
        }

        var options = Options.default
        options.telemetryEnabled = telemetry.telemetryEnabled
        options.runID = telemetry.runID

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--paging-lab":
                options.pagingLab = true

            case "--page-count":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                guard let value = Int(raw), value > 0 else {
                    return .failure(.invalidInteger(argument, raw))
                }
                options.pageCount = value
                index += 1

            case "--items-per-page":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                guard let value = Int(raw), value > 0 else {
                    return .failure(.invalidInteger(argument, raw))
                }
                options.itemsPerPage = value
                index += 1

            case "--page-hosting":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                guard let mode = PageHostingMode(rawValue: raw) else {
                    return .failure(.invalidHosting(raw))
                }
                options.pageHosting = mode
                index += 1

            case "--reduce-motion-override":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                guard let mode = ReduceMotionOverride(rawValue: raw) else {
                    return .failure(.invalidReduceMotion(raw))
                }
                options.reduceMotionOverride = mode
                index += 1

            case "--momentum-decay":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                // 合法范围（0.50–0.99，T-worker-b-tune2 扩展下界容纳短滑行试值）；越界/非数字 → 显式失败。
                guard let value = Double(raw), value >= 0.50, value <= 0.99 else {
                    return .failure(.invalidMomentumDecay(raw))
                }
                options.momentumDecay = value
                index += 1

            case "--momentum-glide-frames":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                // 合法范围 0–10（T-worker-b-glide：0=直接决策，N=最多跟随 2N 个 momentum 事件）；
                // 越界/非数字 → 显式失败（exit 2，不静默回退）。
                guard let value = Int(raw), value >= 0, value <= 10 else {
                    return .failure(.invalidMomentumGlideFrames(raw))
                }
                options.momentumGlideFrames = value
                index += 1

            case "--momentum-overshoot":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                // 合法范围 0.05–1.0（页；T-worker-b-overshoot2）；越界/非数字 → 显式失败（exit 2）。
                guard let value = Double(raw), value >= 0.05, value <= 1.0 else {
                    return .failure(.invalidMomentumOvershoot(raw))
                }
                options.momentumOvershoot = value
                index += 1

            case "--fullscreen":
                options.fullscreen = true

            case "--catalog-root":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                // 路径原样接受（URL(fileURLWithPath:)）；多次出现累积（顺序保留）。
                options.catalogRoots.append(URL(fileURLWithPath: raw))
                index += 1

            case "--neutral-content":
                options.neutralContent = true

            case "--folder-lab":
                options.folderLab = true

            case "--frame-driver":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                guard let mode = FrameDriverMode(rawValue: raw) else {
                    return .failure(.invalidFrameDriver(raw))
                }
                options.frameDriver = mode
                index += 1

            case "--frame-timer-tolerance-ms":
                guard index + 1 < arguments.count else { return .failure(.missingValue(argument)) }
                let raw = arguments[index + 1]
                guard let value = Double(raw), value >= 0, value <= 16.667 else {
                    return .failure(.invalidFrameTimerTolerance(raw))
                }
                options.frameTimerToleranceMS = value
                index += 1

            case "--frame-profile":
                options.frameProfile = true

            case "--frame-callback-profile":
                options.frameCallbackProfile = true

            case "--runloop-profile":
                options.runLoopProfile = true

            case "--disable-telemetry-bridge":
                options.disableTelemetryBridge = true

            case "--paging-telemetry", "--run-id":
                break // 已由 TelemetryArguments 处理

            case "--help", "-h":
                options.helpRequested = true

            default:
                if argument.hasPrefix("-") {
                    return .failure(.unknownArgument(argument))
                }
                // 非 `-` 开头的裸参数：忽略（宽容）。
            }
            index += 1
        }
        return .success(options)
    }

    /// 帮助文本。
    public static func helpText() -> String {
        """
        PagingPrototype（Phase 1A 分页原型）用法：

          --paging-lab               诊断模式（显示状态/偏移叠加层）
          --page-count <N>           页面数量（默认 5）
          --items-per-page <N>       每页占位 item 数（默认 35）
          --paging-telemetry         开启 telemetry（默认关闭）
          --run-id <id>              指定 telemetry run ID（默认自动生成）
          --page-hosting live|composited   页面承载模式（composited 保留未实现，将按 live 运行）
          --reduce-motion-override on|off|system   Reduce Motion 覆盖（默认 system）
          --momentum-decay <0.50–0.99>   momentum 每帧衰减系数（默认 0.95；调参试值，越界报错退出）
          --momentum-glide-frames <0–10> momentum 系统流跟随帧数（默认跟随完整系统流；0=直接决策，
                                        越界报错退出）
          --momentum-overshoot <0.05–1.0>  momentum 过冲钳制（页；默认 0.20，越界报错退出）
          --fullscreen                 以全屏 Space 启动（默认窗口形态；全屏为调参基准）
          --catalog-root <path>        Phase 1B：覆盖默认 4 个受限扫描根（可多次；缺省 =
                                      CatalogRoots.defaults；测试/演示用临时目录）
          --neutral-content            Phase 1B 回归模式：强制 Phase 1A 中性 placeholder
                                      （不装配真实 catalog/图标）
          --folder-lab                Phase 1E：会话内 folder lab/demo 入口（默认关闭）；
                                      按稳定 catalog 顺序每 35 个 app 一组，中性标题 "Group N"
          --frame-driver runloop|displaylink|auto   Phase 1B §8 帧源实验（缺省 runloop；
                                      displaylink/auto 零回调自动回退 RunLoop 并记录证据）
          --frame-timer-tolerance-ms <0–16.667>  RunLoop Timer tolerance 实验（缺省 0ms；
                                      0 = 禁止容差合并；只改变帧源调度提示，不改 PagingCore）
          --frame-profile             Phase 1B 帧路径耗时探针（默认关闭）：帧回调/输入
                                      事件各阶段耗时 → /tmp/launch-copy-paging-prototype-
                                      <run-id>-profile.jsonl；同时开 runloop 级主线程
                                      探针 → <run-id>-runloop.jsonl（stdout 打印文件路径）
          --frame-callback-profile    Timer callback 边界探针（默认关闭）：deadline、first tick、
                                      callback wall/CPU、closure-tail marker → <run-id>-callback.jsonl
          --runloop-profile           独立 RunLoop observer 探针（默认关闭）：与 callback
                                      探针同钟；--frame-profile 仍会开启同一探针，两者
                                      同时出现时只注册一个 observer
          --disable-telemetry-bridge  诊断对照：完全不安装 telemetry bridge/frame hook；若同时
                                      请求 --paging-telemetry，则本轮明确禁用 telemetry
          --help, -h                 显示本帮助并退出

        无参数时以默认配置打开原型。
        """
    }
}
