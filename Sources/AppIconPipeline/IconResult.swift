// AppIconPipeline — IconResult / IconFailure（wave1-interfaces.md §D）

import AppKit

/// 单次图标请求的结果。`success` 仅承载运行时内存对象（NSImage），
/// 绝不包含字节/哈希/路径；不落盘、不复制进资源/fixture/发布包。
/// NSImage 非 Sendable → @unchecked（对象在创建线程产生、MainActor 只读投递）。
public enum IconResult: @unchecked Sendable {
    case success(NSImage)
    case failed(IconFailure)
}

/// 失败分类（UI 显示中性 placeholder）。
public enum IconFailure: Error, Sendable, Equatable {
    case cancelled       // 底层加载被取消（全部 consumer 取消 / cancelAll）
    case loadFailed      // loader 失败
    case pipelineShutdown // 预留：shutdown 后按契约零回调，本 case 供未来语义使用
}
