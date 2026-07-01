import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var preferencesWindow: NSWindow?
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the app to run as an accessory (LSUIElement = 1) initially, so no dock icon
        NSApp.setActivationPolicy(.accessory)
        if let iconImage = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = iconImage
        }
        
        // Setup menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Observe monitoring state to dynamically update icon
        appState.$isMonitoring
            .receive(on: RunLoop.main)
            .sink { [weak self] isMonitoring in
                self?.updateStatusItemIcon(isMonitoring: isMonitoring)
            }
            .store(in: &cancellables)
        
        setupMenu()
        
        // Only show preferences window if NOT launched as a login item
        // When started at login, the app should stay silently in the menu bar
        let isLoginLaunch = (appState.launchAtStartup && isLaunchedAtLogin())
        if !isLoginLaunch {
            showPreferences()
        }
    }
    
    /// Detect if the app was launched as a login item by checking the launch event
    private func isLaunchedAtLogin() -> Bool {
        // If the app was launched by the system (login item), the Apple Event descriptor
        // won't have the "resume" event that a user double-click launch would have.
        // A simpler heuristic: if launched within a few seconds of system boot, it's a login item.
        let uptime = ProcessInfo.processInfo.systemUptime
        return uptime < 120 // Launched within 2 minutes of boot = likely login item
    }
    
    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    // NSMenuDelegate: Dynamically populate menu bar items on click
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let titleItem = NSMenuItem(title: "IdleSentry: \(appState.isMonitoring ? "Monitoring" : "Paused")", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Dynamic Monitoring Toggle
        let toggleMonitoringItem = NSMenuItem(
            title: appState.isMonitoring ? "Pause Monitoring" : "Resume Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: "p"
        )
        menu.addItem(toggleMonitoringItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Monitored Apps list with remaining times
        if !appState.runningStates.isEmpty {
            let appsHeader = NSMenuItem(title: "Monitored Apps:", action: nil, keyEquivalent: "")
            appsHeader.isEnabled = false
            menu.addItem(appsHeader)
            
            for state in appState.runningStates {
                let statusText: String
                if state.isRunning {
                    if state.isFrontmost {
                        statusText = "Active"
                    } else {
                        let secs = Int(state.timeRemaining)
                        let mins = secs / 60
                        let remainingSecs = secs % 60
                        statusText = String(format: "%02d:%02d", mins, remainingSecs)
                    }
                } else {
                    statusText = "Not Running"
                }
                
                let item = NSMenuItem(title: "  \(state.name) (\(statusText))", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit IdleSentry", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc func toggleMonitoring() {
        appState.isMonitoring.toggle()
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let contentView = ContentView(appState: appState)
            
            // Create a window that looks modern and clean
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            
            // Build version from Info.plist
            let buildVersion = Bundle.main.object(forInfoDictionaryKey: "ISBuildVersion") as? String ?? "1.0.0"
            let buildType = Bundle.main.object(forInfoDictionaryKey: "ISBuildType") as? String ?? "custom"
            
            if buildType == "testing" {
                window.title = "IdleSentry \(buildVersion) — For developer testing only"
            } else if buildType == "custom" {
                window.title = "IdleSentry \(buildVersion) (Custom Build)"
            } else {
                window.title = "IdleSentry \(buildVersion)"
            }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: contentView)
            
            self.preferencesWindow = window
        }
        
        // Promote to regular application dynamically so we get a Dock icon and standard menu bar
        NSApp.setActivationPolicy(.regular)
        if let iconImage = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = iconImage
        }
        
        // Construct system menu bar so keyboard shortcuts work
        setupSystemMainMenu()
        
        // Bring window to the front
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupSystemMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenu = NSMenu(title: "IdleSentry")
        appMenu.addItem(NSMenuItem(title: "About IdleSentry", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide IdleSentry", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit IdleSentry", action: #selector(quitApp), keyEquivalent: "q"))
        
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu (crucial for Copy/Paste shortcuts in SwiftUI text fields!)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Demote back to accessory so it hides from the Dock and sits only in the menu bar
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateStatusItemIcon(isMonitoring: Bool) {
        if let button = statusItem?.button {
            let symbolName = isMonitoring ? "shield" : "shield.slash"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "IdleSentry")
            button.image?.isTemplate = true
        }
    }
}
