//
//  main.swift — 四指采集实验工具（T-G-P6 交付物 2；Phase 1G）
//
//  实验用途（用户已确认风险清单 R-01..R-07，2026-09-05）：
//    - 验证私有 MultitouchSupport ABI（R-01）：符号存在性、MTTouch 布局、回调签名
//    - 核实触点状态分类（R-02）：记录 state 值分布（经后端合成后的 phase 枚举）
//    - 核实设备枚举与回调频率（参考实现注释预期 125-250Hz）
//  数据义务：本工具把匿名帧（含 normalized 坐标）写入 /tmp/fourfinger-capture-*.jsonl，
//    仅实验用途；实验完成后必须删除该文件（删除义务）。
//  中性输出：实时打印只含触点计数与状态枚举，不打印坐标原始值。
//
//  编译（独立脚本，不动 Package.swift）：
//    swiftc -O \
//      Sources/PagingPrototypeApp/PinchRecognizer.swift \
//      Sources/PagingPrototypeApp/TouchProvider.swift \
//      Sources/PagingPrototypeApp/MultitouchSupportBackend.swift \
//      Sources/PagingPrototypeApp/FourFingerCaptureStats.swift \
//      Tools/FourFingerCaptureTool/main.swift \
//      -o /tmp/fourfinger-capture-tool
//  运行：
//    /tmp/fourfinger-capture-tool
//    输入场景名（slow-pinch / fast-pinch / spread / negative）开始一段采集，
//    按 Enter 结束当前段，Ctrl-C 整体停止（写 JSONL + 汇总）。
//

import Foundation

// 行缓冲：重定向到文件时实时可见（实验工具小适配，Main 2026-09-05）
setvbuf(stdout, nil, _IOLBF, 0)

// MARK: - 停止标志（SIGINT 与主循环共享）

final class StopFlag {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}

let stopFlag = StopFlag()

// MARK: - 录制帧（匿名；仅实验用途；含 normalized 坐标）

struct RecordedContact: Codable {
    var id: Int
    var x: Double
    var y: Double
}

struct RecordedFrame: Codable {
    var scenario: String
    var timestamp: Double
    var phase: String
    var contactCount: Int
    var contacts: [RecordedContact]
}

// MARK: - 采集会话

final class CaptureSession {
    private let lock = NSLock()
    private var currentScenarioStorage: String?
    private var recordedFramesStorage: [RecordedFrame] = []
    private var statsStorage = FourFingerCaptureStats()
    private var frameSequence = 0

    var currentScenario: String? {
        lock.lock()
        defer { lock.unlock() }
        return currentScenarioStorage
    }

    func beginScenario(_ name: String) {
        lock.lock()
        currentScenarioStorage = name
        lock.unlock()
        print("== 开始场景: \(name)（做手势，按 Enter 结束本段）")
    }

    func endScenario() {
        lock.lock()
        let name = currentScenarioStorage
        currentScenarioStorage = nil
        let stats = statsStorage
        lock.unlock()
        if let name = name {
            print("== 场景结束: \(stats.summary(for: name))")
        }
    }

    func record(_ frame: PinchFrame) {
        lock.lock()
        guard let scenario = currentScenarioStorage else {
            lock.unlock()
            return
        }
        frameSequence += 1
        let seq = frameSequence
        let phaseName: String
        switch frame.phase {
        case .began: phaseName = "began"
        case .moved: phaseName = "moved"
        case .ended: phaseName = "ended"
        case .cancelled: phaseName = "cancelled"
        }
        let recorded = RecordedFrame(
            scenario: scenario,
            timestamp: frame.timestamp,
            phase: phaseName,
            contactCount: frame.contacts.count,
            contacts: frame.contacts.map {
                RecordedContact(id: $0.id.rawValue, x: $0.position.x, y: $0.position.y)
            }
        )
        recordedFramesStorage.append(recorded)
        statsStorage.record(frame, scenario: scenario)
        lock.unlock()
        // 中性输出：只打印计数与状态枚举（不打印坐标）
        print("[\(scenario)] #\(seq) contacts=\(frame.contacts.count) phase=\(phaseName)")
    }

    func snapshot() -> (frames: [RecordedFrame], stats: FourFingerCaptureStats) {
        lock.lock()
        defer { lock.unlock() }
        return (recordedFramesStorage, statsStorage)
    }
}

// MARK: - 主流程

let session = CaptureSession()
let backend = MultitouchSupportBackend()

func stateDescription(_ state: TouchProviderState) -> String {
    switch state {
    case .off: return "off"
    case .checking: return "checking"
    case .ready: return "ready"
    case .noDevice: return "noDevice"
    case .unavailable: return "unavailable"
    case .permissionNotConfirmed: return "permissionNotConfirmed"
    case .suspended(let reason): return "suspended(\(reason))"
    }
}

backend.onStateChange = { state in
    print("[state] \(stateDescription(state))")
}
backend.onFrame = { frame in
    session.record(frame)
}

// SIGINT → 优雅停止（写 JSONL + 汇总）
signal(SIGINT, SIG_IGN)
let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalSource.setEventHandler {
    stopFlag.isSet = true
}
signalSource.resume()

// stdin 线程：场景名 / Enter / quit
let stdinThread = Thread {
    while !stopFlag.isSet {
        guard let line = readLine() else { break } // EOF
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            session.endScenario()
        } else if trimmed == "quit" || trimmed == "exit" {
            stopFlag.isSet = true
        } else {
            session.endScenario()
            session.beginScenario(trimmed)
        }
    }
}
stdinThread.start()

print("四指采集工具（Phase 1G 实验；Ctrl-C 停止）")
print("输入场景名开始采集（slow-pinch / fast-pinch / spread / negative），Enter 结束本段")
backend.start()
print("[detail] \(backend.lastStartDetail)")

// 主线程等待停止
while !stopFlag.isSet {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
}

// 收尾
session.endScenario()
backend.stop()

let (frames, stats) = session.snapshot()
print("== 汇总 ==")
for name in stats.scenarioNames {
    print(stats.summary(for: name))
}
print("总帧数: \(frames.count)")

// 写临时文件（仅实验用途；实验后删除）
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]
let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
let path = "/tmp/fourfinger-capture-\(stamp).jsonl"
do {
    var lines: [String] = []
    let encoder = JSONEncoder()
    for f in frames {
        if let data = try? encoder.encode(f), let line = String(data: data, encoding: .utf8) {
            lines.append(line)
        }
    }
    try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    print("已写入 \(path)（\(frames.count) 帧；仅实验用途，实验完成后请删除该文件）")
} catch {
    print("写文件失败: \(error)")
}
