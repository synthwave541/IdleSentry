import AppKit
import Combine
import SwiftUI
import Sparkle

/// Sparkle owns update state, verification, installation and preferences.
/// Creating this object does not start networking; preview never starts it.
final class UpdateService: ObservableObject {
    static let shared = UpdateService()
    let controller = SPUStandardUpdaterController(startingUpdater: false,
                                                  updaterDelegate: nil, userDriverDelegate: nil)
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = true
    private var started = false

    private init() {
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticChecks)
    }

    func start(preview: Bool) {
        guard !preview, !started else { return }
        started = true
        controller.startUpdater()
    }

    func check() {
        guard started, canCheck else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard started else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
    }
}

struct UpdateSettingsView: View {
    let preview: Bool
    var body: some View {
        if preview {
            Text("Updates are disabled in UI preview.").font(.caption).foregroundStyle(.secondary)
        } else {
            LiveUpdateSettingsView()
        }
    }
}

private struct LiveUpdateSettingsView: View {
    @ObservedObject private var updates = UpdateService.shared
    var body: some View {
        SentryCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Software updates", systemImage: "arrow.triangle.2.circlepath").font(.headline)
                Text("Checks GitHub for new releases. Downloads and installation require your approval. Your apps and activity stay on this Mac.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updates.automaticChecks }, set: { updates.setAutomaticChecks($0) }))
                Button("Check for Updates…") { updates.check() }.disabled(!updates.canCheck)
            }
        }.frame(maxWidth: 440)
    }
}
