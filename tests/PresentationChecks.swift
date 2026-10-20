import Foundation
import AppKit

@main
struct PresentationChecks {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
        }
        let next = AppRunningState(name: "Sample", bundleIdentifier: "test.sample", path: "/Sample.app",
                                   isRunning: true, isFrontmost: true, timeRemaining: 0.2)
        check(MonitoringPhase.resolve(isMonitoring: false, configuredCount: 1, runningCount: 1, nextApp: next) == .paused,
              "Pause must override a stale pending timer")
        check(MonitoringPhase.resolve(isMonitoring: true, configuredCount: 0, runningCount: 1, nextApp: next) == .needsApps,
              "Empty configuration must override stale process data")
        check(MonitoringPhase.resolve(isMonitoring: true, configuredCount: 1, runningCount: 0, nextApp: next) == .waiting,
              "Stopped apps must never show a pending countdown")
        check(MonitoringPhase.resolve(isMonitoring: true, configuredCount: 1, runningCount: 1, nextApp: nil) == .ready,
              "Running apps without pending timers should be ready")
        check(MonitoringPhase.resolve(isMonitoring: true, configuredCount: 1, runningCount: 1, nextApp: next)
              == .countdown(name: "Sample", remaining: 0.2), "A pending app must drive the summary")
        check(SentryFormat.countdown(0.2) == "00:01", "Display must round up until the deadline")
        check(SentryFormat.countdown(60) == "01:00", "Minute transition")
        check(SentryFormat.countdown(3601) == "1:00:01", "Hour transition")
        check(SentryFormat.countdown(-2) == "00:00", "Negative presentation value")
        check(SentryFormat.countdown(.nan) == "00:00", "Nonfinite presentation value")
        check(SentryFormat.duration(90) == "1m 30s", "Mixed duration")
        check(SentryFormat.duration(3600) == "1h", "Hour duration")
        check(MonitoringPhase.countdown(name: "Sample", remaining: 0).title == "Closing…", "Reached deadline label")

        let domain = "com.zennoris.IdleSentry"
        let before = UserDefaults.standard.persistentDomain(forName: domain) as NSDictionary?
        let preview = AppState(preview: true)
        check(preview.runningAppCount == 2 && preview.monitoredApps.count == 3, "Preview sample isolation")
        preview.applyPreviewScenario("Countdown")
        check(preview.monitoringPhase.isCountingDown && preview.countdownValue == 50, "Countdown sample")
        preview.isMonitoring = false
        check(preview.monitoringPhase == .paused, "Live pause cancels displayed countdown")
        preview.applyPreviewScenario("Waiting")
        check(preview.runningAppCount == 0 && preview.monitoringPhase == .waiting, "No running apps removes badge state")
        preview.applyPreviewScenario("Empty")
        check(preview.monitoredApps.isEmpty && preview.monitoringPhase == .needsApps, "Empty state")
        preview.applyPreviewScenario("Ready")
        preview.removeApp(bundleId: "com.apple.Safari")
        check(preview.runningAppCount == 1 && preview.monitoredApps.count == 2, "Remove sample updates projection")
        preview.globalTimeout = 90
        preview.quitMethod = 1
        preview.fullyCloseApps = true
        preview.launchAtStartup = true
        preview.requestAccessibility()
        preview.openAccessibilitySettings()
        preview.startTimer()
        preview.reEvaluateTimerState()
        preview.stopTimer()
        preview.applyPreviewScenario("Many Apps")
        check(preview.closingQueue.count == 24, "Full queue retains every running app")
        check(preview.closingQueue.first?.timeRemaining == 50 && preview.closingQueue.last?.timeRemaining == 395,
              "Queue is ordered by next close deadline")
        preview.isCountdownActive = false
        check(preview.monitoringPhase == .ready && preview.closingQueue.count == 24,
              "Resetting inactivity must not remove the list while a person is inspecting it")
        preview.isMonitoring = false
        check(preview.closingQueue.isEmpty, "Pausing removes the active closing queue")
        let after = UserDefaults.standard.persistentDomain(forName: domain) as NSDictionary?
        check(before == after, "Preview controls must never modify user preferences")

        let configured = MonitoredApp(name: "Legacy App", bundleIdentifier: "test.legacy", path: "/Legacy.app", customTimeout: 120)
        let decoded = try JSONDecoder().decode([MonitoredApp].self, from: JSONEncoder().encode([configured]))
        check(decoded == [configured], "Stored identity and custom timeouts must remain compatible")
        let discovered = AppCandidate.discover()
        check(!discovered.isEmpty, "Installed app discovery should find real apps")
        check(Set(discovered.map(\.id)).count == discovered.count, "Discovery deduplicates bundle identifiers")
        check(!discovered.contains { $0.id == "com.zennoris.IdleSentry" }, "IdleSentry must not select itself")
        check(discovered.allSatisfy { Bundle(url: $0.url)?.bundleIdentifier == $0.id }, "Discovery produces valid application identities")
        if let firstStopped = discovered.firstIndex(where: { !$0.isRunning }) {
            check(!discovered[firstStopped...].contains(where: \.isRunning), "Running apps must sort before stopped apps")
        }
        print("Passed \(count) presentation, preview isolation, settings compatibility, and installed-app discovery checks.")
    }
}
