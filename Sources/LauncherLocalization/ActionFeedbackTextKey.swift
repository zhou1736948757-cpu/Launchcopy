/// Neutral launch/Finder feedback. No app identity or native error details are arguments.
public enum ActionFeedbackTextKey: String, CaseIterable, Sendable {
    case launchFailed = "actionFeedback.launchFailed"
    case launchMissing = "actionFeedback.launchMissing"
    case launchUnavailable = "actionFeedback.launchUnavailable"
    case finderMissing = "actionFeedback.finderMissing"
    case finderUnavailable = "actionFeedback.finderUnavailable"
    case feedbackAccessibility = "actionFeedback.feedbackAccessibility"

    public var englishFallback: String {
        switch self {
        case .launchFailed: return "Could not open the app. Try again."
        case .launchMissing: return "The app could not be found. Refresh the app list and try again."
        case .launchUnavailable: return "The app is currently unavailable. Refresh the app list and try again."
        case .finderMissing: return "The app could not be found. Refresh the app list before showing it in Finder."
        case .finderUnavailable: return "The app is currently unavailable. Try showing it in Finder again later."
        case .feedbackAccessibility: return "App action status"
        }
    }
}
