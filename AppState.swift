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
}

struct AppRunningState: Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let path: String
    var isRunning: Bool
    var isFrontmost: Bool
    var timeRemaining: Double
}

class AppState: ObservableObject {
    // All settings stored under the bundle identifier domain so AppCleaner can find them
    // Location: ~/Library/Preferences/com.zennoris.IdleSentry.plist
    private static let defaults = UserDefaults(suiteName: "com.zennoris.IdleSentry") ?? UserDefaults.standard
    
    @Published var monitoredApps: [MonitoredApp] = [] {
        didSet {
            saveApps()
            reEvaluateTimerState()
        }
    }
    
    @Published var globalTimeout: Double = 300 {
        didSet {
            AppState.defaults.set(globalTimeout, forKey: "globalTimeout")
        }
    }
    

    
    @Published var quitMethod: Int = 0 {
        didSet {
            AppState.defaults.set(quitMethod, forKey: "quitMethod")
        }
    }
    
    @Published var isMonitoring: Bool = true {
        didSet {
            AppState.defaults.set(isMonitoring, forKey: "isMonitoring")
            reEvaluateTimerState()
        }
    }
    
    @Published var systemIdleTime: Double = 0.0
    @Published var isAccessibilityGranted: Bool = false
    @Published var runningStates: [AppRunningState] = []
    
    /// Grace period before countdown begins after system goes idle (silent delay)
    let countdownDelay: Double = 1.25
    /// Recently quit apps — bundle IDs with quit timestamps to avoid zombie re-detection
    private var recentlyQuitApps: [String: Date] = [:]
    
    /// Whether the system has been idle long enough for countdowns to be active
    @Published var isCountdownActive: Bool = false
    
    /// All running monitored apps that are actively counting down (system is idle past the delay).
    /// Sorted by timeRemaining ascending so the app closing soonest appears first.
    var appsPendingClose: [AppRunningState] {
        guard isCountdownActive else { return [] }
        return runningStates
            .filter { $0.isRunning && $0.timeRemaining < (appStatesDict[$0.bundleIdentifier] ?? globalTimeout) }
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
            let isCurrentlyEnabled = SMAppService.mainApp.status == .enabled
            if launchAtStartup != isCurrentlyEnabled {
                toggleLaunchAtStartup(launchAtStartup)
            }
        }
    }
    
    private var timer: Timer?
    private var appStatesDict: [String: Double] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSettings()
        requestNotificationPermission()
        isAccessibilityGranted = AXIsProcessTrusted()
        
        // Listen to workspace notifications to start/stop the timer in an event-driven way
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] _ in self?.reEvaluateTimerState() }
            .store(in: &cancellables)
            
        nc.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] _ in self?.reEvaluateTimerState() }
            .store(in: &cancellables)
            
        nc.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in self?.reEvaluateTimerState() }
            .store(in: &cancellables)
            
        // Initial state population
        updateStates()
        reEvaluateTimerState()
    }
    
    /// Evaluates if any of the monitored applications are currently running, and starts/stops the timer accordingly.
    func reEvaluateTimerState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let runningApps = NSWorkspace.shared.runningApplications
            let anyMonitoredAppRunning = self.monitoredApps.contains { app in
                runningApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
            }
            
            if self.isMonitoring && anyMonitoredAppRunning {
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
                    self.recentlyQuitApps.removeAll()
                }
            }
            
            // Always update states so the UI correctly reflects current app list and run state
            self.updateStates()
        }
    }
    
    /// Explicitly check and publish accessibility permission status
    func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    /// Prompt the user to grant accessibility access and open System Settings
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }
    
    /// Open System Settings directly to the Accessibility privacy pane
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func loadSettings() {
        let d = AppState.defaults
        
        if let timeoutVal = d.object(forKey: "globalTimeout") as? Double {
            self.globalTimeout = timeoutVal
        } else {
            self.globalTimeout = 300
        }
        
        // pauseOnSystemIdle removed
        self.quitMethod = d.integer(forKey: "quitMethod")
        
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
        if let encoded = try? JSONEncoder().encode(monitoredApps) {
            AppState.defaults.set(encoded, forKey: "monitoredApps")
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
        isAccessibilityGranted = AXIsProcessTrusted()
        
        // Get system idle time (time since last mouse/keyboard event)
        systemIdleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        
        // The countdown is active once the system has been idle past the grace period
        let effectiveIdle = max(0, systemIdleTime - countdownDelay)
        isCountdownActive = effectiveIdle > 0
        
        // Clean up stale entries from recentlyQuitApps (older than 5 seconds)
        let now = Date()
        recentlyQuitApps = recentlyQuitApps.filter { now.timeIntervalSince($0.value) < 5.0 }
        
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
        let runningApps = NSWorkspace.shared.runningApplications
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        
        var newStates: [AppRunningState] = []
        
        for app in monitoredApps {
            let bundleId = app.bundleIdentifier
            let runningApp = runningApps.first { $0.bundleIdentifier == bundleId }
            let limit = app.customTimeout ?? globalTimeout
            
            // Skip recently-quit apps to avoid zombie re-detection
            if recentlyQuitApps[bundleId] != nil {
                appStatesDict[bundleId] = limit
                newStates.append(AppRunningState(
                    name: app.name,
                    bundleIdentifier: bundleId,
                    path: app.path,
                    isRunning: false,
                    isFrontmost: false,
                    timeRemaining: limit
                ))
                continue
            }
            
            let isRunning = runningApp != nil
            
            // isFrontmost is purely a UI label (visible windows check)
            let isFrontmost: Bool
            if let rApp = runningApp, frontmostApp?.bundleIdentifier == bundleId {
                isFrontmost = appHasVisibleWindows(pid: rApp.processIdentifier)
            } else {
                isFrontmost = false
            }
            
            // Countdown logic: based purely on system idle time
            // When user is active (effectiveIdle == 0), timeRemaining == limit (full timer)
            // When system is idle, timeRemaining counts down from limit
            let timeRemaining: Double
            if isRunning && isMonitoring {
                timeRemaining = max(0, limit - effectiveIdle)
                
                if timeRemaining <= 0 {
                    if let rApp = runningApp {
                        quitApp(rApp, name: app.name)
                        recentlyQuitApps[bundleId] = Date()
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
                timeRemaining: timeRemaining
            ))
        }
        
        self.runningStates = newStates
    }
    
    private func quitApp(_ app: NSRunningApplication, name: String) {
        print("IdleSentry: Quitting idle app \(name) (\(app.bundleIdentifier ?? ""))")
        
        let success: Bool
        if quitMethod == 1 {
            success = app.forceTerminate()
        } else {
            success = app.terminate()
        }
        
        if success {
            sendNotification(
                title: "App Closed Automatically",
                body: "\(name) was quit because it exceeded the idle timeout."
            )
        } else {
            print("Failed to terminate \(name)")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
}
