/// Semantic activation transaction and service vocabulary. Native error details remain data.
public enum ActivationStatusTextKey: String, CaseIterable, Sendable {
    case activationCoordinatorUnavailable
    case activationAlertTitle
    case activationLoginAlertTitle
    case activationLoginPartial
    case activationLoginDisabled
    case activationLoginEnabled
    case activationLoginApproval
    case activationLoginUnavailable
    case activationLoginFailure
    case activationCornerRequired
    case activationShortcutRequired
    case activationModifierRequired
    case activationGestureReady
    case activationGestureNotReady
    case activationGestureBackendMissing
    case activationGestureOff
    case activationGestureChecking
    case activationGestureSwitchOff
    case activationGestureNoDevice
    case activationGestureUnavailable
    case activationGesturePermission
    case activationGestureSuspended

    case activationLoginEnableFailed
    case activationLoginDisableFailed

    public var englishFallback: String {
        switch self {
        case .activationLoginEnableFailed: return "Could not enable Open at Login."
        case .activationLoginDisableFailed: return "Could not disable Open at Login."
        case .activationCoordinatorUnavailable: return "Settings are currently unavailable."
        case .activationAlertTitle: return "Could Not Apply Settings"
        case .activationLoginAlertTitle: return "Open at Login Was Not Completed"
        case .activationLoginPartial: return "Other accepted settings were saved. The login preference was not confirmed."
        case .activationLoginDisabled: return "Current: off"
        case .activationLoginEnabled: return "Current: on"
        case .activationLoginApproval: return "Current: approval required in System Settings"
        case .activationLoginUnavailable: return "Current: unavailable"
        case .activationLoginFailure: return "Current: failed"
        case .activationCornerRequired: return "Choose a corner before enabling Hot Corner."
        case .activationShortcutRequired: return "Choose a preset or record a shortcut before enabling the global shortcut."
        case .activationModifierRequired: return "Global shortcuts require at least one modifier key."
        case .activationGestureReady: return "Ready"
        case .activationGestureNotReady: return "Not ready"
        case .activationGestureBackendMissing: return "Backend not connected"
        case .activationGestureOff: return "Off"
        case .activationGestureChecking: return "Checking"
        case .activationGestureSwitchOff: return "Switch is off"
        case .activationGestureNoDevice: return "No device"
        case .activationGestureUnavailable: return "Unavailable"
        case .activationGesturePermission: return "Permission not confirmed"
        case .activationGestureSuspended: return "Suspended"
        }
    }
}
