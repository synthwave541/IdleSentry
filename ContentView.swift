import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: Tab = .general
    
    enum Tab {
        case general
        case apps
        case permissions
        case about
    }
    
    private var windowTitle: String {
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "ISBuildVersion") as? String ?? "1.0.0"
        let buildType = Bundle.main.object(forInfoDictionaryKey: "ISBuildType") as? String ?? "custom"
        if buildType == "testing" {
            return "IdleSentry \(buildVersion) — For developer testing only"
        } else if buildType == "custom" {
            return "IdleSentry \(buildVersion) (Custom Build)"
        } else {
            return "IdleSentry \(buildVersion)"
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                // Sidebar Navigation
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                        .frame(height: 28) // Space for traffic light buttons
                    
                    // App Branding (Real AppIcon)
                    HStack(spacing: 10) {
                        if let nsImage = NSImage(named: "AppIcon") {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 24, height: 24)
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Text("IdleSentry")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    
                    // Navigation Buttons
                    sidebarButton(title: "General", icon: "gearshape.fill", tab: .general)
                    sidebarButton(title: "Monitored Apps", icon: "app.badge.fill", tab: .apps)
                    sidebarButton(title: "Permissions", icon: "shield.righthalf.filled", tab: .permissions)
                    sidebarButton(title: "About", icon: "info.circle.fill", tab: .about)
                    
                    Spacer()
                    
                    // Status Box
                    statusBox
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appState.appsPendingClose.isEmpty)
                        .padding(12)
                }
                .frame(width: 170)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                    .padding(.top, 28)
                
                // Detail View Area
                ZStack {
                    Color(NSColor.controlBackgroundColor)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 28) // Space for transparent titlebar
                        
                        switch selectedTab {
                        case .general:
                            GeneralSettingsView(appState: appState)
                        case .apps:
                            MonitoredAppsView(appState: appState)
                        case .permissions:
                            PermissionsView(appState: appState)
                        case .about:
                            AboutView()
                        }
                    }
                    
                    // Bottom fade gradient overlay
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [
                                Color(NSColor.controlBackgroundColor).opacity(0),
                                Color(NSColor.controlBackgroundColor)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 40)
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.all)
            
            // Centered Titlebar Overlay & Border
            VStack(spacing: 0) {
                ZStack {
                    Text(windowTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(height: 27)
                .frame(maxWidth: .infinity)
                
                // Dark themed bottom border
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1)
            }
            .frame(height: 28)
            .allowsHitTesting(false) // Let clicks/drags pass through to native titlebar
            .ignoresSafeArea(.all)
        }
        .ignoresSafeArea(.all)
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
    }
    
    private func sidebarButton(title: String, icon: String, tab: Tab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
    }
    
    
    // MARK: - Status Box
    @ViewBuilder
    private var statusBox: some View {
        let pendingApps = appState.appsPendingClose
        
        VStack(spacing: 0) {
            // Sliding idle notification card
            if !pendingApps.isEmpty {
                idleNotificationCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
            
            if pendingApps.isEmpty {
                // No jobs pending — green tinted box
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("No jobs pending")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green.opacity(0.15), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Countdown active — dark themed, larger box
                let countdown = Int(appState.countdownValue)
                let minutes = countdown / 60
                let seconds = countdown % 60
                let countdownText = countdown > 59 ? (seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s") : "\(countdown)s"
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quitting these apps in \(countdownText):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary.opacity(0.85))
                        .contentTransition(.numericText())
                    
                    // Overlapping app icons with animations
                    overlappingAppIcons(apps: pendingApps)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    // MARK: - Idle Notification Card (Sliding banner)
    @ViewBuilder
    private var idleNotificationCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Text("System is idle")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.bottom, 6)
    }
    
    // MARK: - Overlapping App Icons
    @ViewBuilder
    private func overlappingAppIcons(apps: [AppRunningState]) -> some View {
        let maxVisible = 5
        let visibleApps = Array(apps.prefix(maxVisible))
        let overflow = apps.count - maxVisible
        let iconSize: CGFloat = 22
        let overlap: CGFloat = 8
        
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, app in
                    appIconCircle(app: app, size: iconSize)
                        .offset(x: CGFloat(index) * (iconSize - overlap))
                        .zIndex(Double(visibleApps.count - index))
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.3)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: 6)),
                                removal: .scale(scale: 0.1)
                                    .combined(with: .opacity)
                            )
                        )
                }
            }
            .frame(
                width: CGFloat(visibleApps.count) * (iconSize - overlap) + overlap,
                alignment: .leading
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.1), value: visibleApps.count)
            
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.1), value: apps.map { $0.id })
    }
    
    /// Calculates the zoom multiplier needed to fill a circle without black edges.
    /// Checks corner pixels of the icon — if they're transparent/near-black, the icon
    /// is a squircle/rounded-rect and needs more zoom to fill the circular clip.
    private func iconZoomFactor(for icon: NSImage) -> CGFloat {
        guard let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 1.4
        }
        
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return 1.4 }
        
        // Create a bitmap context to read pixel data
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 1.4
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Sample corner pixels (top-left, top-right, bottom-left, bottom-right)
        let corners = [
            (0, 0),
            (width - 1, 0),
            (0, height - 1),
            (width - 1, height - 1)
        ]
        
        var transparentCorners = 0
        for (x, y) in corners {
            let offset = (y * bytesPerRow) + (x * bytesPerPixel)
            let alpha = pixelData[offset + 3] // Alpha channel
            if alpha < 30 { // Nearly transparent
                transparentCorners += 1
            }
        }
        
        // If most corners are transparent, it's a squircle — zoom more
        if transparentCorners >= 3 {
            return 1.45 // Squircle icons (like Pages, Keynote)
        } else if transparentCorners >= 1 {
            return 1.3  // Partially rounded
        } else {
            return 1.15 // Already fills the space well
        }
    }
    
    private func appIconCircle(app: AppRunningState, size: CGFloat) -> some View {
        Group {
            if let nsApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }),
               let icon = nsApp.icon {
                let zoom = iconZoomFactor(for: icon)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * zoom, height: size * zoom)
                    .frame(width: size, height: size) // Clip frame
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1.5)
                    )
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(app.name.prefix(1)))
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1.5)
                    )
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let secs = Int(seconds)
        if secs < 60 {
            return "\(secs)s"
        } else {
            let mins = secs / 60
            let remainingSecs = secs % 60
            return String(format: "%dm %02ds", mins, remainingSecs)
        }
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("General Settings")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.bottom, 2)
                
                // Active Monitoring Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Active Monitoring")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Temporarily disable or enable all idle app quitting.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.isMonitoring)
                            .toggleStyle(SwitchToggleStyle())
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.01))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
                
                // Idle Timer Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Inactivity Threshold")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text("Time a monitored app must sit in the background before it is automatically closed:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Slider(value: $appState.globalTimeout, in: 10...3600)
                            .accentColor(.accentColor)
                        
                        Text(formatTimeout(appState.globalTimeout))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    Text("Note: Default timeout is applied to all added applications unless custom overrides are set.")
                        .font(.system(size: 9, weight: .light))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.primary.opacity(0.01))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
                
                // Behavior Customizations Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Inactivity Behaviors")
                        .font(.system(size: 13, weight: .semibold))
                    
                    // Launch at Startup
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start in Background at Login")
                                .font(.system(size: 12, weight: .medium))
                            Text("Launch IdleSentry silently in the menu bar when you log in.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.launchAtStartup)
                            .toggleStyle(SwitchToggleStyle())
                    }
                    
                    Divider()
                    
                    // Termination Method
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Termination Method")
                            .font(.system(size: 12, weight: .medium))
                        
                        Picker("", selection: $appState.quitMethod) {
                            Text("Standard Quit (Recommended)").tag(0)
                            Text("Force Quit").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text("Standard quit sends a regular close command, letting apps save files. Force quit terminates immediately.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.01))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
            }
            .padding(20)
        }
    }
    
    private func formatTimeout(_ seconds: Double) -> String {
        let secs = Int(seconds)
        if secs < 60 {
            return "\(secs)s"
        } else {
            let mins = secs / 60
            let remainingSecs = secs % 60
            if remainingSecs == 0 {
                return "\(mins)m"
            } else {
                return "\(mins)m \(remainingSecs)s"
            }
        }
    }
}

