import Foundation
import AppKit
import Combine
import UserNotifications
import ApplicationServices
import ServiceManagement

struct MonitoredApp: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bundleIdentifier: String
    var path: String
    var customTimeout: Double?
    var customAction: IdleAction?
}

struct AppRunningState: Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let path: String
    var isRunning: Bool
    var isFrontmost: Bool
    var timeRemaining: Double
    var isHidden: Bool = false
    var isPlaybackProtected: Bool = false
    var action: IdleAction = .standardQuit
    var isActionPending: Bool { isRunning && !isPlaybackProtected && !(action == .hide && isHidden) }
}

class AppState: ObservableObject {
    /// UI previews never read/write user preferences, register login items, or monitor processes.
    let isPreview: Bool
    // All settings stored under the bundle identifier domain so AppCleaner can find them
    // Location: ~/Library/Preferences/com.zennoris.IdleSentry.plist
    private let saveWarningReported: (NSRunningApplication) -> Bool
    private let buildIdentity = BuildIdentity.current
    private let returningUser: Bool
    private let previousBuildIdentity: String?
    private let defaults: UserDefaults
    private let deliverNotification: (UNNotificationRequest) -> Void
    private let playbackProtection: () -> Set<pid_t>
    private var protectedPlaybackProcesses = Set<pid_t>()
    
    @Published var monitoredApps: [MonitoredApp] = [] {
        didSet {
            saveApps()
            if isPreview { updateStates() } else { reEvaluateTimerState() }
        }
    }
    
    @Published var globalTimeout: Double = 300 {
        didSet {
            let rounded = round(globalTimeout / 10.0) * 10.0
            if rounded != globalTimeout {
                globalTimeout = rounded
            }
            if !isPreview { defaults.set(globalTimeout, forKey: "globalTimeout") }
        }
    }
    

    
    var defaultAction: IdleAction { IdleAction(rawValue: quitMethod) ?? .standardQuit }

    private var loadingSettings = true
    @Published var sendCloseNotifications = false {
        didSet {
            guard !isPreview else { return }
            defaults.set(sendCloseNotifications, forKey: "sendCloseNotifications")
            if sendCloseNotifications && !oldValue && !loadingSettings { requestNotificationPermission() }
        }
    }
    @Published var protectFullscreenPlayback = true {
        didSet { if !isPreview { defaults.set(protectFullscreenPlayback, forKey: "protectFullscreenPlayback") } }
    }
    @Published var unsavedWorkAction: UnsavedWorkAction = .leaveOpen {
        didSet { if !isPreview { defaults.set(unsavedWorkAction.rawValue, forKey: "unsavedWorkAction") } }
    }
    var isUnsavedFallbackEnabled: Bool { defaultAction == .standardQuit }
    @Published var tipsDismissed = false {
        didSet { if !isPreview { defaults.set(tipsDismissed, forKey: "setupTipsDismissed") } }
    }
    @Published var accessibilityTipDismissed = false {
        didSet { if !isPreview { defaults.set(accessibilityTipDismissed, forKey: "accessibilityTipDismissed") } }
    }
    @Published var needsAccessibilityRecovery = false
    var showsSetupTips: Bool { !tipsDismissed || needsAccessibilityRecovery }
    var needsAccessibilityTip: Bool { needsAccessibilityRecovery || (!isAccessibilityGranted && !accessibilityTipDismissed) }
    func dismissCurrentTip() {
        if needsAccessibilityRecovery {
            if !isPreview { defaults.set(buildIdentity, forKey: "accessibilityRecoveryDismissedBuild") }
            needsAccessibilityRecovery = false
            accessibilityTipDismissed = true
        } else if needsAccessibilityTip { accessibilityTipDismissed = true } else { tipsDismissed = true }
    }
    @Published var accessibilityHighlightRequest = 0
    var accessibilityHighlightHandled = 0

    func showAccessibilityGuidance() { accessibilityHighlightRequest += 1 }

    @Published var notificationsDenied = false

    @Published var quitMethod: Int = 0 {
        didSet {
            if !isPreview { defaults.set(quitMethod, forKey: "quitMethod") }
            if isPreview { updateStates() }
        }
    }
    
