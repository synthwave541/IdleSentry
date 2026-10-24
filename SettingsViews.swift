import SwiftUI
import AppKit
import ServiceManagement

struct InactivityRulesView: View {
    @ObservedObject var appState: AppState
    private let presets: [Double] = [30, 60, 300, 600, 1800]

    var body: some View {
        PageLayout("Inactivity Rules", subtitle: "Choose when apps hide or quit after inactivity.") {
            MonitoringToggleCard(appState: appState)
            SentryCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Default timeout").font(.headline)
                        Spacer()
                        Text(SentryFormat.duration(appState.globalTimeout))
                            .font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    Text("Time without keyboard or mouse activity before a running monitored app hides or quits.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Text("10s").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $appState.globalTimeout, in: 10...3600)
                            .accessibilityLabel("Default inactivity timeout")
                            .accessibilityValue(SentryFormat.duration(appState.globalTimeout))
                        Text("1h").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { timeout in
                            Button(SentryFormat.duration(timeout)) { appState.globalTimeout = timeout }
                                .tint(appState.globalTimeout == timeout ? .accentColor : nil)
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Set timeout to \(SentryFormat.duration(timeout))")
                        }
                    }
                    Text("Any keyboard or mouse activity resets the countdown. Apps with a saved custom timeout keep their override.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            SentryCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Action after inactivity").font(.headline)
                    Picker("Action after inactivity", selection: $appState.quitMethod) {
                        Text("Hide").tag(2)
                        Text("Standard Quit").tag(0)
                        Text("Force Quit").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden().accessibilityLabel("Action after inactivity")
                    Label(appState.defaultAction.detail,
                          systemImage: appState.defaultAction == .hide ? "eye.slash" : appState.defaultAction == .forceQuit ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(appState.defaultAction == .forceQuit ? SentryPalette.amber : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Choose a different action for individual apps in Monitored Apps.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    SettingToggle(title: "Close remaining background processes",
                                  detail: "Clean up matching background processes after the main app has exited. Never runs for Hide.",
                                  isOn: $appState.fullyCloseApps)
                        .disabled(appState.defaultAction == .hide)

                }
            }
            SentryCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Playback protection", systemImage: "play.rectangle").font(.headline)
                    SettingToggle(title: "Protect fullscreen playback",
                                  detail: "Keep a fullscreen app open while it asks macOS to keep the display awake. Applies to Hide, Standard Quit and Force Quit.",
                                  isOn: $appState.protectFullscreenPlayback)
                    Text("Enabled by default. Supports apps that report display-awake activity, including supported browser video and media players. A player may keep that request active while paused. When protection ends, the app gets a fresh inactivity timeout. Windowed playback and Picture in Picture are not covered.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            SentryCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label("When an app reports unsaved work", systemImage: "doc.badge.ellipsis").font(.headline)
                    Text("After Standard Quit, choose what happens when an app reports a recognized save warning.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Picker("Unsaved work fallback", selection: $appState.unsavedWorkAction) {
                        ForEach(UnsavedWorkAction.allCases) { action in Text(action.title).tag(action) }
                    }
                    .pickerStyle(.segmented).labelsHidden().accessibilityLabel("Unsaved work fallback")
                    Label(appState.unsavedWorkAction == .forceQuit
                          ? "Force Quit discards unsaved changes. This fallback applies only after a recognized save warning."
                          : appState.unsavedWorkAction == .hide
                          ? "Hide the app and its save warning while keeping unsaved work open. Click its Dock icon to return."
                          : "Keep the app and its save warning open so you can decide what to save.",
                          systemImage: appState.unsavedWorkAction == .forceQuit ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(appState.unsavedWorkAction == .forceQuit ? SentryPalette.amber : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Requires Accessibility access. Recognizes native keep/discard save panels and English Save / Don’t Save / Cancel warnings with an edited-document signal. Other apps stay open. Input or pausing cancels the fallback; a slow quit alone never triggers it.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !appState.isAccessibilityGranted {
                        Button("Request Accessibility Access…") { appState.requestAccessibility() }
                            .disabled(appState.isPreview)
                    }
                }
            }
            .disabled(!appState.isUnsavedFallbackEnabled)
            .opacity(appState.isUnsavedFallbackEnabled ? 1 : 0.45)
            .help(appState.isUnsavedFallbackEnabled ? "Applies after Standard Quit" : "Select Standard Quit to configure the unsaved-work fallback")
            Label("Save your work before testing automatic closing.", systemImage: "doc.badge.clock")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SettingToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).accessibilityLabel(title)
        }
    }
}

struct SystemSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var loginStatus: SMAppService.Status = .notRegistered
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var accessibilityHighlight = false

