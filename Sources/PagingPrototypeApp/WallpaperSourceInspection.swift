import Darwin
import Foundation

/// Metadata-only diagnostic snapshot. Never contains a URL, name, content or raw error.
struct WallpaperSourceInspection: Equatable, Sendable {
    enum Kind: String, Sendable {
        case regular, directory, fifo, socket, device, other, unavailable
        case nonFile = "non-file"
    }
    let kind: Kind
    let localVolume: Bool?
    let ubiquitous: Bool?
    let downloaded: Bool?

    var summary: String {
        func flag(_ value: Bool?) -> String { value.map { $0 ? "yes" : "no" } ?? "unknown" }
        return "source=" + kind.rawValue + "; local=" + flag(localVolume)
            + "; ubiquitous=" + flag(ubiquitous) + "; downloaded=" + flag(downloaded)
    }

    /// Called on a background queue. fstatat follows the source's target but does
    /// not open/read it; special files such as FIFOs are safe to inspect here.
    static func inspect(_ url: URL) -> Self {
        guard url.isFileURL,
              url.host == nil || url.host == "" || url.host == "localhost" else {
            return .init(kind: .nonFile, localVolume: nil, ubiquitous: nil, downloaded: nil)
        }
        var metadata = stat()
        let result = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return fstatat(AT_FDCWD, path, &metadata, 0)
        }
        guard result == 0 else {
            return .init(kind: .unavailable, localVolume: nil, ubiquitous: nil, downloaded: nil)
        }
        let kind: Kind
        switch metadata.st_mode & mode_t(S_IFMT) {
        case mode_t(S_IFREG): kind = .regular
        case mode_t(S_IFDIR): kind = .directory
        case mode_t(S_IFIFO): kind = .fifo
        case mode_t(S_IFSOCK): kind = .socket
        case mode_t(S_IFBLK), mode_t(S_IFCHR): kind = .device
        default: kind = .other
        }
        // Cloud keys are relevant only for regular files; never ask Foundation
        // to resolve content-provider metadata for streams/devices/directories.
        let keys: Set<URLResourceKey> = kind == .regular
            ? [.volumeIsLocalKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
            : []
        let values = keys.isEmpty ? nil : try? url.resourceValues(forKeys: keys)
        let status = values?.ubiquitousItemDownloadingStatus
        let downloaded: Bool?
        if let status { downloaded = status == .current || status == .downloaded }
        else { downloaded = nil }
        return .init(kind: kind, localVolume: values?.volumeIsLocal,
                     ubiquitous: values?.isUbiquitousItem, downloaded: downloaded)
    }
}