    /// When enabled, IdleSentry kills ALL processes matching the app's bundle identifier
    /// (including helper/menu-bar processes that linger after a standard quit).
    /// Disabled by default to preserve the safer standard-quit behavior.
    @Published var fullyCloseApps: Bool = false {
        didSet {
            if !isPreview { defaults.set(fullyCloseApps, forKey: "fullyCloseApps") }
        }
    }
    
    @Published var isMonitoring: Bool = true {
        didSet {
            if !isPreview { defaults.set(isMonitoring, forKey: "isMonitoring") }
            reEvaluateTimerState()
        }
    }
    
    @Published var systemIdleTime: Double = 0.0
    @Published var isAccessibilityGranted: Bool = false
    @Published var runningStates: [AppRunningState] = []
    
    /// Grace period before countdown begins after system goes idle (silent delay)
    let countdownDelay: Double = 1.25
    /// At most one action attempt per process during an uninterrupted idle episode.
    private var attemptedProcesses = Set<pid_t>()
    private var appInteractions = AppInteractionGrace()
    private let monotonicNow: () -> TimeInterval
    private var fallbackHiddenProcesses: [pid_t: Date] = [:]
    private struct PendingQuit {
        let app: NSRunningApplication
        let name: String
        let requestedAt: Date
        let notify: Bool
        let cleanup: [NSRunningApplication]
        let fallback: UnsavedWorkAction
        var fallbackApplied = false
    }
    private var pendingQuits: [pid_t: PendingQuit] = [:]
    
    /// Whether the system has been idle long enough for countdowns to be active
    @Published var isCountdownActive: Bool = false
    
    /// All running monitored apps that are actively counting down (system is idle past the delay).
    /// Sorted by timeRemaining ascending so the app closing soonest appears first.
    var appsPendingClose: [AppRunningState] {
        guard isCountdownActive else { return [] }
        return runningStates
            .filter { $0.isActionPending && $0.timeRemaining < (appStatesDict[$0.bundleIdentifier] ?? globalTimeout) }
            .sorted { $0.timeRemaining < $1.timeRemaining }
    }
    
    /// The minimum time remaining across all pending-close apps (used for the countdown display)
    var countdownValue: Double {
        let pending = appsPendingClose
        guard !pending.isEmpty else { return 0 }
        return pending.map { $0.timeRemaining }.min() ?? 0
    }
    @Published var launchAtStartup: Bool = false {
        didSet {
            guard !isPreview else { return }
            let isCurrentlyEnabled = SMAppService.mainApp.status == .enabled
            if launchAtStartup != isCurrentlyEnabled {
                toggleLaunchAtStartup(launchAtStartup)
            }
        }
    }
    