    var body: some View {
        ScrollViewReader { scroll in
        PageLayout("System & Startup", subtitle: "Keep IdleSentry close at hand, quietly in your menu bar.") {
            SentryCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Startup", systemImage: "power").font(.headline)
                    SettingToggle(title: "Launch at login", detail: "Start IdleSentry in the menu bar when you sign in to your Mac.", isOn: $appState.launchAtStartup)
                    if !appState.isPreview && loginStatus == .requiresApproval {
                        Label("macOS needs your approval in System Settings → General → Login Items.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(SentryPalette.amber)
                    }
                    Divider()
                    Label("Closing this window keeps monitoring active in the menu bar. Use Quit IdleSentry from its menu to exit.", systemImage: "menubar.rectangle")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            SentryCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Notifications", systemImage: "bell").font(.headline)
                    SettingToggle(title: "Send notifications after closing apps",
                                  detail: "Show a silent notification when monitored apps finish closing. Hidden apps do not send notifications.",
                                  isOn: $appState.sendCloseNotifications)
                    if appState.sendCloseNotifications && appState.notificationsDenied {
                        Text("Notifications are blocked by macOS. Allow IdleSentry in System Settings → Notifications.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Open Notification Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                        }
                        .disabled(appState.isPreview)
                    }
                }
            }
            SentryCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Accessibility", systemImage: "hand.raised").font(.headline)
                        Spacer()
                        Label(appState.isAccessibilityGranted ? "Granted" : "Not granted",
                              systemImage: appState.isAccessibilityGranted ? "checkmark.circle.fill" : "circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Accessibility lets IdleSentry recognize edited documents and supported save warnings for the unsaved-work fallback. The inactivity timer works without it. IdleSentry does not record what you type.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Accessibility status does not pause monitoring. To keep apps open while you’re away, pause monitoring on the Dashboard.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        if !appState.isAccessibilityGranted {
                            Button("Request Access…") { appState.requestAccessibility() }
                        }
                        Button("Open System Settings") { appState.openAccessibilitySettings() }
                    }
                    .disabled(appState.isPreview)
                }
            }
            .id("accessibility-settings")
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor.opacity(accessibilityHighlight ? 0.9 : 0), lineWidth: 2))
            SentryCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Private by design", systemImage: "lock.shield").font(.headline)
                    Text("Monitoring and preferences stay on this Mac. No account, analytics, or activity upload.")
                        .foregroundStyle(.secondary)
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Preferences location").font(.caption).foregroundStyle(.secondary)
                        Text("~/Library/Preferences/com.zennoris.IdleSentry.plist")
                            .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .task(id: appState.accessibilityHighlightRequest) {
            guard appState.accessibilityHighlightRequest > appState.accessibilityHighlightHandled else { return }
            appState.accessibilityHighlightHandled = appState.accessibilityHighlightRequest
            scroll.scrollTo("accessibility-settings", anchor: .center)
            if reduceMotion {
                accessibilityHighlight = true
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                accessibilityHighlight = false
            } else {
                for _ in 0..<2 {
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.25)) { accessibilityHighlight = true }
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) { accessibilityHighlight = false }
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        } // ScrollViewReader
        .onAppear(perform: refreshSystemState)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refreshSystemState() }
    }

    private func refreshSystemState() {
        guard !appState.isPreview else { return }
        appState.checkAccessibility()
        appState.refreshNotificationPermission()
        loginStatus = SMAppService.mainApp.status
    }
}

struct AboutView: View {
    var preview = false
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                BrandIcon(size: 88).padding(.top, 36)
                VStack(spacing: 7) {
                    Text("IdleSentry").font(.system(size: 30, weight: .bold))
                    Text("Version \(SentryFormat.version)").foregroundStyle(.secondary)
                    if let type = Bundle.main.object(forInfoDictionaryKey: "ISBuildType") as? String,
                       type == "custom" || type == "testing" {
                        Text(type == "custom" ? "Custom build" : "Development build")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("A little peace of mind when you step away.")
                    .font(.system(size: 17, weight: .medium)).multilineTextAlignment(.center)
                Text("IdleSentry quietly watches for inactivity and quits the apps you choose. Native to your Mac. Private by design.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 360).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Link(destination: URL(string: "https://zennoris.com")!) {
                        Label("Visit Website", systemImage: "arrow.up.right")
                    }.buttonStyle(.borderedProminent)
                    Link("Source Code", destination: URL(string: "https://github.com/synthwave541/IdleSentry")!)
                        .buttonStyle(.bordered)
                }
                UpdateSettingsView(preview: preview)
                Divider().frame(maxWidth: 300).padding(.vertical, 6)
                VStack(spacing: 8) {
                    Text("Made by Anush Vishwakarma").font(.system(size: 12, weight: .medium))
                    Link("zennoris.com", destination: URL(string: "https://zennoris.com")!).font(.caption)
                    Text("Free and open source · Apache License 2.0").font(.caption).foregroundStyle(.secondary)
                    Text("© 2026 Zennoris").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(28)
        }
    }
}
