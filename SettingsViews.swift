import SwiftUI
import AppKit
import ServiceManagement

struct InactivityRulesView: View {
    @ObservedObject var appState: AppState
    private let presets: [Double] = [30, 60, 300, 600, 1800]

    var body: some View {
        PageLayout("Inactivity Rules", subtitle: "Set when apps close and how they quit.") {
            MonitoringToggleCard(appState: appState)
            SentryCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Default timeout").font(.headline)
                        Spacer()
                        Text(SentryFormat.duration(appState.globalTimeout))
                            .font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    Text("Time without keyboard or mouse activity before a running monitored app is asked to quit.")
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
                    Text("Quit method").font(.headline)
                    Picker("Quit method", selection: $appState.quitMethod) {
                        Text("Standard Quit").tag(0)
                        Text("Force Quit").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden().accessibilityLabel("Quit method")
                    Label(appState.quitMethod == 1
                          ? "Force Quit ends the app immediately. Unsaved changes can be lost."
                          : "Standard Quit requests a normal quit. An app may ask you to save or refuse to close.",
                          systemImage: appState.quitMethod == 1 ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(appState.quitMethod == 1 ? SentryPalette.amber : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    SettingToggle(title: "Close remaining background processes",
                                  detail: "Force-terminate remaining processes with the same app identifier shortly after the quit request. This can interrupt saving.",
                                  isOn: $appState.fullyCloseApps)
                }
            }
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

    var body: some View {
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Accessibility", systemImage: "hand.raised").font(.headline)
                        Spacer()
                        Label(appState.isAccessibilityGranted ? "Granted" : "Not granted",
                              systemImage: appState.isAccessibilityGranted ? "checkmark.circle.fill" : "circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Check or manage IdleSentry’s Accessibility access here. Monitoring reads system idle time; it does not record what you type.")
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
        .onAppear(perform: refreshSystemState)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refreshSystemState() }
    }

    private func refreshSystemState() {
        guard !appState.isPreview else { return }
        appState.checkAccessibility()
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
