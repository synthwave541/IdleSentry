import SwiftUI
import AppKit

// MARK: - Window and native navigation

struct ContentView: View {
    @ObservedObject var appState: AppState
    @State private var selection: Destination? = .dashboard
    @State private var showingAppPicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Destination: String, CaseIterable, Identifiable {
        case dashboard, apps, rules, system, about
        var id: Self { self }
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .apps: return "Monitored Apps"
            case .rules: return "Inactivity Rules"
            case .system: return "System & Startup"
            case .about: return "About"
            }
        }
        var symbol: String {
            switch self {
            case .dashboard: return "house"
            case .apps: return "square.stack.3d.up"
            case .rules: return "timer"
            case .system: return "desktopcomputer"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("IdleSentry").font(.system(size: 16, weight: .semibold))
                        Text("v\(SentryFormat.version)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 18)

                List(selection: $selection) {
                    ForEach(Destination.allCases) { destination in
                        HStack(spacing: 8) {
                            Label(destination.title, systemImage: destination.symbol)
                            Spacer(minLength: 0)
                            if destination == .apps && appState.runningAppCount > 0 {
                                RunningCountBadge(count: appState.runningAppCount)
                            }
                        }
                        .padding(.vertical, 5)
                        .tag(destination)
                    }
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Navigation")
                .frame(height: 200)

                ScrollView {
                    if appState.showsSetupTips {
                        SidebarTips(appState: appState,
                                    reviewRules: { selection = .rules },
                                    reviewSystem: { selection = .system },
                                    reviewAccessibility: {
                                        selection = .system
                                        appState.showAccessibilityGuidance()
                                    })
                            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                VStack(spacing: 0) {
                    // Reveal inside its own viewport so the idle card rises from
                    // behind the status card without painting over its contents.
                    VStack(spacing: 0) {
                        if appState.isSystemIdle {
                            SystemIdleCard()
                                .padding(.bottom, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .clipped()
                    SidebarStatus(phase: appState.monitoringPhase, queueApps: appState.closingQueue)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.9),
                           value: appState.isSystemIdle)
                .padding(12)
                .layoutPriority(1)
            }
            .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 280)
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView(appState: appState, showApps: { selection = .apps },
                                  showRules: { selection = .rules }, addApps: { showingAppPicker = true })
                case .apps:
                    MonitoredAppsView(appState: appState, addApps: { showingAppPicker = true })
                case .rules:
                    InactivityRulesView(appState: appState)
                case .system:
                    SystemSettingsView(appState: appState)
                case .about:
                    AboutView(preview: appState.isPreview)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SentryPalette.canvas)
            .navigationTitle((selection ?? .dashboard).title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAppPicker = true } label: {
                        Label("Add Apps", systemImage: "plus")
                    }
                    .help("Choose applications to monitor (⌘N)")
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 560)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(appState: appState)
        }
        .onAppear { appState.checkAccessibility() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            if appState.showsSetupTips { appState.checkAccessibility() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sentryShowAbout)) { _ in selection = .about }
        .onReceive(NotificationCenter.default.publisher(for: .sentryShowRules)) { _ in selection = .rules }
    }
}

extension Notification.Name {
    static let sentryShowAbout = Notification.Name("IdleSentry.showAbout")
    static let sentryShowRules = Notification.Name("IdleSentry.showRules")
}

// MARK: - Shared visual components

enum SentryPalette {
    static let canvas = Color(nsColor: NSColor(name: "IdleSentryCanvas") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .windowBackgroundColor : NSColor(srgbRed: 0.955, green: 0.96, blue: 0.97, alpha: 1)
    })
    static let surface = Color(nsColor: NSColor(name: "IdleSentryCard") { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 0.16, green: 0.165, blue: 0.175, alpha: 1)
        }
        return .controlBackgroundColor
    })
    static let countdownAccent = Color(nsColor: NSColor(name: "IdleSentryCountdownAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.80, green: 0.67, blue: 0.46, alpha: 1)
            : NSColor(srgbRed: 0.50, green: 0.34, blue: 0.12, alpha: 1)
    })
    static let amber = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .systemYellow : NSColor(srgbRed: 0.53, green: 0.31, blue: 0, alpha: 1)
    })
}

struct SentryCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SentryPalette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.06)))
    }
}

