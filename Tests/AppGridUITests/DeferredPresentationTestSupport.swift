import Foundation

/// Drains text-only main-queue presentation outside synthetic gesture/frame loops.
/// This is a deterministic code gate, not physical input or GUI acceptance.
@MainActor
func drainDeferredPresentationTurns() async {
    for _ in 0..<4 {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
