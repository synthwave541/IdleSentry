import AppKit

final class HelperDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var quitRequests = 0
    let text = "Unsaved IdleSentry test document — café 🌙"
    let metrics = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--metrics=") }.map { String($0.dropFirst(10)) }!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 420, height: 240),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "IdleSentry disposable test document"
        let view = NSTextView(frame: window.contentView!.bounds)
        view.string = text
        window.contentView = view
        window.isDocumentEdited = true
        window.makeKeyAndOrderFront(nil)
        publish()
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in self.publish() }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitRequests += 1
        publish()
        return ProcessInfo.processInfo.arguments.contains("--refuse-quit") ? .terminateCancel : .terminateNow
    }
    func publish() {
        let data = try! JSONSerialization.data(withJSONObject: ["text": (window.contentView as! NSTextView).string,
                   "edited": window.isDocumentEdited, "hidden": NSApp.isHidden, "quitRequests": quitRequests])
        try! data.write(to: URL(fileURLWithPath: metrics), options: .atomic)
    }
}
let app = NSApplication.shared
let delegate = HelperDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
