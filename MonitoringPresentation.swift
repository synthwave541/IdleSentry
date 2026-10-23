import Foundation

/// One status for both the window and menu bar. Pausing takes precedence over stale timer data.
enum MonitoringPhase: Equatable {
    case paused, needsApps, waiting, ready
    case countdown(name: String, remaining: Double, action: IdleAction = .standardQuit)

    static func resolve(isMonitoring: Bool, configuredCount: Int, runningCount: Int,
                        nextApp: AppRunningState?) -> MonitoringPhase {
        guard isMonitoring else { return .paused }
        guard configuredCount > 0 else { return .needsApps }
        guard runningCount > 0 else { return .waiting }
        if let nextApp { return .countdown(name: nextApp.name, remaining: nextApp.timeRemaining, action: nextApp.action) }
        return .ready
    }

    var title: String {
        switch self {
        case .paused: return "Monitoring paused"
        case .needsApps: return "Ready when you are"
        case .waiting: return "Waiting for apps"
        case .ready: return "Watching for inactivity"
        case .countdown(_, let remaining, let action):
            return remaining <= 0 ? (action == .hide ? "Hiding…" : "Closing…") : SentryFormat.countdown(remaining)
        }
    }

    var subtitle: String {
        switch self {
        case .paused: return "Your apps will stay open."
        case .needsApps: return "Add an app to get started."
        case .waiting: return "Open a monitored app to begin."
        case .ready: return "Keyboard or mouse activity resets the timer."
        case .countdown(let name, _, let action): return "Next to \(action == .hide ? "hide" : "close") · \(name)"
        }
    }

    var symbol: String {
        switch self {
        case .paused: return "pause.circle"
        case .needsApps: return "plus.app"
        case .waiting: return "app.dashed"
        case .ready: return "checkmark.shield"
        case .countdown: return "timer"
        }
    }

    var isCountingDown: Bool {
        if case .countdown = self { return true }
        return false
    }
}

enum SentryFormat {
    // Bound display conversions so an invalid stored value can't trap an Int conversion.
    private static func safeSeconds(_ seconds: Double) -> Int {
        guard seconds.isFinite else { return 0 }
        return Int(min(31_536_000, max(0, ceil(seconds))))
    }

    static func countdown(_ seconds: Double) -> String {
        let value = safeSeconds(seconds)
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    static func duration(_ seconds: Double) -> String {
        let value = safeSeconds(seconds)
        if value < 60 { return "\(value)s" }
        if value % 3600 == 0 { return "\(value / 3600)h" }
        if value % 60 == 0 { return "\(value / 60)m" }
        return "\(value / 60)m \(value % 60)s"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Custom build"
    }
}

extension AppState {
    var isSystemIdle: Bool { isMonitoring && !monitoredApps.isEmpty && systemIdleTime > countdownDelay }

    var runningAppCount: Int { runningStates.filter(\.isRunning).count }

    /// Keep the detail list available when pointer/keyboard interaction resets the countdown.
    var closingQueue: [AppRunningState] {
        guard isMonitoring else { return [] }
        return runningStates.filter(\.isActionPending).sorted { $0.timeRemaining < $1.timeRemaining }
    }

    var monitoringPhase: MonitoringPhase {
        MonitoringPhase.resolve(isMonitoring: isMonitoring, configuredCount: monitoredApps.count,
                                runningCount: runningAppCount, nextApp: appsPendingClose.first)
    }
}
