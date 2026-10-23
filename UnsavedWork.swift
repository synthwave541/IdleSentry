import AppKit
import ApplicationServices
import os

enum UnsavedWorkAction: Int, CaseIterable, Identifiable {
    case leaveOpen = 0, hide = 1, forceQuit = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .leaveOpen: return "Leave open"
        case .hide: return "Hide"
        case .forceQuit: return "Force Quit"
        }
    }
}

struct SaveWarningEvidence {
    var editedDocument: Bool
    var dialog: Bool
    var save: Bool
    var discard: Bool
    var cancel: Bool
    var nativeSaveDecision: Bool = false
    var isConfirmed: Bool { (editedDocument || nativeSaveDecision) && dialog && save && discard && cancel }
}

enum UnsavedWorkInspector {
    /// Conservative public Accessibility inspection; unsupported/localized dialogs fail open.
    /// Never infer unsaved work from a timeout, a busy process, or an arbitrary sheet.
    static func reportsSaveWarning(_ app: NSRunningApplication) -> Bool {
        guard AXIsProcessTrusted(), !app.isTerminated else { return false }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.1)
        func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
            var result: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
            return result
        }
        let windows = value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
        let editedDocument = windows.prefix(12).contains { value($0, kAXEditedAttribute) as? Bool == true }
        let deadline = Date().addingTimeInterval(0.3)
        for window in windows.prefix(12) {
            let sheets = (value(window, kAXChildrenAttribute) as? [AXUIElement] ?? []).filter { value($0, kAXRoleAttribute) as? String == kAXSheetRole }
            let isDialog = value(window, kAXSubroleAttribute) as? String == kAXDialogSubrole ||
                value(window, kAXRoleAttribute) as? String == kAXSheetRole ||
                value(window, kAXIdentifierAttribute) as? String == "save-panel"
            let dialogs = sheets + (isDialog ? [window] : [])
            for dialog in dialogs {
                var queue: [AXUIElement] = [dialog]
                var titles = Set<String>()
                var identifiers = Set<String>()
                var visited = 0
                while !queue.isEmpty && visited < 48 && Date() < deadline {
                    let element = queue.removeFirst()
                    visited += 1
                    if value(element, kAXRoleAttribute) as? String == kAXButtonRole {
                        if let title = value(element, kAXTitleAttribute) as? String {
                            titles.insert(title.lowercased().replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        if let identifier = value(element, kAXIdentifierAttribute) as? String { identifiers.insert(identifier) }
                    }
                    queue += (value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).prefix(16)
                }
                // AppKit can autosave an unnamed draft and clear AXEdited while still
                // requiring a keep/discard decision. Its dedicated discard control is
                // stronger evidence than the generic Save button in an ordinary file panel.
                let nativeSaveDecision = value(dialog, kAXIdentifierAttribute) as? String == "save-panel" &&
                    identifiers.isSuperset(of: ["DontSaveButton", "CancelButton", "OKButton"])
                let evidence = SaveWarningEvidence(editedDocument: editedDocument, dialog: true,
                    save: identifiers.contains("OKButton") || titles.contains("save") || titles.contains("save…") || titles.contains("save..."),
                    discard: identifiers.contains("DontSaveButton") || titles.contains("don't save") || titles.contains("do not save"), cancel: identifiers.contains("CancelButton") || titles.contains("cancel"), nativeSaveDecision: nativeSaveDecision)
                Logger(subsystem: "com.zennoris.IdleSentry", category: "SaveWarnings")
                    .debug("Save warning: edited=\(editedDocument), native=\(nativeSaveDecision), save=\(evidence.save), discard=\(evidence.discard), cancel=\(evidence.cancel)")
                if evidence.isConfirmed { return true }
            }
        }
        return false
    }
}
