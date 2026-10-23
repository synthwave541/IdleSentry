import Foundation
import AppKit
import UserNotifications
import Carbon

@main
struct PresentationChecks {
    static func pump(_ seconds: Double = 0.2) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    static func lifecycleChecks(_ check: (Bool, String) -> Void) throws {
        guard let directory = ProcessInfo.processInfo.environment["IDLESENTRY_HELPER_DIR"] else { return }
        let suite = "com.zennoris.IdleSentry.tests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        // Exercise opted-in delivery without requesting or changing system notification permission.
        preferences.set(true, forKey: "sendCloseNotifications")
        preferences.set(10.0, forKey: "globalTimeout")
        var reportsWarning = false
        var delivered: [UNNotificationRequest] = []
        let state = AppState(preview: false, preferences: preferences, saveWarningReported: { _ in reportsWarning }, deliverNotification: { delivered.append($0) })
        defer { state.isMonitoring = false; state.stopTimer() }
        // Drive idle episodes explicitly below. Workspace callbacks can restart the
        // production timer while awaiting helpers; real mouse input must not race
        // the injected idle values and cancel a fallback during these checks.
        func pump(_ seconds: Double = 0.2) {
            let deadline = Date().addingTimeInterval(seconds)
            repeat {
                state.stopTimer()
                RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.02)))
            } while Date() < deadline
            state.stopTimer()
        }
        var helpers: [NSRunningApplication] = []
        defer { for helper in helpers where !helper.isTerminated { helper.forceTerminate() } }
        func launch(_ name: String, refuse: Bool = false) throws -> (NSRunningApplication, URL) {
            let metrics = URL(fileURLWithPath: directory).appendingPathComponent("\(name).json")
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = ["--metrics=\(metrics.path)"] + (refuse ? ["--refuse-quit"] : [])
            config.activates = false
            var result: NSRunningApplication?
            var launchError: Error?
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: directory).appendingPathComponent("\(name).app"), configuration: config) { app, error in
                result = app; launchError = error
            }
            let deadline = Date().addingTimeInterval(10)
            while (result == nil || !FileManager.default.fileExists(atPath: metrics.path)) && Date() < deadline { pump(0.05) }
            if let launchError { throw launchError }
            guard let result else { fatalError("Helper launch timed out") }
            helpers.append(result)
            return (result, metrics)
        }
        func metrics(_ url: URL) throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any] }
        let (unsaved, url) = try launch("Unsaved", refuse: true)
        state.monitoredApps = [MonitoredApp(name: "Unsaved", bundleIdentifier: unsaved.bundleIdentifier!, path: unsaved.bundleURL!.path, customAction: .hide)]
        state.fullyCloseApps = true
        state.quitMethod = 1 // Per-app Hide must override even global Force Quit and cleanup.
        pump(); state.stopTimer()
        state.checkIdleTime(20); pump()
        check(unsaved.isHidden && !unsaved.isTerminated, "Real Hide keeps unsaved app alive")
        check((try metrics(url)["text"] as? String) == "Unsaved IdleSentry test document — café 🌙", "Hide preserves document contents")
        check((try metrics(url)["edited"] as? Bool) == true, "Hide preserves edited status")
        check((try metrics(url)["quitRequests"] as? Int) == 0 && delivered.isEmpty, "Hide never quits or sends close notification")
        state.checkIdleTime(25)
        check(state.runningAppCount == 1 && state.closingQueue.isEmpty, "Hidden app has no repeated countdown")
        unsaved.unhide(); pump()
        state.checkIdleTime(0)
        check(!unsaved.isHidden && !unsaved.isTerminated, "Native unhide restores app")
        state.monitoredApps[0].customAction = .standardQuit
        state.checkIdleTime(20); pump(); state.stopTimer()
        state.checkIdleTime(20)
        check(!unsaved.isTerminated && delivered.isEmpty, "Declined quit is never reported closed or killed by cleanup")
        check((try metrics(url)["quitRequests"] as? Int) == 1, "Only one quit request per idle episode")
        reportsWarning = true
        state.unsavedWorkAction = .forceQuit
        state.quitMethod = 1
        state.checkIdleTime(0); state.checkIdleTime(20); pump(1.1); state.stopTimer(); state.checkIdleTime(20)
        check(!unsaved.isTerminated, "Global Force Quit disables unsaved fallback even for a Standard Quit override")
        state.quitMethod = 2
        state.unsavedWorkAction = .hide
        state.checkIdleTime(0); state.checkIdleTime(20); pump(1.1); state.stopTimer(); state.checkIdleTime(20)
        check(!unsaved.isHidden && !unsaved.isTerminated, "Global Hide disables save-warning fallback")
        reportsWarning = false
        // Only the evidence source is injected; every action below targets a real disposable app.
        state.quitMethod = 0
        state.unsavedWorkAction = .forceQuit
        state.checkIdleTime(0); state.checkIdleTime(20); pump(1.1); state.stopTimer(); state.checkIdleTime(20)
        check(!unsaved.isTerminated, "A slow/refused quit without save evidence never triggers Force Quit")
        reportsWarning = true
        state.unsavedWorkAction = .hide
        state.checkIdleTime(0); state.checkIdleTime(20); pump(1.1); state.stopTimer(); state.checkIdleTime(20); pump()
        check(unsaved.isHidden && !unsaved.isTerminated, "Reported save warning applies explicit Hide fallback")
        state.checkIdleTime(20)
        check(state.closingQueue.isEmpty && state.runningAppCount == 1, "Fallback-hidden app leaves queue but stays running")
        check(delivered.isEmpty, "Fallback Hide does not notify as closed")
        unsaved.unhide(); pump(); state.checkIdleTime(0)
        state.unsavedWorkAction = .forceQuit
        state.checkIdleTime(20); pump(1.1); state.stopTimer()
        state.isMonitoring = false
        state.checkIdleTime(20)
        check(!unsaved.isTerminated, "Pause cancels an armed Force Quit fallback")
        state.checkIdleTime(0)
        check(!unsaved.isTerminated, "Input cancels an armed fallback")
        state.isMonitoring = true
        state.unsavedWorkAction = .leaveOpen
        reportsWarning = false
        let (first, _) = try launch("First")
        let (second, _) = try launch("Second")
        state.fullyCloseApps = false
        state.quitMethod = 0
        state.monitoredApps = [first, second].enumerated().map { index, app in
            MonitoredApp(name: index == 0 ? "First" : "Second", bundleIdentifier: app.bundleIdentifier!, path: app.bundleURL!.path)
        }
        state.checkIdleTime(0); state.checkIdleTime(20)
        check(delivered.isEmpty, "Quit acceptance does not immediately notify")
        pump(0.6); state.stopTimer(); state.checkIdleTime(20)
        check(first.isTerminated && second.isTerminated, "Real standard quit exits both apps")
        check(delivered.count == 1 && delivered[0].content.body.contains("First, Second"), "Confirmed exits combine into one notification")
        check(delivered.first?.content.sound == nil, "Delivered notification is silent")
        check(delivered.first?.content.attachments.isEmpty == true, "Notifications use the sender app icon without a right-side thumbnail")
        state.checkIdleTime(20)
        check(delivered.count == 1, "Confirmed close notifies only once")
        state.sendCloseNotifications = false
        check(!preferences.bool(forKey: "sendCloseNotifications"), "Opt-out persists")
        reportsWarning = true
        state.unsavedWorkAction = .forceQuit
        state.monitoredApps = [MonitoredApp(name: "Unsaved", bundleIdentifier: unsaved.bundleIdentifier!, path: unsaved.bundleURL!.path, customAction: .standardQuit)]
        state.checkIdleTime(0); state.checkIdleTime(20); pump(1.1); state.stopTimer(); state.checkIdleTime(20); pump(0.4); state.checkIdleTime(20)
        check(unsaved.isTerminated && delivered.count == 1, "Explicit unsaved-work Force Quit works while notification opt-out stays silent")
        state.isMonitoring = false
        state.stopTimer()
        state.tipsDismissed = true
        let restored = AppState(preview: false, preferences: preferences, deliverNotification: { _ in fatalError("Unexpected notification") })
        check(!restored.sendCloseNotifications && restored.monitoredApps.first?.customAction == .standardQuit && restored.unsavedWorkAction == .forceQuit, "Settings and override survive reload")
        check(restored.tipsDismissed, "Dismissed setup tips stay dismissed after restart")
        restored.isMonitoring = false; restored.stopTimer()
    }

    static func main() throws {
        setbuf(stdout, nil)
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

        let login = NSAppleEventDescriptor.appleEvent(withEventClass: kCoreEventClass, eventID: kAEOpenApplication,
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        login.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        check(LaunchContext.isLoginItem(login), "Recognizes the real login Apple event")
        check(!LaunchContext.isLoginItem(nil), "Missing event never guesses from uptime")
        check(!LaunchContext.opensWindow(isPreview: false, loginItem: true, arguments: []), "Login stays in menu bar")
        check(LaunchContext.opensWindow(isPreview: false, loginItem: false, arguments: []), "Manual launch opens settings")
        check(!LaunchContext.opensWindow(isPreview: false, loginItem: false, arguments: ["--background"]), "Explicit background launch stays quiet")
        check(LaunchContext.opensWindow(isPreview: true, loginItem: true, arguments: []), "Isolated visual QA remains accessible")
        check(!AccessRecovery.shouldShow(granted: true, returningUser: true, previousBuild: "old", currentBuild: "new", lastTrustedBuild: "old", dismissedBuild: nil), "A working grant never nags after reinstall")
        check(AccessRecovery.shouldShow(granted: false, returningUser: true, previousBuild: "old", currentBuild: "new", lastTrustedBuild: "old", dismissedBuild: "old"), "A changed build with missing access reopens repair guidance")
        check(!AccessRecovery.shouldShow(granted: false, returningUser: true, previousBuild: "same", currentBuild: "same", lastTrustedBuild: "same", dismissedBuild: "same"), "Repair dismissal persists for the same executable")
        check(!AccessRecovery.shouldShow(granted: false, returningUser: false, previousBuild: nil, currentBuild: "first", lastTrustedBuild: nil, dismissedBuild: nil), "New users receive ordinary setup rather than reinstall claims")
        check(AccessRecovery.shouldShow(granted: false, returningUser: true, previousBuild: nil, currentBuild: "migration", lastTrustedBuild: nil, dismissedBuild: nil), "Existing installations without history still get recovery guidance")
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
        let legacyJSON = "[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Old\",\"bundleIdentifier\":\"old.app\",\"path\":\"/Old.app\",\"customTimeout\":120}]"
        let legacy = try JSONDecoder().decode([MonitoredApp].self, from: Data(legacyJSON.utf8))
        check(legacy.first?.customAction == nil && legacy.first?.customTimeout == 120, "Old settings inherit the existing action")
        var override = configured
        override.customAction = .hide
        check(try! JSONDecoder().decode(MonitoredApp.self, from: JSONEncoder().encode(override)) == override, "Per-app action round trip")
        check(IdleAction.standardQuit.rawValue == 0 && IdleAction.forceQuit.rawValue == 1, "Legacy quit values stay stable")
        preview.applyPreviewScenario("Countdown")
        check(preview.isSystemIdle, "Idle card appears past grace")
        preview.systemIdleTime = 0
        check(!preview.isSystemIdle, "Input hides the idle card")
        preview.systemIdleTime = 1.25
        check(!preview.isSystemIdle, "Grace boundary does not show idle")
        preview.systemIdleTime = 5
        preview.isMonitoring = false
        check(!preview.isSystemIdle, "Pause hides idle card")
        preview.applyPreviewScenario("Empty")
        preview.systemIdleTime = 5
        check(!preview.isSystemIdle, "No configuration hides idle card")
        preview.applyPreviewScenario("Countdown")
        preview.quitMethod = 2
        check(preview.closingQueue.allSatisfy { $0.action == .hide }, "Preview default action updates live queue labels")
        preview.runningStates[0].action = .hide
        check(preview.monitoringPhase.subtitle.contains("hide"), "Hide deadline uses action-aware copy")
        preview.runningStates[0].isHidden = true
        check(preview.closingQueue.count == 1 && preview.runningAppCount == 2, "Hidden app stays running but leaves Hide queue")
        preview.runningStates[0].action = .standardQuit
        check(preview.closingQueue.count == 2, "Hidden apps can still be configured to quit")
        let tipsPreview = AppState(preview: true)
        check(!tipsPreview.tipsDismissed && tipsPreview.isUnsavedFallbackEnabled, "Setup tips visible and fallback enabled by default")
        tipsPreview.unsavedWorkAction = .hide
        tipsPreview.quitMethod = 1
        check(!tipsPreview.isUnsavedFallbackEnabled, "Force Quit disables fallback controls")
        tipsPreview.quitMethod = 2
        check(!tipsPreview.isUnsavedFallbackEnabled, "Hide disables fallback controls")
        tipsPreview.quitMethod = 0
        check(tipsPreview.isUnsavedFallbackEnabled && tipsPreview.unsavedWorkAction == .hide, "Returning to Standard Quit preserves fallback preference")
        check(tipsPreview.needsAccessibilityTip, "Missing access shows the Accessibility step first")
        tipsPreview.isAccessibilityGranted = true
        check(!tipsPreview.needsAccessibilityTip && !tipsPreview.tipsDismissed, "Granting access automatically advances to settings review")
        tipsPreview.isAccessibilityGranted = false
        tipsPreview.dismissCurrentTip()
        check(!tipsPreview.needsAccessibilityTip && !tipsPreview.tipsDismissed, "Dismiss advances to settings review without requiring permission")
        tipsPreview.dismissCurrentTip()
        check(tipsPreview.tipsDismissed, "Dismissing settings review hides setup tips")
        tipsPreview.needsAccessibilityRecovery = true
        check(tipsPreview.showsSetupTips, "Missing-access repair overrides previously dismissed setup tips")
        tipsPreview.dismissCurrentTip()
        check(!tipsPreview.showsSetupTips, "Repair reminder can be dismissed without a permission change")
        tipsPreview.showAccessibilityGuidance()
        check(tipsPreview.accessibilityHighlightRequest == 1, "Tips request targeted Accessibility attention")
        check(!AppState(preview: true).sendCloseNotifications, "Notifications default off")
        check(CloseNotification.body(names: ["One", "Two"]).contains("One, Two"), "Notification combines small batches")
        check(CloseNotification.body(names: (1...12).map { "App \($0)" }).contains("9 more"), "Exact overflow count")
        check(!CloseNotification.body(names: ["One\nTwo\tThree"]).contains("\n"), "Control characters removed")
        check(CloseNotification.body(names: [String(repeating: "🌙", count: 200)]).count < 120, "Long Unicode name bounded safely")
        check(!SaveWarningEvidence(editedDocument: true, dialog: true, save: true, discard: false, cancel: true).isConfirmed,
              "An arbitrary sheet/save panel cannot prove a quit warning")
        check(!SaveWarningEvidence(editedDocument: false, dialog: true, save: true, discard: true, cancel: true).isConfirmed,
              "A dialog without an edited-document report cannot force quit")
        check(SaveWarningEvidence(editedDocument: true, dialog: true, save: true, discard: true, cancel: true).isConfirmed,
              "Both edited document and recognized decision controls are required")
        check(SaveWarningEvidence(editedDocument: false, dialog: true, save: true, discard: true, cancel: true, nativeSaveDecision: true).isConfirmed,
              "Native keep/discard panel reports an unsaved draft even after autosave clears edited flag")
        check(!SaveWarningEvidence(editedDocument: false, dialog: true, save: true, discard: false, cancel: true, nativeSaveDecision: false).isConfirmed,
              "Ordinary Save As panels never permit fallback escalation")
        check(AppState(preview: true).unsavedWorkAction == .leaveOpen, "Save-warning policy defaults to preserving work")
        try lifecycleChecks { condition, message in check(condition, message) }
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