// MARK: - Monitored Apps Tab
struct MonitoredAppsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monitored Applications")
                        .font(.system(size: 18, weight: .bold))
                    Text("Apps in this list will be terminated after being inactive.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: addAppDialog) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add App")
                    }
                }
                .buttonStyle(BorderedButtonStyle())
                .accentColor(.accentColor)
            }
            .padding(20)
            
            Divider()
            
            // List of monitored apps
            if appState.runningStates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No Apps Monitored")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Click 'Add App' above to monitor an application.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.runningStates) { state in
                        HStack(spacing: 12) {
                            // Represent App Icon
                            Image(systemName: "square.dashed.inset.filled")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(state.name)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(state.bundleIdentifier)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // App running status indicator
                            if state.isRunning {
                                Capsule()
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 60, height: 16)
                                    .overlay(
                                        Text("Running")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.green)
                                    )
                                
                                // Countdown/Active status
                                if state.timeRemaining < (state.isFrontmost ? appState.globalTimeout : appState.globalTimeout) && appState.isCountdownActive {
                                    // System is idle — show countdown for ALL running apps
                                    HStack(spacing: 3) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 9))
                                        Text(formatCountdown(state.timeRemaining))
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                } else if state.isFrontmost {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                } else {
                                    // Running but not frontmost, system not idle yet
                                    Text("Idle")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.08))
                                        .cornerRadius(4)
                                }
                            } else {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.08))
                                    .frame(width: 75, height: 16)
                                    .overlay(
                                        Text("Not Running")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.secondary)
                                    )
                            }
                            
                            // Delete button
                            Button(action: {
                                appState.removeApp(bundleId: state.bundleIdentifier)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(SidebarListStyle())
            }
        }
    }
    
    private func addAppDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.addApp(url: url)
        }
    }
    
    private func formatCountdown(_ seconds: Double) -> String {
        let secs = Int(seconds)
        let mins = secs / 60
        let remainingSecs = secs % 60
        return String(format: "%02d:%02d", mins, remainingSecs)
    }
}