    private var timer: Timer?
    private var appStatesDict: [String: Double] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init(preview: Bool = ProcessInfo.processInfo.arguments.contains("--ui-preview") ||
         Bundle.main.object(forInfoDictionaryKey: "ISPreviewMode") as? Bool == true,
         preferences: UserDefaults? = nil,
         monotonicNow: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         playbackProtection: @escaping () -> Set<pid_t> = PlaybackProtection.protectedProcesses,
         saveWarningReported: @escaping (NSRunningApplication) -> Bool = UnsavedWorkInspector.reportsSaveWarning,
         deliverNotification: @escaping (UNNotificationRequest) -> Void = { request in
             UNUserNotificationCenter.current().add(request) { error in
                 if let error { print("IdleSentry: Notification failed: \(error.localizedDescription)") }
             }
         }) {
        isPreview = preview
        self.monotonicNow = monotonicNow
        self.playbackProtection = playbackProtection
        self.deliverNotification = deliverNotification
        self.saveWarningReported = saveWarningReported
        defaults = preferences ?? UserDefaults(suiteName: "com.zennoris.IdleSentry") ?? .standard
        returningUser = defaults.object(forKey: "setupTipsDismissed") != nil || defaults.data(forKey: "monitoredApps") != nil
        previousBuildIdentity = defaults.string(forKey: "accessibilityLastSeenBuild")
        if preview {
            applyPreviewScenario("Ready")
            return
        }
        loadSettings()
        loadingSettings = false
        checkAccessibility()
        defaults.set(buildIdentity, forKey: "accessibilityLastSeenBuild")
        
        // Listen to workspace notifications to start/stop the timer in an event-driven way
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] notification in self?.handleAppInteraction(notification) }
            .store(in: &cancellables)
            
        nc.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.appInteractions.remove(app.processIdentifier)
                }
                self?.reEvaluateTimerState()
            }
            .store(in: &cancellables)
            
        nc.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in self?.handleAppInteraction(notification) }
            .store(in: &cancellables)
            
        nc.publisher(for: NSWorkspace.didUnhideApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.fallbackHiddenProcesses.removeValue(forKey: app.processIdentifier)
                    self?.reEvaluateTimerState()
                }
            }
            .store(in: &cancellables)

        // Initial state population
        updateStates()
        reEvaluateTimerState()
    }
    
    private func handleAppInteraction(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            recordAppInteraction(app)
        }
        reEvaluateTimerState()
    }

    /// Launchers/remappers can open or activate an app without resetting CGEvent's
    /// idle counter. Give only that monitored process a fresh inactivity interval.
    func recordAppInteraction(_ app: NSRunningApplication) {
        guard !isPreview, !app.isTerminated,
              monitoredApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }),
              pendingQuits[app.processIdentifier] == nil else { return }
        // A normal quit may itself activate the app to show a save decision.
        // Do not cancel that decision or re-arm an already pending action.
        appInteractions.record(app.processIdentifier, at: monotonicNow())
        attemptedProcesses.remove(app.processIdentifier)
    }

    /// Evaluates if any of the monitored applications are currently running, and starts/stops the timer accordingly.
    func reEvaluateTimerState() {
        guard !isPreview else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let runningApps = NSWorkspace.shared.runningApplications
            let anyMonitoredAppRunning = self.monitoredApps.contains { app in
                runningApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
            }
            
            if (self.isMonitoring && anyMonitoredAppRunning) || !self.pendingQuits.isEmpty {
                if self.timer == nil {
                    print("IdleSentry: Monitored app detected running. Starting timer.")
                    self.startTimer()
                }
            } else {
                if self.timer != nil {
                    print("IdleSentry: No monitored apps running or monitoring disabled. Stopping timer to conserve CPU.")
                    self.stopTimer()
                    self.systemIdleTime = 0.0
                    self.isCountdownActive = false
                    self.attemptedProcesses.removeAll()
                }
            }
            
            // Always update states so the UI correctly reflects current app list and run state
            self.updateStates()
        }
    }
    
    /// Explicitly check and publish accessibility permission status
    func checkAccessibility() {
        guard !isPreview else { return }
        let granted = AXIsProcessTrusted()
        if isAccessibilityGranted != granted { isAccessibilityGranted = granted }
        if granted {
            if defaults.string(forKey: "accessibilityLastTrustedBuild") != buildIdentity {
                defaults.set(buildIdentity, forKey: "accessibilityLastTrustedBuild")
            }
            defaults.removeObject(forKey: "accessibilityRecoveryDismissedBuild")
        }
        let needsRecovery = AccessRecovery.shouldShow(granted: granted, returningUser: returningUser,
            previousBuild: previousBuildIdentity, currentBuild: buildIdentity,
            lastTrustedBuild: defaults.string(forKey: "accessibilityLastTrustedBuild"),
            dismissedBuild: defaults.string(forKey: "accessibilityRecoveryDismissedBuild"))
        if needsAccessibilityRecovery != needsRecovery { needsAccessibilityRecovery = needsRecovery }
    }

    /// Prompt the user to grant accessibility access and open System Settings
    func requestAccessibility() {
        guard !isPreview else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }
    
    /// Open System Settings directly to the Accessibility privacy pane
    func openAccessibilitySettings() {
        guard !isPreview else { return }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func loadSettings() {
        let d = defaults
        
        if let timeoutVal = d.object(forKey: "globalTimeout") as? Double {
            self.globalTimeout = timeoutVal
        } else {
            self.globalTimeout = 300
        }
        
        self.quitMethod = IdleAction(rawValue: d.integer(forKey: "quitMethod"))?.rawValue ?? 0
        // Assign the stored value without prompting on launch. Permission is requested only on opt-in.
        tipsDismissed = d.bool(forKey: "setupTipsDismissed")
        accessibilityTipDismissed = d.bool(forKey: "accessibilityTipDismissed")
        unsavedWorkAction = UnsavedWorkAction(rawValue: d.integer(forKey: "unsavedWorkAction")) ?? .leaveOpen
        protectFullscreenPlayback = d.object(forKey: "protectFullscreenPlayback") as? Bool ?? true
        let storedNotifications = d.bool(forKey: "sendCloseNotifications")
        if storedNotifications { sendCloseNotifications = true }
        
        if d.object(forKey: "fullyCloseApps") != nil {
            self.fullyCloseApps = d.bool(forKey: "fullyCloseApps")
        } else {
            self.fullyCloseApps = false
        }
        
        if d.object(forKey: "isMonitoring") != nil {
            self.isMonitoring = d.bool(forKey: "isMonitoring")
        } else {
            self.isMonitoring = true
        }
        
        if let data = d.data(forKey: "monitoredApps"),
           let decoded = try? JSONDecoder().decode([MonitoredApp].self, from: data) {
            self.monitoredApps = decoded
        } else {
            self.monitoredApps = []
        }
        
        self.launchAtStartup = (SMAppService.mainApp.status == .enabled)
    }
    
    private func saveApps() {
        guard !isPreview else { return }
        if let encoded = try? JSONEncoder().encode(monitoredApps) {
            defaults.set(encoded, forKey: "monitoredApps")
        }
    }
    
    func addApp(url: URL) {
        let bundle = Bundle(url: url)
        let name = url.deletingPathExtension().lastPathComponent
        let bundleId = bundle?.bundleIdentifier ?? "unknown.\(name.lowercased())"
        
        if monitoredApps.contains(where: { $0.bundleIdentifier == bundleId }) {
            return
        }
        
        let newApp = MonitoredApp(name: name, bundleIdentifier: bundleId, path: url.path)
        monitoredApps.append(newApp)
        appStatesDict[bundleId] = newApp.customTimeout ?? globalTimeout
        updateStates()
    }
    
    func removeApp(bundleId: String) {
        monitoredApps.removeAll(where: { $0.bundleIdentifier == bundleId })
        appStatesDict.removeValue(forKey: bundleId)
        updateStates()
    }
    
    func startTimer() {
        guard !isPreview else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        // Poll accessibility
        checkAccessibility()
        
        checkIdleTime(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!))
    }

    /// Shared by the timer and isolated lifecycle integration checks.
    func checkIdleTime(_ seconds: Double) {
        guard !isPreview else { return }
        systemIdleTime = seconds.isFinite ? max(0, seconds) : 0
        let effectiveIdle = max(0, systemIdleTime - countdownDelay)
        isCountdownActive = isMonitoring && effectiveIdle > 0
        protectedPlaybackProcesses = isMonitoring && protectFullscreenPlayback ? playbackProtection() : []
        for pid in protectedPlaybackProcesses {
            // Playback can begin after an earlier close request. Never apply its
            // unsaved-work fallback or helper cleanup while protection is active.
            pendingQuits.removeValue(forKey: pid)
            attemptedProcesses.remove(pid)
            appInteractions.record(pid, at: monotonicNow())
        }
        collectCompletedQuits(allowFallback: isMonitoring && effectiveIdle > 0)
        if effectiveIdle == 0 {
            attemptedProcesses.removeAll()
            // Input returns control to the user. An unanswered save prompt is no longer
            // an automatic close; the next idle episode may request a new action.
            pendingQuits.removeAll()
        }
        updateStates(effectiveIdle: effectiveIdle)
        
        // If all monitored apps have quit, stop the timer
        let runningApps = NSWorkspace.shared.runningApplications
        let anyMonitoredAppRunning = monitoredApps.contains { app in
            runningApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
        }
        if !anyMonitoredAppRunning {
            reEvaluateTimerState()
        }
    }
    
    /// Check if a given app has any visible (non-minimized) windows on screen
    private func appHasVisibleWindows(pid: pid_t) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windowList.contains { info in
            guard let windowPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowLayer = info[kCGWindowLayer as String] as? Int else {
                return false
            }
            return windowPID == pid && windowLayer == 0
        }
    }
    
    private func updateStates(effectiveIdle: Double = 0) {
        if isPreview {
            runningStates = monitoredApps.map { app in
                var state = runningStates.first { $0.bundleIdentifier == app.bundleIdentifier } ??
                    AppRunningState(name: app.name, bundleIdentifier: app.bundleIdentifier, path: app.path,
                                    isRunning: false, isFrontmost: false, timeRemaining: globalTimeout)
                state.action = app.customAction ?? defaultAction
                return state
            }
            return
        }
        let runningApps = NSWorkspace.shared.runningApplications
        appInteractions.retain(Set(runningApps.map(\.processIdentifier)))
        let now = monotonicNow()
        fallbackHiddenProcesses = fallbackHiddenProcesses.filter { pid, requested in
            runningApps.contains { $0.processIdentifier == pid && ($0.isHidden || Date().timeIntervalSince(requested) < 2) }
        }
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        
        var newStates: [AppRunningState] = []
        
        for app in monitoredApps {
            let bundleId = app.bundleIdentifier
            let runningApp = runningApps.first { $0.bundleIdentifier == bundleId }
            let limit = app.customTimeout ?? globalTimeout
            let effectiveAction: IdleAction = runningApp.map { fallbackHiddenProcesses[$0.processIdentifier] != nil } == true
                ? .hide : (app.customAction ?? defaultAction)
            
            let isRunning = runningApp != nil
            let playbackProtected = protectFullscreenPlayback && runningApp.map {
                protectedPlaybackProcesses.contains($0.processIdentifier)
            } == true
            
            // isFrontmost is purely a UI label (visible windows check)
            let isFrontmost: Bool
            if let rApp = runningApp, frontmostApp?.bundleIdentifier == bundleId {
                isFrontmost = appHasVisibleWindows(pid: rApp.processIdentifier)
            } else {
                isFrontmost = false
            }
            
            // Use the newer of system input and this process's launch/activation.
            // No app inherits inactivity accumulated before it was opened.
            let timeRemaining: Double
            if isRunning && isMonitoring && !playbackProtected && runningApp?.isFinishedLaunching == true &&
               !(effectiveAction == .hide && runningApp?.isHidden == true) {
                let appIdle = runningApp.map {
                    appInteractions.effectiveIdle(for: $0.processIdentifier, systemIdle: effectiveIdle,
                                                  now: now, grace: countdownDelay)
                } ?? effectiveIdle
                timeRemaining = max(0, limit - appIdle)
                
                if timeRemaining <= 0 {
                    if let rApp = runningApp {
                        if attemptedProcesses.insert(rApp.processIdentifier).inserted {
                            performAction(effectiveAction, on: rApp, name: app.name)
                        }
                    }
                }
            } else {
                timeRemaining = limit
            }
            
            appStatesDict[bundleId] = limit // Store the limit, not remaining (remaining is computed)
            
            newStates.append(AppRunningState(
                name: app.name,
                bundleIdentifier: bundleId,
                path: app.path,
                isRunning: isRunning,
                isFrontmost: isFrontmost,
                timeRemaining: timeRemaining,
                isHidden: runningApp?.isHidden ?? false,
                isPlaybackProtected: playbackProtected,
                action: effectiveAction
            ))
        }
        
        self.runningStates = newStates
    }
    
    private func performAction(_ action: IdleAction, on app: NSRunningApplication, name: String) {
        if action == .hide {
            if !app.hide() { print("IdleSentry: Could not hide \(name)") }
            return
        }
        guard pendingQuits[app.processIdentifier] == nil else { return }
        let cleanup = fullyCloseApps ? NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == app.bundleIdentifier && $0.processIdentifier != app.processIdentifier && $0.activationPolicy != .regular
        } : []
        let accepted = action == .forceQuit ? app.forceTerminate() : app.terminate()
        // A refused normal quit may be exactly the save-decision case we must inspect.
        if accepted || action == .standardQuit {
            pendingQuits[app.processIdentifier] = PendingQuit(app: app, name: name, requestedAt: Date(),
                                                           notify: sendCloseNotifications, cleanup: cleanup,
                                                           fallback: action == .standardQuit && isUnsavedFallbackEnabled ? unsavedWorkAction : .leaveOpen)
        }
    }

    private func collectCompletedQuits(allowFallback: Bool) {
        var closed: [String] = []
        for (pid, pending) in pendingQuits {
            if pending.app.isTerminated {
                // Never kill a process displaying a save prompt, or a newly relaunched instance.
                for helper in pending.cleanup where !helper.isTerminated { helper.forceTerminate() }
                if pending.notify { closed.append(pending.name) }
                pendingQuits.removeValue(forKey: pid)
            } else if allowFallback && !pending.fallbackApplied && pending.fallback != .leaveOpen &&
                        Date().timeIntervalSince(pending.requestedAt) >= 1 &&
                        Date().timeIntervalSince(pending.requestedAt) <= 30 && saveWarningReported(pending.app) {
                // Only a positively reported save decision can trigger the explicit fallback.
                pendingQuits[pid]?.fallbackApplied = true
                if pending.fallback == .hide {
                    fallbackHiddenProcesses[pid] = Date()
                    pending.app.hide()
                    pendingQuits.removeValue(forKey: pid) // Hiding is not a completed close.
                } else {
                    pending.app.forceTerminate() // Opt-in policy explicitly permits losing unsaved work.
                }
            } else if Date().timeIntervalSince(pending.requestedAt) > 30 {
                // A declined quit/save prompt is not a successful close.
                pendingQuits.removeValue(forKey: pid)
            }
        }
        if sendCloseNotifications && !closed.isEmpty { sendNotification(names: closed) }
    }

    func refreshNotificationPermission() {
        guard !isPreview else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async { self?.notificationsDenied = settings.authorizationStatus == .denied }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { [weak self] _, _ in
            self?.refreshNotificationPermission()
        }
    }

    private func sendNotification(names: [String]) {
        let content = UNMutableNotificationContent()
        content.title = names.count == 1 ? "App closed automatically" : "Apps closed automatically"
        content.body = CloseNotification.body(names: names)
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        deliverNotification(request)
    }

    private func toggleLaunchAtStartup(_ enable: Bool) {
        let service = SMAppService.mainApp
        if enable {
            if service.status != .enabled {
                do {
                    try service.register()
                } catch {
                    print("Failed to register login item: \(error)")
                }
            }
        } else {
            if service.status == .enabled {
                do {
                    try service.unregister()
                } catch {
                    print("Failed to unregister login item: \(error)")
                }
            }
        }
    }

    /// Deterministic sample data for visual QA. Never invoked by a regular app launch.
    func applyPreviewScenario(_ scenario: String) {
        guard isPreview else { return }
        globalTimeout = 300
        isMonitoring = scenario != "Paused"
        isCountdownActive = scenario == "Countdown" || scenario == "Many Apps"
        systemIdleTime = isCountdownActive ? 251.25 : 0
        var samples = [
            ("Safari", "com.apple.Safari", "/Applications/Safari.app"),
            ("Notes", "com.apple.Notes", "/System/Applications/Notes.app"),
            ("TextEdit", "com.apple.TextEdit", "/System/Applications/TextEdit.app")
        ]
        let many = scenario == "Many Apps"
        if many {
            samples[0].0 = "Safari — Research, Reading & Work Profiles"
            for index in 4...24 {
                samples.append(("Sample Application \(index)", "preview.application.\(index)", "/System/Applications/Preview.app"))
            }
        }
        monitoredApps = scenario == "Empty" ? [] : samples.enumerated().map { index, sample in
            MonitoredApp(name: sample.0, bundleIdentifier: sample.1, path: sample.2,
                         customTimeout: many ? globalTimeout + Double(index) * 15 : nil)
        }
        appStatesDict = Dictionary(uniqueKeysWithValues: monitoredApps.map { ($0.bundleIdentifier, $0.customTimeout ?? globalTimeout) })
        runningStates = monitoredApps.enumerated().map { index, app in
            AppRunningState(name: app.name, bundleIdentifier: app.bundleIdentifier, path: app.path,
                            isRunning: scenario != "Waiting" && (many || index < 2), isFrontmost: index == 0,
                            timeRemaining: many ? 50 + Double(index) * 15 : scenario == "Countdown" ? 50 : globalTimeout,
                            action: app.customAction ?? defaultAction)
        }
    }
}
