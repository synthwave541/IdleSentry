import AppKit
import Carbon

enum LaunchContext {
    static func isLoginItem(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == kCoreEventClass, event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem ||
            event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
    }

    static func opensWindow(isPreview: Bool, loginItem: Bool, arguments: [String]) -> Bool {
        isPreview || (!loginItem && !arguments.contains("--background"))
    }
}