struct PageLayout<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: Content
    init(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 27, weight: .bold)).accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 2)
                content
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct BrandIcon: View {
    let size: CGFloat
    var body: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
            .resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private enum AppIconCache {
    static let images = NSCache<NSString, NSImage>()
    static func icon(for path: String) -> NSImage {
        if let image = images.object(forKey: path as NSString) { return image }
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        let image = NSWorkspace.shared.icon(forFile: resolvedPath)
        images.setObject(image, forKey: path as NSString)
        return image
    }
}

struct ApplicationIcon: View {
    let path: String
    var size: CGFloat = 36
    var body: some View {
        Image(nsImage: AppIconCache.icon(for: path))
            .resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct RunningCountBadge: View {
    let count: Int
    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: count > 99 ? 8 : 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Color.red, in: Circle())
            .accessibilityLabel("\(count) monitored apps running")
    }
}

struct SidebarStatus: View {
    let phase: MonitoringPhase
    let queueApps: [AppRunningState]
    @State private var showingQueue = false

    var body: some View {
        Group {
            if !queueApps.isEmpty {
                Button { showingQueue.toggle() } label: { card }
                    .buttonStyle(.plain)
                    .accessibilityLabel(phase.isCountingDown
                        ? "\(phase.subtitle), \(phase.title) remaining, \(queueApps.count) apps in activity queue"
                        : "\(phase.title). View \(queueApps.count) monitored apps")
                    .accessibilityHint("Shows the full list of apps waiting to hide or quit")
                    .popover(isPresented: $showingQueue, arrowEdge: .trailing) {
                        PendingAppsPopover(apps: queueApps)
                    }
            } else {
                card.accessibilityElement(children: .combine)
                    .accessibilityLabel("\(phase.title). \(phase.subtitle)")
            }
        }
        .frame(height: phase.isCountingDown ? 110 : 88)
        .onChange(of: queueApps.isEmpty) { empty in
            if empty { showingQueue = false }
        }
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: phase.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(phase.isCountingDown ? SentryPalette.countdownAccent : Color.secondary)
                .frame(width: 20).padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(phase.title)
                    .font(phase.isCountingDown ? .system(size: 24, weight: .medium, design: .monospaced) : .system(size: 12, weight: .semibold))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                if case .countdown(let name, _, let action) = phase {
                    HStack {
                        Text(action == .hide ? "Next to hide" : "Next to close").font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 5) {
                        Text(name).font(.system(size: 11)).lineLimit(1).truncationMode(.tail)
                            .help(name)
                        Spacer(minLength: 0)
                        if queueApps.count > 1 {
                            Text("+\(queueApps.count - 1) more")
                                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                        }
                    }
                } else {
                    Text(phase.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.primary.opacity(0.04)))
        .contentShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct PendingAppsPopover: View {
    let apps: [AppRunningState]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Activity queue").font(.headline)
                Text("\(apps.count) \(apps.count == 1 ? "monitored app" : "monitored apps") · soonest first")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
            Divider()
            if apps.isEmpty {
                Text("No apps are waiting to hide or quit.").foregroundStyle(.secondary).padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(apps) { app in
                            HStack(spacing: 10) {
                                ApplicationIcon(path: app.path, size: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(2).help(app.name)
                                    Text(app.action.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                Text(app.timeRemaining <= 0 ? (app.action == .hide ? "Hiding…" : "Closing…") : SentryFormat.countdown(app.timeRemaining))
                                    .font(.system(size: 12, design: .monospaced)).monospacedDigit()
                                    .foregroundStyle(.secondary).fixedSize()
                            }
                            .padding(.horizontal, 16).frame(minHeight: 56)
                            .accessibilityElement(children: .combine)
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .frame(height: min(CGFloat(apps.count) * 57, 320))
            }
            Divider()
            Text("Keyboard or mouse activity resets these timers.")
                .font(.caption).foregroundStyle(.secondary).padding(16)
        }
        .frame(width: 340)
    }
}

struct MonitoringToggleCard: View {
    @ObservedObject var appState: AppState
    var body: some View {
        SentryCard {
            HStack(spacing: 16) {
                Image(systemName: appState.isMonitoring ? "checkmark.shield" : "pause.fill")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(appState.isMonitoring ? Color.accentColor : .secondary)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor.opacity(appState.isMonitoring ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.isMonitoring ? "Monitoring enabled" : "Monitoring paused").font(.system(size: 17, weight: .semibold))
                    Text(appState.isMonitoring
                         ? "Selected apps hide or quit when keyboard and mouse inactivity reaches their timeout."
                         : "Automatic actions are paused. Resume whenever you’re ready.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("Monitoring", isOn: $appState.isMonitoring).labelsHidden().toggleStyle(.switch)
                    .accessibilityLabel("Enable monitoring")
            }
        }
    }
}

struct ApplicationRow: View {
    let state: AppRunningState
    var timeout: Double? = nil
    var actionOverride: Binding<IdleAction?>? = nil
    var defaultAction: IdleAction = .standardQuit
    var remove: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 12) {
            ApplicationIcon(path: state.path)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(timeout.map { "Custom timeout · \(SentryFormat.duration($0))" } ?? state.bundleIdentifier)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Circle().fill(state.isRunning ? Color.green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                Text(state.isPlaybackProtected ? "Playback protected" : state.isHidden ? "Hidden" : state.isRunning ? "Running" : "Not running").font(.caption)
                    .foregroundStyle(state.isRunning ? Color.primary : Color.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.isPlaybackProtected ? "Playback protected" : state.isHidden ? "Hidden" : state.isRunning ? "Running" : "Not running")
            if let actionOverride {
                Picker("Action for \(state.name)", selection: actionOverride) {
                    Text("Default (\(defaultAction.title))").tag(nil as IdleAction?)
                    ForEach(IdleAction.allCases) { action in Text(action.title).tag(Optional(action)) }
                }
                .labelsHidden().frame(width: 170)
                .help("Action after inactivity for \(state.name)")
            }
            if let remove {
                Button(role: .destructive, action: remove) { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless).padding(.leading, 8)
                    .help("Remove \(state.name) from monitoring")
                    .accessibilityLabel("Remove \(state.name)")
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(state.path)
    }
}

struct AppRows: View {
    @ObservedObject var appState: AppState
    var allowsRemoval = false
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(appState.runningStates.enumerated()), id: \.element.id) { index, state in
                ApplicationRow(state: state,
                               timeout: appState.monitoredApps.first { $0.bundleIdentifier == state.bundleIdentifier }?.customTimeout,
                               actionOverride: allowsRemoval ? Binding(
                                get: { appState.monitoredApps.first { $0.bundleIdentifier == state.bundleIdentifier }?.customAction },
                                set: { value in
                                    if let index = appState.monitoredApps.firstIndex(where: { $0.bundleIdentifier == state.bundleIdentifier }) {
                                        appState.monitoredApps[index].customAction = value
                                    }
                                }) : nil,
                               defaultAction: appState.defaultAction,
                               remove: allowsRemoval ? { appState.removeApp(bundleId: state.bundleIdentifier) } : nil)
                if index < appState.runningStates.count - 1 { Divider().padding(.leading, 66) }
            }
        }
        .background(SentryPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.06)))
    }
}

struct EmptyAppsCard: View {
    let addApps: () -> Void
    var body: some View {
        SentryCard {
            VStack(spacing: 12) {
                Image(systemName: "plus.app").font(.system(size: 32, weight: .light)).foregroundStyle(Color.accentColor)
                    .padding(.bottom, 3).accessibilityHidden(true)
                Text("Choose what stays private").font(.system(size: 17, weight: .semibold))
                Text("Add the apps you’d like to hide or quit when you step away.\nEverything else stays just as you left it.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Add Apps", action: addApps).buttonStyle(.borderedProminent).padding(.top, 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var appState: AppState
    let showApps: () -> Void
    let showRules: () -> Void
    let addApps: () -> Void

    var body: some View {
        PageLayout("Dashboard", subtitle: "A quieter workspace when you step away.") {
            MonitoringToggleCard(appState: appState)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { summaryCards }
                VStack(spacing: 12) { summaryCards }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Your apps", detail: "\(appState.runningAppCount) running")
                if appState.monitoredApps.isEmpty {
                    EmptyAppsCard(addApps: addApps)
                } else {
                    AppRows(appState: appState)
                }
            }
            Label("On-device monitoring. Your activity stays on your Mac.", systemImage: "lock")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var summaryCards: some View {
        SummaryCard(symbol: "square.stack.3d.up.fill", tint: .blue, title: "Monitored apps",
                    value: "\(appState.monitoredApps.count) \(appState.monitoredApps.count == 1 ? "app" : "apps")",
                    detail: "\(appState.runningAppCount) running right now", actionTitle: "Manage Apps", action: showApps)
        SummaryCard(symbol: "clock.fill", tint: .teal, title: "Idle timeout", value: SentryFormat.duration(appState.globalTimeout),
                    detail: "Default for selected apps", actionTitle: "Adjust Timer", action: showRules)
        SummaryCard(symbol: "power", tint: .purple, title: "Idle action", value: appState.defaultAction.title,
                    detail: appState.defaultAction == .hide ? "Keeps your work open" : appState.fullyCloseApps ? "Background cleanup enabled" : appState.defaultAction == .forceQuit ? "Terminates immediately" : "Requests a normal quit",
                    actionTitle: "Change Rule", action: showRules)
    }
}

private struct SummaryCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String
    let detail: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        SentryCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.08)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint.opacity(0.16)))
                        .accessibilityHidden(true)
                    Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .frame(height: 32, alignment: .leading).padding(.bottom, 12)
                Text(value).font(.system(size: title == "Quit method" ? 16 : 25, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8).frame(height: 30, alignment: .leading)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).frame(height: 32, alignment: .topLeading).padding(.top, 5)
                Button(actionTitle, action: action).controlSize(.small).padding(.top, 12)
            }
        }
        .frame(minWidth: 155, maxWidth: .infinity)
    }
}