// MARK: - Permissions Tab
struct PermissionsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("System Permissions")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.bottom, 2)
                
                Text("To function properly, IdleSentry uses standard macOS APIs to observe app switching and terminate background processes.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    
                // Accessibility Permission Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 22))
                            .foregroundColor(appState.isAccessibilityGranted ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Access")
                                .font(.system(size: 13, weight: .semibold))
                            
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(appState.isAccessibilityGranted ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)
                                Text(appState.isAccessibilityGranted ? "Access Granted" : "Access Pending Setup")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(appState.isAccessibilityGranted ? .green : .orange)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    Text("Accessibility permission is optional but highly recommended. It allows IdleSentry to monitor global keyboard and mouse events so it can pause countdowns when you step away from your desk, preventing your apps from being closed while you are away.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                    
                    if !appState.isAccessibilityGranted {
                        HStack(spacing: 10) {
                            Button(action: {
                                appState.requestAccessibility()
                            }) {
                                Text("Request Accessibility Access...")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                            .accentColor(.accentColor)
                            
                            Button(action: {
                                appState.openAccessibilitySettings()
                            }) {
                                Text("Open System Settings")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                        
                        Text("Tip: If already toggled on in System Settings, try toggling it off and back on. Each rebuild changes the app signature, requiring a re-grant.")
                            .font(.system(size: 10))
                            .foregroundColor(.orange.opacity(0.8))
                            .lineSpacing(2)
                            .padding(.top, 2)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("IdleSentry is fully authorized.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.01))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
                
                // Data Storage Card
                VStack(alignment: .leading, spacing: 6) {
                    Text("Data Storage")
                        .font(.system(size: 12, weight: .semibold))
                    Text("All preferences are stored in ~/Library/Preferences/com.zennoris.IdleSentry.plist. No other files are created. The app is fully compatible with AppCleaner and similar utilities for clean uninstallation.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.04))
                .cornerRadius(8)
                
                // Sandbox Status Card
                VStack(alignment: .leading, spacing: 6) {
                    Text("App Sandboxing: Off")
                        .font(.system(size: 12, weight: .semibold))
                    Text("IdleSentry runs outside the macOS sandbox. This ensures the app has sufficient rights to request running applications to quit. Absolutely no tracking or data transmission takes place.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.04))
                .cornerRadius(8)
            }
            .padding(20)
        }
        .onAppear {
            appState.checkAccessibility()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            appState.checkAccessibility()
        }
    }
}

// MARK: - About Tab
struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            
            // Branding graphic (Actual AppIcon)
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            } else {
                // Fallback graphic
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
                    
                    ZStack {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(.white)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .offset(y: 4)
                    }
                }
            }
            
            let buildVersion = Bundle.main.object(forInfoDictionaryKey: "ISBuildVersion") as? String ?? "1.0.0"
            VStack(spacing: 3) {
                Text("IdleSentry")
                    .font(.system(size: 20, weight: .bold))
                Text("Version \(buildVersion)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Text("A sleek, lightweight macOS menu-bar utility designed to protect your privacy by automatically quitting sensitive background apps when you step away.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 320)
                .padding(.vertical, 6)
                .lineSpacing(3)
            
            Divider()
                .frame(width: 160)
            
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("Developer: Anush Vishwakarma")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("zennoris.com")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                
                VStack(spacing: 2) {
                    Text("Copyright © 2026 Zennoris. All rights reserved.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("Privacy First • Free Utility")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
    }
}
