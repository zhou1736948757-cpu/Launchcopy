import Foundation

enum AppRemovalRunningPolicy {
    /// Inputs are canonicalized by the caller. No process or filesystem I/O.
    static func matches(candidate: URL, runningURL: URL?, isTerminated: Bool) -> Bool {
        guard !isTerminated, candidate.isFileURL, let runningURL, runningURL.isFileURL else { return false }
        // Conservative on case-sensitive volumes: an extra refusal is safer
        // than missing a case alias on the usual case-insensitive volume.
        return candidate.path.compare(runningURL.path, options: .caseInsensitive,
                                      locale: Locale(identifier: "en_US_POSIX")) == .orderedSame
    }
}
