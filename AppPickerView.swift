import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppCandidate: Identifiable {
    let id: String
    let name: String
    let url: URL
    let isRunning: Bool

    static func discover() -> [AppCandidate] {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        var urls = running.compactMap(\.bundleURL)
        let roots = [URL(fileURLWithPath: "/Applications"),
                     URL(fileURLWithPath: "/System/Applications"),
                     FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root,
                    includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" { urls.append(url) }
        }
        let runningIDs = Set(running.compactMap(\.bundleIdentifier))
        var seen = Set<String>()
        return urls.compactMap { url -> AppCandidate? in
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  id != "com.zennoris.IdleSentry", id != Bundle.main.bundleIdentifier,
                  seen.insert(id).inserted else { return nil }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            return AppCandidate(id: id, name: name, url: url, isRunning: runningIDs.contains(id))
        }.sorted {
            if $0.isRunning != $1.isRunning { return $0.isRunning }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

struct AppPickerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [AppCandidate] = []
    @State private var search = ""
    @State private var selected = Set<String>()
    @State private var isLoading = true
    @State private var browseError: String?

    private var existingIDs: Set<String> { Set(appState.monitoredApps.map(\.bundleIdentifier)) }
    private var filtered: [AppCandidate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? candidates : candidates.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Add Applications").font(.system(size: 22, weight: .bold))
                Text("Choose apps to close when you step away. Running apps appear first.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search applications", text: $search).textFieldStyle(.plain)
                        .accessibilityLabel("Search applications")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }
                .padding(9).background(SentryPalette.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.12)))
                .padding(.top, 10)
            }.padding(24)
            Divider()
            if isLoading {
                ProgressView("Finding applications…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.title).foregroundStyle(.secondary)
                    Text("No matching applications").font(.headline)
                    Text("Try another name, or use Browse to find an app.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { app in
                            HStack(spacing: 12) {
                                Toggle(isOn: Binding(get: { selected.contains(app.id) }, set: { enabled in
                                    if enabled { selected.insert(app.id) } else { selected.remove(app.id) }
                                })) { EmptyView() }
                                .labelsHidden().toggleStyle(.checkbox)
                                .disabled(existingIDs.contains(app.id)).accessibilityLabel("Select \(app.name)")
                                ApplicationIcon(path: app.url.path, size: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name).font(.system(size: 13, weight: .medium))
                                    Text(app.id).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if existingIDs.contains(app.id) {
                                    Text("Already added").font(.caption).foregroundStyle(.secondary)
                                } else if app.isRunning {
                                    Text("Running").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .contentShape(Rectangle())
                            Divider().padding(.leading, 94)
                        }
                    }
                }
            }
            Divider()
            HStack(spacing: 10) {
                Button("Browse…", action: browse)
                Text(selected.isEmpty ? "" : "\(selected.count) selected").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(selected.count == 1 ? "Add App" : "Add Apps") {
                    for app in candidates where selected.contains(app.id) && !existingIDs.contains(app.id) {
                        appState.addApp(url: app.url)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(selected.isEmpty)
            }.padding(18)
        }
        .frame(width: 580, height: 590)
        .task {
            // Discovery stays off the main thread; AppKit icon lookup happens lazily on visible rows.
            let discovered = await Task.detached(priority: .userInitiated) { AppCandidate.discover() }.value
            if !Task.isCancelled { candidates = discovered; isLoading = false }
        }
        .alert("Couldn’t add application", isPresented: Binding(get: { browseError != nil }, set: { if !$0 { browseError = nil } })) {
            Button("OK", role: .cancel) { browseError = nil }
        } message: { Text(browseError ?? "") }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add Apps"
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            let valid = panel.urls.filter { url in
                guard let id = Bundle(url: url)?.bundleIdentifier else { return false }
                return id != "com.zennoris.IdleSentry" && id != Bundle.main.bundleIdentifier
            }
            guard !valid.isEmpty else { browseError = "Choose an application with a valid bundle identifier, other than IdleSentry itself."; return }
            for url in valid { appState.addApp(url: url) }
            dismiss()
        }
    }
}
