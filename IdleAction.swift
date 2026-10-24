import Foundation

// Keep legacy quitMethod values stable so upgrades preserve existing choices.
enum IdleAction: Int, Codable, CaseIterable, Identifiable {
    case standardQuit = 0, forceQuit = 1, hide = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .hide: return "Hide"
        case .standardQuit: return "Standard Quit"
        case .forceQuit: return "Force Quit"
        }
    }
    var detail: String {
        switch self {
        case .hide: return "Hide app windows while keeping the app running and your work open. Click its Dock icon to return. Hiding does not save your work."
        case .standardQuit: return "Request a normal quit. An app may ask you to save or refuse to close."
        case .forceQuit: return "End the app immediately. Unsaved changes can be lost."
        }
    }
}

enum CloseNotification {
    static func body(names: [String]) -> String {
        let names = names.sorted().map { name in
            String(name.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }.joined().prefix(60))
        }
        let shown = names.prefix(3).joined(separator: ", ")
        let extra = names.count - min(3, names.count)
        return shown + (extra > 0 ? " and \(extra) more" : "") + " closed after inactivity."
    }
}

/// Per-process interaction floors use a monotonic clock, so wall-clock changes
/// cannot expire launch protection or indefinitely postpone an inactivity action.
struct AppInteractionGrace {
    private var interactions: [Int32: TimeInterval] = [:]

    mutating func record(_ process: Int32, at now: TimeInterval) { interactions[process] = now }
    mutating func remove(_ process: Int32) { interactions.removeValue(forKey: process) }
    mutating func retain(_ processes: Set<Int32>) {
        interactions = interactions.filter { processes.contains($0.key) }
    }
    func effectiveIdle(for process: Int32, systemIdle: TimeInterval,
                       now: TimeInterval, grace: TimeInterval) -> TimeInterval {
        guard let interaction = interactions[process] else { return systemIdle }
        return min(systemIdle, max(0, now - interaction - grace))
    }
}
