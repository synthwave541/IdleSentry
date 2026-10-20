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
        
        let phase = appState.monitoringPhase
        let summary = NSMenuItem(title: phase.isCountingDown ? "\(phase.subtitle) · \(phase.title)" : phase.title,
                                 action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)
        if !appState.runningStates.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for state in appState.runningStates {
                let item = NSMenuItem(title: "\(state.name) · \(state.isRunning ? "Running" : "Not running")",
                                      action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Open IdleSentry…", action: #selector(showPreferences), keyEquivalent: ","))
        
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
                contentRect: NSRect(x: 0, y: 0, width: 1040, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.contentMinSize = NSSize(width: 800, height: 560)
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
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: contentView)
            // Restore after hosting establishes its fitting size, then remember future resizes.
            let frameName = appState.isPreview ? "IdleSentry.PreviewWindow" : "IdleSentry.MainWindow"
            if !window.setFrameUsingName(frameName) {
                window.setContentSize(NSSize(width: 1040, height: 740))
                window.center()
            }
            window.setFrameAutosaveName(frameName)
            
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
        appMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(showRules), keyEquivalent: ","))
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
        
        let viewMenu = NSMenu(title: "View")
        let sidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "s")
        sidebarItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(sidebarItem)
        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        if appState.isPreview {
            let previewMenu = NSMenu(title: "Preview")
            for scenario in ["Ready", "Countdown", "Many Apps", "Paused", "Empty", "Waiting"] {
                let item = NSMenuItem(title: scenario, action: #selector(previewScenario(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = scenario
                previewMenu.addItem(item)
            }
            previewMenu.addItem(.separator())
            for appearance in ["System", "Light", "Dark"] {
                let item = NSMenuItem(title: appearance, action: #selector(previewAppearance(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = appearance
                previewMenu.addItem(item)
            }
            previewMenu.addItem(.separator())
            for size in ["Compact Window", "Default Window", "Large Window"] {
                let item = NSMenuItem(title: size, action: #selector(previewWindowSize(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = size
                previewMenu.addItem(item)
            }
            let item = NSMenuItem()
            item.submenu = previewMenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }
    
    @objc func showAbout() {
        showPreferences()
        NotificationCenter.default.post(name: .sentryShowAbout, object: nil)
    }
    
    @objc func showRules() {
        showPreferences()
        NotificationCenter.default.post(name: .sentryShowRules, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopTimer()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    @objc private func previewScenario(_ sender: NSMenuItem) {
        guard appState.isPreview, let scenario = sender.representedObject as? String else { return }
        appState.applyPreviewScenario(scenario)
    }

    @objc private func previewAppearance(_ sender: NSMenuItem) {
        guard appState.isPreview, let name = sender.representedObject as? String else { return }
        NSApp.appearance = name == "System" ? nil : NSAppearance(named: name == "Dark" ? .darkAqua : .aqua)
    }

    @objc private func previewWindowSize(_ sender: NSMenuItem) {
        guard appState.isPreview, let name = sender.representedObject as? String else { return }
        let size = name == "Compact Window" ? NSSize(width: 800, height: 560)
            : name == "Large Window" ? NSSize(width: 1200, height: 860) : NSSize(width: 1040, height: 740)
        preferencesWindow?.setContentSize(size)
        preferencesWindow?.center()
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
