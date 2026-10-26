import LauncherLocalization

/// The existing Finder API is void: requested is dispatch, never proof of displayed Finder UI.
enum FinderRevealOutcome: Equatable {
    case requested
    case rejectedMissingFile
    case rejectedUnavailable
}

/// Pure neutral presentation policy. No record/path/name data crosses into the message.
enum ApplicationActionFeedback {
    static func launchReason(_ outcome: AppLaunchOutcome) -> ActionFeedbackTextKey? {
        switch outcome {
        case .launched, .rejectedNoBinding: return nil
        case .failedToLaunch: return .launchFailed
        case .rejectedMissingApp, .rejectedMissingFile: return .launchMissing
        case .rejectedStaleRevision, .rejectedHiddenApp: return .launchUnavailable
        }
    }
    static func finderReason(_ outcome: FinderRevealOutcome) -> ActionFeedbackTextKey? {
        switch outcome {
        case .requested: return nil
        case .rejectedMissingFile: return .finderMissing
        case .rejectedUnavailable: return .finderUnavailable
        }
    }
}
