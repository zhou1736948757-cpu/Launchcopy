import CoreFoundation
import Foundation

/// Explicit test-candidate opt-in; no production/default storage fallback.
/// Samples stay in memory until ordinary application termination, never per frame.
@MainActor
final class LibraryEntryProfileSession {
    let recorder: LibraryEntryProfile
    private let profile: UITestProfile
    private var observer: CFRunLoopObserver?
    private var exported = false
    var isCapturingInteraction: () -> Bool = { false }

    static func isEnabled(marker: Any?) -> Bool {
        guard let marker = marker as? NSNumber,
              CFGetTypeID(marker) == CFBooleanGetTypeID() else { return false }
        return marker.boolValue
    }

    static func make(profile: UITestProfile, marker: Any?) -> LibraryEntryProfileSession? {
        guard isEnabled(marker: marker) else { return nil }
        return LibraryEntryProfileSession(profile: profile)
    }

    private init(profile: UITestProfile) {
        self.profile = profile
        recorder = LibraryEntryProfile()
        let activities: CFRunLoopActivity = [.entry, .exit, .beforeWaiting, .afterWaiting]
        observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, activities.rawValue, true, 0) { [weak self] _, activity in
            MainActor.assumeIsolated {
                guard let self, self.isCapturingInteraction() else { return }
                switch activity {
                case .entry: self.recorder.mark(.runLoopEntry)
                case .exit: self.recorder.mark(.runLoopExit)
                case .beforeWaiting: self.recorder.mark(.runLoopBeforeWaiting)
                case .afterWaiting: self.recorder.mark(.runLoopAfterWaiting)
                default: break
                }
            }
        }
        if let observer { CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes) }
    }

    deinit { if let observer { CFRunLoopObserverInvalidate(observer) } }

    /// Revalidate candidate containment immediately before writing. A unique output
    /// preserves earlier captures. Errors are deliberately silent and non-fatal.
    @discardableResult
    func exportOnTermination() -> Bool {
        guard !exported else { return false }
        exported = true
        if let observer { CFRunLoopObserverInvalidate(observer) }
        observer = nil
        guard let current = try? UITestProfile.resolve(bundleURL: profile.bundleURL, profileID: profile.id),
              current == profile,
              let data = try? recorder.encodedSnapshot() else { return false }
        do {
            try FileManager.default.createDirectory(at: profile.rootURL, withIntermediateDirectories: true)
            let output = profile.rootURL.appendingPathComponent("LibraryEntryProfile-" + UUID().uuidString + ".json")
            try data.write(to: output, options: .withoutOverwriting)
            return true
        } catch { return false }
    }
}
