// AppGridUI — LayoutStore.LayoutStoreIO（Phase 1F §6.1 / ADR-009 Q5/Q6）
// 实现：T-1F-B（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 文件系统注入抽象：生产实现 = `FileManagerLayoutStoreIO`（temp 写 + fsync + 原子替换 +
// 目录 fsync 尽力；文件 0o600 / 目录 0o700）；测试注入 fault-injecting/gating 包装。
// 多实例协调：`workspace-layout.lock` flock（ADR-009 Q6 显式裁决：single-writer /
// last-writer-wins）。隐私：本文件不产生任何输出；错误载荷中性。

import Darwin
import Foundation

/// 中性 IO 错误（进程内；不进 telemetry/日志）。
public enum LayoutStoreIOError: Error {
    case writeFailed
    case lockFailed
}

/// 文件锁（持有 flock fd；deinit 释放）。仅由 `LayoutStoreIO.acquireLock` 创建。
public final class LayoutStoreLock: @unchecked Sendable {
    private let fd: Int32
    fileprivate init(fd: Int32) {
        self.fd = fd
    }
    deinit {
        Darwin.close(fd)
    }
}

/// 文件系统注入抽象（全部 async：测试可注入 gate/故障；生产实现无真实挂起）。
public protocol LayoutStoreIO: Sendable {
    /// 创建目录（含中间目录；权限 0o700）。已存在 → 成功。
    func createDirectoryIfNeeded(at url: URL) async throws
    /// 写文件（覆盖；权限 0o600 + fsync）。temp 写用。
    func writeFile(_ data: Data, to url: URL) async throws
    /// 原子替换：source → destination（同卷 rename/replace）。
    func replaceFile(at source: URL, with destination: URL) async throws
    /// 读文件；不存在/不可读 → nil。
    func readFile(at url: URL) async -> Data?
    /// 尽力删除（不存在 → 成功）。
    func removeFileIfExists(at url: URL) async
    /// 移动（归档/quarantine 用）。
    func moveFile(from source: URL, to destination: URL) async throws
    /// 文件是否存在。
    func fileExists(at url: URL) async -> Bool
    /// 目录内容（文件名清单；失败 → 空）。
    func contentsOfDirectory(at url: URL) async -> [URL]
    /// 获取文件锁：成功 → 锁；被同机另一实例持有 → nil；失败 → throw。
    func acquireLock(at url: URL) async throws -> LayoutStoreLock?
    /// 目录 fsync（尽力；失败静默）。
    func fsyncDirectory(at url: URL) async
}

/// 生产实现：FileManager + flock。
public struct FileManagerLayoutStoreIO: LayoutStoreIO {

    public init() {}

    public func createDirectoryIfNeeded(at url: URL) async throws {
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }

    public func writeFile(_ data: Data, to url: URL) async throws {
        guard FileManager.default.createFile(atPath: url.path,
                                             contents: data,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw LayoutStoreIOError.writeFailed
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }

    public func replaceFile(at source: URL, with destination: URL) async throws {
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
    }

    public func readFile(at url: URL) async -> Data? {
        try? Data(contentsOf: url)
    }

    public func removeFileIfExists(at url: URL) async {
        try? FileManager.default.removeItem(at: url)
    }

    public func moveFile(from source: URL, to destination: URL) async throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    public func fileExists(at url: URL) async -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func contentsOfDirectory(at url: URL) async -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url,
                                                      includingPropertiesForKeys: nil)) ?? []
    }

    public func acquireLock(at url: URL) async throws -> LayoutStoreLock? {
        let fd = Darwin.open(url.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw LayoutStoreIOError.lockFailed }
        // 注意：必须用非限定 `flock`（Darwin.flock 被 sys/fcntl.h 的 struct flock 遮蔽）。
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            return LayoutStoreLock(fd: fd)
        }
        Darwin.close(fd)
        return nil   // 同机另一实例持有锁 → last-writer-wins
    }

    public func fsyncDirectory(at url: URL) async {
        let fd = Darwin.open(url.path, O_RDONLY)
        if fd >= 0 {
            Darwin.fsync(fd)
            Darwin.close(fd)
        }
    }
}