// MARK: - Application management

struct MonitoredAppsView: View {
    @ObservedObject var appState: AppState
    let addApps: () -> Void
    var body: some View {
        PageLayout("Monitored Apps", subtitle: "Choose the apps IdleSentry hides or quits after inactivity.") {
            if appState.monitoredApps.isEmpty {
                EmptyAppsCard(addApps: addApps)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Applications", detail: "\(appState.monitoredApps.count) added · \(appState.runningAppCount) running")
                    AppRows(appState: appState, allowsRemoval: true)
                }
                Label("Only apps in this list are monitored. Removing an app leaves it open.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}


private struct SystemIdleCard: View {
    var body: some View {
        HStack(spacing: 10) {
            ClockPauseShape()
                .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 22).accessibilityHidden(true)
            Text("System is idle").font(.system(size: 11.5, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.primary.opacity(0.04)))
        .accessibilityElement(children: .combine)
    }
}

private struct ClockPauseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: 12, y: 12), radius: 9,
                    startAngle: .degrees(0), endAngle: .degrees(-270), clockwise: true)
        path.move(to: CGPoint(x: 12, y: 7.5))
        path.addLine(to: CGPoint(x: 12, y: 12))
        path.addLine(to: CGPoint(x: 15, y: 12))
        for x in [16.5, 20.5] {
            path.move(to: CGPoint(x: x, y: 15.5))
            path.addLine(to: CGPoint(x: x, y: 20.5))
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}


private struct SidebarTips: View {
    @ObservedObject var appState: AppState
    let reviewRules: () -> Void
    let reviewSystem: () -> Void
    let reviewAccessibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick setup", systemImage: "lightbulb").font(.system(size: 12, weight: .semibold))
            if appState.needsAccessibilityRecovery {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recheck Accessibility access").font(.system(size: 11, weight: .medium))
                    Text("Access is missing. An update or reinstall can invalidate macOS’s saved approval.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("If the switch is on but access still fails:\n1. Remove IdleSentry with −.\n2. Add IdleSentry from Applications with +.\n3. Enable its access again.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Button("Open permission settings") { appState.openAccessibilitySettings() }
                        .font(.system(size: 10)).buttonStyle(.bordered).disabled(appState.isPreview)
                }
            } else if appState.needsAccessibilityTip {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enable Accessibility").font(.system(size: 11, weight: .medium))
                    Text("Needed to recognize supported unsaved-work warnings.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Button("Review Accessibility", action: reviewAccessibility)
                        .font(.system(size: 10)).buttonStyle(.bordered)
                }
            } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Review your settings").font(.system(size: 11, weight: .medium))
                Text("Default rules may not suit you. Review inactivity rules and System & Startup before leaving apps unattended.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Button("Inactivity Rules", action: reviewRules).buttonStyle(.link).font(.system(size: 10))
                Button("System & Startup", action: reviewSystem).buttonStyle(.link).font(.system(size: 10))
            }
            }
            HStack {
                Spacer()
                Button("Dismiss") { appState.dismissCurrentTip() }
                    .buttonStyle(.borderless).font(.system(size: 10))
                    .accessibilityLabel("Dismiss setup tips")
                Spacer()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.primary.opacity(0.06)))
    }
}
