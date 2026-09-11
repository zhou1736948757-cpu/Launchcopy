//
//  rawdiag.swift — 原始帧诊断采集器（T-G-P6 诊断；Phase 1G）
//
//  目的：区分「系统只上报 1-2 触点」vs「上报 4 触点但 state 被误读/过滤」。
//  独立最小实现（不依赖 MultitouchSupportBackend 的过滤与合成）：
//    - dlopen MultitouchSupport.framework，注册 C 回调
//    - 每帧打印：count 参数 + 每触点原始 (state, identifier) + 帧时间戳
//    - 不做任何过滤/合成/坐标输出（中性：不打印坐标）
//
//  编译（独立脚本，不动 Package.swift）：
//    swiftc -O Tools/FourFingerCaptureTool/rawdiag.swift -o /tmp/fourfinger-rawdiag
//  运行：
//    /tmp/fourfinger-rawdiag
//    做手势（四指平放 / slow-pinch），Ctrl-C 停止。
//

import Darwin
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

// MARK: - 私有 ABI 类型（与审计文档 §2.2 / LaunchBetter 布局一致）

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTReadout {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTReadout
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTReadout
    var zero2: (Int32, Int32)
    var density: Float
}

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>?
typealias MTContactCallbackFn =
    @convention(c) (MTDeviceRef, UnsafeMutableRawPointer, Int32, Double, Int32) -> Int32
typealias MTRegisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactCallbackFn) -> Void
typealias MTUnregisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactCallbackFn) -> Void
typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Void
typealias MTDeviceStopFn = @convention(c) (MTDeviceRef, Int32) -> Void

// MARK: - 全局回调（非捕获 C 闭包）

private let diagLock = NSLock()
private var diagFrameCount: Int64 = 0
private var diagStateHistogram: [Int32: Int] = [:]
private var diagMaxContacts = 0

private let diagCallback: MTContactCallbackFn = { _, touchesPtr, count, timestamp, frame in
    let n = Int(count)
    diagLock.lock()
    diagFrameCount += 1
    diagMaxContacts = max(diagMaxContacts, n)
    var states: [Int32] = []
    if n > 0 {
        let typed = touchesPtr.assumingMemoryBound(to: MTTouch.self)
        let buffer = UnsafeBufferPointer(start: typed, count: n)
        for t in buffer {
            diagStateHistogram[t.state, default: 0] += 1
            states.append(t.state)
        }
    }
    let seq = diagFrameCount
    let maxC = diagMaxContacts
    let hist = diagStateHistogram
    diagLock.unlock()
    // 中性输出：count + state 值 + identifier 值（不打印坐标）
    let stateStr = states.map(String.init).joined(separator: ",")
    print("[raw] #\(seq) count=\(n) states=[\(stateStr)] ts=\(String(format: "%.4f", timestamp)) frame=\(frame)")
    if seq % 50 == 0 {
        print("[hist] frames=\(seq) maxContacts=\(maxC) stateHist=\(hist.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
    }
    return 0
}

// MARK: - 主流程

guard let handle = dlopen(
    "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
    RTLD_LAZY
) else {
    fputs("dlopen failed\n", stderr)
    exit(1)
}

guard
    let createList = dlsym(handle, "MTDeviceCreateList").map({
        unsafeBitCast($0, to: MTDeviceCreateListFn.self)
    }),
    let register = dlsym(handle, "MTRegisterContactFrameCallback").map({
        unsafeBitCast($0, to: MTRegisterContactFrameCallbackFn.self)
    }),
    let unregister = dlsym(handle, "MTUnregisterContactFrameCallback").map({
        unsafeBitCast($0, to: MTUnregisterContactFrameCallbackFn.self)
    }),
    let start = dlsym(handle, "MTDeviceStart").map({
        unsafeBitCast($0, to: MTDeviceStartFn.self)
    }),
    let stop = dlsym(handle, "MTDeviceStop").map({
        unsafeBitCast($0, to: MTDeviceStopFn.self)
    })
else {
    fputs("dlsym failed\n", stderr)
    dlclose(handle)
    exit(1)
}

guard let listRef = createList() else {
    fputs("MTDeviceCreateList returned nil\n", stderr)
    dlclose(handle)
    exit(1)
}
let list = listRef.takeUnretainedValue()
let count = CFArrayGetCount(list)
print("[devices] count=\(count)")
guard count > 0 else {
    fputs("no devices\n", stderr)
    dlclose(handle)
    exit(1)
}

var registered = 0
for index in 0..<count {
    guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
    let device = unsafeBitCast(value, to: MTDeviceRef.self)
    register(device, diagCallback)
    start(device, 0)
    registered += 1
}
print("[started] registered=\(registered)（做手势：四指平放 / slow-pinch；Ctrl-C 停止）")

// SIGINT → 优雅停止
signal(SIGINT, SIG_IGN)
let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalSource.setEventHandler {
    diagLock.lock()
    let frames = diagFrameCount
    let maxC = diagMaxContacts
    let hist = diagStateHistogram
    diagLock.unlock()
    print("== 汇总 ==")
    print("总帧数: \(frames)")
    print("最大触点: \(maxC)")
    print("state 直方图: \(hist.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
    for index in 0..<count {
        guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
        let device = unsafeBitCast(value, to: MTDeviceRef.self)
        stop(device, 0)
        unregister(device, diagCallback)
    }
    dlclose(handle)
    exit(0)
}
signalSource.resume()

RunLoop.current.run()
